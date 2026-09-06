import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import './HomePage.css';

const STAT_CARDS = [
  { icon: '👥', label: 'Total Users', value: '248', delta: '+12 this week', up: true },
  { icon: '📅', label: 'Active Events', value: '14', delta: '+3 ongoing', up: true },
  { icon: '🌾', label: 'Vendors', value: '87', delta: '-2 this week', up: false },
  { icon: '📊', label: 'Reports', value: '36', delta: '5 pending review', up: null },
];

const RECENT_ACTIVITY = [
  { type: 'user', msg: 'New user registered: maria@fairphl.com', time: '2m ago' },
  { type: 'event', msg: 'Event "AgriExpo 2025" updated by admin', time: '18m ago' },
  { type: 'report', msg: 'Monthly report generated for March', time: '1h ago' },
  { type: 'system', msg: 'System backup completed successfully', time: '3h ago' },
  { type: 'user', msg: 'Password reset for vendor@agrifair.ph', time: '5h ago' },
];

const QUICK_LINKS = [
  { icon: '👤', label: 'User Management', desc: 'Add, edit, or remove users', path: '#' },
  { icon: '📅', label: 'Events', desc: 'Manage agricultural fair events', path: '#' },
  { icon: '📈', label: 'Analytics', desc: 'View performance reports', path: '#' },
  { icon: '⚙️', label: 'Settings', desc: 'Configure system preferences', path: '#' },
];

const TYPE_COLOR = {
  user: '#4a8c4a',
  event: '#c9a84c',
  report: '#3b82f6',
  system: '#8b5cf6',
};

export default function HomePage({ onLogout }) {
  const navigate = useNavigate();
  const [user, setUser] = useState({ email: '', role: 'Admin' });
  const [showLogoutModal, setShowLogoutModal] = useState(false);
  const [sidebarOpen, setSidebarOpen] = useState(false);

  useEffect(() => {
    const session = sessionStorage.getItem('userSession');
    if (session) setUser(JSON.parse(session));
  }, []);

  const handleLogout = () => {
    sessionStorage.removeItem('isLoggedIn');
    sessionStorage.removeItem('userSession');
    if (onLogout) onLogout();
    navigate('/login');
  };

  const initials = user.email
    ? user.email.slice(0, 2).toUpperCase()
    : 'AD';

  return (
    <div className="hp-root">
      {/* SIDEBAR */}
      <aside className={`hp-sidebar ${sidebarOpen ? 'open' : ''}`}>
        <div className="hp-sidebar-header">
          <div className="hp-logo">
            <span>🌿</span>
            <span className="hp-logo-text">AgriFair</span>
          </div>
          <button className="hp-sidebar-close" onClick={() => setSidebarOpen(false)}>✕</button>
        </div>

        <nav className="hp-nav">
          <a href="#" className="hp-nav-item active">
            <span className="hp-nav-icon">🏠</span> Dashboard
          </a>
          <a href="#" className="hp-nav-item">
            <span className="hp-nav-icon">👥</span> Users
          </a>
          <a href="#" className="hp-nav-item">
            <span className="hp-nav-icon">📅</span> Events
          </a>
          <a href="#" className="hp-nav-item">
            <span className="hp-nav-icon">🌾</span> Vendors
          </a>
          <a href="#" className="hp-nav-item">
            <span className="hp-nav-icon">📊</span> Reports
          </a>
          <a href="#" className="hp-nav-item">
            <span className="hp-nav-icon">⚙️</span> Settings
          </a>
        </nav>

        <div className="hp-sidebar-foot">
          <div className="hp-user-chip">
            <div className="hp-avatar">{initials}</div>
            <div>
              <div className="hp-user-email">{user.email || 'admin@agrifair.ph'}</div>
              <div className="hp-user-role">{user.role || 'Admin'}</div>
            </div>
          </div>
          <button className="hp-logout-btn" onClick={() => setShowLogoutModal(true)}>
            🚪 Logout
          </button>
        </div>
      </aside>

      {/* OVERLAY */}
      {sidebarOpen && <div className="hp-overlay" onClick={() => setSidebarOpen(false)} />}

      {/* MAIN */}
      <main className="hp-main">
        {/* TOP BAR */}
        <header className="hp-topbar">
          <button className="hp-menu-btn" onClick={() => setSidebarOpen(true)}>☰</button>
          <div className="hp-topbar-title">Dashboard</div>
          <div className="hp-topbar-right">
            <div className="hp-avatar hp-topbar-avatar">{initials}</div>
          </div>
        </header>

        {/* CONTENT */}
        <div className="hp-content">
          {/* WELCOME */}
          <div className="hp-welcome">
            <div>
              <h1>Good day, {user.role || 'Admin'} 👋</h1>
              <p>Here's what's happening with AgriFair today.</p>
            </div>
            <div className="hp-date-badge">
              {new Date().toLocaleDateString('en-PH', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}
            </div>
          </div>

          {/* STAT CARDS */}
          <div className="hp-stats-grid">
            {STAT_CARDS.map((s, i) => (
              <div
                className="hp-stat-card"
                key={s.label}
                style={{ animationDelay: `${i * 0.08}s` }}
              >
                <div className="hp-stat-icon">{s.icon}</div>
                <div className="hp-stat-info">
                  <div className="hp-stat-value">{s.value}</div>
                  <div className="hp-stat-label">{s.label}</div>
                </div>
                <div className={`hp-stat-delta ${s.up === true ? 'up' : s.up === false ? 'down' : 'neutral'}`}>
                  {s.up === true ? '↑' : s.up === false ? '↓' : '·'} {s.delta}
                </div>
              </div>
            ))}
          </div>

          {/* TWO-COL SECTION */}
          <div className="hp-two-col">
            {/* QUICK LINKS */}
            <div className="hp-panel">
              <div className="hp-panel-header">
                <h2>Quick Actions</h2>
              </div>
              <div className="hp-quick-links">
                {QUICK_LINKS.map((q) => (
                  <a href={q.path} className="hp-quick-link" key={q.label}>
                    <div className="hp-ql-icon">{q.icon}</div>
                    <div>
                      <div className="hp-ql-label">{q.label}</div>
                      <div className="hp-ql-desc">{q.desc}</div>
                    </div>
                    <span className="hp-ql-arrow">→</span>
                  </a>
                ))}
              </div>
            </div>

            {/* RECENT ACTIVITY */}
            <div className="hp-panel">
              <div className="hp-panel-header">
                <h2>Recent Activity</h2>
                <a href="#" className="hp-panel-link">View all</a>
              </div>
              <div className="hp-activity-list">
                {RECENT_ACTIVITY.map((a, i) => (
                  <div className="hp-activity-item" key={i}>
                    <div
                      className="hp-activity-dot"
                      style={{ background: TYPE_COLOR[a.type] || '#aaa' }}
                    />
                    <div className="hp-activity-body">
                      <p>{a.msg}</p>
                      <span>{a.time}</span>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </main>

      {/* LOGOUT MODAL */}
      {showLogoutModal && (
        <div className="hp-modal-overlay">
          <div className="hp-modal">
            <div className="hp-modal-icon">🚪</div>
            <h3>Log out?</h3>
            <p>Are you sure you want to sign out of AgriFair Admin?</p>
            <div className="hp-modal-actions">
              <button className="hp-modal-cancel" onClick={() => setShowLogoutModal(false)}>Cancel</button>
              <button className="hp-modal-confirm" onClick={handleLogout}>Yes, Log Out</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
