import React, { useEffect, useMemo, useState } from 'react';
import { Plus, ClipboardList, ChevronRight } from 'lucide-react';
import OrderDetailView from '../components/OrderDetailView';
import { fetchMyOrders, fetchMyProducts, recordSale, updateOrderStatus, reviewOrderPayment } from '../../../services/clientApi';

const STATUS_TABS = ['All', 'pending', 'confirmed', 'processing', 'shipped', 'delivered', 'completed', 'cancelled'];

const STATUS_LABEL = {
  pending: 'Pending',
  confirmed: 'Confirmed',
  processing: 'Processing',
  shipped: 'Shipped',
  delivered: 'Delivered',
  completed: 'Completed',
  cancelled: 'Cancelled',
};

/** What each stage means, in the seller's own terms. */
const STATUS_HINT = {
  pending: 'The buyer placed this order. Nothing is reserved until you accept it.',
  confirmed: 'You accepted it. The stock is now reserved for this buyer.',
  processing: 'You are preparing the goods.',
  shipped: 'It has left your place and is on the way.',
  delivered: 'The buyer received it. Confirm payment to close the sale.',
  completed: 'Done and counted in your sales.',
  cancelled: 'Called off. Any reserved stock went back to your inventory.',
};

/** Button copy states the action, not the destination status. */
const ACTION_LABEL = {
  confirmed: 'Accept order',
  processing: 'Start preparing',
  shipped: 'Mark as shipped',
  delivered: 'Mark as delivered',
  completed: 'Complete sale',
  cancelled: 'Cancel order',
};

/** Side effects worth warning about before the click. */
const ACTION_NOTE = {
  confirmed: 'Accepting deducts the quantity from your stock.',
  completed: 'Completing counts this order in your total sales.',
  cancelled: 'Cancelling returns any reserved stock to your inventory.',
};

const NEXT_STATUSES = {
  pending: ['confirmed', 'cancelled'],
  confirmed: ['processing', 'cancelled'],
  processing: ['shipped', 'cancelled'],
  shipped: ['delivered'],
  delivered: ['completed'],
  completed: [],
  cancelled: [],
};

const EMPTY_SALE = {
  productId: '',
  customerName: '',
  customerContact: '',
  deliveryAddress: '',
  quantity: 1,
  unitPrice: '',
  deliveryFee: 0,
  paymentMethod: 'Cash/COD',
  orderDate: new Date().toISOString().slice(0, 10),
  status: 'pending',
  notes: '',
};

