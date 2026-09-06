/**
 * One-shot migration: fills nameKey for users created before names had to be
 * unique. Without it those accounts are invisible to the duplicate check, so a
 * new signup could take a name that is already in use.
 *
 * Also reports names that already collide. Those have to be settled by hand -
 * the script will not rename anyone's account for them.
 *
 * Run: node src/scripts/backfillNameKeys.js
 */
import path from 'path';
import { fileURLToPath } from 'url';
import mongoose from 'mongoose';
import dotenv from 'dotenv';

import User, { toNameKey } from '../models/User.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

dotenv.config({ path: path.join(__dirname, '../../.env') });

async function backfill() {
  const uri = process.env.MONGODB_URI || process.env.MONGO_URI;
  if (!uri) {
    console.error('MONGODB_URI missing in .env');
    process.exit(1);
  }

  await mongoose.connect(uri);

  const users = await User.find().select('name nameKey email');
  let filled = 0;

  for (const user of users) {
    const key = toNameKey(user.name);
    if (user.nameKey !== key) {
      await User.updateOne({ _id: user._id }, { nameKey: key });
      filled += 1;
    }
  }

  console.log(`nameKey written for ${filled} of ${users.length} users`);

  const clashes = await User.aggregate([
    { $group: { _id: '$nameKey', count: { $sum: 1 }, emails: { $push: '$email' } } },
    { $match: { count: { $gt: 1 } } },
  ]);

  if (clashes.length === 0) {
    console.log('no duplicate names — safe to add a unique index on nameKey');
  } else {
    console.log(`\n${clashes.length} name(s) already used more than once:`);
    for (const clash of clashes) {
      console.log(`  "${clash._id}" -> ${clash.emails.join(', ')}`);
    }
    console.log('\nRename all but one of each before adding a unique index.');
  }

  await mongoose.disconnect();
}

backfill().catch((err) => {
  console.error(err);
  process.exit(1);
});
