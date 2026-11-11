-- Automatically carry forward Today's Tasks (pending = 0) whose status is
-- still 'not_started' ("Yet to start") at end of day (00:00 IST / 18:30 UTC),
-- keeping their status as 'not_started' while moving task_date & display_date
-- to the new IST calendar date (preserving original created_at).

CREATE OR REPLACE FUNCTION aroundtally.auto_carry_forward_not_started()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = aroundtally, public
SET TimeZone = 'UTC'
AS $$
DECLARE
  v_today_ist text := to_char(NOW() AT TIME ZONE 'Asia/Kolkata', 'YYYY-MM-DD');
  v_updated integer := 0;
BEGIN
  UPDATE aroundtally.tasks
  SET task_date = v_today_ist,
      display_date = v_today_ist
  WHERE pending = 0
    AND status = 'not_started'
    AND (
      COALESCE(
        NULLIF(display_date, ''),
        to_char(created_at::timestamptz AT TIME ZONE 'Asia/Kolkata', 'YYYY-MM-DD'),
        NULLIF(task_date, '')
      ) < v_today_ist
      OR (
        NULLIF(display_date, '') = v_today_ist
        AND NULLIF(task_date, '') < v_today_ist
      )
    );

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  RETURN v_updated;
END;
$$;

REVOKE ALL ON FUNCTION aroundtally.auto_carry_forward_not_started() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION aroundtally.auto_carry_forward_not_started() TO authenticated, service_role;

-- Backfill any existing prior-day 'not_started' Today's Tasks immediately.
SELECT aroundtally.auto_carry_forward_not_started();

-- Schedule daily midnight IST (18:30 UTC) execution when pg_cron is enabled.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    IF EXISTS (
      SELECT 1 FROM cron.job WHERE jobname = 'aroundtally_auto_carry_forward_not_started'
    ) THEN
      PERFORM cron.unschedule('aroundtally_auto_carry_forward_not_started');
    END IF;

    PERFORM cron.schedule(
      'aroundtally_auto_carry_forward_not_started',
      '30 18 * * *',
      $cron$SELECT aroundtally.auto_carry_forward_not_started();$cron$
    );
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'Could not schedule pg_cron job aroundtally_auto_carry_forward_not_started: %', SQLERRM;
END
$$;

