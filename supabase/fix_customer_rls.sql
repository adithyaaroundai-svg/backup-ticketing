-- Fix Customer RLS and Linkage

-- 1. Link existing customers to auth users based on email
-- This fixes the immediate issue for existing users where auth_user_id might be NULL
UPDATE public.customers
SET auth_user_id = au.id
FROM auth.users au
WHERE public.customers.contact_email = au.email
  AND public.customers.auth_user_id IS NULL;

-- 2. Drop the overly strict update policy
DROP POLICY IF EXISTS "Customers can update their own record" ON public.customers;

-- 3. Create a more robust update policy
-- This allows updates if:
-- a) The auth_user_id matches the logged-in user (Standard case)
-- b) The auth_user_id is NULL BUT the contact_email matches the logged-in user's email (Fallback/Claiming case)
CREATE POLICY "Customers can update their own profile" ON public.customers
FOR UPDATE TO authenticated
USING (
  auth_user_id = auth.uid() OR
  (auth_user_id IS NULL AND contact_email = (auth.jwt() ->> 'email'))
)
WITH CHECK (
  auth_user_id = auth.uid() OR
  (auth_user_id IS NULL AND contact_email = (auth.jwt() ->> 'email'))
);

-- 4. Ensure Select policy is also robust (optional but good practice)
DROP POLICY IF EXISTS "Customers can view their own record" ON public.customers;

CREATE POLICY "Customers can view their own record" ON public.customers
FOR SELECT TO authenticated
USING (
  auth_user_id = auth.uid() OR
  contact_email = (auth.jwt() ->> 'email')
);
