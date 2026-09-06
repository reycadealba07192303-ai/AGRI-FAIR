import multer from 'multer';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export const PUBLIC_DIR = path.join(__dirname, '../uploads/media');
export const PRIVATE_DIR = path.join(__dirname, '../uploads/private');

for (const dir of [PUBLIC_DIR, PRIVATE_DIR]) {
  fs.mkdirSync(dir, { recursive: true });
}

/**
 * Anything a buyer is meant to see (product photos, farm photos, avatars) goes to
 * PUBLIC_DIR, which is served statically.
 *
 * Credentials — BIR certificates, permits, payment QR codes — go to PRIVATE_DIR,
 * which is never served statically. They are only readable through the
 * authenticated /api/files route, which checks who is asking.
 */
const PRIVATE_FIELDS = new Set(['paymentQr', 'document']);

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, PRIVATE_FIELDS.has(file.fieldname) ? PRIVATE_DIR : PUBLIC_DIR);
  },
  filename: (req, file, cb) => {
    // Random name, not the original: a predictable filename is a guessable URL,
    // and the original name often leaks what the document is.
    const ext = path.extname(file.originalname).toLowerCase().slice(0, 10);
    const random = Math.random().toString(36).slice(2, 10);
    cb(null, `${Date.now()}-${random}${ext}`);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 8 * 1024 * 1024 },
});

export default upload;
