import dotenv from 'dotenv';
dotenv.config();
import path from 'path';
import { fileURLToPath } from 'url';
import express from 'express';
import http from 'http';
import { notFoundHandler, errorHandler } from './middleware/errorMiddleware.js';
import routes from './routes/index.js';
import mongoose from 'mongoose';
import cookieParser from 'cookie-parser';
import cors from 'cors';
import { initSockets } from './sockets/socket.js';
import chatRoutes from './routes/chatRoutes.js';
import { initFirebase } from './config/firebase.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const port = process.env.PORT || 3000;

initFirebase();

// ====================== CORS (PUT FIRST) ======================
// Vite falls back to 5174, 5175, ... when its default port is taken, so pinning a
// single origin here silently breaks the app with an opaque "cannot reach server".
// Allow any loopback origin in development; use CORS_ORIGINS in production.
const allowedOrigins = (process.env.CORS_ORIGINS || '')
  .split(',')
  .map((o) => o.trim())
  .filter(Boolean);

const isLoopbackOrigin = (origin) =>
  /^https?:\/\/(localhost|127\.0\.0\.1|\[::1\])(:\d+)?$/.test(origin);

export const corsOrigin = (origin, callback) => {
  // Same-origin / curl / mobile apps send no Origin header.
  if (!origin) return callback(null, true);
  if (allowedOrigins.includes(origin)) return callback(null, true);
  if (process.env.NODE_ENV !== 'production' && isLoopbackOrigin(origin)) {
    return callback(null, true);
  }
  console.warn('[cors] blocked origin:', origin);
  return callback(new Error(`Origin ${origin} is not allowed by CORS`));
};

app.use(cors({
  origin: corsOrigin,
  credentials: true
}));
app.get('/test', (req, res) => res.send('Server is alive!'));

// ====================== MIDDLEWARE ======================
app.use(express.json());
app.use(cookieParser());
// Only the public media folder is served statically. Credentials live in
// uploads/private and are reachable only through the authenticated /api/files
// route — serving the whole uploads tree made every document world-readable.
app.use('/uploads/media', express.static(path.join(__dirname, 'uploads/media')));

// ====================== ROUTES ======================
app.use('/api', routes);
app.use('/api/chat', chatRoutes);

// ====================== ERRORS ======================
// Must sit after every route: Express matches these only once nothing else has.
app.use('/api', notFoundHandler);
app.use(errorHandler);

// ====================== MONGO DB ======================
mongoose.connect(process.env.MONGODB_URI)
  .then(() => console.log('🚀 MongoDB connected successfully'))
  .catch(err => console.error('❌ MongoDB connection error:', err));

// ====================== SERVER & SOCKETS ======================
const server = http.createServer(app);

// Initialize WebSocket
initSockets(server);

server.listen(port, () => {
  console.log("✅ Server is running");
  console.log("ENV CHECK:", {
    PORT: process.env.PORT,
    JWT: process.env.JWT_SECRET ? 'SET' : 'NOT SET',
    MONGO: process.env.MONGODB_URI ? 'SET' : 'NOT SET',
    FIREBASE: process.env.FIREBASE_CREDENTIALS_PATH || 'default path'
  });
});
