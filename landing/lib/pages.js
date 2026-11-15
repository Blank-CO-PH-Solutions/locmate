// Server-rendered pages. No client-side framework: everything important is in
// the HTML so the site works without JavaScript.

const { config } = require("./config");
const { renderLegal } = require("./legal");
const { escapeHtml, formatPeso, icon, layout } = require("./ui");

const monthly = config.plans.monthly;
const annual = config.plans.annual;
const annualMonthly = Math.round(annual.amount / 12);
const annualSaving = Math.max(
  0,
  Math.round((1 - annual.amount / (monthly.amount * 12)) * 100),
);

function checkItem(text) {
  return `<li>${icon("check")}<span>${text}</span></li>`;
}

function phoneMock() {
  return `<div class="phone-wrap">
    <div class="phone-glow" aria-hidden="true"></div>
    <div class="phone" role="img" aria-label="Locmate live map showing three circle members">
      <div class="phone-notch"></div>
      <div class="phone-screen">
        <div class="map-bg"></div>
        <div class="map-road road-a"></div>
        <div class="map-road road-b"></div>
        <div class="map-park"></div>
        <div class="phone-top">
          <span class="phone-title">The Lee family</span>
          <span class="phone-live"><i></i>Live</span>
        </div>
        <div class="pin pin-a"><span class="pin-dot dot-purple"></span><span class="pin-name">Jordan</span></div>
        <div class="pin pin-b"><span class="pin-dot dot-teal"></span><span class="pin-name">Mia</span></div>
        <div class="pin pin-c"><span class="pin-dot dot-coral"></span><span class="pin-name">Dad</span></div>
        <div class="map-card">
          <span class="map-card-icon">${icon("bell")}</span>
          <div>
            <strong>Mia arrived at Home</strong>
            <span>Just now · Place alert</span>
          </div>
        </div>
        <div class="phone-dock">
          <span class="dock-item is-active">${icon("pin")}<em>Map</em></span>
          <span class="dock-item">${icon("message")}<em>Chat</em></span>
          <span class="dock-item">${icon("users")}<em>Circle</em></span>
        </div>
      </div>
    </div>
  </div>`;
}

function faq(items) {
  return `<div class="faq-list">
    ${items
      .map(
        ([question, answer]) => `<details class="faq-item">
          <summary>${question}<span class="faq-plus">+</span></summary>
          <div class="faq-answer">${answer}</div>
        </details>`,
      )
      .join("")}
  </div>`;
}

const sharedFaq = [
  [
    "Which platforms does Locmate support?",
    "Android is available now as a direct download. The same codebase also builds for iOS, macOS, Windows and Linux; those builds are being prepared. Your account and circle work across devices.",
  ],
  [
    "Who can see my location?",
    "Only the members of the circle you join. Every database row is protected by row-level security, and you can pause location sharing at any time in Settings.",
  ],
  [
    "How do refunds work?",
    `Email <a href="mailto:${config.supportEmail}">${config.supportEmail}</a> with your PayMongo reference number. Refunds are handled under our <a href="/terms">Terms of Service</a> and Philippine consumer law.`,
  ],
];

