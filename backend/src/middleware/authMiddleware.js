import jwt from 'jsonwebtoken';
import { getFirebaseAuth } from '../config/firebase.js';
import { authRepository } from '../repositories/authRepository.js';

function attachUser(req, payload) {
  req.user = {
    id: payload.userId,
    userId: payload.userId,
    email: payload.email,
    role: payload.role
  };
}

function extractBearer(req) {
  const header = req.headers.authorization || '';
  if (header.startsWith('Bearer ')) return header.slice(7).trim();
  return null;
}

export const protect = async (req, res, next) => {
  const token = extractBearer(req) || req.cookies?.accessToken;

  if (!token) {
    return res.status(401).json({ message: 'Not authorized' });
  }

  try {
    // App JWT (issued after login)
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    attachUser(req, decoded);
    return next();
  } catch {
    // Optional: accept Firebase ID tokens when WEB flow is enabled
    try {
      const auth = getFirebaseAuth();
      if (!auth) {
        return res.status(401).json({ message: 'Invalid token' });
      }

      const decodedFb = await auth.verifyIdToken(token);
      const user =
        (await authRepository.findByFirebaseUid(decodedFb.uid)) ||
        (await authRepository.findByEmail(decodedFb.email));

      if (!user) {
        return res.status(401).json({ message: 'User not found' });
      }

      if (user.status === 'suspended') {
        return res.status(403).json({ message: 'Account suspended' });
      }

      attachUser(req, {
        userId: user.userId,
        email: user.email,
        role: user.role
      });
      return next();
    } catch {
      return res.status(401).json({ message: 'Invalid token' });
    }
  }
};

export const authorizeRoles = (...roles) => {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return res.status(403).json({
        error: `User role ${req.user?.role} is not authorized to access this route`
      });
    }
    next();
  };
};
