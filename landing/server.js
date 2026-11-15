// Locmate landing site and PayMongo Premium checkout.
//
// Run locally:  cd landing && npm install && npm start
// Render:       build: cd landing && npm install
//               start: cd landing && npm start

const path = require("node:path");
const crypto = require("node:crypto");
const express = require("express");

const { config } = require("./lib/config");
const {
  homePage,
  downloadPage,
  legalPage,
  notFoundPage,
} = require("./lib/pages");

const app = express();
const publicDirectory = path.join(__dirname, "public");

app.disable("x-powered-by");
app.set("trust proxy", 1);

app.use((req, res, next) => {
  res.setHeader("X-Content-Type-Options", "nosniff");
  res.setHeader("X-Frame-Options", "DENY");
  res.setHeader("Referrer-Policy", "strict-origin-when-cross-origin");
  res.setHeader(
    "Permissions-Policy",
    "geolocation=(), camera=(), microphone=(), payment=()",
  );
  res.setHeader(
    "Content-Security-Policy",
    [
      "default-src 'self'",
      "base-uri 'none'",
      "form-action 'self'",
      "frame-ancestors 'none'",
      "object-src 'none'",
      "img-src 'self' data:",
      "style-src 'self' 'unsafe-inline'",
      "script-src 'self'",
      "connect-src 'self'",
    ].join("; "),
  );
  if (config.publicBaseUrl.startsWith("https://")) {
    res.setHeader(
      "Strict-Transport-Security",
      "max-age=31536000; includeSubDomains",
    );
  }
  next();
});

// ---------- Rate limiting (single Render instance) ----------
const requestBuckets = new Map();

function rateLimit({ windowMs, max }) {
  return (req, res, next) => {
    const now = Date.now();
    const key = `${req.ip}:${req.path}`;
    const bucket = requestBuckets.get(key) || [];
    const recent = bucket.filter((time) => now - time < windowMs);
    if (recent.length >= max) {
      res.setHeader("Retry-After", String(Math.ceil(windowMs / 1000)));
      return res.status(429).json({
        error: "too_many_requests",
        message: "Too many attempts. Please wait a moment and try again.",
      });
    }
    recent.push(now);
    requestBuckets.set(key, recent);
    if (requestBuckets.size > 5000) {
      for (const [bucketKey, times] of requestBuckets) {
        if (times.every((time) => now - time >= windowMs)) {
          requestBuckets.delete(bucketKey);
        }
      }
    }
    next();
  };
}

// ---------- Helpers ----------
function baseUrl(req) {
  return (
    config.publicBaseUrl ||
    `${req.protocol}://${req.get("host") || `localhost:${config.port}`}`
  );
}

function newReference() {
  const date = new Date().toISOString().slice(0, 10).replaceAll("-", "");
  return `LM-${date}-${crypto.randomBytes(6).toString("hex").toUpperCase()}`;
}

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function validReference(value) {
  return (
    typeof value === "string" &&
    value.length > 0 &&
    value.length <= 120 &&
    /^[A-Za-z0-9._:-]+$/.test(value)
  );
}

// ---------- Public JSON API ----------
app.get("/healthz", (req, res) => {
  res.setHeader("Cache-Control", "no-store");
  res.json({
    ok: true,
    service: "locmate-landing",
    uptimeSeconds: Math.round(process.uptime()),
    supabase: config.hasSupabase,
    payments: config.paymentsConfigured,
  });
});

app.get("/api/config", (req, res) => {
  res.setHeader("Cache-Control", "public, max-age=60");
  res.json({
    company: config.company,
    supportEmail: config.supportEmail,
    download: {
      available: Boolean(config.apkUrl),
      version: config.apkVersion,
      sha256: config.apkSha256 || null,
    },
  });
});

app.get("/api/download", (req, res) => {
  if (!config.apkUrl) {
    return res.status(503).json({
      error: "download_unavailable",
      message: "The Android build is not available yet.",
    });
  }
  res.setHeader("Cache-Control", "no-store");
  res.redirect(302, config.apkUrl);
});

// ---------- PayMongo webhook ----------
// Raw body is required for signature verification, so this route must be
// registered before express.json() is used anywhere else.
// ---------- Pages ----------
app.get("/", (req, res) => {
  res.setHeader("Cache-Control", "public, max-age=300");
  res.type("html").send(homePage());
});

app.get("/download", (req, res) => {
  res.setHeader("Cache-Control", "public, max-age=120");
  res.type("html").send(downloadPage());
});

app.get("/privacy", (req, res) => {
  res.setHeader("Cache-Control", "public, max-age=300");
  res.type("html").send(
    legalPage({
      title: "Privacy Policy",
      filename: "privacy_policy.md",
      path: "/privacy",
    }),
  );
});

app.get("/terms", (req, res) => {
  res.setHeader("Cache-Control", "public, max-age=300");
  res.type("html").send(
    legalPage({
      title: "Terms of Service",
      filename: "terms_of_service.md",
      path: "/terms",
    }),
  );
});

app.get("/robots.txt", (req, res) => {
  res.type("text/plain").send("User-agent: *\nAllow: /\nDisallow: /success\n");
});

app.use(
  express.static(publicDirectory, {
    index: false,
    maxAge: "7d",
    setHeaders(res, filePath) {
      if (filePath.endsWith("app.js") || filePath.endsWith("styles.css")) {
        res.setHeader("Cache-Control", "public, max-age=300");
      }
    },
  }),
);

app.use((req, res) => {
  if (req.path.startsWith("/api/") || req.path.startsWith("/webhooks/")) {
    return res.status(404).json({ error: "not_found" });
  }
  res.status(404).type("html").send(notFoundPage());
});

// Final error handler: log the detail, return a generic page or JSON.
app.use((error, req, res, next) => {
  console.error(`[error] ${req.method} ${req.path}: ${error.message}`);
  if (res.headersSent) return next(error);

  if (req.path.startsWith("/api/") || req.path.startsWith("/webhooks/")) {
    return res.status(500).json({ error: "server_error" });
  }
  res.status(500).type("html").send(notFoundPage());
});

const server = app.listen(config.port, () => {
  console.log(
    `Locmate landing listening on port ${config.port} (payments=${
      config.paymentsConfigured ? "on" : "off"
    }, supabase=${config.hasSupabase ? "on" : "off"}, apk=${
      config.apkUrl ? "on" : "off"
    })`,
  );
});

function shutdown(signal) {
  console.log(`[shutdown] ${signal}`);
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(1), 10000).unref();
}

process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));

module.exports = app;
