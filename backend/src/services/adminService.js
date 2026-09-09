import * as adminRepo from '../repositories/adminRepository.js';
import * as orderRepo from '../repositories/orderRepository.js';
import * as inventoryRepo from '../repositories/inventoryRepository.js';
import * as notificationRepo from '../repositories/notificationRepository.js';
import { postOrderSystemMessage } from './chatService.js';
import { stockUnits } from '../models/Order.js';

// Valid next-statuses per current status (Orders module status flow).
const STATUS_TRANSITIONS = {
  pending: ['confirmed', 'cancelled'],
  confirmed: ['processing', 'cancelled'],
  processing: ['shipped', 'cancelled'],
  shipped: ['delivered'],
  delivered: ['completed'],
  completed: [],
  cancelled: [],
};

// Statuses at/after which stock has already been taken out of inventory.
const STOCK_DEDUCTED_STATUSES = ['confirmed', 'processing', 'shipped', 'delivered', 'completed'];

async function maybeNotifyLowStock(sellerId, product) {
  const fresh = await adminRepo.getProductById(product._id, sellerId);
  if (fresh && fresh.stock > 0 && fresh.stock <= fresh.lowStockThreshold) {
    await notificationRepo.createNotification({
      userId: sellerId,
      type: 'STOCK',
      title: `${fresh.name} is running low`,
      body: `Only ${fresh.stock}kg left (threshold: ${fresh.lowStockThreshold}kg).`,
      link: `/client?tab=Inventory`,
    });
  } else if (fresh && fresh.stock <= 0) {
    await notificationRepo.createNotification({
      userId: sellerId,
      type: 'STOCK',
      title: `${fresh.name} is out of stock`,
      body: 'Restock soon to avoid missed sales.',
      link: `/client?tab=Inventory`,
    });
  }
}

function validateProductInput(productData, { partial = false } = {}) {
  const required = ['name', 'variety', 'description', 'price', 'stock'];
  if (!partial) {
    for (const field of required) {
      if (productData[field] === undefined || productData[field] === '') {
        throw new Error(`${field} is required.`);
      }
    }
    if (!productData.images || productData.images.length === 0) {
      throw new Error('At least one product image is required.');
    }
  }
  if (productData.price !== undefined && Number(productData.price) < 1) {
    throw new Error('Price must be at least ₱1.');
  }
  if (productData.stock !== undefined && Number(productData.stock) < 0) {
    throw new Error('Stock cannot be negative.');
  }
}

export const addProduct = async (productData, adminId) => {
  validateProductInput(productData);
  return await adminRepo.addProduct(productData, adminId);
};

export const getMyProducts = async (adminId) => {
  if (!adminId) throw new Error('Admin ID is required.');
  return await adminRepo.getProductsByAdmin(adminId);
};

export const editProduct = async (id, sellerId, productData) => {
  validateProductInput(productData, { partial: true });
  const updated = await adminRepo.updateProduct(id, sellerId, productData);
  if (!updated) {
    throw new Error('Product not found.');
  }
  return updated;
};

export const deleteProduct = async (id, sellerId) => {
  const product = await adminRepo.getProductById(id, sellerId);
  if (!product) {
    throw new Error('Product not found.');
  }

  const hasActiveOrders = await orderRepo.hasActiveOrdersForProduct(id);
  if (hasActiveOrders) {
    throw new Error('This product has active orders and cannot be deleted. Deactivate it instead.');
  }

  await adminRepo.deleteProduct(id, sellerId);
  return { message: 'Product deleted successfully.' };
};

export const duplicateProduct = async (id, sellerId) => {
  const product = await adminRepo.getProductById(id, sellerId);
  if (!product) {
    throw new Error('Product not found.');
  }

  const clone = product.toObject();
  delete clone._id;
  delete clone.createdAt;
  delete clone.updatedAt;
  clone.name = `${clone.name} (Copy)`;

  return await adminRepo.addProduct(clone, sellerId);
};

export const viewOrders = async (sellerId) => {
  return await orderRepo.findOrdersBySeller(sellerId);
};

