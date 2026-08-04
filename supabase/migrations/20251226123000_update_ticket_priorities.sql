-- Migration: 20251226123000_update_ticket_priorities.sql
-- Description: Update ticket priorities check constraint and remove default values.

-- 1. Drop the old check constraint
ALTER TABLE public.tickets DROP CONSTRAINT IF EXISTS tickets_priority_check;

-- 2. Add the new check constraint with 'Medium' and 'Urgent' instead of 'Normal' and 'Critical'
-- Also we allow NULL for "unassigned" state.
ALTER TABLE public.tickets ADD CONSTRAINT tickets_priority_check 
CHECK (priority IN ('Low', 'Medium', 'High', 'Urgent'));

-- 3. Update any existing 'Normal' to 'Medium' and 'Critical' to 'Urgent' to maintain data integrity
UPDATE public.tickets SET priority = 'Medium' WHERE priority = 'Normal';
UPDATE public.tickets SET priority = 'Urgent' WHERE priority = 'Critical';

-- 4. Ensure no default priority is set by the database (though it wasn't explicitly set in initial schema)
ALTER TABLE public.tickets ALTER COLUMN priority DROP DEFAULT;
