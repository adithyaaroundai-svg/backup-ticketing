-- Allow 'Paused', 'CallBack', and 'WontPay' statuses in tickets table check constraint
ALTER TABLE public.tickets DROP CONSTRAINT IF EXISTS tickets_status_check;
ALTER TABLE public.tickets DROP CONSTRAINT IF EXISTS tickets_status_check1;

ALTER TABLE public.tickets ADD CONSTRAINT tickets_status_check 
CHECK (status IN (
  'New', 
  'Open', 
  'In Progress', 
  'On Hold',
  'Paused',
  'CallBack',
  'Call Back',
  'WontPay',
  'Won''t Pay',
  'Waiting for Customer', 
  'Resolved', 
  'Closed', 
  'Cancelled',
  'Completed',
  'Reopened',
  'BillRaised',
  'BillProcessed'
));
