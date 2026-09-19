-- Secure ONE table: notifications

-- 1. notifications
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access for MVP" ON public.notifications;
CREATE POLICY "Authenticated agents can manage notifications" ON public.notifications FOR ALL TO authenticated USING ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text) WITH CHECK ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text);
