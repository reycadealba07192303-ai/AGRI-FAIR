import express from 'express';
import {
  sendChatMessage,
  getConversationMessages,
  getUserConversationsList
} from '../controllers/chatController.js';

import upload from '../middleware/multerMiddleware.js';
import { protect, authorizeRoles } from '../middleware/authMiddleware.js';

const router = express.Router();

router.use(protect);
router.use(authorizeRoles('superadmin', 'seller', 'buyer'));

// GET /api/chat/conversations
router.get('/conversations', getUserConversationsList);

// GET /api/chat/messages/:conversationId
router.get('/messages/:conversationId', getConversationMessages);

// POST /api/chat/send
router.post('/send', upload.single('media'), sendChatMessage);

export default router;