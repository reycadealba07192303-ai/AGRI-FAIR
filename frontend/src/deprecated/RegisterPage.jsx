import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import './AuthPages.css';
import { registerUser } from '../../services/authApi';

export default function RegisterPage() {
  const navigate = useNavigate();
  const [formData, setFormData] = useState({
    fullName: '',
    email: '',
    password: '',
    confirmPassword: '',
    role: 'Admin',
  });
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
    if (!formData.fullName.trim()) errs.fullName = 'Full name is required';
    if (!formData.email) errs.email = 'Email is required';
    else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(formData.email)) errs.email = 'Invalid email format';
    if (!formData.password) errs.password = 'Password is required';
    else if (formData.password.length < 6) errs.password = 'Minimum 6 characters';
    if (!formData.confirmPassword) errs.confirmPassword = 'Please confirm your password';
    else if (formData.password !== formData.confirmPassword) errs.confirmPassword = 'Passwords do not match';
    return errs;
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
    const payload = {
      name: formData.fullName, // 🔥 important mapping
      email: formData.email,
      password: formData.password
    };

    await registerUser(payload);

    setSuccessMessage('Account created! Redirecting to log in…');
    setTimeout(() => navigate('/login'), 1400);

  } catch (err) {
    setErrors({
      submit: err.response?.data?.message || 'Registration failed'
    });
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
          <h2>"Grow the system. Empower the fair."</h2>
          <p>Create an admin account to manage agricultural events.</p>
        </div>
        <p className="auth-left-foot">© 2025 AgriFair Capstone</p>
      </div>

      <div className="auth-right">
        <div className="auth-card">
          <div className="auth-card-header">
            <h1>Create Account</h1>
            <p>Register for admin access</p>
          </div>

          <form className="auth-form" onSubmit={handleSubmit} noValidate>
            <div className={`auth-field ${errors.fullName ? 'has-error' : ''}`}>
              <label htmlFor="fullName">Full Name</label>
              <div className="auth-input-wrap">
                <span className="auth-input-icon">👤</span>
                <input
                  type="text"
                  id="fullName"
                  name="fullName"
                  value={formData.fullName}
                  onChange={handleChange}
                  placeholder="Juan dela Cruz"
                  disabled={loading}
                  autoComplete="name"
                />
              </div>
              {errors.fullName && <span className="auth-error-msg">{errors.fullName}</span>}
            </div>

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
                  placeholder="admin@example.com"
                  disabled={loading}
                  autoComplete="email"
                />
              </div>
              {errors.email && <span className="auth-error-msg">{errors.email}</span>}
            </div>

            <div className="auth-fields-row">
              <div className={`auth-field ${errors.password ? 'has-error' : ''}`}>
                <label htmlFor="password">Password</label>
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
                    autoComplete="new-password"
                  />
                </div>
                {errors.password && <span className="auth-error-msg">{errors.password}</span>}
              </div>

              <div className={`auth-field ${errors.confirmPassword ? 'has-error' : ''}`}>
                <label htmlFor="confirmPassword">Confirm Password</label>
                <div className="auth-input-wrap">
                  <span className="auth-input-icon">🔒</span>
                  <input
                    type="password"
                    id="confirmPassword"
                    name="confirmPassword"
                    value={formData.confirmPassword}
                    onChange={handleChange}
                    placeholder="••••••••"
                    disabled={loading}
                    autoComplete="new-password"
                  />
                </div>
                {errors.confirmPassword && <span className="auth-error-msg">{errors.confirmPassword}</span>}
              </div>
            </div>

            <div className="auth-field">
              <label htmlFor="role">Role</label>
              <div className="auth-input-wrap auth-select-wrap">
                <span className="auth-input-icon">🏷</span>
                <select
                  id="role"
                  name="role"
                  value={formData.role}
                  onChange={handleChange}
                  disabled={loading}
                  className="auth-select"
                >
                  <option value="Admin">Admin</option>
                  <option value="Super Admin">Super Admin</option>
                </select>
              </div>
            </div>

            {errors.submit && <div className="auth-banner auth-banner-error">{errors.submit}</div>}
            {successMessage && <div className="auth-banner auth-banner-success">{successMessage}</div>}

            <button type="submit" className="auth-submit-btn" disabled={loading}>
              {loading ? <span className="auth-spinner" /> : null}
              {loading ? 'Creating account…' : 'Create Account'}
            </button>
          </form>

          <p className="auth-toggle">
            Already have an account?{' '}
            <Link to="/login" className="auth-toggle-link">Sign in</Link>
          </p>
        </div>
      </div>
    </div>
  );
}
