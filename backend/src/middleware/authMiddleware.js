import jwt from 'jsonwebtoken';
import { getFirebaseAuth } from '../config/firebase.js';
import { authRepository } from '../repositories/authRepository.js';
import User from '../models/User.js';

function attachUser(req, payload) {
  req.user = {
    id: payload.userId,
    userId: payload.userId,
    email: payload.email,
    role: payload.role
  };
}

/**
 * The same answer for a session whose account was suspended after sign-in.
 *
 * 401 rather than 403: the session is over, not merely short of permission,
 * and 401 is what already sends the app back to sign-in and the web to its
 * login page. The code lets either say why.
 */
function refuseSuspended(res) {
  return res.status(401).json({
    success: false,
    code: 'ACCOUNT_SUSPENDED',
    message: 'Your account has been suspended. Contact AgriFair support.',
  });
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

  let decoded = null;
  try {
    // App JWT (issued after login)
    decoded = jwt.verify(token, process.env.JWT_SECRET);
  } catch {
    decoded = null;
  }

  if (decoded) {
    // The token says who, not whether they are still allowed in. A day-long
    // token issued before a suspension would otherwise keep working until it
    // expired, so the account is read on every request.
    try {
      const account = await User.findOne({ userId: decoded.userId })
        .select('status')
        .lean();

      if (!account) {
        return res.status(401).json({ message: 'User not found' });
      }
      if (account.status === 'suspended') {
        return refuseSuspended(res);
      }
    } catch (err) {
      return next(err);
    }

    attachUser(req, decoded);
    return next();
  }

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
      return refuseSuspended(res);
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
