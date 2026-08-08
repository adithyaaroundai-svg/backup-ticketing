CREATE TABLE public.call_history (
  id uuid NOT NULL DEFAULT gen_random_uuid(),

  caller_id uuid NOT NULL,
  receiver_id uuid NOT NULL,

  started_at timestamp with time zone NOT NULL DEFAULT now(),
  ended_at timestamp with time zone NULL,

  duration_seconds integer NULL,

  status text NOT NULL DEFAULT 'initiated',
  type text NOT NULL DEFAULT 'audio',
  direction text NOT NULL DEFAULT 'outgoing',

  created_at timestamp with time zone NOT NULL DEFAULT now(),

  CONSTRAINT call_history_pkey PRIMARY KEY (id),

  CONSTRAINT call_history_caller_id_fkey
    FOREIGN KEY (caller_id)
    REFERENCES public.agents(id)
    ON DELETE CASCADE,

  CONSTRAINT call_history_receiver_id_fkey
    FOREIGN KEY (receiver_id)
    REFERENCES public.agents(id)
    ON DELETE CASCADE,

  CONSTRAINT call_history_type_check
    CHECK (type IN ('audio', 'video')),

  CONSTRAINT call_history_direction_check
    CHECK (direction IN ('incoming', 'outgoing')),

  CONSTRAINT call_history_status_check
    CHECK (
      status IN (
        'initiated',
        'ringing',
        'answered',
        'missed',
        'rejected',
        'cancelled',
        'ended'
      )
    )
);

CREATE INDEX IF NOT EXISTS idx_call_history_caller_time
ON public.call_history (caller_id, started_at DESC);

CREATE INDEX IF NOT EXISTS idx_call_history_receiver_time
ON public.call_history (receiver_id, started_at DESC);

CREATE INDEX IF NOT EXISTS idx_call_history_time
ON public.call_history (started_at DESC);
