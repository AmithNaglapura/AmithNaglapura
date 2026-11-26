-- Portfolio backend for amithnaglapura.github.io
-- Run this once in Supabase: Dashboard → SQL Editor → New query → paste → Run.
-- Security model: the public site can only INSERT (write-only). Nobody can read,
-- change or delete rows except the signed-in owner, amithnaglapura@gmail.com.
-- This is enforced by Postgres Row Level Security on Supabase's servers, so it
-- holds even if someone reads the site's JavaScript.

-- ---------- Messages from the contact form ----------
create table if not exists public.messages (
  id          bigint generated always as identity primary key,
  created_at  timestamptz not null default now(),
  name        text not null check (char_length(name) between 1 and 120),
  email       text not null check (char_length(email) between 3 and 200 and email ~* '^[^@\s]+@[^@\s]+\.[^@\s]{2,}$'),
  company     text check (char_length(company) <= 160),
  topic       text not null default 'Other' check (char_length(topic) <= 80),
  body        text not null check (char_length(body) between 1 and 5000),
  page        text check (char_length(page) <= 200),
  read        boolean not null default false
);

-- ---------- Anonymous page views ----------
create table if not exists public.visits (
  id          bigint generated always as identity primary key,
  created_at  timestamptz not null default now(),
  session_id  text not null check (char_length(session_id) between 1 and 64),
  path        text not null check (char_length(path) <= 200),
  referrer    text check (char_length(referrer) <= 300),
  device      text check (char_length(device) <= 20),
  browser     text check (char_length(browser) <= 40),
  os          text check (char_length(os) <= 40),
  lang        text check (char_length(lang) <= 20),
  tz          text check (char_length(tz) <= 64),
  screen      text check (char_length(screen) <= 20)
);
create index if not exists visits_created_at_idx on public.visits (created_at desc);
create index if not exists messages_created_at_idx on public.messages (created_at desc);

-- ---------- Row Level Security ----------
alter table public.messages enable row level security;
alter table public.visits   enable row level security;

-- Owner check used by every read/update/delete policy
create or replace function public.is_owner() returns boolean
language sql stable as $$
  select coalesce(auth.jwt() ->> 'email', '') = 'amithnaglapura@gmail.com'
     and coalesce((auth.jwt() ->> 'email_verified')::boolean, true)
$$;

-- Public: write-only. New messages must arrive unread.
drop policy if exists "public can send messages" on public.messages;
create policy "public can send messages" on public.messages
  for insert to anon, authenticated with check (read = false);

drop policy if exists "public can log visits" on public.visits;
create policy "public can log visits" on public.visits
  for insert to anon, authenticated with check (true);

-- Owner only: read, mark read, delete.
drop policy if exists "owner reads messages" on public.messages;
create policy "owner reads messages" on public.messages for select to authenticated using (public.is_owner());
drop policy if exists "owner updates messages" on public.messages;
create policy "owner updates messages" on public.messages for update to authenticated using (public.is_owner()) with check (public.is_owner());
drop policy if exists "owner deletes messages" on public.messages;
create policy "owner deletes messages" on public.messages for delete to authenticated using (public.is_owner());

drop policy if exists "owner reads visits" on public.visits;
create policy "owner reads visits" on public.visits for select to authenticated using (public.is_owner());
drop policy if exists "owner deletes visits" on public.visits;
create policy "owner deletes visits" on public.visits for delete to authenticated using (public.is_owner());

-- Tighten table privileges: anon may only insert.
revoke all on public.messages, public.visits from anon;
grant insert on public.messages, public.visits to anon;
grant select, insert, update, delete on public.messages to authenticated;
grant select, insert, delete on public.visits to authenticated;

-- ---------- Flood protection ----------
-- Rejects bursts: more than 30 messages or 600 visits per 10 minutes site-wide.
create or replace function public.flood_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare n int; lim int;
begin
  lim := case tg_table_name when 'messages' then 30 else 600 end;
  execute format('select count(*) from public.%I where created_at > now() - interval ''10 minutes''', tg_table_name) into n;
  if n >= lim then raise exception 'rate limit'; end if;
  return new;
end $$;

drop trigger if exists messages_flood on public.messages;
create trigger messages_flood before insert on public.messages for each row execute function public.flood_guard();
drop trigger if exists visits_flood on public.visits;
create trigger visits_flood before insert on public.visits for each row execute function public.flood_guard();

-- ---------- Housekeeping: keep 13 months of visits ----------
-- Optional: enable the pg_cron extension (Database → Extensions) and run:
-- select cron.schedule('trim-visits', '0 3 * * *', $$delete from public.visits where created_at < now() - interval '13 months'$$);
