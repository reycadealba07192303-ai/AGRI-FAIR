import { Message } from '../models/Chat.js';

const createMessage = async (conversationId, senderId, receiverId, text, mediaUrl) => {
  return await Message.create({
    conversationId,
    sender: senderId,
    receiver: receiverId,
    text,
    mediaUrl
  });
};

const getMessagesByConversationId = async (conversationId) => {
  return await Message.find({ conversationId })
    .populate('sender', 'name email userId')
    .populate('receiver', 'name email userId')
    .sort({ createdAt: 1 });
};

// Exporting once at the bottom to avoid duplicates
export { createMessage, getMessagesByConversationId };