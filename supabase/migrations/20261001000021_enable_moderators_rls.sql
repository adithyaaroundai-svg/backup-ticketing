-- Secure ONE table: moderators

-- 1. moderators
ALTER TABLE public.moderators ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access for MVP" ON public.moderators;
CREATE POLICY "Authenticated agents can manage moderators" ON public.moderators FOR ALL TO authenticated USING ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text) WITH CHECK ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text);
