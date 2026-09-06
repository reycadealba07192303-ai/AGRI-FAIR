import {
  X, QrCode, ShieldCheck, Clock, AlertCircle, Upload,
  UserCog, Sprout, Wallet, MapPin, KeyRound, Bell, BadgeCheck,
  FileCheck, ShieldAlert, Eye,
} from 'lucide-react';
import React, { useEffect, useState } from 'react';
import { fetchMe, updateAccount, changePassword, fetchLoginHistory } from '../../../services/userApi';
import { API_ORIGIN } from '../../../services/authApi';

const SUB_TABS = [
  { id: 'Profile',       icon: UserCog,    hint: 'Name and contact' },
  { id: 'Business',      icon: Sprout,     hint: 'Type, name, and farm' },
  { id: 'Documents',     icon: FileCheck,  hint: 'Permits and registration' },
  { id: 'Payment',       icon: Wallet,     hint: 'How you get paid' },
  { id: 'Addresses',     icon: MapPin,     hint: 'Pickup and dispatch' },
  { id: 'Security',      icon: KeyRound,   hint: 'Password' },
  { id: 'Notifications', icon: Bell,       hint: 'What alerts you' },
];

const SELLER_TYPES = [
  { id: 'farmer',      label: 'Farmer — I grow the rice I sell',        hint: 'You will be asked for your farm details below.' },
  { id: 'cooperative', label: 'Cooperative — we farm as a group',        hint: 'Register under the cooperative name.' },
  { id: 'trader',      label: 'Trader — I buy and resell in bulk',       hint: 'No farm needed; your permits are what matter.' },
  { id: 'retailer',    label: 'Retailer — I sell from a shop or stall',  hint: 'No farm needed; your permits are what matter.' },
];

const PAYOUT_CHIP = {
  unset:    { tone: 'idle', label: 'Payment not set up' },
  pending:  { tone: 'warn', label: 'Payment under review' },
  verified: { tone: 'good', label: 'Payment verified' },
  rejected: { tone: 'bad',  label: 'Payment rejected' },
};

export default function AccountInfoTab() {
  const [sub, setSub] = useState('Profile');
  const [me, setMe] = useState(null);
  const [loading, setLoading] = useState(true);

  const load = async () => {
    try {
      const res = await fetchMe();
      setMe(res.data);
    } catch {
      setMe(null);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    let mounted = true;
    (async () => { if (mounted) await load(); })();
    return () => { mounted = false; };
  }, []);

  if (loading) return <div className="ap-tab-content"><p className="ap-empty-state">Loading account info…</p></div>;
  if (!me) return <div className="ap-tab-content"><p className="ap-empty-state">Could not load your account.</p></div>;

  const initials = (me.name || me.email || '?').trim().split(/\s+/).slice(0, 2)
    .map((w) => w[0]).join('').toUpperCase();
  const chip = PAYOUT_CHIP[me.payout?.status] || PAYOUT_CHIP.unset;
  const joined = me.createdAt
    ? new Date(me.createdAt).toLocaleDateString('en-PH', { month: 'long', year: 'numeric' })
    : null;

  return (
    <div className="ap-account">
      {/* ---------- Identity banner ---------- */}
      <section className="ap-acct-hero">
        <div className="ap-acct-hero-glow" aria-hidden="true" />
        <div className="ap-acct-avatar">
          {me.avatarUrl ? <img src={`${API_ORIGIN}${me.avatarUrl}`} alt="" /> : <span>{initials}</span>}
        </div>
        <div className="ap-acct-identity">
          <h2>{me.name || 'Unnamed seller'}</h2>
          <p>{me.email}</p>
          <div className="ap-acct-chips">
            <span className="ap-acct-chip ap-acct-chip--role">
              <BadgeCheck size={13} strokeWidth={2.4} /> Seller
            </span>
            <span className={`ap-acct-chip ap-acct-chip--${chip.tone}`}>{chip.label}</span>
            {joined && <span className="ap-acct-chip">Since {joined}</span>}
          </div>
        </div>
        {me.sellerProfile?.farmName && (
          <div className="ap-acct-farm">
            <span>Farm</span>
            <strong>{me.sellerProfile.farmName}</strong>
            {me.sellerProfile.farmLocation && <em>{me.sellerProfile.farmLocation}</em>}
          </div>
        )}
      </section>

      {/* ---------- Section rail + pane ---------- */}
      <div className="ap-acct-grid">
        <nav className="ap-acct-nav" aria-label="Account sections">
          {SUB_TABS.map((t) => (
            <button
              key={t.id}
              type="button"
              className={`ap-acct-nav-item ${sub === t.id ? 'is-active' : ''}`}
              aria-current={sub === t.id}
              onClick={() => setSub(t.id)}
            >
              <t.icon size={17} strokeWidth={2.2} />
              <span className="ap-acct-nav-text">
                <span className="ap-acct-nav-label">{t.id}</span>
                <span className="ap-acct-nav-hint">{t.hint}</span>
              </span>
            </button>
          ))}
        </nav>

        <div className="ap-acct-pane">
          {sub === 'Profile' && <ProfileSection me={me} onSaved={load} />}
          {sub === 'Business' && <FarmDetailsSection me={me} onSaved={load} />}
          {sub === 'Documents' && <DocumentsSection me={me} onSaved={load} />}
          {sub === 'Payment' && <PaymentSetupSection me={me} onSaved={load} />}
          {sub === 'Addresses' && <AddressesSection me={me} onSaved={load} />}
          {sub === 'Security' && <SecuritySection />}
          {sub === 'Notifications' && <NotificationsSection me={me} onSaved={load} />}
        </div>
      </div>
    </div>
  );
}

