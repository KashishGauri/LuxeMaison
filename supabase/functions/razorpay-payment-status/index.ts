// razorpay-payment-status
//
// Polled by the app while the QR is on screen. Returns the payment status from
// `payment_orders`. If the webhook hasn't landed yet, it falls back to querying
// Razorpay directly so polling still resolves (webhook is recommended, not required).
//
// Request  (POST JSON): { qrId: string }
// Response (JSON):      { status, amountPaidPaise, paymentId }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  let body: { qrId?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }
  const qrId = body.qrId;
  if (!qrId) return json({ error: "qrId is required" }, 400);

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: row } = await supabase
    .from("payment_orders")
    .select("*")
    .eq("qr_id", qrId)
    .maybeSingle();

  if (!row) return json({ status: "unknown", amountPaidPaise: null, paymentId: null });

  // Already resolved by the webhook.
  if (row.status === "paid") {
    return json({ status: "paid", amountPaidPaise: row.amount_paid_paise, paymentId: row.payment_id });
  }

  // Fallback: ask Razorpay directly (works even before the webhook lands).
  const keyId = Deno.env.get("RAZORPAY_KEY_ID");
  const keySecret = Deno.env.get("RAZORPAY_KEY_SECRET");
  if (keyId && keySecret) {
    const auth = "Basic " + btoa(`${keyId}:${keySecret}`);

    if (qrId.startsWith("plink_")) {
      // Payment Link (hosted checkout: card / UPI / QR).
      const resp = await fetch(`https://api.razorpay.com/v1/payment_links/${qrId}`, {
        headers: { Authorization: auth },
      });
      if (resp.ok) {
        const link = await resp.json();
        if (link.status === "paid") {
          const paidPaise = link.amount_paid ?? row.amount_paise;
          const paymentId = link.payments?.[0]?.payment_id ?? null;
          await supabase
            .from("payment_orders")
            .update({ status: "paid", amount_paid_paise: paidPaise, payment_id: paymentId, updated_at: new Date().toISOString() })
            .eq("qr_id", qrId);
          return json({ status: "paid", amountPaidPaise: paidPaise, paymentId });
        }
      }
    } else {
      // UPI QR code.
      const resp = await fetch(`https://api.razorpay.com/v1/payments/qr_codes/${qrId}`, {
        headers: { Authorization: auth },
      });
      if (resp.ok) {
        const qr = await resp.json();
        const received = qr.payments_amount_received ?? 0;
        if (received >= row.amount_paise) {
          let paymentId: string | null = null;
          const payResp = await fetch(`https://api.razorpay.com/v1/payments/qr_codes/${qrId}/payments`, {
            headers: { Authorization: auth },
          });
          if (payResp.ok) {
            const payments = await payResp.json();
            paymentId = payments?.items?.[0]?.id ?? null;
          }
          await supabase
            .from("payment_orders")
            .update({ status: "paid", amount_paid_paise: received, payment_id: paymentId, updated_at: new Date().toISOString() })
            .eq("qr_id", qrId);
          return json({ status: "paid", amountPaidPaise: received, paymentId });
        }
      }
    }
  }

  // Expire on read once close_by has passed.
  if (row.close_by && new Date(row.close_by).getTime() < Date.now()) {
    return json({ status: "expired", amountPaidPaise: null, paymentId: null });
  }

  return json({ status: row.status, amountPaidPaise: null, paymentId: null });
});

function json(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}
