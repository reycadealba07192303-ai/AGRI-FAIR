import crypto from 'crypto';
import * as cartRepo from '../repositories/cartRepository.js';
import Product from '../models/Product.js';
import Order from '../models/Order.js';
import { findUserByUserId } from '../repositories/userRepository.js';

/** Two lines are the same line only if the rice and the sack size both match. */
const sameLine = (item, productId, weightKg) =>
  String(item.productId) === String(productId) &&
  Number(item.weightKg || 1) === Number(weightKg);

/** Price of one sack at this weight, applying its tier discount if one is set. */
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

    const weightKg = Number(item.weightKg || 1);
    const sacks = Number(item.quantity);

    // Priced per sack and multiplied, not priced as one big weight: three
    // 50 kg sacks earn the 50 kg discount three times, where 150 kg matches
    // no tier at all and would quietly lose it.
    const perSack = priceForWeight(product, weightKg);
    const lineTotal = Math.round(perSack * sacks * 100) / 100;

    const needed = weightKg * sacks;
    const available = Number(product.stock || 0);

    items.push({
      productId: String(product._id),
      sellerId: product.createdBy,
      name: product.name,
      variety: product.variety || '',
      image: product.images?.[0] || null,
      weightKg,
      quantity: sacks,
      // What the buyer's sacks come to in stock terms, so the seller's page
      // and the buyer's are talking about the same number.
      totalKg: needed,
      unitPrice: perSack,
      unitPriceAtAdd: item.unitPriceAtAdd,
      priceChanged: Number(item.unitPriceAtAdd) !== perSack,
      lineTotal,
      inStock: available >= needed,
      availableStock: available,
    });

    if (available >= needed) subtotal += lineTotal;
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

export const addItem = async (buyerUserId, { productId, weightKg, quantity }) => {
  const sacks = Number(quantity);
  const weight = Number(weightKg || 1);

  if (!productId) throw new Error('Which product?');
  if (!Number.isFinite(weight) || weight <= 0) throw new Error('Choose a weight.');
  if (!Number.isFinite(sacks) || sacks <= 0) throw new Error('Choose how many.');

  const product = await Product.findById(productId);
  if (!product) throw new Error('Product not found');
  if (product.status === 'inactive') throw new Error('That product is not for sale right now.');

  const cart = await cartRepo.getOrCreate(buyerUserId);
  const existing = cart.items.find((i) => sameLine(i, productId, weight));

  // Checked against what the cart would hold in total, not just what is being
  // added, or three separate taps could add past the stock one at a time.
  const wanted = weight * (sacks + Number(existing?.quantity || 0));
  if (Number(product.stock) < wanted) {
    throw new Error(`Only ${product.stock} kg left.`);
  }

  if (existing) {
    existing.quantity = Number(existing.quantity) + sacks;
  } else {
    cart.items.push({
      productId: product._id,
      sellerId: product.createdBy,
      weightKg: weight,
      quantity: sacks,
      unitPriceAtAdd: priceForWeight(product, weight),
    });
  }

  await cartRepo.save(cart);
  return decorate(cart);
};

export const setQuantity = async (buyerUserId, productId, quantity, weightKg = 1) => {
  const sacks = Number(quantity);
  const weight = Number(weightKg || 1);

  const cart = await cartRepo.getOrCreate(buyerUserId);
  const item = cart.items.find((i) => sameLine(i, productId, weight));
  if (!item) throw new Error('That item is not in your cart.');

  if (sacks <= 0) {
    cart.items = cart.items.filter((i) => !sameLine(i, productId, weight));
  } else {
    const product = await Product.findById(productId);
    if (product && Number(product.stock) < weight * sacks) {
      throw new Error(`Only ${product.stock} kg left.`);
    }
    item.quantity = sacks;
  }

  await cartRepo.save(cart);
  return decorate(cart);
};

export const removeItem = async (buyerUserId, productId, weightKg = 1) =>
  setQuantity(buyerUserId, productId, 0, weightKg);

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
      // The name carries the sack size, since an order row for "3 × Jasmine"
      // does not say whether that is 3 kg or 150.
      productName: line.weightKg > 1
        ? `${line.name} (${line.weightKg} kg)`
        : line.name,
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
