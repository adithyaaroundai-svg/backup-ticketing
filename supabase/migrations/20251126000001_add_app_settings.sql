-- Create app_settings table for feature toggles
CREATE TABLE IF NOT EXISTS app_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  setting_key VARCHAR(100) UNIQUE NOT NULL,
  setting_value JSONB NOT NULL,
  description TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  updated_by UUID REFERENCES agents(id)
);

-- Enable RLS
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Allow all authenticated users to read settings
CREATE POLICY "Allow read access to all authenticated users" ON app_settings
  FOR SELECT USING (true);

-- RLS Policy: Only admins can insert/update settings
CREATE POLICY "Allow admin to insert settings" ON app_settings
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM agents
      WHERE agents.id = auth.uid()
      AND agents.role = 'Admin'
    )
  );

CREATE POLICY "Allow admin to update settings" ON app_settings
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM agents
      WHERE agents.id = auth.uid()
      AND agents.role = 'Admin'
    )
  );

-- Insert default settings
INSERT INTO app_settings (setting_key, setting_value, description) VALUES
  ('enable_chat', '{"enabled": true}'::jsonb, 'Enable/disable chat functionality'),
  ('enable_billing', '{"enabled": true}'::jsonb, 'Enable/disable billing features'),
  ('enable_ticket_creation', '{"enabled": true}'::jsonb, 'Enable/disable ticket creation'),
  ('enable_reports', '{"enabled": true}'::jsonb, 'Enable/disable reports access'),
  ('enable_notifications', '{"enabled": true}'::jsonb, 'Enable/disable notifications')
ON CONFLICT (setting_key) DO NOTHING;
