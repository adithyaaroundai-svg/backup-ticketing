-- Secure chat_messages table with RLS

-- 1. Enable RLS
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

-- 2. Drop any existing insecure MVP policy (if it exists)
DROP POLICY IF EXISTS "Public access for MVP" ON public.chat_messages;
DROP POLICY IF EXISTS "Allow agents (anon) to manage chat_messages" ON public.chat_messages;

-- 3. Add Authenticated Agent Policy
CREATE POLICY "Authenticated agents can manage chat_messages"
ON public.chat_messages
FOR ALL
TO authenticated
USING ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text)
WITH CHECK ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text);