export default function OrdersTab() {
  const [orders, setOrders] = useState([]);
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [statusTab, setStatusTab] = useState('All');
  const [selectedId, setSelectedId] = useState(null);

  const [showForm, setShowForm] = useState(false);
  const [saleForm, setSaleForm] = useState(EMPTY_SALE);
  const [submitting, setSubmitting] = useState(false);
  const [formError, setFormError] = useState('');

  const [cancelTarget, setCancelTarget] = useState(null);
  const [cancelReason, setCancelReason] = useState('');
  const [actionBusy, setActionBusy] = useState(false);

  const load = async () => {
    setLoading(true);
    setError('');
    try {
      const res = await fetchMyOrders();
      const list = res.data?.orders || res.data || [];
      setOrders(Array.isArray(list) ? list : []);
    } catch (err) {
      setError(err.response?.data?.message || 'Orders will appear here once you record a sale.');
      setOrders([]);
    } finally {
      setLoading(false);
    }
  };

  const loadProducts = async () => {
    try {
      const res = await fetchMyProducts();
      const list = res.data?.products || res.data || [];
      setProducts(Array.isArray(list) ? list : []);
    } catch {
      setProducts([]);
    }
  };

  useEffect(() => {
    load();
    loadProducts();
  }, []);

  const counts = useMemo(() => {
    const c = { All: orders.length };
    STATUS_TABS.slice(1).forEach((s) => { c[s] = orders.filter((o) => o.status === s).length; });
    return c;
  }, [orders]);

  const filteredOrders = useMemo(() => {
    if (statusTab === 'All') return orders;
    return orders.filter((o) => o.status === statusTab);
  }, [orders, statusTab]);

  // No fallback to the first order: that was for the old split layout, where a
  // detail panel sat beside the list. Now the detail is a full-screen view, so
  // falling back meant it opened on its own and Back could never close it.
  const selectedOrder = useMemo(
    () => orders.find((o) => o._id === selectedId) || null,
    [orders, selectedId]
  );

  const selectedProduct = useMemo(
    () => products.find((p) => p._id === saleForm.productId),
    [products, saleForm.productId]
  );

  const total = (Number(saleForm.quantity) || 0) * (Number(saleForm.unitPrice) || 0) + (Number(saleForm.deliveryFee) || 0);

  function handleProductChange(productId) {
    const product = products.find((p) => p._id === productId);
    setSaleForm((f) => ({ ...f, productId, unitPrice: product ? product.price : '' }));
  }

  async function handleSubmit(e) {
    e.preventDefault();
    setFormError('');
    if (!saleForm.productId || !saleForm.customerName.trim() || !saleForm.quantity) {
      setFormError('Product, customer name, and quantity are required.');
      return;
    }
    setSubmitting(true);
    try {
      await recordSale({
        ...saleForm,
        quantity: Number(saleForm.quantity),
        unitPrice: saleForm.unitPrice === '' ? undefined : Number(saleForm.unitPrice),
        deliveryFee: Number(saleForm.deliveryFee) || 0,
      });
      setSaleForm(EMPTY_SALE);
      setShowForm(false);
      await Promise.all([load(), loadProducts()]);
    } catch (err) {
      setFormError(err.response?.data?.message || 'Could not record this sale.');
    } finally {
      setSubmitting(false);
    }
  }

  async function handleReviewPayment(order, decision) {
    setActionBusy(true);
    try {
      await reviewOrderPayment(order._id, decision);
      await load();
    } catch (err) {
      // Surfaced through the list reload; the order keeps its previous state.
      console.error('Payment review failed:', err.response?.data?.error || err.message);
    } finally {
      setActionBusy(false);
    }
  }

  async function handleTransition(order, status) {
    if (status === 'cancelled') {
      setCancelTarget(order);
      setCancelReason('');
      return;
    }
    setActionBusy(true);
    try {
      await updateOrderStatus(order._id, status);
      await Promise.all([load(), loadProducts()]);
    } catch (err) {
      setError(err.response?.data?.message || 'Could not update order status.');
    } finally {
      setActionBusy(false);
    }
  }

  async function confirmCancel() {
    if (!cancelReason.trim()) return;
    setActionBusy(true);
    try {
      await updateOrderStatus(cancelTarget._id, 'cancelled', cancelReason.trim());
      setCancelTarget(null);
      setCancelReason('');
      await Promise.all([load(), loadProducts()]);
    } catch (err) {
      setError(err.response?.data?.message || 'Could not cancel this order.');
    } finally {
      setActionBusy(false);
    }
  }

  return (
    <div className="ap-tab-content">
      <div className="ap-orders-bar">
        <div className="ap-status-tabs">
          {STATUS_TABS.map((st) => (
            <button
              key={st}
              type="button"
              className={`ap-status-tab ${statusTab === st ? 'active' : ''}`}
              onClick={() => setStatusTab(st)}
            >
              {st === 'All' ? 'All orders' : STATUS_LABEL[st]}
              <span>{counts[st] || 0}</span>
            </button>
          ))}
        </div>

        {!showForm && (
          <button className="ap-btn-primary" type="button" onClick={() => setShowForm(true)}>
            <Plus size={16} strokeWidth={2.5} />
            Record sale
          </button>
        )}
      </div>

      {showForm && (
        <div className="ap-panel ap-form-panel">
          <h3>Record a Sale</h3>
          {formError && <p className="ap-empty-state">{formError}</p>}
          <form className="ap-prod-form" onSubmit={handleSubmit}>
            <div className="ap-form-row">
              <div className="ap-form-field">
                <label>Product *</label>
                <select value={saleForm.productId} onChange={(e) => handleProductChange(e.target.value)} required>
                  <option value="">Select a product</option>
                  {products.map((p) => (
                    <option key={p._id} value={p._id}>{p.name} (stock: {p.stock ?? 0})</option>
                  ))}
                </select>
              </div>
              <div className="ap-form-field">
                <label>Customer Name *</label>
                <input type="text" value={saleForm.customerName} onChange={(e) => setSaleForm((f) => ({ ...f, customerName: e.target.value }))} required />
              </div>
              <div className="ap-form-field">
                <label>Customer Contact</label>
                <input type="text" value={saleForm.customerContact} onChange={(e) => setSaleForm((f) => ({ ...f, customerContact: e.target.value }))} />
              </div>
            </div>
            <div className="ap-form-row">
              <div className="ap-form-field" style={{ gridColumn: '1 / -1' }}>
                <label>Delivery Address</label>
                <input type="text" value={saleForm.deliveryAddress} onChange={(e) => setSaleForm((f) => ({ ...f, deliveryAddress: e.target.value }))} placeholder="Optional for pickup orders" />
              </div>
            </div>
            <div className="ap-form-row">
              <div className="ap-form-field">
                <label>Quantity (kg) *</label>
                <input type="number" min="1" max={selectedProduct?.stock || undefined} value={saleForm.quantity} onChange={(e) => setSaleForm((f) => ({ ...f, quantity: e.target.value }))} required />
              </div>
              <div className="ap-form-field">
                <label>Unit Price (₱/kg)</label>
                <input type="number" min="0" step="0.01" value={saleForm.unitPrice} onChange={(e) => setSaleForm((f) => ({ ...f, unitPrice: e.target.value }))} />
              </div>
              <div className="ap-form-field">
                <label>Delivery Fee (₱)</label>
                <input type="number" min="0" step="0.01" value={saleForm.deliveryFee} onChange={(e) => setSaleForm((f) => ({ ...f, deliveryFee: e.target.value }))} />
              </div>
              <div className="ap-form-field">
                <label>Payment Method</label>
                <select value={saleForm.paymentMethod} onChange={(e) => setSaleForm((f) => ({ ...f, paymentMethod: e.target.value }))}>
                  <option value="Cash/COD">Cash / COD</option>
                  <option value="GCash">GCash</option>
                  <option value="PayMongo">PayMongo</option>
                </select>
              </div>
            </div>
            <div className="ap-form-row">
              <div className="ap-form-field">
                <label>Order Date</label>
                <input type="date" value={saleForm.orderDate} onChange={(e) => setSaleForm((f) => ({ ...f, orderDate: e.target.value }))} />
              </div>
              <div className="ap-form-field">
                <label>Starting Status</label>
                <select value={saleForm.status} onChange={(e) => setSaleForm((f) => ({ ...f, status: e.target.value }))}>
                  <option value="pending">Pending (not yet confirmed)</option>
                  <option value="confirmed">Confirmed (deducts stock now)</option>
                  <option value="completed">Completed (already fulfilled)</option>
                </select>
              </div>
              <div className="ap-form-field">
                <label>Total</label>
                <div className="ap-form-total">₱{total.toLocaleString(undefined, { minimumFractionDigits: 2 })}</div>
              </div>
            </div>
            <div className="ap-form-actions">
              <button type="button" className="ap-btn-ghost" onClick={() => { setShowForm(false); setSaleForm(EMPTY_SALE); }}>Cancel</button>
              <button type="submit" className="ap-btn-primary" disabled={submitting}>{submitting ? 'Saving…' : 'Record Sale'}</button>
            </div>
          </form>
        </div>
      )}

      {error && <p className="ap-empty-state">{error}</p>}

      {loading && <div className="ap-skeleton" style={{ height: 300 }} />}

      {!loading && (
        <div className="ap-panel ap-orders-list-panel">
          <div className="ap-orders-list-head">
            <h3>{statusTab === 'All' ? 'All orders' : STATUS_LABEL[statusTab]}</h3>
            <span>{filteredOrders.length} shown</span>
          </div>

          {filteredOrders.length === 0 ? (
            <div className="ap-empty-state">
              <ClipboardList size={26} strokeWidth={1.6} />
              <p>
                {orders.length === 0
                  ? 'No orders yet. Use Record sale to log an order you took in person.'
                  : 'No orders with this status.'}
              </p>
            </div>
          ) : (
            <ul className="ap-order-list">
              {filteredOrders.map((o) => (
                <li key={o._id}>
                  <div className="ap-order-row">
                    <span className="ap-order-row-main">
                      <span className="ap-order-list-id">{o.orderNumber}</span>
                      <span className="ap-order-list-buyer">{o.customerName}</span>
                    </span>

                    <span className="ap-order-row-product">
                      {o.productName} · {o.quantity} kg
                    </span>

                    <span className={`ap-badge ap-badge-${o.status}`}>
                      {STATUS_LABEL[o.status] || o.status}
                    </span>

                    <span className="ap-order-list-amount">
                      ₱{Number(o.total).toLocaleString()}
                    </span>

                    <span className="ap-order-row-date">
                      {new Date(o.orderDate).toLocaleDateString('en-PH', { month: 'short', day: 'numeric' })}
                    </span>

                    <button
                      type="button"
                      className="ap-btn-ghost ap-btn-sm ap-order-row-open"
                      onClick={() => setSelectedId(o._id)}
                    >
                      Details
                      <ChevronRight size={14} strokeWidth={2.3} />
                    </button>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </div>
      )}

      {selectedOrder && (
        <OrderDetailView
          order={selectedOrder}
          statusLabel={STATUS_LABEL}
          statusHint={STATUS_HINT}
          nextStatuses={NEXT_STATUSES}
          actionLabel={ACTION_LABEL}
          actionNote={ACTION_NOTE}
          busy={actionBusy}
          onClose={() => setSelectedId(null)}
          onTransition={handleTransition}
          onReviewPayment={handleReviewPayment}
        />
      )}

      {cancelTarget && (
        <div className="ap-modal-overlay">
          <div className="ap-modal ap-modal-md">
            <h3>Cancel {cancelTarget.orderNumber}?</h3>
            <div className="ap-form-field" style={{ marginBottom: '0.9rem' }}>
              <label>Reason (required, visible to buyer)</label>
              <input type="text" value={cancelReason} onChange={(e) => setCancelReason(e.target.value)} autoFocus />
            </div>
            <div className="ap-modal-actions">
              <button className="ap-modal-cancel" type="button" onClick={() => setCancelTarget(null)}>Never mind</button>
              <button className="ap-modal-confirm" type="button" disabled={!cancelReason.trim() || actionBusy} onClick={confirmCancel}>
                {actionBusy ? 'Cancelling…' : 'Confirm Cancel'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
