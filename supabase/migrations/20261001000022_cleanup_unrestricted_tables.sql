-- 1. agents
ALTER TABLE public.agents ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access for MVP" ON public.agents;
DROP POLICY IF EXISTS "Authenticated agents can manage agents" ON public.agents;
CREATE POLICY "Authenticated agents can manage agents" ON public.agents FOR ALL TO authenticated USING ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text) WITH CHECK ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text);

-- 2. audit_log
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access for MVP" ON public.audit_log;
DROP POLICY IF EXISTS "Authenticated agents can manage audit_log" ON public.audit_log;
CREATE POLICY "Authenticated agents can manage audit_log" ON public.audit_log FOR ALL TO authenticated USING ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text) WITH CHECK ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text);

-- 3. history
ALTER TABLE public.history ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access for MVP" ON public.history;
DROP POLICY IF EXISTS "Authenticated agents can manage history" ON public.history;
CREATE POLICY "Authenticated agents can manage history" ON public.history FOR ALL TO authenticated USING ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text) WITH CHECK ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text);

-- 4. service_reports
ALTER TABLE public.service_reports ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access for MVP" ON public.service_reports;
DROP POLICY IF EXISTS "Authenticated agents can manage service_reports" ON public.service_reports;
CREATE POLICY "Authenticated agents can manage service_reports" ON public.service_reports FOR ALL TO authenticated USING ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text) WITH CHECK ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text);
