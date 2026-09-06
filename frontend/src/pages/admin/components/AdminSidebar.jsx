import React from 'react';
import {
  LayoutGrid,
  Package,
  ClipboardList,
  ShoppingCart,
  BarChart3,
  MessageSquare,
  UserCog,
  X,
  LogOut,
} from 'lucide-react';
import logoImg from '../../../assets/logo.png';

const DEFAULT_TABS = ['Dashboard', 'Products', 'Inventory', 'Orders', 'Analytics', 'Messages', 'Account Info'];

const TAB_ICONS = {
  Dashboard: LayoutGrid,
  Products: Package,
  Inventory: ClipboardList,
  Orders: ShoppingCart,
  Analytics: BarChart3,
  Messages: MessageSquare,
  'Account Info': UserCog,
};

export default function AdminSidebar({
  user,
  tabs = DEFAULT_TABS,
  activeTab,
  setActiveTab,
  sidebarOpen,
  setSidebarOpen,
  onLogoutClick,
}) {
  const initials = user.email ? user.email.slice(0, 2).toUpperCase() : 'SE';

  return (
    <>
      <aside className={`ap-sidebar ${sidebarOpen ? 'open' : ''}`}>
        <div className="ap-sidebar-header">
          <div className="ap-logo">
            <img src={logoImg} alt="" className="ap-logo-img" />
            <div className="ap-logo-text">
              <span className="ap-logo-name">AgriFair</span>
              <span className="ap-logo-role">Seller Portal</span>
            </div>
          </div>
          <button
            className="ap-sidebar-close"
            type="button"
            aria-label="Close menu"
            onClick={() => setSidebarOpen(false)}
          >
            <X size={18} strokeWidth={2.4} />
          </button>
        </div>

        <nav className="ap-nav">
          {tabs.map((tab) => {
            const Icon = TAB_ICONS[tab] || LayoutGrid;
            return (
              <button
                key={tab}
                type="button"
                className={`ap-nav-item ${activeTab === tab ? 'active' : ''}`}
                aria-current={activeTab === tab}
                onClick={() => { setActiveTab(tab); setSidebarOpen(false); }}
              >
                <Icon size={17} strokeWidth={2.2} />
                <span>{tab}</span>
              </button>
            );
          })}
        </nav>

        <div className="ap-sidebar-foot">
          <div className="ap-user-chip">
            <div className="ap-avatar">{initials}</div>
            <div className="ap-user-meta">
              <div className="ap-user-email">{user.email || 'seller@agrifair.ph'}</div>
              <div className="ap-user-role">Seller</div>
            </div>
          </div>
          <button className="ap-logout-btn" type="button" onClick={onLogoutClick}>
            <LogOut size={16} strokeWidth={2.2} />
            Log out
          </button>
        </div>
      </aside>

      {sidebarOpen && <div className="ap-overlay" onClick={() => setSidebarOpen(false)} />}
    </>
  );
}
