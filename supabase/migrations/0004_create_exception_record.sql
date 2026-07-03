-- Create ExceptionRecord table in public schema
CREATE TABLE IF NOT EXISTS public."ExceptionRecord" (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "productID" TEXT NOT NULL,
    "storeID" TEXT NOT NULL,
    "exceptionType" TEXT NOT NULL,
    "reportedBy" TEXT NOT NULL,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'pending',
    "expectedQuantity" INTEGER,
    "receivedQuantity" INTEGER,
    "varianceInQuantity" INTEGER,
    variant TEXT,
    photos TEXT[], -- array of photo paths
    "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public."ExceptionRecord" ENABLE ROW LEVEL SECURITY;

-- Add new columns if they do not exist (defensive design)
ALTER TABLE public."ExceptionRecord" ADD COLUMN IF NOT EXISTS "expectedQuantity" INTEGER;
ALTER TABLE public."ExceptionRecord" ADD COLUMN IF NOT EXISTS "receivedQuantity" INTEGER;
ALTER TABLE public."ExceptionRecord" ADD COLUMN IF NOT EXISTS "varianceInQuantity" INTEGER;
ALTER TABLE public."ExceptionRecord" ADD COLUMN IF NOT EXISTS "variant" TEXT;
ALTER TABLE public."ExceptionRecord" ADD COLUMN IF NOT EXISTS "photos" TEXT[];

-- Policies for public access (anon key usage)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'ExceptionRecord' AND policyname = 'Allow public select'
    ) THEN
        CREATE POLICY "Allow public select" ON public."ExceptionRecord" FOR SELECT USING (true);
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'ExceptionRecord' AND policyname = 'Allow public insert'
    ) THEN
        CREATE POLICY "Allow public insert" ON public."ExceptionRecord" FOR INSERT WITH CHECK (true);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'ExceptionRecord' AND policyname = 'Allow public update'
    ) THEN
        CREATE POLICY "Allow public update" ON public."ExceptionRecord" FOR UPDATE USING (true);
    END IF;
END
$$;
