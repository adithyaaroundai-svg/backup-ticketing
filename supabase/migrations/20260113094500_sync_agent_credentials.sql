-- Normalize agent usernames/passwords so they match the credentials documented in the app.
-- Run this in Supabase SQL Editor (or via `supabase db push`) after applying login RPC changes.

-- Ensure usernames are lowercase for consistent comparisons.
update public.agents
set username = lower(username)
where username <> lower(username);

-- Reset the demo credentials to their expected values.
update public.agents
set password = case username
  when 'admin' then 'admin123'
  when 'support' then 'supp123'
  when 'accountant' then 'acc123'
  when 'moderator' then 'mod123'
  when 'agent' then 'agent123'
  when 'sales' then 'sales123'
  else password
end
where username in (
  'admin',
  'support',
  'accountant',
  'moderator',
  'agent',
  'sales'
);
