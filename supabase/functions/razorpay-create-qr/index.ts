// razorpay-create-qr
//
// Creates a single-use, fixed-amount UPI QR code via the Razorpay QR Codes API
// and records it in `payment_orders`. The Razorpay key_secret lives only in the
// function's environment — never on the device.
//
// Request  (POST JSON): { localOrderId: string, amountPaise: number, description?: string, closeBySeconds?: number }
// Response (JSON):      { qrId, imageUrl, closeBy (unix s), amountPaise, status }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  // This function is deployed with gateway JWT verification disabled because
  // the project still uses a legacy anon JWT that the current Edge gateway
  // rejects. Preserve the same access boundary inside the function instead.
  const expectedAnonKey = Deno.env.get("APP_LEGACY_ANON_KEY") ?? Deno.env.get("SUPABASE_ANON_KEY");
  const suppliedAPIKey = req.headers.get("apikey");
  const suppliedBearer = req.headers.get("authorization")?.replace(/^Bearer\s+/i, "");
  if (!expectedAnonKey || (suppliedAPIKey !== expectedAnonKey && suppliedBearer !== expectedAnonKey)) {
    return json({ error: "Unauthorized" }, 401);
  }

  const keyId = Deno.env.get("RAZORPAY_KEY_ID");
  const keySecret = Deno.env.get("RAZORPAY_KEY_SECRET");
  if (!keyId || !keySecret) return json({ error: "Razorpay keys not configured" }, 500);

  let body: { localOrderId?: string; amountPaise?: number; description?: string; closeBySeconds?: number };
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const localOrderId = body.localOrderId;
  const amountPaise = Math.round(body.amountPaise ?? 0);
  if (!localOrderId || amountPaise <= 0) return json({ error: "localOrderId and positive amountPaise are required" }, 400);

  // Razorpay requires close_by to be at least 15 minutes in the future.
  // Keep a small clock-skew buffer so latency cannot push it below the minimum.
  const closeBySeconds = Math.max(15 * 60 + 30, Math.min(body.closeBySeconds ?? 15 * 60 + 30, 2 * 60 * 60));
  const closeBy = Math.floor(Date.now() / 1000) + closeBySeconds;

  const auth = "Basic " + btoa(`${keyId}:${keySecret}`);
  const directQREnabled = Deno.env.get("RAZORPAY_DIRECT_QR_ENABLED") === "true";
  const razorpayResp = directQREnabled
    ? await fetch("https://api.razorpay.com/v1/payments/qr_codes", {
        method: "POST",
        headers: { Authorization: auth, "Content-Type": "application/json" },
        body: JSON.stringify({
          type: "upi_qr",
          name: "Luxe Maison",
          usage: "single_use",
          fixed_amount: true,
          payment_amount: amountPaise,
          description: body.description ?? `Order ${localOrderId}`,
          close_by: closeBy,
          notes: { local_order_id: localOrderId },
        }),
      })
    : null;

  const qr = razorpayResp
    ? await razorpayResp.json()
    : { error: { description: "Direct Razorpay QR API is not enabled for this merchant." } };

  let externalId: string;
  let imageUrl: string | null = null;
  let qrPayload: string | null = null;
  let gatewayMode: "upi_qr" | "payment_link_qr";
  let raw: unknown;

  if (razorpayResp?.ok) {
    externalId = qr.id;
    imageUrl = qr.image_url;
    gatewayMode = "upi_qr";
    raw = qr;
  } else {
    // QR Codes API is an on-demand Razorpay feature and may not be enabled for
    // every merchant. Fall back to a short-lived standard Payment Link encoded
    // as a QR. The customer still scans a unique, amount-locked Razorpay URL and
    // the existing plink webhook/poller reconciles the payment.
    const referenceId = `${localOrderId.slice(0, 24)}-${crypto.randomUUID().slice(0, 8)}`;
    const linkResp = await fetch("https://api.razorpay.com/v1/payment_links", {
      method: "POST",
      headers: { Authorization: auth, "Content-Type": "application/json" },
      body: JSON.stringify({
        amount: amountPaise,
        currency: "INR",
        accept_partial: false,
        reference_id: referenceId,
        description: body.description ?? `Order ${localOrderId}`,
        expire_by: closeBy,
        notify: { sms: false, email: false },
        reminder_enable: false,
        notes: { local_order_id: localOrderId, checkout_mode: "scan_to_pay" },
      }),
    });
    const link = await linkResp.json();
    if (!linkResp.ok || !link.id || !link.short_url) {
      return json({
        error: "Razorpay QR and scan-to-pay fallback both failed",
        detail: { qr, paymentLink: link },
      }, 502);
    }
    externalId = link.id;
    qrPayload = link.short_url;
    gatewayMode = "payment_link_qr";
    raw = { qrError: qr, paymentLink: link };
  }

  // Record it so the webhook / status poll can resolve payment.
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const { error: trackingError } = await supabase.from("payment_orders").insert({
    local_order_id: localOrderId,
    qr_id: externalId,
    amount_paise: amountPaise,
    status: "created",
    close_by: new Date(closeBy * 1000).toISOString(),
    raw,
  });
  if (trackingError) {
    // Do not show a QR that cannot be resolved by webhook/polling; otherwise the
    // customer can pay while the app remains stuck before receipt generation.
    return json({
      error: "Unable to initialise payment status tracking",
      detail: trackingError.message,
    }, 500);
  }

  return json({
    qrId: externalId,
    imageUrl,
    qrPayload,
    gatewayMode,
    closeBy,
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
