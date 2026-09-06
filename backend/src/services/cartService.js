import crypto from 'crypto';
import * as cartRepo from '../repositories/cartRepository.js';
import Product from '../models/Product.js';
import Order from '../models/Order.js';
import { findUserByUserId } from '../repositories/userRepository.js';

/** Price for a weight tier, applying its discount if one is set. */
function priceForWeight(product, weightKg) {
  const base = Number(product.price || 0) * Number(weightKg);
  const tier = (product.weightTiers || []).find((t) => Number(t.weightKg) === Number(weightKg));
  if (!tier?.discountPercent) return base;
  return Math.round(base * (1 - Number(tier.discountPercent) / 100) * 100) / 100;
}

/**
 * Rebuilds the cart against live products so the buyer sees the truth: a price
 * that moved, or an item that sold out while it sat in the cart.
 */
async function decorate(cart) {
  const ids = cart.items.map((i) => i.productId);
  const products = await Product.find({ _id: { $in: ids } }).lean();
  const byId = new Map(products.map((p) => [String(p._id), p]));

  const items = [];
  let subtotal = 0;

  for (const item of cart.items) {
    const product = byId.get(String(item.productId));
    if (!product) continue; // listing was deleted

    const unitNow = Number(product.price || 0);
    const lineTotal = priceForWeight(product, item.quantity);
    const available = Number(product.stock || 0);

    items.push({
      productId: String(product._id),
      sellerId: product.createdBy,
      name: product.name,
      variety: product.variety || '',
      image: product.images?.[0] || null,
      quantity: item.quantity,
      unitPrice: unitNow,
      unitPriceAtAdd: item.unitPriceAtAdd,
      priceChanged: Number(item.unitPriceAtAdd) !== unitNow,
      lineTotal,
      inStock: available >= item.quantity,
      availableStock: available,
    });

    if (available >= item.quantity) subtotal += lineTotal;
  }

  const blocked = items.filter((i) => !i.inStock);

  return {
    items,
    subtotal: Math.round(subtotal * 100) / 100,
    itemCount: items.reduce((n, i) => n + 1, 0),
    hasUnavailable: blocked.length > 0,
    unavailable: blocked.map((i) => i.name),
  };
}

export const getCart = async (buyerUserId) => decorate(await cartRepo.getOrCreate(buyerUserId));

export const addItem = async (buyerUserId, { productId, quantity }) => {
  const qty = Number(quantity);
  if (!productId) throw new Error('Which product?');
  if (!Number.isFinite(qty) || qty <= 0) throw new Error('Choose a valid weight.');

  const product = await Product.findById(productId);
  if (!product) throw new Error('Product not found');
  if (product.status === 'inactive') throw new Error('That product is not for sale right now.');
  if (Number(product.stock) < qty) throw new Error(`Only ${product.stock} kg left.`);

  const cart = await cartRepo.getOrCreate(buyerUserId);
  const existing = cart.items.find((i) => String(i.productId) === String(productId));

  if (existing) {
    existing.quantity = Number(existing.quantity) + qty;
  } else {
    cart.items.push({
      productId: product._id,
      sellerId: product.createdBy,
      quantity: qty,
      unitPriceAtAdd: Number(product.price || 0),
    });
  }

  await cartRepo.save(cart);
  return decorate(cart);
};

export const setQuantity = async (buyerUserId, productId, quantity) => {
  const qty = Number(quantity);
  const cart = await cartRepo.getOrCreate(buyerUserId);
  const item = cart.items.find((i) => String(i.productId) === String(productId));
  if (!item) throw new Error('That item is not in your cart.');

  if (qty <= 0) {
    cart.items = cart.items.filter((i) => String(i.productId) !== String(productId));
  } else {
    item.quantity = qty;
  }

  await cartRepo.save(cart);
  return decorate(cart);
};

export const removeItem = async (buyerUserId, productId) => setQuantity(buyerUserId, productId, 0);

export const clearCart = async (buyerUserId) => decorate(await cartRepo.clear(buyerUserId));

/**
 * Turns the cart into orders. One Order row per line item — sellers fulfil and
 * get paid separately — but all rows share a groupId and order number so the
 * buyer sees one receipt.
 */
export const checkout = async (buyerUserId, {
  customerName,
  customerContact,
  deliveryAddress,
  paymentMethod,
  notes,
  deliveryFee = 0,
  paymentProof = '',
  paymentReference = '',
}) => {
  const cart = await cartRepo.getOrCreate(buyerUserId);
  if (!cart.items.length) throw new Error('Your cart is empty.');

  const view = await decorate(cart);
  if (view.hasUnavailable) {
    throw new Error(`Out of stock: ${view.unavailable.join(', ')}. Remove them to continue.`);
  }
  if (!deliveryAddress?.trim()) throw new Error('Add a delivery address.');
  if (!customerName?.trim()) throw new Error('Add the name for this delivery.');

  const buyer = await findUserByUserId(buyerUserId);
  const groupId = crypto.randomUUID();
  const orderNumber = `AGF-${crypto.randomBytes(3).toString('hex').toUpperCase()}`;

  // The delivery fee belongs to the whole basket, so it lands on the first row
  // only — otherwise the buyer is charged once per seller.
  const orders = [];
  for (const [index, line] of view.items.entries()) {
    const fee = index === 0 ? Number(deliveryFee) : 0;
    orders.push(await Order.create({
      sellerId: line.sellerId,
      productId: line.productId,
      productName: line.name,
      unitPrice: line.unitPrice,
      quantity: line.quantity,
      subtotal: line.lineTotal,
      deliveryFee: fee,
      total: line.lineTotal + fee,
      paymentMethod: paymentMethod || 'Cash/COD',

      // A receipt attached at checkout means the buyer has already sent the
      // money and is waiting on the seller to confirm it. Without one the
      // order is simply unpaid - cash on delivery, or GCash still to be sent.
      paymentStatus: paymentProof ? 'proof_sent' : 'unpaid',
      paymentProof,
      paymentReference,
      customerName: customerName.trim(),
      customerContact: customerContact?.trim() || buyer?.contact || '',
      deliveryAddress: deliveryAddress.trim(),
      buyerUserId,
      status: 'pending',
      source: 'storefront',
      orderNumber,
      groupId,
      notes: notes?.trim() || '',
    }));
  }

  await cartRepo.clear(buyerUserId);

  return {
    orderNumber,
    groupId,
    itemCount: orders.length,
    total: orders.reduce((sum, o) => sum + Number(o.total), 0),
    paymentMethod: paymentMethod || 'Cash/COD',
    deliveryAddress: deliveryAddress.trim(),
  };
};
