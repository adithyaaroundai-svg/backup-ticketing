-- Secure ONE table: aroundai_project_status

-- 1. aroundai_project_status
ALTER TABLE public.aroundai_project_status ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access for MVP" ON public.aroundai_project_status;
CREATE POLICY "Authenticated agents can manage aroundai_project_status" ON public.aroundai_project_status FOR ALL TO authenticated USING ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text) WITH CHECK ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text);
