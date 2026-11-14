// Server-rendered pages. No client-side framework: everything important is in
// the HTML so the site works without JavaScript, and /app.js adds the checkout
// and purchase-status interactions.

const { config, planList } = require("./config");
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
    <div class="trial-bubble">
      <span class="trial-bubble-icon">${icon("sparkles")}</span>
      <div><strong>7-day Premium trial</strong><span>Included with every new account</span></div>
    </div>
  </div>`;
}

function pricingCards({ buyLinks = false } = {}) {
  const premiumCta = buyLinks
    ? '<a class="btn btn-primary btn-block" href="/premium#buy">Choose Premium</a>'
    : '<a class="btn btn-primary btn-block" href="/premium">Get Premium</a>';

  return `<div class="pricing-grid">
    <article class="price-card">
      <div class="price-head">
        <span class="plan-pill">Free forever</span>
        <h3>Free</h3>
        <p>Everything you need to start sharing safely.</p>
      </div>
      <p class="price"><span>₱0</span></p>
      <p class="price-note">No card. No trial countdown.</p>
      <ul class="feature-list">
        ${checkItem("Up to <strong>5 circle members</strong>")}
        ${checkItem("Up to <strong>2 saved places</strong>")}
        ${checkItem("Live map and battery status")}
        ${checkItem("Arrival and departure alerts")}
        ${checkItem("Circle chat")}
        ${checkItem("SOS alerts, always free")}
      </ul>
      <a class="btn btn-soft btn-block" href="/download">Download free</a>
    </article>

    <article class="price-card price-card-premium">
      <div class="premium-ribbon">${icon("sparkles")} 7 days free</div>
      <div class="price-head">
        <span class="plan-pill plan-pill-light">For bigger circles</span>
        <h3>Premium</h3>
        <p>Room to grow, plus a heads-up when someone needs a charge.</p>
      </div>
      <p class="price"><span>${formatPeso(monthly.amount)}</span><small>/ 30 days</small></p>
      <p class="price-note">or ${formatPeso(annual.amount)} for a full year${
        annualSaving > 0 ? ` · save ${annualSaving}%` : ""
      }</p>
      <ul class="feature-list">
        ${checkItem("<strong>Unlimited circle members</strong>")}
        ${checkItem("<strong>Unlimited saved places</strong>")}
        ${checkItem("Low-battery alerts")}
        ${checkItem("Everything in Free")}
        ${checkItem("Works in every circle you own")}
      </ul>
      ${premiumCta}
      <p class="price-foot">Starts with a ${config.trialDays}-day free trial. Cancel anytime.</p>
    </article>
  </div>`;
}

function comparisonTable() {
  const rows = [
    ["Circle members", "5", "Unlimited"],
    ["Saved places", "2", "Unlimited"],
    ["Live map and battery status", "Included", "Included"],
    ["Arrival and departure alerts", "Included", "Included"],
    ["Circle chat", "Included", "Included"],
    ["SOS alerts", "Included", "Included"],
    ["Low-battery alerts", "—", "Included"],
    ["7-day Premium trial", "—", "Included"],
  ];

  return `<div class="table-wrap">
    <table class="compare">
      <thead>
        <tr><th scope="col">Feature</th><th scope="col">Free</th><th scope="col" class="is-premium">Premium</th></tr>
      </thead>
      <tbody>
        ${rows
          .map(
            ([feature, free, premium]) => `<tr>
              <th scope="row">${feature}</th>
              <td>${free}</td>
              <td class="is-premium">${premium}</td>
            </tr>`,
          )
          .join("")}
      </tbody>
    </table>
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
    "Is Locmate really free to download?",
    "Yes. The app is free on Android and the Free plan is free forever. You only pay if you want Premium, and every new account starts with a 7-day Premium trial so you can try it first.",
  ],
  [
    "How does the 7-day trial work?",
    `When you create a Locmate account, we automatically turn on Premium for ${config.trialDays} days. No card is required. You will see the days remaining in Settings and on the Premium screen. When the trial ends, your circle simply returns to the Free plan unless you upgrade.`,
  ],
  [
    "What do I get with Premium?",
    "Unlimited circle members and saved places, plus low-battery alerts. Arrival and departure alerts, live location, chat and SOS are included on both plans.",
  ],
  [
    "How do I pay for Premium?",
    "On this site you can buy a 30-day or 365-day Premium pass through PayMongo. You can pay with GCash, Maya, QR Ph or a card on PayMongo's secure checkout page. Use the same email address as your Locmate account so the pass is applied automatically.",
  ],
  [
    "Can I buy Premium before creating an account?",
    "Yes. We link the purchase to the email you enter at checkout. If no Locmate account exists yet, the pass stays pending and is applied automatically the first time you create an account with that email.",
  ],
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
          <a class="btn btn-ghost btn-large" href="/premium">See Premium ${icon("arrow")}</a>
        </div>
        <ul class="hero-points">
          <li>${icon("check")} Free to download</li>
          <li>${icon("check")} ${config.trialDays}-day Premium trial</li>
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
          <p>Know when someone's phone is about to die, so a lost connection does not become a worry. Premium.</p>
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
          <p>Turn on location sharing and add the places that matter. Your ${config.trialDays}-day Premium trial starts automatically.</p>
        </li>
      </ol>
    </div>
  </section>

  <section class="section" id="pricing">
    <div class="wrap">
      <div class="section-head">
        <p class="eyebrow eyebrow-dark">Simple plans</p>
        <h2>Free for the everyday. Premium when you need more room.</h2>
        <p>No subscription is required to use Locmate. Premium is a prepaid pass — 30 days or a full year.</p>
      </div>
      ${pricingCards()}
      <p class="center-note">Premium passes are sold on this site through PayMongo. In the mobile app, Premium is also available through the App Store or Google Play where supported.</p>
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
        <p>Download Locmate free, and try every Premium feature for ${config.trialDays} days.</p>
      </div>
      <div class="cta-actions">
        <a class="btn btn-light btn-large" href="/download">${icon("download")} Download the app</a>
        <a class="btn btn-outline-light btn-large" href="/premium">Compare plans</a>
      </div>
    </div>
  </section>`;

  return layout({
    title: "Locmate",
    description:
      "Locmate is a private location-sharing app for families and friends. See your circle on a live map, get arrival alerts and send an SOS. Free download with a 7-day Premium trial.",
    path: "/",
    content,
  });
}

function checkoutForm({ paymentsConfigured }) {
  const planOption = (plan, checked) => `<label class="plan-option">
    <input type="radio" name="plan" value="${plan.id}" ${checked ? "checked" : ""} ${
      paymentsConfigured ? "" : "disabled"
    }>
    <span class="plan-option-body">
      <span class="plan-option-top">
        <strong>${plan.name}</strong>
        ${plan.id === "annual" ? `<span class="save-pill">Save ${annualSaving}%</span>` : ""}
      </span>
      <span class="plan-option-price">${formatPeso(plan.amount)} <small>/ ${plan.days} days</small></span>
      <span class="plan-option-note">${plan.id === "annual" ? "Best value — a full year of Premium" : "Try Premium for a month"}</span>
    </span>
  </label>`;

  return `<form class="buy-card" id="checkout-form" data-payments-configured="${
    paymentsConfigured ? "true" : "false"
  }" novalidate>
    <div class="buy-card-head">
      <h2>Buy a Premium pass</h2>
      <p>One payment. No auto-renewal, no surprise charges.</p>
    </div>

    ${
      paymentsConfigured
        ? ""
        : `<div class="notice notice-warning" role="status">
            <strong>Payments are being enabled.</strong>
            <span>The ${config.trialDays}-day Premium trial is already available in the app. Please check back shortly to buy a pass here, or email ${escapeHtml(
              config.supportEmail,
            )}.</span>
          </div>`
    }

    <fieldset class="plan-options" ${paymentsConfigured ? "" : "disabled"}>
      <legend>Choose a pass</legend>
      ${planOption(monthly, true)}
      ${planOption(annual, false)}
    </fieldset>

    <label class="field">
      <span>Email address</span>
      <input type="email" name="email" id="checkout-email" inputmode="email" autocomplete="email"
        placeholder="you@example.com" required ${paymentsConfigured ? "" : "disabled"}>
      <small>Use the same email as your Locmate account. If you do not have an account yet, create one later with this email and Premium will be applied automatically.</small>
    </label>

    <label class="check">
      <input type="checkbox" name="terms" required ${paymentsConfigured ? "" : "disabled"}>
      <span>I agree to the <a href="/terms" target="_blank" rel="noopener">Terms of Service</a> and <a href="/privacy" target="_blank" rel="noopener">Privacy Policy</a>.</span>
    </label>

    <button class="btn btn-primary btn-block btn-large" type="submit" ${
      paymentsConfigured ? "" : "disabled"
    }>
      ${paymentsConfigured ? "Continue to secure checkout" : "Payments coming soon"}
    </button>
    <p class="form-status" id="checkout-status" role="status" aria-live="polite"></p>

    <div class="secure-row">
      ${icon("lock")} Secure checkout by PayMongo
      <span class="pay-methods">GCash · Maya · QR Ph · Card</span>
    </div>
  </form>`;
}

function premiumPage({ canceled = false } = {}) {
  const content = `
  <section class="page-hero">
    <div class="wrap narrow center">
      <p class="eyebrow eyebrow-dark">Locmate Premium</p>
      <h1>More room for your circle.</h1>
      <p class="page-lede">Unlimited members, unlimited places and low-battery alerts — as a simple prepaid pass. Every new account tries it free for ${config.trialDays} days.</p>
      <div class="hero-badges">
        <span>${icon("sparkles")} ${config.trialDays}-day free trial</span>
        <span>${icon("wallet")} One-time payment</span>
        <span>${icon("lock")} PayMongo secure checkout</span>
      </div>
    </div>
  </section>

  ${
    canceled
      ? `<div class="wrap narrow"><div class="notice notice-info">Checkout was cancelled. Nothing was charged. You can try again whenever you are ready.</div></div>`
      : ""
  }

  <section class="section section-tight">
    <div class="wrap">
      ${pricingCards({ buyLinks: true })}
    </div>
  </section>

  <section class="section section-tint" id="buy">
    <div class="wrap buy-grid">
      <div class="buy-copy">
        <p class="eyebrow eyebrow-dark">Checkout</p>
        <h2>Premium, without the subscription trap.</h2>
        <p>Pay once for a 30-day or 365-day pass. When it ends, your circle returns to the Free plan — nothing renews automatically.</p>
        <ul class="feature-list feature-list-dark">
          ${checkItem("Premium starts as soon as PayMongo confirms your payment")}
          ${checkItem("Use your Locmate account email so we can match the pass")}
          ${checkItem("Buying before you sign up? We will apply it when your account is created")}
          ${checkItem("Need help? A real person answers at " + escapeHtml(config.supportEmail))}
        </ul>
        <div class="trust-box">
          ${icon("shield")}
          <div>
            <strong>Your card details never touch our servers.</strong>
            <span>You pay on PayMongo's hosted checkout page. Locmate only receives the payment reference and the email you enter.</span>
          </div>
        </div>
      </div>
      ${checkoutForm({ paymentsConfigured: config.paymentsConfigured })}
    </div>
  </section>

  <section class="section">
    <div class="wrap narrow">
      <div class="section-head">
        <p class="eyebrow eyebrow-dark">Compare</p>
        <h2>What changes with Premium?</h2>
      </div>
      ${comparisonTable()}
      <p class="center-note">Premium applies to circles you own. Members of your circle get the higher limits automatically.</p>
    </div>
  </section>

  <section class="section section-tint">
    <div class="wrap narrow">
      <div class="section-head">
        <p class="eyebrow eyebrow-dark">Questions</p>
        <h2>Before you pay.</h2>
      </div>
      ${faq(sharedFaq.slice(1, 7))}
    </div>
  </section>`;

  return layout({
    title: "Premium",
    description: `Locmate Premium: unlimited members, unlimited places and low-battery alerts. ${formatPeso(
      monthly.amount,
    )} for 30 days or ${formatPeso(annual.amount)} for a year. ${config.trialDays}-day free trial.`,
    path: "/premium",
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
        <span>The download link will appear here as soon as the signed APK is uploaded. In the meantime, the ${config.trialDays}-day Premium trial details are ready below.</span>
      </div>
      <a class="btn btn-soft btn-block" href="/premium">Explore Premium</a>`;

  const content = `
  <section class="page-hero">
    <div class="wrap download-grid">
      <div>
        <p class="eyebrow eyebrow-dark">Download</p>
        <h1>Locmate for Android.</h1>
        <p class="page-lede">Install the app directly — no Play Store account needed. Free, with a ${config.trialDays}-day Premium trial when you create your account.</p>
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
          <li><span>4</span><div><strong>Create your circle</strong><p>Sign up with email or Google. Your Premium trial starts automatically.</p></div></li>
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
      "Download Locmate for Android free. Direct APK, Android 7.0 or newer, with a 7-day Premium trial on every new account.",
    path: "/download",
    content,
  });
}

function statusCard({ purchase, reference }) {
  if (!reference) {
    return {
      status: "unknown",
      title: "No purchase reference",
      body: `<p>This page needs the reference from your PayMongo receipt. If you completed a payment, check your email or contact <a href="mailto:${config.supportEmail}">${config.supportEmail}</a>.</p>`,
      icon: "help",
    };
  }

  if (!purchase) {
    return {
      status: "unknown",
      title: "We are looking for your payment",
      body: `<p>If you just paid, PayMongo may still be confirming it. This page refreshes automatically for a couple of minutes. Your reference is <code>${escapeHtml(
        reference,
      )}</code>.</p>`,
      icon: "clock",
    };
  }

  const granted = Boolean(purchase.granted_at);
  const planName =
    purchase.plan === "annual" ? "Annual Premium" : "Monthly Premium";

  if (granted) {
    return {
      status: "granted",
      title: "Premium is active",
      body: `<p>Your <strong>${planName}</strong> pass (${purchase.days} days) has been applied to the Locmate account with the email you used at checkout. Open the app and sign in to see it.</p>`,
      icon: "check",
    };
  }

  return {
    status: "pending",
    title: "Payment received — waiting for your account",
    body: `<p>We received your <strong>${planName}</strong> pass (${purchase.days} days), but there is no Locmate account with that email yet. Create an account with the same email and Premium will be applied automatically.</p>`,
    icon: "clock",
  };
}

function successPage({ purchase, reference }) {
  const status = statusCard({ purchase, reference });

  const content = `
  <section class="section success-section">
    <div class="wrap narrow">
      <div class="status-card status-${status.status}" id="status-card"
        data-ref="${escapeHtml(reference || "")}"
        data-status="${status.status}">
        <span class="status-icon">${icon(status.icon)}</span>
        <p class="eyebrow eyebrow-dark">Premium checkout</p>
        <h1 id="status-title">${status.title}</h1>
        <div id="status-body">${status.body}</div>
        <div class="status-actions">
          <a class="btn btn-primary" href="/download">Open Locmate download</a>
          <a class="btn btn-soft" href="/premium">Back to Premium</a>
        </div>
        <p class="status-help">Need help? Email <a href="mailto:${config.supportEmail}">${config.supportEmail}</a> and include your reference number.</p>
      </div>
    </div>
  </section>`;

  return layout({
    title: "Premium checkout",
    description: "Locmate Premium checkout status.",
    path: "/success",
    noindex: true,
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
  premiumPage,
  downloadPage,
  successPage,
  legalPage,
  notFoundPage,
};
