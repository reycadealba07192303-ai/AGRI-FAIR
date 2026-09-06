import * as orderRepo from '../repositories/orderRepository.js';

const TRACKABLE = ['shipped', 'delivered'];

/**
 * The seller (or their courier) pushes a position while an order is in transit.
 * Only the seller who owns the order may write it.
 */
export const updateLocation = async (orderId, sellerId, { lat, lng, etaMinutes, courierName, courierContact }) => {
  const order = await orderRepo.findOrderById(orderId);
  if (!order) throw new Error('Order not found');
  if (order.sellerId !== sellerId) throw new Error('Not your order');

  if (!TRACKABLE.includes(order.status)) {
    throw new Error('Tracking only runs once the order is shipped.');
  }

  const latN = Number(lat);
  const lngN = Number(lng);
  if (!Number.isFinite(latN) || latN < -90 || latN > 90) throw new Error('Invalid latitude');
  if (!Number.isFinite(lngN) || lngN < -180 || lngN > 180) throw new Error('Invalid longitude');

  order.delivery = {
    ...(order.delivery?.toObject?.() || order.delivery || {}),
    lat: latN,
    lng: lngN,
    etaMinutes: etaMinutes != null ? Number(etaMinutes) : order.delivery?.etaMinutes ?? null,
    courierName: courierName ?? order.delivery?.courierName ?? '',
    courierContact: courierContact ?? order.delivery?.courierContact ?? '',
    updatedAt: new Date(),
    isLive: true,
  };

  await order.save();
  return order.delivery;
};

/** Both the buyer who placed the order and the seller may read the position. */
export const getTracking = async (orderId, user) => {
  const order = await orderRepo.findOrderById(orderId);
  if (!order) throw new Error('Order not found');

  const isSeller = order.sellerId === user.userId;
  const isBuyer = order.buyerUserId === user.userId;
  if (!isSeller && !isBuyer && user.role !== 'superadmin') {
    throw new Error('This order is not yours');
  }

  const d = order.delivery || {};
  return {
    orderNumber: order.orderNumber,
    status: order.status,
    isLive: Boolean(d.isLive && TRACKABLE.includes(order.status)),
    lat: d.lat ?? null,
    lng: d.lng ?? null,
    etaMinutes: d.etaMinutes ?? null,
    courierName: d.courierName || '',
    courierContact: d.courierContact || '',
    updatedAt: d.updatedAt || null,
    destination: order.deliveryAddress || '',
  };
};

/** Called when an order completes: stop broadcasting a rider's position. */
export const stopTracking = async (order) => {
  if (!order?.delivery) return;
  order.delivery.isLive = false;
  order.delivery.lat = null;
  order.delivery.lng = null;
  await order.save();
};
