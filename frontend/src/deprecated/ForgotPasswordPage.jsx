import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import './AuthPages.css';

export default function ForgotPasswordPage() {
  const [email, setEmail] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [sent, setSent] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!email) { setError('Email is required'); return; }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) { setError('Invalid email format'); return; }
    setLoading(true);
    setError('');
    try {
      // TODO: axios.post('/api/auth/forgot-password', { email })
      await new Promise((r) => setTimeout(r, 1200));
      setSent(true);
    } catch {
      setError('Something went wrong. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="auth-page">
      <div className="auth-left">
        <Link to="/" className="auth-brand">
          <span>🌿</span> AgriFair
        </Link>
        <div className="auth-left-body">
          <h2>"We'll get you back in no time."</h2>
          <p>Password recovery for admin users.</p>
        </div>
        <p className="auth-left-foot">© 2025 AgriFair Capstone</p>
      </div>

      <div className="auth-right">
        <div className="auth-card">
          {!sent ? (
            <>
              <div className="auth-card-header">
                <div className="auth-icon-large">🔑</div>
                <h1>Forgot Password?</h1>
                <p>Enter your email and we'll send you a reset link.</p>
              </div>

              <form className="auth-form" onSubmit={handleSubmit} noValidate>
                <div className={`auth-field ${error ? 'has-error' : ''}`}>
                  <label htmlFor="email">Email Address</label>
                  <div className="auth-input-wrap">
                    <span className="auth-input-icon">✉</span>
                    <input
                      type="email"
                      id="email"
                      name="email"
                      value={email}
                      onChange={(e) => { setEmail(e.target.value); setError(''); }}
                      placeholder="admin@example.com"
                      disabled={loading}
                      autoComplete="email"
                    />
                  </div>
                  {error && <span className="auth-error-msg">{error}</span>}
                </div>

                <button type="submit" className="auth-submit-btn" disabled={loading}>
                  {loading ? <span className="auth-spinner" /> : null}
                  {loading ? 'Sending…' : 'Send Reset Link'}
                </button>
              </form>

              <p className="auth-toggle">
                Remember your password?{' '}
                <Link to="/login" className="auth-toggle-link">Back to Sign In</Link>
              </p>
            </>
          ) : (
            <div className="auth-success-state">
              <div className="auth-success-icon">📬</div>
              <h2>Check Your Email</h2>
              <p>
                We sent a password reset link to <strong>{email}</strong>.
                It may take a few minutes to arrive.
              </p>
              <Link to="/login" className="auth-submit-btn" style={{ display: 'flex', justifyContent: 'center', textDecoration: 'none' }}>
                Back to Sign In
              </Link>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
