/**
 * One-shot migration: client → seller, customer → buyer
 * Run: node src/scripts/migrateSellerBuyer.js
 */
import path from 'path';
import { fileURLToPath } from 'url';
import mongoose from 'mongoose';
import dotenv from 'dotenv';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

dotenv.config({ path: path.join(__dirname, '../../.env') });

async function migrate() {
  const uri = process.env.MONGODB_URI || process.env.MONGO_URI;
  if (!uri) {
    console.error('MONGODB_URI missing in .env');
    process.exit(1);
  }

  await mongoose.connect(uri);
  const users = mongoose.connection.collection('users');

  const clientResult = await users.updateMany(
    { role: 'client' },
    { $set: { role: 'seller' } }
  );
  const customerResult = await users.updateMany(
    { role: 'customer' },
    { $set: { role: 'buyer' } }
  );

  console.log(`Migrated client → seller: ${clientResult.modifiedCount}`);
  console.log(`Migrated customer → buyer: ${customerResult.modifiedCount}`);

  await mongoose.disconnect();
  process.exit(0);
}

migrate().catch((err) => {
  console.error(err);
  process.exit(1);
});
