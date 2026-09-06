import React, { useEffect, useState, useCallback, useRef } from 'react';
import { MapContainer, TileLayer, Marker, Popup, useMap } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { MapPin, Navigation, Truck, RefreshCw } from 'lucide-react';
import API from '../../../services/authApi';
import './DeliveryMap.css';

/**
 * Leaflet's default marker images are resolved relative to the CSS, which the
 * bundler rewrites — so markers vanish. Building the icon inline avoids it.
 */
const riderIcon = L.divIcon({
  className: 'dm-pin-wrap',
  html: '<div class="dm-pin dm-pin--rider"></div>',
  iconSize: [26, 26],
  iconAnchor: [13, 13],
});

/** Keeps the view centred as the courier moves, without fighting the user. */
function Recenter({ position }) {
  const map = useMap();
  const last = useRef(null);

  useEffect(() => {
    if (!position) return;
    const key = position.join(',');
    if (last.current === key) return;
    last.current = key;
    map.setView(position, map.getZoom(), { animate: true });
  }, [position, map]);

  return null;
}

export default function DeliveryMap({ orderId, orderNumber, canUpdate }) {
  const [tracking, setTracking] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [sending, setSending] = useState(false);

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

  /** Pushes the seller's own device position as the courier location. */
  async function shareMyLocation() {
    if (!navigator.geolocation) {
      setError('This browser cannot share a location.');
      return;
    }

    setSending(true);
    navigator.geolocation.getCurrentPosition(
      async (pos) => {
        try {
          await API.put(`/delivery/${orderId}/location`, {
            lat: pos.coords.latitude,
            lng: pos.coords.longitude,
          });
          await load();
        } catch (err) {
          setError(err.response?.data?.error || 'Could not send the location.');
        } finally {
          setSending(false);
        }
      },
      () => {
        setError('Location permission was denied.');
        setSending(false);
      },
      { enableHighAccuracy: true, timeout: 10000 },
    );
  }

  if (loading) return <div className="dm-skeleton" />;

  const hasPosition = tracking?.lat != null && tracking?.lng != null;
  const position = hasPosition ? [tracking.lat, tracking.lng] : null;

  return (
    <div className="dm-root">
      <div className="dm-head">
        <div>
          <span className="ap-panel-tag">Live delivery</span>
          <h2>Where {orderNumber} is now</h2>
        </div>
        {canUpdate && (
          <button
            className="ap-btn-ghost ap-btn-sm"
            type="button"
            onClick={shareMyLocation}
            disabled={sending}
          >
            <Navigation size={14} strokeWidth={2.3} />
            {sending ? 'Sending…' : 'Share my location'}
          </button>
        )}
      </div>

      {error && <p className="ap-form-error">{error}</p>}

      {!tracking?.isLive && (
        <div className="dm-notice">
          <Truck size={16} strokeWidth={2.2} />
          <span>
            {tracking?.status === 'shipped' || tracking?.status === 'delivered'
              ? 'No position shared yet. Tap "Share my location" while you are on the way.'
              : 'Tracking starts once you mark this order as shipped.'}
          </span>
        </div>
      )}

      {hasPosition ? (
        <>
          <div className="dm-map">
            <MapContainer center={position} zoom={15} scrollWheelZoom={false}>
              <TileLayer
                attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
                url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
              />
              <Marker position={position} icon={riderIcon}>
                <Popup>
                  {tracking.courierName || 'Courier'}
                  {tracking.etaMinutes != null && <> · about {tracking.etaMinutes} min away</>}
                </Popup>
              </Marker>
              <Recenter position={position} />
            </MapContainer>
          </div>

          <div className="dm-meta">
            <span>
              <RefreshCw size={13} strokeWidth={2.3} />
              Updated {new Date(tracking.updatedAt).toLocaleTimeString('en-PH', {
                hour: 'numeric',
                minute: '2-digit',
              })}
            </span>
            {tracking.etaMinutes != null && <span>ETA {tracking.etaMinutes} min</span>}
            {tracking.destination && (
              <span className="dm-dest">
                <MapPin size={13} strokeWidth={2.3} />
                {tracking.destination}
              </span>
            )}
          </div>
        </>
      ) : (
        <div className="dm-empty">
          <MapPin size={26} strokeWidth={1.6} />
          <p>The map appears here once a position has been shared.</p>
        </div>
      )}
    </div>
  );
}
