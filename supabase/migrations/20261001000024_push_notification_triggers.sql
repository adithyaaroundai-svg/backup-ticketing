-- 1. Ensure pg_net extension is enabled (required for making HTTP requests from Postgres)
CREATE EXTENSION IF NOT EXISTS pg_net;

-- 2. Create the trigger function that forwards the payload to the Edge Function
CREATE OR REPLACE FUNCTION public.trigger_send_fcm_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  -- Replace this with your actual Supabase project URL if needed.
  -- Alternatively, rely on the Supabase dashboard to set up Webhooks directly.
  edge_function_url text := 'https://ybmxpmsiihtasyjwxtol.supabase.co/functions/v1/send_fcm';
BEGIN
  -- We use net.http_post to asynchronously trigger the Edge function
  PERFORM net.http_post(
    url := edge_function_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json'
      -- Note: In a production environment, you should pass an Authorization header here.
      -- If the Edge Function requires JWT, pass 'Authorization', 'Bearer <ANON_OR_SERVICE_KEY>'
    ),
    body := jsonb_build_object(
      'type', 'INSERT',
      'table', TG_TABLE_NAME,
      'schema', TG_TABLE_SCHEMA,
      'record', row_to_json(NEW)
    )
  );

  RETURN NEW;
END;
$$;

-- 3. Attach the trigger to the notifications table
DROP TRIGGER IF EXISTS on_notification_created ON public.notifications;

CREATE TRIGGER on_notification_created
  AFTER INSERT ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_send_fcm_notification();
