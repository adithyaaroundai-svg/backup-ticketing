-- Secure ONE table: tally_portal_sessions

-- 1. tally_portal_sessions
ALTER TABLE public.tally_portal_sessions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access for MVP" ON public.tally_portal_sessions;
CREATE POLICY "Authenticated agents can manage tally_portal_sessions" ON public.tally_portal_sessions FOR ALL TO authenticated USING ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text) WITH CHECK ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text);
