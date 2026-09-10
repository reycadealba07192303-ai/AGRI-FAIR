import React, { useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import './LandingPage.css';
import logoImg from '../assets/logo.png';
import riceGrain from '../assets/rice_grain_3d.png';
import riceStalk from '../assets/rice_stalk_hero.png';

const FEATURES = [
  {
    icon: '🌾',
    title: 'Real-time Analytics',
    desc: 'Monitor agricultural data streams and fair activity with live dashboards.',
  },
  {
    icon: '🔒',
    title: 'Secure Access',
    desc: 'Role-based control ensures only authorized admins manage the system.',
  },
  {
    icon: '📱',
    title: 'Mobile Integration',
    desc: 'Seamlessly syncs with the companion mobile app for field use.',
  },
  {
    icon: '📊',
    title: 'Performance Reports',
    desc: 'Generate detailed reports on fair performance and user engagement.',
  },
  {
    icon: '👥',
    title: 'User Management',
    desc: 'Manage participants, vendors, and staff accounts from one place.',
  },
  {
    icon: '⚙️',
    title: 'Easy Configuration',
    desc: 'Configure system settings, schedules, and modules with ease.',
  },
];

const STATS = [
  { value: '500+', label: 'Registered Users', icon: '👥' },
  { value: '120+', label: 'Events Managed', icon: '📅' },
  { value: '99.9%', label: 'Uptime', icon: '⚡' },
  { value: '24/7', label: 'Support', icon: '💬' },
];

const HOW_TO_STEPS = [
  {
    step: '01',
    title: 'Install AgriFair',
    desc: 'Scan the QR on this page and install the buyer app on your phone.',
  },
  {
    step: '02',
    title: 'Sign up or sign in',
    desc: 'Create an account with your email, or jump back in if you already have one.',
  },
  {
    step: '03',
    title: 'Browse shops & chat',
    desc: 'Explore rice listings, open a seller’s shop, and message them when you need details.',
  },
  {
    step: '04',
    title: 'Order and track',
    desc: 'Checkout with COD or GCash, then follow the order until delivery arrives.',
  },
];

/** APK / Play Store URL — override with VITE_APP_DOWNLOAD_URL in .env when needed. */
const APP_DOWNLOAD_URL =
  import.meta.env.VITE_APP_DOWNLOAD_URL?.trim() ||
  'https://drive.google.com/file/d/103PzpjBsiWU0bW8iLgqojdNuYaMCk6bQ/view?usp=sharing';

export default function LandingPage() {
  const navigate = useNavigate();
  const heroRef = useRef(null);
  const [downloadOpen, setDownloadOpen] = useState(false);
  const [linkCopied, setLinkCopied] = useState(false);
  const downloadUrl = APP_DOWNLOAD_URL;

  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add('visible');
          }
        });
      },
      { threshold: 0.1 }
    );

    document.querySelectorAll('.animate-on-scroll').forEach((el) => observer.observe(el));
    // Reveal anything already in view (or stuck near the fold) so CTAs are never invisible.
    requestAnimationFrame(() => {
      document.querySelectorAll('.animate-on-scroll').forEach((el) => {
        const rect = el.getBoundingClientRect();
        if (rect.top < window.innerHeight * 0.92) el.classList.add('visible');
      });
    });
    return () => observer.disconnect();
  }, []);

  useEffect(() => {
    const hash = window.location.hash?.replace(/^#/, '');
    if (!hash) return undefined;
    const t = window.setTimeout(() => {
      document.getElementById(hash)?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }, 80);
    return () => window.clearTimeout(t);
  }, []);

  useEffect(() => {
    if (!downloadOpen) return undefined;
    const onKey = (e) => {
      if (e.key === 'Escape') setDownloadOpen(false);
    };
    const prev = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    window.addEventListener('keydown', onKey);
    return () => {
      document.body.style.overflow = prev;
      window.removeEventListener('keydown', onKey);
    };
  }, [downloadOpen]);

  const copyDownloadLink = async () => {
    try {
      await navigator.clipboard.writeText(downloadUrl);
      setLinkCopied(true);
      window.setTimeout(() => setLinkCopied(false), 1800);
    } catch {
      setLinkCopied(false);
    }
  };

  const scrollToSection = (id) => (e) => {
    e.preventDefault();
    const el = document.getElementById(id);
    if (!el) return;
    el.scrollIntoView({ behavior: 'smooth', block: 'start' });
    window.history.replaceState(null, '', `#${id}`);
  };

  return (
    <div className="lp-root">
      {/* NAV */}
      <nav className="lp-nav">
        <div className="lp-nav-inner">
          <div className="lp-logo" onClick={() => navigate('/')}>
            <img src={logoImg} alt="AgriFair Logo" className="lp-logo-img" />
            <span className="lp-logo-text">AgriFair</span>
          </div>
          <div className="lp-nav-links">
            <a href="#features" onClick={scrollToSection('features')}>Features</a>
            <a href="#about" onClick={scrollToSection('about')}>About</a>
            <a href="#how-to-use" onClick={scrollToSection('how-to-use')}>How to use</a>
            <a href="#download" onClick={scrollToSection('download')}>Download</a>
            <button className="lp-nav-cta" onClick={() => navigate('/login')}>
              Sign In
            </button>
          </div>
        </div>
      </nav>

      {/* HERO — Full-width immersive */}
      <section className="lp-hero" ref={heroRef}>
        {/* Decorative background */}
        <div className="lp-hero-bg">
          <div className="lp-hero-gradient" />
          <div className="lp-blob lp-blob-1" />
          <div className="lp-blob lp-blob-2" />
          <div className="lp-blob lp-blob-3" />
        </div>

        <div className="lp-hero-wrapper">
          <div className="lp-hero-content">
            <div className="lp-hero-badge">
              <span className="lp-badge-dot" />
              Admin Management System
            </div>
            <h1 className="lp-hero-title">
              Manage Your
              <br />
              <span className="lp-hero-accent">Agricultural Fair</span>
              <br />
              With Confidence
            </h1>
            <p className="lp-hero-sub">
              A centralized platform for admins to oversee events, users, analytics,
              and mobile integrations — all in one place.
            </p>
          </div>

          <div className="lp-hero-visual">
            <div className="lp-hero-main-image-container">
              <img src={riceStalk} className="lp-hero-main-image" alt="AgriFair 3D Rice Stalk" />
            </div>
          </div>
        </div>

        {/* STATS — Glassmorphic line inside hero */}
        <div className="lp-stats-container">
          {STATS.map((s, i) => (
            <React.Fragment key={s.label}>
              <div className="lp-stat-item">
                <span className="lp-stat-item-icon">{s.icon}</span>
                <div className="lp-stat-item-text">
                  <span className="lp-stat-value">{s.value}</span>
                  <span className="lp-stat-label">{s.label}</span>
                </div>
              </div>
              {i < STATS.length - 1 && <div className="lp-stat-divider" />}
            </React.Fragment>
          ))}
        </div>
      </section>

      {/* FEATURES */}
      <section className="lp-features" id="features">
        <div className="lp-section-inner">
          <div className="lp-section-header animate-on-scroll">
            <span className="lp-section-badge">Features</span>
            <h2 className="lp-section-title">Everything You Need</h2>
            <p className="lp-section-sub">
              Built for agricultural fair administrators who need power, speed, and clarity.
            </p>
          </div>
          <div className="lp-features-grid">
            {FEATURES.map((f, i) => (
              <div
                className="lp-feature-card animate-on-scroll"
                key={f.title}
                style={{ transitionDelay: `${i * 0.08}s` }}
              >
                <div className="lp-feature-icon-wrap">
                  <span className="lp-feature-icon">{f.icon}</span>
                </div>
                <h3 className="lp-feature-title">{f.title}</h3>
                <p className="lp-feature-desc">{f.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ABOUT */}
      <section className="lp-about" id="about">
        <div className="lp-section-inner lp-about-inner">
          <div className="lp-about-text animate-on-scroll">
            <span className="lp-section-badge">About</span>
            <h2 className="lp-section-title">Built for AgriTech Admins</h2>
            <p>
              AgriFair Admin is a capstone project designed to streamline the management
              of agricultural fairs and events. The platform bridges the gap between
              field operations (via mobile) and administrative oversight (via web).
            </p>
            <p>
              With role-based access, only authorized administrators can log in, ensuring
              the integrity of your event data.
            </p>
            <button className="lp-btn-primary" onClick={() => navigate('/login')}>
              Sign In Now <span className="lp-btn-arrow">→</span>
            </button>
            <a
              className="lp-btn-howto"
              href="#how-to-use"
              onClick={scrollToSection('how-to-use')}
            >
              How to use the app <span className="lp-btn-arrow">→</span>
            </a>
          </div>
          <div className="lp-about-visual animate-on-scroll">
            <div className="lp-about-card">
              <div className="lp-about-card-glow" />
              <div className="lp-about-card-icon">🌱</div>
              <h3>Seller's Portal</h3>
              <p>A dedicated space for sellers to manage listings, track orders, and monitor sales performance.</p>
            </div>
            <div className="lp-about-card lp-about-card-offset">
              <div className="lp-about-card-glow lp-glow-gold" />
              <div className="lp-about-card-icon">📲</div>
              <h3>Mobile Companion</h3>
              <p>Field officers use the mobile app, synced in real time.</p>
            </div>
          </div>
        </div>
      </section>

      {/* HOW TO USE — always visible (no scroll-hide) */}
      <section className="lp-howto" id="how-to-use">
        <div className="lp-howto-shell">
          <div className="lp-howto-intro">
            <span className="lp-howto-badge">Getting started</span>
            <h2>
              How to use
              <br />
              <em>the AgriFair app</em>
            </h2>
            <p>
              One path from install to delivery. Follow the four steps, then
              grab the app below.
            </p>
            <a
              className="lp-btn-white"
              href="#download"
              onClick={scrollToSection('download')}
            >
              Get the app <span className="lp-btn-arrow">→</span>
            </a>
          </div>
          <ol className="lp-howto-rail">
            {HOW_TO_STEPS.map((item, i) => (
              <li key={item.step} className="lp-howto-rail-item">
                <div className="lp-howto-rail-marker">
                  <span>{item.step}</span>
                  {i < HOW_TO_STEPS.length - 1 && (
                    <span className="lp-howto-rail-line" aria-hidden="true" />
                  )}
                </div>
                <div className="lp-howto-rail-copy">
                  <h3>{item.title}</h3>
                  <p>{item.desc}</p>
                </div>
              </li>
            ))}
          </ol>
        </div>
      </section>

      {/* DOWNLOAD */}
      <section className="lp-download" id="download">
        <div className="lp-download-row">
          <div className="lp-download-visual">
            <img
              className="lp-download-phones"
              src="/app-preview/mobile-showcase.png"
              alt="AgriFair mobile app splash and onboarding screens"
              width={1052}
              height={922}
              loading="lazy"
              decoding="async"
            />
          </div>

          <div className="lp-download-copy">
            <p className="lp-download-kicker">For buyers &amp; delivery</p>
            <h2 className="lp-download-title">
              Get the app.
              <br />
              <span>Shop rice on the go.</span>
            </h2>
            <p className="lp-download-sub">
              Splash, onboarding, then shop. Sellers and admins stay on the web
              portal — this install is for the mobile experience.
            </p>
            <button
              type="button"
              className="lp-download-btn"
              onClick={() => setDownloadOpen(true)}
            >
              Download
            </button>
          </div>
        </div>
      </section>

      {downloadOpen && (
        <div
          className="lp-dl-modal"
          role="dialog"
          aria-modal="true"
          aria-labelledby="lp-dl-modal-title"
          onClick={() => setDownloadOpen(false)}
        >
          <div
            className="lp-dl-modal-card"
            onClick={(e) => e.stopPropagation()}
          >
            <button
              type="button"
              className="lp-dl-modal-close"
              aria-label="Close"
              onClick={() => setDownloadOpen(false)}
            >
              ×
            </button>
            <h3 id="lp-dl-modal-title">Install AgriFair</h3>
            <p className="lp-dl-modal-hint">
              Scan the QR with your phone, or tap Download here.
            </p>
            <img
              className="lp-dl-modal-qr"
              src="/app-preview/apk-qr.png"
              alt="QR code to download AgriFair"
              width={200}
              height={200}
            />
            <a
              className="lp-dl-modal-download-link"
              href={downloadUrl}
              target="_blank"
              rel="noopener noreferrer"
            >
              DOWNLOAD HERE
            </a>
            <div className="lp-dl-modal-actions">
              <button
                type="button"
                className="lp-dl-modal-copy"
                onClick={copyDownloadLink}
              >
                {linkCopied ? 'Copied' : 'Copy link'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* VIDEO ADS SECTION */}
      <section className="lp-video-ads" id="video">
        <div className="lp-section-inner animate-on-scroll">
          <div className="lp-section-header">
            <span className="lp-section-badge">Highlights</span>
            <h2 className="lp-section-title">See AgriFair in Action</h2>
            <p className="lp-section-sub">
              Watch our latest highlights and promotional videos to see how we transform agricultural events.
            </p>
          </div>
          <div className="lp-video-container">
            <video className="lp-video-element" controls poster="https://placehold.co/900x500/1a2e1a/c9a84c?text=AgriFair+Video&font=playfair-display">
              <source src="https://www.w3schools.com/html/mov_bbb.mp4" type="video/mp4" />
              Your browser does not support the video tag.
            </video>
          </div>
        </div>
      </section>

      {/* END CTA */}
      <section className="lp-cta" id="get-started">
        <div className="lp-cta-bg" aria-hidden="true">
          <div className="lp-blob lp-blob-4" />
          <div className="lp-blob lp-blob-5" />
        </div>
        <div className="lp-cta-inner">
          <h2>Ready to run your fair?</h2>
          <p>
            Sign in to the web portal for sellers and admins, or download the
            mobile app for buyers and delivery riders.
          </p>
          <div className="lp-cta-actions">
            <button
              type="button"
              className="lp-btn-white"
              onClick={() => navigate('/login')}
            >
              Sign in to portal <span className="lp-btn-arrow">→</span>
            </button>
            <a
              className="lp-btn-outline-white"
              href="#download"
              onClick={scrollToSection('download')}
            >
              Download the app
            </a>
          </div>
        </div>
      </section>

      {/* FOOTER */}
      <footer className="lp-footer">
        <div className="lp-footer-inner">
          <div className="lp-footer-top">
            <div className="lp-logo" onClick={() => navigate('/')}>
              <img src={logoImg} alt="AgriFair Logo" className="lp-logo-img" />
              <span className="lp-logo-text">AgriFair</span>
            </div>
            <p className="lp-footer-tagline">Connecting farmers, traders, and administrators — one fair at a time.</p>
          </div>
          <div className="lp-footer-divider" />
          <div className="lp-footer-bottom">
            <p className="lp-footer-copy">© 2026 AgriFair. Capstone Project. All rights reserved.</p>
            <div className="lp-footer-links">
              <a href="#features" onClick={scrollToSection('features')}>Features</a>
              <a href="#about" onClick={scrollToSection('about')}>About</a>
              <a href="#how-to-use" onClick={scrollToSection('how-to-use')}>How to use</a>
              <a href="#download" onClick={scrollToSection('download')}>Download</a>
            </div>
          </div>
        </div>
      </footer>
    </div>
  );
}