function homePage() {
  const content = `
  <section class="hero">
    <div class="hero-glow hero-glow-a" aria-hidden="true"></div>
    <div class="hero-glow hero-glow-b" aria-hidden="true"></div>
    <div class="wrap hero-grid">
      <div class="hero-copy">
        <p class="eyebrow"><span class="eyebrow-dot"></span>Private location sharing for your circle</p>
        <h1>Keep your circle close, wherever life takes you.</h1>
        <p class="hero-lede">Locmate shows your family and friends on a private live map, lets you know when they arrive somewhere safe, and helps you reach them fast when it matters.</p>
        <div class="hero-actions">
          <a class="btn btn-primary btn-large" href="/download">${icon("download")} Download for Android</a>
        </div>
        <ul class="hero-points">
          <li>${icon("check")} Free to download</li>
          <li>${icon("check")} No card required</li>
        </ul>
      </div>
      ${phoneMock()}
    </div>
    <div class="wrap hero-strip">
      <span>${icon("lock")} Your circle only — never public</span>
      <span>${icon("shield")} SOS included on every plan</span>
      <span>${icon("phone")} Android 7.0+</span>
      <span>${icon("globe")} Built in the Philippines</span>
    </div>
  </section>

  <section class="section" id="features">
    <div class="wrap">
      <div class="section-head">
        <p class="eyebrow eyebrow-dark">Why Locmate</p>
        <h2>Less checking in. More peace of mind.</h2>
        <p>Locmate is built around consent, privacy and the small moments that matter — not constant surveillance.</p>
      </div>
      <div class="feature-grid">
        <article class="feature-card">
          <span class="feature-icon">${icon("pin")}</span>
          <h3>A live map of your people</h3>
          <p>See where everyone is, their battery level and when they were last online. Tap a member for directions.</p>
        </article>
        <article class="feature-card">
          <span class="feature-icon">${icon("route")}</span>
          <h3>Places that tell you they made it</h3>
          <p>Save home, school or the office. Locmate sends a quiet alert when someone arrives or leaves.</p>
        </article>
        <article class="feature-card">
          <span class="feature-icon feature-icon-coral">${icon("shield")}</span>
          <h3>Help in one tap</h3>
          <p>Send an SOS to everyone in your circle with your live location. SOS is free on every plan.</p>
        </article>
        <article class="feature-card">
          <span class="feature-icon feature-icon-teal">${icon("message")}</span>
          <h3>Chat without leaving the map</h3>
          <p>Coordinate pickups, share a quick update or ask someone to check in — all inside your circle.</p>
        </article>
        <article class="feature-card">
          <span class="feature-icon feature-icon-amber">${icon("battery")}</span>
          <h3>Low-battery alerts</h3>
          <p>Know when someone's phone is about to die, so a lost connection does not become a worry.</p>
        </article>
        <article class="feature-card">
          <span class="feature-icon">${icon("lock")}</span>
          <h3>Private by design</h3>
          <p>Only your circle can see your location. Pause sharing whenever you want, and delete your account in the app.</p>
        </article>
      </div>
    </div>
  </section>

  <section class="section section-tint" id="how">
    <div class="wrap">
      <div class="section-head">
        <p class="eyebrow eyebrow-dark">Getting started</p>
        <h2>Three minutes to your own circle.</h2>
      </div>
      <ol class="steps">
        <li>
          <span class="step-number">1</span>
          <h3>Download Locmate</h3>
          <p>Install the Android app directly from this page. No store account required.</p>
        </li>
        <li>
          <span class="step-number">2</span>
          <h3>Create your circle</h3>
          <p>Sign up with email or Google, then invite the people you trust with a private invite code.</p>
        </li>
        <li>
          <span class="step-number">3</span>
          <h3>Start sharing</h3>
          <p>Turn on location sharing and add the places that matter. Start sharing in seconds.</p>
        </li>
      </ol>
    </div>
  </section>

  <section class="section section-tint" id="faq">
    <div class="wrap narrow">
      <div class="section-head">
        <p class="eyebrow eyebrow-dark">Questions</p>
        <h2>Good to know.</h2>
      </div>
      ${faq(sharedFaq)}
      <div class="contact-card">
        <div>
          <h3>Still need a hand?</h3>
          <p>We are a small team in the Philippines. Email us and a real person will reply.</p>
        </div>
        <a class="btn btn-primary" href="mailto:${config.supportEmail}">${icon("mail")} Email support</a>
      </div>
    </div>
  </section>

  <section class="cta-band">
    <div class="wrap cta-inner">
      <div>
        <h2>Bring your circle closer.</h2>
        <p>Download Locmate free and start your circle in minutes.</p>
      </div>
      <div class="cta-actions">
        <a class="btn btn-light btn-large" href="/download">${icon("download")} Download the app</a>
      </div>
    </div>
  </section>`;

  return layout({
    title: "Locmate",
    description:
      "Locmate is a private location-sharing app for families and friends. See your circle on a live map, get arrival alerts and send an SOS. Free download, no card required.",
    path: "/",
    content,
  });
}

