import { Package, AlertTriangle, Ban, Wallet, History, PlusCircle, SlidersHorizontal, Boxes } from 'lucide-react';
import React, { useEffect, useState } from 'react';
import { fetchInventorySummary, restockProduct, adjustStock, fetchStockMovements } from '../../../services/clientApi';

function stockStatus(p) {
  if (p.stock <= 0) return { label: 'Out of Stock', cls: 'out-of-stock' };
  if (p.stock <= p.lowStockThreshold) return { label: 'Low Stock', cls: 'pending' };
  return { label: 'In Stock', cls: 'active' };
}

const MOVEMENT_LABEL = {
  RESTOCK: 'Restock',
  SALE: 'Sale',
  RETURN: 'Return',
  ADJUSTMENT: 'Adjustment',
  DAMAGE: 'Damage / Loss',
};

export default function InventoryTab() {
  const [summary, setSummary] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const [restockTarget, setRestockTarget] = useState(null);
  const [restockQty, setRestockQty] = useState('');
  const [restockNote, setRestockNote] = useState('');
  const [saving, setSaving] = useState(false);
  const [actionError, setActionError] = useState('');

  const [adjustTarget, setAdjustTarget] = useState(null);
  const [adjustQty, setAdjustQty] = useState('');
  const [adjustType, setAdjustType] = useState('ADJUSTMENT');
  const [adjustNote, setAdjustNote] = useState('');

  const [historyTarget, setHistoryTarget] = useState(null);
  const [movements, setMovements] = useState([]);
  const [movementsLoading, setMovementsLoading] = useState(false);

  const load = async () => {
    setLoading(true);
    setError('');
    try {
      const res = await fetchInventorySummary();
      setSummary(res.data);
    } catch (err) {
      setError(err.response?.data?.message || 'Could not load inventory.');
      setSummary(null);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load();
  }, []);

  async function handleRestockSubmit(e) {
    e.preventDefault();
    setActionError('');
    if (!restockQty || Number(restockQty) < 1) {
      setActionError('Enter a quantity of at least 1 kg.');
      return;
    }
    setSaving(true);
    try {
      await restockProduct(restockTarget._id, Number(restockQty), restockNote);
      setRestockTarget(null);
      setRestockQty('');
      setRestockNote('');
      await load();
    } catch (err) {
      setActionError(err.response?.data?.message || 'Could not restock this product.');
    } finally {
      setSaving(false);
    }
  }

  async function handleAdjustSubmit(e) {
    e.preventDefault();
    setActionError('');
    if (!adjustQty || Number(adjustQty) === 0) {
      setActionError('Enter a non-zero quantity (use negative for loss/damage).');
      return;
    }
    setSaving(true);
    try {
      await adjustStock(adjustTarget._id, Number(adjustQty), adjustType, adjustNote);
      setAdjustTarget(null);
      setAdjustQty('');
      setAdjustNote('');
      await load();
    } catch (err) {
      setActionError(err.response?.data?.message || 'Could not adjust stock for this product.');
    } finally {
      setSaving(false);
    }
  }

  async function openHistory(p) {
    setHistoryTarget(p);
    setMovementsLoading(true);
    try {
      const res = await fetchStockMovements(p._id);
      setMovements(res.data || []);
    } catch {
      setMovements([]);
    } finally {
      setMovementsLoading(false);
    }
  }

  return (
    <div className="ap-tab-content">
      {error && <p className="ap-empty-state">{error}</p>}

      {loading && (
        <div className="ap-skeleton-grid">
          {[0, 1, 2, 3].map((i) => <div key={i} className="ap-skeleton" style={{ height: 118 }} />)}
        </div>
      )}

      {!loading && summary && (
        <>
          <div className="ap-stats-grid">
            <div className="ap-stat-card ap-stat--green">
              <span className="ap-stat-icon"><Package size={20} strokeWidth={2.2} /></span>
              <span className="ap-stat-label">Total stock</span>
              <span className="ap-stat-value">
                {summary.totalStock.toLocaleString()}<small className="ap-stat-unit">kg</small>
              </span>
              <span className="ap-stat-foot">Across {summary.products.length} product{summary.products.length === 1 ? '' : 's'}</span>
            </div>

            <div className="ap-stat-card ap-stat--gold">
              <span className="ap-stat-icon"><AlertTriangle size={20} strokeWidth={2.2} /></span>
              <span className="ap-stat-label">Running low</span>
              <span className="ap-stat-value">{summary.lowStockCount}</span>
              <span className="ap-stat-foot">
                {summary.lowStockCount ? 'At or below their threshold' : 'Nothing needs restocking'}
              </span>
            </div>

            <div className="ap-stat-card ap-stat--plum">
              <span className="ap-stat-icon"><Ban size={20} strokeWidth={2.2} /></span>
              <span className="ap-stat-label">Out of stock</span>
              <span className="ap-stat-value">{summary.outOfStockCount}</span>
              <span className="ap-stat-foot">
                {summary.outOfStockCount ? 'Cannot be ordered right now' : 'Everything is orderable'}
              </span>
            </div>

            <div className="ap-stat-card ap-stat--teal">
              <span className="ap-stat-icon"><Wallet size={20} strokeWidth={2.2} /></span>
              <span className="ap-stat-label">Stock value</span>
              <span className="ap-stat-value">
                <small>₱</small>{summary.stockValue.toLocaleString()}
              </span>
              <span className="ap-stat-foot">What your shelves are worth at list price</span>
            </div>
          </div>

          <div className="ap-panel">
            <div className="ap-panel-header">
              <div>
                <span className="ap-panel-tag">Stock levels</span>
                <h2>Every product you sell</h2>
              </div>
            </div>
            {summary.products.length === 0 ? (
              <div className="ap-empty-state">
                <Boxes size={28} strokeWidth={1.6} />
                <p>No products yet. Add a product first, then you can manage its stock here.</p>
              </div>
            ) : (
              <div className="ap-table-wrap">
                <table className="ap-table">
                  <thead>
                    <tr>
                      <th>Product</th>
                      <th>Stock on hand</th>
                      <th className="ap-th-num" title="You get a low-stock warning at or below this level">
                        Warn at
                      </th>
                      <th>Status</th>
                      <th>Last restocked</th>
                      <th className="ap-th-actions">Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {summary.products.map((p) => {
                      const st = stockStatus(p);
                      const pct = Math.min(100, p.lowStockThreshold > 0 ? (p.stock / (p.lowStockThreshold * 3)) * 100 : 100);
                      return (
                        <tr key={p._id}>
                          <td className="ap-td-name">{p.name}</td>
                          <td>
                            <div className="ap-stock-cell">
                              <span className="ap-stock-value">{Number(p.stock).toLocaleString()} kg</span>
                              <div className="ap-stock-bar-track">
                                <div className={`ap-stock-bar-fill ap-stock-bar-${st.cls}`} style={{ width: `${Math.max(3, pct)}%` }} />
                              </div>
                            </div>
                          </td>
                          <td className="ap-td-num ap-td-soft">{p.lowStockThreshold} kg</td>
                          <td><span className={`ap-badge ap-badge-${st.cls}`}>{st.label}</span></td>
                          <td className="ap-td-soft">
                            {p.lastRestockedAt ? new Date(p.lastRestockedAt).toLocaleDateString('en-PH', { month: 'short', day: 'numeric', year: 'numeric' }) : 'Never'}
                          </td>
                          <td>
                            <div className="ap-inv-actions">
                              <button
                                className="ap-btn-ghost ap-btn-sm"
                                type="button"
                                title="Record new stock you received, e.g. a harvest or delivery"
                                onClick={() => { setRestockTarget(p); setActionError(''); }}
                              >
                                <PlusCircle size={14} strokeWidth={2.3} />
                                Add stock
                              </button>
                              <button
                                className="ap-btn-ghost ap-btn-sm"
                                type="button"
                                title="Correct the count, or record damage, loss, or a return"
                                onClick={() => { setAdjustTarget(p); setActionError(''); }}
                              >
                                <SlidersHorizontal size={14} strokeWidth={2.3} />
                                Correct
                              </button>
                              <button
                                className="ap-btn-ghost ap-btn-sm"
                                type="button"
                                title="See every stock change for this product"
                                onClick={() => openHistory(p)}
                              >
                                <History size={14} strokeWidth={2.3} />
                                History
                              </button>
                            </div>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </>
      )}

      {restockTarget && (
        <div className="ap-modal-overlay">
          <div className="ap-modal ap-modal-md">
            <h3>Add stock</h3>
            <p className="ap-modal-sub">
              Record new stock you received for <strong>{restockTarget.name}</strong> — a harvest,
              a delivery, or anything that increases what you have on hand.
            </p>
            {actionError && <p className="ap-form-error">{actionError}</p>}
            <form onSubmit={handleRestockSubmit}>
              <div className="ap-form-field" style={{ marginBottom: '0.9rem' }}>
                <label>Quantity to add (kg)</label>
                <input type="number" min="1" value={restockQty} onChange={(e) => setRestockQty(e.target.value)} autoFocus />
                {Number(restockQty) > 0 && (
                  <span className="ap-field-hint">
                    {Number(restockTarget.stock).toLocaleString()} kg → <strong>{(Number(restockTarget.stock) + Number(restockQty)).toLocaleString()} kg</strong>
                  </span>
                )}
              </div>
              <div className="ap-form-field" style={{ marginBottom: '0.9rem' }}>
                <label>Note (optional)</label>
                <input type="text" value={restockNote} onChange={(e) => setRestockNote(e.target.value)} placeholder="e.g. Weekly harvest" />
              </div>
              <div className="ap-modal-actions">
                <button type="button" className="ap-modal-cancel" onClick={() => setRestockTarget(null)}>Cancel</button>
                <button type="submit" className="ap-modal-confirm" disabled={saving}>{saving ? 'Saving…' : 'Add stock'}</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {adjustTarget && (
        <div className="ap-modal-overlay">
          <div className="ap-modal ap-modal-md">
            <h3>Correct stock</h3>
            <p className="ap-modal-sub">
              Use this when the real count of <strong>{adjustTarget.name}</strong> does not match
              the system — spoilage, loss, or a miscount. This is not for sales.
            </p>
            {actionError && <p className="ap-form-error">{actionError}</p>}
            <form onSubmit={handleAdjustSubmit}>
              <div className="ap-form-field" style={{ marginBottom: '0.9rem' }}>
                <label>Change in kilos</label>
                <input
                  type="number"
                  value={adjustQty}
                  onChange={(e) => setAdjustQty(e.target.value)}
                  placeholder="e.g. -5"
                  autoFocus
                />
                <span className="ap-field-hint">
                  {Number(adjustQty)
                    ? <>{Number(adjustTarget.stock).toLocaleString()} kg → <strong>{(Number(adjustTarget.stock) + Number(adjustQty)).toLocaleString()} kg</strong></>
                    : 'Use a negative number to remove stock, positive to add it back.'}
                </span>
              </div>
              <div className="ap-form-field" style={{ marginBottom: '0.9rem' }}>
                <label>Reason</label>
                <select value={adjustType} onChange={(e) => setAdjustType(e.target.value)}>
                  <option value="ADJUSTMENT">Miscount — correcting the record</option>
                  <option value="DAMAGE">Damaged or spoiled</option>
                </select>
              </div>
              <div className="ap-form-field" style={{ marginBottom: '0.9rem' }}>
                <label>Note (optional)</label>
                <input type="text" value={adjustNote} onChange={(e) => setAdjustNote(e.target.value)} />
              </div>
              <div className="ap-modal-actions">
                <button type="button" className="ap-modal-cancel" onClick={() => setAdjustTarget(null)}>Cancel</button>
                <button type="submit" className="ap-modal-confirm" disabled={saving}>{saving ? 'Saving…' : 'Save correction'}</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {historyTarget && (
        <div className="ap-modal-overlay">
          <div className="ap-modal ap-modal-lg">
            <h3>Stock History — {historyTarget.name}</h3>
            {movementsLoading && <p className="ap-empty-state">Loading…</p>}
            {!movementsLoading && movements.length === 0 && <p className="ap-empty-state">No stock movements recorded yet.</p>}
            {!movementsLoading && movements.length > 0 && (
              <div className="ap-table-wrap">
                <table className="ap-table">
                  <thead>
                    <tr><th>Date</th><th>Type</th><th>Change</th><th>Resulting Stock</th><th>Note</th></tr>
                  </thead>
                  <tbody>
                    {movements.map((m) => (
                      <tr key={m._id}>
                        <td>{new Date(m.createdAt).toLocaleString()}</td>
                        <td>{MOVEMENT_LABEL[m.type] || m.type}</td>
                        <td style={{ color: m.quantity < 0 ? 'var(--error)' : 'var(--green-700)', fontWeight: 700 }}>
                          {m.quantity > 0 ? `+${m.quantity}` : m.quantity} kg
                        </td>
                        <td>{m.resultingStock} kg</td>
                        <td>{m.note || '—'}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
            <div className="ap-modal-actions">
              <button className="ap-modal-cancel" type="button" onClick={() => setHistoryTarget(null)}>Close</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
