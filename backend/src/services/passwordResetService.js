import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';

import { authRepository } from '../repositories/authRepository.js';
import { updatePasswordByUserId } from '../repositories/userRepository.js';
import { getFirebaseAuth } from '../config/firebase.js';
import { otpService, normalizeEmail, OTP_PURPOSES } from './otpService.js';

const RESET_TOKEN_TTL = '15m';
const RESET_TOKEN_PURPOSE = 'password-reset';

function getJwtSecret() {
  const secret = process.env.JWT_SECRET;
  if (!secret) throw new Error('JWT_SECRET is not configured');
  return secret;
}

export const passwordResetService = {
  /**
   * Always resolves the same way whether or not the address exists. Telling a
   * caller "no such user" turns this endpoint into a way to harvest which
   * emails are registered.
   */
  async requestOtp({ email }) {
    const cleanEmail = normalizeEmail(email);
    if (!cleanEmail) throw new Error('Email is required');

    const user = await authRepository.findByEmail(cleanEmail);
    if (!user) return { sent: false };

    return otpService.issue({
      email: cleanEmail,
      purpose: OTP_PURPOSES.passwordReset,
      name: user.name,
    });
  },

  /**
   * Trades a correct code for a short-lived token. The password change itself
   * is a separate call, so the code never has to travel with the new password.
   */
  async verifyOtp({ email, code }) {
    const verified = await otpService.verify({
      email,
      code,
      purpose: OTP_PURPOSES.passwordReset,
    });

    const resetToken = jwt.sign(
      { purpose: RESET_TOKEN_PURPOSE, email: verified.email },
      getJwtSecret(),
      { expiresIn: RESET_TOKEN_TTL }
    );

    return { resetToken };
  },

  /**
   * Firebase holds the password the login actually checks; the local bcrypt
   * hash is only the offline fallback. Writing one and not the other leaves the
   * account signing in with the old password, so both move together here.
   */
  async resetPassword({ resetToken, newPassword }) {
    if (!resetToken || !newPassword) {
      throw new Error('Reset token and new password are required');
    }

    if (newPassword.length < 6) {
      throw new Error('Password must be at least 6 characters');
    }

    let payload;
    try {
      payload = jwt.verify(resetToken, getJwtSecret());
    } catch {
      throw new Error('This reset link has expired. Start again.');
    }

    if (payload.purpose !== RESET_TOKEN_PURPOSE) {
      throw new Error('Invalid reset token');
    }

    const user = await authRepository.findByEmail(payload.email);
    if (!user) throw new Error('User not found');

    if (user.firebaseUid) {
      const auth = getFirebaseAuth();
      if (!auth) {
        throw new Error('Firebase Auth is not configured, so the password cannot be changed right now.');
      }
      await auth.updateUser(user.firebaseUid, { password: newPassword });
    }

    const hashedPassword = await bcrypt.hash(newPassword, 12);
    await updatePasswordByUserId(user.userId, hashedPassword);

    return { message: 'Password updated. You can sign in with your new password.' };
  }
};

export const emailVerificationService = {
  /**
   * The phone has a 6-digit screen, the web has a link. Sending the code only
   * to the client that can actually collect it keeps sellers - who sign up on
   * the web and are blocked from signing in until verified - on the flow their
   * UI already supports.
   */
  async sendSignupOtp(user) {
    return otpService.issue({
      email: user.email,
      purpose: OTP_PURPOSES.signup,
      name: user.name,
    });
  },

  /**
   * Marks the address verified in both places. Firebase is what the login path
   * reads back through syncEmailVerifiedFromFirebase, so writing only the local
   * flag would be silently undone on the next sign-in.
   */
  async verifySignupOtp({ email, code }) {
    const verified = await otpService.verify({
      email,
      code,
      purpose: OTP_PURPOSES.signup,
    });

    const user = await authRepository.findByEmail(verified.email);
    if (!user) throw new Error('User not found');

    if (user.emailVerified) {
      return { message: 'This email is already verified. You can sign in.' };
    }

    if (user.firebaseUid) {
      const auth = getFirebaseAuth();
      if (!auth) {
        throw new Error('Firebase Auth is not configured, so the email cannot be verified right now.');
      }
      await auth.updateUser(user.firebaseUid, { emailVerified: true });
    }

    user.emailVerified = true;
    await user.save();

    return { message: 'Email verified. You can sign in now.' };
  }
};
