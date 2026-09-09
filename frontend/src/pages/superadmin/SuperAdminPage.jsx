import React, { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import './SuperAdminPage.css';
import logoImg from '../../assets/logo.png';
import {
  LayoutGrid,
  Users,
  BarChart3,
  Settings as SettingsIcon,
  ShoppingCart,
  CheckCircle2,
  Clock,
  Menu,
  X,
  ScrollText,
  BadgeCheck,
  Eye,
  Pencil,
  Trash2,
  Plus,
  Download,
  ShieldCheck,
  ShieldOff,
  CalendarDays,
} from 'lucide-react';
import {
  fetchAllUsers,
  suspendUser,
  activateUser,
  approveSeller,
  fetchPendingApprovals,
  deleteUserAccount,
  createUserAccount,
  updateUserAccount,
  fetchAuditLogs,
  fetchUserAnalytics,
  fetchPlatformRevenue,
} from '../../services/superAdminApi';
import AuditLogPanel from './AuditLogPanel';
import CredentialsPanel from './CredentialsPanel';
import BusinessAnalytics from './BusinessAnalytics';
import SettingsPanel from './SettingsPanel';
import RowActionsMenu from './RowActionsMenu';
import UserDetailView from './UserDetailView';
import { clearSession, getSessionUser } from '../../utils/auth';
import { exportToCsv } from '../../utils/csv';

const TABS = [
  { id: 'Overview', icon: LayoutGrid, label: 'Overview' },
  { id: 'UserManagement', icon: Users, label: 'User Management' },
  { id: 'Credentials', icon: BadgeCheck, label: 'Credentials' },
  { id: 'AuditLogs', icon: ScrollText, label: 'Audit Logs' },
  { id: 'Analytics', icon: BarChart3, label: 'Analytics' },
  { id: 'Settings', icon: SettingsIcon, label: 'Settings' },
];

const ROLE_FILTERS = [
  { value: 'all', label: 'All' },
  { value: 'superadmin', label: 'Admin' },
  { value: 'seller', label: 'Seller' },
  { value: 'buyer', label: 'Buyer' },
];

const EMPTY_USER_FORM = { name: '', email: '', password: '', role: 'seller', status: 'active' };

export default function SuperAdminPage({ onLogout }) {
  const navigate = useNavigate();
  const [user, setUser] = useState({ email: '', role: 'superadmin', name: '' });
  const [activeTab, setActiveTab] = useState('Overview');
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [showLogout, setShowLogout] = useState(false);
  const [accounts, setAccounts] = useState([]);
  const [pending, setPending] = useState([]);
  const [roleFilter, setRoleFilter] = useState('all');
  const [loadingAccounts, setLoadingAccounts] = useState(false);
  const [accountsError, setAccountsError] = useState('');
  const [revenue, setRevenue] = useState(0);

  // Create / edit account modal
  const [showUserModal, setShowUserModal] = useState(false);
  const [editingUser, setEditingUser] = useState(null);
  const [userForm, setUserForm] = useState(EMPTY_USER_FORM);
  const [savingUser, setSavingUser] = useState(false);
  const [userFormError, setUserFormError] = useState('');

  // Delete confirm
  const [deleteTarget, setDeleteTarget] = useState(null);

  // Per-user detail view
  const [detailUser, setDetailUser] = useState(null);
  const [detailAnalytics, setDetailAnalytics] = useState(null);
  const [detailLoading, setDetailLoading] = useState(false);

  // Audit logs
  const [auditLogs, setAuditLogs] = useState([]);
  const [auditPage, setAuditPage] = useState(1);
  const [auditTotalPages, setAuditTotalPages] = useState(1);
  const [auditActionFilter, setAuditActionFilter] = useState('');
  const [auditLoading, setAuditLoading] = useState(false);

  useEffect(() => {
    const sessionUser = getSessionUser();
    if (sessionUser) setUser(sessionUser);
  }, []);

  useEffect(() => {
    if (activeTab === 'UserManagement' || activeTab === 'Overview') {
      loadAccounts();
    }
    if (activeTab === 'Overview') {
      fetchPlatformRevenue()
        .then((res) => setRevenue(res.data?.total || 0))
        .catch(() => setRevenue(0));
    }
    if (activeTab === 'AuditLogs') {
      loadAuditLogs(1, false);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeTab]);

  async function loadAccounts() {
    setLoadingAccounts(true);
    setAccountsError('');
    try {
      const [usersRes, pendingRes] = await Promise.all([
        fetchAllUsers(),
        fetchPendingApprovals().catch(() => ({ data: [] })),
      ]);
      const list = usersRes.data?.users || usersRes.data || [];
      setAccounts(Array.isArray(list) ? list : []);
      const pendingList = pendingRes.data?.users || pendingRes.data || [];
      setPending(Array.isArray(pendingList) ? pendingList : []);
    } catch (err) {
      setAccountsError(
        err.response?.data?.error || err.response?.data?.message || 'Failed to load accounts'
      );
    } finally {
      setLoadingAccounts(false);
    }
  }

  async function loadAuditLogs(page, append, actionOverride) {
    const action = actionOverride !== undefined ? actionOverride : auditActionFilter;
    setAuditLoading(true);
    try {
      const res = await fetchAuditLogs({ page, limit: 20, action: action || undefined });
      const data = res.data || {};
      setAuditLogs((prev) => (append ? [...prev, ...(data.logs || [])] : data.logs || []));
      setAuditPage(data.page || 1);
      setAuditTotalPages(data.totalPages || 1);
    } catch {
      if (!append) setAuditLogs([]);
    } finally {
      setAuditLoading(false);
    }
  }

  function handleLogout() {
    clearSession();
    if (onLogout) onLogout();
    navigate('/login');
  }

  const counts = useMemo(() => {
    const sellers = accounts.filter((u) => u.role === 'seller').length;
    const buyers = accounts.filter((u) => u.role === 'buyer').length;
    const activeSellers = accounts.filter((u) => u.role === 'seller' && u.status === 'active').length;
    return { sellers, buyers, activeSellers, total: accounts.length };
  }, [accounts]);

  const filteredAccounts = useMemo(() => {
    if (roleFilter === 'all') return accounts;
    return accounts.filter((u) => u.role === roleFilter);
  }, [accounts, roleFilter]);

  const initials = user.email ? user.email.slice(0, 2).toUpperCase() : 'SA';
  const displayName = user.name || user.email?.split('@')[0] || 'Admin';
  const now = new Date();
  const todayWeekday = now.toLocaleDateString('en-PH', { weekday: 'long' });
  const todayDate = now.toLocaleDateString('en-PH', {
    month: 'long',
    day: 'numeric',
    year: 'numeric',
  });

  const overviewStats = [
    { label: 'Sellers', value: counts.sellers, icon: Users, tone: 'green' },
    { label: 'Buyers', value: counts.buyers, icon: ShoppingCart, tone: 'gold' },
    { label: 'Active sellers', value: counts.activeSellers, icon: CheckCircle2, tone: 'teal' },
    { label: 'Pending', value: pending.length, icon: Clock, tone: 'coral' },
  ];

  const approvalRate = counts.sellers
    ? Math.round((counts.activeSellers / counts.sellers) * 100)
    : 0;

  function pct(part, whole) {
    return whole ? Math.round((part / whole) * 100) : 0;
  }

  // --- Account CRUD handlers ---
  function openCreateUser() {
    setEditingUser(null);
    setUserForm(EMPTY_USER_FORM);
    setUserFormError('');
    setShowUserModal(true);
  }

  function openEditUser(u) {
    setEditingUser(u);
    setUserForm({
      name: u.name || '',
      email: u.email || '',
      password: '',
      role: u.role || 'seller',
      status: u.status || 'active',
    });
    setUserFormError('');
    setShowUserModal(true);
  }

  function closeUserModal() {
    setShowUserModal(false);
    setEditingUser(null);
    setUserForm(EMPTY_USER_FORM);
    setUserFormError('');
  }

  async function handleUserFormSubmit(e) {
    e.preventDefault();
    setUserFormError('');

    if (!userForm.name.trim() || !userForm.email.trim()) {
      setUserFormError('Name and email are required.');
      return;
    }
    if (!editingUser && !userForm.password) {
      setUserFormError('Password is required for a new account.');
      return;
    }

    setSavingUser(true);
    try {
      if (editingUser) {
        const targetId = editingUser.userId ?? editingUser._id;
        const payload = { name: userForm.name, email: userForm.email, role: userForm.role, status: userForm.status };
        if (userForm.password) payload.password = userForm.password;
        await updateUserAccount(targetId, payload);
      } else {
        await createUserAccount(userForm);
      }
      closeUserModal();
      await loadAccounts();
    } catch (err) {
      setUserFormError(err.response?.data?.error || err.response?.data?.message || 'Could not save this account.');
    } finally {
      setSavingUser(false);
    }
  }

  async function handleToggleStatus(u) {
    const id = u.userId ?? u._id;
    const nextStatus = u.status === 'suspended' ? 'active' : 'suspended';
    try {
      if (u.status === 'suspended') {
        await activateUser(id);
      } else {
        await suspendUser(id);
      }
      // Keep the open detail view in sync with the change we just made.
      setDetailUser((prev) => (prev && (prev.userId ?? prev._id) === id ? { ...prev, status: nextStatus } : prev));
      await loadAccounts();
    } catch (err) {
      setAccountsError(
        err.response?.data?.error || err.response?.data?.message || 'Could not update this account.'
      );
    }
  }

  async function handleConfirmDelete() {
    if (!deleteTarget) return;
    const deletedId = deleteTarget.userId ?? deleteTarget._id;
    try {
      await deleteUserAccount(deletedId);
      setDeleteTarget(null);
      // If the deleted account is the one on screen, leave the detail workspace.
      setDetailUser((prev) => (prev && (prev.userId ?? prev._id) === deletedId ? null : prev));
      await loadAccounts();
    } catch {
      setDeleteTarget(null);
    }
  }

  async function openDetail(u) {
    setDetailUser(u);
    setDetailAnalytics(null);
    if (u.role === 'seller') {
      setDetailLoading(true);
      try {
        const res = await fetchUserAnalytics(u.userId ?? u._id);
        setDetailAnalytics(res.data);
      } catch {
        setDetailAnalytics(null);
      } finally {
        setDetailLoading(false);
      }
    }
  }

  function closeDetail() {
    setDetailUser(null);
    setDetailAnalytics(null);
  }

  function handleExportCsv() {
    exportToCsv(
      'agrifair-accounts.csv',
      filteredAccounts.map((u) => ({
        userId: u.userId ?? '',
        name: u.name || '',
        email: u.email || '',
        role: u.role || '',
        status: u.status || '',
        joined: u.createdAt ? new Date(u.createdAt).toLocaleDateString() : '',
      })),
      [
        { key: 'userId', label: 'User ID' },
        { key: 'name', label: 'Name' },
        { key: 'email', label: 'Email' },
        { key: 'role', label: 'Role' },
        { key: 'status', label: 'Status' },
        { key: 'joined', label: 'Joined' },
      ]
    );
  }

  function renderContent() {
    switch (activeTab) {
      case 'Overview':
        return (
          <div className="sa-tab">
            <section className="sa-revenue-hero">
              <div className="sa-revenue-hero-glow" aria-hidden="true" />
              <div className="sa-revenue-top">
                <span className="sa-revenue-eyebrow">Ecosystem revenue</span>
                <span className="sa-revenue-period">All-time</span>
              </div>
              <div className="sa-revenue-value">
                <span className="sa-revenue-currency">₱</span>
                {Number(revenue).toLocaleString('en-PH', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
              </div>
              <p className="sa-revenue-note">
                Total money moved across the AgriFair platform, from completed sales recorded by sellers.
              </p>
              <div className="sa-revenue-chips">
                <div className="sa-revenue-chip">
                  <span className="sa-revenue-chip-label">Total accounts</span>
                  <span className="sa-revenue-chip-value">{counts.total}</span>
                </div>
                <div className="sa-revenue-chip">
                  <span className="sa-revenue-chip-label">Sellers active</span>
                  <span className="sa-revenue-chip-value">{approvalRate}%</span>
                </div>
                <div className="sa-revenue-chip">
                  <span className="sa-revenue-chip-label">Pending approvals</span>
                  <span className="sa-revenue-chip-value">{pending.length}</span>
                </div>
              </div>
            </section>

            <section className="sa-stats">
              {overviewStats.map((s) => (
                <article key={s.label} className={`sa-stat-v2 sa-stat-v2--${s.tone}`}>
                  <div className="sa-stat-v2-icon">
                    <s.icon size={20} strokeWidth={2.25} />
                  </div>
                  <div className="sa-stat-v2-body">
                    <div className="sa-stat-v2-value">{s.value}</div>
                    <div className="sa-stat-v2-label">{s.label}</div>
                  </div>
                </article>
              ))}
            </section>

            <section className="sa-grid-2">
              <div className="sa-panel">
                <div className="sa-panel-head">
                  <div>
                    <span className="sa-panel-tag">Activity</span>
                    <h2>Recent activity</h2>
                  </div>
                </div>
                {pending.length === 0 && accounts.length === 0 ? (
                  <p className="sa-empty">
                    Platform activity will show here. Approve sellers from User Management when registrations come in.
                  </p>
                ) : (
                  <div className="sa-table-wrap">
                    <table className="sa-table">
                      <thead>
                        <tr>
                          <th>User</th>
                          <th>Role</th>
                          <th>Status</th>
                        </tr>
                      </thead>
                      <tbody>
                        {(pending.length ? pending : accounts).slice(0, 6).map((u) => (
                          <tr key={u._id || u.userId}>
                            <td>{u.name || u.email}</td>
                            <td>{u.role}</td>
                            <td>
                              <span className={`sa-badge sa-badge-${(u.status || 'active').toLowerCase()}`}>
                                {u.status || 'active'}
                              </span>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                )}
              </div>

              <div className="sa-panel sa-panel-dark">
                <div className="sa-panel-head">
                  <div>
                    <span className="sa-panel-tag">Composition</span>
                    <h2>Role mix</h2>
                  </div>
                </div>
                <div className="sa-progress-list">
                  <div className="sa-progress-item">
                    <div className="sa-progress-meta">
                      <span>Sellers ({counts.sellers} of {counts.total})</span>
                      <span>{pct(counts.sellers, counts.total)}%</span>
                    </div>
                    <div className="sa-progress-track">
                      <div
                        className="sa-progress-fill"
                        style={{ width: `${pct(counts.sellers, counts.total)}%` }}
                      />
                    </div>
                  </div>
                  <div className="sa-progress-item">
                    <div className="sa-progress-meta">
                      <span>Buyers ({counts.buyers} of {counts.total})</span>
                      <span>{pct(counts.buyers, counts.total)}%</span>
                    </div>
                    <div className="sa-progress-track">
                      <div
                        className="sa-progress-fill gold"
                        style={{ width: `${pct(counts.buyers, counts.total)}%` }}
                      />
                    </div>
                  </div>
                  <div className="sa-progress-item">
                    <div className="sa-progress-meta">
                      <span>Active sellers ({counts.activeSellers} of {counts.sellers})</span>
                      <span>{pct(counts.activeSellers, counts.sellers)}%</span>
                    </div>
                    <div className="sa-progress-track">
                      <div
                        className="sa-progress-fill teal"
                        style={{ width: `${pct(counts.activeSellers, counts.sellers)}%` }}
                      />
                    </div>
                  </div>
                  <div className="sa-progress-item">
                    <div className="sa-progress-meta">
                      <span>Pending approvals</span>
                      <span>{pending.length}</span>
                    </div>
                    <div className="sa-progress-track">
                      <div
                        className="sa-progress-fill coral"
                        style={{ width: `${Math.min(100, pending.length * 20)}%` }}
                      />
                    </div>
                  </div>
                </div>
              </div>
            </section>
          </div>
        );

      case 'UserManagement':
        return (
          <div className="sa-tab">
            <section className="sa-panel">
              <div className="sa-panel-head">
                <div>
                  <span className="sa-panel-tag">Directory</span>
                  <h2>User accounts</h2>
                </div>
                <div className="sa-panel-actions">
                  <button className="sa-btn-ghost" type="button" onClick={handleExportCsv}>
                    <Download size={15} strokeWidth={2.25} style={{ marginRight: 6, verticalAlign: -2 }} />
                    Export
                  </button>
                  <button className="sa-btn" type="button" onClick={loadAccounts}>
                    Refresh
                  </button>
                  <button className="sa-btn" type="button" onClick={openCreateUser}>
                    <Plus size={15} strokeWidth={2.5} style={{ marginRight: 6, verticalAlign: -2 }} />
                    New Account
                  </button>
                </div>
              </div>

              <div className="sa-role-pills">
                {ROLE_FILTERS.map((f) => (
                  <button
                    key={f.value}
                    type="button"
                    className={`sa-role-pill ${roleFilter === f.value ? 'active' : ''}`}
                    onClick={() => setRoleFilter(f.value)}
                  >
                    {f.label}
                  </button>
                ))}
              </div>

              {accountsError && <p className="sa-empty">{accountsError}</p>}
              {loadingAccounts && <p className="sa-empty">Loading accounts…</p>}

              {pending.length > 0 && (
                <div style={{ marginBottom: '1.1rem' }}>
                  <h3
                    style={{
                      margin: '0 0 0.7rem',
                      fontFamily: 'Fraunces, serif',
                      fontSize: '1.05rem',
                      fontWeight: 700,
                    }}
                  >
                    Pending seller approvals
                  </h3>
                  <div className="sa-table-wrap">
                    <table className="sa-table">
                      <thead>
                        <tr>
                          <th>Name</th>
                          <th>Email</th>
                          <th>Role</th>
                          <th>Action</th>
                        </tr>
                      </thead>
                      <tbody>
                        {pending.map((u) => (
                          <tr key={u._id || u.userId}>
                            <td>{u.name}</td>
                            <td>{u.email}</td>
                            <td>{u.role}</td>
                            <td>
                              <button
                                className="sa-btn"
                                type="button"
                                onClick={() => approveSeller(u.userId || u._id).then(loadAccounts)}
                              >
                                Approve
                              </button>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>
              )}

              {filteredAccounts.length === 0 && !loadingAccounts ? (
                <p className="sa-empty">No accounts found for this filter.</p>
              ) : (
                <div className="sa-table-wrap">
                  <table className="sa-table">
                    <thead>
                      <tr>
                        <th>ID</th>
                        <th>Name</th>
                        <th>Email</th>
                        <th>Role</th>
                        <th>Status</th>
                        <th>Actions</th>
                      </tr>
                    </thead>
                    <tbody>
                      {filteredAccounts.map((u) => (
                        <tr key={u._id || u.userId}>
                          <td>{u.userId ?? '—'}</td>
                          <td>{u.name}</td>
                          <td>{u.email}</td>
                          <td>{u.role}</td>
                          <td>
                            <span className={`sa-badge sa-badge-${(u.status || 'active').toLowerCase()}`}>
                              {u.status || 'active'}
                            </span>
                          </td>
                          <td>
                            <div className="sa-row-actions">
                              <RowActionsMenu
                                label={`Actions for ${u.name || u.email}`}
                                items={[
                                  { label: 'View details', icon: Eye, onClick: () => openDetail(u) },
                                  { label: 'Edit account', icon: Pencil, onClick: () => openEditUser(u) },
                                  {
                                    label: u.status === 'suspended' ? 'Activate account' : 'Suspend account',
                                    icon: u.status === 'suspended' ? ShieldCheck : ShieldOff,
                                    hidden: u.role === 'superadmin',
                                    separatorBefore: true,
                                    onClick: () => handleToggleStatus(u),
                                  },
                                  {
                                    label: 'Delete user',
                                    icon: Trash2,
                                    danger: true,
                                    hidden: u.userId === user.userId,
                                    separatorBefore: u.role === 'superadmin',
                                    onClick: () => setDeleteTarget(u),
                                  },
                                ]}
                              />
                            </div>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </section>
          </div>
        );

      case 'Credentials':
        return <CredentialsPanel />;

      case 'AuditLogs':
        return (
          <div className="sa-tab">
            <AuditLogPanel
              logs={auditLogs}
              loading={auditLoading}
              page={auditPage}
              totalPages={auditTotalPages}
              actionFilter={auditActionFilter}
              onFilterChange={(val) => {
                setAuditActionFilter(val);
                loadAuditLogs(1, false, val);
              }}
              onRefresh={() => loadAuditLogs(1, false)}
              onLoadMore={() => loadAuditLogs(auditPage + 1, true)}
            />
          </div>
        );

      case 'Analytics':
        return (
          <div className="sa-tab">
            <BusinessAnalytics />
          </div>
        );

      case 'Settings':
        return (
          <div className="sa-tab">
            <SettingsPanel user={user} />
          </div>
        );

      default:
        return null;
    }
  }

  return (
    <div className="sa-root">
      <aside className={`sa-sidebar ${sidebarOpen ? 'open' : ''}`}>
        <button
          className="sa-sidebar-close"
          type="button"
          onClick={() => setSidebarOpen(false)}
          aria-label="Close menu"
        >
          <X size={18} strokeWidth={2.25} />
        </button>

        <div className="sa-brand">
          <img src={logoImg} alt="AgriFair" className="sa-brand-img" />
          <div>
            <div className="sa-brand-text">AgriFair</div>
            <span className="sa-brand-sub">Super Admin</span>
          </div>
        </div>

        <nav className="sa-nav">
          {TABS.map((tab) => (
            <button
              key={tab.id}
              type="button"
              className={`sa-nav-item ${activeTab === tab.id ? 'active' : ''}`}
              onClick={() => {
                setActiveTab(tab.id);
                setSidebarOpen(false);
              }}
            >
              <span className="sa-nav-icon">
                <tab.icon size={17} strokeWidth={2.25} />
              </span>
              {tab.label}
            </button>
          ))}
        </nav>

        <div className="sa-sidebar-foot">
          <div className="sa-user-chip">
            <div className="sa-avatar">{initials}</div>
            <div>
              <div className="sa-user-email">{user.email || 'superadmin@agrifair.ph'}</div>
              <div className="sa-user-role">Super Admin</div>
            </div>
          </div>
          <button className="sa-logout-btn" type="button" onClick={() => setShowLogout(true)}>
            Log out
          </button>
        </div>
      </aside>

      {sidebarOpen && <div className="sa-overlay" onClick={() => setSidebarOpen(false)} />}

      <main className="sa-main">
        <header className="sa-topbar">
          <div style={{ display: 'flex', alignItems: 'center' }}>
            <button
              className="sa-menu-btn"
              type="button"
              onClick={() => setSidebarOpen(true)}
              aria-label="Open menu"
            >
              <Menu size={18} strokeWidth={2.25} />
            </button>
            <div>
              <p className="sa-eyebrow">Platform control</p>
              <p className="sa-greeting">Hello, {displayName}</p>
              <h1 className="sa-topbar-title">Welcome to your dashboard.</h1>
            </div>
          </div>
          <div className="sa-topbar-meta">
            <CalendarDays size={17} strokeWidth={2.2} />
            <div>
              <span className="sa-topbar-meta-day">{todayWeekday}</span>
              <span className="sa-topbar-meta-date">{todayDate}</span>
            </div>
          </div>
        </header>
        <div className="sa-body">{renderContent()}</div>
      </main>

      {showLogout && (
        <div className="sa-modal-overlay">
          <div className="sa-modal">
            <h3>Log out?</h3>
            <p>Leave the Super Admin dashboard?</p>
            <div className="sa-modal-actions">
              <button className="sa-btn-ghost" type="button" onClick={() => setShowLogout(false)}>
                Cancel
              </button>
              <button className="sa-btn-danger" type="button" onClick={handleLogout}>
                Yes, log out
              </button>
            </div>
          </div>
        </div>
      )}

      {showUserModal && (
        <div className="sa-modal-overlay">
          <div className="sa-modal sa-modal-md">
            <h3>{editingUser ? 'Edit account' : 'New account'}</h3>
            {userFormError && <p className="sa-form-error">{userFormError}</p>}
            <form onSubmit={handleUserFormSubmit}>
              <div className="sa-form-grid">
                <div className="sa-form-field">
                  <label>Name *</label>
                  <input
                    type="text"
                    className="sa-input"
                    value={userForm.name}
                    onChange={(e) => setUserForm((f) => ({ ...f, name: e.target.value }))}
                    required
                  />
                </div>
                <div className="sa-form-field">
                  <label>Email *</label>
                  <input
                    type="email"
                    className="sa-input"
                    value={userForm.email}
                    onChange={(e) => setUserForm((f) => ({ ...f, email: e.target.value }))}
                    required
                  />
                </div>
                <div className="sa-form-field">
                  <label>{editingUser ? 'New password (optional)' : 'Password *'}</label>
                  <input
                    type="password"
                    className="sa-input"
                    value={userForm.password}
                    onChange={(e) => setUserForm((f) => ({ ...f, password: e.target.value }))}
                    placeholder={editingUser ? 'Leave blank to keep current' : ''}
                  />
                </div>
                <div className="sa-form-field">
                  <label>Role</label>
                  <select
                    className="sa-select"
                    value={userForm.role}
                    onChange={(e) => setUserForm((f) => ({ ...f, role: e.target.value }))}
                  >
                    <option value="seller">Seller</option>
                    <option value="buyer">Buyer</option>
                    <option value="superadmin">Super admin</option>
                  </select>
                </div>
                <div className="sa-form-field">
                  <label>Status</label>
                  <select
                    className="sa-select"
                    value={userForm.status}
                    onChange={(e) => setUserForm((f) => ({ ...f, status: e.target.value }))}
                  >
                    <option value="active">Active</option>
                    <option value="pending">Pending</option>
                    <option value="suspended">Suspended</option>
                  </select>
                </div>
              </div>
              <div className="sa-modal-actions">
                <button type="button" className="sa-btn-ghost" onClick={closeUserModal}>
                  Cancel
                </button>
                <button type="submit" className="sa-btn" disabled={savingUser}>
                  {savingUser ? 'Saving…' : editingUser ? 'Save changes' : 'Create account'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {deleteTarget && (
        <div className="sa-modal-overlay">
          <div className="sa-modal">
            <h3>Delete account?</h3>
            <p>
              This permanently removes <strong>{deleteTarget.name || deleteTarget.email}</strong> from AgriFair.
              This cannot be undone.
            </p>
            <div className="sa-modal-actions">
              <button className="sa-btn-ghost" type="button" onClick={() => setDeleteTarget(null)}>
                Cancel
              </button>
              <button className="sa-btn-danger" type="button" onClick={handleConfirmDelete}>
                Yes, delete
              </button>
            </div>
          </div>
        </div>
      )}

      {detailUser && (
        <UserDetailView
          user={detailUser}
          analytics={detailAnalytics}
          loading={detailLoading}
          onClose={closeDetail}
          onEdit={(u) => {
            closeDetail();
            openEditUser(u);
          }}
          onToggleStatus={handleToggleStatus}
        />
      )}
    </div>
  );
}
