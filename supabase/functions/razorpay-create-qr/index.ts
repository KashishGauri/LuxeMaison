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

  // Razorpay requires close_by to be at least ~2 min in the future.
  const closeBySeconds = Math.max(120, Math.min(body.closeBySeconds ?? 420, 2 * 60 * 60));
  const closeBy = Math.floor(Date.now() / 1000) + closeBySeconds;

  const auth = "Basic " + btoa(`${keyId}:${keySecret}`);
  const razorpayResp = await fetch("https://api.razorpay.com/v1/payments/qr_codes", {
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
  });

  const qr = await razorpayResp.json();
  if (!razorpayResp.ok) {
    return json({ error: "Razorpay QR create failed", detail: qr }, 502);
  }

  // Record it so the webhook / status poll can resolve payment.
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  await supabase.from("payment_orders").insert({
    local_order_id: localOrderId,
    qr_id: qr.id,
    amount_paise: amountPaise,
    status: "created",
    close_by: new Date(closeBy * 1000).toISOString(),
    raw: qr,
  });

  return json({
    qrId: qr.id,
    imageUrl: qr.image_url,
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
