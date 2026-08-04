-- 1. Canned Responses
create table if not exists public.canned_responses (
  id uuid default gen_random_uuid() primary key,
  title text not null,
  content text not null,
  category text,
  created_by uuid references public.agents(id),
  created_at timestamptz default now()
);

-- No RLS needed since we're using custom auth

-- 2. Notifications
create table if not exists public.notifications (
  id uuid default gen_random_uuid() primary key,
  user_id uuid not null references public.agents(id),
  type text not null, -- 'assignment', 'comment', 'sla', 'system'
  title text not null,
  message text,
  link text,
  is_read boolean default false,
  created_at timestamptz default now()
);

-- No RLS needed since we're using custom auth

-- Notification Function and Trigger for Ticket Assignment
create or replace function public.handle_ticket_assignment()
returns trigger as $$
begin
  if (new.assigned_to is not null and (old.assigned_to is null or old.assigned_to != new.assigned_to)) then
    insert into public.notifications (user_id, type, title, message, link)
    values (
      new.assigned_to,
      'assignment',
      'New Ticket Assigned',
      'You have been assigned ticket #' || new.id,
      '/ticket/' || new.id
    );
  end if;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_ticket_assigned on public.tickets;
create trigger on_ticket_assigned
  after update on public.tickets
  for each row
  execute procedure public.handle_ticket_assignment();

-- 3. Knowledge Base (Articles)
create table if not exists public.articles (
  id uuid default gen_random_uuid() primary key,
  title text not null,
  content text not null,
  tags text[],
  created_by uuid references public.agents(id),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- No RLS needed since we're using custom auth

-- 4. Deals / Pipeline
create table if not exists public.deals (
  id uuid default gen_random_uuid() primary key,
  customer_id uuid references public.customers(id) not null,
  title text not null,
  stage text not null check (stage in ('new', 'qualified', 'proposal', 'negotiation', 'won', 'lost')),
  value numeric default 0,
  description text,
  assigned_to uuid references public.agents(id),
  expected_close_date date,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- No RLS needed since we're using custom auth
