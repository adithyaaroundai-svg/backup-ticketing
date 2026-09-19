-- Secure ONE table: ticket_remarks

-- 1. ticket_remarks
ALTER TABLE public.ticket_remarks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access for MVP" ON public.ticket_remarks;
CREATE POLICY "Authenticated agents can manage ticket_remarks" ON public.ticket_remarks FOR ALL TO authenticated USING ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text) WITH CHECK ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text);
