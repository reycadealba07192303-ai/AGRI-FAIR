import React from 'react';
import {
  UserPlus,
  UserMinus,
  ShieldOff,
  ShieldCheck,
  BadgeCheck,
  PencilLine,
  Activity,
  RotateCw,
  ScrollText,
} from 'lucide-react';
import './AuditLogPanel.css';

const AUDIT_ACTIONS = [
  'CREATE_USER',
  'UPDATE_USER',
  'SUSPEND_USER',
  'ACTIVATE_USER',
  'APPROVE_SELLER',
  'DELETE_USER',
];

const ACTION_META = {
  CREATE_USER:    { icon: UserPlus,    tone: 'green',   label: 'Account created' },
  UPDATE_USER:    { icon: PencilLine,  tone: 'neutral', label: 'Account updated' },
  SUSPEND_USER:   { icon: ShieldOff,   tone: 'amber',   label: 'Access suspended' },
  ACTIVATE_USER:  { icon: ShieldCheck, tone: 'teal',    label: 'Access restored' },
  APPROVE_SELLER: { icon: BadgeCheck,  tone: 'gold',    label: 'Seller approved' },
  DELETE_USER:    { icon: UserMinus,   tone: 'red',     label: 'Account deleted' },
};

function metaFor(action) {
  return ACTION_META[action] || { icon: Activity, tone: 'neutral', label: action.replace(/_/g, ' ') };
}

function relativeTime(value) {
  const then = new Date(value);
  const mins = Math.round((Date.now() - then.getTime()) / 60000);

  if (mins < 1) return 'Just now';
  if (mins < 60) return `${mins}m ago`;

  const hours = Math.round(mins / 60);
  if (hours < 24) return `${hours}h ago`;

  return then.toLocaleTimeString('en-PH', { hour: 'numeric', minute: '2-digit' });
}

function exactTime(value) {
  return new Date(value).toLocaleString('en-PH', {
    year: 'numeric', month: 'short', day: 'numeric',
    hour: 'numeric', minute: '2-digit',
  });
}

/** "Today" / "Yesterday" / "August 21, 2026" — the heading entries group under. */
function dayLabel(value) {
  const d = new Date(value);
  const today = new Date();
  const yesterday = new Date();
  yesterday.setDate(today.getDate() - 1);

  const sameDay = (a, b) => a.toDateString() === b.toDateString();
  if (sameDay(d, today)) return 'Today';
  if (sameDay(d, yesterday)) return 'Yesterday';

  return d.toLocaleDateString('en-PH', { month: 'long', day: 'numeric', year: 'numeric' });
}

const Who = ({ children }) => <span className="al-who">{children}</span>;

/**
 * The headline says WHAT happened to WHOM. The icon already carries the action
 * type and the meta line carries WHO did it, so nothing is stated twice — the
 * old table repeated the verb in both the pill and the sentence.
 */
function headlineFor(log) {
  const target = <Who>{log.targetName}</Who>;
  const role = log.targetRole ? `${log.targetRole} ` : '';

  switch (log.action) {
    case 'CREATE_USER':
      return <>{target} was added as a new {role}account.</>;
    case 'UPDATE_USER':
      return <>{target} had their account details updated.</>;
    case 'SUSPEND_USER':
      return <>{target} was suspended and can no longer sign in.</>;
    case 'ACTIVATE_USER':
      return <>Access was restored for {target}.</>;
    case 'APPROVE_SELLER':
      return <>{target} was approved as a verified seller.</>;
    case 'DELETE_USER':
      return <>{target} was permanently removed from the platform.</>;
    default:
      return <>{target} — {log.action.replace(/_/g, ' ').toLowerCase()}.</>;
  }
}

/** Consecutive entries from the same calendar day share one heading. */
function groupByDay(items) {
  const groups = [];
  for (const log of items) {
    const label = dayLabel(log.createdAt);
    const last = groups[groups.length - 1];
    if (last && last.label === label) last.items.push(log);
    else groups.push({ label, items: [log] });
  }
  return groups;
}

export default function AuditLogPanel({
  logs,
  loading,
  page,
  totalPages,
  actionFilter,
  onFilterChange,
  onRefresh,
  onLoadMore,
}) {
  const isEmpty = !loading && logs.length === 0;
  const groups = groupByDay(logs);

  return (
    <section className="al-panel">
      <header className="al-head">
        <div className="al-head-text">
          <span className="al-tag">History</span>
          <h2>Audit logs</h2>
        </div>

        <div className="al-head-actions">
          <select
            className="al-select"
            value={actionFilter}
            onChange={(e) => onFilterChange(e.target.value)}
            aria-label="Filter by action"
          >
            <option value="">All actions</option>
            {AUDIT_ACTIONS.map((a) => (
              <option key={a} value={a}>{metaFor(a).label}</option>
            ))}
          </select>
          <button className="al-refresh" type="button" onClick={onRefresh} disabled={loading}>
            <RotateCw size={15} strokeWidth={2.3} className={loading ? 'al-spin' : ''} />
            Refresh
          </button>
        </div>
      </header>

      {isEmpty ? (
        <div className="al-empty">
          <ScrollText size={30} strokeWidth={1.6} />
          <p>
            {actionFilter
              ? 'No entries match this filter yet.'
              : 'No account activity has been recorded yet.'}
          </p>
        </div>
      ) : (
        <div className="al-scroll">
          {loading && logs.length === 0 ? (
            <div className="al-loading">
              {[0, 1, 2, 3, 4].map((i) => <div key={i} className="al-skeleton" />)}
            </div>
          ) : (
            groups.map((group) => (
              <div className="al-group" key={group.label}>
                <div className="al-day">{group.label}</div>

                {group.items.map((log) => {
                  const meta = metaFor(log.action);
                  const Icon = meta.icon;
                  const showEmail = log.targetEmail && log.targetEmail !== log.targetName;

                  return (
                    <article className="al-entry" key={log.id}>
                      <span className={`al-icon al-icon--${meta.tone}`}>
                        <Icon size={15} strokeWidth={2.3} />
                      </span>

                      <div className="al-entry-body">
                        <p className="al-headline">{headlineFor(log)}</p>
                        <p className="al-meta">
                          <span>by {log.adminName}</span>
                          {showEmail && <span className="al-sep">{log.targetEmail}</span>}
                          {log.targetDeleted && log.action !== 'DELETE_USER' && (
                            <span className="al-sep">account since removed</span>
                          )}
                        </p>
                      </div>

                      <time
                        className="al-time"
                        dateTime={log.createdAt}
                        title={exactTime(log.createdAt)}
                      >
                        {relativeTime(log.createdAt)}
                      </time>
                    </article>
                  );
                })}
              </div>
            ))
          )}

          {page < totalPages && (
            <div className="al-more">
              <button type="button" onClick={onLoadMore} disabled={loading}>
                {loading ? 'Loading…' : 'Load older entries'}
              </button>
            </div>
          )}
        </div>
      )}
    </section>
  );
}
