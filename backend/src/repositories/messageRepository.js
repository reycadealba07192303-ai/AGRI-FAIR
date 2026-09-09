import { Message } from '../models/Chat.js';

/** Just enough of a listing to draw a card in a thread - never the whole document. */
const PRODUCT_CARD_FIELDS = 'name price variety images stock createdBy';

const createMessage = async (conversationId, senderId, receiverId, text, mediaUrl, extra = {}) => {
  return await Message.create({
    conversationId,
    sender: senderId,
    receiver: receiverId,
    text,
    mediaUrl,
    ...extra,
  });
};

const getMessagesByConversationId = async (conversationId) => {
  return await Message.find({ conversationId })
    .populate('sender', 'name email userId')
    .populate('receiver', 'name email userId')
    .populate('product', PRODUCT_CARD_FIELDS)
    .sort({ createdAt: 1 });
};

// Exporting once at the bottom to avoid duplicates
export { createMessage, getMessagesByConversationId, PRODUCT_CARD_FIELDS };
