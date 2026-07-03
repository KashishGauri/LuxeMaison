-- Migration file to create the AfterSaleRequest table and storage policies
-- for LuxeMaison after-sale support.

CREATE TABLE IF NOT EXISTS public."AfterSaleRequest" (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "receiptID" UUID NOT NULL REFERENCES public.receipt(receipt_id) ON DELETE CASCADE,
    "productID" UUID NOT NULL,                        -- Backing product UUID
    "requestType" TEXT NOT NULL,                      -- 'repair', 'service', 'exchange'
    status TEXT NOT NULL DEFAULT 'pending',
    notes TEXT,
    "imageUrl" TEXT,                                  -- Path of uploaded photo in bucket
    "reportedBy" UUID NOT NULL,
    "storeID" UUID NOT NULL,
    "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE public."AfterSaleRequest" ENABLE ROW LEVEL SECURITY;

-- Create Policies for Anonymous/Authenticated inserts and selects
CREATE POLICY "Allow public insert" ON public."AfterSaleRequest" FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public select" ON public."AfterSaleRequest" FOR SELECT USING (true);

-- Grant access on the new table
GRANT SELECT, INSERT ON public."AfterSaleRequest" TO anon, authenticated;

-- Create storage bucket "aftersaleproduct" if it does not exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('aftersaleproduct', 'aftersaleproduct', true)
ON CONFLICT (id) DO NOTHING;

-- Grant bucket storage insert and select policies to anon role
CREATE POLICY "Allow public upload" ON storage.objects FOR INSERT TO anon WITH CHECK (bucket_id = 'aftersaleproduct');
CREATE POLICY "Allow public select" ON storage.objects FOR SELECT TO anon USING (bucket_id = 'aftersaleproduct');
