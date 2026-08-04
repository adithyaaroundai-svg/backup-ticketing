-- Create chat_messages table
CREATE TABLE IF NOT EXISTS public.chat_messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    sender_id TEXT NOT NULL,
    sender_name TEXT NOT NULL,
    sender_role TEXT NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    is_deleted BOOLEAN DEFAULT false NOT NULL
);

-- Enable Row Level Security
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

-- Policy: Everyone (authenticated) can view all messages
CREATE POLICY "Everyone can view chat messages" 
ON public.chat_messages FOR SELECT 
TO authenticated 
USING (true);

-- Policy: Authenticated users can insert messages
CREATE POLICY "Authenticated users can insert chat messages" 
ON public.chat_messages FOR INSERT 
TO authenticated 
WITH CHECK (true);

-- Policy: Users can update (soft delete) their own messages, or Admins/Support Head can delete any
CREATE POLICY "Users can update their own messages" 
ON public.chat_messages FOR UPDATE
TO authenticated
USING (
    sender_id = auth.uid()::text OR 
    EXISTS (
        SELECT 1 FROM public.agents 
        WHERE agents.id = auth.uid() 
        AND (agents.role = 'Admin' OR agents.role = 'Support Head')
    )
);

-- Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
