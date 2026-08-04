-- Add screenshot URL column to tickets
ALTER TABLE public.tickets
  ADD COLUMN IF NOT EXISTS screenshot_url text;

COMMENT ON COLUMN public.tickets.screenshot_url
  IS 'Public Supabase Storage URL for the optional customer-provided screenshot.';

-- Create ticket-screenshots storage bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'ticket-screenshots',
  'ticket-screenshots',
  true,
  5242880, -- 5 MB limit
  ARRAY['image/png', 'image/jpeg']
)
ON CONFLICT (id) DO UPDATE
SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Refresh policies for the ticket-screenshots bucket
DROP POLICY IF EXISTS "Allow authenticated users to upload ticket screenshots" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated users to read ticket screenshots" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated users to delete ticket screenshots" ON storage.objects;

CREATE POLICY "Allow authenticated users to upload ticket screenshots" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'ticket-screenshots'
  );

CREATE POLICY "Allow authenticated users to read ticket screenshots" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'ticket-screenshots'
  );

CREATE POLICY "Allow authenticated users to delete ticket screenshots" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'ticket-screenshots'
  );