export const recordSale = async (payload, sellerId) => {
  const { productId, customerName, quantity } = payload;

  if (!productId || !customerName || !quantity) {
    throw new Error('Product, customer name, and quantity are required.');
  }

  const qty = Number(quantity);
  if (!Number.isFinite(qty) || qty < 1) {
    throw new Error('Quantity must be at least 1.');
  }

  const product = await adminRepo.getProductById(productId, sellerId);
  if (!product) {
    throw new Error('Product not found.');
  }

  const unitPrice = payload.unitPrice != null && payload.unitPrice !== ''
    ? Number(payload.unitPrice)
    : product.price;

  if (!Number.isFinite(unitPrice) || unitPrice < 0) {
    throw new Error('Unit price is invalid.');
  }

  const status = payload.status || 'pending';
  if (!STATUS_TRANSITIONS[status] && status !== 'pending') {
    throw new Error('Invalid order status.');
  }

  const deliveryFee = Number(payload.deliveryFee) || 0;
  const subtotal = unitPrice * qty;
  const total = subtotal + deliveryFee;

  const stockDeducted = STOCK_DEDUCTED_STATUSES.includes(status);
  if (stockDeducted) {
    const updated = await adminRepo.decrementStock(product._id, qty);
    if (!updated) {
      throw new Error('Not enough stock for this sale.');
    }
    await inventoryRepo.logMovement({
      sellerId,
      productId: product._id,
      productName: product.name,
      type: 'SALE',
      quantity: -qty,
      resultingStock: updated.stock,
      note: `Sale to ${customerName}`,
    });
    await maybeNotifyLowStock(sellerId, product);
  }

  const order = await orderRepo.createOrder({
    sellerId,
    productId: product._id,
    productName: product.name,
    unitPrice,
    quantity: qty,
    subtotal,
    deliveryFee,
    total,
    paymentMethod: payload.paymentMethod || 'Cash/COD',
    customerName,
    customerContact: payload.customerContact || '',
    deliveryAddress: payload.deliveryAddress || '',
    status,
    statusHistory: [{ status, changedAt: new Date() }],
    stockDeducted,
    orderDate: payload.orderDate ? new Date(payload.orderDate) : new Date(),
    notes: payload.notes || '',
  });

  const orderNumber = `ORD-${order._id.toString().slice(-6).toUpperCase()}`;
  const finalOrder = await orderRepo.setOrderNumber(order._id, orderNumber);

  await notificationRepo.createNotification({
    userId: sellerId,
    type: 'ORDER',
    title: `New order ${orderNumber}`,
    body: `${customerName} — ${qty}kg ${product.name}`,
    link: `/client?tab=Orders&order=${order._id}`,
  });

  return finalOrder;
};

export const getMyOrderAnalytics = async (sellerId) => {
  return await orderRepo.getSellerAnalytics(sellerId);
};

export const getMyOrderBreakdown = async (sellerId) => {
  return await orderRepo.getSellerBreakdown(sellerId);
};

export const getMyCustomers = async (sellerId) => {
  return await orderRepo.getDistinctCustomersForSeller(sellerId);
};

/**
 * What a status change says out loud.
 *
 * Written for the buyer, not the database: "shipped" on its own tells them
 * nothing about what to do next.
 */
const STATUS_SENTENCE = (orderNumber, status, reason) => {
  const sentences = {
    confirmed: `Order ${orderNumber} is confirmed. The seller is preparing it now.`,
    processing: `Order ${orderNumber} is being packed.`,
    shipped: `Order ${orderNumber} is on the way. Please keep your phone reachable for the rider.`,
    delivered: `Order ${orderNumber} was delivered. Tell the seller if anything is wrong with it.`,
    completed: `Order ${orderNumber} is complete. You can leave a review now.`,
    cancelled: `Order ${orderNumber} was cancelled${reason ? ` - ${reason}` : ''}.`,
  };

  return sentences[status] || `Order ${orderNumber} is now ${status}.`;
};

