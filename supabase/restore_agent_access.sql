-- Fix Agent App Access (Restore MVP "Anon" Access)

-- The Agent App uses a custom login system (RPC) that does NOT create a Supabase Auth session.
-- This means Agents access the database as 'anon' (anonymous users).
-- The security policies I added previously restricted updates to 'authenticated' users only, blocking Agents.
-- This script explicitly allows 'anon' users (Methods used by Analyst/Agent app) to update customers again.

-- 1. Restore Update Permission for Anon (Agent App) on Customers
DROP POLICY IF EXISTS "Allow agents (anon) to update customers" ON public.customers;

CREATE POLICY "Allow agents (anon) to update customers" ON public.customers
FOR UPDATE TO anon
USING (true)
WITH CHECK (true);

-- 2. Restore Select Permission for Anon (Agent App) on Customers
-- (Already mostly covered, but ensuring full access for agents)
DROP POLICY IF EXISTS "Allow agents (anon) to select customers" ON public.customers;

CREATE POLICY "Allow agents (anon) to select customers" ON public.customers
FOR SELECT TO anon
USING (true);

-- 3. Restore Insert Permission for Anon (Agent App) on Customers
DROP POLICY IF EXISTS "Allow agents (anon) to insert customers" ON public.customers;

CREATE POLICY "Allow agents (anon) to insert customers" ON public.customers
FOR INSERT TO anon
WITH CHECK (true);

-- NOTE: The 'authenticated' policies for the Customer Portal (My Profile) remain in place.
-- This creates a specific exception for the unauthenticated Agent App connection.
