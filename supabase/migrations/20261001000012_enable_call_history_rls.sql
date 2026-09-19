-- Secure ONE table: call_history

-- 1. call_history
ALTER TABLE public.call_history ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access for MVP" ON public.call_history;
CREATE POLICY "Authenticated agents can manage call_history" ON public.call_history FOR ALL TO authenticated USING ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text) WITH CHECK ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text);
