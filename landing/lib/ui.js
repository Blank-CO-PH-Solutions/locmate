// Shared HTML shell and small presentational helpers.

const { config } = require("./config");

const ICONS = {
  pin: '<path d="M20 10c0 5-8 12-8 12S4 15 4 10a8 8 0 1 1 16 0Z"/><circle cx="12" cy="10" r="3"/>',
  users:
    '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>',
  bell:
    '<path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/>',
  message:
    '<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>',
  battery:
    '<rect x="2" y="7" width="16" height="10" rx="2"/><path d="M22 11v2"/><path d="M6 11v2"/><path d="M10 11v2"/>',
  shield:
    '<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><path d="m9 12 2 2 4-4"/>',
  check: '<path d="m20 6-11 11-5-5"/>',
  arrow: '<path d="M5 12h14"/><path d="m13 6 6 6-6 6"/>',
  download:
    '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><path d="m7 10 5 5 5-5"/><path d="M12 15V3"/>',
  sparkles:
    '<path d="m12 3 1.9 5.1L19 10l-5.1 1.9L12 17l-1.9-5.1L5 10l5.1-1.9L12 3Z"/><path d="M19 15l.9 2.1L22 18l-2.1.9L19 21l-.9-2.1L16 18l2.1-.9L19 15Z"/>',
  lock:
    '<rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>',
  heart:
    '<path d="M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.7l-1.1-1.1a5.5 5.5 0 0 0-7.8 7.8l1.1 1.1L12 21l7.8-7.5 1.1-1.1a5.5 5.5 0 0 0-.1-7.8Z"/>',
  route:
    '<circle cx="6" cy="19" r="3"/><path d="M9 19h8.5a3.5 3.5 0 0 0 0-7h-11a3.5 3.5 0 0 1 0-7H15"/><circle cx="18" cy="5" r="3"/>',
  globe:
    '<circle cx="12" cy="12" r="10"/><path d="M2 12h20"/><path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/>',
  phone:
    '<rect x="6" y="2" width="12" height="20" rx="2"/><path d="M12 18h.01"/>',
  clock:
    '<circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/>',
  wallet:
    '<path d="M20 12V8H6a2 2 0 0 1 0-4h12v4"/><path d="M4 6v12a2 2 0 0 0 2 2h14v-4"/><path d="M18 12a2 2 0 0 0 0 4h4v-4Z"/>',
  mail:
    '<rect x="2" y="4" width="20" height="16" rx="2"/><path d="m22 7-10 6L2 7"/>',
  help:
    '<circle cx="12" cy="12" r="10"/><path d="M9.1 9a3 3 0 0 1 5.8 1c0 2-3 2-3 4"/><path d="M12 17h.01"/>',
};

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function icon(name, className = "") {
  const paths = ICONS[name];
  if (!paths) throw new Error(`Unknown icon: ${name}`);
  return `<svg class="icon ${className}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${paths}</svg>`;
}

function formatPeso(centavos) {
  const value = Number(centavos) / 100;
  return `₱${value.toLocaleString("en-PH", {
    minimumFractionDigits: Number.isInteger(value) ? 0 : 2,
    maximumFractionDigits: 2,
  })}`;
}

function navItem(label, href, path) {
  const active = href === "/" ? path === "/" : path.startsWith(href);
  return `<a class="nav-link${active ? " is-active" : ""}" href="${href}"${
    active ? ' aria-current="page"' : ""
  }>${label}</a>`;
}

function layout({
  title,
  description,
  path = "/",
  content,
  noindex = false,
  bodyClass = "",
}) {
  const pageTitle =
    path === "/"
      ? "Locmate — keep your circle close"
      : `${title} · Locmate`;
  const shareImage = `${config.publicBaseUrl || ""}/img/locmate-logo.png`;

  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${escapeHtml(pageTitle)}</title>
  <meta name="description" content="${escapeHtml(description)}">
  <meta name="theme-color" content="#3B0F7A">
  ${noindex ? '<meta name="robots" content="noindex,nofollow">' : ""}
  <link rel="icon" type="image/png" href="/img/favicon.png">
  <link rel="apple-touch-icon" href="/img/locmate-mark.png">
  <link rel="stylesheet" href="/styles.css">
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="Locmate">
  <meta property="og:title" content="${escapeHtml(pageTitle)}">
  <meta property="og:description" content="${escapeHtml(description)}">
  <meta property="og:image" content="${escapeHtml(shareImage)}">
  <meta property="og:url" content="${escapeHtml(`${config.publicBaseUrl || ""}${path}`)}">
  <meta name="twitter:card" content="summary_large_image">
</head>
<body class="${escapeHtml(bodyClass)}">
  <a class="skip-link" href="#main">Skip to content</a>

  <header class="site-header">
    <div class="wrap nav">
      <a class="brand" href="/" aria-label="Locmate home">
        <img src="/img/locmate-mark.png" alt="" width="38" height="38">
        <span>Locmate</span>
      </a>
      <nav class="nav-links" aria-label="Main navigation">
        ${navItem("Why Locmate", "/#features", path)}
        ${navItem("Download", "/download", path)}
        ${navItem("Help", "/#faq", path)}
      </nav>
      <a class="btn btn-small btn-primary nav-cta" href="/download">Get the app</a>
    </div>
  </header>

  <main id="main">
    ${content}
  </main>

  <footer class="site-footer">
    <div class="wrap footer-grid">
      <div class="footer-brand">
        <a class="brand" href="/">
          <img src="/img/locmate-mark.png" alt="" width="36" height="36">
          <span>Locmate</span>
        </a>
        <p>A calmer way to keep the people you love close.</p>
        <p class="footer-company">${escapeHtml(config.company)} · ${escapeHtml(
          config.jurisdiction,
        )}</p>
      </div>
      <div>
        <h2>Product</h2>
        <a href="/#features">Features</a>
        <a href="/download">Download for Android</a>
        <a href="/#faq">FAQ</a>
      </div>
      <div>
        <h2>Company</h2>
        <a href="mailto:${escapeHtml(config.supportEmail)}">Contact us</a>
        <a href="/privacy">Privacy Policy</a>
        <a href="/terms">Terms of Service</a>
        <a href="/healthz">Service status</a>
      </div>
      <div class="footer-note">
        <h2>Support</h2>
        <p>Questions about your account or a payment?</p>
        <a class="footer-mail" href="mailto:${escapeHtml(
          config.supportEmail,
        )}">${escapeHtml(config.supportEmail)}</a>
        <p class="muted">We usually reply within 2 business days.</p>
      </div>
    </div>
    <div class="wrap footer-bottom">
      <span>© 2026 ${escapeHtml(config.company)}. All rights reserved.</span>
      <span class="footer-legal">
        <a href="/privacy">Privacy</a>
        <a href="/terms">Terms</a>
      </span>
    </div>
  </footer>

  <script src="/app.js" defer></script>
</body>
</html>`;
}

module.exports = {
  escapeHtml,
  formatPeso,
  icon,
  layout,
};
