-- Secure ONE table: history

-- 1. history
ALTER TABLE public.history ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access for MVP" ON public.history;
CREATE POLICY "Authenticated agents can manage history" ON public.history FOR ALL TO authenticated USING ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text) WITH CHECK ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text);
