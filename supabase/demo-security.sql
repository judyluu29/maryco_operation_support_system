-- Remove development-only anonymous access

drop policy if exists dev_anon_cases on public.cases;
drop policy if exists dev_anon_queries on public.queries;
drop policy if exists dev_anon_orders on public.orders;
drop policy if exists dev_anon_rules on public.notification_rules;
drop policy if exists dev_anon_log on public.email_log;


-- Only an it_admin account can manage dashboard account records.
-- The public it_team demo account can still use every normal dashboard feature.

create or replace function public.is_it_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.staff
    where id = (select auth.uid())
      and role = 'it_admin'
  );
$$;

revoke all on function public.is_it_admin() from public;
grant execute on function public.is_it_admin() to authenticated;

drop policy if exists staff_admin_manage on public.staff;

create policy staff_admin_manage
on public.staff
for all
to authenticated
using ((select public.is_it_admin()))
with check ((select public.is_it_admin()));
