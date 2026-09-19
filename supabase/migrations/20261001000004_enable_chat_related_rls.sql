-- Secure chat-related tables with RLS

-- 1. message_threads
ALTER TABLE public.message_threads ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access for MVP" ON public.message_threads;
CREATE POLICY "Authenticated agents can manage message_threads"
ON public.message_threads FOR ALL TO authenticated
USING ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text)
WITH CHECK ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text);

-- 2. chat_read_receipts
ALTER TABLE public.chat_read_receipts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access for MVP" ON public.chat_read_receipts;
CREATE POLICY "Authenticated agents can manage chat_read_receipts"
ON public.chat_read_receipts FOR ALL TO authenticated
USING ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text)
WITH CHECK ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text);

-- 3. starred_messages
ALTER TABLE public.starred_messages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access for MVP" ON public.starred_messages;
CREATE POLICY "Authenticated agents can manage starred_messages"
ON public.starred_messages FOR ALL TO authenticated
USING ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text)
WITH CHECK ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text);
