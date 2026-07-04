-- Adds delivery-fulfilment fields to the receipt snapshot. When the client chose
-- "Deliver to Address", the app now stores the shipping address and a courier
-- tracking id on the receipt row (both stay NULL for boutique-pickup receipts).
-- Idempotent so it is safe to re-run.

ALTER TABLE public.receipt
    ADD COLUMN IF NOT EXISTS tracking_id      text,   -- courier tracking number (delivery only)
    ADD COLUMN IF NOT EXISTS delivery_address text;   -- shipping address printed on the receipt

-- Existing table grants (SELECT, INSERT to anon/authenticated) already cover the
-- new columns, so no extra GRANT is required.
