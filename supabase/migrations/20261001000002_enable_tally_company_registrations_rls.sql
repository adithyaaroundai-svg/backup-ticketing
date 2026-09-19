-- Secure tally_company_registrations with RLS and an RPC

-- 1. Create a Security Definer RPC for the Customer Portal's restore session
CREATE OR REPLACE FUNCTION public.portal_restore_session(p_registration_id uuid)
RETURNS public.tally_company_registrations
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_registration public.tally_company_registrations;
BEGIN
  -- Fetch the registration record
  SELECT * INTO v_registration 
  FROM public.tally_company_registrations 
  WHERE id = p_registration_id;

  -- If it doesn't exist, return null
  IF v_registration IS NULL THEN
    RETURN NULL;
  END IF;

  -- Update the last_connected_at timestamp
  UPDATE public.tally_company_registrations 
  SET last_connected_at = now() 
  WHERE id = p_registration_id;

  -- Return the updated record
  RETURN v_registration;
END;
$$;

-- 2. Enable RLS
ALTER TABLE public.tally_company_registrations ENABLE ROW LEVEL SECURITY;

-- 3. Add Authenticated Agent Policy
CREATE POLICY "Authenticated agents can manage tally_company_registrations"
ON public.tally_company_registrations
FOR ALL
TO authenticated
USING ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text)
WITH CHECK ((auth.jwt() ->> 'email'::text) = 'agents@tallycare.local'::text);
