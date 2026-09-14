import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';

import LandingPage from './pages/LandingPage.jsx';
import LoginPage from './pages/landing/LoginPage.jsx';
import RegisterPage from './pages/landing/RegisterPage.jsx';
import ForgotPasswordPage from './pages/landing/ForgotPasswordPage.jsx';

import AdminPage from './pages/admin/AdminPage.jsx';
import SuperAdminPage from './pages/superadmin/SuperAdminPage.jsx';
import RiderPage from './pages/rider/RiderPage.jsx';
import ActivatePage from './pages/rider/ActivatePage.jsx';
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

        {/* A rider creating the password for the account their shop made,
            from the emailed link. Open to everyone: the token is the key, and
            a signed-in session on this browser has nothing to do with it. */}
        <Route path="/activate" element={<ActivatePage />} />

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

        {/* Where a rider signing in on the web lands. Without it, "/rider"
            fell through to "*", back to "/", and was sent to "/rider" again. */}
        <Route path="/rider" element={
          <ProtectedRoute role="rider">
            <RiderPage />
          </ProtectedRoute>
        } />

        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
