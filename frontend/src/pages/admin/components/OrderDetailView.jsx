import React, { useEffect, useState } from 'react';
import {
  ArrowLeft,
  User,
  Package,
  Receipt,
  Clock,
  MapPin,
  Phone,
  CheckCircle2,
  XCircle,
  ImageIcon,
} from 'lucide-react';
import { API_ORIGIN } from '../../../services/authApi';
import PrivateFileModal from '../../../components/PrivateFileModal';
import { fetchRiders, assignRider } from '../../../services/riderApi';
import DeliveryMap from './DeliveryMap';
import './OrderDetailView.css';

function peso(n) {
  return `₱${Number(n || 0).toLocaleString('en-PH', { maximumFractionDigits: 2 })}`;
}

function fullDate(value) {
  return new Date(value).toLocaleString('en-PH', {
    month: 'long', day: 'numeric', year: 'numeric',
    hour: 'numeric', minute: '2-digit',
  });
}

const PAYMENT_STATE = {
  unpaid:     { tone: 'idle', label: 'Unpaid',          text: 'No payment recorded yet.' },
  proof_sent: { tone: 'warn', label: 'Proof submitted', text: 'The buyer says they paid. Open your GCash and check before confirming.' },
  paid:       { tone: 'good', label: 'Paid',            text: 'You confirmed this money arrived.' },
  rejected:   { tone: 'bad',  label: 'Not received',    text: 'You checked and the payment was not there.' },
};

