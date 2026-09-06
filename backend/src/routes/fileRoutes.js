import express from 'express';
import fs from 'fs';
import path from 'path';
import { protect } from '../middleware/authMiddleware.js';
import { PRIVATE_DIR } from '../middleware/multerMiddleware.js';
import { findUserByUserId } from '../repositories/userRepository.js';

const router = express.Router();

/** Every private file this user is allowed to read. */
function ownedFiles(user) {
  const files = [];
  if (user?.payout?.qrImage) files.push(user.payout.qrImage);
  for (const doc of user?.documents || []) {
    if (doc.file) files.push(doc.file);
  }
  return files.map((f) => path.basename(f));
}

/**
 * Credentials are readable only by the person they belong to, or by a Super Admin
 * reviewing them. They are deliberately not served by express.static — a file
 * behind a guessable URL is a file anyone can take.
 */
router.get('/:filename', protect, async (req, res) => {
  // basename() strips any ../ so a crafted name cannot escape the folder.
  const filename = path.basename(req.params.filename);
  const filePath = path.join(PRIVATE_DIR, filename);

  if (!fs.existsSync(filePath)) {
    return res.status(404).json({ error: 'File not found' });
  }

  const isSuperAdmin = req.user.role === 'superadmin';

  if (!isSuperAdmin) {
    const user = await findUserByUserId(req.user.userId);
    if (!ownedFiles(user).includes(filename)) {
      return res.status(403).json({ error: 'Not your file' });
    }
  }

  // Credentials must never be cached by a shared proxy.
  res.setHeader('Cache-Control', 'private, no-store');
  res.sendFile(filePath);
});

export default router;
