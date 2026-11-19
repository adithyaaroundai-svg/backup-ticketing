-- Migration: Schedule 5:00 PM Daily Deals Summary Push
-- Description: Simultaneously compiles and pushes deals logged today across ALL agents
-- to the #deal-register channel at 5:00 PM IST (11:30 UTC) every day via pg_cron.

CREATE OR REPLACE FUNCTION public.push_all_daily_deals_summary_5pm()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
SET TimeZone = 'UTC'
AS $$
DECLARE
  v_today_ist text := to_char(NOW() AT TIME ZONE 'Asia/Kolkata', 'YYYY-MM-DD');
  v_today_display text := to_char(NOW() AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY');
  v_today_start_utc timestamptz := ((NOW() AT TIME ZONE 'Asia/Kolkata')::date)::timestamp AT TIME ZONE 'Asia/Kolkata';
  v_channel_id text;
  v_agent record;
  v_deal record;
  v_count integer;
  v_summary text;
  v_idx integer;
  v_clean_follow_up text;
  v_pushed_agents text[] := ARRAY[]::text[];
  v_recipient_ids text[];
  v_recip_id text;
  v_anil_kumar_id text := '14db36db-0cb9-44ef-8032-d9610b3bc797';
  v_saved_recipients jsonb;
BEGIN
  -- 1. Resolve #deal-register channel ID
  SELECT id INTO v_channel_id 
  FROM public.custom_channels 
  WHERE name ILIKE 'deal%register' 
  ORDER BY created_at ASC 
  LIMIT 1;

  IF v_channel_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'deal-register channel not found',
      'date', v_today_ist,
      'pushed_count', 0
    );
  END IF;

  -- 2. Find every agent who created at least one deal today
  FOR v_agent IN
    SELECT DISTINCT a.id, a.full_name, a.role, a.avatar_url
    FROM public.deals d
    JOIN public.agents a ON a.id = d.created_by
    WHERE (d.date = v_today_ist OR d.created_at >= v_today_start_utc)
      AND a.role NOT IN ('Admin', 'Software Developer')
    ORDER BY a.full_name ASC
  LOOP
    -- 3. Check if today's summary for this agent has already been posted to deal-register
    IF EXISTS (
      SELECT 1 FROM public.chat_messages
      WHERE channel = v_channel_id
        AND sender_id = v_agent.id
        AND created_at >= v_today_start_utc
    ) THEN
      CONTINUE; -- Skip: already sent today
    END IF;

    -- 4. Count total deals for this agent today
    SELECT COUNT(*) INTO v_count
    FROM public.deals
    WHERE created_by = v_agent.id
      AND (date = v_today_ist OR created_at >= v_today_start_utc);

    IF v_count = 0 THEN
      CONTINUE;
    END IF;

    -- 5. Format Summary Markdown (matching app style without asterisks)
    v_summary := '👤 Agent: ' || COALESCE(v_agent.full_name, 'Agent') || ' (' || COALESCE(v_agent.role, 'Agent') || ')' || E'\n' ||
                 '📋 Daily Deals Summary — ' || v_today_display || E'\n' ||
                 '📦 Deals Logged Today: ' || v_count || E'\n\n';

    v_idx := 1;
    FOR v_deal IN
      SELECT name, company_name, phone_number, follow_up_date, remark
      FROM public.deals
      WHERE created_by = v_agent.id
        AND (date = v_today_ist OR created_at >= v_today_start_utc)
      ORDER BY created_at ASC
    LOOP
      v_summary := v_summary || v_idx || '. ' || COALESCE(v_deal.name, 'Untitled Deal') || E'\n';
      
      IF v_deal.company_name IS NOT NULL AND TRIM(v_deal.company_name) <> '' THEN
        v_summary := v_summary || '   • Company: ' || TRIM(v_deal.company_name) || E'\n';
      END IF;

      IF v_deal.phone_number IS NOT NULL AND TRIM(v_deal.phone_number) <> '' THEN
        v_summary := v_summary || '   • Contact: ' || TRIM(v_deal.phone_number) || E'\n';
      END IF;

      IF v_deal.follow_up_date IS NOT NULL AND TRIM(v_deal.follow_up_date) <> '' THEN
        BEGIN
          v_clean_follow_up := to_char(v_deal.follow_up_date::date, 'DD Mon YYYY');
        EXCEPTION WHEN OTHERS THEN
          v_clean_follow_up := SUBSTRING(v_deal.follow_up_date, 1, 10);
        END;
        v_summary := v_summary || '   • Follow Up: ' || v_clean_follow_up || E'\n';
      END IF;

      IF v_deal.remark IS NOT NULL AND TRIM(v_deal.remark) <> '' THEN
        v_summary := v_summary || '   • Remark: ' || TRIM(v_deal.remark) || E'\n';
      END IF;

      v_summary := v_summary || E'\n';
      v_idx := v_idx + 1;
    END LOOP;

    v_summary := TRIM(v_summary);

    -- 6. Determine target recipients:
    -- A) First check if the agent configured custom recipients in app_settings
    SELECT setting_value INTO v_saved_recipients
    FROM public.app_settings
    WHERE setting_key = 'deal_summary_recipients_' || v_agent.id;

    IF v_saved_recipients IS NOT NULL AND jsonb_typeof(v_saved_recipients) = 'array' AND jsonb_array_length(v_saved_recipients) > 0 THEN
      SELECT array_agg(value#>>'{}') INTO v_recipient_ids
      FROM jsonb_array_elements(v_saved_recipients);
    ELSE
      -- B) Default: Query enrolled members of deal-register channel excluding sender
      SELECT array_agg(user_id::text) INTO v_recipient_ids
      FROM public.channel_members
      WHERE channel_id = v_channel_id
        AND user_id <> v_agent.id;
    END IF;

    -- Ensure Anil Kumar is always included if no recipients returned
    IF v_recipient_ids IS NULL OR array_length(v_recipient_ids, 1) = 0 THEN
      v_recipient_ids := ARRAY[v_anil_kumar_id];
    END IF;

    -- 7. Insert message for each recipient in a single transaction
    FOREACH v_recip_id IN ARRAY v_recipient_ids
    LOOP
      INSERT INTO public.chat_messages (
        id,
        sender_id,
        receiver_id,
        sender_name,
        sender_role,
        sender_avatar_url,
        content,
        channel,
        created_at
      ) VALUES (
        gen_random_uuid(),
        v_agent.id,
        v_recip_id,
        v_agent.full_name,
        v_agent.role,
        v_agent.avatar_url,
        v_summary,
        v_channel_id,
        NOW()
      );
    END LOOP;

    v_pushed_agents := array_append(v_pushed_agents, COALESCE(v_agent.full_name, v_agent.id::text));
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'date', v_today_ist,
    'pushed_count', array_length(v_pushed_agents, 1),
    'pushed_agents', to_jsonb(v_pushed_agents)
  );
END;
$$;

-- Allow authenticated users and service_role to call this function
REVOKE ALL ON FUNCTION public.push_all_daily_deals_summary_5pm() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.push_all_daily_deals_summary_5pm() TO authenticated, service_role;

-- Schedule daily 5:00 PM IST (11:30 UTC) execution via pg_cron
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    IF EXISTS (
      SELECT 1 FROM cron.job WHERE jobname = 'push_daily_deals_summary_5pm'
    ) THEN
      PERFORM cron.unschedule('push_daily_deals_summary_5pm');
    END IF;

    PERFORM cron.schedule(
      'push_daily_deals_summary_5pm',
      '30 11 * * *',
      $cron$SELECT public.push_all_daily_deals_summary_5pm();$cron$
    );
  END IF;
END $$;
