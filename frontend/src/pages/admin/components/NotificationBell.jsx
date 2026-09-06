import React, { useEffect, useRef, useState } from 'react';
import { Bell, Receipt, CreditCard, MessageSquare, Package, Info } from 'lucide-react';
import { fetchNotifications, markNotificationRead, markAllNotificationsRead } from '../../../services/notificationApi';

const FILTERS = ['All', 'Unread', 'ORDER', 'PAYMENT', 'MESSAGE'];
const FILTER_LABEL = { All: 'All', Unread: 'Unread', ORDER: 'Order', PAYMENT: 'Payment', MESSAGE: 'Message' };

const TYPE_ICON = {
  ORDER: Receipt,
  PAYMENT: CreditCard,
  MESSAGE: MessageSquare,
  STOCK: Package,
  SYSTEM: Info,
};

export default function NotificationBell({ onNavigate }) {
  const [open, setOpen] = useState(false);
  const [notifications, setNotifications] = useState([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [filter, setFilter] = useState('All');
  const rootRef = useRef(null);

  const load = async () => {
    try {
      const res = await fetchNotifications();
      setNotifications(res.data.notifications || []);
      setUnreadCount(res.data.unreadCount || 0);
    } catch {
      // silent — bell just stays quiet if this fails
    }
  };

  useEffect(() => {
    let mounted = true;
    (async () => {
      if (mounted) await load();
    })();
    const interval = setInterval(load, 20000);
    return () => {
      mounted = false;
      clearInterval(interval);
    };
  }, []);

  useEffect(() => {
    function handleClickOutside(e) {
      if (rootRef.current && !rootRef.current.contains(e.target)) setOpen(false);
    }
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const filtered = notifications.filter((n) => {
    if (filter === 'All') return true;
    if (filter === 'Unread') return !n.read;
    return n.type === filter;
  });

  async function handleItemClick(n) {
    if (!n.read) {
      try {
        await markNotificationRead(n._id);
        setNotifications((prev) => prev.map((x) => (x._id === n._id ? { ...x, read: true } : x)));
        setUnreadCount((c) => Math.max(0, c - 1));
      } catch {
        // ignore
      }
    }
    if (n.type === 'ORDER' && onNavigate) onNavigate('Orders');
    else if (n.type === 'MESSAGE' && onNavigate) onNavigate('Messages');
    else if (n.type === 'STOCK' && onNavigate) onNavigate('Inventory');
    setOpen(false);
  }

  async function handleMarkAll() {
    try {
      await markAllNotificationsRead();
      setNotifications((prev) => prev.map((n) => ({ ...n, read: true })));
      setUnreadCount(0);
    } catch {
      // ignore
    }
  }

  return (
    <div className="ap-notif-root" ref={rootRef}>
      <button className="ap-notif-bell" type="button" onClick={() => setOpen((o) => !o)} aria-label="Notifications">
        <Bell size={18} strokeWidth={2.2} />
        {unreadCount > 0 && <span className="ap-notif-badge">{unreadCount > 9 ? '9+' : unreadCount}</span>}
      </button>

      {open && (
        <div className="ap-notif-dropdown">
          <div className="ap-notif-dropdown-header">
            <h4>Notifications</h4>
            {unreadCount > 0 && (
              <button type="button" className="ap-notif-mark-all" onClick={handleMarkAll}>Mark all as read</button>
            )}
          </div>
          <div className="ap-notif-filters">
            {FILTERS.map((f) => (
              <button
                key={f}
                type="button"
                className={`ap-notif-filter ${filter === f ? 'active' : ''}`}
                onClick={() => setFilter(f)}
              >
                {FILTER_LABEL[f]}
              </button>
            ))}
          </div>
          <div className="ap-notif-list">
            {filtered.length === 0 ? (
              <p className="ap-empty-state">No notifications here.</p>
            ) : (
              filtered.map((n) => (
                <div
                  key={n._id}
                  className={`ap-notif-item ${n.read ? '' : 'unread'}`}
                  onClick={() => handleItemClick(n)}
                >
                  <span className="ap-notif-item-icon">
                    {React.createElement(TYPE_ICON[n.type] || Bell, { size: 15, strokeWidth: 2.2 })}
                  </span>
                  <div className="ap-notif-item-body">
                    <div className="ap-notif-item-title">{n.title}</div>
                    {n.body && <div className="ap-notif-item-text">{n.body}</div>}
                    <div className="ap-notif-item-time">{new Date(n.createdAt).toLocaleString()}</div>
                  </div>
                  {!n.read && <span className="ap-notif-item-dot" />}
                </div>
              ))
            )}
          </div>
        </div>
      )}
    </div>
  );
}
