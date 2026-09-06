import API from './authApi';

export const fetchConversations = () => API.get('/chat/conversations');
export const fetchConversationMessages = (conversationId) => API.get(`/chat/messages/${conversationId}`);
export const sendChatMessage = (receiverUserId, text) => API.post('/chat/send', { receiverUserId, text });
