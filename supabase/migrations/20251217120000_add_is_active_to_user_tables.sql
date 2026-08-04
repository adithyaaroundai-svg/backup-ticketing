-- Add is_active column to user tables (agents, moderators, accountants)
-- This column is needed for user management functionality

-- Add is_active column to agents table
alter table public.agents add column if not exists is_active boolean default true;

-- Create moderators table if it doesn't exist (for user management)
create table if not exists public.moderators (
    id uuid primary key default gen_random_uuid(),
    username text not null unique,
    password text not null, -- In real prod, store hash. For MVP, plain text or basic hash.
    full_name text,
    role text default 'Moderator',
    is_active boolean default true,
    created_at timestamptz default now()
);

-- Create accountants table if it doesn't exist (for user management)
create table if not exists public.accountants (
    id uuid primary key default gen_random_uuid(),
    username text not null unique,
    password text not null, -- In real prod, store hash. For MVP, plain text or basic hash.
    full_name text,
    role text default 'Accountant',
    is_active boolean default true,
    created_at timestamptz default now()
);

-- Enable RLS for new user tables
alter table public.moderators enable row level security;
alter table public.accountants enable row level security;
