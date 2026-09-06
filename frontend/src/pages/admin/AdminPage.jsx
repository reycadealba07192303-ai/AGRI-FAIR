import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Menu, CalendarDays } from 'lucide-react';
import './AdminPage.css';

import AdminSidebar from './components/AdminSidebar';
import NotificationBell from './components/NotificationBell';
import DashboardTab from './tabs/DashboardTab';
import ProductListTab from './tabs/ProductListTab';
import InventoryTab from './tabs/InventoryTab';
import OrdersTab from './tabs/OrdersTab';
import ReportsTab from './tabs/ReportsTab';
import MessagesTab from './tabs/MessagesTab';
import AccountInfoTab from './tabs/AccountInfoTab';
import { clearSession, getSessionUser } from '../../utils/auth';

const TABS = ['Dashboard', 'Products', 'Inventory', 'Orders', 'Analytics', 'Messages', 'Account Info'];

export default function AdminPage({ onLogout }) {
  const navigate = useNavigate();
  // Read the session during initialisation - syncing it in an effect caused a
  // cascading render and a frame of empty user data on every mount.
  const [user] = useState(() => getSessionUser() || { email: '', role: 'seller', name: '' });
  const [activeTab, setActiveTab] = useState('Dashboard');
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [showLogout, setShowLogout] = useState(false);

  const handleLogout = () => {
    clearSession();
    if (onLogout) onLogout();
    navigate('/login');
  };

  const displayName = user.name || user.email?.split('@')[0] || 'Seller';
  const now = new Date();
  const todayWeekday = now.toLocaleDateString('en-PH', { weekday: 'long' });
  const todayDate = now.toLocaleDateString('en-PH', { month: 'long', day: 'numeric', year: 'numeric' });

  const renderTab = () => {
    switch (activeTab) {
      case 'Dashboard':
        return <DashboardTab onNavigate={setActiveTab} />;
      case 'Products':
        return <ProductListTab />;
      case 'Inventory':
        return <InventoryTab />;
      case 'Orders':
        return <OrdersTab />;
      case 'Analytics':
        return <ReportsTab />;
      case 'Messages':
        return <MessagesTab user={user} />;
      case 'Account Info':
        return <AccountInfoTab />;
      default:
        return null;
    }
  };

  return (
    <div className="ap-root">
      <AdminSidebar
        user={user}
        tabs={TABS}
        activeTab={activeTab}
        setActiveTab={setActiveTab}
        sidebarOpen={sidebarOpen}
        setSidebarOpen={setSidebarOpen}
        onLogoutClick={() => setShowLogout(true)}
      />

      <main className="ap-main">
        <header className="ap-topbar">
          <div className="ap-topbar-left">
            <button
              className="ap-menu-btn"
              type="button"
              aria-label="Open menu"
              onClick={() => setSidebarOpen(true)}
            >
              <Menu size={18} strokeWidth={2.25} />
            </button>
            <div>
              <p className="ap-eyebrow">Seller workspace</p>
              <p className="ap-greeting">Hello, {displayName}</p>
              <h1 className="ap-topbar-title">{activeTab}</h1>
            </div>
          </div>

          <div className="ap-topbar-right">
            <div className="ap-topbar-meta">
              <CalendarDays size={17} strokeWidth={2.2} />
              <div>
                <span className="ap-topbar-meta-day">{todayWeekday}</span>
                <span className="ap-topbar-meta-date">{todayDate}</span>
              </div>
            </div>
            <NotificationBell onNavigate={setActiveTab} />
          </div>
        </header>
        <div className="ap-body">{renderTab()}</div>
      </main>

      {showLogout && (
        <div className="ap-modal-overlay">
          <div className="ap-modal">
            <h3>Log out?</h3>
            <p>Are you sure you want to sign out of your AgriFair seller portal?</p>
            <div className="ap-modal-actions">
              <button className="ap-modal-cancel" type="button" onClick={() => setShowLogout(false)}>Cancel</button>
              <button className="ap-modal-confirm" type="button" onClick={handleLogout}>Yes, Log Out</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
