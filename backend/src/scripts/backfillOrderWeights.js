import 'dotenv/config';
import mongoose from 'mongoose';
import Order from '../models/Order.js';

/**
 * Gives older order lines the sack size they were always sold in.
 *
 * Run once:  node src/scripts/backfillOrderWeights.js
 *
 * `weightKg` did not exist when these were placed, so the only record of the
 * size is the product name checkout wrote - "Premium Jasmine Rice (25 kg)".
 * That is parsed back out here.
 *
 * It matters most for orders still waiting to be confirmed: confirming one
 * without a weight takes sacks off a shelf counted in kilograms, which is the
 * bug this repairs. A line whose name carries no weight is left at 1 kg, which
 * is what a manually typed sale means anyway.
 *
 * Stock already deducted is NOT corrected - that is a judgement call about
 * real inventory, so the script only reports the gap and leaves it alone.
 */

const uri = process.env.MONGO_URI || process.env.MONGODB_URI;
if (!uri) {
  console.error('No MONGO_URI in the environment.');
  process.exit(1);
}

await mongoose.connect(uri);

/** "Premium Jasmine Rice (Copy) (25 kg)" -> 25 */
const weightFromName = (name = '') => {
  const match = /\((\d+(?:\.\d+)?)\s*kg\)\s*$/i.exec(name.trim());
  return match ? Number(match[1]) : null;
};

const orders = await Order.find({
  $or: [{ weightKg: { $exists: false } }, { weightKg: 1 }],
});

let updated = 0;
let plain = 0;
let shortfall = 0;

for (const order of orders) {
  const kg = weightFromName(order.productName);
  if (!kg || kg === 1) {
    plain += 1;
    continue;
  }

  order.weightKg = kg;
  await order.save();
  updated += 1;

  // What confirming this line already took, versus what it should have.
  if (order.stockDeducted) {
    shortfall += order.quantity * kg - order.quantity;
  }

  console.log(`  + ${order.orderNumber}: ${order.quantity} x ${kg} kg = ${order.quantity * kg} kg`);
}

console.log(`\n${updated} line(s) given a sack size, ${plain} already sold by the kilo.`);

if (shortfall > 0) {
  console.log(
    `\nAlready-confirmed orders took ${shortfall} kg less off the shelf than they\n`
    + 'should have, back when sacks were counted as kilos. Nothing here changes\n'
    + 'that - correcting real stock is a decision for whoever counts the sacks.\n'
    + 'Adjust it from Inventory if the numbers on the floor disagree.'
  );
}

await mongoose.disconnect();
