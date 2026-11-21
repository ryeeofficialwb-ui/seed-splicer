-- Fix 2 (2026-11-22): LIVE seeds. Run once in the SQL Editor (setup.sql now includes it).
--   public.official   one row: the official seed list the developer pushed (Push to players).
--                     Everyone can read it; only admins can write it.
--   pending_count()   how many submissions wait for review (admins only; 0 for everyone else).

create table if not exists public.official (
  id int primary key default 1 check (id = 1),
  version bigint not null default 0,
  data jsonb not null default '{}'::jsonb,
  published_at timestamptz not null default now(),
  published_by uuid references auth.users (id)
);
insert into public.official (id, version, data) values (1, 0, '{}'::jsonb) on conflict (id) do nothing;

alter table public.official enable row level security;
drop policy if exists "everyone reads the official list" on public.official;
create policy "everyone reads the official list" on public.official for select using (true);
drop policy if exists "only admins push" on public.official;
create policy "only admins push" on public.official for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

grant select on public.official to anon, authenticated;
grant update on public.official to authenticated;

create or replace function public.pending_count() returns integer
language sql stable security definer set search_path = public as $$
  select case when public.is_admin()
    then (select count(*)::int from public.submissions where status = 'pending') else 0 end
$$;
grant execute on function public.pending_count() to authenticated;

-- make the game's server see the new table right away
notify pgrst, 'reload schema';
