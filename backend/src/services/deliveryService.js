import * as orderRepo from '../repositories/orderRepository.js';
import { findUserByUserId } from '../repositories/userRepository.js';

const TRACKABLE = ['shipped', 'delivered'];

/**
 * The seller (or their courier) pushes a position while an order is in transit.
 * Only the seller who owns the order may write it.
 */
export const updateLocation = async (orderId, actor, { lat, lng, etaMinutes, courierName, courierContact }) => {
  const order = await orderRepo.findOrderById(orderId);
  if (!order) throw new Error('Order not found');

  // Two people may say where this order is: the seller who owns it, and the
  // rider actually carrying it. Assignment is what grants the rider that -
  // working for the seller is not enough on its own.
  const userId = typeof actor === 'object' ? actor.userId : actor;
  const isSeller = order.sellerId === userId;
  const isAssignedRider = order.delivery?.riderUserId === userId;

  if (!isSeller && !isAssignedRider) throw new Error('Not your order');

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
  const isRider = order.delivery?.riderUserId === user.userId;
  if (!isSeller && !isBuyer && !isRider && user.role !== 'superadmin') {
    throw new Error('This order is not yours');
  }

  const d = order.delivery || {};
  const r = order.route || {};

  // The snapshot is the truth once it exists. When it does not - an order
  // placed before the seller had pinned their shop - their current pickup
  // point stands in, so setting it late fixes the orders already out there
  // rather than only the next ones.
  let pickupLat = r.pickupLat ?? null;
  let pickupLng = r.pickupLng ?? null;
  let pickupAddress = r.pickupAddress || '';

  if (pickupLat == null || pickupLng == null) {
    const seller = await findUserByUserId(order.sellerId);
    pickupLat = seller?.pickupLat ?? null;
    pickupLng = seller?.pickupLng ?? null;
    pickupAddress = pickupAddress || seller?.pickupAddress || '';
  }

  return {
    orderNumber: order.orderNumber,
    status: order.status,
    productName: order.productName || '',
    isLive: Boolean(d.isLive && TRACKABLE.includes(order.status)),
    lat: d.lat ?? null,
    lng: d.lng ?? null,
    etaMinutes: d.etaMinutes ?? null,
    courierName: d.courierName || '',
    courierContact: d.courierContact || '',
    updatedAt: d.updatedAt || null,
    destination: order.deliveryAddress || '',

    /** The assigned rider, once the seller has put somebody on it. */
    riderUserId: d.riderUserId ?? null,

    // The photo taken at the door, and when. Behind /api/files - the buyer's
    // gate is in it - and readable by the three people on the delivery.
    proofOfDelivery: d.proofOfDelivery || '',
    deliveredAt: d.deliveredAt || null,
    deliveryNote: d.deliveryNote || '',

    // The two fixed ends. Both are known the moment an order exists, so the
    // map has something to show long before anybody shares a position.
    pickup: {
      lat: pickupLat,
      lng: pickupLng,
      address: pickupAddress,
    },
    dropoff: {
      lat: r.dropoffLat ?? null,
      lng: r.dropoffLng ?? null,
      address: order.deliveryAddress || '',
      // How good that point is. A barangay centre must never be presented as
      // somebody's front door.
      precision: r.dropoffPrecision || '',
    },
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
