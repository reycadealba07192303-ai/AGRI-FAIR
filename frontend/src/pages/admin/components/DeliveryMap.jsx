import React, { useEffect, useState, useCallback, useRef, useMemo } from 'react';
import { MapContainer, TileLayer, Marker, Popup, Polyline, useMap } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { MapPin, Navigation, Truck, RefreshCw, Store, Home } from 'lucide-react';
import API from '../../../services/authApi';
import { updateAccount } from '../../../services/userApi';
import './DeliveryMap.css';

/**
 * Leaflet's default marker images are resolved relative to the CSS, which the
 * bundler rewrites — so markers vanish. Building the icons inline avoids it.
 */
const pin = (modifier) =>
  L.divIcon({
    className: 'dm-pin-wrap',
    html: `<div class="dm-pin dm-pin--${modifier}"></div>`,
    iconSize: [26, 26],
    iconAnchor: [13, 13],
  });

const riderIcon = pin('rider');
const shopIcon = pin('shop');
const doorIcon = pin('door');

/**
 * Frames every point that exists rather than centring on one.
 *
 * A map zoomed to the shop with the destination off-screen answers nothing —
 * the question is how far apart they are.
 */
function FitRoute({ points }) {
  const map = useMap();
  const last = useRef(null);

  useEffect(() => {
    if (!points.length) return;

    const key = points.map((p) => p.join(',')).join('|');
    if (last.current === key) return;
    last.current = key;

    if (points.length === 1) {
      map.setView(points[0], 15, { animate: true });
      return;
    }

    map.fitBounds(points, { padding: [40, 40], maxZoom: 16, animate: true });
  }, [points, map]);

  return null;
}

