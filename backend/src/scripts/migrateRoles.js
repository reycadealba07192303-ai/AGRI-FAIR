/**
 * One-shot migration: admin → client, user → customer
 * Run: node src/scripts/migrateRoles.js
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

  const adminResult = await users.updateMany(
    { role: 'admin' },
    { $set: { role: 'client' } }
  );
  const userResult = await users.updateMany(
    { role: 'user' },
    { $set: { role: 'customer' } }
  );

  console.log(`Migrated admin → client: ${adminResult.modifiedCount}`);
  console.log(`Migrated user → customer: ${userResult.modifiedCount}`);

  await mongoose.disconnect();
  process.exit(0);
}

migrate().catch((err) => {
  console.error(err);
  process.exit(1);
});
