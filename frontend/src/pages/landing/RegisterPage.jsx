import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import './AuthPages.css';
import logoImg from '../../assets/logo.png';
import { registerUser, resendVerificationEmail, getErrorMessage } from '../../services/authApi';

export default function RegisterPage() {
  const [formData, setFormData] = useState({
    firstName: '',
    lastName: '',
    email: '',
    password: '',
    confirmPassword: '',
    role: 'seller',
  });
  const [errors, setErrors] = useState({});
  const [loading, setLoading] = useState(false);
  const [resending, setResending] = useState(false);
  const [alert, setAlert] = useState({ type: '', message: '' });
  const [awaitingVerification, setAwaitingVerification] = useState(false);

  const handleChange = (e) => {
    const { name, value } = e.target;

    setFormData((prev) => ({ ...prev, [name]: value }));
    if (errors[name]) setErrors((prev) => ({ ...prev, [name]: '' }));
  };

  const validate = () => {
    const errs = {};

    if (!formData.firstName.trim()) errs.firstName = 'First name is required';
    if (!formData.lastName.trim()) errs.lastName = 'Last name is required';
    if (!formData.email) errs.email = 'Email is required';
    else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(formData.email)) {
      errs.email = 'Invalid email format';
    }

    if (!formData.password) errs.password = 'Password is required';
    else if (formData.password.length < 6) errs.password = 'Minimum 6 characters';

    if (!formData.confirmPassword) errs.confirmPassword = 'Please confirm your password';
    else if (formData.password !== formData.confirmPassword) {
      errs.confirmPassword = 'Passwords do not match';
    }

    if (!['seller', 'superadmin'].includes(formData.role)) {
      errs.role = 'Please select a role';
    }

    return errs;
  };

  const showAlert = (type, message) => {
    setAlert({ type, message });
    // Errors now carry actionable detail - give them time to be read.
    setTimeout(() => setAlert({ type: '', message: '' }), type === 'error' ? 9000 : 4000);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();

    const errs = validate();
    if (Object.keys(errs).length) {
      setErrors(errs);
      return;
    }

    setLoading(true);
    setErrors({});

    try {
      const res = await registerUser({
        name: `${formData.firstName.trim()} ${formData.lastName.trim()}`,
        email: formData.email.trim().toLowerCase(),
        password: formData.password,
        role: formData.role,
      });

      setAwaitingVerification(true);
      if (res.data?.user?.verificationEmailSent === false) {
        showAlert('error', res.data.message || 'Account created, but verification email failed. Try Resend.');
      }
    } catch (err) {
      showAlert('error', getErrorMessage(err, 'Registration failed'));
    } finally {
      setLoading(false);
    }
  };

  const handleResend = async () => {
    setResending(true);
    try {
      await resendVerificationEmail(formData.email.trim().toLowerCase());
      showAlert('success', 'Verification email resent. Check your Gmail inbox.');
    } catch (err) {
      showAlert('error', getErrorMessage(err, 'Could not resend verification email'));
    } finally {
      setResending(false);
    }
  };

  return (
    <div className="auth-page-v2 auth-page-register">
      <div className="auth-brand-side">
        <div className="auth-brand-side-bg" />
        <div className="auth-brand-side-content">
          <div className="auth-brand-badge">Seller Business Access</div>
          <h2 className="auth-brand-headline">
            Start managing.
            <br />
            Grow smarter fairs.
          </h2>
          <p className="auth-brand-desc">
            Set up your AgriFair admin account and unlock event tools, seller coordination, and live reports.
          </p>

          <div className="auth-brand-stats-card">
            <div className="auth-brand-stats-card-header">
              <span className="auth-brand-stats-tag">Account Setup</span>
              <span className="auth-brand-stats-desc">Your admin workspace starts here.</span>
            </div>
            <div className="auth-brand-stats-row">
              <div className="auth-brand-stat">
                <span className="auth-brand-stat-value">Role</span>
                <span className="auth-brand-stat-label">Access</span>
              </div>
              <div className="auth-brand-stat">
                <span className="auth-brand-stat-value">Live</span>
                <span className="auth-brand-stat-label">Reports</span>
              </div>
              <div className="auth-brand-stat">
                <span className="auth-brand-stat-value">Sync</span>
                <span className="auth-brand-stat-label">Mobile</span>
              </div>
            </div>
            <p className="auth-brand-stats-foot">Secure admin registration for coordinated fair operations.</p>
          </div>
        </div>
      </div>

      <div className="auth-form-side">
        <Link to="/" className="auth-v2-brand" aria-label="Go to AgriFair home">
          <img src={logoImg} alt="AgriFair Logo" className="auth-v2-brand-img" />
          <span className="auth-v2-brand-text">AgriFair</span>
        </Link>

        <div className="auth-form-body auth-form-body-register">
          {awaitingVerification ? (
            <>
              <div className="auth-v2-label">Email Verification</div>
              <h1 className="auth-v2-title">Check your Gmail.</h1>
              <p className="auth-v2-subtitle">
                We sent a verification link to <strong>{formData.email}</strong>.
                {formData.role === 'superadmin'
                  ? ' After verifying, you can sign in to the Super Admin portal.'
                  : ' After verifying, wait for Super Admin approval, then sign in on the seller portal.'}
              </p>

              {alert.message && (
                <div className={`custom-alert-v2 ${alert.type}`}>
                  {alert.message}
                </div>
              )}

              <button
                type="button"
                className="auth-v2-submit"
                onClick={handleResend}
                disabled={resending}
              >
                {resending ? 'Sending...' : 'Resend verification email'}
                {!resending && <span className="auth-v2-submit-arrow">-&gt;</span>}
              </button>

              <p className="auth-v2-footer-note">
                Already verified?{' '}
                <Link to="/login" className="auth-v2-inline-link">Sign in</Link>
              </p>
            </>
          ) : (
            <>
          <div className="auth-v2-label">Create Account</div>
          <h1 className="auth-v2-title">Create account.</h1>
          <p className="auth-v2-subtitle">
            Choose your role and register for AgriFair — Super Admins oversee the platform, Sellers manage their business.
          </p>

              {alert.message && (
                <div className={`custom-alert-v2 ${alert.type}`}>
                  {alert.message}
                </div>
              )}

              <form className="auth-v2-form" onSubmit={handleSubmit} noValidate>
                <div className="auth-register-name-row">
                  <div className={`auth-v2-field ${errors.firstName ? 'has-error' : ''}`}>
                    <label htmlFor="firstName">First name</label>
                    <div className="auth-v2-input-wrap">
                      <input
                        id="firstName"
                        type="text"
                        name="firstName"
                        value={formData.firstName}
                        onChange={handleChange}
                        placeholder="First name"
                        autoComplete="given-name"
                        disabled={loading}
                      />
                    </div>
                    {errors.firstName && <span className="auth-v2-error">{errors.firstName}</span>}
                  </div>

                  <div className={`auth-v2-field ${errors.lastName ? 'has-error' : ''}`}>
                    <label htmlFor="lastName">Last name</label>
                    <div className="auth-v2-input-wrap">
                      <input
                        id="lastName"
                        type="text"
                        name="lastName"
                        value={formData.lastName}
                        onChange={handleChange}
                        placeholder="Last name"
                        autoComplete="family-name"
                        disabled={loading}
                      />
                    </div>
                    {errors.lastName && <span className="auth-v2-error">{errors.lastName}</span>}
                  </div>
                </div>

                <div className={`auth-v2-field ${errors.email ? 'has-error' : ''}`}>
                  <label htmlFor="email">Email address</label>
                  <div className="auth-v2-input-wrap">
                    <span className="auth-v2-input-icon">ID</span>
                    <input
                      id="email"
                      type="email"
                      name="email"
                      value={formData.email}
                      onChange={handleChange}
                      placeholder="you@email.com"
                      autoComplete="email"
                      disabled={loading}
                    />
                  </div>
                  {errors.email && <span className="auth-v2-error">{errors.email}</span>}
                </div>

                <div className="auth-register-name-row auth-register-password-row">
                  <div className={`auth-v2-field ${errors.password ? 'has-error' : ''}`}>
                    <label htmlFor="password">Password</label>
                    <div className="auth-v2-input-wrap">
                      <span className="auth-v2-input-icon">PW</span>
                      <input
                        id="password"
                        type="password"
                        name="password"
                        value={formData.password}
                        onChange={handleChange}
                        placeholder="Min. 6 characters"
                        autoComplete="new-password"
                        disabled={loading}
                      />
                    </div>
                    {errors.password && <span className="auth-v2-error">{errors.password}</span>}
                  </div>

                  <div className={`auth-v2-field ${errors.confirmPassword ? 'has-error' : ''}`}>
                    <label htmlFor="confirmPassword">Confirm password</label>
                    <div className="auth-v2-input-wrap">
                      <span className="auth-v2-input-icon">PW</span>
                      <input
                        id="confirmPassword"
                        type="password"
                        name="confirmPassword"
                        value={formData.confirmPassword}
                        onChange={handleChange}
                        placeholder="Re-enter password"
                        autoComplete="new-password"
                        disabled={loading}
                      />
                    </div>
                    {errors.confirmPassword && <span className="auth-v2-error">{errors.confirmPassword}</span>}
                  </div>
                </div>

                <div className={`auth-v2-field ${errors.role ? 'has-error' : ''}`}>
                  <label htmlFor="role">Account role</label>
                  <div className="auth-v2-input-wrap auth-v2-select-wrap">
                    <select
                      id="role"
                      name="role"
                      className="auth-v2-select"
                      value={formData.role}
                      onChange={handleChange}
                      disabled={loading}
                    >
                      <option value="seller">Seller — Business owner</option>
                      <option value="superadmin">Super Admin — Platform operator</option>
                    </select>
                  </div>
                  <span className="auth-v2-help">
                    {formData.role === 'superadmin'
                      ? 'Super Admin accounts can access the full platform portal after email verification.'
                      : 'Seller accounts need Super Admin approval after email verification.'}
                  </span>
                  {errors.role && <span className="auth-v2-error">{errors.role}</span>}
                </div>

                <button type="submit" className="auth-v2-submit" disabled={loading}>
                  {loading ? 'Creating account...' : 'Create Account'}
                  {!loading && <span className="auth-v2-submit-arrow">-&gt;</span>}
                </button>
              </form>

              <p className="auth-v2-footer-note">
                Already have an account?{' '}
                <Link to="/login" className="auth-v2-inline-link">Sign in</Link>
              </p>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
