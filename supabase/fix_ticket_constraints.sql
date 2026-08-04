-- Revised SQL Script to fix all ticket constraints
-- Run this in your Supabase SQL Editor.

-- 1. Drop existing constraints first
ALTER TABLE public.tickets DROP CONSTRAINT IF EXISTS tickets_priority_check;
ALTER TABLE public.tickets DROP CONSTRAINT IF EXISTS tickets_priority_check1;
ALTER TABLE public.tickets DROP CONSTRAINT IF EXISTS tickets_status_check;
ALTER TABLE public.tickets DROP CONSTRAINT IF EXISTS tickets_status_check1;

-- 2. Clean Priority Data BEFORE adding constraint
-- Map 'Normal' to 'Medium' and 'Critical' to 'Urgent'
UPDATE public.tickets SET priority = 'Medium' WHERE priority = 'Normal';
UPDATE public.tickets SET priority = 'Urgent' WHERE priority = 'Critical';

-- Safety: Convert any unrecognized priority to NULL (unassigned)
UPDATE public.tickets 
SET priority = NULL 
WHERE priority IS NOT NULL 
AND priority NOT IN ('Low', 'Medium', 'High', 'Urgent');

-- 3. Clean Status Data (In case of formatting issues)
-- Ensure 'BillRaised' and 'BillProcessed' are lowercase if needed, but our Dart models use these exact strings.
-- Just ensure existing rows won't break the new constraint.
UPDATE public.tickets SET status = 'In Progress' WHERE status = 'InProgress';

-- 4. Add Constraints back
ALTER TABLE public.tickets ADD CONSTRAINT tickets_priority_check 
CHECK (priority IN ('Low', 'Medium', 'High', 'Urgent'));

ALTER TABLE public.tickets ADD CONSTRAINT tickets_status_check 
CHECK (status IN (
  'New', 
  'Open', 
  'In Progress', 
  'On Hold',
  'Waiting for Customer', 
  'Resolved', 
  'Closed', 
  'Reopened',
  'BillRaised',
  'BillProcessed'
));

-- 5. Housekeeping
ALTER TABLE public.tickets ALTER COLUMN priority DROP DEFAULT;
