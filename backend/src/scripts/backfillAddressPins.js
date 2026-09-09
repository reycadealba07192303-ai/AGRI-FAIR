import 'dotenv/config';
import mongoose from 'mongoose';
import User from '../models/User.js';
import Order from '../models/Order.js';
import { locateArea } from '../services/geocodeService.js';

/**
 * Gives a point to addresses and orders saved before addresses had one.
 *
 * Run once:  node src/scripts/backfillAddressPins.js
 *
 * Two passes. The first locates every saved address by its barangay, so the
 * next order placed to it carries a destination. The second fills in orders
 * whose route was snapshotted when there was nothing to snapshot - filling a
 * blank, never moving a pin that already exists, because an order already on
 * the road must not change where it is going.
 *
 * Safe to run again: anything already located is skipped, and the geocode
 * cache means a second run asks the map service nothing at all.
 */

const uri = process.env.MONGO_URI || process.env.MONGODB_URI;
if (!uri) {
  console.error('No MONGO_URI in the environment.');
  process.exit(1);
}

await mongoose.connect(uri);

let located = 0;
let skipped = 0;
let unfound = 0;

const users = await User.find({ 'addresses.0': { $exists: true } });

for (const user of users) {
  let touched = false;

  for (const address of user.addresses) {
    if (address.lat != null && address.lng != null) {
      skipped += 1;
      continue;
    }

    const area = await locateArea({
      barangay: address.barangay,
      city: address.city,
      province: address.province,
    });

    if (!area) {
      unfound += 1;
      console.log(`  ? ${[address.barangay, address.city, address.province].filter(Boolean).join(', ')} — not on the map`);
      continue;
    }

    address.lat = area.lat;
    address.lng = area.lng;
    address.precision = 'approximate';
    touched = true;
    located += 1;

    console.log(`  + ${[address.barangay, address.city].filter(Boolean).join(', ')} → ${area.lat}, ${area.lng}`);
  }

  if (touched) await user.save();
}

console.log(`\nAddresses: ${located} located, ${skipped} already had a point, ${unfound} not found.`);

// --- Orders placed before a route was recorded ---
let orders = 0;

const pending = await Order.find({
  buyerUserId: { $ne: null },
  $or: [{ 'route.dropoffLat': null }, { 'route.dropoffLat': { $exists: false } }],
});

for (const order of pending) {
  const buyer = await User.findOne({ userId: order.buyerUserId });
  if (!buyer) continue;

  // The address the order text was written from. Matched on the words rather
  // than an id, because the id was never stored on these older orders.
  const match = (buyer.addresses || []).find(
    (a) => a.lat != null && order.deliveryAddress?.includes(a.city),
  );
  if (!match) continue;

  order.route = {
    ...(order.route?.toObject?.() || order.route || {}),
    dropoffLat: match.lat,
    dropoffLng: match.lng,
    dropoffPrecision: match.precision || 'approximate',
  };

  await order.save();
  orders += 1;
  console.log(`  + ${order.orderNumber} → ${match.city}`);
}

console.log(`Orders: ${orders} given a destination.`);

await mongoose.disconnect();
