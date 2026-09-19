-- Secure ONE table: deals

-- 1. deals
ALTER TABLE public.deals ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access for MVP" ON public.deals;
CREATE POLICY "Authenticated agents can manage deals" ON public.deals FOR ALL TO authenticated USING ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text) WITH CHECK ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text);
