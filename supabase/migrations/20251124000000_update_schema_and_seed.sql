-- 1. Update Ticket Status Constraint to include 'BillRaised' and 'BillProcessed'
ALTER TABLE public.tickets DROP CONSTRAINT tickets_status_check;
ALTER TABLE public.tickets ADD CONSTRAINT tickets_status_check 
  CHECK (status IN ('New', 'Open', 'In Progress', 'Waiting for Customer', 'Resolved', 'Closed', 'Reopened', 'BillRaised', 'BillProcessed'));

-- 2. Seed Agents (Password is plaintext for MVP as per schema comment)
DELETE FROM public.agents WHERE username IN ('admin', 'moderator', 'accountant', 'support');

INSERT INTO public.agents (username, password, full_name, role) VALUES
('admin', 'admin123', 'Admin User', 'Admin'),
('moderator', 'mod123', 'Moderator User', 'Moderator'),
('accountant', 'acc123', 'Accountant User', 'Accountant'),
('support', 'supp123', 'Support User', 'Support');

-- 3. Seed Customers
INSERT INTO public.customers (company_name, api_key, contact_person) VALUES
('Acme Corp', 'acme-api-key', 'John Doe'),
('Globex Inc', 'globex-api-key', 'Jane Smith')
ON CONFLICT (api_key) DO NOTHING;

-- 4. Seed Tickets
DO $$
DECLARE
  cust_acme uuid;
  cust_globex uuid;
  agent_support uuid;
BEGIN
  SELECT id INTO cust_acme FROM public.customers WHERE company_name = 'Acme Corp' LIMIT 1;
  SELECT id INTO cust_globex FROM public.customers WHERE company_name = 'Globex Inc' LIMIT 1;
  SELECT id INTO agent_support FROM public.agents WHERE username = 'support' LIMIT 1;

  -- Unassigned Tickets
  INSERT INTO public.tickets (customer_id, title, description, priority, status, created_by) VALUES
  (cust_acme, 'Login failing', 'Cannot login to the dashboard.', 'High', 'New', 'John Doe'),
  (cust_globex, 'Printer not working', 'Tally printer config issue.', 'Normal', 'Open', 'Jane Smith'),
  (cust_acme, 'Feature request: Dark mode', 'Please add dark mode.', 'Low', 'New', 'John Doe');

  -- Assigned to Support (In Progress)
  INSERT INTO public.tickets (customer_id, title, description, priority, status, created_by, assigned_to) VALUES
  (cust_globex, 'Data sync error', 'Sync failing with error 500.', 'Critical', 'In Progress', 'Jane Smith', agent_support);

  -- Resolved / Bill Raised
  INSERT INTO public.tickets (customer_id, title, description, priority, status, created_by, assigned_to) VALUES
  (cust_acme, 'License expired', 'Renewed license.', 'High', 'BillRaised', 'John Doe', agent_support);

END $$;
