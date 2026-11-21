-- Seed Splicer online: accounts (username + password), seed submissions, the developer's review.
-- Run ONCE in your Supabase project: Dashboard > SQL Editor > New query > paste all of this > Run.
-- Running it again is safe (it only creates what's missing and replaces the functions/policies).
--
-- How it fits together
--   * A player signs up in the game with a username + password. Supabase Auth keeps the password
--     (hashed); the game never stores it. The username lives in public.profiles.
--     Usernames: 3-20 letters, digits or _, unique ignoring case AND look-alikes ("B0b" = "Bob").
--     RyeeRue / KeepUpp / KeepUp and anything that looks like them are reserved.
--   * A logged-in player uploads seeds: one row in public.submissions per seed, status 'pending'.
--     The row's payload is a small Seed Splicer list (the seed, the seeds it's made from, their
--     recipes and block art) that the developer's game can import.
--   * Only admins (the developer) can see everyone's submissions and set approved / denied.
--     Players see only their own. All of this is enforced HERE (row level security), not in the
--     game, so a modified game can't get around it.
--
-- Becoming the admin (once): run   insert into public.reserved_allow values ('RyeeRue');
-- then sign up as RyeeRue in your Developer game. The sign-up uses the allowance (it's deleted)
-- and makes that account an admin.

-- --- usernames ----------------------------------------------------------------------------------

-- The look-alike key: lowercase letters only, look-alike digits/symbols read as letters, repeats
-- collapsed. Same as the game's DevMode.normalize: "Ry33_Rue" -> "ryerue", "KEEP-UPP" -> "kepup".
create or replace function public.name_key(n text) returns text
language sql immutable as $$
  select regexp_replace(
    regexp_replace(translate(lower(coalesce(n, '')), '01!|34@5$789', 'oiiieaasstbg'), '[^a-z]', '', 'g'),
    '(.)\1+', '\1', 'g')
$$;

create or replace function public.is_reserved(n text) returns boolean
language sql immutable as $$
  select public.name_key(n) like '%ryeru%' or public.name_key(n) like '%kepup%'
$$;

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text not null unique check (username ~ '^[A-Za-z0-9_]{3,20}$'),
  name_key text generated always as (public.name_key(username)) stored unique,
  created_at timestamptz not null default now()
);

create table if not exists public.admins (
  user_id uuid primary key references auth.users (id) on delete cascade
);

-- One-time permission to sign up with a reserved name (only you can add rows: no policies).
create table if not exists public.reserved_allow (
  username text primary key
);

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins where user_id = auth.uid())
$$;

-- The game asks before signing up, so it can say what's wrong: 'ok', 'invalid' or 'taken'.
create or replace function public.username_status(u text) returns text
language sql stable security definer set search_path = public as $$
  select case
    when u is null or u !~ '^[A-Za-z0-9_]{3,20}$' then 'invalid'
    when exists (select 1 from public.profiles p where p.name_key = public.name_key(u)) then 'taken'
    when public.is_reserved(u) and not exists (select 1 from public.reserved_allow r where lower(r.username) = lower(u)) then 'taken'
    else 'ok'
  end
$$;

-- Every new account gets its profile from the username the game sent (raw_user_meta_data).
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  u text := coalesce(new.raw_user_meta_data ->> 'username', '');
  allowed boolean;
begin
  if u !~ '^[A-Za-z0-9_]{3,20}$' then
    raise exception 'USERNAME_INVALID';
  end if;
  allowed := exists (select 1 from public.reserved_allow r where lower(r.username) = lower(u));
  if public.is_reserved(u) and not allowed then
    raise exception 'USERNAME_TAKEN';
  end if;
  insert into public.profiles (id, username) values (new.id, u);
  if allowed then
    delete from public.reserved_allow where lower(username) = lower(u);
    insert into public.admins (user_id) values (new.id) on conflict do nothing;
  end if;
  return new;
end
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- --- submissions ----------------------------------------------------------------------------------

create table if not exists public.submissions (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  seed_name text not null check (char_length(seed_name) between 1 and 60),
  payload jsonb not null check (pg_column_size(payload) < 400000),
  status text not null default 'pending' check (status in ('pending', 'approved', 'denied')),
  note text check (char_length(note) <= 300),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users (id)
);
create index if not exists submissions_status on public.submissions (status, created_at);
create index if not exists submissions_user on public.submissions (user_id, created_at);

-- No flooding: at most 100 pending submissions per player, and one per seed name.
create or replace function public.check_submission() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from public.submissions where user_id = new.user_id and status = 'pending') >= 100 then
    raise exception 'TOO_MANY_PENDING';
  end if;
  if exists (select 1 from public.submissions where user_id = new.user_id and status = 'pending'
             and lower(seed_name) = lower(new.seed_name)) then
    raise exception 'ALREADY_PENDING';
  end if;
  return new;
end
$$;

drop trigger if exists submissions_check on public.submissions;
create trigger submissions_check before insert on public.submissions
  for each row execute function public.check_submission();

-- --- who may do what (row level security) ----------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.admins enable row level security;
alter table public.reserved_allow enable row level security;
alter table public.submissions enable row level security;

drop policy if exists "usernames are public" on public.profiles;
create policy "usernames are public" on public.profiles for select using (true);

drop policy if exists "players add their own, pending" on public.submissions;
create policy "players add their own, pending" on public.submissions for insert to authenticated
  with check (user_id = auth.uid() and status = 'pending' and reviewed_at is null and reviewed_by is null);

drop policy if exists "players see their own, admins see all" on public.submissions;
create policy "players see their own, admins see all" on public.submissions for select to authenticated
  using (user_id = auth.uid() or public.is_admin());

drop policy if exists "only admins review" on public.submissions;
create policy "only admins review" on public.submissions for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

drop policy if exists "players withdraw their pending" on public.submissions;
create policy "players withdraw their pending" on public.submissions for delete to authenticated
  using (user_id = auth.uid() and status = 'pending');

grant execute on function public.username_status(text) to anon, authenticated;
grant execute on function public.is_admin() to authenticated;

-- --- the live official list (Push to players) ----------------------------------------------------

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

-- Newer Supabase projects don't open new tables to the game automatically: say which ones it may
-- use (the policies above still decide which ROWS). admins / reserved_allow stay closed.
grant usage on schema public to anon, authenticated;
grant select on public.profiles to anon, authenticated;
grant select, insert, update, delete on public.submissions to authenticated;
