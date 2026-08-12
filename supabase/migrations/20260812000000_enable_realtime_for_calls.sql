-- Add tables to the supabase_realtime publication
ALTER PUBLICATION supabase_realtime ADD TABLE call_history;
ALTER PUBLICATION supabase_realtime ADD TABLE call_history_participants;
