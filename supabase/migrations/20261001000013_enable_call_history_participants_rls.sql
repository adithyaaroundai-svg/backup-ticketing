-- Secure ONE table: call_history_participants

-- 1. call_history_participants
ALTER TABLE public.call_history_participants ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access for MVP" ON public.call_history_participants;
CREATE POLICY "Authenticated agents can manage call_history_participants" ON public.call_history_participants FOR ALL TO authenticated USING ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text) WITH CHECK ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text);