export default function OrderDetailView({
  order,
  statusLabel,
  statusHint,
  nextStatuses,
  actionLabel,
  actionNote,
  busy,
  onClose,
  onTransition,
  onReviewPayment,
}) {
  const [proofOpen, setProofOpen] = useState(false);
  const [riders, setRiders] = useState([]);
  const [assigning, setAssigning] = useState(false);
  const [assignError, setAssignError] = useState('');
  const [assignedTo, setAssignedTo] = useState(order.delivery?.riderUserId ?? '');
  const [deliveryProofOpen, setDeliveryProofOpen] = useState(false);

  useEffect(() => {
    let cancelled = false;
    fetchRiders()
      .then((res) => {
        if (!cancelled) setRiders(Array.isArray(res.data) ? res.data : []);
      })
      .catch(() => {
        // No delivery people is a normal state, not an error worth shouting
        // about on an order screen.
      });
    return () => {
      cancelled = true;
    };
  }, []);

  async function assignTo(value) {
    setAssigning(true);
    setAssignError('');
    try {
      await assignRider(order._id, value === '' ? null : Number(value));
      setAssignedTo(value);
    } catch (err) {
      setAssignError(err.response?.data?.error || 'Could not assign that person.');
    } finally {
      setAssigning(false);
    }
  }
  const [rejecting, setRejecting] = useState(false);
  const [rejectNote, setRejectNote] = useState('');

  // Escape closes the workspace; the page behind it stays put.
  useEffect(() => {
    const onKey = (e) => { if (e.key === 'Escape') onClose(); };
    document.addEventListener('keydown', onKey);
    const prev = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    return () => {
      document.removeEventListener('keydown', onKey);
      document.body.style.overflow = prev;
    };
  }, [onClose]);

  const actions = nextStatuses[order.status] || [];
  const notes = actions.filter((n) => actionNote[n]);
  const pay = PAYMENT_STATE[order.paymentStatus] || PAYMENT_STATE.unpaid;
  const awaitingReview = order.paymentStatus === 'proof_sent';

  return (
    <div
      className="odv-overlay"
      role="dialog"
      aria-modal="true"
      aria-label={`Order ${order.orderNumber}`}
    >
      <header className="odv-topbar">
        <button
          type="button"
          className="odv-back"
          onClick={onClose}
          aria-label="Back to orders"
          title="Back to orders"
        >
          <ArrowLeft size={22} strokeWidth={2.2} />
        </button>

        <div className="odv-topbar-title">
          <span className="odv-eyebrow">Order</span>
          <span className="odv-number">{order.orderNumber}</span>
        </div>

        <div className="odv-spacer" />

        <span className={`ap-badge ap-badge-${order.status}`}>
          {statusLabel[order.status] || order.status}
        </span>
      </header>

      <div className="odv-body">
        <div className="odv-grid">
          {/* ---------- Left: what this order is ---------- */}
          <div className="odv-main">
            <section className="odv-card odv-stage">
              <p className="odv-stage-text">{statusHint[order.status]}</p>
              <span className="odv-stage-date">Placed {fullDate(order.orderDate)}</span>
            </section>

            <section className="odv-card">
              <h3><User size={16} strokeWidth={2.2} /> Buyer</h3>
              <div className="odv-card-body">
                <p className="odv-buyer-name">{order.customerName}</p>
                {order.customerContact && (
                  <p className="odv-line"><Phone size={14} strokeWidth={2.2} />{order.customerContact}</p>
                )}
                {order.deliveryAddress && (
                  <p className="odv-line"><MapPin size={14} strokeWidth={2.2} />{order.deliveryAddress}</p>
                )}
                {!order.customerContact && !order.deliveryAddress && (
                  <p className="odv-muted">No contact or address recorded.</p>
                )}
              </div>
            </section>

            <section className="odv-card">
              <h3><Package size={16} strokeWidth={2.2} /> Items</h3>
              <div className="odv-card-body">
                <div className="odv-item">
                  <div>
                    <span className="odv-item-name">{order.productName}</span>
                    <span className="odv-item-qty">{order.quantity} kg</span>
                  </div>
                  <span className="odv-item-amount">
                    {peso(order.subtotal ?? order.total)}
                  </span>
                </div>
              </div>
            </section>

            {['shipped', 'delivered'].includes(order.status) && (
              <DeliveryMap
                orderId={order._id}
                orderNumber={order.orderNumber}
                canUpdate={order.status === 'shipped'}
              />
            )}

            {order.statusHistory?.length > 0 && (
              <section className="odv-card">
                <h3><Clock size={16} strokeWidth={2.2} /> Timeline</h3>
                <div className="odv-card-body">
                  <ul className="odv-timeline">
                    {order.statusHistory.map((h, i) => (
                      <li key={`${h.status}-${i}`}>
                        <strong>{statusLabel[h.status] || h.status}</strong>
                        <span>{fullDate(h.changedAt)}</span>
                        {h.reason && <em>{h.reason}</em>}
                      </li>
                    ))}
                  </ul>
                </div>
              </section>
            )}
          </div>

          {/* ---------- Right: money and next step ---------- */}
          <aside className="odv-side">
            <section className="odv-card">
              <h3><Receipt size={16} strokeWidth={2.2} /> Payment</h3>
              <div className="odv-card-body">
                <div className="odv-row">
                  <span>Subtotal</span>
                  <span>{peso(order.subtotal ?? order.total)}</span>
                </div>
                <div className="odv-row">
                  <span>Delivery fee</span>
                  <span>{peso(order.deliveryFee || 0)}</span>
                </div>
                <div className="odv-row odv-row-total">
                  <span>Total</span>
                  <span>{peso(order.total)}</span>
                </div>
                <div className="odv-row odv-row-method">
                  <span>Method</span>
                  <span>{order.paymentMethod || 'Cash/COD'}</span>
                </div>

                <div className={`odv-pay-state odv-pay-state--${pay.tone}`}>
                  <strong>{pay.label}</strong>
                  <span>{pay.text}</span>
                </div>

                {order.paymentStatus === 'paid' && order.paidAt && (
                  <p className="odv-note">
                    {peso(order.amountPaid)} confirmed on {fullDate(order.paidAt)}.
                  </p>
                )}

                {order.paymentNote && (
                  <p className="odv-note">Note: {order.paymentNote}</p>
                )}

                {order.paymentProof && (
                  <button
                    className="odv-proof"
                    type="button"
                    onClick={() => setProofOpen(true)}
                  >
                    <ImageIcon size={15} strokeWidth={2.2} />
                    View the buyer&apos;s proof of payment
                  </button>
                )}

                {awaitingReview && !rejecting && (
                  <>
                    <p className="odv-note odv-note-strong">
                      Check your own GCash app first. Only confirm if the money is
                      really there — a screenshot can be edited.
                    </p>
                    <div className="odv-actions">
                      <button
                        type="button"
                        className="ap-btn-primary"
                        disabled={busy}
                        onClick={() => onReviewPayment(order, { paid: true })}
                      >
                        <CheckCircle2 size={15} strokeWidth={2.3} />
                        I received it
                      </button>
                      <button
                        type="button"
                        className="ap-btn-ghost"
                        disabled={busy}
                        onClick={() => setRejecting(true)}
                      >
                        <XCircle size={15} strokeWidth={2.3} />
                        Not received
                      </button>
                    </div>
                  </>
                )}

                {awaitingReview && rejecting && (
                  <div className="odv-reject">
                    <label htmlFor="odv-reject-note">Tell the buyer what was wrong</label>
                    <input
                      id="odv-reject-note"
                      type="text"
                      value={rejectNote}
                      onChange={(e) => setRejectNote(e.target.value)}
                      placeholder="e.g. Nothing arrived in my GCash"
                    />
                    <div className="odv-actions">
                      <button
                        type="button"
                        className="ap-btn-ghost"
                        onClick={() => { setRejecting(false); setRejectNote(''); }}
                      >
                        Never mind
                      </button>
                      <button
                        type="button"
                        className="ap-btn-primary"
                        disabled={busy || !rejectNote.trim()}
                        onClick={() => onReviewPayment(order, { paid: false, note: rejectNote.trim() })}
                      >
                        Mark as not received
                      </button>
                    </div>
                  </div>
                )}
              </div>
            </section>

            <section className="odv-card">
              <h3>Delivery person</h3>
              <div className="odv-card-body">
                {riders.length === 0 ? (
                  <p className="odv-muted">
                    You have no delivery people yet. Add one under Delivery, and
                    they will appear here.
                  </p>
                ) : (
                  <>
                    <select
                      className="odv-assign"
                      value={assignedTo}
                      disabled={assigning}
                      onChange={(e) => assignTo(e.target.value)}
                    >
                      <option value="">Nobody assigned</option>
                      {riders
                        .filter((r) => r.status !== 'suspended')
                        .map((r) => (
                          <option key={r.userId} value={r.userId}>
                            {r.name}
                            {r.activated ? '' : ' — has not signed in yet'}
                          </option>
                        ))}
                    </select>
                    <p className="odv-note">
                      Assigning is what lets them see this order and share the
                      truck&apos;s position. They see nothing else of yours.
                    </p>
                  </>
                )}
                {assignError && <p className="ap-form-error">{assignError}</p>}

                {order.delivery?.proofOfDelivery && (
                  <button
                    className="odv-proof"
                    type="button"
                    onClick={() => setDeliveryProofOpen(true)}
                  >
                    <ImageIcon size={15} strokeWidth={2.2} />
                    View proof of delivery
                  </button>
                )}
              </div>
            </section>

            <section className="odv-card">
              <h3>Next step</h3>
              <div className="odv-card-body">
                {actions.length === 0 ? (
                  <p className="odv-muted">
                    This order is {statusLabel[order.status]?.toLowerCase()} — nothing left to do.
                  </p>
                ) : (
                  <>
                    <div className="odv-actions">
                      {actions.map((next) => (
                        <button
                          key={next}
                          type="button"
                          className={next === 'cancelled' ? 'ap-btn-ghost' : 'ap-btn-primary'}
                          disabled={busy}
                          onClick={() => onTransition(order, next)}
                        >
                          {actionLabel[next] || `Mark as ${statusLabel[next]}`}
                        </button>
                      ))}
                    </div>
                    {notes.map((next) => (
                      <p className="odv-note" key={`note-${next}`}>{actionNote[next]}</p>
                    ))}
                  </>
                )}
              </div>
            </section>
          </aside>
        </div>
      </div>

      {proofOpen && (
        <PrivateFileModal
          path={order.paymentProof}
          title={`Proof of payment — ${order.orderNumber}`}
          onClose={() => setProofOpen(false)}
        />
      )}

      {deliveryProofOpen && (
        <PrivateFileModal
          path={order.delivery.proofOfDelivery}
          title={`Proof of delivery — ${order.orderNumber}`}
          onClose={() => setDeliveryProofOpen(false)}
        />
      )}
    </div>
  );
}
