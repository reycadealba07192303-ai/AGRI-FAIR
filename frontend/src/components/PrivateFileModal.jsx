import React, { useEffect, useState } from 'react';
import { X, Download, AlertCircle } from 'lucide-react';
import API from '../services/authApi';
import './PrivateFileModal.css';

/**
 * Shows a file that lives behind `/api/files`, in place.
 *
 * These are deliberately not served statically — a file behind a guessable URL
 * is a file anyone can take — so they need the session token to read. A plain
 * `<a href>` or `<img src>` sends no Authorization header and comes back 403,
 * which is why "View the buyer's proof of payment" opened a blank tab.
 *
 * Fetched as a blob through the same axios instance every other call uses, so
 * the token rides along, and shown here rather than in a new tab: checking a
 * receipt is something you do *while* deciding whether to accept an order, not
 * somewhere else.
 */
export default function PrivateFileModal({ path, title, onClose }) {
  const [url, setUrl] = useState('');
  const [error, setError] = useState('');
  const [isPdf, setIsPdf] = useState(false);

  useEffect(() => {
    if (!path) return undefined;

    let objectUrl = '';
    let cancelled = false;

    (async () => {
      try {
        // The axios instance is mounted at /api, and these paths already
        // include it.
        const res = await API.get(path.replace(/^\/api/, ''), { responseType: 'blob' });
        if (cancelled) return;

        objectUrl = URL.createObjectURL(res.data);
        setIsPdf(res.data.type === 'application/pdf');
        setUrl(objectUrl);
      } catch (err) {
        if (cancelled) return;
        setError(
          err.response?.status === 403
            ? 'This file is not yours to open.'
            : 'Could not load this file.',
        );
      }
    })();

    return () => {
      cancelled = true;
      if (objectUrl) URL.revokeObjectURL(objectUrl);
    };
  }, [path]);

  useEffect(() => {
    const onKey = (e) => {
      if (e.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose]);

  if (!path) return null;

  return (
    <div className="pfm-backdrop" onClick={onClose} role="presentation">
      <div
        className="pfm-panel"
        onClick={(e) => e.stopPropagation()}
        role="dialog"
        aria-modal="true"
        aria-label={title}
      >
        <div className="pfm-head">
          <h3>{title}</h3>
          <div className="pfm-head-actions">
            {url && (
              <a className="pfm-icon" href={url} download title="Download">
                <Download size={16} strokeWidth={2.2} />
              </a>
            )}
            <button className="pfm-icon" type="button" onClick={onClose} title="Close">
              <X size={17} strokeWidth={2.3} />
            </button>
          </div>
        </div>

        <div className="pfm-body">
          {error && (
            <p className="pfm-error">
              <AlertCircle size={15} strokeWidth={2.2} /> {error}
            </p>
          )}
          {!error && !url && <div className="pfm-loading" />}
          {url && isPdf && <iframe className="pfm-pdf" src={url} title={title} />}
          {url && !isPdf && <img className="pfm-image" src={url} alt={title} />}
        </div>
      </div>
    </div>
  );
}
