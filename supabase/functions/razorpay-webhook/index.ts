// razorpay-webhook
//
// Receives Razorpay webhooks, verifies the X-Razorpay-Signature (HMAC-SHA256 of
// the raw body with the webhook secret), and marks the matching payment_orders
// row as paid on `qr_code.credited`.
//
// Deploy with `--no-verify-jwt` (Razorpay does not send a Supabase JWT).
// Subscribe this URL to `qr_code.credited` (and optionally `payment.captured`).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });

  const secret = Deno.env.get("RAZORPAY_WEBHOOK_SECRET");
  if (!secret) return new Response("Webhook secret not configured", { status: 500 });

  const rawBody = await req.text();
  const signature = req.headers.get("x-razorpay-signature") ?? "";

  if (!(await verifySignature(rawBody, signature, secret))) {
    return new Response("Invalid signature", { status: 401 });
  }

  let event: any;
  try {
    event = JSON.parse(rawBody);
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }

  if (event.event === "qr_code.credited" || event.event === "payment_link.paid") {
    // qr_code.credited → UPI QR; payment_link.paid → hosted checkout link.
    const externalId = event.payload?.qr_code?.entity?.id ?? event.payload?.payment_link?.entity?.id;
    const payment = event.payload?.payment?.entity;
    if (externalId) {
      const supabase = createClient(
        Deno.env.get("SUPABASE_URL")!,
        Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      );
      await supabase
        .from("payment_orders")
        .update({
          status: "paid",
          payment_id: payment?.id ?? null,
          amount_paid_paise: payment?.amount ?? null,
          updated_at: new Date().toISOString(),
          raw: event,
        })
        .eq("qr_id", externalId);
    }
  }

  // Always 200 once verified so Razorpay stops retrying.
  return new Response("ok", { status: 200 });
});

async function verifySignature(rawBody: string, signature: string, secret: string): Promise<boolean> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const mac = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(rawBody));
  const expected = [...new Uint8Array(mac)].map((b) => b.toString(16).padStart(2, "0")).join("");
  // Constant-time compare.
  if (expected.length !== signature.length) return false;
  let diff = 0;
  for (let i = 0; i < expected.length; i++) diff |= expected.charCodeAt(i) ^ signature.charCodeAt(i);
  return diff === 0;
}
