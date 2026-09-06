import React, { useEffect, useState, useCallback } from 'react';
import {
  Wallet,
  ShoppingBag,
  Receipt,
  Store,
  RotateCw,
  BarChart3,
  Package,
} from 'lucide-react';
import DonutChart from './DonutChart';
import { fetchBusinessAnalytics } from '../../services/superAdminApi';
import './BusinessAnalytics.css';

/* Categorical slots, validated against the cream card surface with the
   data-viz palette checker (lightness band, chroma floor, CVD separation).
   The raw brand greens failed those checks, so these are the snapped steps.
   Assigned in fixed order and never cycled. */
const SERIES = ['#1baf7a', '#eda100', '#2a78d6', '#eb6834', '#8757c4'];
const SERIES_OTHER = '#8a8f86';

/* Status tokens are reserved - they mean state, never series identity. */
const STATUS_BUCKETS = [
  {
    key: 'completed',
    label: 'Completed',
    color: '#0ca30c',
    matches: ['completed', 'delivered'],
  },
  {
    key: 'inprogress',
    label: 'In progress',
    color: '#fab219',
    matches: ['pending', 'confirmed', 'processing', 'shipped'],
  },
  {
    key: 'cancelled',
    label: 'Cancelled',
    color: '#d03b3b',
    matches: ['cancelled'],
  },
];

/** Keeps a donut within its 6-segment budget by folding the tail into "Other". */
function foldToSegments(rows, max = 5) {
  const head = rows.slice(0, max).map((r, i) => ({ ...r, color: SERIES[i] }));
  const tail = rows.slice(max);
  if (tail.length === 0) return head;
  return [
    ...head,
    {
      key: 'other',
      label: `Other (${tail.length})`,
      value: tail.reduce((sum, r) => sum + r.value, 0),
      color: SERIES_OTHER,
    },
  ];
}

function peso(n, decimals = 0) {
  return `₱${Number(n || 0).toLocaleString('en-PH', {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  })}`;
}

function compactPeso(n) {
  const v = Number(n || 0);
  if (v >= 1_000_000) return `₱${(v / 1_000_000).toFixed(1)}M`;
  if (v >= 10_000) return `₱${Math.round(v / 1000)}k`;
  return peso(v);
}

function dayOnly(value) {
  if (!value) return 'No sales yet';
  return new Date(value).toLocaleDateString('en-PH', { month: 'short', day: 'numeric', year: 'numeric' });
}

function Stat({ icon, tone, label, value, note }) {
  const Icon = icon;
  return (
    <article className={`ba-stat ba-stat--${tone}`}>
      <span className="ba-stat-icon"><Icon size={20} strokeWidth={2.2} /></span>
      <div className="ba-stat-body">
        <span className="ba-stat-label">{label}</span>
        <span className="ba-stat-value">{value}</span>
        <span className="ba-stat-note">{note}</span>
      </div>
    </article>
  );
}

