import { Server } from 'socket.io';

let io;

export const initAdminSocket = (server) => {
  io = new Server(server, {
    cors: {
      origin: "http://localhost:5173",
      credentials: true
    }
  });

  io.on('connection', (socket) => {
    console.log('📡 Admin connected to WebSocket:', socket.id);
    
    socket.on('disconnect', () => {
      console.log('📡 Admin disconnected');
    });
  });

  return io;
};

export const getIO = () => {
  if (!io) {
    console.warn("⚠️ Socket.io not initialized!");
  }
  return io;
};