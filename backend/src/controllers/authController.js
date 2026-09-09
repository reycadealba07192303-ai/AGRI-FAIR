import { authService } from '../services/authService.js';
import { passwordResetService, emailVerificationService } from '../services/passwordResetService.js';
import { getIo } from '../sockets/socket.js';

/** Never let the client fall back to a bare "Login failed" - always send real text. */
function fail(res, status, err, fallback) {
  console.error(`[auth] ${fallback}:`, err);
  return res.status(status).json({
    success: false,
    message: err?.message || fallback,
    // Only set for failures a client should handle rather than just display -
    // an unverified email sends the app to the code screen, not to an alert.
    ...(err?.code ? { code: err.code } : {}),
    ...(err?.email ? { email: err.email } : {})
  });
}

export const register = async (req, res) => {
  try {
    const user = await authService.register(req.body, { client: req.headers['x-client'] });

    res.status(201).json({
      success: true,
      message: user.verificationEmailSent
        ? 'Account created. Please check your Gmail to verify your email.'
        : 'Account created, but the verification email could not be sent. Use Resend.',
      user
    });
  } catch (err) {
    // A taken name is the same class of failure as a taken email: the request
    // conflicts with something already there, not malformed input.
    const isDuplicate = /already (exists|taken)/i.test(err?.message || '');
    return fail(res, isDuplicate ? 409 : 400, err, 'Registration failed');
  }
};

export const resendVerification = async (req, res) => {
  try {
    const result = await authService.resendVerification(req.body, { client: req.headers['x-client'] });
    return res.status(200).json({
      success: true,
      message: 'If that account exists, a verification email was sent.',
      ...result
    });
  } catch (err) {
    return fail(res, 400, err, 'Could not resend verification email');
  }
};

export const login = async (req, res) => {
  let result;

  try {
    result = await authService.login(req.body, {
      ipAddress: req.ip,
      userAgent: req.headers['user-agent'],
      client: req.headers['x-client'],
    });
  } catch (err) {
    return fail(res, 401, err, 'Login failed');
  }

  res.cookie('accessToken', result.token, authService.getAuthCookieOptions());

  // Broadcasting is best-effort - a socket problem must not reject a valid login.
  try {
    const io = getIo();
    if (io) {
      io.emit('new-login', {
        userId: result.user.id,
        name: result.user.name,
        email: result.user.email,
        role: result.user.role,
        timestamp: new Date().toISOString()
      });
    }
  } catch (err) {
    console.warn('[auth] could not broadcast new-login:', err.message);
  }

  return res.status(200).json({
    success: true,
    message: 'Login successful',
    token: result.token,
    firebaseIdToken: result.firebaseIdToken || null,
    user: result.user
  });
};

export const logout = (req, res) => {
  res.cookie('accessToken', '', authService.getLogoutCookieOptions());

  res.json({
    success: true,
    message: 'Logged out successfully'
  });
};

export const forgotPassword = async (req, res) => {
  try {
    await passwordResetService.requestOtp(req.body);
  } catch (err) {
    // Config and rate-limit problems are real failures the caller must see.
    // A missing account is not - that answer would leak who is registered.
    return fail(res, 400, err, 'Could not send the reset code');
  }

  return res.status(200).json({
    success: true,
    message: 'If that account exists, a 6-digit code is on its way to that email.'
  });
};

export const verifyResetOtp = async (req, res) => {
  try {
    const result = await passwordResetService.verifyOtp(req.body);
    return res.status(200).json({
      success: true,
      message: 'Code accepted. You can set a new password now.',
      ...result
    });
  } catch (err) {
    return fail(res, 400, err, 'Could not verify that code');
  }
};

export const resetPassword = async (req, res) => {
  try {
    const result = await passwordResetService.resetPassword(req.body);
    return res.status(200).json({ success: true, ...result });
  } catch (err) {
    return fail(res, 400, err, 'Could not reset the password');
  }
};

export const verifyEmailOtp = async (req, res) => {
  try {
    const result = await emailVerificationService.verifySignupOtp(req.body);
    return res.status(200).json({ success: true, ...result });
  } catch (err) {
    return fail(res, 400, err, 'Could not verify that code');
  }
};

/**
 * Step one for a delivery person: confirms the account exists and emails the
 * code, so the app knows whether to offer the create-password step.
 */
export const startDeliverySetup = async (req, res) => {
  try {
    const result = await emailVerificationService.startDeliverySetup(req.body);
    return res.status(200).json({ success: true, ...result });
  } catch (err) {
    return fail(res, 400, err, 'Could not find that delivery account');
  }
};

/**
 * Finishes an account created by somebody else - a rider's, made by their
 * seller. One call: the code proves the address, the password is set.
 */
export const activateAccount = async (req, res) => {
  try {
    const result = await emailVerificationService.activateAccount(req.body);
    return res.status(200).json({ success: true, ...result });
  } catch (err) {
    return fail(res, 400, err, 'Could not set up this account');
  }
};
