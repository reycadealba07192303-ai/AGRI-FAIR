import React, { useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import './AuthPages.css';
import logoImg from '../../assets/logo.png';
import {
  requestPasswordReset,
  verifyResetCode,
  resetPassword,
  getErrorMessage,
} from '../../services/authApi';

const RESEND_SECONDS = 60;

/**
 * Same flow as the phone: email -> 6-digit code -> new password. The code is
 * traded for a short-lived reset token first, so the code never travels with
 * the new password.
 */
export default function ForgotPasswordPage() {
  const navigate = useNavigate();

  const [step, setStep] = useState('email'); // email | code | password | done
  const [email, setEmail] = useState('');
  const [code, setCode] = useState('');
  const [resetToken, setResetToken] = useState('');
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');

  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [loading, setLoading] = useState(false);
  const [resendIn, setResendIn] = useState(0);

  useEffect(() => {
    if (resendIn <= 0) return undefined;
    const timer = setTimeout(() => setResendIn((s) => s - 1), 1000);
    return () => clearTimeout(timer);
  }, [resendIn]);

  /**
   * A request inside the cooldown still lands on the code step: the code sent
   * a moment ago works, so there is nothing for the person to fix.
   */
  const sendCode = async () => {
    setLoading(true);
    setError('');
    setNotice('');
    try {
      await requestPasswordReset(email.trim());
      setResendIn(RESEND_SECONDS);
      setStep('code');
      setNotice(`If ${email.trim()} has an AgriFair account, a 6-digit code is on its way. Check Spam too.`);
    } catch (err) {
      const data = err?.response?.data;
      if (data?.code === 'RESEND_COOLDOWN') {
        setResendIn(data.retryAfter || RESEND_SECONDS);
        setStep('code');
        setNotice(data.message);
      } else {
        setError(getErrorMessage(err, 'Could not send the reset code.'));
      }
    } finally {
      setLoading(false);
    }
  };

  const handleEmailSubmit = (e) => {
    e.preventDefault();
    if (!email.trim()) return setError('Email is required');
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())) return setError('Invalid email format');
    sendCode();
  };

  const handleCodeSubmit = async (e) => {
    e.preventDefault();
    if (!/^\d{6}$/.test(code.trim())) return setError('Enter the 6-digit code from the email');

    setLoading(true);
    setError('');
    try {
      const { data } = await verifyResetCode(email.trim(), code.trim());
      setResetToken(data.resetToken);
      setNotice('');
      setStep('password');
    } catch (err) {
      setError(getErrorMessage(err, 'Could not verify that code.'));
    } finally {
      setLoading(false);
    }
  };

  const handlePasswordSubmit = async (e) => {
    e.preventDefault();
    if (password.length < 6) return setError('Password must be at least 6 characters');
    if (password !== confirm) return setError('Passwords do not match');

    setLoading(true);
    setError('');
    try {
      await resetPassword(resetToken, password);
      setStep('done');
    } catch (err) {
      setError(getErrorMessage(err, 'Could not reset the password.'));
    } finally {
      setLoading(false);
    }
  };

  const startOver = () => {
    setStep('email');
    setCode('');
    setResetToken('');
    setPassword('');
    setConfirm('');
    setError('');
    setNotice('');
  };

  const submitLabel = (idle, busy) => (
    <>
      {loading ? busy : idle}
      {!loading && <span className="auth-v2-submit-arrow">-&gt;</span>}
    </>
  );

  return (
    <div className="auth-page-v2">
      <div className="auth-form-side">
        <Link to="/" className="auth-v2-brand" aria-label="Go to AgriFair home">
          <img src={logoImg} alt="AgriFair Logo" className="auth-v2-brand-img" />
          <span className="auth-v2-brand-text">AgriFair</span>
        </Link>

        <div className="auth-form-body">
          <div className="auth-v2-label">Password Recovery</div>

          {step === 'email' && (
            <>
              <h1 className="auth-v2-title">Forgot password?</h1>
              <p className="auth-v2-subtitle">
                Enter the email on your account and we will send you a 6-digit reset code.
              </p>

              <form className="auth-v2-form" onSubmit={handleEmailSubmit} noValidate>
                <div className={`auth-v2-field ${error ? 'has-error' : ''}`}>
                  <label htmlFor="email">Email address</label>
                  <div className="auth-v2-input-wrap">
                    <span className="auth-v2-input-icon">ID</span>
                    <input
                      id="email"
                      type="email"
                      name="email"
                      value={email}
                      onChange={(e) => {
                        setEmail(e.target.value);
                        setError('');
                      }}
                      placeholder="you@email.com"
                      autoComplete="email"
                      disabled={loading}
                    />
                  </div>
                  {error && <span className="auth-v2-error">{error}</span>}
                </div>

                <button type="submit" className="auth-v2-submit" disabled={loading}>
                  {submitLabel('Send Reset Code', 'Sending...')}
                </button>
              </form>
            </>
          )}

          {step === 'code' && (
            <>
              <h1 className="auth-v2-title">Check your email.</h1>
              <p className="auth-v2-subtitle">
                {notice || <>Enter the 6-digit code sent to <strong>{email}</strong>.</>}
              </p>

              <form className="auth-v2-form" onSubmit={handleCodeSubmit} noValidate>
                <div className={`auth-v2-field ${error ? 'has-error' : ''}`}>
                  <label htmlFor="code">Reset code</label>
                  <div className="auth-v2-input-wrap">
                    <span className="auth-v2-input-icon">#</span>
                    <input
                      id="code"
                      name="code"
                      inputMode="numeric"
                      autoComplete="one-time-code"
                      maxLength={6}
                      value={code}
                      onChange={(e) => {
                        setCode(e.target.value.replace(/\D/g, ''));
                        setError('');
                      }}
                      placeholder="123456"
                      disabled={loading}
                      autoFocus
                    />
                  </div>
                  {error && <span className="auth-v2-error">{error}</span>}
                </div>

                <button type="submit" className="auth-v2-submit" disabled={loading}>
                  {submitLabel('Verify Code', 'Checking...')}
                </button>
              </form>

              <p className="auth-v2-footer-note">
                Didn&apos;t get it?{' '}
                {resendIn > 0 ? (
                  <span>Resend in {resendIn}s</span>
                ) : (
                  <button
                    type="button"
                    className="auth-v2-inline-link"
                    onClick={sendCode}
                    disabled={loading}
                    style={{ background: 'none', border: 0, padding: 0, cursor: 'pointer', font: 'inherit' }}
                  >
                    Resend code
                  </button>
                )}
                {' · '}
                <button
                  type="button"
                  className="auth-v2-inline-link"
                  onClick={startOver}
                  style={{ background: 'none', border: 0, padding: 0, cursor: 'pointer', font: 'inherit' }}
                >
                  Use a different email
                </button>
              </p>
            </>
          )}

          {step === 'password' && (
            <>
              <h1 className="auth-v2-title">Set a new password.</h1>
              <p className="auth-v2-subtitle">
                Choose a new password for <strong>{email}</strong>.
              </p>

              <form className="auth-v2-form" onSubmit={handlePasswordSubmit} noValidate>
                <div className="auth-v2-field">
                  <label htmlFor="new-password">New password</label>
                  <div className="auth-v2-input-wrap">
                    <span className="auth-v2-input-icon">PW</span>
                    <input
                      id="new-password"
                      type="password"
                      autoComplete="new-password"
                      value={password}
                      onChange={(e) => {
                        setPassword(e.target.value);
                        setError('');
                      }}
                      placeholder="At least 6 characters"
                      disabled={loading}
                      autoFocus
                    />
                  </div>
                </div>

                <div className={`auth-v2-field ${error ? 'has-error' : ''}`}>
                  <label htmlFor="confirm-password">Confirm password</label>
                  <div className="auth-v2-input-wrap">
                    <span className="auth-v2-input-icon">PW</span>
                    <input
                      id="confirm-password"
                      type="password"
                      autoComplete="new-password"
                      value={confirm}
                      onChange={(e) => {
                        setConfirm(e.target.value);
                        setError('');
                      }}
                      placeholder="Type it again"
                      disabled={loading}
                    />
                  </div>
                  {error && <span className="auth-v2-error">{error}</span>}
                </div>

                <button type="submit" className="auth-v2-submit" disabled={loading}>
                  {submitLabel('Update Password', 'Saving...')}
                </button>
              </form>
            </>
          )}

          {step === 'done' && (
            <>
              <h1 className="auth-v2-title">Password updated.</h1>
              <p className="auth-v2-subtitle">You can sign in with your new password now.</p>
              <button type="button" className="auth-v2-submit" onClick={() => navigate('/login')}>
                Back to Sign In <span className="auth-v2-submit-arrow">-&gt;</span>
              </button>
            </>
          )}

          {step !== 'done' && (
            <p className="auth-v2-footer-note">
              Remember your password?{' '}
              <Link to="/login" className="auth-v2-inline-link">Back to sign in</Link>
            </p>
          )}
        </div>
      </div>

      <div className="auth-brand-side">
        <div className="auth-brand-side-bg" />
        <div className="auth-brand-side-content">
          <div className="auth-brand-badge">Account Recovery</div>
          <h2 className="auth-brand-headline">
            Back in
            <br />
            control soon.
          </h2>
          <p className="auth-brand-desc">
            Reset your access securely and return to managing AgriFair operations.
          </p>
        </div>
      </div>
    </div>
  );
}
