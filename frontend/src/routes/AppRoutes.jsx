import React from 'react';
import { Routes, Route, Navigate } from 'react-router-dom';

import LandingPage from '../pages/LandingPage';
import LoginPage from '../pages/landing/LoginPage';
import RegisterPage from '../pages/landing/RegisterPage';
import ForgotPasswordPage from '../pages/landing/ForgotPasswordPage';
import AdminPage from '../pages/admin/AdminPage';
import SuperAdminPage from '../pages/superadmin/SuperAdminPage';
import { getHomePath, getSessionUser } from '../utils/auth';

const getAuth = () => {
  const token = sessionStorage.getItem('token');
  const user = getSessionUser();
  return { token, user };
};

const Protected = ({ children, role }) => {
  const { token, user } = getAuth();

  if (!token || !user) return <Navigate to="/login" replace />;
  if (role && user.role !== role) return <Navigate to={getHomePath(user.role)} replace />;

  return children;
};

export default function AppRoutes() {
  const { token, user } = getAuth();

  return (
    <Routes>
      <Route
        path="/"
        element={
          token && user ? (
            <Navigate to={getHomePath(user.role)} replace />
          ) : (
            <LandingPage />
          )
        }
      />

      <Route path="/login" element={<LoginPage />} />
      <Route path="/register" element={<RegisterPage />} />
      <Route path="/forgot-password" element={<ForgotPasswordPage />} />
      <Route path="/admin" element={<Navigate to="/client" replace />} />

      <Route
        path="/client"
        element={
          <Protected role="seller">
            <AdminPage />
          </Protected>
        }
      />

      <Route
        path="/superadmin"
        element={
          <Protected role="superadmin">
            <SuperAdminPage />
          </Protected>
        }
      />

      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
