import React, { useCallback, useEffect, useState } from 'react';
import { UserPlus, Mail, CheckCircle2, Clock, Ban, RotateCcw, RefreshCw } from 'lucide-react';
import {
  fetchRiders,
  addRider,
  resendRiderCode,
  toggleRiderSuspension,
} from '../../../services/riderApi';
import './DeliveryPeopleTab.css';

/**
 * The people who carry the rice.
 *
 * A delivery person does not sign themselves up. Their name and email is the
 * whole form — the account is created with a random password nobody is told,
 * not even you, so a seller cannot sign in as their own staff. The rider gets
 * a six-digit code by email and chooses their own password from the delivery
 * portal.
 */
export default function DeliveryPeopleTab() {
  const [riders, setRiders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [busy, setBusy] = useState('');
  const [form, setForm] = useState({ name: '', email: '', contact: '' });

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const res = await fetchRiders();
      setRiders(Array.isArray(res.data) ? res.data : []);
      setError('');
    } catch (err) {
      setError(err.response?.data?.error || 'Could not load your delivery people.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  async function submit(e) {
    e.preventDefault();
    setBusy('add');
    setError('');
    setNotice('');

    try {
      const res = await addRider(form);
      setForm({ name: '', email: '', contact: '' });
      setNotice(
        res.data?.codeSent
          ? `Code sent to ${res.data.email}. They set their own password from the delivery portal.`
          : `${res.data?.name} was added, but the code could not be emailed. Use "Resend code".`,
      );
      await load();
    } catch (err) {
      setError(err.response?.data?.error || 'Could not add that person.');
    } finally {
      setBusy('');
    }
  }

  async function act(key, fn, done) {
    setBusy(key);
    setError('');
    setNotice('');
    try {
      await fn();
      setNotice(done);
      await load();
    } catch (err) {
      setError(err.response?.data?.error || 'That did not work.');
    } finally {
      setBusy('');
    }
  }

  return (
    <div className="ap-tab-content">
      <div className="dp-grid">
        <section className="ap-panel dp-form-panel">
          <div className="ap-panel-head">
            <h2>Add a delivery person</h2>
          </div>

          <p className="dp-lede">
            Name and email is all you need. They get a code by email and choose
            their own password — you never see it, and cannot sign in as them.
          </p>

          <form onSubmit={submit} className="dp-form">
            <label>
              <span>Full name</span>
              <input
                type="text"
                required
                value={form.name}
                placeholder="Juan Dela Cruz"
                onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
              />
            </label>
            <label>
              <span>Email</span>
              <input
                type="email"
                required
                value={form.email}
                placeholder="juan@example.com"
                onChange={(e) => setForm((f) => ({ ...f, email: e.target.value }))}
              />
            </label>
            <label>
              <span>Contact number <em>optional</em></span>
              <input
                type="tel"
                value={form.contact}
                placeholder="09XX XXX XXXX"
                onChange={(e) => setForm((f) => ({ ...f, contact: e.target.value }))}
              />
            </label>

            <button className="ap-btn-primary" type="submit" disabled={busy === 'add'}>
              <UserPlus size={15} strokeWidth={2.3} />
              {busy === 'add' ? 'Adding…' : 'Add and send the code'}
            </button>
          </form>

          {error && <p className="ap-form-error">{error}</p>}
          {notice && <p className="dp-notice">{notice}</p>}
        </section>

        <section className="ap-panel">
          <div className="ap-panel-head">
            <h2>Your delivery people</h2>
            <button className="dp-refresh" type="button" onClick={load}>
              <RefreshCw size={14} strokeWidth={2.3} /> Refresh
            </button>
          </div>

          {loading ? (
            <div className="dp-skeleton" />
          ) : riders.length === 0 ? (
            <p className="ap-empty-state">
              Nobody yet. Add somebody and they will appear in the assign list on
              each order.
            </p>
          ) : (
            <ul className="dp-list">
              {riders.map((rider) => (
                <li className="dp-row" key={rider.userId}>
                  <div className="dp-who">
                    <strong>{rider.name}</strong>
                    <span>
                      {rider.email}
                      {rider.contact ? ` · ${rider.contact}` : ''} · ID {rider.userId}
                    </span>
                  </div>

                  <div className="dp-state">
                    {rider.status === 'suspended' ? (
                      <span className="dp-chip dp-chip--off">
                        <Ban size={12} strokeWidth={2.4} /> Suspended
                      </span>
                    ) : rider.activated ? (
                      <span className="dp-chip dp-chip--on">
                        <CheckCircle2 size={12} strokeWidth={2.4} /> Active
                      </span>
                    ) : (
                      <span className="dp-chip dp-chip--wait">
                        <Clock size={12} strokeWidth={2.4} /> Has not signed in yet
                      </span>
                    )}
                  </div>

                  <div className="dp-actions">
                    {!rider.activated && rider.status !== 'suspended' && (
                      <button
                        type="button"
                        className="ap-btn-ghost ap-btn-sm"
                        disabled={busy === `code-${rider.userId}`}
                        onClick={() =>
                          act(
                            `code-${rider.userId}`,
                            () => resendRiderCode(rider.userId),
                            `New code sent to ${rider.email}.`,
                          )
                        }
                      >
                        <Mail size={13} strokeWidth={2.3} /> Resend code
                      </button>
                    )}
                    <button
                      type="button"
                      className="ap-btn-ghost ap-btn-sm"
                      disabled={busy === `susp-${rider.userId}`}
                      onClick={() =>
                        act(
                          `susp-${rider.userId}`,
                          () => toggleRiderSuspension(rider.userId),
                          rider.status === 'suspended'
                            ? `${rider.name} can take deliveries again.`
                            : `${rider.name} is suspended.`,
                        )
                      }
                    >
                      {rider.status === 'suspended' ? (
                        <>
                          <RotateCcw size={13} strokeWidth={2.3} /> Reinstate
                        </>
                      ) : (
                        <>
                          <Ban size={13} strokeWidth={2.3} /> Suspend
                        </>
                      )}
                    </button>
                  </div>
                </li>
              ))}
            </ul>
          )}

          <p className="dp-foot">
            Suspending never deletes. Their name is on the orders they already
            delivered, and those would otherwise lose track of who carried them.
          </p>
        </section>
      </div>
    </div>
  );
}
