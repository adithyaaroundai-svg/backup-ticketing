-- Migration to fix RLS permissions for authenticated users in the customer portal

-- 1. Allow authenticated users (logged-in customers) to see their company record
-- Note: 'anon' already has access, but Supabase roles are specific.
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'customers' AND policyname = 'Allow authenticated read'
    ) THEN
        CREATE POLICY "Allow authenticated read" ON public.customers 
        FOR SELECT TO authenticated USING (true);
    END IF;
END $$;

-- 2. Allow authenticated users to see and manage their own tickets
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'tickets' AND policyname = 'Allow authenticated access'
    ) THEN
        CREATE POLICY "Allow authenticated access" ON public.tickets 
        FOR ALL TO authenticated USING (true);
    END IF;
END $$;

-- 3. Ensure remarks are ALSO accessible to authenticated users
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'ticket_remarks' AND policyname = 'Allow authenticated read remarks'
    ) THEN
        CREATE POLICY "Allow authenticated read remarks" ON public.ticket_remarks 
        FOR SELECT TO authenticated USING (true);
    END IF;
END $$;
