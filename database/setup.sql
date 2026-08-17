-- Peer Review / Unterrichtsbeobachtung - Supabase schema
-- Run this ONCE in Supabase Dashboard -> SQL Editor.
-- Designed for:
--   * anonymous/public users: INSERT only
--   * authenticated administrators listed in public.admin_users: SELECT/INSERT/DELETE
-- No secret/service-role key is required by the browser application.

begin;

create extension if not exists pgcrypto;

create table if not exists public.observations (
  id uuid primary key default gen_random_uuid(),
  submitted_at timestamptz not null default now(),
  submission_uuid uuid not null unique,
  form_version text not null,
  peer_code text,
  observation_date date,
  phase text check (phase is null or phase in ('A','E')),
  grade_level text,
  subject text,
  payload jsonb not null,
  constraint observations_payload_object check (jsonb_typeof(payload) = 'object')
);

create index if not exists observations_submitted_at_idx on public.observations (submitted_at desc);
create index if not exists observations_observation_date_idx on public.observations (observation_date);
create index if not exists observations_phase_idx on public.observations (phase);
create index if not exists observations_grade_level_idx on public.observations (grade_level);
create index if not exists observations_subject_idx on public.observations (subject);

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.observations enable row level security;
alter table public.admin_users enable row level security;

-- Least-privilege table grants. RLS is still applied after these grants.
revoke all on table public.observations from anon, authenticated;
revoke all on table public.admin_users from anon, authenticated;
grant insert on table public.observations to anon, authenticated;
grant select, delete on table public.observations to authenticated;

-- Helper used by admin policies and by admin.html to verify that a logged-in user is authorized.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.admin_users a
    where a.user_id = (select auth.uid())
  );
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

-- Lightweight connectivity check used by the public form.
create or replace function public.can_submit_observation()
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$ select true; $$;

revoke all on function public.can_submit_observation() from public;
grant execute on function public.can_submit_observation() to anon, authenticated;

-- Recreate policies idempotently.
drop policy if exists observations_public_insert on public.observations;
create policy observations_public_insert
on public.observations
for insert
to anon, authenticated
with check (
  submission_uuid is not null
  and form_version = 'peer-review-kurz-v16-supabase-1'
  and jsonb_typeof(payload) = 'object'
  and coalesce(length(payload->>'id'),0) between 1 and 120
  and coalesce(length(grade_level),0) between 1 and 80
  and coalesce(length(subject),0) between 1 and 160
);

drop policy if exists observations_admin_select on public.observations;
create policy observations_admin_select
on public.observations
for select
to authenticated
using ((select public.is_admin()));

drop policy if exists observations_admin_delete on public.observations;
create policy observations_admin_delete
on public.observations
for delete
to authenticated
using ((select public.is_admin()));

-- Admin imports use the same INSERT policy; authenticated users can insert the same form version.
-- Legacy imports are performed by admin.html with form_version='legacy-import', so add a separate admin-only insert policy.
drop policy if exists observations_admin_legacy_insert on public.observations;
create policy observations_admin_legacy_insert
on public.observations
for insert
to authenticated
with check ((select public.is_admin()));

commit;