function SaveBar({ saving, error, onSubmit }) {
  return (
    <>
      {error && <p className="ap-empty-state">{error}</p>}
      <div className="ap-form-actions">
        <button type="submit" className="ap-btn-primary" disabled={saving} onClick={onSubmit}>
          {saving ? 'Saving…' : 'Save changes'}
        </button>
      </div>
    </>
  );
}

function ProfileSection({ me, onSaved }) {
  const [form, setForm] = useState({ name: me.name || '', email: me.email || '', contact: me.contact || '', bio: me.bio || '' });
  const [avatarFile, setAvatarFile] = useState(null);
  const [avatarPreview, setAvatarPreview] = useState(me.avatarUrl ? `${API_ORIGIN}${me.avatarUrl}` : '');
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');

  function handleAvatarChange(e) {
    const file = e.target.files?.[0];
    if (!file) return;
    setAvatarFile(file);
    setAvatarPreview(URL.createObjectURL(file));
  }

  async function handleSubmit(e) {
    e.preventDefault();
    setError('');
    setSaving(true);
    try {
      await updateAccount({ ...form, avatarFile });
      await onSaved();
    } catch (err) {
      setError(err.response?.data?.error || 'Could not save profile.');
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="ap-panel">
      <div className="ap-panel-header"><div><span className="ap-panel-tag">Your details</span><h2>Profile</h2><p className="ap-panel-sub">How buyers and the AgriFair team recognise you.</p></div></div>
      <form onSubmit={handleSubmit}>
        <div className="ap-avatar-row">
          <div className="ap-avatar-preview">
            {avatarPreview ? <img src={avatarPreview} alt="Avatar" /> : <span>{(form.name || '?').slice(0, 2).toUpperCase()}</span>}
          </div>
          <label className="ap-btn-ghost" style={{ cursor: 'pointer' }}>
            Change photo
            <input type="file" accept="image/*" onChange={handleAvatarChange} hidden />
          </label>
        </div>
        <div className="ap-form-row">
          <div className="ap-form-field">
            <label>Name</label>
            <input type="text" value={form.name} onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))} />
          </div>
          <div className="ap-form-field">
            <label>Email</label>
            <input type="email" value={form.email} onChange={(e) => setForm((f) => ({ ...f, email: e.target.value }))} />
          </div>
          <div className="ap-form-field">
            <label>Contact number</label>
            <input type="text" value={form.contact} onChange={(e) => setForm((f) => ({ ...f, contact: e.target.value }))} placeholder="09xx-xxx-xxxx" />
          </div>
        </div>
        <div className="ap-form-row">
          <div className="ap-form-field" style={{ gridColumn: '1 / -1' }}>
            <label>Bio</label>
            <input type="text" value={form.bio} onChange={(e) => setForm((f) => ({ ...f, bio: e.target.value }))} placeholder="A short description of your business" />
          </div>
        </div>
        <SaveBar saving={saving} error={error} onSubmit={handleSubmit} />
      </form>
    </div>
  );
}

