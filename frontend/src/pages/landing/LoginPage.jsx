import React, { useState, useEffect } from 'react';
import { useNavigate, Link, useSearchParams } from 'react-router-dom';
import './AuthPages.css';
import logoImg from '../../assets/logo.png';
import { loginUser, getErrorMessage } from '../../services/authApi';
import { getHomePath } from '../../utils/auth';

export default function LoginPage() {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();

  const [formData, setFormData] = useState({
    email: '',
    password: '',
  });
  const [errors, setErrors] = useState({});
  const [loading, setLoading] = useState(false);
  const [alert, setAlert] = useState({ type: '', message: '' });

  useEffect(() => {
    if (searchParams.get('verified') === '1') {
      setAlert({
        type: 'success',
        message: 'Email verified successfully. You can sign in now.'
      });
    }
  }, [searchParams]);

  const handleChange = (e) => {
    const { name, value } = e.target;

    setFormData((prev) => ({ ...prev, [name]: value }));
    if (errors[name]) setErrors((prev) => ({ ...prev, [name]: '' }));
  };

  const validate = () => {
    const errs = {};

    if (!formData.email) errs.email = 'Email is required';
    else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(formData.email)) {
      errs.email = 'Invalid email format';
    }

    if (!formData.password) errs.password = 'Password is required';
    else if (formData.password.length < 6) errs.password = 'Minimum 6 characters';

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
      const res = await loginUser({
        email: formData.email.trim().toLowerCase(),
        password: formData.password,
      });

      sessionStorage.setItem('token', res.data.token);
      sessionStorage.setItem('user', JSON.stringify(res.data.user));

      const home = getHomePath(res.data.user?.role);
      showAlert('success', 'Login successful. Redirecting...');
      setTimeout(() => navigate(home === '/' ? '/' : home), 1000);
    } catch (err) {
      showAlert('error', getErrorMessage(err, 'Login failed'));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="auth-page-v2 auth-page-login">
      <div className="auth-form-side">
        <Link to="/" className="auth-v2-brand" aria-label="Go to AgriFair home">
          <img src={logoImg} alt="AgriFair Logo" className="auth-v2-brand-img" />
          <span className="auth-v2-brand-text">AgriFair</span>
        </Link>

        <div className="auth-form-body">
          <div className="auth-v2-label">Portal Access</div>
          <h1 className="auth-v2-title">Welcome back.</h1>
          <p className="auth-v2-subtitle">
            Enter your account details to continue to the AgriFair management system.
          </p>

          {alert.message && (
            <div className={`custom-alert-v2 ${alert.type}`}>
              {alert.message}
            </div>
          )}

          <form className="auth-v2-form" onSubmit={handleSubmit} noValidate>
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
                  placeholder="admin@agrifair.com"
                  autoComplete="email"
                  disabled={loading}
                />
              </div>
              {errors.email && <span className="auth-v2-error">{errors.email}</span>}
            </div>

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
                  placeholder="Enter your password"
                  autoComplete="current-password"
                  disabled={loading}
                />
              </div>
              {errors.password && <span className="auth-v2-error">{errors.password}</span>}
            </div>

            <div className="auth-v2-options">
              <label className="auth-v2-checkbox">
                <input type="checkbox" />
                <span>Keep me signed in</span>
              </label>
              <Link to="/forgot-password" className="auth-v2-forgot">Forgot password?</Link>
            </div>

            <button type="submit" className="auth-v2-submit" disabled={loading}>
              {loading ? 'Signing in...' : 'Sign In'}
              {!loading && <span className="auth-v2-submit-arrow">-&gt;</span>}
            </button>
          </form>

          <p className="auth-v2-footer-note">
            Need an admin account?{' '}
            <Link to="/register" className="auth-v2-inline-link">Create account</Link>
          </p>
        </div>
      </div>

      <div className="auth-brand-side">
        <div className="auth-brand-side-bg" />
        <div className="auth-brand-side-content">
          <div className="auth-brand-badge">Secure Admin Portal</div>
          <h2 className="auth-brand-headline">
            One platform.
            <br />
            Smarter fairs.
          </h2>
          <p className="auth-brand-desc">
            Coordinating events, sellers, analytics, and mobile activity across the AgriFair system.
          </p>

          <div className="auth-brand-stats-card">
            <div className="auth-brand-stats-card-header">
              <span className="auth-brand-stats-tag">AgriFair at a Glance</span>
              <span className="auth-brand-stats-desc">Fair operations, simplified.</span>
            </div>
            <div className="auth-brand-stats-row">
              <div className="auth-brand-stat">
                <span className="auth-brand-stat-value">500+</span>
                <span className="auth-brand-stat-label">Users</span>
              </div>
              <div className="auth-brand-stat">
                <span className="auth-brand-stat-value">120+</span>
                <span className="auth-brand-stat-label">Events</span>
              </div>
              <div className="auth-brand-stat">
                <span className="auth-brand-stat-value">24/7</span>
                <span className="auth-brand-stat-label">Admin Sync</span>
              </div>
            </div>
            <p className="auth-brand-stats-foot">Serving agricultural communities with one unified portal.</p>
          </div>
        </div>
      </div>
    </div>
  );
}