export const updateOrderStatus = async (orderId, sellerId, status, reason) => {
  const order = await orderRepo.findOrderById(orderId);
  if (!order) {
    throw new Error('Order not found.');
  }
  if (order.sellerId !== sellerId) {
    throw new Error('Not authorized to update this order.');
  }

  const allowedNext = STATUS_TRANSITIONS[order.status] || [];
  if (!allowedNext.includes(status)) {
    throw new Error(`Cannot move an order from "${order.status}" to "${status}".`);
  }

  if (status === 'cancelled' && !reason) {
    throw new Error('A reason is required to cancel an order.');
  }

  // Kilograms, not sacks. Stock is kept in kilograms and an order is counted
  // in sacks, so one 25 kg sack used to take a single kilo off the shelf.
  const kilos = stockUnits(order);

  // Deduct stock the moment an order is confirmed (not while merely pending).
  if (status === 'confirmed' && !order.stockDeducted) {
    const updated = await adminRepo.decrementStock(order.productId, kilos);
    if (!updated) {
      throw new Error('Not enough stock to confirm this order.');
    }
    await inventoryRepo.logMovement({
      sellerId,
      productId: order.productId,
      productName: order.productName,
      type: 'SALE',
      quantity: -kilos,
      resultingStock: updated.stock,
      note: `Order ${order.orderNumber} confirmed`,
    });
    // Sacks, deliberately: "8 sold" reads as eight bags, not eight kilos.
    await adminRepo.bumpSoldCount(order.productId, order.quantity);
    order.stockDeducted = true;
    await maybeNotifyLowStock(sellerId, { _id: order.productId });
  }

  // Restock if cancelling an order that had already taken stock out.
  if (status === 'cancelled' && order.stockDeducted) {
    await adminRepo.bumpSoldCount(order.productId, -order.quantity);
    const updated = await adminRepo.incrementStock(order.productId, kilos);
    if (updated) {
      await inventoryRepo.logMovement({
        sellerId,
        productId: order.productId,
        productName: order.productName,
        type: 'RETURN',
        quantity: kilos,
        resultingStock: updated.stock,
        note: `Order ${order.orderNumber} cancelled`,
      });
    }
  }

  const historyEntry = { status, changedAt: new Date(), reason: reason || '' };
  const updatedOrder = await orderRepo.updateOrderStatus(orderId, {
    status,
    statusReason: reason || '',
    stockDeducted: order.stockDeducted,
    historyEntry,
  });

  await notificationRepo.createNotification({
    userId: sellerId,
    type: 'ORDER',
    title: `Order ${order.orderNumber} ${status}`,
    body: reason || `Status updated to ${status}.`,
    link: `/client?tab=Orders&order=${order._id}`,
  });

  // And in the thread, where the buyer is already asking about it. Only for
  // storefront orders: one typed in by the seller has no buyer account behind
  // it and so nobody to tell.
  if (order.buyerUserId) {
    await postOrderSystemMessage({
      sellerUserId: sellerId,
      buyerUserId: order.buyerUserId,
      text: STATUS_SENTENCE(order.orderNumber, status, reason),
    });
  }

  return updatedOrder;
};

export const restockProduct = async (productId, sellerId, quantity, note) => {
  const qty = Number(quantity);
  if (!Number.isFinite(qty) || qty < 1) {
    throw new Error('Restock quantity must be at least 1.');
  }

  const product = await adminRepo.getProductById(productId, sellerId);
  if (!product) {
    throw new Error('Product not found.');
  }

  const updated = await adminRepo.incrementStock(productId, qty);
  await inventoryRepo.logMovement({
    sellerId,
    productId,
    productName: product.name,
    type: 'RESTOCK',
    quantity: qty,
    resultingStock: updated.stock,
    note: note || '',
  });

  return updated;
};

export const adjustStock = async (productId, sellerId, quantity, type, note) => {
  const qty = Number(quantity);
  if (!Number.isFinite(qty) || qty === 0) {
    throw new Error('Adjustment quantity must be non-zero.');
  }
  if (!['ADJUSTMENT', 'DAMAGE'].includes(type)) {
    throw new Error('Invalid adjustment type.');
  }

  const product = await adminRepo.getProductById(productId, sellerId);
  if (!product) {
    throw new Error('Product not found.');
  }

  const updated = qty > 0
    ? await adminRepo.incrementStock(productId, qty)
    : await adminRepo.decrementStock(productId, Math.abs(qty));

  if (!updated) {
    throw new Error('Not enough stock for this adjustment.');
  }

  await inventoryRepo.logMovement({
    sellerId,
    productId,
    productName: product.name,
    type,
    quantity: qty,
    resultingStock: updated.stock,
    note: note || '',
  });

  if (qty < 0) {
    await maybeNotifyLowStock(sellerId, { _id: productId });
  }

  return updated;
};

export const getInventorySummary = async (sellerId) => {
  return await inventoryRepo.getInventorySummary(sellerId);
};

export const getStockMovements = async (productId, sellerId) => {
  return await inventoryRepo.findMovementsByProduct(productId, sellerId);
};
// --- PAYMENT VERIFICATION (GCash QR flow) ---
/**
 * The seller opens their own GCash app, checks whether the money actually
 * arrived, and records the answer here. AgriFair never holds the funds, so this
 * confirmation is the only source of truth about payment.
 */
export const reviewOrderPayment = async (orderId, sellerId, { paid, note, reference, amount }) => {
  const order = await orderRepo.findOrderById(orderId);
  if (!order) throw new Error('Order not found');
  if (order.sellerId !== sellerId) throw new Error('Not your order');

  if (paid) {
    order.paymentStatus = 'paid';
    order.amountPaid = amount != null ? Number(amount) : order.total;
    order.paidAt = new Date();
    order.paymentReference = reference || order.paymentReference || '';
    order.paymentNote = note || '';
  } else {
    order.paymentStatus = 'rejected';
    order.amountPaid = 0;
    order.paidAt = null;
    order.paymentNote = note || '';
  }

  order.paymentReviewedAt = new Date();
  await order.save();

  return order;
};
