// Supabase access for the landing page. Only the server uses the service role
// key. The browser never receives it.

const { config } = require("./config");

class SupabaseError extends Error {
  constructor(message, status) {
    super(message);
    this.name = "SupabaseError";
    this.status = status;
  }
}

function headers() {
  return {
    apikey: config.supabaseServiceRoleKey,
    Authorization: `Bearer ${config.supabaseServiceRoleKey}`,
    "Content-Type": "application/json",
    Accept: "application/json",
  };
}

async function callRpc(name, body) {
  if (!config.hasSupabase) {
    throw new SupabaseError("Supabase is not configured", 503);
  }

  let response;
  try {
    response = await fetch(`${config.supabaseUrl}/rest/v1/rpc/${name}`, {
      method: "POST",
      headers: headers(),
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(15000),
    });
  } catch (error) {
    throw new SupabaseError(`Could not reach Supabase: ${error.message}`, 502);
  }

  const text = await response.text();
  let parsed = null;
  try {
    parsed = text ? JSON.parse(text) : null;
  } catch {
    // Leave parsed null; the status code is enough for the caller.
  }

  if (!response.ok) {
    const detail =
      parsed?.message || parsed?.hint || `Supabase returned ${response.status}`;
    throw new SupabaseError(detail, response.status);
  }

  return parsed;
}

// Idempotent: the database deduplicates on (provider, provider_payment_id).
async function recordPaymongoPurchase(purchase) {
  return callRpc("record_paymongo_purchase", {
    p_payment_id: purchase.paymentId,
    p_checkout_session_id: purchase.checkoutSessionId,
    p_reference_number: purchase.referenceNumber,
    p_email: purchase.email,
    p_plan: purchase.plan,
    p_amount: purchase.amount,
    p_currency: purchase.currency,
    p_days: purchase.days,
  });
}

async function getPurchaseByReference(reference) {
  if (!reference || !config.hasSupabase) return null;

  const params = new URLSearchParams({
    reference_number: `eq.${reference}`,
    select: "reference_number,plan,days,amount,currency,granted_at,created_at",
    limit: "1",
  });

  let response;
  try {
    response = await fetch(
      `${config.supabaseUrl}/rest/v1/premium_purchases?${params}`,
      { headers: headers(), signal: AbortSignal.timeout(10000) },
    );
  } catch (error) {
    throw new SupabaseError(`Could not reach Supabase: ${error.message}`, 502);
  }

  if (!response.ok) {
    throw new SupabaseError(`Supabase returned ${response.status}`, 502);
  }

  const rows = await response.json();
  return Array.isArray(rows) && rows.length > 0 ? rows[0] : null;
}

module.exports = {
  SupabaseError,
  recordPaymongoPurchase,
  getPurchaseByReference,
};
