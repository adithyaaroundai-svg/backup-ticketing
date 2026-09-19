-- Enable RLS for tickets table and configure hybrid authentication

-- 1. Create a generic agent user for Realtime and RLS access
DO $$
DECLARE
  v_user_id uuid := '00000000-0000-0000-0000-000000000001'::uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'agents@tallycare.local') THEN
    INSERT INTO auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, recovery_sent_at, last_sign_in_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token
    ) VALUES (
      '00000000-0000-0000-0000-000000000000', v_user_id, 'authenticated', 'authenticated', 'agents@tallycare.local', crypt('AgentShared#2026', gen_salt('bf')), now(), now(), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', ''
    );
    INSERT INTO auth.identities (
      id, provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at
    ) VALUES (
      uuid_generate_v4(), v_user_id::text, v_user_id, format('{"sub":"%s","email":"%s"}', v_user_id::text, 'agents@tallycare.local')::jsonb, 'email', now(), now(), now()
    );
  END IF;
END $$;


-- 2. Create Security Definer RPCs for Customer Portal
CREATE OR REPLACE FUNCTION public.get_portal_tickets(p_token text)
RETURNS SETOF public.tickets
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_customer_id uuid;
BEGIN
  -- Validate the session token and get the customer ID
  SELECT tally_registration_id INTO v_customer_id 
  FROM public.tally_portal_sessions 
  WHERE token_hash = encode(digest(p_token, 'sha256'), 'hex')
  AND expires_at > now();
  
  IF v_customer_id IS NULL THEN
    RAISE EXCEPTION 'Invalid or expired session token';
  END IF;
  
  -- Return only tickets belonging to this customer
  RETURN QUERY SELECT * FROM public.tickets WHERE customer_id = v_customer_id ORDER BY created_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.portal_update_ticket_status(p_token text, p_ticket_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_customer_id uuid;
BEGIN
  -- Validate the session token and get the customer ID
  SELECT tally_registration_id INTO v_customer_id 
  FROM public.tally_portal_sessions 
  WHERE token_hash = encode(digest(p_token, 'sha256'), 'hex')
  AND expires_at > now();
  
  IF v_customer_id IS NULL THEN
    RAISE EXCEPTION 'Invalid or expired session token';
  END IF;
  
  -- Ensure the ticket belongs to the customer before updating
  IF NOT EXISTS (SELECT 1 FROM public.tickets WHERE id = p_ticket_id AND customer_id = v_customer_id) THEN
    RAISE EXCEPTION 'Ticket not found or access denied';
  END IF;

  -- Update the ticket status
  UPDATE public.tickets 
  SET status = p_status, updated_at = now() 
  WHERE id = p_ticket_id;
END;
$$;


-- 3. Update RLS Policies on `tickets` table

-- Enable RLS (if not already enabled)
ALTER TABLE public.tickets ENABLE ROW LEVEL SECURITY;

-- Drop the insecure MVP policy if it exists
DROP POLICY IF EXISTS "Public access for MVP" ON public.tickets;

-- Create the new secure policy for authenticated agents
CREATE POLICY "Agents can access all tickets"
ON public.tickets
FOR ALL
TO authenticated
USING (
  (auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text
)
WITH CHECK (
  (auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text
);

-- Note: Customer portal accesses the table via Security Definer RPCs (get_portal_tickets, portal_update_ticket_status) 
-- and Vercel edge functions using the service_role key. Both methods bypass RLS, so no explicit policy is needed for customers.
