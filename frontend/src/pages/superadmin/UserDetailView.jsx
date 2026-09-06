import React, { useEffect, useMemo } from 'react';
import {
  ArrowLeft,
  Pencil,
  ShieldCheck,
  ShieldOff,
  CalendarRange,
  CalendarDays,
  Users,
  Receipt,
  TrendingUp,
  TrendingDown,
  Minus,
  CheckCircle2,
  AlertTriangle,
  Lightbulb,
  Inbox,
  Info,
} from 'lucide-react';
import './UserDetailView.css';

const PESO = '₱';

function peso(n) {
  return `${PESO}${Number(n || 0).toLocaleString('en-PH', { maximumFractionDigits: 0 })}`;
}

function shortDate(value) {
  if (!value) return '—';
  return new Date(value).toLocaleDateString('en-PH', { month: 'short', day: 'numeric', year: 'numeric' });
}

function initialsOf(name, email) {
  const source = (name || email || '?').trim();
  const parts = source.split(/\s+/).filter(Boolean);
  if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
  return source.slice(0, 2).toUpperCase();
}

/** Percentage change between the two most recent buckets in a series. */
function trendOf(series, key = 'income') {
  if (!series || series.length < 2) return null;
  const latest = series[series.length - 1][key];
  const previous = series[series.length - 2][key];
  if (!previous) return latest > 0 ? { dir: 'up', pct: 100 } : null;
  const pct = Math.round(((latest - previous) / previous) * 100);
  if (pct === 0) return { dir: 'flat', pct: 0 };
  return { dir: pct > 0 ? 'up' : 'down', pct: Math.abs(pct) };
}

function Delta({ trend, unit }) {
  if (!trend) return <span className="uv-delta flat">No prior period</span>;
  const Icon = trend.dir === 'up' ? TrendingUp : trend.dir === 'down' ? TrendingDown : Minus;
  return (
    <>
      <span className={`uv-delta ${trend.dir}`}>
        <Icon size={13} strokeWidth={2.5} />
        {trend.pct}%
      </span>
      <span>vs previous {unit}</span>
    </>
  );
}

function EmptyState({ icon, children }) {
  const Icon = icon || Inbox;
  return (
    <div className="uv-empty">
      <Icon size={28} strokeWidth={1.6} />
      <p>{children}</p>
    </div>
  );
}

