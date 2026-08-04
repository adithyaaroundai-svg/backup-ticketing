-- Add first_assigned_to to tickets to track the first handler of a ticket

ALTER TABLE public.tickets
ADD COLUMN IF NOT EXISTS first_assigned_to uuid REFERENCES public.agents(id);

UPDATE public.tickets
SET first_assigned_to = assigned_to
WHERE first_assigned_to IS NULL
  AND assigned_to IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_tickets_first_assigned_to
ON public.tickets(first_assigned_to);

-- Ensure first_assigned_to is set once, the first time assigned_to is populated
CREATE OR REPLACE FUNCTION public.set_first_assigned_to()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.first_assigned_to IS NULL
     AND NEW.assigned_to IS NOT NULL
     AND (TG_OP = 'INSERT' OR OLD.assigned_to IS DISTINCT FROM NEW.assigned_to)
  THEN
    NEW.first_assigned_to := NEW.assigned_to;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_set_first_assigned_to ON public.tickets;
CREATE TRIGGER trg_set_first_assigned_to
BEFORE INSERT OR UPDATE OF assigned_to
ON public.tickets
FOR EACH ROW
EXECUTE PROCEDURE public.set_first_assigned_to();
