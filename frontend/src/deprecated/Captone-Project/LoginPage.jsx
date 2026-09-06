import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import './AuthPages.css';

export default function LoginPage({ onLoginSuccess }) {
  const navigate = useNavigate();
  const [formData, setFormData] = useState({ email: '', password: '' });
  const [errors, setErrors] = useState({});
  const [loading, setLoading] = useState(false);
  const [successMessage, setSuccessMessage] = useState('');

  const handleChange = (e) => {
    const { name, value } = e.target;
    setFormData((prev) => ({ ...prev, [name]: value }));
    if (errors[name]) setErrors((prev) => ({ ...prev, [name]: '' }));
  };

  const validate = () => {
    const errs = {};
    if (!formData.email) errs.email = 'Email is required';
    else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(formData.email)) errs.email = 'Invalid email format';
    if (!formData.password) errs.password = 'Password is required';
    else if (formData.password.length < 6) errs.password = 'Minimum 6 characters';
    return errs;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    const errs = validate();
    if (Object.keys(errs).length) { setErrors(errs); return; }
    setLoading(true);
    setErrors({});
    try {
      // MOCK LOGIN — any valid email + 6+ char password works.
      // Replace this block when backend is ready:
      //   const res = await axios.post('/api/auth/login', formData);
      //   const { token, user } = res.data;
      //   sessionStorage.setItem('token', token);
      await new Promise((r) => setTimeout(r, 900));

      setSuccessMessage('Login successful! Redirecting…');
      sessionStorage.setItem('isLoggedIn', 'true');
      sessionStorage.setItem('userSession', JSON.stringify({
        email: formData.email,
        role: 'Admin',
      }));
      setTimeout(() => {
        if (onLoginSuccess) onLoginSuccess({ email: formData.email });
        navigate('/home');
      }, 900);
    } catch {
      setErrors({ submit: 'Something went wrong. Please try again.' });
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
          <h2>"Connecting farmers, traders, and administrators — one fair at a time."</h2>
          <p>Admin Portal · Secure Access · Role-Based Control</p>
        </div>
        <p className="auth-left-foot">© 2025 AgriFair Capstone</p>
      </div>

      <div className="auth-right">
        <div className="auth-card">
          <div className="auth-card-header">
            <h1>Welcome back</h1>
            <p>Sign in to your admin account</p>
          </div>

          <form className="auth-form" onSubmit={handleSubmit} noValidate>
            <div className={`auth-field ${errors.email ? 'has-error' : ''}`}>
              <label htmlFor="email">Email Address</label>
              <div className="auth-input-wrap">
                <span className="auth-input-icon">✉</span>
                <input
                  type="email"
                  id="email"
                  name="email"
                  value={formData.email}
                  onChange={handleChange}
                  placeholder="you@example.com"
                  disabled={loading}
                  autoComplete="email"
                />
              </div>
              {errors.email && <span className="auth-error-msg">{errors.email}</span>}
            </div>

            <div className={`auth-field ${errors.password ? 'has-error' : ''}`}>
              <label htmlFor="password">
                Password
                <Link to="/forgot-password" className="auth-inline-link">Forgot password?</Link>
              </label>
              <div className="auth-input-wrap">
                <span className="auth-input-icon">🔒</span>
                <input
                  type="password"
                  id="password"
                  name="password"
                  value={formData.password}
                  onChange={handleChange}
                  placeholder="••••••••"
                  disabled={loading}
                  autoComplete="current-password"
                />
              </div>
              {errors.password && <span className="auth-error-msg">{errors.password}</span>}
            </div>

            {errors.submit && <div className="auth-banner auth-banner-error">{errors.submit}</div>}
            {successMessage && <div className="auth-banner auth-banner-success">{successMessage}</div>}

            <button type="submit" className="auth-submit-btn" disabled={loading}>
              {loading ? <span className="auth-spinner" /> : null}
              {loading ? 'Signing in…' : 'Sign In'}
            </button>
          </form>

          <p className="auth-toggle">
            Don't have an account?{' '}
            <Link to="/register" className="auth-toggle-link">Register here</Link>
          </p>
        </div>
      </div>
    </div>
  );
}