export default function UserDetailView({
  user,
  analytics,
  loading,
  onClose,
  onEdit,
  onToggleStatus,
}) {
  // Escape closes the workspace; body scroll is locked while it is open.
  useEffect(() => {
    const onKey = (e) => {
      if (e.key === 'Escape') onClose();
    };
    document.addEventListener('keydown', onKey);
    const prevOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    return () => {
      document.removeEventListener('keydown', onKey);
      document.body.style.overflow = prevOverflow;
    };
  }, [onClose]);

  const isSeller = user.role === 'seller';
  const status = (user.status || 'active').toLowerCase();
  const hasData = Boolean(analytics && analytics.applicable);

  const monthly = useMemo(() => analytics?.monthlyIncome || [], [analytics]);
  const weekly = useMemo(() => analytics?.weeklyIncome || [], [analytics]);
  const clients = analytics?.clients || { total: 0, repeat: 0, newLast30: 0, repeatRate: 0 };
  const orders = analytics?.recentOrders || [];
  const topClients = analytics?.topClients || [];

  const monthTrend = useMemo(() => trendOf(monthly), [monthly]);
  const weekTrend = useMemo(() => trendOf(weekly), [weekly]);

  const thisMonth = monthly.length ? monthly[monthly.length - 1] : null;
  const thisWeek = weekly.length ? weekly[weekly.length - 1] : null;

  const strengths = analytics?.strengths || [];
  const weaknesses = analytics?.weaknesses || [];
  const suggestions = analytics?.suggestions || [];

  return (
    <div className="uv-overlay" role="dialog" aria-modal="true" aria-label={`Account detail for ${user.name || user.email}`}>
      <header className="uv-topbar">
        <button
          type="button"
          className="uv-backlink"
          onClick={onClose}
          aria-label="Back to directory"
          title="Back to directory"
        >
          <ArrowLeft size={22} strokeWidth={2.2} />
        </button>

        <div className="uv-topbar-title">
          <span className="uv-topbar-eyebrow">Account detail</span>
          <span className="uv-topbar-name">{user.name || user.email}</span>
        </div>

        <div className="uv-topbar-spacer" />

        <div className="uv-topbar-actions">
          <button type="button" className="uv-back" onClick={() => onEdit(user)}>
            <Pencil size={15} strokeWidth={2.3} />
            <span className="uv-hide-sm">Edit</span>
          </button>
          {user.role !== 'superadmin' && (
            <button type="button" className="uv-back" onClick={() => onToggleStatus(user)}>
              {status === 'suspended' ? <ShieldCheck size={15} strokeWidth={2.3} /> : <ShieldOff size={15} strokeWidth={2.3} />}
              <span className="uv-hide-sm">{status === 'suspended' ? 'Activate' : 'Suspend'}</span>
            </button>
          )}
        </div>
      </header>

      <div className="uv-body">
        <div className="uv-grid">
          {/* ---------------- Left rail ---------------- */}
          <aside className="uv-rail">
            <section className="uv-card uv-identity">
              <div className="uv-avatar">
                {user.avatarUrl ? (
                  <img src={user.avatarUrl} alt="" />
                ) : (
                  initialsOf(user.name, user.email)
                )}
              </div>
              <h2 className="uv-identity-name">{user.name || 'Unnamed account'}</h2>
              <p className="uv-identity-email">{user.email}</p>
              <div className="uv-identity-tags">
                <span className="uv-tag uv-tag-role">{user.role || 'buyer'}</span>
                <span className={`uv-tag uv-tag-${status}`}>{status}</span>
              </div>
            </section>

            <section className="uv-card">
              <div className="uv-card-head">
                <h3>Information</h3>
              </div>
              <div className="uv-card-body">
                <dl className="uv-info-list">
                  <div className="uv-info-row">
                    <dt>User ID</dt>
                    <dd>{user.userId ?? '—'}</dd>
                  </div>
                  <div className="uv-info-row">
                    <dt>Verified</dt>
                    <dd>{user.emailVerified ? 'Yes' : 'No'}</dd>
                  </div>
                  <div className="uv-info-row">
                    <dt>Joined</dt>
                    <dd>{shortDate(user.createdAt)}</dd>
                  </div>
                  <div className="uv-info-row">
                    <dt>Last login</dt>
                    <dd>{shortDate(user.lastLogin)}</dd>
                  </div>
                </dl>
              </div>
            </section>
          </aside>

          {/* ---------------- Main ---------------- */}
          <div className="uv-main">
            {!isSeller ? (
              <section className="uv-card">
                <div className="uv-card-body" style={{ paddingTop: '1.15rem' }}>
                  <div className="uv-notice">
                    <Info size={17} strokeWidth={2.2} />
                    <span>
                      Sales analytics are tracked for seller accounts only. This is a{' '}
                      <strong>{user.role}</strong> account, so there is no storefront activity to report.
                    </span>
                  </div>
                </div>
              </section>
            ) : (
              <>
                {/* --- Metric row --- */}
                <div className="uv-metrics">
                  <section className="uv-card uv-metric uv-metric--green">
                    <div className="uv-metric-head">
                      <span className="uv-metric-icon"><CalendarRange size={22} strokeWidth={2.2} /></span>
                      <span className="uv-metric-label">Monthly sales</span>
                    </div>
                    {loading ? (
                      <div className="uv-skeleton" style={{ height: 32, width: '60%' }} />
                    ) : (
                      <>
                        <div className="uv-metric-value">
                          <small>{PESO}</small>
                          {Number(thisMonth?.income || 0).toLocaleString('en-PH', { maximumFractionDigits: 0 })}
                        </div>
                        <div className="uv-metric-foot">
                          <Delta trend={monthTrend} unit="month" />
                        </div>
                      </>
                    )}
                  </section>

                  <section className="uv-card uv-metric uv-metric--gold">
                    <div className="uv-metric-head">
                      <span className="uv-metric-icon"><CalendarDays size={22} strokeWidth={2.2} /></span>
                      <span className="uv-metric-label">Weekly sales</span>
                    </div>
                    {loading ? (
                      <div className="uv-skeleton" style={{ height: 32, width: '60%' }} />
                    ) : (
                      <>
                        <div className="uv-metric-value">
                          <small>{PESO}</small>
                          {Number(thisWeek?.income || 0).toLocaleString('en-PH', { maximumFractionDigits: 0 })}
                        </div>
                        <div className="uv-metric-foot">
                          <Delta trend={weekTrend} unit="week" />
                        </div>
                      </>
                    )}
                  </section>

                  <section className="uv-card uv-metric uv-metric--teal">
                    <div className="uv-metric-head">
                      <span className="uv-metric-icon"><Users size={22} strokeWidth={2.2} /></span>
                      <span className="uv-metric-label">Clients</span>
                    </div>
                    {loading ? (
                      <div className="uv-skeleton" style={{ height: 32, width: '40%' }} />
                    ) : (
                      <>
                        <div className="uv-metric-value">{clients.total}</div>
                        <div className="uv-metric-foot">
                          <span>{clients.total === 1 ? 'customer has' : 'customers have'} bought from this seller</span>
                        </div>
                      </>
                    )}
                  </section>
                </div>

                {/* --- Order history + analysis --- */}
                <div className="uv-split">
                  <section className="uv-card">
                    <div className="uv-card-head">
                      <div>
                        <h3>Order history</h3>
                        <p className="uv-card-sub">Who bought what, newest first</p>
                      </div>
                      <span className="uv-cell-muted">
                        {orders.length ? `${orders.length} shown` : ''}
                      </span>
                    </div>
                    <div className="uv-card-body">
                      {loading ? (
                        <div style={{ display: 'grid', gap: 8 }}>
                          {[0, 1, 2, 3].map((i) => (
                            <div key={i} className="uv-skeleton" style={{ height: 38 }} />
                          ))}
                        </div>
                      ) : orders.length === 0 ? (
                        <EmptyState icon={Receipt}>
                          No orders recorded for this seller yet. Order history appears here as soon as
                          buyers start purchasing.
                        </EmptyState>
                      ) : (
                        <div className="uv-table-wrap">
                          <table className="uv-table">
                            <thead>
                              <tr>
                                <th>Buyer</th>
                                <th>Product</th>
                                <th style={{ textAlign: 'right' }}>Qty</th>
                                <th style={{ textAlign: 'right' }}>Total</th>
                                <th>Status</th>
                                <th>Date</th>
                              </tr>
                            </thead>
                            <tbody>
                              {orders.map((o) => (
                                <tr key={o.id}>
                                  <td>
                                    <div className="uv-buyer">
                                      <span className="uv-buyer-dot">{initialsOf(o.customerName)}</span>
                                      <span className="uv-cell-strong">{o.customerName || 'Walk-in'}</span>
                                    </div>
                                  </td>
                                  <td>{o.productName}</td>
                                  <td className="uv-cell-num">{o.quantity}</td>
                                  <td className="uv-cell-num uv-cell-strong">{peso(o.total)}</td>
                                  <td>
                                    <span className={`uv-status uv-status-${
                                      ['completed', 'pending', 'cancelled'].includes(o.status) ? o.status : 'default'
                                    }`}>
                                      {o.status}
                                    </span>
                                  </td>
                                  <td className="uv-cell-muted">{shortDate(o.orderDate)}</td>
                                </tr>
                              ))}
                            </tbody>
                          </table>
                        </div>
                      )}

                      {!loading && topClients.length > 0 && (
                        <div style={{ marginTop: '1.25rem' }}>
                          <p className="uv-analysis-title">
                            <Users size={13} strokeWidth={2.4} /> Top clients by spend
                          </p>
                          {topClients.map((c) => (
                            <div className="uv-client-row" key={`${c.name}-${c.buyerUserId ?? 'guest'}`}>
                              <span className="uv-buyer-dot">{initialsOf(c.name)}</span>
                              <span className="uv-client-name">{c.name}</span>
                              <span className="uv-client-meta">
                                {c.orders} order{c.orders === 1 ? '' : 's'}
                              </span>
                              <span className="uv-client-spent">{peso(c.spent)}</span>
                            </div>
                          ))}
                        </div>
                      )}
                    </div>
                  </section>

                  <section className="uv-card">
                    <div className="uv-card-head">
                      <div>
                        <h3>Business analytics</h3>
                        <p className="uv-card-sub">What the numbers say, and what to do</p>
                      </div>
                    </div>
                    <div className="uv-card-body">
                      {loading ? (
                        <div style={{ display: 'grid', gap: 8 }}>
                          {[0, 1, 2].map((i) => (
                            <div key={i} className="uv-skeleton" style={{ height: 46 }} />
                          ))}
                        </div>
                      ) : !hasData ? (
                        <EmptyState icon={AlertTriangle}>
                          Analytics could not be loaded for this account.
                        </EmptyState>
                      ) : (
                        <>
                          <div className="uv-analysis-group">
                            <p className="uv-analysis-title">
                              <CheckCircle2 size={13} strokeWidth={2.4} /> Strengths
                            </p>
                            {strengths.length === 0 ? (
                              <div className="uv-finding uv-finding-neutral">
                                <Minus size={15} strokeWidth={2.3} />
                                <span>Not enough completed sales to identify a strength yet.</span>
                              </div>
                            ) : (
                              strengths.map((text) => (
                                <div className="uv-finding uv-finding-good" key={text}>
                                  <CheckCircle2 size={15} strokeWidth={2.3} />
                                  <span>{text}</span>
                                </div>
                              ))
                            )}
                          </div>

                          <div className="uv-analysis-group">
                            <p className="uv-analysis-title">
                              <AlertTriangle size={13} strokeWidth={2.4} /> Weak points
                            </p>
                            {weaknesses.length === 0 ? (
                              <div className="uv-finding uv-finding-good">
                                <CheckCircle2 size={15} strokeWidth={2.3} />
                                <span>No weak points detected in the current data.</span>
                              </div>
                            ) : (
                              weaknesses.map((text) => (
                                <div className="uv-finding uv-finding-bad" key={text}>
                                  <AlertTriangle size={15} strokeWidth={2.3} />
                                  <span>{text}</span>
                                </div>
                              ))
                            )}
                          </div>

                          <div className="uv-analysis-group">
                            <p className="uv-analysis-title">
                              <Lightbulb size={13} strokeWidth={2.4} /> Recommended actions
                            </p>
                            {suggestions.length === 0 ? (
                              <div className="uv-action">
                                <Lightbulb size={15} strokeWidth={2.3} />
                                <span>Nothing urgent. Keep monitoring weekly sales for changes.</span>
                              </div>
                            ) : (
                              suggestions.map((s) => (
                                <div className="uv-action" key={s.type}>
                                  <Lightbulb size={15} strokeWidth={2.3} />
                                  <span>{s.message}</span>
                                </div>
                              ))
                            )}
                          </div>
                        </>
                      )}
                    </div>
                  </section>
                </div>
              </>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
