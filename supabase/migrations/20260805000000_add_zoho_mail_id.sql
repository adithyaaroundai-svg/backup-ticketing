-- Add zoho_mail_id column to agents table
ALTER TABLE public.agents
ADD COLUMN IF NOT EXISTS zoho_mail_id text;

-- Create an index to ensure fast lookups by email if needed
CREATE UNIQUE INDEX IF NOT EXISTS agents_zoho_mail_id_unique_idx
ON public.agents (zoho_mail_id)
WHERE zoho_mail_id IS NOT NULL;
