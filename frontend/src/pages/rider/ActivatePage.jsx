import React, { useEffect, useRef, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import {
  Lock,
  Eye,
  EyeOff,
  Check,
  Mail,
  Clock,
  CheckCircle2,
  Ban,
  Link2Off,
  Smartphone,
} from 'lucide-react';
import {
  fetchActivationStatus,
  activateAccount,
  resendActivationLink,
} from '../../services/riderApi';
import { APP_DOWNLOAD_URL, openAppHref, tryOpenApp } from '../../utils/appLinks';
import logoImg from '../../assets/logo.png';
import './ActivatePage.css';

/**
 * Creating the password for an account somebody else created, from the
 * emailed link.
 *
 * A delivery person's account is made by their seller with a random password
 * nobody is told — not even the seller, who should not be able to sign in as
 * their own staff. The link proves the address is theirs, so the only thing
 * left to ask is the password.
 *
 * It is opened on a phone, from an email, by somebody who will then use the
 * AgriFair app — so it looks like the app's own sign-in screen, not the web
 * portal.
 *
 * Opening this page changes nothing. Mail scanners follow links, and a page
 * that activated on load would be used up before the rider saw it.
 *
 * Every link lands on one of these:
 *   valid     create a password
 *   expired   send a new link, to the address already on the account
 *   active    already set up — go sign in
 *   suspended nothing to do here; ask the shop
 *   invalid   replaced by a newer link, or never was one
 */

/** Server codes that mean the link's state changed under the page. */
const STATE_FOR_CODE = {
  ACTIVATION_EXPIRED: 'expired',
  ACTIVATION_INVALID: 'invalid',
  ALREADY_ACTIVE: 'active',
  ACCOUNT_SUSPENDED: 'suspended',
};

const MIN_LENGTH = 6;

/** Only phones have the app, so only phones get sent to it unasked. */
const isPhone = () =>
  typeof navigator !== 'undefined' && /android|iphone|ipad|ipod/i.test(navigator.userAgent);

function message(err, fallback) {
  return err.response?.data?.message || err.response?.data?.error || fallback;
}

export default function ActivatePage() {
  const [params] = useSearchParams();
  const token = params.get('token') || '';

  const [state, setState] = useState(token ? 'loading' : 'invalid');
  const [who, setWho] = useState({ name: '', email: '' });
  const [form, setForm] = useState({ password: '', confirm: '' });
  const [show, setShow] = useState({ password: false, confirm: false });
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [sentTo, setSentTo] = useState('');
  const [cooldown, setCooldown] = useState(0);
  // idle: offer "Open AgriFair App" · opening: trying right now
  const [launch, setLaunch] = useState('idle');
  const triedApp = useRef(false);

  // Once the account is ready, go straight to the app.
  //
  // This works right after "Create Password", while the tap still counts.
  // Chrome refuses to open an app from a page nobody has touched, so simply
  // re-opening an old link lands on the button instead. A page cannot tell
  // "refused" from "not installed", so it never claims the app is missing:
  // the button opens the app when it is there and the download when it is not.
  useEffect(() => {
    if (state !== 'done' && state !== 'active') return;
    if (triedApp.current || !isPhone()) return;
    triedApp.current = true;

    setLaunch('opening');
    tryOpenApp().then(() => setLaunch('idle'));
  }, [state]);

  useEffect(() => {
    if (!token) return undefined;
    let cancelled = false;

    fetchActivationStatus(token)
      .then((res) => {
        if (cancelled) return;
        setWho({ name: res.data?.name || '', email: res.data?.email || '' });
        setState(res.data?.state || 'invalid');
      })
      .catch((err) => {
        if (cancelled) return;
        setState('error');
        setError(message(err, 'Could not check this link. Check your connection and reload.'));
      });

    return () => {
      cancelled = true;
    };
  }, [token]);

  // Counts the resend button down after the server says "not yet".
  useEffect(() => {
    if (cooldown <= 0) return undefined;
    const timer = setTimeout(() => setCooldown((s) => s - 1), 1000);
    return () => clearTimeout(timer);
  }, [cooldown]);

  const longEnough = form.password.length >= MIN_LENGTH;
  const matches = form.confirm.length > 0 && form.password === form.confirm;

  const set = (key) => (e) => {
    setForm((f) => ({ ...f, [key]: e.target.value }));
    setError('');
  };

  const toggle = (key) => setShow((s) => ({ ...s, [key]: !s[key] }));

  /** A failure that is really the link changing state moves the page with it. */
  function handleFailure(err, fallback) {
    const next = STATE_FOR_CODE[err.response?.data?.code];
    if (next) {
      setState(next);
      setError('');
      return;
    }
    setError(message(err, fallback));
  }

  async function submit(e) {
    e.preventDefault();

    if (!longEnough) {
      setError(`Use at least ${MIN_LENGTH} characters.`);
      return;
    }
    if (!matches) {
      setError('The two passwords do not match.');
      return;
    }

    setBusy(true);
    setError('');
    try {
      await activateAccount({ token, password: form.password });
      setForm({ password: '', confirm: '' });
      setState('done');
    } catch (err) {
      handleFailure(err, 'Could not create your password. Try again.');
    } finally {
      setBusy(false);
    }
  }

  async function resend() {
    setBusy(true);
    setError('');
    try {
      const res = await resendActivationLink(token);
      // This link was just replaced, so the button has nothing left to do.
      setSentTo(res.data?.sentTo || who.email);
    } catch (err) {
      if (err.response?.data?.code === 'RESEND_COOLDOWN') {
        setCooldown(err.response.data.retryAfter || 60);
      } else {
        handleFailure(err, 'Could not send a new link. Try again.');
      }
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="act">
      <div className="act-leaf act-leaf--right" aria-hidden="true" />
      <div className="act-leaf act-leaf--left" aria-hidden="true" />

      <main className="act-shell">
        <header className="act-brand">
          <span className="act-wordmark">AGRIFAIR</span>
          <div className="act-logo">
            <img src={logoImg} alt="AgriFair" />
          </div>
        </header>

        {state === 'loading' && (
          <div className="act-body" aria-busy="true" aria-label="Checking your link">
            <div className="act-skeleton act-skeleton--title" />
            <div className="act-skeleton act-skeleton--line" />
            <div className="act-skeleton act-skeleton--field" />
            <div className="act-skeleton act-skeleton--field" />
            <div className="act-skeleton act-skeleton--button" />
          </div>
        )}

        {state === 'valid' && (
          <form className="act-body" onSubmit={submit} noValidate>
            <h1 className="act-title">Create your password</h1>
            <p className="act-subtitle">
              {who.name ? `Hi ${who.name.split(' ')[0]}, ` : ''}
              set a password for <strong>{who.email}</strong>. You will use it to
              sign in on the AgriFair app.
            </p>

            <label className="act-label" htmlFor="act-password">New password</label>
            <div className="act-field">
              <Lock size={18} strokeWidth={2} className="act-field-icon" />
              <input
                id="act-password"
                type={show.password ? 'text' : 'password'}
                autoComplete="new-password"
                autoFocus
                value={form.password}
                onChange={set('password')}
                placeholder="Enter a new password"
                disabled={busy}
              />
              <button
                type="button"
                className="act-eye"
                onClick={() => toggle('password')}
                aria-label={show.password ? 'Hide password' : 'Show password'}
              >
                {show.password ? <Eye size={18} /> : <EyeOff size={18} />}
              </button>
            </div>

            <label className="act-label" htmlFor="act-confirm">Confirm password</label>
            <div className="act-field">
              <Lock size={18} strokeWidth={2} className="act-field-icon" />
              <input
                id="act-confirm"
                type={show.confirm ? 'text' : 'password'}
                autoComplete="new-password"
                value={form.confirm}
                onChange={set('confirm')}
                placeholder="Type it again"
                disabled={busy}
              />
              <button
                type="button"
                className="act-eye"
                onClick={() => toggle('confirm')}
                aria-label={show.confirm ? 'Hide password' : 'Show password'}
              >
                {show.confirm ? <Eye size={18} /> : <EyeOff size={18} />}
              </button>
            </div>

            <ul className="act-checks">
              <li className={longEnough ? 'is-ok' : ''}>
                <Check size={14} strokeWidth={3} /> At least {MIN_LENGTH} characters
              </li>
              <li className={matches ? 'is-ok' : ''}>
                <Check size={14} strokeWidth={3} /> Both passwords match
              </li>
            </ul>

            {error && <p className="act-error" role="alert">{error}</p>}

            <button type="submit" className="act-button" disabled={busy}>
              {busy ? <span className="act-spinner" aria-label="Saving" /> : 'Create Password'}
            </button>

            <p className="act-note">
              Only you will know this password — not even your shop.
            </p>
          </form>
        )}

        {state === 'expired' && (
          <section className="act-body act-state">
            <span className="act-state-icon act-state-icon--wait">
              <Clock size={26} strokeWidth={2.2} />
            </span>
            {sentTo ? (
              <>
                <h1 className="act-title">Check your inbox</h1>
                <p className="act-subtitle">
                  We sent a new link to <strong>{sentTo}</strong>. Open the newest
                  email — this link no longer works.
                </p>
              </>
            ) : (
              <>
                <h1 className="act-title">This link has expired</h1>
                <p className="act-subtitle">
                  Links work for 48 hours. We can send a new one to{' '}
                  <strong>{who.email}</strong>.
                </p>

                {error && <p className="act-error" role="alert">{error}</p>}

                <button
                  type="button"
                  className="act-button"
                  onClick={resend}
                  disabled={busy || cooldown > 0}
                >
                  {busy ? (
                    <span className="act-spinner" aria-label="Sending" />
                  ) : (
                    <>
                      <Mail size={17} strokeWidth={2.2} />
                      {cooldown > 0 ? `Resend in ${cooldown}s` : 'Resend Activation Email'}
                    </>
                  )}
                </button>
              </>
            )}
          </section>
        )}

        {(state === 'active' || state === 'done') && (
          <section className="act-body act-state">
            <span className="act-state-icon act-state-icon--ok">
              <CheckCircle2 size={26} strokeWidth={2.2} />
            </span>
            <h1 className="act-title">
              {state === 'done' ? 'Password created' : 'Already set up'}
            </h1>
            <p className="act-subtitle">
              Your delivery account is ready. Sign in with{' '}
              {who.email ? <strong>{who.email}</strong> : 'your email'} and your
              new password.
            </p>

            {launch === 'opening' && (
              <div className="act-opening" role="status">
                <span className="act-spinner act-spinner--dark" />
                Opening the AgriFair app…
              </div>
            )}

            {launch === 'idle' && (
              <>
                <a className="act-button" href={openAppHref()}>
                  <Smartphone size={18} strokeWidth={2.2} />
                  Open AgriFair App
                </a>
                <p className="act-note">
                  No app yet?{' '}
                  <a className="act-link" href={APP_DOWNLOAD_URL}>
                    Download AgriFair
                  </a>
                </p>
              </>
            )}

          </section>
        )}

        {state === 'suspended' && (
          <section className="act-body act-state">
            <span className="act-state-icon act-state-icon--off">
              <Ban size={26} strokeWidth={2.2} />
            </span>
            <h1 className="act-title">Account suspended</h1>
            <p className="act-subtitle">Ask the shop you deliver for about it.</p>
          </section>
        )}

        {state === 'invalid' && (
          <section className="act-body act-state">
            <span className="act-state-icon act-state-icon--off">
              <Link2Off size={26} strokeWidth={2.2} />
            </span>
            <h1 className="act-title">Link no longer valid</h1>
            <p className="act-subtitle">
              A newer link may have been sent. Open the newest AgriFair email, or
              ask your shop to send you a new one.
            </p>
          </section>
        )}

        {state === 'error' && (
          <section className="act-body act-state">
            <p className="act-error" role="alert">{error}</p>
          </section>
        )}
      </main>
    </div>
  );
}
