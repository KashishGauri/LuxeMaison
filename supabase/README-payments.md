# Razorpay UPI QR — backend setup

The app talks only to these Supabase Edge Functions. The Razorpay secret never
touches the device.

## 0. Prerequisites
- Supabase CLI installed and logged in (`supabase login`).
- Razorpay account in **Test mode**; grab `key_id` + `key_secret` from
  Dashboard → Settings → API Keys.
- Project ref: `zfengirsvsjikrhxrfit` (already used by the app).

## 1. Create the table
Run the migration in the SQL editor (or `supabase db push`):
```
supabase/migrations/0001_payment_orders.sql
```

## 2. Set secrets (NEVER put these in the app)
```sh
supabase secrets set \
  RAZORPAY_KEY_ID=rzp_test_xxxxxxxx \
  RAZORPAY_KEY_SECRET=xxxxxxxxxxxxxxxx \
  RAZORPAY_WEBHOOK_SECRET=choose_a_strong_string
```
`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are injected automatically.

## 3. Deploy the functions
```sh
supabase functions deploy razorpay-create-link    --project-ref zfengirsvsjikrhxrfit
supabase functions deploy razorpay-create-qr      --project-ref zfengirsvsjikrhxrfit
supabase functions deploy razorpay-payment-status --project-ref zfengirsvsjikrhxrfit
supabase functions deploy razorpay-webhook --no-verify-jwt --project-ref zfengirsvsjikrhxrfit
```
`--no-verify-jwt` only on the webhook (Razorpay can't send a Supabase JWT). The
others require the anon JWT the app already sends.

`razorpay-create-link` powers the redirect flow: Proceed to Pay → a hosted
Razorpay page (card / UPI / QR) opens in an in-app Safari view → after payment
the app polls status and continues. `razorpay-create-qr` is the older
UPI-QR-only path (kept for reference).

## 4. Configure the webhook (recommended)
Razorpay Dashboard → Settings → Webhooks → Add:
- URL: `https://zfengirsvsjikrhxrfit.supabase.co/functions/v1/razorpay-webhook`
- Secret: the same `RAZORPAY_WEBHOOK_SECRET` from step 2
- Active events: `payment_link.paid` and `qr_code.credited` (optionally `payment.captured`)

> Even without the webhook, the app's status poll falls back to querying
> Razorpay directly, so testing works — the webhook just makes it instant.

## 5. Turn it on in the app
In the payment screen's **Demo** menu, enable **"Live UPI QR (Razorpay)"**.
Pick UPI QR → a real Razorpay QR renders and the app polls for payment.

## Test-mode note
In **test mode** you cannot pay a QR with a real UPI app. Simulate the payment
from the Razorpay Dashboard (the test QR page has a "pay"/simulate option) or use
Razorpay's test payment tooling. The webhook/poll then flips the order to `paid`.
Real scan-to-pay works only in **live mode**.

## Endpoints (for reference)
| Function | Method | Body | Returns |
|---|---|---|---|
| `razorpay-create-qr` | POST | `{localOrderId, amountPaise, description?, closeBySeconds?}` | `{qrId, imageUrl, closeBy, amountPaise, status}` |
| `razorpay-payment-status` | POST | `{qrId}` | `{status, amountPaidPaise, paymentId}` |
| `razorpay-webhook` | POST | Razorpay event | `200 ok` |
