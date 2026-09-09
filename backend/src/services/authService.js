import jwt from 'jsonwebtoken';
import { authRepository } from '../repositories/authRepository.js';
import { toNameKey } from '../models/User.js';
import { getFirebaseAuth } from '../config/firebase.js';
import LoginSession from '../models/LoginSession.js';
import { emailVerificationService } from './passwordResetService.js';

function signToken(user) {
  const secret = process.env.JWT_SECRET;
  if (!secret) throw new Error('JWT_SECRET is not configured');

  return jwt.sign(
    {
      userId: user.userId,
      email: user.email,
      role: user.role
    },
    secret,
    { expiresIn: process.env.JWT_EXPIRES_IN || '1d' }
  );
}

function toUserResponse(user, extras = {}) {
  return {
    id: user.userId,

    // The same number under the name the rest of the API uses for it.
    //
    // `/user/me` returns the raw document, which calls it `userId`, so a client
    // that reads `user.userId` works after fetching the profile and silently
    // gets undefined after logging in. That undefined is how a seller ended up
    // being shown as their own chat partner: "the participant who is not me"
    // matched nobody, so the first one - themselves - was picked.
    userId: user.userId,
    name: user.name,
    email: user.email,
    role: user.role,
    status: user.status,
    emailVerified: Boolean(user.emailVerified),
    firebaseUid: user.firebaseUid || null,
    ...extras
  };
}

function getAppUrl() {
  return (process.env.APP_URL || 'http://localhost:5173').replace(/\/$/, '');
}

function getFirebaseApiKey() {
  return process.env.FIREBASE_WEB_API_KEY || '';
}

/** Emails are stored lower-cased and trimmed - normalise before every lookup. */
function normalizeEmail(email) {
  return typeof email === 'string' ? email.trim().toLowerCase() : '';
}

/** Turns a raw Firebase identitytoolkit error code into something a user can act on. */
function describeFirebaseError(code = '') {
  if (code.includes('TOO_MANY_ATTEMPTS_TRY_LATER')) {
    return 'Too many failed attempts. Please wait a few minutes and try again.';
  }
  if (code.includes('USER_DISABLED')) {
    return 'This account has been disabled. Contact a Super Admin.';
  }
  if (code.includes('OPERATION_NOT_ALLOWED')) {
    return 'Email/password sign-in is disabled in Firebase. Enable it under Authentication -> Sign-in method.';
  }
  if (code.includes('API_KEY') || code.includes('PERMISSION_DENIED')) {
    return 'FIREBASE_WEB_API_KEY in backend/.env is invalid. Copy it from Firebase Console -> Project settings -> General.';
  }
  return code || 'Firebase sign-in failed';
}

async function signInWithFirebaseRest(email, password) {
  const apiKey = getFirebaseApiKey();
  if (!apiKey) return null;

  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email,
        password,
        returnSecureToken: true
      })
    }
  );

  const data = await response.json();
  if (!response.ok) {
    const code = data?.error?.message || 'FIREBASE_AUTH_FAILED';
    if (
      code.includes('INVALID_PASSWORD') ||
      code.includes('EMAIL_NOT_FOUND') ||
      code.includes('INVALID_LOGIN_CREDENTIALS')
    ) {
      return null;
    }
    throw new Error(describeFirebaseError(code));
  }

  return data;
}

/**
 * Firebase is the source of truth for passwords, but a dropped connection to
 * Google must not take the whole login down - fall back to the local hash.
 */
async function trySignInWithFirebase(email, password) {
  try {
    return { session: await signInWithFirebaseRest(email, password), reachable: true };
  } catch (err) {
    if (err instanceof TypeError) {
      // fetch() network failure - Firebase unreachable, not a bad password
      console.warn('Firebase sign-in unreachable, falling back to local password:', err.message);
      return { session: null, reachable: false };
    }
    throw err;
  }
}

/**
 * Sends Firebase's built-in verification email to the user's inbox (e.g. Gmail).
 * Flow: customToken → idToken → sendOobCode(VERIFY_EMAIL)
 */
async function sendFirebaseVerificationEmail(uid, email) {
  const auth = getFirebaseAuth();
  const apiKey = getFirebaseApiKey();

  if (!auth) {
    throw new Error('Firebase Auth is not configured');
  }

  if (!apiKey) {
    throw new Error(
      'FIREBASE_WEB_API_KEY is missing. Add your Firebase Web API key to backend/.env so verification emails can be sent.'
    );
  }

  const continueUrl = `${getAppUrl()}/login?verified=1`;
  const customToken = await auth.createCustomToken(uid);

  const signInRes = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=${apiKey}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        token: customToken,
        returnSecureToken: true
      })
    }
  );
  const signInData = await signInRes.json();
  if (!signInRes.ok) {
    throw new Error(signInData?.error?.message || 'Failed to prepare verification email');
  }

  const oobRes = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=${apiKey}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        requestType: 'VERIFY_EMAIL',
        idToken: signInData.idToken,
        continueUrl
      })
    }
  );
  const oobData = await oobRes.json();
  if (!oobRes.ok) {
    throw new Error(oobData?.error?.message || 'Failed to send verification email');
  }

  console.log(`📧 Verification email sent to ${email || oobData.email}`);
  return true;
}