function downloadPage() {
  const hasApk = Boolean(config.apkUrl);
  const sha = config.apkSha256
    ? `<p class="sha">SHA-256 <code>${escapeHtml(config.apkSha256)}</code></p>`
    : "";

  const downloadBlock = hasApk
    ? `<a class="btn btn-primary btn-large btn-block" href="/api/download" rel="noopener">
        ${icon("download")} Download Locmate ${escapeHtml(config.apkVersion)}
      </a>
      <p class="download-meta">Android 7.0 or newer · Direct APK · Free</p>
      ${sha}`
    : `<div class="notice notice-warning">
        <strong>The Android build is being finalized.</strong>
        <span>The download link will appear here as soon as the signed APK is uploaded. In the meantime, the app is free to download once the build lands.</span>
      </div>`;

  const content = `
  <section class="page-hero">
    <div class="wrap download-grid">
      <div>
        <p class="eyebrow eyebrow-dark">Download</p>
        <h1>Locmate for Android.</h1>
        <p class="page-lede">Install the app directly — no Play Store account needed. Free, no card required.</p>
        <div class="download-card">
          <div class="download-card-top">
            <img src="/img/locmate-mark.png" alt="" width="64" height="64">
            <div>
              <strong>Locmate</strong>
              <span>Version ${escapeHtml(config.apkVersion)} · Android</span>
            </div>
            <span class="free-pill">Free</span>
          </div>
          ${downloadBlock}
        </div>
        <p class="small-print">By downloading you agree to the <a href="/terms">Terms of Service</a> and <a href="/privacy">Privacy Policy</a>.</p>
      </div>
      <div class="install-card">
        <h2>How to install</h2>
        <ol class="install-steps">
          <li><span>1</span><div><strong>Tap the download button</strong><p>Your browser will download the Locmate APK file.</p></div></li>
          <li><span>2</span><div><strong>Open the file</strong><p>If asked, allow your browser to install apps from this source.</p></div></li>
          <li><span>3</span><div><strong>Install and open Locmate</strong><p>Android may show a standard "unknown app" warning because Locmate is distributed directly.</p></div></li>
          <li><span>4</span><div><strong>Create your circle</strong><p>Sign up with email or Google. Start sharing in seconds.</p></div></li>
        </ol>
        <div class="install-note">
          ${icon("shield")}
          <p>Only install the APK from this page or a link we share officially. You can verify the SHA-256 checksum above after downloading.</p>
        </div>
      </div>
    </div>
  </section>

  <section class="section section-tint">
    <div class="wrap narrow">
      <div class="section-head">
        <p class="eyebrow eyebrow-dark">Before you install</p>
        <h2>What Locmate needs.</h2>
      </div>
      <div class="requirement-grid">
        <div class="requirement">${icon("phone")}<h3>Android 7.0+</h3><p>Works on most Android phones released since 2016.</p></div>
        <div class="requirement">${icon("pin")}<h3>Location permission</h3><p>Needed to show you on your circle's map. You can pause sharing anytime.</p></div>
        <div class="requirement">${icon("bell")}<h3>Notification permission</h3><p>Used for arrival, departure, SOS and low-battery alerts.</p></div>
      </div>
      <p class="center-note">Using an iPhone or a computer? The same Locmate account works across platforms. Email <a href="mailto:${config.supportEmail}">${config.supportEmail}</a> for the current iOS and desktop builds.</p>
    </div>
  </section>`;

  return layout({
    title: "Download for Android",
    description:
      "Download Locmate for Android free. Direct APK, Android 7.0 or newer.",
    path: "/download",
    content,
  });
}

function legalPage({ title, filename, path }) {
  const content = `
  <section class="page-hero page-hero-compact">
    <div class="wrap narrow">
      <p class="eyebrow eyebrow-dark">Legal</p>
      <h1>${escapeHtml(title)}</h1>
      <p class="page-lede">${escapeHtml(config.company)} · ${escapeHtml(
        config.jurisdiction,
      )}</p>
    </div>
  </section>
  <section class="section section-tight">
    <div class="wrap narrow prose">
      ${renderLegal(filename)}
    </div>
  </section>`;

  return layout({
    title,
    description: `${title} for Locmate, operated by ${config.company}.`,
    path,
    content,
  });
}

function notFoundPage() {
  const content = `
  <section class="section success-section">
    <div class="wrap narrow center">
      <p class="eyebrow eyebrow-dark">404</p>
      <h1>This page took a wrong turn.</h1>
      <p class="page-lede">The link may be old, or the page may have moved.</p>
      <div class="status-actions">
        <a class="btn btn-primary" href="/">Back home</a>
        <a class="btn btn-soft" href="/download">Download Locmate</a>
      </div>
    </div>
  </section>`;

  return layout({
    title: "Page not found",
    description: "Page not found.",
    path: "/404",
    noindex: true,
    content,
  });
}

module.exports = {
  homePage,
  downloadPage,
  legalPage,
  notFoundPage,
};
