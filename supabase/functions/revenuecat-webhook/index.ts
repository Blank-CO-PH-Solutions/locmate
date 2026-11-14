// RevenueCat → Supabase webhook.
//
// Keeps public.subscriptions in sync with RevenueCat. The app calls
// Purchases.logIn(<supabase user id>), so `app_user_id` is the Supabase user id.
//
// Deploy:  supabase functions deploy revenuecat-webhook --no-verify-jwt
// Secret:  supabase secrets set REVENUECAT_WEBHOOK_SECRET=<value>
// RevenueCat dashboard → Integrations → Webhooks:
//   URL:                  https://<project-ref>.supabase.co/functions/v1/revenuecat-webhook
//   Authorization header: Bearer <same value as REVENUECAT_WEBHOOK_SECRET>

import { createClient } from "npm:@supabase/supabase-js@2";

const ENTITLEMENT = "premium";
const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// Events that grant or extend access.
const ACTIVE_EVENTS = new Set([
  "INITIAL_PURCHASE",
  "RENEWAL",
  "UNCANCELLATION",
  "PRODUCT_CHANGE",
  "NON_RENEWING_PURCHASE",
  "SUBSCRIPTION_EXTENDED",
  "TEMPORARY_ENTITLEMENT_GRANT",
  // A cancelled subscription stays active until expiration_at_ms.
  "CANCELLATION",
  "BILLING_ISSUE",
]);

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function setActive(userId: string, event: Record<string, unknown>) {
  const expiresMs = event.expiration_at_ms as number | null | undefined;
  const { error } = await supabase.from("subscriptions").upsert({
    user_id: userId,
    entitlement: ENTITLEMENT,
    product_id: (event.product_id as string) ?? null,
    store: (event.store as string) ?? null,
    expires_at: expiresMs ? new Date(expiresMs).toISOString() : null,
    updated_at: new Date().toISOString(),
  });
  if (error) throw error;
}

async function setExpired(userId: string) {
  const { error } = await supabase
    .from("subscriptions")
    .update({ expires_at: new Date().toISOString(), updated_at: new Date().toISOString() })
    .eq("user_id", userId);
  if (error) throw error;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "Method not allowed" });

  const secret = Deno.env.get("REVENUECAT_WEBHOOK_SECRET");
  if (!secret || req.headers.get("Authorization") !== `Bearer ${secret}`) {
    return json(401, { error: "Unauthorized" });
  }

  let event: Record<string, unknown>;
  try {
    event = (await req.json()).event;
  } catch {
    return json(400, { error: "Invalid JSON" });
  }
  if (!event) return json(400, { error: "Missing event" });

  const type = event.type as string;
  const entitlements = (event.entitlement_ids as string[] | null) ?? [];

  try {
    if (type === "TEST") return json(200, { ok: true, test: true });

    if (type === "TRANSFER") {
      const from = (event.transferred_from as string[] | null) ?? [];
      const to = (event.transferred_to as string[] | null) ?? [];
      for (const id of from.filter((id) => UUID_RE.test(id))) await setExpired(id);
      for (const id of to.filter((id) => UUID_RE.test(id))) await setActive(id, event);
      return json(200, { ok: true });
    }

    const userId = event.app_user_id as string;
    if (!UUID_RE.test(userId ?? "")) {
      // Anonymous RevenueCat users are not linked to a Supabase account yet.
      return json(200, { ok: true, skipped: "anonymous user" });
    }
    if (entitlements.length > 0 && !entitlements.includes(ENTITLEMENT)) {
      return json(200, { ok: true, skipped: "other entitlement" });
    }

    if (type === "EXPIRATION") {
      await setExpired(userId);
    } else if (ACTIVE_EVENTS.has(type)) {
      await setActive(userId, event);
    }
    return json(200, { ok: true });
  } catch (error) {
    console.error("revenuecat-webhook", type, error);
    return json(500, { error: "Database update failed" });
  }
});
