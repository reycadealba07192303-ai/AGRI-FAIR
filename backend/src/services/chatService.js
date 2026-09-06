import { findConversation, createConversation, updateLastMessage, getUserConversations, findConversationById } from '../repositories/conversationRepository.js';
import { createMessage, getMessagesByConversationId } from '../repositories/messageRepository.js';
import User from '../models/User.js';
import * as notificationRepo from '../repositories/notificationRepository.js';

const allowedRoles = ['superadmin', 'seller', 'buyer'];

// 1. Fixed: Cast to Number to match numeric userId in User Schema
const validateParticipantsByUserId = async (senderUserId, receiverUserId) => {
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

// 3. Main Export for Sockets
export const sendMessageByUserId = async (senderUserId, receiverUserId, text, mediaUrl) => {
  const { conversation, sender, receiver } = await getOrCreateConversationByUserId(senderUserId, receiverUserId);
  
  // Save using MongoDB _ids
  const message = await createMessage(conversation._id, sender._id, receiver._id, text, mediaUrl);
  await updateLastMessage(conversation._id, message._id);

  await notificationRepo.createNotification({
    userId: receiver.userId,
    type: 'MESSAGE',
    title: `New message from ${sender.name}`,
    body: text ? text.slice(0, 120) : 'Sent an image',
    link: `/client?tab=Messages&conversation=${conversation._id}`,
  });

  return await message.populate([
    { path: 'sender', select: 'name email role userId' },
    { path: 'receiver', select: 'name email role userId' }
  ]);
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

  return await getMessagesByConversationId(conversationId);
};

export const fetchUserConversationsByMongoId = async (mongoUserId) => {
  return await getUserConversations(mongoUserId);
};

// Exporting all together
export { 
  validateParticipantsByUserId, 
  getOrCreateConversationByUserId 
};