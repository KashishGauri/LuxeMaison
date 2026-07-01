-- Payment orders for the Razorpay UPI QR flow.
-- Rows are created by `razorpay-create-qr` and updated to `paid` by
-- `razorpay-webhook` (or the status-poll fallback). The Edge Functions use the
-- service role and bypass RLS; the anon key never reads/writes this table
-- directly, so no anon policy is granted.

create table if not exists public.payment_orders (
    id                uuid primary key default gen_random_uuid(),
    local_order_id    text not null,
    qr_id             text unique,
    amount_paise      integer not null,
    status            text not null default 'created',  -- created | paid | expired | failed
    payment_id        text,
    amount_paid_paise integer,
    close_by          timestamptz,
    created_at        timestamptz not null default now(),
    updated_at        timestamptz not null default now(),
    raw               jsonb
);

create index if not exists payment_orders_qr_id_idx on public.payment_orders (qr_id);
create index if not exists payment_orders_local_order_idx on public.payment_orders (local_order_id);

alter table public.payment_orders enable row level security;
-- (No policies on purpose — only the service role, used by the Edge Functions,
--  can touch this table.)
