-- Clean up any residual ghost mention messages from chat_messages table
DELETE FROM public.chat_messages
WHERE content LIKE '%[MentionID:%'
   OR content ILIKE '%you were mentioned in the support chat%';

-- Function to prevent ghost mention messages from being inserted in the future
CREATE OR REPLACE FUNCTION public.prevent_ghost_mention_chat_messages()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.content LIKE '%[MentionID:%' OR NEW.content ILIKE '%you were mentioned in the support chat%' THEN
    -- Silently discard ghost mention messages sent by legacy clients
    RETURN NULL;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to intercept inserts on chat_messages
DROP TRIGGER IF EXISTS trg_prevent_ghost_mention_chat_messages ON public.chat_messages;
CREATE TRIGGER trg_prevent_ghost_mention_chat_messages
  BEFORE INSERT ON public.chat_messages
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_ghost_mention_chat_messages();

