-- Add tickets and ticket_comments to the supabase_realtime publication
-- This allows clients to listen to changes on these tables in real-time.
ALTER PUBLICATION supabase_realtime ADD TABLE public.tickets;
ALTER PUBLICATION supabase_realtime ADD TABLE public.ticket_comments;
