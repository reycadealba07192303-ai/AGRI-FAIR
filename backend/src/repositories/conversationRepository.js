import { Conversation } from '../models/Chat.js';

const findConversation = async (participantIds) => {
  // Use $all to ensure both specific MongoDB _ids are present
  return await Conversation.findOne({
    participants: { $all: participantIds, $size: participantIds.length }
  }).populate('participants', 'name email role userId');
};

const createConversation = async (participantIds) => {
  const newConversation = new Conversation({ participants: participantIds });
  return await newConversation.save();
};

const updateLastMessage = async (conversationId, messageId) => {
  return await Conversation.findByIdAndUpdate(
    conversationId, 
    { lastMessage: messageId }, 
    { new: true }
  );
};

const findConversationById = async (conversationId) => {
  return await Conversation.findById(conversationId);
};

const getUserConversations = async (mongoUserId) => {
  // Use the MongoDB _id here, as the Conversation schema stores ObjectIds
  return await Conversation.find({ participants: mongoUserId })
    .populate('participants', 'name email role userId')
    .populate('lastMessage')
    .sort({ updatedAt: -1 });
};

export { findConversation, createConversation, updateLastMessage, getUserConversations, findConversationById };