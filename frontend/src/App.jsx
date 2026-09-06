import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';

import LandingPage from './pages/LandingPage.jsx';
import LoginPage from './pages/landing/LoginPage.jsx';
import RegisterPage from './pages/landing/RegisterPage.jsx';
import ForgotPasswordPage from './pages/landing/ForgotPasswordPage.jsx';

import AdminPage from './pages/admin/AdminPage.jsx';
import SuperAdminPage from './pages/superadmin/SuperAdminPage.jsx';
import { getHomePath, getSessionUser, clearSession } from './utils/auth.js';

const getAuth = () => {
  const token = sessionStorage.getItem('token');
  const user = getSessionUser();
  return { token, user };
};

function ProtectedRoute({ children, role }) {
  const { token, user } = getAuth();

  if (!token || !user) {
    return <Navigate to="/login" replace />;
  }

  if (role && user.role !== role) {
    return <Navigate to={getHomePath(user.role)} replace />;
  }

  return children;
}

function PublicOnlyRoute({ children }) {
  const { token, user } = getAuth();

  if (token && user) {
    return <Navigate to={getHomePath(user.role)} replace />;
  }

  return children;
}

function HomeRedirect() {
  const { token, user } = getAuth();
  if (token && user) {
    const path = getHomePath(user.role);
    if (path === '/') return <LandingPage />;
    return <Navigate to={path} replace />;
  }
  return <LandingPage />;
}

export default function App() {
  const handleLogout = () => {
    clearSession();
  };

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<HomeRedirect />} />

        <Route path="/login" element={
          <PublicOnlyRoute>
            <LoginPage />
          </PublicOnlyRoute>
        } />

        <Route path="/register" element={
          <PublicOnlyRoute>
            <RegisterPage />
          </PublicOnlyRoute>
        } />

        <Route path="/forgot-password" element={
          <PublicOnlyRoute>
            <ForgotPasswordPage />
          </PublicOnlyRoute>
        } />

        <Route path="/admin" element={<Navigate to="/client" replace />} />

        <Route path="/client" element={
          <ProtectedRoute role="seller">
            <AdminPage onLogout={handleLogout} />
          </ProtectedRoute>
        } />

        <Route path="/superadmin" element={
          <ProtectedRoute role="superadmin">
            <SuperAdminPage onLogout={handleLogout} />
          </ProtectedRoute>
        } />

        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
