-- Migration: Create leave_requests table and security policies

CREATE TABLE IF NOT EXISTS public.leave_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL REFERENCES public.agents(id) ON DELETE CASCADE,
    agent_name TEXT NOT NULL,
    agent_role TEXT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    leave_type TEXT NOT NULL DEFAULT 'Casual',
    reason TEXT,
    status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'approved', 'rejected', 'cancelled'
    approved_by UUID REFERENCES public.agents(id) ON DELETE SET NULL,
    approved_by_name TEXT,
    approved_at TIMESTAMPTZ,
    rejection_reason TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Index for querying by agent and status
CREATE INDEX IF NOT EXISTS idx_leave_requests_agent_id ON public.leave_requests(agent_id);
CREATE INDEX IF NOT EXISTS idx_leave_requests_status ON public.leave_requests(status);
CREATE INDEX IF NOT EXISTS idx_leave_requests_dates ON public.leave_requests(start_date, end_date);

-- Enable Row Level Security
ALTER TABLE public.leave_requests ENABLE ROW LEVEL SECURITY;

-- Allow authenticated agents to view and manage leave requests
DROP POLICY IF EXISTS "Authenticated agents can manage leave_requests" ON public.leave_requests;
CREATE POLICY "Authenticated agents can manage leave_requests" 
ON public.leave_requests 
FOR ALL 
TO authenticated 
USING (true) 
WITH CHECK (true);

-- Also allow anon access if hybrid auth is used
DROP POLICY IF EXISTS "Anon agents can manage leave_requests" ON public.leave_requests;
CREATE POLICY "Anon agents can manage leave_requests" 
ON public.leave_requests 
FOR ALL 
TO anon 
USING (true) 
WITH CHECK (true);

-- Enable Supabase Realtime for leave_requests table
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'leave_requests'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.leave_requests;
    END IF;
END $$;
