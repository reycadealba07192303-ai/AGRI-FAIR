import { findConversation, createConversation, updateLastMessage, getUserConversations, findConversationById } from '../repositories/conversationRepository.js';
import { createMessage, getMessagesByConversationId, PRODUCT_CARD_FIELDS } from '../repositories/messageRepository.js';
import User from '../models/User.js';
import Product from '../models/Product.js';
import { Message } from '../models/Chat.js';
import * as notificationRepo from '../repositories/notificationRepository.js';

const allowedRoles = ['superadmin', 'seller', 'buyer', 'rider'];

// 1. Fixed: Cast to Number to match numeric userId in User Schema
const validateParticipantsByUserId = async (senderUserId, receiverUserId) => {
  // Nobody messages themselves. This is not a nicety: a client that cannot
  // work out who the other person is falls back to the first participant -
  // itself - and every reply then goes to the sender. Refusing here turns a
  // silent, confusing wrong into a visible error.
  if (Number(senderUserId) === Number(receiverUserId)) {
    throw new Error('You cannot message yourself.');
  }

  const sender = await User.findOne({ userId: Number(senderUserId) });
  const receiver = await User.findOne({ userId: Number(receiverUserId) });

  if (!sender || !receiver) {
    throw new Error(`Sender (${senderUserId}) or receiver (${receiverUserId}) not found.`);
  }
  if (!allowedRoles.includes(sender.role) || !allowedRoles.includes(receiver.role)) {
    throw new Error('Unauthorized role for chat participants.');
  }
  return { sender, receiver };
};

// 2. Fixed: This was likely declared twice in your file causing the crash
const getOrCreateConversationByUserId = async (senderUserId, receiverUserId) => {
  const { sender, receiver } = await validateParticipantsByUserId(senderUserId, receiverUserId);
  
  // Use MongoDB _ids for the conversation relationships
  const participantIds = [sender._id, receiver._id].sort(); 
  let conversation = await findConversation(participantIds);

  if (!conversation) {
    conversation = await createConversation(participantIds);
  }
  return { conversation, sender, receiver };
};

/** What a notification says a message was, when the message is not words. */
const summarise = (text, kind, productName) => {
  if (text) return text.slice(0, 120);
  if (kind === 'product') return `Shared ${productName || 'a product'}`;
  return 'Sent an image';
};

// 3. Main Export for Sockets
export const sendMessageByUserId = async (senderUserId, receiverUserId, text, mediaUrl, options = {}) => {
  const { conversation, sender, receiver } = await getOrCreateConversationByUserId(senderUserId, receiverUserId);

  // A product message points at a real listing or it is not one. Checking here
  // rather than trusting the id keeps a broken card out of the thread, where
  // it would sit forever with nothing behind it.
  let product = null;
  if (options.productId) {
    product = await Product.findById(options.productId).select('name');
    if (!product) throw new Error('That product no longer exists.');
  }

  const kind = product ? 'product' : 'text';

  // Save using MongoDB _ids
  const message = await createMessage(
    conversation._id,
    sender._id,
    receiver._id,
    text,
    mediaUrl,
    { kind, ...(product ? { product: product._id } : {}) },
  );
  await updateLastMessage(conversation._id, message._id);

  await notificationRepo.createNotification({
    userId: receiver.userId,
    type: 'MESSAGE',
    title: `New message from ${sender.name}`,
    body: summarise(text, kind, product?.name),
    link: `/client?tab=Messages&conversation=${conversation._id}`,
  });

  return await message.populate([
    { path: 'sender', select: 'name email role userId' },
    { path: 'receiver', select: 'name email role userId' },
    { path: 'product', select: PRODUCT_CARD_FIELDS },
  ]);
};

/**
 * Writes an order's own words into the buyer and seller's thread.
 *
 * Placed, confirmed, shipped - the buyer already asks the seller about these
 * in chat, so the answer belongs there rather than only in a notification that
 * scrolls away. It is deliberately quiet: no notification of its own (the
 * order flow raises those already) and never unread, because nobody is being
 * asked anything.
 *
 * Failure never propagates. An order must not fail to be placed because a
 * courtesy message could not be written.
 */
export const postOrderSystemMessage = async ({ sellerUserId, buyerUserId, text }) => {
  try {
    const { conversation, sender, receiver } = await getOrCreateConversationByUserId(
      sellerUserId,
      buyerUserId,
    );

    const message = await createMessage(
      conversation._id,
      sender._id,
      receiver._id,
      text,
      undefined,
      { kind: 'system', isRead: true },
    );
    await updateLastMessage(conversation._id, message._id);
    return message;
  } catch (err) {
    console.error('[chat] could not post the order update:', err.message);
    return null;
  }
};

export const fetchMessagesByConversationId = async (conversationId, requesterUserId) => {
  const conversation = await findConversationById(conversationId);
  if (!conversation) {
    throw new Error('Conversation not found.');
  }

  const requester = await User.findOne({ userId: requesterUserId });
  const isParticipant = requester && conversation.participants.some((p) => p.equals(requester._id));
  if (!isParticipant) {
    throw new Error('Not authorized to view this conversation.');
  }

  const messages = await getMessagesByConversationId(conversationId);

  // Opening a conversation is reading it. Without this the unread badge never
  // clears and stops meaning anything.
  await Message.updateMany(
    { conversationId, receiver: requester._id, isRead: false, kind: { $ne: 'system' } },
    { isRead: true },
  );

  return messages;
};

export const fetchUserConversationsByMongoId = async (mongoUserId) => {
  const conversations = await getUserConversations(mongoUserId);

  // One grouped query for the whole list rather than a count per row - a
  // twenty-conversation inbox would otherwise be twenty-one round trips.
  const unreadRows = await Message.aggregate([
    // System messages are excluded: an order moving to "shipped" is news, not
    // a question, and must not put a red badge on anybody's inbox.
    { $match: { receiver: mongoUserId, isRead: false, kind: { $ne: 'system' } } },
    { $group: { _id: '$conversationId', count: { $sum: 1 } } },
  ]);

  const unreadByConversation = new Map(
    unreadRows.map((row) => [String(row._id), row.count]),
  );

  return conversations.map((conversation) => ({
    ...conversation.toObject(),
    unreadCount: unreadByConversation.get(String(conversation._id)) || 0,
  }));
};

// Exporting all together
export { 
  validateParticipantsByUserId, 
  getOrCreateConversationByUserId 
};