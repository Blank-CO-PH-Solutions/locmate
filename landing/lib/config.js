// Environment configuration for the landing site.
//
// Everything secret stays on the server: the Supabase service role key and the
// PayMongo secret/webhook keys are never sent to the browser.

require("dotenv").config();

const clean = (value) => (value || "").trim();

function integerEnv(name, fallback) {
  const raw = clean(process.env[name]);
  if (!raw) return fallback;
  const parsed = Number.parseInt(raw, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

const port = integerEnv("PORT", 3000);

const supabaseUrl = clean(process.env.SUPABASE_URL).replace(/\/+$/, "");
const supabaseServiceRoleKey = clean(process.env.SUPABASE_SERVICE_ROLE_KEY);

const paymongoSecretKey = clean(process.env.PAYMONGO_SECRET_KEY);
const paymongoWebhookSecret = clean(process.env.PAYMONGO_WEBHOOK_SECRET);

const paymentMethods = clean(process.env.PAYMONGO_PAYMENT_METHODS)
  .split(",")
  .map((method) => method.trim())
  .filter(Boolean);

const monthlyAmount = integerEnv("PREMIUM_MONTHLY_AMOUNT", 9900);
const annualAmount = integerEnv("PREMIUM_ANNUAL_AMOUNT", 99900);

const apkUrl = clean(process.env.APK_URL);
const apkUrlIsWeb = /^https?:\/\//i.test(apkUrl);

const config = {
  port,
  publicBaseUrl: clean(process.env.PUBLIC_BASE_URL).replace(/\/+$/, ""),
  nodeEnv: clean(process.env.NODE_ENV) || "development",

  company: "Blank CO PH Solutions",
  supportEmail: "hello@blankcoph.solutions",
  jurisdiction: "Philippines",
  trialDays: 7,

  supabaseUrl,
  supabaseServiceRoleKey,
  hasSupabase: Boolean(supabaseUrl && supabaseServiceRoleKey),

  paymongoSecretKey,
  paymongoWebhookSecret,
  paymentMethods:
    paymentMethods.length > 0
      ? paymentMethods
      : ["card", "gcash", "paymaya", "qrph"],
  paymentsConfigured: Boolean(paymongoSecretKey),

  apkUrl: apkUrlIsWeb ? apkUrl : "",
  apkSha256: clean(process.env.APK_SHA256),
  apkVersion: clean(process.env.APK_VERSION) || "1.0.0",

  plans: {
    monthly: {
      id: "monthly",
      name: "Monthly",
      days: 30,
      amount: monthlyAmount,
      description: "30 days of Locmate Premium",
    },
    annual: {
      id: "annual",
      name: "Annual",
      days: 365,
      amount: annualAmount,
      description: "365 days of Locmate Premium",
    },
  },
};

function planList() {
  return Object.values(config.plans);
}

module.exports = { config, planList };
