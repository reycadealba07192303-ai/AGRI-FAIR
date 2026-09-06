import React, { useCallback, useEffect, useState } from 'react';
import {
  UserCog,
  KeyRound,
  Bell,
  History,
  Check,
  AlertCircle,
  Eye,
  EyeOff,
  Monitor,
} from 'lucide-react';
import {
  fetchMe,
  updateAccount,
  changePassword,
  fetchLoginHistory,
} from '../../services/userApi';
import './SettingsPanel.css';

const SECTIONS = [
  { id: 'profile',       icon: UserCog,  label: 'Profile',       hint: 'Name and contact' },
  { id: 'security',      icon: KeyRound, label: 'Security',      hint: 'Password' },
  { id: 'notifications', icon: Bell,     label: 'Notifications', hint: 'What you get alerted about' },
  { id: 'sessions',      icon: History,  label: 'Sign-in history', hint: 'Recent access' },
];

const NOTIFICATION_ROWS = [
  { key: 'order',   label: 'Order activity',   desc: 'New orders and status changes across the platform.' },
  { key: 'payment', label: 'Payments',         desc: 'Payment confirmations and failures.' },
  { key: 'message', label: 'Messages',         desc: 'Direct messages from sellers and buyers.' },
  { key: 'stock',   label: 'Stock warnings',   desc: 'Low or depleted inventory on seller listings.' },
  { key: 'system',  label: 'System notices',   desc: 'Account approvals, suspensions, and platform alerts.' },
];

const DEFAULT_PREFS = { order: true, payment: true, message: true, stock: true, system: true };

function Banner({ tone, children }) {
  if (!children) return null;
  const Icon = tone === 'ok' ? Check : AlertCircle;
  return (
    <div className={`sp-banner sp-wide sp-banner--${tone}`}>
      <Icon size={15} strokeWidth={2.4} />
      <span>{children}</span>
    </div>
  );
}

function Field({ label, hint, wide, children }) {
  return (
    <label className={`sp-field ${wide ? 'sp-wide' : ''}`}>
      <span className="sp-field-label">{label}</span>
      {children}
      {hint && <span className="sp-field-hint">{hint}</span>}
    </label>
  );
}

