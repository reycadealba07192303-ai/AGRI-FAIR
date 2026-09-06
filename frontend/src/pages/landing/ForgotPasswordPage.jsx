import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import './AuthPages.css';
import logoImg from '../../assets/logo.png';

export default function ForgotPasswordPage() {
  const [email, setEmail] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [sent, setSent] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();

    if (!email) {
      setError('Email is required');
      return;
    }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      setError('Invalid email format');
      return;
    }

    setLoading(true);
    setError('');

    try {
      await new Promise((resolve) => setTimeout(resolve, 1000));
      setSent(true);
    } catch {
      setError('Something went wrong. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="auth-page-v2">
      <div className="auth-form-side">
        <Link to="/" className="auth-v2-brand" aria-label="Go to AgriFair home">
          <img src={logoImg} alt="AgriFair Logo" className="auth-v2-brand-img" />
          <span className="auth-v2-brand-text">AgriFair</span>
        </Link>

        <div className="auth-form-body">
          <div className="auth-v2-label">Password Recovery</div>

          {!sent ? (
            <>
              <h1 className="auth-v2-title">Forgot password?</h1>
              <p className="auth-v2-subtitle">
                Enter your email and we will send you a reset link to get back in.
              </p>

              <form className="auth-v2-form" onSubmit={handleSubmit} noValidate>
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
                      placeholder="admin@agrifair.com"
                      autoComplete="email"
                      disabled={loading}
                    />
                  </div>
                  {error && <span className="auth-v2-error">{error}</span>}
                </div>

                <button type="submit" className="auth-v2-submit" disabled={loading}>
                  {loading ? 'Sending...' : 'Send Reset Link'}
                  {!loading && <span className="auth-v2-submit-arrow">-&gt;</span>}
                </button>
              </form>

              <p className="auth-v2-footer-note">
                Remember your password?{' '}
                <Link to="/login" className="auth-v2-inline-link">Back to sign in</Link>
              </p>
            </>
          ) : (
            <>
              <h1 className="auth-v2-title">Check your email.</h1>
              <p className="auth-v2-subtitle">
                We sent a password reset link to <strong>{email}</strong>. It may take a few minutes.
              </p>
              <Link to="/login" className="auth-v2-submit">
                Back to Sign In <span className="auth-v2-submit-arrow">-&gt;</span>
              </Link>
            </>
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
            Reset your admin access securely and return to managing AgriFair operations.
          </p>
        </div>
      </div>
    </div>
  );
}
