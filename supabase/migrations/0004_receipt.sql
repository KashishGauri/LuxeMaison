-- Receipt table: a post-payment tax-invoice snapshot written once per completed
-- sale (at finalize, when the receipt is shown). One row per sale, linked to the
-- Sales row via "saleID". Amounts are in rupees; "time" is the transaction
-- time-of-day (matches SalesItem.time).
--
-- The app writes with the anon key (no user session), so RLS is left disabled and
-- INSERT/SELECT are granted to anon/authenticated — mirroring Sales / SalesItem.

CREATE TABLE IF NOT EXISTS public.receipt (
    receipt_id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    "saleID"            uuid,                     -- FK-ish link to public."Sales"(id)
    "invoiceNumber"     text,                     -- e.g. LM/26-27/01234
    "salesAssociateID"  uuid,                     -- User.id who closed the sale
    "storeID"           uuid,                     -- boutique the sale was rung against
    "paymentMethod"     text,                     -- UPI QR / Card / Cash / Split ...
    "paymentReference"  text,                     -- gateway/tender ref (e.g. Razorpay payment id)
    "preTaxAmount"      numeric,                  -- taxable value (rupees)
    "taxAmount"         numeric,                  -- total GST (rupees)
    "totalAmount"       numeric,                  -- grand total incl. GST (rupees)
    "amountPaid"        numeric,                  -- amount actually collected (rupees)
    "Currency"          text DEFAULT 'INR',
    "itemCount"         integer,                  -- number of units on the invoice
    "receiptDate"       date,                     -- transaction date (yyyy-MM-dd)
    "time"              time,                     -- transaction time-of-day (HH:mm:ss)
    "createdAt"         timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS receipt_sale_id_idx ON public.receipt ("saleID");
CREATE INDEX IF NOT EXISTS receipt_associate_id_idx ON public.receipt ("salesAssociateID");

GRANT SELECT, INSERT ON public.receipt TO anon, authenticated;
