-- Create policies to allow the newly authenticated Agent App to access MVP tables

-- 1. Customers
CREATE POLICY "Authenticated agents can manage customers"
ON public.customers
FOR ALL
TO authenticated
USING ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text)
WITH CHECK ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text);

-- 2. Ticket Comments
CREATE POLICY "Authenticated agents can manage ticket_comments"
ON public.ticket_comments
FOR ALL
TO authenticated
USING ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text)
WITH CHECK ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text);

-- 3. Service Reports
CREATE POLICY "Authenticated agents can manage service_reports"
ON public.service_reports
FOR ALL
TO authenticated
USING ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text)
WITH CHECK ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text);

-- 4. Audit Log
CREATE POLICY "Authenticated agents can manage audit_log"
ON public.audit_log
FOR ALL
TO authenticated
USING ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text)
WITH CHECK ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text);

-- 5. Agents
CREATE POLICY "Authenticated agents can manage agents"
ON public.agents
FOR ALL
TO authenticated
USING ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text)
WITH CHECK ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text);