const PAYOUT_STATE = {
  unset:    { tone: 'idle',   icon: QrCode,      text: 'Not set up yet. Buyers can only pay you cash on delivery.' },
  pending:  { tone: 'warn',   icon: Clock,       text: 'Waiting for Super Admin review. Cash on delivery still works meanwhile.' },
  verified: { tone: 'good',   icon: ShieldCheck, text: 'Verified. Buyers can now scan your QR to pay you directly.' },
  rejected: { tone: 'bad',    icon: AlertCircle, text: 'Not approved. Fix the details below and save again.' },
};

const DOC_TYPES = [
  { id: 'BIR',           label: 'BIR Certificate of Registration', hint: 'Form 2303' },
  { id: 'DTI',           label: 'DTI Business Name',               hint: 'Sole proprietors' },
  { id: 'SEC',           label: 'SEC Registration',                hint: 'Corporations and partnerships' },
  { id: 'MAYORS_PERMIT', label: "Mayor's / Business Permit",       hint: 'From your city or municipality' },
  { id: 'BARANGAY',      label: 'Barangay Clearance',              hint: 'From your barangay hall' },
  { id: 'ORGANIC_CERT',  label: 'Organic Certification',           hint: 'Only if you advertise organic rice' },
];

const DOC_STATE = {
  pending:  { tone: 'warn', label: 'Under review' },
  verified: { tone: 'good', label: 'Verified' },
  rejected: { tone: 'bad',  label: 'Rejected' },
};

