-- Fix 1 (2026-11-22): newer Supabase projects don't open new tables to the game automatically.
-- Run once in the SQL Editor if you ran setup.sql before this fix (setup.sql now includes it).
-- The row level security policies still decide which rows each player can see or change.
grant usage on schema public to anon, authenticated;
grant select on public.profiles to anon, authenticated;
grant select, insert, update, delete on public.submissions to authenticated;
