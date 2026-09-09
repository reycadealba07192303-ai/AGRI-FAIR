import React, { useCallback, useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Truck, MapPin, Store, Camera, Navigation, LogOut, CheckCircle2, Phone, RefreshCw,
} from 'lucide-react';
import {
  fetchMyDeliveries,
  pushMyLocation,
  uploadDeliveryProof,
} from '../../services/riderApi';
import { clearSession, getSessionUser } from '../../utils/auth';
import './RiderPage.css';

/**
 * The delivery person's whole app.
 *
 * Built for a phone browser rather than a second Flutter build: a rider needs
 * a list, a map link, a location switch and a camera, and a web page reaches
 * every phone without anybody installing anything.
 *
 * They see only the orders assigned to them. Working for the seller is not
 * enough on its own - assignment is what opens one.
 */

/** How often the position is sent while sharing is on. */
const PUSH_EVERY_MS = 15000;

export default function RiderPage() {
  const navigate = useNavigate();
  const user = getSessionUser();

  const [deliveries, setDeliveries] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [sharingId, setSharingId] = useState(null);
  const [busy, setBusy] = useState('');
  const [notes, setNotes] = useState({});

  const watchRef = useRef(null);
  const lastPushRef = useRef(0);

  const load = useCallback(async () => {
    try {
      const res = await fetchMyDeliveries();
      setDeliveries(Array.isArray(res.data) ? res.data : []);
      setError('');
    } catch (err) {
      setError(err.response?.data?.error || 'Could not load your deliveries.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
    const timer = setInterval(load, 30000);
    return () => clearInterval(timer);
  }, [load]);

  /** Stops the watch when the page goes away, or the phone keeps reporting. */
  useEffect(() => () => stopSharing(), []);

  function stopSharing() {
    if (watchRef.current != null) {
      navigator.geolocation.clearWatch(watchRef.current);
      watchRef.current = null;
    }
    setSharingId(null);
  }

  /**
   * Follows the phone and sends the position while driving.
   *
   * Throttled rather than sent on every fix: a phone reports far more often
   * than a delivery moves, and the buyer's map polls every fifteen seconds
   * anyway.
   */
  function startSharing(orderId) {
    if (!navigator.geolocation) {
      setError('This phone cannot share a location.');
      return;
    }

    stopSharing();
    setError('');
    setSharingId(orderId);
    lastPushRef.current = 0;

    watchRef.current = navigator.geolocation.watchPosition(
      async (pos) => {
        const now = Date.now();
        if (now - lastPushRef.current < PUSH_EVERY_MS) return;
        lastPushRef.current = now;

        try {
          await pushMyLocation(orderId, {
            lat: pos.coords.latitude,
            lng: pos.coords.longitude,
          });
        } catch (err) {
          setError(err.response?.data?.error || 'Could not send your position.');
          stopSharing();
        }
      },
      () => {
        setError('Location permission was denied.');
        stopSharing();
      },
      { enableHighAccuracy: true, maximumAge: 5000, timeout: 20000 },
    );
  }

  async function markDelivered(orderId, file) {
    if (!file) return;

    setBusy(orderId);
    setError('');
    try {
      await uploadDeliveryProof(orderId, file, notes[orderId] || '');
      if (sharingId === orderId) stopSharing();
      setNotes((n) => ({ ...n, [orderId]: '' }));
      setNotice('Delivered. The seller and the buyer can both see the photo.');
      await load();
    } catch (err) {
      setError(err.response?.data?.error || 'Could not upload that photo.');
    } finally {
      setBusy('');
    }
  }

  function signOut() {
    stopSharing();
    clearSession();
    navigate('/login');
  }

  /** Opens the point in whatever map app the phone has. */
  const mapLink = (point) =>
    point?.lat != null ? `https://www.google.com/maps?q=${point.lat},${point.lng}` : null;

  return (
    <div className="rp-root">
      <header className="rp-head">
        <div className="rp-brand">
          <Truck size={19} strokeWidth={2.3} />
          <div>
            <span>AGRIFAIR DELIVERY</span>
            <strong>{user?.name || 'Rider'}</strong>
          </div>
        </div>
        <div className="rp-head-actions">
          <button type="button" className="rp-icon" onClick={load} title="Refresh">
            <RefreshCw size={16} strokeWidth={2.3} />
          </button>
          <button type="button" className="rp-icon" onClick={signOut} title="Sign out">
            <LogOut size={16} strokeWidth={2.3} />
          </button>
        </div>
      </header>

      {error && <p className="rp-error">{error}</p>}
      {notice && <p className="rp-notice">{notice}</p>}

      {loading ? (
        <div className="rp-skeleton" />
      ) : deliveries.length === 0 ? (
        <div className="rp-empty">
          <Truck size={30} strokeWidth={1.5} />
          <p>Nothing assigned to you right now. Your seller puts orders here.</p>
        </div>
      ) : (
        <ul className="rp-list">
          {deliveries.map((d) => {
            const done = Boolean(d.proofOfDelivery);
            const sharing = sharingId === d.orderId;

            return (
              <li className={`rp-card ${done ? 'rp-card--done' : ''}`} key={d.orderId}>
                <div className="rp-card-head">
                  <div>
                    <strong>{d.orderNumber}</strong>
                    <span>{d.productName} · {d.quantity}x</span>
                  </div>
                  <span className={`rp-chip rp-chip--${done ? 'done' : d.status}`}>
                    {done ? 'Delivered' : d.status}
                  </span>
                </div>

                <div className="rp-leg">
                  <Store size={14} strokeWidth={2.3} />
                  <div>
                    <span>Pick up</span>
                    <p>{d.pickup.address || 'The seller has not written an address'}</p>
                    {mapLink(d.pickup) && (
                      <a href={mapLink(d.pickup)} target="_blank" rel="noreferrer">
                        Open in maps
                      </a>
                    )}
                  </div>
                </div>

                <div className="rp-leg">
                  <MapPin size={14} strokeWidth={2.3} />
                  <div>
                    <span>Deliver to {d.customerName}</span>
                    <p>{d.deliveryAddress}</p>
                    {d.dropoff.precision === 'approximate' && (
                      <em>
                        The pin is the barangay, not the door — read the address
                        and the landmark from there.
                      </em>
                    )}
                    {mapLink(d.dropoff) && (
                      <a href={mapLink(d.dropoff)} target="_blank" rel="noreferrer">
                        Open in maps
                      </a>
                    )}
                    {d.customerContact && (
                      <a className="rp-call" href={`tel:${d.customerContact}`}>
                        <Phone size={12} strokeWidth={2.4} /> {d.customerContact}
                      </a>
                    )}
                  </div>
                </div>

                {d.notes && <p className="rp-order-note">Note: {d.notes}</p>}

                <p className="rp-pay">
                  {d.paymentMethod}
                  {d.paymentStatus === 'paid'
                    ? ' · already paid'
                    : d.paymentMethod?.toLowerCase().includes('cash')
                      ? ` · collect ₱${Number(d.total).toFixed(0)}`
                      : ' · payment not confirmed yet'}
                </p>

                {!done && (
                  <div className="rp-actions">
                    <button
                      type="button"
                      className={sharing ? 'rp-btn rp-btn--live' : 'rp-btn'}
                      onClick={() => (sharing ? stopSharing() : startSharing(d.orderId))}
                    >
                      <Navigation size={15} strokeWidth={2.3} />
                      {sharing ? 'Sharing — tap to stop' : 'Share my location'}
                    </button>

                    <label className={`rp-btn rp-btn--primary ${busy === d.orderId ? 'rp-btn--busy' : ''}`}>
                      <Camera size={15} strokeWidth={2.3} />
                      {busy === d.orderId ? 'Uploading…' : 'Photo at the door'}
                      <input
                        type="file"
                        accept="image/*"
                        capture="environment"
                        hidden
                        disabled={busy === d.orderId}
                        onChange={(e) => markDelivered(d.orderId, e.target.files?.[0])}
                      />
                    </label>

                    <input
                      type="text"
                      className="rp-note"
                      placeholder="Who received it? (optional)"
                      value={notes[d.orderId] || ''}
                      onChange={(e) =>
                        setNotes((n) => ({ ...n, [d.orderId]: e.target.value }))
                      }
                    />
                  </div>
                )}

                {done && (
                  <p className="rp-done">
                    <CheckCircle2 size={14} strokeWidth={2.4} />
                    Photo uploaded{d.deliveryNote ? ` — ${d.deliveryNote}` : ''}
                  </p>
                )}
              </li>
            );
          })}
        </ul>
      )}
    </div>
  );
}
