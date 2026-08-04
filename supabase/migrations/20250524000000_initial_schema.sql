  -- Enable pgcrypto for UUIDs
  create extension if not exists "pgcrypto";

  -- Clean up existing tables (Cascade deletes dependent tables)
  drop table if exists public.audit_log;
  drop table if exists public.ticket_comments;
  drop table if exists public.tickets;
  drop table if exists public.agents;
  drop table if exists public.customers;

  -- 1. Customers Table (Stores API Keys and Tally Info)
  create table public.customers (
    id uuid primary key default gen_random_uuid(),
    company_name text not null,
    tally_license text,
    tally_serial_no text, -- Tally Serial Number for asset tracking
    api_key text not null unique, -- The secret key Tally sends in 'x-tally-api-key' header
    amc_expiry_date date, -- Annual Maintenance Contract expiry
    tss_expiry_date date, -- Tally Software Services expiry
    contact_person text,
    contact_phone text,
    contact_email text,
    created_at timestamptz default now()
  );

  -- 5. Agents Table (Custom Auth)
  create table public.agents (
    id uuid primary key default gen_random_uuid(),
    username text not null unique,
    password text not null, -- In real prod, store hash. For MVP, plain text or basic hash.
    full_name text,
    role text default 'Agent',
    created_at timestamptz default now()
  );

  -- 2. Tickets Table
  create table public.tickets (
    id uuid primary key default gen_random_uuid(),
    customer_id uuid references public.customers(id) on delete cascade,
    client_ticket_uuid text, -- Idempotency key
    created_by text not null, -- Username from Tally
    title text not null,
    description text,
    category text,
    priority text check (priority in ('Low', 'Normal', 'High', 'Critical')),
    status text check (status in ('New', 'Open', 'In Progress', 'Waiting for Customer', 'Resolved', 'Closed', 'Reopened')) default 'New',
    assigned_to uuid references public.agents(id), -- Changed from auth.users
    sla_due timestamptz,
    created_at timestamptz default now(),
    updated_at timestamptz default now()
  );

  create index idx_tickets_client_uuid on public.tickets(customer_id, client_ticket_uuid);

  -- 3. Comments Table
  create table public.ticket_comments (
    id uuid primary key default gen_random_uuid(),
    ticket_id uuid references public.tickets(id) on delete cascade,
    author text not null,
    body text not null,
    internal boolean default false,
    created_at timestamptz default now()
  );

  -- 4. Service Reports (Digital Job Cards)
  create table public.service_reports (
    id uuid primary key default gen_random_uuid(),
    ticket_id uuid references public.tickets(id) on delete cascade,
    agent_id uuid references public.agents(id),
    solution_provided text not null,
    time_spent_minutes integer,
    parts_used text,
    remarks text,
    customer_signature_url text, -- URL to signature image in Supabase Storage
    agent_signature_url text,
    created_at timestamptz default now(),
    updated_at timestamptz default now()
  );

  -- 5. Audit Log
  create table public.audit_log (
    id uuid primary key default gen_random_uuid(),
    ticket_id uuid references public.tickets(id) on delete set null,
    action text not null,
    payload jsonb,
    performed_by text,
    created_at timestamptz default now()
  );

  -- Enable RLS
  alter table public.customers enable row level security;
  alter table public.tickets enable row level security;
  alter table public.ticket_comments enable row level security;
  alter table public.service_reports enable row level security;
  alter table public.audit_log enable row level security;
  alter table public.agents enable row level security;

  -------------------------------------------------------------------------------
  -- HELPER: Identify Customer by API Key Header
  -------------------------------------------------------------------------------
  create or replace function public.get_customer_id_by_header()
  returns uuid
  language plpgsql
  security definer
  as $$
  declare
    req_key text;
    cust_id uuid;
  begin
    -- Get the header from the request (available in PostgREST context)
    -- Note: current_setting might throw if missing, so we handle exception or check nulls if needed.
    begin
      req_key := current_setting('request.headers', true)::json->>'x-tally-api-key';
    exception when others then
      return null;
    end;

    if req_key is null then
      return null;
    end if;

    select id into cust_id
    from public.customers
    where api_key = req_key;

    return cust_id;
  end;
  $$;

  -------------------------------------------------------------------------------
  -- RLS POLICIES
  -------------------------------------------------------------------------------

  -- 1. Agents -> FULL ACCESS (Custom Logic: Allow 'anon' access but restrict via App Logic / Custom Header if needed)
  -- For this Custom Auth MVP, we will allow 'anon' (the Flutter App) to read/write agents data.
  -- Ideally, we would sign a custom JWT, but for simplicity:
  create policy "Public access for MVP" on public.customers for all to anon using (true);
  create policy "Public access for MVP" on public.tickets for all to anon using (true);
  create policy "Public access for MVP" on public.ticket_comments for all to anon using (true);
  create policy "Public access for MVP" on public.service_reports for all to anon using (true);
  create policy "Public access for MVP" on public.audit_log for all to anon using (true);
  create policy "Public access for MVP" on public.agents for all to anon using (true);

  -- 2. Tally (Also Anon) -> Still restricted by the specific Policies?
  -- PostgREST policies are OR'd. If we give "Public access", Tally has it too.
  -- To keep Tally restricted, we might need to separate the roles, but since we are ditching Auth,
  -- 'anon' is the only role we have.
  -- We will rely on the App checking credentials.

  -------------------------------------------------------------------------------
  -- RPC: Custom Login
  -------------------------------------------------------------------------------
  create or replace function public.login_agent(p_username text, p_password text)
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
    where username = p_username and password = p_password; -- Plaintext for MVP

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

  -------------------------------------------------------------------------------
  -- RPC: Create Ticket (No Middleware)
  -------------------------------------------------------------------------------

  -- This function is called by Tally via POST /rest/v1/rpc/create_ticket
  create or replace function public.create_ticket(
    title text,
    description text,
    priority text,
    created_by text,
    client_ticket_uuid text,
    category text default null
  )
  returns json
  language plpgsql
  security definer -- Runs with admin privileges to bypass RLS for insertion
  as $$
  declare
    cust_id uuid;
    new_ticket_id uuid;
    existing_ticket_id uuid;
    existing_status text;
  begin
    -- 1. Identify Customer
    cust_id := public.get_customer_id_by_header();
    
    if cust_id is null then
      raise exception 'Unauthorized: Invalid or missing x-tally-api-key';
    end if;

    -- 2. Idempotency Check
    select id, status into existing_ticket_id, existing_status
    from public.tickets
    where customer_id = cust_id and tickets.client_ticket_uuid = create_ticket.client_ticket_uuid
    limit 1;

    if existing_ticket_id is not null then
      return json_build_object(
        'message', 'Ticket already exists',
        'ticket_id', existing_ticket_id,
        'status', existing_status
      );
    end if;

    -- 3. Insert Ticket
    insert into public.tickets (
      customer_id, client_ticket_uuid, created_by, title, description, category, priority
    ) values (
      cust_id, client_ticket_uuid, created_by, title, description, category, priority
    ) returning id into new_ticket_id;

    -- 4. Audit Log
    insert into public.audit_log (ticket_id, action, payload, performed_by)
    values (
      new_ticket_id, 
      'ticket_created', 
      json_build_object('title', title, 'priority', priority), 
      created_by
    );

    return json_build_object(
      'message', 'Ticket created successfully',
      'ticket_id', new_ticket_id,
      'status', 'New'
    );
  end;
  $$;

  -- Grant access to anon (so Tally can call it)
  grant execute on function public.create_ticket to anon;
