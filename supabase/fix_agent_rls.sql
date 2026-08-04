-- Fix Agent RLS and Linkage to allow Customer Updates

-- 1. Add auth_user_id to agents if not exists (to link with specific auth user)
ALTER TABLE public.agents ADD COLUMN IF NOT EXISTS auth_user_id UUID REFERENCES auth.users(id);

-- 2. Link existing agents to auth users based on email/username
-- Assuming 'username' in agents table stores the email
UPDATE public.agents
SET auth_user_id = au.id
FROM auth.users au
WHERE public.agents.username = au.email
  AND public.agents.auth_user_id IS NULL;

-- 3. Allow Authenticated users (Agents) to read the agents table
-- This is critical for the "EXISTS (SELECT 1 FROM agents ...)" check to work!
DROP POLICY IF EXISTS "Allow authenticated read" ON public.agents;
CREATE POLICY "Allow authenticated read" ON public.agents
  FOR SELECT TO authenticated
  USING (true);

-- 4. Update the "Agents can manage all customers" policy to be more robust
-- It now checks if the user exists in agents table via ID match OR auth_user_id match
DROP POLICY IF EXISTS "Agents can manage all customers" ON public.customers;

CREATE POLICY "Agents can manage all customers" ON public.customers
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.agents 
      WHERE id = auth.uid() 
         OR auth_user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.agents 
      WHERE id = auth.uid() 
         OR auth_user_id = auth.uid()
    )
  );
