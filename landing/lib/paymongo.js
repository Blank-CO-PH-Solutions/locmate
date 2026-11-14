// PayMongo Hosted Checkout helpers.
//
// Docs: https://docs.paymongo.com/docs/payment-channels-hosted-checkout
// The secret key is HTTP basic auth with an empty password (trailing colon).

const crypto = require("crypto");
const { config } = require("./config");

const API_BASE = "https://api.paymongo.com/v2";

class PayMongoError extends Error {
  constructor(message, status) {
    super(message);
    this.name = "PayMongoError";
    this.status = status;
  }
}

async function createCheckoutSession({ email, plan, reference, baseUrl }) {
  if (!config.paymongoSecretKey) {
    throw new PayMongoError("Payments are not configured", 503);
  }

  const authorization = Buffer.from(
    `${config.paymongoSecretKey}:`,
    "utf8",
  ).toString("base64");

  const payload = {
    data: {
      attributes: {
        description: "Locmate Premium",
        line_items: [
          {
            name: `Locmate Premium · ${plan.days} days`,
            description:
              "Unlimited circle members, unlimited places and low-battery alerts.",
            amount: plan.amount,
            currency: "PHP",
            quantity: 1,
          },
        ],
        payment_method_types: config.paymentMethods,
        reference_number: reference,
        send_email_receipt: true,
        show_description: true,
        show_line_items: true,
        success_url: `${baseUrl}/success?ref=${encodeURIComponent(reference)}`,
        cancel_url: `${baseUrl}/premium?canceled=1`,
        metadata: {
          source: "locmate_landing",
          reference,
          email,
          plan: plan.id,
          days: String(plan.days),
        },
      },
    },
  };

  let response;
  try {
    response = await fetch(`${API_BASE}/checkout_sessions`, {
      method: "POST",
      headers: {
        Authorization: `Basic ${authorization}`,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify(payload),
      signal: AbortSignal.timeout(15000),
    });
  } catch (error) {
    throw new PayMongoError(
      `Could not reach PayMongo: ${error.message}`,
      502,
    );
  }

  const text = await response.text();
  let body = null;
  try {
    body = text ? JSON.parse(text) : null;
  } catch {
    // Keep the raw text for the server log; never return it to the browser.
  }

  if (!response.ok) {
    const detail =
      body?.errors?.[0]?.detail ||
      body?.errors?.[0]?.code ||
      `PayMongo returned ${response.status}`;
    throw new PayMongoError(detail, response.status);
  }

  const session = body?.data;
  const checkoutUrl = session?.attributes?.checkout_url;
  if (!checkoutUrl) {
    throw new PayMongoError("PayMongo did not return a checkout URL", 502);
  }

  return {
    id: session.id,
    checkoutUrl,
    status: session.attributes?.status || "active",
  };
}

// Verify the Paymongo-Signature header:
//   t=<timestamp>,te=<test signature>,li=<live signature>
// The signed payload is `${t}.${rawBody}`. Accept either signature so the same
// deployment works with test and live keys.
function verifyWebhookSignature(rawBody, signatureHeader) {
  if (!config.paymongoWebhookSecret || !signatureHeader) return false;

  const parts = {};
  for (const part of signatureHeader.split(",")) {
    const index = part.indexOf("=");
    if (index === -1) continue;
    parts[part.slice(0, index).trim()] = part.slice(index + 1).trim();
  }

  if (!parts.t) return false;

  const expected = crypto
    .createHmac("sha256", config.paymongoWebhookSecret)
    .update(`${parts.t}.`)
    .update(rawBody)
    .digest("hex");

  const expectedBuffer = Buffer.from(expected, "utf8");
  for (const key of ["li", "te"]) {
    const candidate = parts[key];
    if (!candidate) continue;
    const candidateBuffer = Buffer.from(candidate, "utf8");
    if (
      candidateBuffer.length === expectedBuffer.length &&
      crypto.timingSafeEqual(candidateBuffer, expectedBuffer)
    ) {
      return true;
    }
  }
  return false;
}

// Turn a signed webhook event into the fields we store. Returns null for
// events we do not handle.
function normalizePaidEvent(event) {
  const attributes = event?.data?.attributes;
  if (!attributes) return null;

  const type = attributes.type;
  if (type !== "checkout_session.payment.paid" && type !== "payment.paid") {
    return null;
  }

  const resource = attributes.data || {};
  const resourceAttributes = resource.attributes || {};
  const metadata = resourceAttributes.metadata || {};

  const payments = Array.isArray(resourceAttributes.payments)
    ? resourceAttributes.payments
    : [];
  const paidPayment =
    payments.find((payment) => payment?.attributes?.status === "paid") ||
    payments[0] ||
    null;
  const paymentAttributes = paidPayment?.attributes || {};

  if (type === "payment.paid" && paymentAttributes.status !== "paid") {
    return null;
  }

  // Metadata for hosted checkout lives on the Checkout Session; for a direct
  // payment event it lives on the payment itself.
  const mergedMetadata =
    type === "checkout_session.payment.paid"
      ? metadata
      : { ...metadata, ...(paymentAttributes.metadata || {}) };

  const paymentId =
    type === "checkout_session.payment.paid" ? paidPayment?.id : resource.id;
  if (!paymentId) return null;

  const plan = mergedMetadata.plan;
  if (plan !== "monthly" && plan !== "annual") return null;

  const configuredPlan = config.plans[plan];
  const amount = Number(
    paymentAttributes.amount ??
      resourceAttributes.amount ??
      resourceAttributes.payment_intent?.attributes?.amount ??
      0,
  );
  const email = String(
    mergedMetadata.email ||
      paymentAttributes.billing?.email ||
      resourceAttributes.billing?.email ||
      "",
  )
    .trim()
    .toLowerCase();

  if (!email) return null;

  return {
    type,
    paymentId,
    checkoutSessionId:
      type === "checkout_session.payment.paid" ? resource.id : null,
    referenceNumber:
      resourceAttributes.reference_number ||
      mergedMetadata.reference ||
      resourceAttributes.external_reference_number ||
      null,
    email,
    plan,
    days: Number.parseInt(mergedMetadata.days, 10) || configuredPlan.days,
    amount: amount > 0 ? amount : configuredPlan.amount,
    currency: paymentAttributes.currency || resourceAttributes.currency || "PHP",
  };
}

module.exports = {
  PayMongoError,
  createCheckoutSession,
  verifyWebhookSignature,
  normalizePaidEvent,
};
