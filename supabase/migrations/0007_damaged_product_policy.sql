-- Storage policies for the "Damaged Product" bucket.
-- Allows authenticated and anonymous roles to upload and select objects.

INSERT INTO storage.buckets (id, name, public)
VALUES ('Damaged Product', 'Damaged Product', true)
ON CONFLICT (id) DO NOTHING;

DO $$
BEGIN
    -- INSERT policy
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'objects' AND schemaname = 'storage' AND policyname = 'Allow upload to Damaged Product'
    ) THEN
        CREATE POLICY "Allow upload to Damaged Product" ON storage.objects 
        FOR INSERT 
        TO anon, authenticated 
        WITH CHECK (bucket_id = 'Damaged Product');
    END IF;

    -- SELECT policy
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'objects' AND schemaname = 'storage' AND policyname = 'Allow select from Damaged Product'
    ) THEN
        CREATE POLICY "Allow select from Damaged Product" ON storage.objects 
        FOR SELECT 
        TO anon, authenticated 
        USING (bucket_id = 'Damaged Product');
    END IF;
END
$$;
