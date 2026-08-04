-- Insert test customers with AMC/TSS data
insert into public.customers (
  company_name, 
  tally_license, 
  tally_serial_no,
  api_key,
  amc_expiry_date,
  tss_expiry_date,
  contact_person,
  contact_phone,
  contact_email
)
values (
  'Test Company Ltd', 
  '123456789', 
  'TALLY-SN-001-2024',
  'TEST_API_KEY_001',
  '2025-12-31', -- AMC Active
  '2025-06-30', -- TSS Active
  'Rajesh Kumar',
  '+91-9876543210',
  'rajesh@testcompany.com'
) on conflict (api_key) do nothing;

-- Insert customer with expired AMC (for testing Revenue Radar)
insert into public.customers (
  company_name, 
  tally_license, 
  tally_serial_no,
  api_key,
  amc_expiry_date,
  tss_expiry_date,
  contact_person,
  contact_phone,
  contact_email
)
values (
  'Expired AMC Corp', 
  '987654321', 
  'TALLY-SN-002-2023',
  'TEST_API_KEY_002',
  '2024-01-15', -- AMC Expired
  '2024-01-15', -- TSS Expired
  'Priya Sharma',
  '+91-9123456789',
  'priya@expiredamc.com'
) on conflict (api_key) do nothing;

-- Insert a test Admin agent
insert into public.agents (username, password, full_name, role)
values (
  'admin', 
  'admin123', 
  'System Admin', 
  'Admin'
) on conflict (username) do nothing;

-- Insert a test User agent
insert into public.agents (username, password, full_name, role)
values (
  'agent', 
  'agent123', 
  'Support User', 
  'Agent'
) on conflict (username) do nothing;