export default function BusinessAnalytics() {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const res = await fetchBusinessAnalytics();
      setData(res.data);
    } catch (err) {
      setError(err.response?.data?.error || 'Could not load business analytics.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  if (loading && !data) {
    return (
      <div className="ba-root">
        <div className="ba-stats">
          {[0, 1, 2, 3].map((i) => <div key={i} className="ba-skeleton" style={{ height: 96 }} />)}
        </div>
        <div className="ba-skeleton" style={{ height: 320 }} />
      </div>
    );
  }

  if (error) {
    return (
      <div className="ba-root">
        <div className="ba-card ba-empty">
          <BarChart3 size={30} strokeWidth={1.6} />
          <p>{error}</p>
          <button type="button" className="ba-refresh" onClick={load}>Try again</button>
        </div>
      </div>
    );
  }

  const sellers = data.sellers || [];
  const ranked = sellers.filter((s) => s.orders > 0);
  const totalStatus = (data.statusMix || []).reduce((sum, s) => sum + s.count, 0);

  // Revenue share: identity matters, so categorical slots in fixed order.
  const revenueSegments = foldToSegments(
    ranked.map((s) => ({ key: String(s.sellerId), label: s.name, value: s.revenue }))
  );

  // Status: state, so the reserved status tokens - collapsed to three buckets
  // because seven raw statuses exceed what a donut can carry legibly.
  const statusSegments = STATUS_BUCKETS.map((b) => ({
    key: b.key,
    label: b.label,
    color: b.color,
    value: (data.statusMix || [])
      .filter((s) => b.matches.includes(s.status))
      .reduce((sum, s) => sum + s.count, 0),
  })).filter((b) => b.value > 0);

  // Product mix by revenue.
  const productSegments = foldToSegments(
    (data.topProducts || []).map((p) => ({ key: p.productId, label: p.name, value: p.revenue }))
  );

  return (
    <div className="ba-root">
      <header className="ba-head">
        <div>
          <span className="ba-tag">Descriptive analytics</span>
          <h2>Business performance</h2>
          <p className="ba-sub">
            What the businesses on AgriFair have actually recorded. Figures come from completed orders only.
          </p>
        </div>
        <button className="ba-refresh" type="button" onClick={load} disabled={loading}>
          <RotateCw size={15} strokeWidth={2.3} className={loading ? 'ba-spin' : ''} />
          Refresh
        </button>
      </header>

      <div className="ba-stats">
        <Stat
          icon={Wallet}
          tone="green"
          label="Platform GMV"
          value={compactPeso(data.gmv)}
          note={`${peso(data.gmvLast30Days)} in the last 30 days`}
        />
        <Stat
          icon={ShoppingBag}
          tone="gold"
          label="Completed orders"
          value={data.orderCount.toLocaleString()}
          note={`${data.unitsSold.toLocaleString()} units sold in total`}
        />
        <Stat
          icon={Receipt}
          tone="teal"
          label="Average order value"
          value={compactPeso(data.avgOrderValue)}
          note={data.orderCount ? 'Across all completed orders' : 'No completed orders yet'}
        />
        <Stat
          icon={Store}
          tone="plum"
          label="Selling businesses"
          value={`${data.activeSellers} / ${data.totalSellers}`}
          note={`${data.participationRate}% of sellers have made a sale`}
        />
      </div>

      <div className="ba-split">
        <section className="ba-card">
          <div className="ba-card-head">
            <div>
              <h3>Seller breakdown</h3>
              <p className="ba-card-sub">Ranked by revenue contribution</p>
            </div>
            <span className="ba-count">{sellers.length} businesses</span>
          </div>

          {sellers.length === 0 ? (
            <div className="ba-empty">
              <Store size={28} strokeWidth={1.6} />
              <p>No seller accounts exist yet.</p>
            </div>
          ) : (
            <div className="ba-scroll">
              <table className="ba-table">
                <thead>
                  <tr>
                    <th className="ba-rank-col">#</th>
                    <th>Business</th>
                    <th className="ba-num">Revenue</th>
                    <th className="ba-num">Orders</th>
                    <th className="ba-num">Clients</th>
                    <th className="ba-num">Avg order</th>
                    <th>Last sale</th>
                  </tr>
                </thead>
                <tbody>
                  {sellers.map((s, i) => (
                    <tr key={s.sellerId} className={s.orders === 0 ? 'is-idle' : ''}>
                      <td className="ba-rank-col">
                        {s.orders > 0 ? <span className="ba-rank">{i + 1}</span> : <span className="ba-rank ba-rank--none">—</span>}
                      </td>
                      <td>
                        <div className="ba-biz">
                          <span className="ba-biz-name">{s.name}</span>
                          {!s.exists && <span className="ba-chip ba-chip--red">removed</span>}
                          {s.exists && s.status === 'pending' && <span className="ba-chip ba-chip--gold">pending</span>}
                          {s.exists && s.status === 'suspended' && <span className="ba-chip ba-chip--red">suspended</span>}
                        </div>
                        {s.share > 0 && (
                          <div className="ba-share" title={`${s.share}% of platform GMV`}>
                            <div className="ba-share-fill" style={{ width: `${Math.max(2, s.share)}%` }} />
                          </div>
                        )}
                      </td>
                      <td className="ba-num ba-strong">{peso(s.revenue)}</td>
                      <td className="ba-num">{s.orders}</td>
                      <td className="ba-num">{s.customers}</td>
                      <td className="ba-num">{peso(s.avgOrderValue)}</td>
                      <td className="ba-muted">{dayOnly(s.lastSale)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          {ranked.length === 0 && sellers.length > 0 && (
            <p className="ba-footnote">
              No completed sales recorded yet, so every business currently shows zero.
            </p>
          )}
        </section>

        <section className="ba-card">
          <div className="ba-card-head">
            <div>
              <h3>Order status mix</h3>
              <p className="ba-card-sub">Share of all orders ever placed</p>
            </div>
          </div>
          <div className="ba-card-body">
            {totalStatus === 0 ? (
              <div className="ba-empty ba-empty--sm">
                <ShoppingBag size={24} strokeWidth={1.6} />
                <p>No orders placed yet.</p>
              </div>
            ) : (
              <DonutChart
                segments={statusSegments}
                centerValue={totalStatus.toLocaleString()}
                centerLabel="Orders"
                ariaLabel={`Order status mix across ${totalStatus} orders`}
                fallback={
                  <ul className="ba-legend">
                    {statusSegments.map((b) => (
                      <li key={b.key}>
                        <span className="ba-dot" style={{ background: b.color }} />
                        <span className="ba-legend-name">{b.label}</span>
                        <span className="ba-legend-val">
                          {b.value} · {Math.round((b.value / totalStatus) * 100)}%
                        </span>
                      </li>
                    ))}
                  </ul>
                }
              />
            )}
          </div>
        </section>
      </div>

      <div className="ba-bottom">
        <section className="ba-card">
          <div className="ba-card-head">
            <div>
              <h3>Revenue share</h3>
              <p className="ba-card-sub">Which businesses make up platform GMV</p>
            </div>
          </div>
          <div className="ba-card-body">
            <DonutChart
              segments={revenueSegments}
              centerValue={compactPeso(data.gmv)}
              centerLabel="Total GMV"
              formatValue={(v) => peso(v)}
              ariaLabel="Share of platform revenue by business"
              fallback={
                ranked.length === 1 ? (
                  <div className="ba-solo">
                    <span className="ba-solo-value">100%</span>
                    <p>
                      All platform revenue so far comes from{' '}
                      <strong>{ranked[0].name}</strong>. A share breakdown appears
                      once a second business records a sale.
                    </p>
                  </div>
                ) : (
                  <div className="ba-empty ba-empty--sm">
                    <Store size={24} strokeWidth={1.6} />
                    <p>No business has recorded revenue yet.</p>
                  </div>
                )
              }
            />
          </div>
        </section>

        <section className="ba-card">
          <div className="ba-card-head">
            <div>
              <h3>Product mix</h3>
              <p className="ba-card-sub">Revenue split across top products</p>
            </div>
          </div>
          <div className="ba-card-body">
            <DonutChart
              segments={productSegments}
              centerValue={String((data.topProducts || []).length)}
              centerLabel="Products sold"
              formatValue={(v) => peso(v)}
              ariaLabel="Revenue split across top products"
              fallback={
                (data.topProducts || []).length === 1 ? (
                  <div className="ba-solo">
                    <span className="ba-solo-value">100%</span>
                    <p>
                      Every sale so far is <strong>{data.topProducts[0].name}</strong>.
                      The split appears once a second product sells.
                    </p>
                  </div>
                ) : (
                  <div className="ba-empty ba-empty--sm">
                    <Package size={24} strokeWidth={1.6} />
                    <p>No products have sold yet.</p>
                  </div>
                )
              }
            />
          </div>
        </section>

        <section className="ba-card">
        <div className="ba-card-head">
        <div>
        <h3>Top products</h3>
        <p className="ba-card-sub">By revenue across all sellers</p>
        </div>
        </div>
        <div className="ba-card-body">
        {(data.topProducts || []).length === 0 ? (
        <div className="ba-empty ba-empty--sm">
        <Package size={24} strokeWidth={1.6} />
        <p>No products have sold yet.</p>
        </div>
        ) : (
        data.topProducts.map((p, i) => (
        <div className="ba-product" key={p.productId}>
        <span className="ba-rank ba-rank--sm">{i + 1}</span>
        <div className="ba-product-body">
        <span className="ba-product-name">{p.name}</span>
        <span className="ba-product-meta">{p.units} units sold</span>
        </div>
        <span className="ba-product-value">{peso(p.revenue)}</span>
        </div>
        ))
        )}
        </div>
        </section>
      </div>
    </div>
  );
}
