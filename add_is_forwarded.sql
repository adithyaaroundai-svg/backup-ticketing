-- ============================================================
-- Add is_forwarded column to chat_messages
-- ============================================================

ALTER TABLE public.chat_messages
ADD COLUMN IF NOT EXISTS is_forwarded boolean DEFAULT false;
