-- Create voice_notes storage bucket for voice note files
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'voice_notes',
  'voice_notes',
  true,
  10485760, -- 10MB limit
  ARRAY['audio/webm', 'audio/opus', 'audio/ogg', 'audio/m4a', 'audio/mp4', 'audio/mpeg', 'audio/wav']
) ON CONFLICT (id) DO NOTHING;

-- Create policies for voice_notes bucket
-- Allow authenticated users to upload voice notes
CREATE POLICY "Allow authenticated users to upload voice notes" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'voice_notes' AND
    auth.role() = 'authenticated'
  );

-- Allow authenticated users to read voice notes
CREATE POLICY "Allow authenticated users to read voice notes" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'voice_notes' AND
    auth.role() = 'authenticated'
  );

-- Allow agents to update voice notes (if needed)
CREATE POLICY "Allow agents to update voice notes" ON storage.objects
  FOR UPDATE TO authenticated
  WITH CHECK (
    bucket_id = 'voice_notes' AND
    EXISTS (SELECT 1 FROM agents WHERE id = auth.uid())
  );

-- Allow agents to delete voice notes (if needed)
CREATE POLICY "Allow agents to delete voice notes" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'voice_notes' AND
    EXISTS (SELECT 1 FROM agents WHERE id = auth.uid())
  );
