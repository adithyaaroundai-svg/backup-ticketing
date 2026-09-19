-- Secure ONE table: canned_responses

-- 1. canned_responses
ALTER TABLE public.canned_responses ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access for MVP" ON public.canned_responses;
CREATE POLICY "Authenticated agents can manage canned_responses" ON public.canned_responses FOR ALL TO authenticated USING ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text) WITH CHECK ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text);
