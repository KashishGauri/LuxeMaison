-- Create SalesAssociateStockRequest table in public schema
CREATE TABLE IF NOT EXISTS public."SalesAssociateStockRequest" (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "productID" TEXT NOT NULL,
    "storeID" TEXT NOT NULL,
    "reportedBy" TEXT NOT NULL,
    quantity INTEGER NOT NULL,
    urgency TEXT NOT NULL, -- 'Normal' | 'Emergency'
    status TEXT NOT NULL DEFAULT 'pending',
    "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public."SalesAssociateStockRequest" ENABLE ROW LEVEL SECURITY;

-- Add new columns if they do not exist (defensive design)
ALTER TABLE public."SalesAssociateStockRequest" ADD COLUMN IF NOT EXISTS "productID" TEXT;
ALTER TABLE public."SalesAssociateStockRequest" ADD COLUMN IF NOT EXISTS "storeID" TEXT;
ALTER TABLE public."SalesAssociateStockRequest" ADD COLUMN IF NOT EXISTS "reportedBy" TEXT;
ALTER TABLE public."SalesAssociateStockRequest" ADD COLUMN IF NOT EXISTS quantity INTEGER;
ALTER TABLE public."SalesAssociateStockRequest" ADD COLUMN IF NOT EXISTS urgency TEXT;
ALTER TABLE public."SalesAssociateStockRequest" ADD COLUMN IF NOT EXISTS status TEXT;

-- Policies for public access (anon key usage)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'SalesAssociateStockRequest' AND policyname = 'Allow public select'
    ) THEN
        CREATE POLICY "Allow public select" ON public."SalesAssociateStockRequest" FOR SELECT USING (true);
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'SalesAssociateStockRequest' AND policyname = 'Allow public insert'
    ) THEN
        CREATE POLICY "Allow public insert" ON public."SalesAssociateStockRequest" FOR INSERT WITH CHECK (true);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'SalesAssociateStockRequest' AND policyname = 'Allow public update'
    ) THEN
        CREATE POLICY "Allow public update" ON public."SalesAssociateStockRequest" FOR UPDATE USING (true);
    END IF;
END
$$;
