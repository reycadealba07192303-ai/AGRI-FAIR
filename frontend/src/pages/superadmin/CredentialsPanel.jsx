import React, { useCallback, useEffect, useState } from 'react';
import { BadgeCheck, ShieldAlert, Wallet, FileText, RefreshCw, Clock } from 'lucide-react';
import { fetchSellerCredentials, reviewCredential } from '../../services/superAdminApi';
import PrivateFileModal from '../../components/PrivateFileModal';
import './CredentialsPanel.css';

/**
 * Where a seller's GCash account and compliance documents are approved.
 *
 * Nothing a seller submits is trusted until somebody here has looked at it. A
 * payout that is merely submitted shows the buyer nothing at all — the server
 * withholds the account details until this panel marks it verified — so this
 * is the step that makes GCash appear in the app.
 *
 * Decided credentials stay on this list rather than disappearing. An approval
 * that vanishes cannot be checked later, and a QR that turns out to belong to
 * somebody else has to be revocable.
 */
export default function CredentialsPanel() {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState('');
  const [reasons, setReasons] = useState({});
  const [viewing, setViewing] = useState(null);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const res = await fetchSellerCredentials();
      setRows(Array.isArray(res.data) ? res.data : []);
      setError('');
    } catch (err) {
      setError(err.response?.data?.error || 'Could not load the credentials.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  async function decide(userId, body, key) {
    if (!body.approve && !(reasons[key] || '').trim()) {
      setError('Give a reason so the seller knows what to fix.');
      return;
    }

    setBusy(key);
    setError('');
    try {
      await reviewCredential(userId, {
        ...body,
        reason: body.approve ? '' : reasons[key].trim(),
      });
      setReasons((r) => ({ ...r, [key]: '' }));
      await load();
    } catch (err) {
      setError(err.response?.data?.error || 'Could not save that decision.');
    } finally {
      setBusy('');
    }
  }

  /** The badge beside a credential, in the words a reviewer thinks in. */
  function statusChip(status) {
    const label = {
      pending: 'Waiting for review',
      verified: 'Approved',
      rejected: 'Rejected',
    }[status] || 'Not submitted';

    return <span className={`cp-chip cp-chip--${status || 'unset'}`}>{label}</span>;
  }

  /**
   * The decision buttons.
   *
   * Shown whatever the current status: approving an already-approved account
   * is harmless, and rejecting one is how an approval gets taken back.
   */
  function actions(userId, body, key, status) {
    const decided = status === 'verified' || status === 'rejected';

    return (
      <div className="cp-actions">
        <input
          type="text"
          className="cp-reason"
          placeholder="Reason — required to reject"
          value={reasons[key] || ''}
          onChange={(e) => setReasons((r) => ({ ...r, [key]: e.target.value }))}
        />
        {status !== 'verified' && (
          <button
            type="button"
            className="cp-approve"
            disabled={busy === key}
            onClick={() => decide(userId, { ...body, approve: true }, key)}
          >
            <BadgeCheck size={14} strokeWidth={2.3} />
            {busy === key ? 'Saving…' : 'Approve'}
          </button>
        )}
        <button
          type="button"
          className="cp-reject"
          disabled={busy === key}
          onClick={() => decide(userId, { ...body, approve: false }, key)}
        >
          <ShieldAlert size={14} strokeWidth={2.3} />
          {decided && status === 'verified' ? 'Revoke' : 'Reject'}
        </button>
      </div>
    );
  }

  if (loading) return <div className="sa-tab"><div className="cp-skeleton" /></div>;

  const waiting = rows.filter((r) => r.needsReview).length;

  return (
    <div className="sa-tab">
      <div className="sa-panel">
        <div className="sa-panel-head">
          <h2>Seller credentials</h2>
          <button className="cp-refresh" type="button" onClick={load}>
            <RefreshCw size={14} strokeWidth={2.3} /> Refresh
          </button>
        </div>

        <p className="cp-lede">
          A GCash account stays invisible to buyers until it is approved here — the
          server sends no account number, and the app offers cash on delivery instead.
          {waiting > 0 && (
            <>
              {' '}
              <strong>
                {waiting} seller{waiting === 1 ? '' : 's'} waiting on a decision.
              </strong>
            </>
          )}
        </p>

        {error && <p className="cp-error">{error}</p>}

        {rows.length === 0 ? (
          <div className="cp-empty">
            <BadgeCheck size={26} strokeWidth={1.6} />
            <p>No seller has submitted a payout account or a document yet.</p>
          </div>
        ) : (
          rows.map((seller) => (
            <div
              className={`cp-seller ${seller.needsReview ? 'cp-seller--waiting' : ''}`}
              key={seller.userId}
            >
              <div className="cp-seller-head">
                <div>
                  <strong>{seller.name}</strong>
                  <span>
                    {seller.email} · User ID {seller.userId}
                    {seller.sellerType ? ` · ${seller.sellerType}` : ''}
                  </span>
                </div>
                {seller.needsReview && (
                  <span className="cp-waiting">
                    <Clock size={13} strokeWidth={2.3} /> Needs a decision
                  </span>
                )}
              </div>

              {seller.payout && (
                <div className="cp-item">
                  <div className="cp-item-head">
                    <Wallet size={15} strokeWidth={2.2} />
                    <strong>Payout account — {seller.payout.method || 'unset'}</strong>
                    {statusChip(seller.payout.status)}
                  </div>

                  <dl className="cp-fields">
                    <div><dt>Account name</dt><dd>{seller.payout.accountName || '—'}</dd></div>
                    <div><dt>Number</dt><dd>{seller.payout.accountNumber || '—'}</dd></div>
                    <div>
                      <dt>QR</dt>
                      <dd>
                        {seller.payout.qrImage ? (
                          <button
                            type="button"
                            className="cp-link"
                            onClick={() => setViewing({
                              path: seller.payout.qrImage,
                              title: `GCash QR — ${seller.name}`,
                            })}
                          >
                            Open QR image
                          </button>
                        ) : 'Not uploaded'}
                      </dd>
                    </div>
                  </dl>

                  {actions(
                    seller.userId,
                    { kind: 'payout' },
                    `payout-${seller.userId}`,
                    seller.payout.status,
                  )}
                </div>
              )}

              {seller.documents.map((doc) => (
                <div className="cp-item" key={doc.type}>
                  <div className="cp-item-head">
                    <FileText size={15} strokeWidth={2.2} />
                    <strong>{doc.label || doc.type}</strong>
                    {statusChip(doc.status)}
                  </div>

                  <dl className="cp-fields">
                    <div><dt>Reference</dt><dd>{doc.referenceNo || '—'}</dd></div>
                    <div>
                      <dt>File</dt>
                      <dd>
                        {doc.file ? (
                          <button
                            type="button"
                            className="cp-link"
                            onClick={() => setViewing({
                              path: doc.file,
                              title: `${doc.label || doc.type} — ${seller.name}`,
                            })}
                          >
                            Open document
                          </button>
                        ) : 'Not uploaded'}
                      </dd>
                    </div>
                    {doc.rejectionReason && (
                      <div><dt>Rejected because</dt><dd>{doc.rejectionReason}</dd></div>
                    )}
                  </dl>

                  {actions(
                    seller.userId,
                    { kind: 'document', docType: doc.type },
                    `${doc.type}-${seller.userId}`,
                    doc.status,
                  )}
                </div>
              ))}
            </div>
          ))
        )}
      </div>

      {viewing && (
        <PrivateFileModal
          path={viewing.path}
          title={viewing.title}
          onClose={() => setViewing(null)}
        />
      )}
    </div>
  );
}
