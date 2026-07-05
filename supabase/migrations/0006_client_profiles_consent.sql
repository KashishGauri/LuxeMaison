-- Explicit per-client consent flags for what a sales associate may see.
--
-- Before this, preference / purchase-history visibility was inferred from the
-- free-text "status" and task rows (fragile string matching). These two columns
-- make each consent an explicit boolean; `marketingConsent` already exists.
--
-- Intentionally NULLABLE with no default: existing rows stay NULL so the app's
-- decoder falls back to the legacy status/task derivation (preserving their
-- current consent). The next profile save backfills the real boolean. A
-- DEFAULT false would have silently revoked consent for every existing client.

ALTER TABLE public.client_profiles
    ADD COLUMN IF NOT EXISTS "preferenceVisibilityConsent"      boolean,
    ADD COLUMN IF NOT EXISTS "purchaseHistoryVisibilityConsent" boolean;
