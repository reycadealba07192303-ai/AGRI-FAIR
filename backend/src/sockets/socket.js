// sockets/socket.js
import { Server } from 'socket.io';
import { sendMessageByUserId } from '../services/chatService.js';

let io;

export const initSockets = (httpServer) => {
  io = new Server(httpServer, {
    cors: {
      // Mirrors the HTTP CORS policy - see corsOrigin in index.js
      origin: (origin, callback) => {
        if (!origin) return callback(null, true);
        const loopback = /^https?:\/\/(localhost|127\.0\.0\.1|\[::1\])(:\d+)?$/.test(origin);
        const allowed = (process.env.CORS_ORIGINS || '')
          .split(',')
          .map((o) => o.trim())
          .filter(Boolean);
        if (allowed.includes(origin)) return callback(null, true);
        if (process.env.NODE_ENV !== 'production' && loopback) return callback(null, true);
        return callback(new Error(`Origin ${origin} is not allowed by CORS`));
      },
      methods: ['GET', 'POST'],
      credentials: true
    }
  });

  io.on('connection', (socket) => {
    // Check if the connection is an admin (you can pass this via query params or auth)
    const isAdmin = socket.handshake.query.role === 'seller' || socket.handshake.query.role === 'superadmin';
    
    if (isAdmin) {
      console.log('📡 Staff connected:', socket.id);
      socket.join('admin_room');
    } else {
      console.log('👤 User connected:', socket.id);
    }

    // --- SHARED EVENTS ---

    socket.on('join', (userId) => {
      if (userId) {
        const roomName = String(userId);
        socket.join(roomName);
        console.log(`User ${roomName} joined their room.`);
      }
    });

    socket.on('privateMessage', async (data) => {
      try {
        const { senderId, receiverId, text, mediaUrl } = data;

        if (!senderId || !receiverId) {
          throw new Error('Sender numeric userId and Receiver numeric userId are required.');
        }

        // 1. Save to DB
        const message = await sendMessageByUserId(senderId, receiverId, text, mediaUrl);

        // 2. Broadcast to Participant Rooms
        // Use io (the global instance) to ensure it reaches all connected clients
        const senderRoom = String(senderId);
        const receiverRoom = String(receiverId);

        io.to(senderRoom).emit('newMessage', message);
        io.to(receiverRoom).emit('newMessage', message);

        // DEBUG LOGS - Check if there are actually people in these rooms
        const receiverRoomData = io.sockets.adapter.rooms.get(receiverRoom);
        console.log(`Room ${receiverRoom} size:`, receiverRoomData ? receiverRoomData.size : 0);

        io.to('admin_room').emit('admin:monitorMessage', message);

        console.log(`Message saved & sent: ${senderId} -> ${receiverId}`);
      } catch (error) {
        console.error('Socket Error:', error.message);
        socket.emit('messageError', { error: error.message });
      }
    });
    socket.on('disconnect', () => {
      console.log('Disconnected:', socket.id);
    });
  });

  return io;
};

export const getIo = () => {
  if (!io) throw new Error('Socket.IO not initialized!');
  return io;
};