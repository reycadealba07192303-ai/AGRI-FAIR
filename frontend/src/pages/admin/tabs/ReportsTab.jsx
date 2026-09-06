import {
  Banknote, Timer, Repeat, RefreshCw, CheckCircle2, TrendingDown, TrendingUp,
  Pin, Wheat, Users, CalendarRange, Mail, ClipboardList, Lock, FileText,
  PackageX, AlertTriangle, UserMinus, Coins,
} from 'lucide-react';
import React, { useEffect, useState } from 'react';
import { fetchMyOrderAnalytics, fetchMyOrderBreakdown, emailReport, fetchMailStatus } from '../../../services/clientApi';

const MONTH_LABELS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const TABS = ['Revenue Overview', 'Breakdown', 'Trends'];


/** Each suggestion gets a heading and a tone so the list is scannable. */
const SUGGESTION_META = {
  LOW_STOCK_BESTSELLER: { icon: PackageX,      tone: 'warn', title: 'Restock your best seller' },
  MONTHLY_DECLINE:      { icon: TrendingDown,  tone: 'warn', title: 'Sales dipped this month' },
  NO_RECENT_SALES:      { icon: AlertTriangle, tone: 'bad',  title: 'No sales in 30 days' },
  NO_REPEAT_CLIENTS:    { icon: UserMinus,     tone: 'info', title: 'No repeat customers yet' },
  LOW_ORDER_VALUE:      { icon: Coins,         tone: 'info', title: 'Small average order' },
  DEFAULT:              { icon: Pin,           tone: 'info', title: 'Worth a look' },
};

