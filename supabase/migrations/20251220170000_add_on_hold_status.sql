-- Add 'On Hold' to the allowed status values for tickets
ALTER TABLE public.tickets DROP CONSTRAINT IF EXISTS tickets_status_check;
ALTER TABLE public.tickets ADD CONSTRAINT tickets_status_check 
  CHECK (status IN ('New', 'Open', 'In Progress', 'Waiting for Customer', 'Resolved', 'Closed', 'Reopened', 'BillRaised', 'BillProcessed', 'On Hold'));
