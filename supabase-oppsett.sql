-- Tess Mobilservice: lagring for jobber, bestillinger og innstillinger.
-- Kjøres én gang i Supabase: SQL Editor -> New query -> lim inn alt -> Run.
-- Hver rad tilhører én innlogget bruker, og radnivå-sikkerhet (RLS) sørger for
-- at hver person bare kan lese og endre sine egne rader.

create table if not exists public.docs (
  user_id    uuid    not null default auth.uid() references auth.users (id) on delete cascade,
  id         text    not null,
  data       jsonb   not null,
  updated    bigint  not null default 0,
  deleted    boolean not null default false,
  primary key (user_id, id)
);

alter table public.docs enable row level security;

drop policy if exists "egne rader lese"   on public.docs;
drop policy if exists "egne rader legge"  on public.docs;
drop policy if exists "egne rader endre"  on public.docs;
drop policy if exists "egne rader slette" on public.docs;

create policy "egne rader lese"   on public.docs for select using (user_id = auth.uid());
create policy "egne rader legge"  on public.docs for insert with check (user_id = auth.uid());
create policy "egne rader endre"  on public.docs for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "egne rader slette" on public.docs for delete using (user_id = auth.uid());

grant select, insert, update, delete on public.docs to authenticated;
revoke all on public.docs from anon;
