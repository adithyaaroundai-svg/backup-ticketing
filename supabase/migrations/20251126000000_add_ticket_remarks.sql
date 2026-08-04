-- Create ticket_remarks table for tracking comments/notes at different stages
CREATE TABLE IF NOT EXISTS ticket_remarks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id UUID NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
  agent_id UUID NOT NULL REFERENCES agents(id),
  remark TEXT NOT NULL,
  stage VARCHAR(50), -- e.g., 'New', 'In Progress', 'Resolved', etc.
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for faster queries
CREATE INDEX idx_ticket_remarks_ticket_id ON ticket_remarks(ticket_id);
CREATE INDEX idx_ticket_remarks_created_at ON ticket_remarks(created_at DESC);

-- Enable RLS
ALTER TABLE ticket_remarks ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Allow all authenticated users to read remarks
CREATE POLICY "Allow read access to all authenticated users" ON ticket_remarks
  FOR SELECT USING (true);

-- RLS Policy: Allow all authenticated users to insert remarks
CREATE POLICY "Allow insert access to all authenticated users" ON ticket_remarks
  FOR INSERT WITH CHECK (true);

-- Add some sample remarks for existing tickets
INSERT INTO ticket_remarks (ticket_id, agent_id, remark, stage)
SELECT 
  t.id,
  (SELECT id FROM agents WHERE role = 'Support' LIMIT 1),
  'Initial assessment completed. Issue identified.',
  'In Progress'
FROM tickets t
WHERE t.status = 'In Progress'
LIMIT 2;