async function syncEmailVerifiedFromFirebase(user) {
  const auth = getFirebaseAuth();
  if (!auth || !user.firebaseUid) return user;

  try {
    const fbUser = await auth.getUser(user.firebaseUid);
    if (Boolean(fbUser.emailVerified) !== Boolean(user.emailVerified)) {
      user.emailVerified = fbUser.emailVerified;
      await user.save();
    }
  } catch (err) {
    console.warn('Could not sync emailVerified from Firebase:', err.message);
  }

  return user;
}

export const authService = {
  async register({ name, email, password, role: requestedRole }, requestMeta = {}) {
    const cleanName = typeof name === 'string' ? name.trim() : '';
    const cleanEmail = normalizeEmail(email);

    if (!cleanName || !cleanEmail || !password) {
      throw new Error('Name, email and password are required');
    }

    if (password.length < 6) {
      throw new Error('Password must be at least 6 characters long');
    }

    // Buyers sign themselves up from the mobile app and start shopping right
    // away. Only sellers wait for Super Admin approval — a buyer has nothing to
    // approve, and leaving 'buyer' off this list silently turned every mobile
    // signup into a pending seller account.
    const allowedSelfRoles = ['buyer', 'seller', 'superadmin'];
    const role = allowedSelfRoles.includes(requestedRole) ? requestedRole : 'seller';
    const status = role === 'seller' ? 'pending' : 'active';

    const existingUser = await authRepository.findByEmail(cleanEmail);
    if (existingUser) {
      throw new Error('User with this email already exists');
    }

    // Checked before the Firebase user is created, so a rejected signup does
    // not leave an orphan account behind in Firebase.
    const takenName = await authRepository.findByNameKey(toNameKey(cleanName));
    if (takenName) {
      throw new Error('That name is already taken. Please choose another one.');
    }

    const auth = getFirebaseAuth();
    if (!auth) {
      throw new Error(
        'Authentication service unavailable: Firebase Admin could not start. Check FIREBASE_CREDENTIALS_PATH in backend/.env.'
      );
    }

    if (!getFirebaseApiKey()) {
      throw new Error(
        'Email verification is not configured. Add FIREBASE_WEB_API_KEY to backend/.env (Firebase Console -> Project settings -> General -> Web API Key).'
      );
    }

    let firebaseUid = null;
    let adoptedOrphan = false;

    try {
      const fbUser = await auth.createUser({
        email: cleanEmail,
        password,
        displayName: cleanName,
        emailVerified: false
      });
      firebaseUid = fbUser.uid;
    } catch (err) {
      if (err.code === 'auth/email-already-exists') {
        // No AgriFair record exists (checked above), so this is a leftover Firebase
        // account from a half-finished signup. Reclaim it instead of dead-ending
        // the user, who could otherwise neither register nor sign in.
        const orphan = await auth.getUserByEmail(cleanEmail).catch(() => null);
        if (!orphan) {
          throw new Error('User with this email already exists');
        }
        await auth.updateUser(orphan.uid, { password, displayName: cleanName });
        firebaseUid = orphan.uid;
        adoptedOrphan = true;
        console.warn('Reclaimed orphaned Firebase account for', cleanEmail);
      } else if (err.code === 'auth/invalid-password') {
        throw new Error('Password must be at least 6 characters long');
      } else if (err.code === 'auth/invalid-email') {
        throw new Error('Please enter a valid email address');
      } else {
        console.error('Firebase createUser failed:', err.code, err.message);
        throw new Error(`Unable to create authentication account: ${err.message}`);
      }
    }

    let newUser;
    try {
      newUser = await authRepository.createUser({
        name: cleanName,
        email: cleanEmail,
        password,
        role,
        status,
        emailVerified: false,
        firebaseUid
      });
    } catch (err) {
      // Roll back the Firebase user if the Mongo insert fails - but never delete
      // an account we merely adopted, it may predate this request.
      if (!adoptedOrphan) {
        try {
          await auth.deleteUser(firebaseUid);
        } catch {
          /* ignore */
        }
      }
      if (err.code === 11000) {
        throw new Error('User with this email already exists');
      }
      console.error('Mongo createUser failed:', err.message);
      throw new Error(err.message || 'Could not save your account. Please try again.');
    }

    // The mobile app collects six digits; the web opens a link. Send whichever
    // the caller can actually complete — a link is a dead end on a phone, and a
    // code is a dead end on a web page with no box to type it into.
    const wantsOtp = requestMeta.client === 'mobile';

    try {
      if (wantsOtp) {
        await emailVerificationService.sendSignupOtp(newUser);
      } else {
        await sendFirebaseVerificationEmail(firebaseUid, cleanEmail);
      }
    } catch (err) {
      console.error('Verification email failed:', err.message);
      // Account exists — ask user to resend from the UI
      return {
        ...toUserResponse(newUser),
        verificationMethod: wantsOtp ? 'otp' : 'link',
        verificationEmailSent: false,
        verificationError: err.message
      };
    }

    return {
      ...toUserResponse(newUser),
      verificationMethod: wantsOtp ? 'otp' : 'link',
      verificationEmailSent: true
    };
  },

  async resendVerification({ email }, requestMeta = {}) {
    const cleanEmail = normalizeEmail(email);
    if (!cleanEmail) throw new Error('Email is required');

    let user = await authRepository.findByEmail(cleanEmail);
    if (!user?.firebaseUid) {
      // Do not leak whether the email exists
      return { sent: true };
    }

    user = await syncEmailVerifiedFromFirebase(user);
    if (user.emailVerified) {
      throw new Error('This email is already verified. You can sign in.');
    }

    if (requestMeta.client === 'mobile') {
      await emailVerificationService.sendSignupOtp(user);
      return { sent: true, verificationMethod: 'otp' };
    }

    await sendFirebaseVerificationEmail(user.firebaseUid, user.email);
    return { sent: true, verificationMethod: 'link' };
  },

  async login({ email, password }, requestMeta = {}) {
    const client = requestMeta.client === 'mobile' ? 'mobile' : 'web';
    const cleanEmail = normalizeEmail(email);

    if (!cleanEmail || !password) {
      throw new Error('Email and password are required');
    }

    let user = await authRepository.findByEmail(cleanEmail);

    // An account somebody else created and its owner has not finished. The
    // stored password is random and nobody knows it, so any attempt would come
    // back "Invalid credentials" - true, and useless. Say what to do instead.
    if (user && user.passwordSet === false) {
      const err = new Error(
        'This account has not been set up yet. Use the code emailed to you to '
        + 'choose a password.'
      );
      err.code = 'ACCOUNT_NOT_ACTIVATED';
      err.status = 403;
      throw err;
    }

    let firebaseIdToken = null;

    const { session: fbSession, reachable } = await trySignInWithFirebase(cleanEmail, password);

    if (fbSession?.localId) {
      firebaseIdToken = fbSession.idToken;
      if (!user) {
        throw new Error('Account exists in Firebase but not in AgriFair. Contact a superadmin.');
      }
      if (!user.firebaseUid) {
        user.firebaseUid = fbSession.localId;
        await user.save();
      }
    } else {
      // Either the Firebase credentials were rejected or Firebase was unreachable.
      // Local accounts seeded without a Firebase user (e.g. the superadmin) still
      // authenticate against the stored hash.
      if (!user) throw new Error('Invalid credentials');
      const isMatch = await user.comparePassword(password);
      if (!isMatch) {
        throw new Error(
          reachable
            ? 'Invalid credentials'
            : 'Could not reach the authentication service. Check your internet connection and try again.'
        );
      }
    }

    user = await syncEmailVerifiedFromFirebase(user);

    // Nobody signs in on an unconfirmed address - buyers included. An account
    // whose email was never proven can be someone else's address typed by
    // mistake, and it is the address every reset code is later sent to.
    if (user.firebaseUid && !user.emailVerified) {
      const err = new Error(
        client === 'mobile'
          ? 'Please verify your email first. Enter the 6-digit code we sent you.'
          : 'Please verify your email before signing in. Check your Gmail inbox for the AgriFair verification link.'
      );
      // A flag the client can act on. Matching the sentence above would break
      // the moment the wording changes.
      err.code = 'EMAIL_NOT_VERIFIED';
      err.email = user.email;
      throw err;
    }

    if (user.status === 'suspended') {
      throw new Error('Your account has been suspended');
    }

    if (user.role === 'seller' && user.status === 'pending') {
      throw new Error('Your seller account is pending Super Admin approval.');
    }

    // Buyers belong in the mobile app; the web portal is for sellers and super
    // admins. This used to reject buyers everywhere, which left them unable to
    // sign in at all once the app existed.
    if (user.role === 'buyer' && client !== 'mobile') {
      throw new Error('Buyer accounts use the AgriFair mobile app. Web access is for sellers and super admins.');
    }

    // Audit bookkeeping must never block a valid sign-in.
    try {
      await authRepository.updateLastLogin(user.userId);
      await LoginSession.create({
        userId: user._id,
        ipAddress: requestMeta.ipAddress || '',
        userAgent: requestMeta.userAgent || '',
      });
    } catch (err) {
      console.error('Could not record login session:', err.message);
    }

    const token = signToken(user);

    return {
      token,
      firebaseIdToken,
      user: toUserResponse(user)
    };
  },

  getAuthCookieOptions(maxAgeMs = 24 * 60 * 60 * 1000) {
    return {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'lax',
      maxAge: maxAgeMs,
      path: '/'
    };
  },

  getLogoutCookieOptions() {
    return {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'lax',
      maxAge: 0,
      path: '/'
    };
  }
};
