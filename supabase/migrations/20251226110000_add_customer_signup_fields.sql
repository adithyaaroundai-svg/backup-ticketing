-- Migration: 20251226110000_add_customer_signup_fields.sql

-- 1. Add missing columns to customers table
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS accountant_name TEXT;
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS accountant_phone TEXT;
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS accountant_email TEXT;
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS tally_customizations JSONB;
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS secret_email TEXT;
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS auth_user_id UUID REFERENCES auth.users(id);
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS password TEXT; -- Redundant but requested

-- 2. Make api_key nullable to allow signup without immediate API key generation
ALTER TABLE public.customers ALTER COLUMN api_key DROP NOT NULL;

-- 3. Secure RLS policies
-- Ensure RLS is enabled
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;

-- Drop existing overlapping policies if any (from previous migrations)
DROP POLICY IF EXISTS "Customers can view their own profile" ON public.customers;
DROP POLICY IF EXISTS "Customers can update their own profile" ON public.customers;
DROP POLICY IF EXISTS "Allow customers to insert their own record" ON public.customers;
DROP POLICY IF EXISTS "Public access for MVP" ON public.customers;
DROP POLICY IF EXISTS "Allow authenticated read" ON public.customers;

-- Agents/Admins can see everything
CREATE POLICY "Agents can manage all customers" ON public.customers
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.agents WHERE id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM public.agents WHERE id = auth.uid()));

-- Customers can view their own record
CREATE POLICY "Customers can view their own record" ON public.customers
  FOR SELECT TO authenticated
  USING (auth_user_id = auth.uid());

-- Customers can update their own record
CREATE POLICY "Customers can update their own record" ON public.customers
  FOR UPDATE TO authenticated
  USING (auth_user_id = auth.uid())
  WITH CHECK (auth_user_id = auth.uid());

-- Allow insert during signup (user is already authenticated after auth.signUp)
CREATE POLICY "Allow authenticated insert" ON public.customers
  FOR INSERT TO authenticated
  WITH CHECK (auth_user_id = auth.uid());

-- Allow anon signup check
CREATE POLICY "Allow anon select for verification" ON public.customers
  FOR SELECT TO anon
  USING (true);
