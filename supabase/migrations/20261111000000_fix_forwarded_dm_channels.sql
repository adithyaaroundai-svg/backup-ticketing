-- Normalize legacy forwarded DM messages that were stored with a composite
-- channel ('dm_<uid1>_<uid2>') instead of the canonical 'dm' channel.
UPDATE public.chat_messages
SET channel = 'dm'
WHERE receiver_id IS NOT NULL
  AND channel LIKE 'dm\_%' ESCAPE '\';

