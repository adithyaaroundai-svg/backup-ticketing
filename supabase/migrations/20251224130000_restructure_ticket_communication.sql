-- Migration: 20251224130000_restructure_ticket_communication.sql
-- Goal: Fix ticket_remarks schema, add voice support, and secure RLS policies.

-- 1. Fix ticket_remarks table
ALTER TABLE public.ticket_remarks ALTER COLUMN agent_id DROP NOT NULL;
ALTER TABLE public.ticket_remarks ALTER COLUMN remark DROP NOT NULL;
ALTER TABLE public.ticket_remarks ADD COLUMN IF NOT EXISTS customer_id UUID REFERENCES public.customers(id);
ALTER TABLE public.ticket_remarks ADD COLUMN IF NOT EXISTS remark_type TEXT DEFAULT 'text';
ALTER TABLE public.ticket_remarks ADD COLUMN IF NOT EXISTS voice_url TEXT;
ALTER TABLE public.ticket_remarks ADD COLUMN IF NOT EXISTS duration_seconds INTEGER;

-- 2. Secure ticket_remarks RLS
DROP POLICY IF EXISTS "Allow read access to all authenticated users" ON public.ticket_remarks;
DROP POLICY IF EXISTS "Allow insert access to all authenticated users" ON public.ticket_remarks;
DROP POLICY IF EXISTS "Allow authenticated read remarks" ON public.ticket_remarks;

-- Agents/Admins can do everything on remarks
CREATE POLICY "Agents can manage all remarks" ON public.ticket_remarks
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.agents WHERE id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM public.agents WHERE id = auth.uid()));

-- Customers can view remarks for their own tickets
CREATE POLICY "Customers can view their own ticket remarks" ON public.ticket_remarks
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.tickets t
      JOIN public.customers c ON t.customer_id = c.id
      WHERE t.id = ticket_remarks.ticket_id
      AND c.auth_user_id = auth.uid()
    )
  );

-- Customers can insert remarks for their own tickets
CREATE POLICY "Customers can insert their own ticket remarks" ON public.ticket_remarks
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.tickets t
      JOIN public.customers c ON t.customer_id = c.id
      WHERE t.id = ticket_id
      AND c.auth_user_id = auth.uid()
    )
  );

-- 3. Secure ticket_comments (Internal Only)
ALTER TABLE public.ticket_comments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access for MVP" ON public.ticket_comments;
DROP POLICY IF EXISTS "Allow authenticated access" ON public.ticket_comments; -- If it exists

-- Only agents can see/insert comments
CREATE POLICY "Agents can manage all comments" ON public.ticket_comments
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.agents WHERE id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM public.agents WHERE id = auth.uid()));

-- CUSTOMERS SHOULD HAVE NO POLICY FOR SELECT ON ticket_comments!
-- This effectively blocks them from reading internal comments.

-- 4. Secure customer_notes (Internal Only)
ALTER TABLE public.customer_notes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Agents can manage customer notes" ON public.customer_notes
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.agents WHERE id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM public.agents WHERE id = auth.uid()));

-- Again, no policy for customers.
