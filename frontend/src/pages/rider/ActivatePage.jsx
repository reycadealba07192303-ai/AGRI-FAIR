import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Truck, ArrowRight, ArrowLeft, Mail, KeyRound, ShieldCheck } from 'lucide-react';
import {
  startDeliverySetup,
  activateAccount,
  resendActivationCode,
} from '../../services/riderApi';
import './RiderPage.css';
import './ActivatePage.css';

/**
 * Setting up an account somebody else created.
 *
 * A delivery person's account is made by their seller with a random password
 * nobody is told — not even the seller, who should not be able to sign in as
 * their own staff. This is where the rider claims it.
 *
 * Three steps, in the order the person actually thinks in: who are you, choose
 * a password, prove the address is yours. The email is checked first so a
 * mistyped address is caught before anybody invents a password for it.
 *
 * The password is held here until the code checks out, and only then sent -
 * one call sets it, so a half-finished attempt leaves nothing behind.
 */
const STEPS = ['email', 'password', 'verify'];

export default function ActivatePage() {
  const navigate = useNavigate();

  const [step, setStep] = useState('email');
  const [name, setName] = useState('');
  const [form, setForm] = useState({ email: '', password: '', confirm: '', code: '' });
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');

  const set = (key) => (e) => setForm((f) => ({ ...f, [key]: e.target.value }));

  function fail(err, fallback) {
    setError(err.response?.data?.message || err.response?.data?.error || fallback);
  }

  /** Step one: is there an account for this address, and send the code. */
  async function findAccount(e) {
    e.preventDefault();
    setBusy(true);
    setError('');
    setNotice('');

    try {
      const res = await startDeliverySetup(form.email.trim());
      setName(res.data?.name || '');
      setStep('password');
      setNotice(`We sent a 6-digit code to ${form.email.trim()}.`);
    } catch (err) {
      // Already set up: nothing to do here, so point at the door they want.
      if (err.response?.data?.code === 'ALREADY_ACTIVE') {
        setError('This account is ready. Sign in with your password instead.');
      } else {
        fail(err, 'Could not find that delivery account.');
      }
    } finally {
      setBusy(false);
    }
  }

  /** Step two: the password, kept here until the code proves the address. */
  function choosePassword(e) {
    e.preventDefault();
    setError('');

    if (form.password.length < 6) {
      setError('Choose a password of at least 6 characters.');
      return;
    }
    if (form.password !== form.confirm) {
      setError('The two passwords do not match.');
      return;
    }

    setStep('verify');
  }

  /** Step three: the code, and the account is real. */
  async function verify(e) {
    e.preventDefault();
    setBusy(true);
    setError('');

    try {
      await activateAccount({
        email: form.email.trim(),
        code: form.code.trim(),
        password: form.password,
      });
      navigate('/login', { replace: true });
    } catch (err) {
      fail(err, 'That code did not work. Check it and try again.');
    } finally {
      setBusy(false);
    }
  }

  async function resend() {
    setError('');
    try {
      await resendActivationCode(form.email.trim());
      setNotice('A new code is on its way. It is good for a few minutes.');
    } catch (err) {
      fail(err, 'Could not send a new code.');
    }
  }

  function back() {
    setError('');
    setStep(STEPS[Math.max(0, STEPS.indexOf(step) - 1)]);
  }

  const stepNumber = STEPS.indexOf(step) + 1;

  return (
    <div className="rp-root ac-root">
      <div className="ac-card">
        <div className="ac-brand">
          <Truck size={22} strokeWidth={2.2} />
          <div>
            <span>AGRIFAIR DELIVERY</span>
            <strong>{name ? `Hello, ${name}` : 'Set up your account'}</strong>
          </div>
        </div>

        <ol className="ac-steps" aria-label={`Step ${stepNumber} of 3`}>
          {[
            { key: 'email', icon: Mail, label: 'Your email' },
            { key: 'password', icon: KeyRound, label: 'Password' },
            { key: 'verify', icon: ShieldCheck, label: 'Verify' },
          ].map(({ key, icon: Icon, label }, i) => (
            <li
              key={key}
              className={
                STEPS.indexOf(key) < STEPS.indexOf(step)
                  ? 'ac-step ac-step--done'
                  : key === step
                    ? 'ac-step ac-step--now'
                    : 'ac-step'
              }
            >
              <Icon size={14} strokeWidth={2.4} />
              <span>{i + 1}. {label}</span>
            </li>
          ))}
        </ol>

        {step === 'email' && (
          <form onSubmit={findAccount} className="ac-form">
            <p className="ac-lede">
              Your shop added you with an email. Type it and we will send a code
              to that mailbox.
            </p>
            <label>
              <span>Email</span>
              <input
                type="email"
                required
                autoFocus
                autoComplete="username"
                value={form.email}
                onChange={set('email')}
                placeholder="the address your shop used"
              />
            </label>

            {error && <p className="rp-error">{error}</p>}

            <button className="rp-btn rp-btn--primary" type="submit" disabled={busy}>
              {busy ? 'Checking…' : 'Continue'}
              {!busy && <ArrowRight size={15} strokeWidth={2.4} />}
            </button>
          </form>
        )}

        {step === 'password' && (
          <form onSubmit={choosePassword} className="ac-form">
            <p className="ac-lede">
              Choose a password. Nobody else will know it — not even your shop.
            </p>
            <label>
              <span>New password</span>
              <input
                type="password"
                required
                autoFocus
                autoComplete="new-password"
                value={form.password}
                onChange={set('password')}
                placeholder="at least 6 characters"
              />
            </label>
            <label>
              <span>Type it again</span>
              <input
                type="password"
                required
                autoComplete="new-password"
                value={form.confirm}
                onChange={set('confirm')}
              />
            </label>

            {error && <p className="rp-error">{error}</p>}
            {notice && <p className="rp-notice">{notice}</p>}

            <button className="rp-btn rp-btn--primary" type="submit">
              Continue <ArrowRight size={15} strokeWidth={2.4} />
            </button>
            <button className="ac-back" type="button" onClick={back}>
              <ArrowLeft size={13} strokeWidth={2.4} /> Change the email
            </button>
          </form>
        )}

        {step === 'verify' && (
          <form onSubmit={verify} className="ac-form">
            <p className="ac-lede">
              Last step. Enter the 6-digit code sent to{' '}
              <strong>{form.email.trim()}</strong>.
            </p>
            <label>
              <span>Code from your email</span>
              <input
                type="text"
                required
                autoFocus
                inputMode="numeric"
                maxLength={6}
                className="ac-code"
                value={form.code}
                onChange={set('code')}
                placeholder="000000"
              />
            </label>

            {error && <p className="rp-error">{error}</p>}
            {notice && <p className="rp-notice">{notice}</p>}

            <button className="rp-btn rp-btn--primary" type="submit" disabled={busy}>
              <ShieldCheck size={15} strokeWidth={2.3} />
              {busy ? 'Verifying…' : 'Verify and finish'}
            </button>
            <button className="ac-back" type="button" onClick={back}>
              <ArrowLeft size={13} strokeWidth={2.4} /> Back
            </button>
          </form>
        )}

        <div className="ac-foot">
          {step !== 'email' && (
            <button type="button" onClick={resend}>Send the code again</button>
          )}
          <Link to="/login">
            Already set up? Sign in <ArrowRight size={13} strokeWidth={2.4} />
          </Link>
        </div>
      </div>
    </div>
  );
}
