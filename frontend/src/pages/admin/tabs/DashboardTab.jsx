import React, { useEffect, useState } from 'react';
import {
  Wallet,
  ShoppingCart,
  Package,
  ClipboardList,
  TrendingUp,
  TrendingDown,
  AlertTriangle,
  Truck,
  CheckCircle2,
  Inbox,
  ArrowRight,
} from 'lucide-react';
import { fetchMyProducts, fetchInventorySummary, fetchMyOrders, fetchMyOrderAnalytics } from '../../../services/clientApi';

const MONTH_LABELS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

export default function DashboardTab({ onNavigate }) {
  const [products, setProducts] = useState([]);
  const [inventory, setInventory] = useState(null);
  const [orders, setOrders] = useState([]);
  const [analytics, setAnalytics] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let mounted = true;
    (async () => {
      try {
        const [prodRes, invRes, ordRes, anaRes] = await Promise.all([
          fetchMyProducts().catch(() => ({ data: [] })),
          fetchInventorySummary().catch(() => ({ data: null })),
          fetchMyOrders().catch(() => ({ data: [] })),
          fetchMyOrderAnalytics().catch(() => ({ data: null })),
        ]);
        if (!mounted) return;
        setProducts(prodRes.data?.products || prodRes.data || []);
        setInventory(invRes.data);
        setOrders(ordRes.data?.orders || ordRes.data || []);
        setAnalytics(anaRes.data);
      } finally {
        if (mounted) setLoading(false);
      }
    })();
    return () => { mounted = false; };
  }, []);

  const pendingOrders = orders.filter((o) => o.status === 'pending');
  const readyToShip = orders.filter((o) => o.status === 'processing');
  const lowStockProducts = products.filter((p) => p.status !== 'inactive' && p.stock <= (p.lowStockThreshold ?? 20) && p.stock > 0);
  const activeProducts = products.filter((p) => p.status !== 'inactive');

  const monthlyIncome = analytics?.monthlyIncome || [];
  const salesChange = (() => {
    if (monthlyIncome.length < 2) return null;
    const latest = monthlyIncome[monthlyIncome.length - 1].income;
    const prev = monthlyIncome[monthlyIncome.length - 2].income;
    if (!prev) return null;
    return Math.round(((latest - prev) / prev) * 100);
  })();
  const maxIncome = monthlyIncome.length ? Math.max(...monthlyIncome.map((m) => m.income), 1) : 1;

  const recentOrders = [...orders]
    .sort((a, b) => new Date(b.orderDate) - new Date(a.orderDate))
    .slice(0, 5);

  return (
    <div className="ap-tab-content">
      {loading ? (
        <div className="ap-skeleton-grid">
          {[0, 1, 2, 3].map((i) => <div key={i} className="ap-skeleton" style={{ height: 118 }} />)}
        </div>
      ) : (
        <>
          <div className="ap-stats-grid">
            <button className="ap-stat-card ap-stat--green" type="button" onClick={() => onNavigate?.('Analytics')}>
              <span className="ap-stat-icon"><Wallet size={20} strokeWidth={2.2} /></span>
              <span className="ap-stat-label">Total sales</span>
              <span className="ap-stat-value">
                <small>₱</small>{Number(analytics?.totalSales || 0).toLocaleString()}
              </span>
              <span className="ap-stat-foot">
                {salesChange != null ? (
                  <>
                    <span className={`ap-delta ${salesChange >= 0 ? 'up' : 'down'}`}>
                      {salesChange >= 0
                        ? <TrendingUp size={13} strokeWidth={2.5} />
                        : <TrendingDown size={13} strokeWidth={2.5} />}
                      {Math.abs(salesChange)}%
                    </span>
                    vs last month
                  </>
                ) : 'No prior month to compare'}
              </span>
            </button>

            <button className="ap-stat-card ap-stat--gold" type="button" onClick={() => onNavigate?.('Orders')}>
              <span className="ap-stat-icon"><ShoppingCart size={20} strokeWidth={2.2} /></span>
              <span className="ap-stat-label">Pending orders</span>
              <span className="ap-stat-value">{pendingOrders.length}</span>
              <span className="ap-stat-foot">
                {pendingOrders.length ? 'Waiting for your confirmation' : 'Nothing waiting'}
              </span>
            </button>

            <button className="ap-stat-card ap-stat--teal" type="button" onClick={() => onNavigate?.('Products')}>
              <span className="ap-stat-icon"><Package size={20} strokeWidth={2.2} /></span>
              <span className="ap-stat-label">Active products</span>
              <span className="ap-stat-value">{activeProducts.length}</span>
              <span className="ap-stat-foot">
                {products.length !== activeProducts.length
                  ? `${products.length - activeProducts.length} inactive`
                  : 'All listings are live'}
              </span>
            </button>

            <button className="ap-stat-card ap-stat--plum" type="button" onClick={() => onNavigate?.('Inventory')}>
              <span className="ap-stat-icon"><ClipboardList size={20} strokeWidth={2.2} /></span>
              <span className="ap-stat-label">Inventory</span>
              <span className="ap-stat-value">
                {inventory ? inventory.totalStock.toLocaleString() : '—'}
                {inventory && <small className="ap-stat-unit">kg</small>}
              </span>
              <span className="ap-stat-foot">
                {inventory && inventory.lowStockCount > 0 ? (
                  <span className="ap-delta down">
                    <AlertTriangle size={13} strokeWidth={2.5} />
                    {inventory.lowStockCount} low stock
                  </span>
                ) : 'Stock levels are healthy'}
              </span>
            </button>
          </div>

          <div className="ap-dash-grid">
            <div className="ap-dash-col">
              <div className="ap-panel">
                <div className="ap-panel-header">
                  <div>
                    <span className="ap-panel-tag">Revenue</span>
                    <h2>Monthly sales</h2>
                  </div>
                </div>
                {monthlyIncome.length === 0 ? (
                  <div className="ap-empty-state">
                    <TrendingUp size={26} strokeWidth={1.6} />
                    <p>No completed sales yet. Your revenue trend will appear here.</p>
                  </div>
                ) : (
                  <div className="ap-income-bars">
                    {monthlyIncome.map((m) => (
                      <div className="ap-income-bar-row" key={`${m.year}-${m.month}`}>
                        <span className="ap-income-bar-label">{MONTH_LABELS[m.month - 1]}</span>
                        <div className="ap-income-bar-track">
                          <div className="ap-income-bar-fill" style={{ width: `${Math.max(4, (m.income / maxIncome) * 100)}%` }} />
                        </div>
                        <span className="ap-income-bar-value">₱{Number(m.income).toLocaleString()}</span>
                      </div>
                    ))}
                  </div>
                )}
              </div>

              <div className="ap-panel">
                <div className="ap-panel-header">
                  <div>
                    <span className="ap-panel-tag">Needs you</span>
                    <h2>Action items</h2>
                  </div>
                </div>
                {pendingOrders.length === 0 && lowStockProducts.length === 0 && readyToShip.length === 0 ? (
                  <div className="ap-empty-state">
                    <CheckCircle2 size={26} strokeWidth={1.6} />
                    <p>You&apos;re all caught up — nothing needs attention right now.</p>
                  </div>
                ) : (
                  <ul className="ap-action-list">
                    {pendingOrders.length > 0 && (
                      <li className="ap-action-item urgent">
                        <button type="button" onClick={() => onNavigate?.('Orders')}>
                          <span className="ap-action-icon"><ShoppingCart size={16} strokeWidth={2.3} /></span>
                          <span className="ap-action-text">
                            <strong>{pendingOrders.length} pending order{pendingOrders.length !== 1 ? 's' : ''}</strong>
                            <span>Waiting for your confirmation.</span>
                          </span>
                          <ArrowRight size={16} strokeWidth={2.3} className="ap-action-go" />
                        </button>
                      </li>
                    )}
                    {lowStockProducts.length > 0 && (
                      <li className="ap-action-item warn">
                        <button type="button" onClick={() => onNavigate?.('Inventory')}>
                          <span className="ap-action-icon"><AlertTriangle size={16} strokeWidth={2.3} /></span>
                          <span className="ap-action-text">
                            <strong>{lowStockProducts.length} product{lowStockProducts.length !== 1 ? 's' : ''} running low</strong>
                            <span>Restock before they sell out.</span>
                          </span>
                          <ArrowRight size={16} strokeWidth={2.3} className="ap-action-go" />
                        </button>
                      </li>
                    )}
                    {readyToShip.length > 0 && (
                      <li className="ap-action-item">
                        <button type="button" onClick={() => onNavigate?.('Orders')}>
                          <span className="ap-action-icon"><Truck size={16} strokeWidth={2.3} /></span>
                          <span className="ap-action-text">
                            <strong>{readyToShip.length} order{readyToShip.length !== 1 ? 's' : ''} ready to ship</strong>
                            <span>Processing is done — send them out.</span>
                          </span>
                          <ArrowRight size={16} strokeWidth={2.3} className="ap-action-go" />
                        </button>
                      </li>
                    )}
                  </ul>
                )}
              </div>
            </div>

            <div className="ap-panel">
              <div className="ap-panel-header">
                <div>
                  <span className="ap-panel-tag">Latest</span>
                  <h2>Recent orders</h2>
                </div>
                <button className="ap-btn-ghost" type="button" onClick={() => onNavigate?.('Orders')}>View all</button>
              </div>
              {recentOrders.length === 0 ? (
                <div className="ap-empty-state">
                  <Inbox size={26} strokeWidth={1.6} />
                  <p>No orders yet.</p>
                </div>
              ) : (
                <div className="ap-table-wrap">
                  <table className="ap-table">
                    <thead>
                      <tr><th>Order</th><th>Buyer</th><th>Amount</th><th>Status</th><th>Date</th></tr>
                    </thead>
                    <tbody>
                      {recentOrders.map((o) => (
                        <tr key={o._id}>
                          <td>{o.orderNumber}</td>
                          <td>{o.customerName}</td>
                          <td>₱{Number(o.total).toLocaleString()}</td>
                          <td><span className={`ap-badge ap-badge-${o.status}`}>{o.status}</span></td>
                          <td>{new Date(o.orderDate).toLocaleDateString()}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </div>
          </div>
        </>
      )}
    </div>
  );
}
