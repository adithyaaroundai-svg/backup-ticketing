-- 1. Ensure pg_net extension is enabled (required for making HTTP requests from Postgres)
CREATE EXTENSION IF NOT EXISTS pg_net;

-- 2. Create the trigger function that forwards the payload to the Meta CAPI Edge Function
CREATE OR REPLACE FUNCTION public.notify_meta_capi()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  edge_function_url text := 'https://ybmxpmsiihtasyjwxtol.supabase.co/functions/v1/meta-capi';
  webhook_secret text := 'tallycare_capi_secret_2026';
  new_status text;
  old_status text;
  pipe_type text;
BEGIN
  new_status := lower(trim(coalesce(NEW.status, '')));
  old_status := lower(trim(coalesce(OLD.status, '')));
  pipe_type := lower(trim(coalesce(NEW.pipeline_type, '')));

  -- Only fire if the status has actually changed
  IF new_status = old_status THEN
    RETURN NEW;
  END IF;

  -- Only fire for Mobile App Sales channel
  -- and when status moves to Contacted, Qualified, Negotiation, or Won
  IF pipe_type = 'mobile-app-sales' 
     AND new_status IN ('contacted', 'qualified', 'negotiation', 'won', 'win') THEN

    PERFORM net.http_post(
      url := edge_function_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-webhook-secret', webhook_secret
      ),
      body := jsonb_build_object(
        'type', 'UPDATE',
        'table', TG_TABLE_NAME,
        'schema', TG_TABLE_SCHEMA,
        'record', to_jsonb(NEW),
        'old_record', to_jsonb(OLD)
      )
    );
  END IF;

  RETURN NEW;
END;
$$;

-- 3. Drop existing trigger if any and attach the trigger to public.leads table (UPDATE ONLY)
DROP TRIGGER IF EXISTS leads_meta_capi_trigger ON public.leads;

CREATE TRIGGER leads_meta_capi_trigger
  AFTER UPDATE OF status ON public.leads
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_meta_capi();