export default function ReportsTab() {
  const [tab, setTab] = useState('Revenue Overview');
  const [analytics, setAnalytics] = useState(null);
  const [breakdown, setBreakdown] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    let mounted = true;
    (async () => {
      try {
        // Reports are built server-side now, so this page only needs the figures
        // it actually charts.
        const [a, b] = await Promise.all([
          fetchMyOrderAnalytics(),
          fetchMyOrderBreakdown(),
        ]);
        if (!mounted) return;
        setAnalytics(a.data);
        setBreakdown(b.data);
      } catch (err) {
        if (mounted) setError(err.response?.data?.message || 'Analytics will appear once sales are recorded.');
      } finally {
        if (mounted) setLoading(false);
      }
    })();
    return () => { mounted = false; };
  }, []);

  const revenueChange = (() => {
    const m = analytics?.monthlyIncome || [];
    if (m.length < 2) return null;
    const latest = m[m.length - 1].income;
    const prev = m[m.length - 2].income;
    if (!prev) return null;
    return Math.round(((latest - prev) / prev) * 100);
  })();


  const [mailBusy, setMailBusy] = useState(null);
  const [mailMsg, setMailMsg] = useState(null);
  const [mailReady, setMailReady] = useState(null);

  useEffect(() => {
    fetchMailStatus()
      .then((res) => setMailReady(Boolean(res.data?.configured)))
      .catch(() => setMailReady(null));
  }, []);

  async function handleEmail(type) {
    setMailBusy(type);
    setMailMsg(null);
    try {
      const res = await emailReport(type);
      setMailMsg({ ok: true, text: `Sent to ${res.data?.to || 'your email'}. Check your inbox.` });
    } catch (err) {
      setMailMsg({ ok: false, text: err.response?.data?.error || 'Could not send the report.' });
    } finally {
      setMailBusy(null);
    }
  }



  if (loading) {
    return (
      <div className="ap-tab-content">
        <div className="ap-skeleton-grid">
          {[0, 1, 2, 3].map((i) => <div key={i} className="ap-skeleton" style={{ height: 118 }} />)}
        </div>
        <div className="ap-skeleton" style={{ height: 280 }} />
      </div>
    );
  }

  return (
    <div className="ap-tab-content">
      {error && <p className="ap-form-error">{error}</p>}

      <div className="ap-status-tabs">
        {TABS.map((t) => (
          <button key={t} type="button" className={`ap-status-tab ${tab === t ? 'active' : ''}`} onClick={() => setTab(t)}>{t}</button>
        ))}
      </div>

      {tab === 'Revenue Overview' && analytics && (
        <>
          <div className="ap-stats-grid">
            <div className="ap-stat-card ap-stat--green">
              <span className="ap-stat-icon"><Banknote size={20} strokeWidth={2.2} /></span>
              <span className="ap-stat-label">Total revenue</span>
              <span className="ap-stat-value">
                <small>₱</small>{Number(analytics.totalSales).toLocaleString()}
              </span>
              <span className="ap-stat-foot">
                {revenueChange != null ? (
                  <>
                    <span className={`ap-delta ${revenueChange >= 0 ? 'up' : 'down'}`}>
                      {revenueChange >= 0
                        ? <TrendingUp size={13} strokeWidth={2.5} />
                        : <TrendingDown size={13} strokeWidth={2.5} />}
                      {Math.abs(revenueChange)}%
                    </span>
                    vs last month
                  </>
                ) : 'From completed orders only'}
              </span>
            </div>

            <div className="ap-stat-card ap-stat--gold">
              <span className="ap-stat-icon"><Timer size={20} strokeWidth={2.2} /></span>
              <span className="ap-stat-label">Fulfillment time</span>
              <span className="ap-stat-value">
                {breakdown?.avgFulfillmentDays != null ? breakdown.avgFulfillmentDays : '—'}
                {breakdown?.avgFulfillmentDays != null && <small className="ap-stat-unit">days</small>}
              </span>
              <span className="ap-stat-foot">Average from order placed to completed</span>
            </div>

            <div className="ap-stat-card ap-stat--teal">
              <span className="ap-stat-icon"><Repeat size={20} strokeWidth={2.2} /></span>
              <span className="ap-stat-label">Repeat buyers</span>
              <span className="ap-stat-value">
                {breakdown?.repeatBuyerRate != null ? breakdown.repeatBuyerRate : '—'}
                {breakdown?.repeatBuyerRate != null && <small className="ap-stat-unit">%</small>}
              </span>
              <span className="ap-stat-foot">Share of buyers who ordered more than once</span>
            </div>

            <div className="ap-stat-card ap-stat--plum">
              <span className="ap-stat-icon"><RefreshCw size={20} strokeWidth={2.2} /></span>
              <span className="ap-stat-label">Stock turnover</span>
              <span className="ap-stat-value">
                {breakdown?.inventoryTurnover != null ? breakdown.inventoryTurnover : '—'}
                {breakdown?.inventoryTurnover != null && <small className="ap-stat-unit">×</small>}
              </span>
              <span className="ap-stat-foot">How many times your stock sold through</span>
            </div>
          </div>

          <div className="ap-panel">
            <div className="ap-panel-header"><div><span className="ap-panel-tag">Trend</span><h2>Revenue, last 6 months</h2></div></div>
            {analytics.monthlyIncome.length === 0 ? (
              <div className="ap-empty-state">
                <TrendingUp size={26} strokeWidth={1.6} />
                <p>No completed sales yet. Your revenue trend appears once orders are completed.</p>
              </div>
            ) : (
              <div className="ap-income-bars">
                {analytics.monthlyIncome.map((m) => {
                  const max = Math.max(...analytics.monthlyIncome.map((x) => x.income), 1);
                  return (
                    <div className="ap-income-bar-row" key={`${m.year}-${m.month}`}>
                      <span className="ap-income-bar-label">{MONTH_LABELS[m.month - 1]}</span>
                      <div className="ap-income-bar-track">
                        <div className="ap-income-bar-fill" style={{ width: `${Math.max(4, (m.income / max) * 100)}%` }} />
                      </div>
                      <span className="ap-income-bar-value">₱{Number(m.income).toLocaleString()}</span>
                    </div>
                  );
                })}
              </div>
            )}
          </div>

          {analytics.suggestions?.length > 0 && (
            <div className="ap-panel">
              <div className="ap-panel-header">
                <div>
                  <span className="ap-panel-tag">Suggested</span>
                  <h2>What to look at</h2>
                </div>
                <span className="ap-panel-count">
                  {analytics.suggestions.length} item{analytics.suggestions.length === 1 ? '' : 's'}
                </span>
              </div>
              <ul className="ap-suggestion-list">
                {analytics.suggestions.map((sg) => {
                  const meta = SUGGESTION_META[sg.type] || SUGGESTION_META.DEFAULT;
                  const Icon = meta.icon;
                  return (
                    <li key={sg.type} className={`ap-suggestion-item ap-suggestion-item--${meta.tone}`}>
                      <span className="ap-suggestion-icon"><Icon size={16} strokeWidth={2.3} /></span>
                      <span className="ap-suggestion-text">
                        <strong>{meta.title}</strong>
                        <span>{sg.message}</span>
                      </span>
                    </li>
                  );
                })}
              </ul>
            </div>
          )}
        </>
      )}

      {tab === 'Breakdown' && breakdown && (
        <>
          <div className="ap-panel">
            <div className="ap-panel-header"><div><span className="ap-panel-tag">Mix</span><h2>Sales by rice variety</h2></div></div>
            {breakdown.salesByVariety.length === 0 ? (
              <div className="ap-empty-state">
                <Wheat size={26} strokeWidth={1.6} />
                <p>No completed sales yet. This shows which varieties sell best.</p>
              </div>
            ) : (
              <div className="ap-income-bars">
                {breakdown.salesByVariety.map((v) => {
                  const max = Math.max(...breakdown.salesByVariety.map((x) => x.revenue), 1);
                  return (
                    <div className="ap-income-bar-row" key={v.variety}>
                      <span className="ap-income-bar-label" style={{ width: '7rem' }}>{v.variety}</span>
                      <div className="ap-income-bar-track">
                        <div className="ap-income-bar-fill" style={{ width: `${Math.max(4, (v.revenue / max) * 100)}%` }} />
                      </div>
                      <span className="ap-income-bar-value">₱{v.revenue.toLocaleString()} ({v.unitsSold}kg)</span>
                    </div>
                  );
                })}
              </div>
            )}
          </div>

          <div className="ap-stats-grid ap-stats-grid--2">
            <div className="ap-stat-card ap-stat--green">
              <span className="ap-stat-icon"><CheckCircle2 size={20} strokeWidth={2.2} /></span>
              <span className="ap-stat-label">Fulfillment rate</span>
              <span className="ap-stat-value">
                {breakdown.fulfillmentRate != null ? breakdown.fulfillmentRate : '—'}
                {breakdown.fulfillmentRate != null && <small className="ap-stat-unit">%</small>}
              </span>
              <span className="ap-stat-foot">How many orders you completed rather than cancelled</span>
            </div>

            <div className="ap-stat-card ap-stat--plum">
              <span className="ap-stat-icon"><TrendingDown size={20} strokeWidth={2.2} /></span>
              <span className="ap-stat-label">Price vs. market</span>
              <span className="ap-stat-value ap-stat-value--na">Not available</span>
              <span className="ap-stat-foot">No market price feed is connected yet.</span>
            </div>
          </div>

          <div className="ap-panel">
            <div className="ap-panel-header"><div><span className="ap-panel-tag">Customers</span><h2>Top buyers</h2></div></div>
            {breakdown.topBuyers.length === 0 ? (
              <div className="ap-empty-state">
                <Users size={26} strokeWidth={1.6} />
                <p>No completed sales yet. Your repeat customers will be listed here.</p>
              </div>
            ) : (
              <div className="ap-table-wrap">
                <table className="ap-table">
                  <thead><tr><th>Buyer</th><th>Orders</th><th>Total Spent</th><th>Last Order</th></tr></thead>
                  <tbody>
                    {breakdown.topBuyers.map((b) => (
                      <tr key={b._id}>
                        <td className="ap-td-name">{b._id}</td>
                        <td>{b.totalOrders}</td>
                        <td>₱{Number(b.totalSpent).toLocaleString()}</td>
                        <td>{new Date(b.lastOrderDate).toLocaleDateString()}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </>
      )}

      {tab === 'Trends' && breakdown && (
        <>
          <div className="ap-panel">
            <div className="ap-panel-header"><div><span className="ap-panel-tag">Seasonality</span><h2>Monthly pattern, last 12 months</h2></div></div>
            {breakdown.seasonalTrend.length === 0 ? (
              <div className="ap-empty-state">
                <CalendarRange size={26} strokeWidth={1.6} />
                <p>Not enough history yet. After a few months of sales, this shows your busy and slow seasons.</p>
              </div>
            ) : (
              <>
                <div className="ap-income-bars">
                  {breakdown.seasonalTrend.map((m) => {
                    const max = Math.max(...breakdown.seasonalTrend.map((x) => x.income), 1);
                    return (
                      <div className="ap-income-bar-row" key={`${m.year}-${m.month}`}>
                        <span className="ap-income-bar-label">{MONTH_LABELS[m.month - 1]}</span>
                        <div className="ap-income-bar-track">
                          <div className="ap-income-bar-fill" style={{ width: `${Math.max(4, (m.income / max) * 100)}%` }} />
                        </div>
                        <span className="ap-income-bar-value">₱{Number(m.income).toLocaleString()}</span>
                      </div>
                    );
                  })}
                </div>
                {breakdown.peakMonthObservation && (
                  <p style={{ marginTop: '1rem', fontSize: '0.85rem', color: 'var(--text-mid)' }}>
                    <Pin size={14} strokeWidth={2.3} /> {breakdown.peakMonthObservation} <em>(historical observation, not a forecast)</em>
                  </p>
                )}
              </>
            )}
          </div>
        </>
      )}

      <div className="ap-panel">
        <div className="ap-panel-header">
          <div>
            <span className="ap-panel-tag">Reports</span>
            <h2>Email a report</h2>
          </div>
        </div>

        {mailMsg && (
          <p className={mailMsg.ok ? 'ap-mail-ok' : 'ap-form-error'}>{mailMsg.text}</p>
        )}

        <div className="ap-report-cards">
          <article className="ap-report-card">
            <span className="ap-report-icon ap-report-icon--green"><Banknote size={18} strokeWidth={2.2} /></span>
            <div className="ap-report-body">
              <h4>Sales report</h4>
              <p>Every completed order with buyer, product, and amount.</p>
            </div>
            <div className="ap-report-actions">
              <button
                className="ap-btn-primary ap-btn-sm"
                type="button"
                disabled={mailBusy === 'sales'}
                onClick={() => handleEmail('sales')}
              >
                <Mail size={14} strokeWidth={2.3} />
                {mailBusy === 'sales' ? 'Sending…' : 'Email to me'}
              </button>
            </div>
          </article>

          <article className="ap-report-card">
            <span className="ap-report-icon ap-report-icon--teal"><ClipboardList size={18} strokeWidth={2.2} /></span>
            <div className="ap-report-body">
              <h4>Inventory report</h4>
              <p>Stock on hand, warning levels, and what it is all worth.</p>
            </div>
            <div className="ap-report-actions">
              <button
                className="ap-btn-primary ap-btn-sm"
                type="button"
                disabled={mailBusy === 'inventory'}
                onClick={() => handleEmail('inventory')}
              >
                <Mail size={14} strokeWidth={2.3} />
                {mailBusy === 'inventory' ? 'Sending…' : 'Email to me'}
              </button>
            </div>
          </article>

          <article className="ap-report-card">
            <span className="ap-report-icon ap-report-icon--gold"><FileText size={18} strokeWidth={2.2} /></span>
            <div className="ap-report-body">
              <h4>Transactions</h4>
              <p>Every order with its payment status, for your records.</p>
            </div>
            <div className="ap-report-actions">
              <button
                className="ap-btn-primary ap-btn-sm"
                type="button"
                disabled={mailBusy === 'transactions'}
                onClick={() => handleEmail('transactions')}
              >
                <Mail size={14} strokeWidth={2.3} />
                {mailBusy === 'transactions' ? 'Sending…' : 'Email to me'}
              </button>
            </div>
          </article>
        </div>

        <p className="ap-report-note">
          <Lock size={13} strokeWidth={2.3} />
          Reports are not downloadable from this page. They are sent as a PDF to your
          own account address only, so business figures never sit in a browser or a
          shared computer&apos;s downloads folder.
          {mailReady === false && ' Email is not switched on yet — ask your developer to add SMTP details to the server.'}
        </p>
      </div>
    </div>
  );
}
