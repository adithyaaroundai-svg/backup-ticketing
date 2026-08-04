-- Add assignment_history and task tracking to tickets, plus RPC helpers

ALTER TABLE public.tickets
ADD COLUMN IF NOT EXISTS assignment_history jsonb NOT NULL DEFAULT '[]'::jsonb;

UPDATE public.tickets
SET assignment_history = '[]'::jsonb
WHERE assignment_history IS NULL;

ALTER TABLE public.tickets
  ALTER COLUMN assignment_history SET DEFAULT '[]'::jsonb;

ALTER TABLE public.tickets
  ALTER COLUMN assignment_history SET NOT NULL;

ALTER TABLE public.tickets
ADD COLUMN IF NOT EXISTS task_status text NOT NULL DEFAULT 'open';

ALTER TABLE public.tickets
ADD COLUMN IF NOT EXISTS completed_at timestamptz NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'tickets_task_status_check'
  ) THEN
    ALTER TABLE public.tickets
      ADD CONSTRAINT tickets_task_status_check
      CHECK (task_status IN ('open','in_progress','completed'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_tickets_task_status ON public.tickets(task_status);
CREATE INDEX IF NOT EXISTS idx_tickets_completed_at ON public.tickets(completed_at);
CREATE INDEX IF NOT EXISTS idx_tickets_assignment_history_gin
ON public.tickets USING gin (assignment_history);

CREATE OR REPLACE FUNCTION public.append_ticket_assignment(
  p_ticket_id uuid,
  p_to uuid,
  p_assigned_by uuid,
  p_note text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_from uuid;
  v_now timestamptz := now();
BEGIN
  SELECT assigned_to INTO v_from
  FROM public.tickets
  WHERE id = p_ticket_id
  FOR UPDATE;

  UPDATE public.tickets
  SET
    assignment_history = COALESCE(assignment_history, '[]'::jsonb) || jsonb_build_array(
      jsonb_build_object(
        'from', CASE WHEN v_from IS NULL THEN NULL ELSE v_from::text END,
        'to', p_to::text,
        'assigned_by', p_assigned_by::text,
        'assigned_at', v_now,
        'note', p_note,
        'completed', false
      )
    ),
    assigned_to = p_to,
    task_status = CASE
      WHEN task_status = 'completed' THEN 'completed'
      ELSE 'in_progress'
    END,
    updated_at = v_now
  WHERE id = p_ticket_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.complete_ticket(
  p_ticket_id uuid,
  p_completed_by uuid DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_now timestamptz := now();
  v_hist jsonb;
  v_len int;
BEGIN
  SELECT assignment_history INTO v_hist
  FROM public.tickets
  WHERE id = p_ticket_id
  FOR UPDATE;

  v_len := jsonb_array_length(v_hist);

  IF v_len > 0 THEN
    v_hist :=
      jsonb_set(
        v_hist,
        ARRAY[(v_len - 1)::text],
        (v_hist->(v_len - 1)) ||
          jsonb_build_object(
            'completed', true,
            'completed_at', v_now,
            'completed_by', CASE WHEN p_completed_by IS NULL THEN NULL ELSE p_completed_by::text END
          )
      );
  END IF;

  UPDATE public.tickets
  SET
    assignment_history = v_hist,
    task_status = 'completed',
    completed_at = v_now,
    updated_at = v_now
  WHERE id = p_ticket_id;
END;
$$;
