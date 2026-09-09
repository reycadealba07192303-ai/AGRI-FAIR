import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { initializeApp, cert, getApps } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

function resolveCredentialsPath() {
  const fromEnv = process.env.FIREBASE_CREDENTIALS_PATH;
  if (fromEnv) {
    return path.isAbsolute(fromEnv)
      ? fromEnv
      : path.resolve(process.cwd(), fromEnv);
  }

  // Default: Captone-Project/agrifair-*-firebase-adminsdk-*.json
  return path.resolve(__dirname, '../../../agrifair-a9ac5-firebase-adminsdk-fbsvc-90e258dd39.json');
}

function loadServiceAccount() {
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT?.trim();
  if (raw) {
    return JSON.parse(raw);
  }

  const credentialsPath = resolveCredentialsPath();
  if (!fs.existsSync(credentialsPath)) {
    console.warn('⚠️  Firebase credentials not found at:', credentialsPath);
    return null;
  }

  return JSON.parse(fs.readFileSync(credentialsPath, 'utf8'));
}

export function initFirebase() {
  if (getApps().length > 0) {
    return getApps()[0];
  }

  let serviceAccount;
  try {
    serviceAccount = loadServiceAccount();
  } catch (err) {
    console.warn('⚠️  Firebase credentials invalid:', err.message);
    return null;
  }

  if (!serviceAccount) return null;

  const app = initializeApp({
    credential: cert(serviceAccount),
    projectId: serviceAccount.project_id,
  });

  console.log('🔥 Firebase Admin initialized:', serviceAccount.project_id);
  return app;
}

export function getFirebaseAuth() {
  const app = initFirebase();
  if (!app) return null;
  return getAuth(app);
}
