-- Add FCM token column to agents
ALTER TABLE public.agents ADD COLUMN IF NOT EXISTS fcm_token text;

-- Create an RPC to easily update the FCM token for the currently authenticated agent
CREATE OR REPLACE FUNCTION update_agent_fcm_token(new_token text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Validate that the user is authenticated
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Update the token for the corresponding agent
  UPDATE public.agents
  SET fcm_token = new_token
  WHERE id = auth.uid();
END;
$$;