export default function DeliveryMap({ orderId, orderNumber, canUpdate }) {
  const [tracking, setTracking] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [sending, setSending] = useState(false);
  const [pinningShop, setPinningShop] = useState(false);

  const load = useCallback(async () => {
    try {
      const res = await API.get(`/delivery/${orderId}`);
      setTracking(res.data);
      setError('');
    } catch (err) {
      setError(err.response?.data?.error || 'Could not load tracking.');
    } finally {
      setLoading(false);
    }
  }, [orderId]);

  useEffect(() => {
    load();
    // The courier's position only changes every so often; polling is enough.
    const timer = setInterval(load, 15000);
    return () => clearInterval(timer);
  }, [load]);

  /** Reads the browser's position once, for whichever button asked for it. */
  function withPosition(onFix, onFail) {
    if (!navigator.geolocation) {
      setError('This browser cannot share a location.');
      onFail();
      return;
    }

    navigator.geolocation.getCurrentPosition(
      (pos) => onFix(pos.coords.latitude, pos.coords.longitude),
      () => {
        setError('Location permission was denied.');
        onFail();
      },
      { enableHighAccuracy: true, timeout: 10000 },
    );
  }

  /** Pushes the seller's own device position as the courier location. */
  function shareMyLocation() {
    setSending(true);
    withPosition(
      async (lat, lng) => {
        try {
          await API.put(`/delivery/${orderId}/location`, { lat, lng });
          await load();
        } catch (err) {
          setError(err.response?.data?.error || 'Could not send the location.');
        } finally {
          setSending(false);
        }
      },
      () => setSending(false),
    );
  }

  /**
   * Saves where the rice is collected from.
   *
   * Stored on the seller, not on this order, so it applies to every order they
   * ship from here — including the ones already out there, which fall back to
   * the current pickup point when they were placed before it was set.
   */
  function pinMyShop() {
    setPinningShop(true);
    withPosition(
      async (lat, lng) => {
        try {
          await updateAccount({ pickupLat: lat, pickupLng: lng });
          await load();
        } catch (err) {
          setError(err.response?.data?.message || 'Could not save the pickup point.');
        } finally {
          setPinningShop(false);
        }
      },
      () => setPinningShop(false),
    );
  }

  const pickup = tracking?.pickup;
  const dropoff = tracking?.dropoff;

  const hasCourier = tracking?.isLive && tracking?.lat != null && tracking?.lng != null;
  const hasPickup = pickup?.lat != null && pickup?.lng != null;
  const hasDropoff = dropoff?.lat != null && dropoff?.lng != null;

  // Shop first, rider in the middle, door last — the order they occur in.
  const points = useMemo(() => {
    const list = [];
    if (hasPickup) list.push([pickup.lat, pickup.lng]);
    if (hasCourier) list.push([tracking.lat, tracking.lng]);
    if (hasDropoff) list.push([dropoff.lat, dropoff.lng]);
    return list;
  }, [hasPickup, hasCourier, hasDropoff, pickup, dropoff, tracking]);

  if (loading) return <div className="dm-skeleton" />;

  // A barangay centre is not a front door, and the map must not imply it is.
  const approximate = dropoff?.precision === 'approximate';

  const missing = [
    !hasPickup && 'your shop has no pickup point',
    !hasDropoff && 'the delivery address could not be placed on the map',
  ].filter(Boolean);

  return (
    <div className="dm-root">
      <div className="dm-head">
        <div>
          <span className="ap-panel-tag">Live delivery</span>
          <h2>Where {orderNumber} is now</h2>
        </div>
        {canUpdate && (
          <div className="dm-actions">
            {!hasPickup && (
              <button
                className="ap-btn-ghost ap-btn-sm"
                type="button"
                onClick={pinMyShop}
                disabled={pinningShop}
              >
                <Store size={14} strokeWidth={2.3} />
                {pinningShop ? 'Saving…' : 'Pin my shop'}
              </button>
            )}
            <button
              className="ap-btn-ghost ap-btn-sm"
              type="button"
              onClick={shareMyLocation}
              disabled={sending}
            >
              <Navigation size={14} strokeWidth={2.3} />
              {sending ? 'Sending…' : 'Share my location'}
            </button>
          </div>
        )}
      </div>

      {error && <p className="ap-form-error">{error}</p>}

      {!tracking?.isLive && (
        <div className="dm-notice">
          <Truck size={16} strokeWidth={2.2} />
          <span>
            {tracking?.status === 'shipped' || tracking?.status === 'delivered'
              ? 'No position shared yet. Tap "Share my location" while you are on the way.'
              : 'Live tracking starts once you mark this order as shipped.'}
          </span>
        </div>
      )}

      {points.length > 0 ? (
        <>
          <div className="dm-map">
            <MapContainer center={points[0]} zoom={14} scrollWheelZoom={false}>
              <TileLayer
                attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
                url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
              />

              {points.length > 1 && (
                // Dashed: this is the line between two places, not the road a
                // rider will actually take.
                <Polyline positions={points} pathOptions={{ color: '#4A7C59', weight: 3, dashArray: '7 6' }} />
              )}

              {hasPickup && (
                <Marker position={[pickup.lat, pickup.lng]} icon={shopIcon}>
                  <Popup>Picked up here{pickup.address ? ` — ${pickup.address}` : ''}</Popup>
                </Marker>
              )}

              {hasDropoff && (
                <Marker position={[dropoff.lat, dropoff.lng]} icon={doorIcon}>
                  <Popup>
                    {approximate ? 'Barangay of the delivery address' : 'Deliver here'}
                    {dropoff.address ? ` — ${dropoff.address}` : ''}
                  </Popup>
                </Marker>
              )}

              {hasCourier && (
                <Marker position={[tracking.lat, tracking.lng]} icon={riderIcon}>
                  <Popup>
                    {tracking.courierName || 'Courier'}
                    {tracking.etaMinutes != null && <> · about {tracking.etaMinutes} min away</>}
                  </Popup>
                </Marker>
              )}

              <FitRoute points={points} />
            </MapContainer>
          </div>

          <div className="dm-legs">
            <span className="dm-leg">
              <i className="dm-dot dm-dot--shop" />
              <Store size={13} strokeWidth={2.3} />
              {hasPickup ? pickup.address || 'Pinned shop' : 'Pickup point not set'}
            </span>
            <span className="dm-leg">
              <i className="dm-dot dm-dot--door" />
              <Home size={13} strokeWidth={2.3} />
              {dropoff?.address || 'No address on this order'}
            </span>
            {approximate && (
              <span className="dm-approx">
                The delivery pin is the barangay, not the door. Follow the written
                address and landmark from there.
              </span>
            )}
          </div>

          {missing.length > 0 && (
            <p className="dm-gap">
              The map is incomplete because {missing.join(' and ')}.
            </p>
          )}

          <div className="dm-meta">
            {tracking?.updatedAt && (
              <span>
                <RefreshCw size={13} strokeWidth={2.3} />
                Updated {new Date(tracking.updatedAt).toLocaleTimeString('en-PH', {
                  hour: 'numeric',
                  minute: '2-digit',
                })}
              </span>
            )}
            {tracking?.etaMinutes != null && <span>ETA {tracking.etaMinutes} min</span>}
          </div>
        </>
      ) : (
        <div className="dm-empty">
          <MapPin size={26} strokeWidth={1.6} />
          <p>
            Nothing to map yet — {missing.join(', and ')}.
            {canUpdate && !hasPickup && ' Tap "Pin my shop" while you are at it.'}
          </p>
        </div>
      )}
    </div>
  );
}