export default function SettingsPanel({ user }) {
  const [active, setActive] = useState('profile');
  const [me, setMe] = useState(null);
  const [loading, setLoading] = useState(true);

  // Profile
  const [profile, setProfile] = useState({ name: '', contact: '', bio: '' });
  const [savingProfile, setSavingProfile] = useState(false);
  const [profileMsg, setProfileMsg] = useState(null);

  // Password
  const [pw, setPw] = useState({ current: '', next: '', confirm: '' });
  const [showPw, setShowPw] = useState(false);
  const [savingPw, setSavingPw] = useState(false);
  const [pwMsg, setPwMsg] = useState(null);

  // Notifications
  const [prefs, setPrefs] = useState(DEFAULT_PREFS);
  const [savingPrefs, setSavingPrefs] = useState(false);
  const [prefsMsg, setPrefsMsg] = useState(null);

  // Sessions
  const [sessions, setSessions] = useState([]);
  const [sessionsLoading, setSessionsLoading] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const res = await fetchMe();
      const data = res.data?.user || res.data;
      setMe(data);
      setProfile({
        name: data?.name || '',
        contact: data?.contact || '',
        bio: data?.bio || '',
      });
      setPrefs({ ...DEFAULT_PREFS, ...(data?.notificationPrefs || {}) });
    } catch {
      setMe(null);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  useEffect(() => {
    if (active !== 'sessions' || sessions.length) return;
    setSessionsLoading(true);
    fetchLoginHistory()
      .then((res) => setSessions(res.data?.sessions || res.data || []))
      .catch(() => setSessions([]))
      .finally(() => setSessionsLoading(false));
  }, [active, sessions.length]);

  async function saveProfile(e) {
    e.preventDefault();
    setProfileMsg(null);
    if (!profile.name.trim()) {
      setProfileMsg({ tone: 'bad', text: 'Name cannot be empty.' });
      return;
    }
    setSavingProfile(true);
    try {
      await updateAccount(profile);
      setProfileMsg({ tone: 'ok', text: 'Profile saved.' });
      await load();
    } catch (err) {
      setProfileMsg({
        tone: 'bad',
        text: err.response?.data?.error || err.response?.data?.message || 'Could not save your profile.',
      });
    } finally {
      setSavingProfile(false);
    }
  }

  async function savePassword(e) {
    e.preventDefault();
    setPwMsg(null);

    if (!pw.current || !pw.next) {
      setPwMsg({ tone: 'bad', text: 'Enter your current and new password.' });
      return;
    }
    if (pw.next.length < 6) {
      setPwMsg({ tone: 'bad', text: 'New password must be at least 6 characters.' });
      return;
    }
    if (pw.next !== pw.confirm) {
      setPwMsg({ tone: 'bad', text: 'The new passwords do not match.' });
      return;
    }
    if (pw.next === pw.current) {
      setPwMsg({ tone: 'bad', text: 'The new password must be different from the current one.' });
      return;
    }

    setSavingPw(true);
    try {
      await changePassword(pw.current, pw.next);
      setPw({ current: '', next: '', confirm: '' });
      setPwMsg({ tone: 'ok', text: 'Password changed.' });
    } catch (err) {
      setPwMsg({
        tone: 'bad',
        text: err.response?.data?.error || err.response?.data?.message || 'Could not change your password.',
      });
    } finally {
      setSavingPw(false);
    }
  }

  async function savePrefs(next) {
    setPrefs(next);
    setPrefsMsg(null);
    setSavingPrefs(true);
    try {
      await updateAccount({ notificationPrefs: next });
      setPrefsMsg({ tone: 'ok', text: 'Notification preferences saved.' });
    } catch (err) {
      setPrefsMsg({
        tone: 'bad',
        text: err.response?.data?.error || 'Could not save preferences.',
      });
    } finally {
      setSavingPrefs(false);
    }
  }

  const displayName = me?.name || user?.name || user?.email || 'Super Admin';
  const initials = displayName.trim().split(/\s+/).slice(0, 2).map((w) => w[0]).join('').toUpperCase();

  return (
    <div className="sp-root">
      {/* -------- Section rail -------- */}
      <nav className="sp-nav" aria-label="Settings sections">
        <div className="sp-nav-id">
          <span className="sp-nav-avatar">{initials}</span>
          <div>
            <span className="sp-nav-name">{displayName}</span>
            <span className="sp-nav-role">Super Admin</span>
          </div>
        </div>

        {SECTIONS.map((s) => (
          <button
            key={s.id}
            type="button"
            className={`sp-nav-item ${active === s.id ? 'is-active' : ''}`}
            onClick={() => setActive(s.id)}
            aria-current={active === s.id}
          >
            <s.icon size={17} strokeWidth={2.2} />
            <span className="sp-nav-text">
              <span className="sp-nav-label">{s.label}</span>
              <span className="sp-nav-hint">{s.hint}</span>
            </span>
          </button>
        ))}
      </nav>

      {/* -------- Section content -------- */}
      <div className="sp-pane">
        {active === 'profile' && (
          <section className="sp-card">
            <header className="sp-card-head">
              <h3>Profile</h3>
              <p>How your account appears across the platform.</p>
            </header>
            {loading ? (
              <div className="sp-card-body"><div className="sp-skeleton" style={{ height: 180 }} /></div>
            ) : (
              <form className="sp-card-body sp-grid" onSubmit={saveProfile}>
                <Banner tone={profileMsg?.tone}>{profileMsg?.text}</Banner>

                <Field label="Full name">
                  <input
                    className="sp-input"
                    value={profile.name}
                    onChange={(e) => setProfile((p) => ({ ...p, name: e.target.value }))}
                    disabled={savingProfile}
                  />
                </Field>

                <Field label="Email" hint="Email is tied to sign-in and cannot be changed here.">
                  <input className="sp-input" value={me?.email || ''} disabled readOnly />
                </Field>

                <Field label="Contact number">
                  <input
                    className="sp-input"
                    value={profile.contact}
                    onChange={(e) => setProfile((p) => ({ ...p, contact: e.target.value }))}
                    placeholder="09XX XXX XXXX"
                    disabled={savingProfile}
                  />
                </Field>

                <Field label="Bio" wide>
                  <textarea
                    className="sp-input sp-textarea"
                    rows={3}
                    value={profile.bio}
                    onChange={(e) => setProfile((p) => ({ ...p, bio: e.target.value }))}
                    placeholder="A short note about your role."
                    disabled={savingProfile}
                  />
                </Field>

                <div className="sp-actions sp-wide">
                  <button className="sp-btn" type="submit" disabled={savingProfile}>
                    {savingProfile ? 'Saving…' : 'Save changes'}
                  </button>
                </div>
              </form>
            )}
          </section>
        )}

        {active === 'security' && (
          <section className="sp-card">
            <header className="sp-card-head">
              <h3>Password</h3>
              <p>Use at least 6 characters. You will stay signed in after changing it.</p>
            </header>
            <form className="sp-card-body sp-grid" onSubmit={savePassword}>
              <Banner tone={pwMsg?.tone}>{pwMsg?.text}</Banner>

              <Field label="Current password" wide>
                <div className="sp-input-wrap">
                  <input
                    className="sp-input"
                    type={showPw ? 'text' : 'password'}
                    value={pw.current}
                    onChange={(e) => setPw((p) => ({ ...p, current: e.target.value }))}
                    autoComplete="current-password"
                    disabled={savingPw}
                  />
                  <button
                    type="button"
                    className="sp-reveal"
                    onClick={() => setShowPw((v) => !v)}
                    aria-label={showPw ? 'Hide passwords' : 'Show passwords'}
                  >
                    {showPw ? <EyeOff size={15} strokeWidth={2.2} /> : <Eye size={15} strokeWidth={2.2} />}
                  </button>
                </div>
              </Field>

              <Field label="New password">
                <input
                  className="sp-input"
                  type={showPw ? 'text' : 'password'}
                  value={pw.next}
                  onChange={(e) => setPw((p) => ({ ...p, next: e.target.value }))}
                  autoComplete="new-password"
                  disabled={savingPw}
                />
              </Field>

              <Field label="Confirm new password">
                <input
                  className="sp-input"
                  type={showPw ? 'text' : 'password'}
                  value={pw.confirm}
                  onChange={(e) => setPw((p) => ({ ...p, confirm: e.target.value }))}
                  autoComplete="new-password"
                  disabled={savingPw}
                />
              </Field>

              <p className="sp-note sp-wide">
                For safety, password changes are limited to 5 attempts every 15 minutes.
              </p>

              <div className="sp-actions sp-wide">
                <button className="sp-btn" type="submit" disabled={savingPw}>
                  {savingPw ? 'Updating…' : 'Update password'}
                </button>
              </div>
            </form>
          </section>
        )}

        {active === 'notifications' && (
          <section className="sp-card">
            <header className="sp-card-head">
              <h3>Notifications</h3>
              <p>Choose what AgriFair alerts you about. Saved automatically.</p>
            </header>
            <div className="sp-card-body">
              <Banner tone={prefsMsg?.tone}>{prefsMsg?.text}</Banner>

              {NOTIFICATION_ROWS.map((row) => (
                <div className="sp-toggle-row" key={row.key}>
                  <div className="sp-toggle-text">
                    <span className="sp-toggle-label">{row.label}</span>
                    <span className="sp-toggle-desc">{row.desc}</span>
                  </div>
                  <button
                    type="button"
                    role="switch"
                    aria-checked={Boolean(prefs[row.key])}
                    aria-label={row.label}
                    className={`sp-switch ${prefs[row.key] ? 'is-on' : ''}`}
                    disabled={savingPrefs}
                    onClick={() => savePrefs({ ...prefs, [row.key]: !prefs[row.key] })}
                  >
                    <span className="sp-switch-knob" />
                  </button>
                </div>
              ))}
            </div>
          </section>
        )}

        {active === 'sessions' && (
          <section className="sp-card">
            <header className="sp-card-head">
              <h3>Sign-in history</h3>
              <p>Recent sessions recorded for your account.</p>
            </header>
            <div className="sp-card-body">
              {sessionsLoading ? (
                <div className="sp-skeleton" style={{ height: 140 }} />
              ) : sessions.length === 0 ? (
                <div className="sp-empty">
                  <Monitor size={26} strokeWidth={1.6} />
                  <p>No sign-in history recorded yet.</p>
                </div>
              ) : (
                <ul className="sp-sessions">
                  {sessions.slice(0, 12).map((s, i) => (
                    <li key={s._id || i}>
                      <span className="sp-session-dot" />
                      <div className="sp-session-body">
                        <span className="sp-session-time">
                          {new Date(s.loggedInAt || s.createdAt).toLocaleString('en-PH', {
                            month: 'short', day: 'numeric', year: 'numeric',
                            hour: 'numeric', minute: '2-digit',
                          })}
                        </span>
                        <span className="sp-session-agent">{s.userAgent || 'Unknown device'}</span>
                      </div>
                      <span className="sp-session-ip">{s.ipAddress || '—'}</span>
                    </li>
                  ))}
                </ul>
              )}
            </div>
          </section>
        )}
      </div>
    </div>
  );
}
