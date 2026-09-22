CREATE OR REPLACE FUNCTION public.set_agent_fcm_token(p_agent_id uuid, p_token text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.agents
  SET fcm_token = p_token
  WHERE id = p_agent_id;
END;
$$;
