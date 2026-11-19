-- Ensure chat_messages can be read by anon role for Supabase Realtime publications.
-- This guarantees WebSocket broadcasts are never dropped by Postgres RLS if a client connects
-- before auth token resolution or during background session restores.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'chat_messages' AND policyname = 'Allow anon to select chat_messages'
    ) THEN
        CREATE POLICY "Allow anon to select chat_messages"
        ON public.chat_messages
        FOR SELECT
        TO anon
        USING (true);
    END IF;
END $$;

-- Ensure chat_read_receipts is in the realtime publication
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'chat_read_receipts'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_read_receipts;
    END IF;
END $$;

-- Ensure chat_read_receipts can be read by anon role as well
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'chat_read_receipts' AND policyname = 'Allow anon to select chat_read_receipts'
    ) THEN
        CREATE POLICY "Allow anon to select chat_read_receipts"
        ON public.chat_read_receipts
        FOR SELECT
        TO anon
        USING (true);
    END IF;
END $$;

