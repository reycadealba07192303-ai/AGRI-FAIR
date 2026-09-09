import 'dotenv/config';
import mongoose from 'mongoose';
import Product from '../models/Product.js';
import Order, { stockUnits } from '../models/Order.js';
import { updateOrderStatus } from '../services/adminService.js';

/**
 * Checks that confirming an order moves kilograms, not sacks.
 *
 * Run:  node src/scripts/checkStockUnits.js
 *
 * Stock is kept in kilograms and an order is counted in sacks. Reading one as
 * the other is invisible until somebody notices a 25 kg sale took a single
 * kilo off the shelf - which is exactly how this bug survived.
 *
 * Leaves nothing behind: it confirms an order and then cancels it, and the
 * cancellation is itself the second half of the check. Any pending sack order
 * will do, so this is safe to run again.
 */

const uri = process.env.MONGO_URI || process.env.MONGODB_URI;
if (!uri) {
  console.error('No MONGO_URI in the environment.');
  process.exit(1);
}

await mongoose.connect(uri);

const order = await Order.findOne({
  status: 'pending',
  weightKg: { $gt: 1 },
}).sort({ createdAt: -1 });

if (!order) {
  console.log('No pending order sold by the sack. Place one and run this again.');
  await mongoose.disconnect();
  process.exit(0);
}

const expected = stockUnits(order);
const before = await Product.findById(order.productId).select('stock soldCount');

console.log(`order   ${order.orderNumber}: ${order.quantity} x ${order.weightKg} kg`);
console.log(`stock   ${before.stock} kg, ${before.soldCount} sold`);

await updateOrderStatus(order._id, order.sellerId, 'confirmed');
const afterConfirm = await Product.findById(order.productId).select('stock soldCount');
const moved = before.stock - afterConfirm.stock;

console.log(`confirm ${afterConfirm.stock} kg  ->  ${moved} kg left the shelf, expected ${expected}`);

await updateOrderStatus(order._id, order.sellerId, 'cancelled', 'stock unit check');
const afterCancel = await Product.findById(order.productId).select('stock soldCount');

console.log(`cancel  ${afterCancel.stock} kg  ->  back to where it started?`);

const results = [
  ['kilograms leave the shelf, not sacks', moved === expected],
  ['sold count moves by sacks', afterConfirm.soldCount - before.soldCount === order.quantity],
  ['cancelling returns exactly what it took', afterCancel.stock === before.stock],
  ['cancelling returns the sold count too', afterCancel.soldCount === before.soldCount],
];

console.log('');
for (const [what, ok] of results) {
  console.log(`  ${ok ? 'OK  ' : 'FAIL'}  ${what}`);
}

await mongoose.disconnect();
process.exit(results.every(([, ok]) => ok) ? 0 : 1);
