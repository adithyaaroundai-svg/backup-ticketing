-- Migration to add claimed_by column to leads table

ALTER TABLE public.leads 
ADD COLUMN IF NOT EXISTS claimed_by TEXT;

-- (Optional) If you want to track which agent claimed it by their ID instead of name,
-- you can use UUID, but the Dart code currently sends and expects a String name.
-- e.g. updateLeadDetails(leadId, {'claimed_by': currentUserName})
