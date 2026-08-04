-- Ensure agent logins are case-insensitive so credentials like "admin" and "Admin"
-- behave identically. This mirrors expectations in the README and seeded data.
drop function if exists public.login_agent(text, text);

create function public.login_agent(p_username text, p_password text)
returns json
language plpgsql
security definer
as $$
declare
  agent_record record;
begin
  select id, username, full_name, role
  into agent_record
  from public.agents
  where lower(username) = lower(trim(p_username))
    and password = p_password;

  if agent_record.id is null then
    return json_build_object('error', 'Invalid credentials');
  else
    return json_build_object(
      'success', true,
      'agent', json_build_object(
        'id', agent_record.id,
        'username', agent_record.username,
        'full_name', agent_record.full_name,
        'role', agent_record.role
      )
    );
  end if;
end;
$$;

grant execute on function public.login_agent to anon;
