// razorpay-create-link
//
// Creates a Razorpay Payment Link (hosted checkout page that supports Card /
// UPI / UPI-QR / Netbanking / Wallet) and records it in `payment_orders`. The
// app opens the returned short_url in an in-app Safari view; a webhook / poll
// then resolves the payment.
//
// Request  (POST JSON): { localOrderId: string, amountPaise: number, description?: string, customerName?: string, customerPhone?: string }
// Response (JSON):      { linkId, shortUrl, amountPaise, status }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const keyId = Deno.env.get("RAZORPAY_KEY_ID");
  const keySecret = Deno.env.get("RAZORPAY_KEY_SECRET");
  if (!keyId || !keySecret) return json({ error: "Razorpay keys not configured" }, 500);

  let body: { localOrderId?: string; amountPaise?: number; description?: string; customerName?: string; customerPhone?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const localOrderId = body.localOrderId;
  const amountPaise = Math.round(body.amountPaise ?? 0);
  if (!localOrderId || amountPaise <= 0) return json({ error: "localOrderId and positive amountPaise are required" }, 400);

  const payload: Record<string, unknown> = {
    amount: amountPaise,
    currency: "INR",
    accept_partial: false,
    description: body.description ?? `Order ${localOrderId}`,
    notify: { sms: false, email: false },
    reminder_enable: false,
    notes: { local_order_id: localOrderId },
  };

  const auth = "Basic " + btoa(`${keyId}:${keySecret}`);
  const resp = await fetch("https://api.razorpay.com/v1/payment_links", {
    method: "POST",
    headers: { Authorization: auth, "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });

  const link = await resp.json();
  if (!resp.ok) {
    return json({ error: "Razorpay payment link create failed", detail: link }, 502);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const { error: trackingError } = await supabase.from("payment_orders").insert({
    local_order_id: localOrderId,
    qr_id: link.id, // reuse the external-id column (plink_… vs qr_…)
    amount_paise: amountPaise,
    status: "created",
    raw: link,
  });
  if (trackingError) {
    // Never expose a payable link that the app cannot subsequently resolve. If
    // tracking is missing, a successful payment polls as unknown forever.
    return json({
      error: "Unable to initialise payment status tracking",
      detail: trackingError.message,
    }, 500);
  }

  return json({
    linkId: link.id,
    shortUrl: link.short_url,
    amountPaise,
    status: "created",
  });
});

function json(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}
