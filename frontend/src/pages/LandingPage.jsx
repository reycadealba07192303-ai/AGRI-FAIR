import React, { useEffect, useRef } from 'react';
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

export default function LandingPage() {
  const navigate = useNavigate();
  const heroRef = useRef(null);

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
    return () => observer.disconnect();
  }, []);

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
            <a href="#features">Features</a>
            <a href="#about">About</a>
            <a href="#video">Highlights</a>
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

      {/* CTA */}
      <section className="lp-cta">
        <div className="lp-cta-bg">
          <div className="lp-blob lp-blob-4" />
          <div className="lp-blob lp-blob-5" />
        </div>
        <div className="lp-cta-inner animate-on-scroll">
          <h2>Ready to manage your fair?</h2>
          <p>Sign in with your admin credentials to get started.</p>
          <div className="lp-hero-actions lp-hero-actions-centered">
            <button className="lp-btn-white" onClick={() => navigate('/login')}>
              Log In <span className="lp-btn-arrow">→</span>
            </button>
          </div>
        </div>
      </section>

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

      {/* FOOTER */}
      <footer className="lp-footer">
        <div className="lp-footer-inner">
          <div className="lp-footer-top">
            <div className="lp-logo">
              <img src={logoImg} alt="AgriFair Logo" className="lp-logo-img" />
              <span className="lp-logo-text">AgriFair</span>
            </div>
            <p className="lp-footer-tagline">Connecting farmers, traders, and administrators — one fair at a time.</p>
          </div>
          <div className="lp-footer-divider" />
          <div className="lp-footer-bottom">
            <p className="lp-footer-copy">© 2025 AgriFair. Capstone Project. All rights reserved.</p>
            <div className="lp-footer-links">
              <a href="#features">Features</a>
              <a href="#about">About</a>
              <a href="#video">Highlights</a>
            </div>
          </div>
        </div>
      </footer>
    </div>
  );
}