function DocumentsSection({ me, onSaved }) {
  const [type, setType] = useState(DOC_TYPES[0].id);
  const [referenceNo, setReferenceNo] = useState('');
  const [file, setFile] = useState(null);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');

  const docs = me.documents || [];
  const byType = Object.fromEntries(docs.map((d) => [d.type, d]));

  async function handleSubmit(e) {
    e.preventDefault();
    setError('');
    if (!file) { setError('Choose the file to upload.'); return; }

    setSaving(true);
    try {
      await updateAccount({ documentFile: file, documentMeta: { type, referenceNo } });
      setFile(null);
      setReferenceNo('');
      await onSaved();
    } catch (err) {
      setError(err.response?.data?.error || 'Could not upload that document.');
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="ap-panel">
      <div className="ap-panel-header">
        <div>
          <span className="ap-panel-tag">Compliance</span>
          <h2>Business documents</h2>
          <p className="ap-panel-sub">
            Proof that you are registered to sell rice. A Super Admin reviews each one.
          </p>
        </div>
      </div>

      <div className="ap-doc-privacy">
        <ShieldAlert size={16} strokeWidth={2.2} />
        <span>
          Your documents are stored privately and are <strong>never shown to buyers</strong>.
          Once approved, only a verified badge appears — the image itself is not displayed
          again, not even to you.
        </span>
      </div>

      <ul className="ap-doc-list">
        {DOC_TYPES.map((d) => {
          const doc = byType[d.id];
          const state = doc ? DOC_STATE[doc.status] : null;
          return (
            <li className="ap-doc-row" key={d.id}>
              <span className={`ap-doc-icon ${doc ? `ap-doc-icon--${state.tone}` : ''}`}>
                {doc ? <FileCheck size={16} strokeWidth={2.3} /> : <Eye size={16} strokeWidth={2.2} />}
              </span>
              <div className="ap-doc-text">
                <strong>{d.label}</strong>
                <span>{doc?.rejectionReason || d.hint}</span>
              </div>
              {doc
                ? <span className={`ap-doc-chip ap-doc-chip--${state.tone}`}>{state.label}</span>
                : <span className="ap-doc-chip">Not uploaded</span>}
            </li>
          );
        })}
      </ul>

      {error && <p className="ap-form-error" style={{ marginTop: '1rem' }}>{error}</p>}

      <form onSubmit={handleSubmit} className="ap-doc-form">
        <div className="ap-form-row">
          <div className="ap-form-field">
            <label>Document</label>
            <select value={type} onChange={(e) => setType(e.target.value)}>
              {DOC_TYPES.map((d) => <option key={d.id} value={d.id}>{d.label}</option>)}
            </select>
          </div>
          <div className="ap-form-field">
            <label>Reference number (optional)</label>
            <input
              type="text"
              value={referenceNo}
              onChange={(e) => setReferenceNo(e.target.value)}
              placeholder="e.g. TIN or permit number"
            />
          </div>
          <div className="ap-form-field">
            <label>File</label>
            <label className="ap-btn-ghost ap-doc-pick">
              <Upload size={14} strokeWidth={2.3} />
              {file ? file.name.slice(0, 24) : 'Choose image or PDF'}
              <input
                type="file"
                accept="image/*,application/pdf"
                hidden
                onChange={(e) => { setFile(e.target.files?.[0] || null); e.target.value = ''; }}
              />
            </label>
          </div>
        </div>

        <div className="ap-form-actions">
          <button type="submit" className="ap-btn-primary" disabled={saving}>
            {saving ? 'Uploading…' : 'Upload for review'}
          </button>
        </div>
      </form>
    </div>
  );
}

function PaymentSetupSection({ me, onSaved }) {
  const payout = me.payout || {};
  const [form, setForm] = useState({
    method: payout.method || 'gcash',
    accountName: payout.accountName || '',
    accountNumber: payout.accountNumber || '',
  });
  const [qrFile, setQrFile] = useState(null);
  const [qrPreview, setQrPreview] = useState(payout.qrImage ? `${API_ORIGIN}${payout.qrImage}` : '');
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');

  const state = PAYOUT_STATE[payout.status] || PAYOUT_STATE.unset;
  const StateIcon = state.icon;

  function handleQrChange(e) {
    const file = e.target.files?.[0];
    if (!file) return;
    setQrFile(file);
    setQrPreview(URL.createObjectURL(file));
    e.target.value = '';
  }

  async function handleSubmit(e) {
    e.preventDefault();
    setError('');

    if (!form.accountName.trim()) {
      setError('Enter the exact name on your GCash account.');
      return;
    }
    if (!form.accountNumber.trim() && !qrFile && !payout.qrImage) {
      setError('Add your GCash number or upload your QR code.');
      return;
    }

    setSaving(true);
    try {
      await updateAccount({ payout: form, paymentQrFile: qrFile });
      setQrFile(null);
      await onSaved();
    } catch (err) {
      setError(err.response?.data?.error || 'Could not save your payment details.');
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="ap-panel">
      <div className="ap-panel-header">
        <div>
          <span className="ap-panel-tag">Getting paid</span>
          <h2>Payment setup</h2>
        </div>
      </div>

      <div className={`ap-payout-state ap-payout-state--${state.tone}`}>
        <StateIcon size={17} strokeWidth={2.2} />
        <span>{state.text}</span>
      </div>

      {payout.status === 'rejected' && payout.rejectionReason && (
        <p className="ap-form-error">{payout.rejectionReason}</p>
      )}

      <p className="ap-payout-help">
        AgriFair does not hold your money. The buyer scans this QR in their own GCash
        app and pays you directly — then you confirm in Orders that it arrived.
      </p>

      {error && <p className="ap-form-error">{error}</p>}

      <form onSubmit={handleSubmit}>
        <div className="ap-payout-grid">
          <div className="ap-payout-fields">
            <div className="ap-form-row">
              <div className="ap-form-field">
                <label>Payment method</label>
                <select
                  value={form.method}
                  onChange={(e) => setForm((f) => ({ ...f, method: e.target.value }))}
                >
                  <option value="gcash">GCash</option>
                  <option value="bank">Bank transfer</option>
                </select>
              </div>
              <div className="ap-form-field">
                <label>{form.method === 'gcash' ? 'GCash number' : 'Account number'}</label>
                <input
                  type="text"
                  value={form.accountNumber}
                  onChange={(e) => setForm((f) => ({ ...f, accountNumber: e.target.value }))}
                  placeholder="09XX XXX XXXX"
                />
              </div>
            </div>

            <div className="ap-form-field">
              <label>Account name</label>
              <input
                type="text"
                value={form.accountName}
                onChange={(e) => setForm((f) => ({ ...f, accountName: e.target.value }))}
                placeholder="Exactly as it appears in your GCash"
              />
              <span className="ap-field-hint">
                Buyers check this name before sending. A mismatch is the usual reason
                money ends up with the wrong person.
              </span>
            </div>
          </div>

          <div className="ap-payout-qr">
            <label>QR code</label>
            <div className="ap-qr-box">
              {qrPreview ? (
                <img src={qrPreview} alt="Your payment QR code" />
              ) : (
                <div className="ap-qr-empty">
                  <QrCode size={30} strokeWidth={1.5} />
                  <span>No QR uploaded</span>
                </div>
              )}
            </div>
            <label className="ap-btn-ghost ap-qr-upload">
              <Upload size={14} strokeWidth={2.3} />
              {qrPreview ? 'Replace QR' : 'Upload QR'}
              <input type="file" accept="image/*" hidden onChange={handleQrChange} />
            </label>
          </div>
        </div>

        <div className="ap-form-actions">
          <button type="submit" className="ap-btn-primary" disabled={saving}>
            {saving ? 'Saving…' : 'Save payment details'}
          </button>
        </div>
      </form>

      <p className="ap-payout-note">
        Saving sends your details for Super Admin review again, so buyers are never
        shown a QR nobody has checked.
      </p>
    </div>
  );
}

function FarmDetailsSection({ me, onSaved }) {
  const sp = me.sellerProfile || {};
  const [form, setForm] = useState({
    sellerType: me.sellerType || 'farmer',
    businessName: sp.businessName || '',
    businessAddress: sp.businessAddress || '',
    farmName: sp.farmName || '',
    farmLocation: sp.farmLocation || '',
    farmSize: sp.farmSize || '',
  });
  const isFarmer = form.sellerType === 'farmer' || form.sellerType === 'cooperative';
  const [existingPhotos, setExistingPhotos] = useState(sp.farmPhotos || []);
  const [newPhotos, setNewPhotos] = useState([]);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');

  function handlePhotosChange(e) {
    const files = Array.from(e.target.files || []);
    setNewPhotos((prev) => [...prev, ...files.map((f) => Object.assign(f, { preview: URL.createObjectURL(f) }))]);
    e.target.value = '';
  }

  async function handleSubmit(e) {
    e.preventDefault();
    setError('');
    setSaving(true);
    try {
      await updateAccount({
        sellerType: form.sellerType,
        sellerProfile: {
          businessName: form.businessName,
          businessAddress: form.businessAddress,
          farmName: isFarmer ? form.farmName : '',
          farmLocation: isFarmer ? form.farmLocation : '',
          farmSize: isFarmer ? form.farmSize : '',
          farmPhotos: existingPhotos,
        },
        farmPhotoFiles: newPhotos,
      });
      setNewPhotos([]);
      await onSaved();
    } catch (err) {
      setError(err.response?.data?.error || 'Could not save your business details.');
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="ap-panel">
      <div className="ap-panel-header">
        <div>
          <span className="ap-panel-tag">Your business</span>
          <h2>Business details</h2>
          <p className="ap-panel-sub">Shown to buyers browsing your listings.</p>
        </div>
      </div>
      <form onSubmit={handleSubmit}>
        <div className="ap-form-row">
          <div className="ap-form-field">
            <label>What kind of seller are you?</label>
            <select
              value={form.sellerType}
              onChange={(e) => setForm((f) => ({ ...f, sellerType: e.target.value }))}
            >
              {SELLER_TYPES.map((t) => <option key={t.id} value={t.id}>{t.label}</option>)}
            </select>
            <span className="ap-field-hint">
              {SELLER_TYPES.find((t) => t.id === form.sellerType)?.hint}
            </span>
          </div>
          <div className="ap-form-field">
            <label>Business name</label>
            <input
              type="text"
              value={form.businessName}
              onChange={(e) => setForm((f) => ({ ...f, businessName: e.target.value }))}
              placeholder="As registered with DTI or SEC"
            />
          </div>
        </div>

        <div className="ap-form-field" style={{ marginBottom: '0.9rem' }}>
          <label>Business address</label>
          <input
            type="text"
            value={form.businessAddress}
            onChange={(e) => setForm((f) => ({ ...f, businessAddress: e.target.value }))}
            placeholder="Where your business operates"
          />
        </div>

        {!isFarmer && (
          <p className="ap-field-hint" style={{ marginBottom: '0.9rem' }}>
            Farm fields are hidden because you sell rice without farming it yourself.
          </p>
        )}

        {isFarmer && (
        <div className="ap-form-row">
          <div className="ap-form-field">
            <label>Farm name</label>
            <input type="text" value={form.farmName} onChange={(e) => setForm((f) => ({ ...f, farmName: e.target.value }))} />
          </div>
          <div className="ap-form-field">
            <label>Location</label>
            <input type="text" value={form.farmLocation} onChange={(e) => setForm((f) => ({ ...f, farmLocation: e.target.value }))} />
          </div>
          <div className="ap-form-field">
            <label>Size</label>
            <input type="text" value={form.farmSize} onChange={(e) => setForm((f) => ({ ...f, farmSize: e.target.value }))} placeholder="e.g. 5 hectares" />
          </div>
        </div>
        )}

        {isFarmer && (
        <div className="ap-form-field" style={{ marginBottom: '0.9rem' }}>
          <label>Farm photos (max 5)</label>
          <div className="ap-image-grid">
            {existingPhotos.map((src, idx) => (
              <div className="ap-image-thumb" key={`e-${idx}`}>
                <img src={`${API_ORIGIN}${src}`} alt="Farm" />
                <button type="button" aria-label="Remove photo" onClick={() => setExistingPhotos((p) => p.filter((_, i) => i !== idx))}><X size={13} strokeWidth={2.6} /></button>
              </div>
            ))}
            {newPhotos.map((f, idx) => (
              <div className="ap-image-thumb" key={`n-${idx}`}>
                <img src={f.preview} alt="New" />
                <button type="button" aria-label="Remove photo" onClick={() => setNewPhotos((p) => p.filter((_, i) => i !== idx))}><X size={13} strokeWidth={2.6} /></button>
              </div>
            ))}
            {existingPhotos.length + newPhotos.length < 5 && (
              <label className="ap-image-upload-btn">+<input type="file" accept="image/*" multiple onChange={handlePhotosChange} hidden /></label>
            )}
          </div>
        </div>
        )}
        <SaveBar saving={saving} error={error} onSubmit={handleSubmit} />
      </form>
    </div>
  );
}

function AddressesSection({ me, onSaved }) {
  const [form, setForm] = useState({ pickupAddress: me.pickupAddress || '', deliveryOrigin: me.deliveryOrigin || '' });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');

  async function handleSubmit(e) {
    e.preventDefault();
    setError('');
    setSaving(true);
    try {
      await updateAccount(form);
      await onSaved();
    } catch (err) {
      setError(err.response?.data?.error || 'Could not save addresses.');
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="ap-panel">
      <div className="ap-panel-header"><div><span className="ap-panel-tag">Logistics</span><h2>Addresses</h2><p className="ap-panel-sub">Where orders are collected from and dispatched.</p></div></div>
      <form onSubmit={handleSubmit}>
        <div className="ap-form-row">
          <div className="ap-form-field" style={{ gridColumn: '1 / -1' }}>
            <label>Pickup address</label>
            <input type="text" value={form.pickupAddress} onChange={(e) => setForm((f) => ({ ...f, pickupAddress: e.target.value }))} placeholder="Where buyers or couriers pick up orders" />
          </div>
        </div>
        <div className="ap-form-row">
          <div className="ap-form-field" style={{ gridColumn: '1 / -1' }}>
            <label>Delivery origin</label>
            <input type="text" value={form.deliveryOrigin} onChange={(e) => setForm((f) => ({ ...f, deliveryOrigin: e.target.value }))} placeholder="Where shipments are dispatched from" />
          </div>
        </div>
        <SaveBar saving={saving} error={error} onSubmit={handleSubmit} />
      </form>
    </div>
  );
}

function SecuritySection() {
  const [pwForm, setPwForm] = useState({ currentPassword: '', newPassword: '', confirmPassword: '' });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [sessions, setSessions] = useState([]);
  const [sessionsLoading, setSessionsLoading] = useState(true);

  useEffect(() => {
    let mounted = true;
    (async () => {
      try {
        const res = await fetchLoginHistory();
        if (mounted) setSessions(res.data || []);
      } catch {
        if (mounted) setSessions([]);
      } finally {
        if (mounted) setSessionsLoading(false);
      }
    })();
    return () => { mounted = false; };
  }, []);

  async function handleSubmit(e) {
    e.preventDefault();
    setError('');
    setSuccess('');
    if (pwForm.newPassword !== pwForm.confirmPassword) {
      setError('New passwords do not match.');
      return;
    }
    setSaving(true);
    try {
      await changePassword(pwForm.currentPassword, pwForm.newPassword);
      setSuccess('Password updated successfully.');
      setPwForm({ currentPassword: '', newPassword: '', confirmPassword: '' });
    } catch (err) {
      setError(err.response?.data?.error || 'Could not update password.');
    } finally {
      setSaving(false);
    }
  }

  return (
    <>
      <div className="ap-panel">
        <div className="ap-panel-header"><div><span className="ap-panel-tag">Security</span><h2>Change password</h2><p className="ap-panel-sub">At least 6 characters. You stay signed in afterwards.</p></div></div>
        <form onSubmit={handleSubmit}>
          {success && <p style={{ color: 'var(--green-700)', fontSize: '0.85rem', marginBottom: '0.8rem' }}>{success}</p>}
          <div className="ap-form-row">
            <div className="ap-form-field">
              <label>Current password</label>
              <input type="password" value={pwForm.currentPassword} onChange={(e) => setPwForm((f) => ({ ...f, currentPassword: e.target.value }))} />
            </div>
            <div className="ap-form-field">
              <label>New password</label>
              <input type="password" value={pwForm.newPassword} onChange={(e) => setPwForm((f) => ({ ...f, newPassword: e.target.value }))} />
            </div>
            <div className="ap-form-field">
              <label>Confirm new password</label>
              <input type="password" value={pwForm.confirmPassword} onChange={(e) => setPwForm((f) => ({ ...f, confirmPassword: e.target.value }))} />
            </div>
          </div>
          <SaveBar saving={saving} error={error} onSubmit={handleSubmit} />
        </form>
      </div>

      <div className="ap-panel">
        <div className="ap-panel-header"><div><span className="ap-panel-tag">Access</span><h2>Recent sign-ins</h2><p className="ap-panel-sub">If you see something you did not do, change your password.</p></div></div>
        {sessionsLoading && <p className="ap-empty-state">Loading…</p>}
        {!sessionsLoading && sessions.length === 0 && <p className="ap-empty-state">No login history yet.</p>}
        {!sessionsLoading && sessions.length > 0 && (
          <div className="ap-table-wrap">
            <table className="ap-table">
              <thead><tr><th>Date</th><th>IP Address</th><th>Device</th></tr></thead>
              <tbody>
                {sessions.map((s) => (
                  <tr key={s._id}>
                    <td>{new Date(s.loggedInAt).toLocaleString()}</td>
                    <td>{s.ipAddress || '—'}</td>
                    <td style={{ maxWidth: 320, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{s.userAgent || '—'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </>
  );
}

function NotificationsSection({ me, onSaved }) {
  const [prefs, setPrefs] = useState(me.notificationPrefs || { order: true, payment: true, message: true, stock: true, system: true });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');

  const LABELS = { order: 'Order updates', payment: 'Payment confirmations', message: 'New messages', stock: 'Low-stock alerts', system: 'Platform announcements' };

  async function handleSubmit(e) {
    e.preventDefault();
    setError('');
    setSaving(true);
    try {
      await updateAccount({ notificationPrefs: prefs });
      await onSaved();
    } catch (err) {
      setError(err.response?.data?.error || 'Could not save notification preferences.');
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="ap-panel">
      <div className="ap-panel-header"><div><span className="ap-panel-tag">Alerts</span><h2>Notifications</h2><p className="ap-panel-sub">Choose what AgriFair tells you about.</p></div></div>
      <form onSubmit={handleSubmit}>
        <div className="ap-toggle-list">
          {Object.keys(LABELS).map((key) => (
            <label className="ap-toggle-row" key={key}>
              <span>{LABELS[key]}</span>
              <input
                type="checkbox"
                checked={!!prefs[key]}
                onChange={(e) => setPrefs((p) => ({ ...p, [key]: e.target.checked }))}
              />
            </label>
          ))}
        </div>
        <SaveBar saving={saving} error={error} onSubmit={handleSubmit} />
      </form>
    </div>
  );
}
