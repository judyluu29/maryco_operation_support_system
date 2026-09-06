-- ============================================================
-- G'dAI — Mary's House Services
-- Phase 1: database schema (Supabase / Postgres)
-- Paste the whole file into the Supabase SQL Editor and run once.
-- Safe to re-run during development.
-- ============================================================

-- ---------- extensions ----------
create extension if not exists pgcrypto;   -- gen_random_uuid()

-- ---------- enums ----------
do $$ begin
  create type case_priority as enum ('low','medium','high','critical');
exception when duplicate_object then null; end $$;

do $$ begin
  create type case_category as enum ('password','hardware','software','network','security','phone');
exception when duplicate_object then null; end $$;

do $$ begin
  create type case_status as enum ('open','in-progress','resolved');
exception when duplicate_object then null; end $$;

do $$ begin
  create type order_status as enum ('pending','approved','ordered','delivered');
exception when duplicate_object then null; end $$;

do $$ begin
  create type staff_role as enum ('it_admin','it_team','staff');
exception when duplicate_object then null; end $$;

-- ---------- case ref counter (MC-1001, MC-1002, ...) ----------
create sequence if not exists case_ref_seq start with 1001;

-- ============================================================
-- STAFF  (links Supabase Auth users to a role)
-- ============================================================
create table if not exists public.staff (
  id          uuid primary key references auth.users(id) on delete cascade,
  full_name   text,
  email       text,
  role        staff_role not null default 'staff',
  created_at  timestamptz not null default now()
);

-- Helper used by every RLS policy. security definer so it can read
-- public.staff without tripping over staff's own RLS.
create or replace function public.is_it_team()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.staff
    where id = auth.uid() and role in ('it_admin','it_team')
  );
$$;

-- ============================================================
-- CASES  (IT support tickets)
-- ============================================================
create table if not exists public.cases (
  id          uuid primary key default gen_random_uuid(),
  ref         text not null unique default 'MC-' || nextval('case_ref_seq')::text,
  summary     text not null,
  detail      text,
  tried       text,
  required    text,
  priority    case_priority not null default 'low',
  category    case_category not null,
  status      case_status   not null default 'open',
  site        text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  resolved_at timestamptz
);

-- keep updated_at current + stamp/clear resolved_at on status change
create or replace function public.cases_before_update()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  if new.status = 'resolved' and old.status <> 'resolved' then
    new.resolved_at := now();
  elsif new.status <> 'resolved' then
    new.resolved_at := null;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_cases_before_update on public.cases;
create trigger trg_cases_before_update
  before update on public.cases
  for each row execute function public.cases_before_update();

-- ============================================================
-- QUERIES  (self-resolved chats — never became a ticket)
-- ============================================================
create table if not exists public.queries (
  id          uuid primary key default gen_random_uuid(),
  message     text,
  summary     text,
  category    case_category,          -- nullable: auto-detect may miss
  created_at  timestamptz not null default now()
);

-- ============================================================
-- ORDERS  (supply requests: pending -> approved -> ordered -> delivered)
-- ============================================================
create table if not exists public.orders (
  id           uuid primary key default gen_random_uuid(),
  item         text not null,
  site         text,
  status       order_status not null default 'pending',
  requested_by text,
  approved_by  text,
  approved_at  timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_orders_updated on public.orders;
create trigger trg_orders_updated
  before update on public.orders
  for each row execute function public.set_updated_at();

-- ============================================================
-- NOTIFICATION_RULES  (one row per priority — the dashboard toggles)
-- ============================================================
create table if not exists public.notification_rules (
  priority       case_priority primary key,
  email_enabled  boolean not null default true,
  teams_enabled  boolean not null default true,
  recipients     text[]  not null default '{}'
);

-- seed the four priorities (idempotent)
insert into public.notification_rules (priority, email_enabled, teams_enabled)
values ('critical',true,true),
       ('high',    true,true),
       ('medium',  true,true),
       ('low',     true,true)
on conflict (priority) do nothing;

-- ============================================================
-- EMAIL_LOG  (record of every notification attempt)
-- ============================================================
create table if not exists public.email_log (
  id           uuid primary key default gen_random_uuid(),
  case_id      uuid references public.cases(id) on delete set null,
  case_ref     text,
  priority     case_priority,
  email_status text,          -- 'sent' | 'failed' | null
  teams_status text,
  suppressed   boolean not null default false,   -- true = rule turned it off
  created_at   timestamptz not null default now()
);

-- ============================================================
-- INDEXES
-- ============================================================
create index if not exists idx_cases_status    on public.cases(status);
create index if not exists idx_cases_priority   on public.cases(priority);
create index if not exists idx_cases_created    on public.cases(created_at desc);
create index if not exists idx_cases_category   on public.cases(category);
create index if not exists idx_cases_open_age   on public.cases(created_at) where status <> 'resolved';
create index if not exists idx_orders_status    on public.orders(status);
create index if not exists idx_queries_created  on public.queries(created_at desc);
create index if not exists idx_queries_category on public.queries(category);
create index if not exists idx_email_log_case   on public.email_log(case_id);

-- ============================================================
-- ROW LEVEL SECURITY
-- Model: the chatbot writes via an Edge Function using the
-- service_role key, which BYPASSES RLS. So these policies only
-- need to govern authenticated IT staff using the dashboard.
-- Anonymous browser clients get nothing.
-- ============================================================
alter table public.staff              enable row level security;
alter table public.cases              enable row level security;
alter table public.queries            enable row level security;
alter table public.orders             enable row level security;
alter table public.notification_rules enable row level security;
alter table public.email_log          enable row level security;

-- staff: you can read your own row; IT team can read/manage all
drop policy if exists staff_read_self on public.staff;
create policy staff_read_self on public.staff
  for select to authenticated
  using (id = auth.uid() or public.is_it_team());

drop policy if exists staff_admin_manage on public.staff;
create policy staff_admin_manage on public.staff
  for all to authenticated
  using (public.is_it_team())
  with check (public.is_it_team());

-- cases: IT team full access (insert allowed for manual dashboard tickets)
drop policy if exists cases_it_all on public.cases;
create policy cases_it_all on public.cases
  for all to authenticated
  using (public.is_it_team())
  with check (public.is_it_team());

-- queries / orders / notification_rules / email_log: IT team full access
drop policy if exists queries_it_all on public.queries;
create policy queries_it_all on public.queries
  for all to authenticated using (public.is_it_team()) with check (public.is_it_team());

drop policy if exists orders_it_all on public.orders;
create policy orders_it_all on public.orders
  for all to authenticated using (public.is_it_team()) with check (public.is_it_team());

drop policy if exists rules_it_all on public.notification_rules;
create policy rules_it_all on public.notification_rules
  for all to authenticated using (public.is_it_team()) with check (public.is_it_team());

drop policy if exists emaillog_it_all on public.email_log;
create policy emaillog_it_all on public.email_log
  for all to authenticated using (public.is_it_team()) with check (public.is_it_team());

-- ============================================================
-- REALTIME  (dashboard subscribes instead of polling)
-- ============================================================
do $$ begin
  alter publication supabase_realtime add table public.cases;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.orders;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.queries;
exception when duplicate_object then null; end $$;

-- ============================================================
-- DONE. Next: promote yourself to IT admin after you sign up —
--   update public.staff set role = 'it_admin' where email = 'you@...';
-- ============================================================
