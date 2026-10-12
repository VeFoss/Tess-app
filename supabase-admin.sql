-- Tess Mobilservice: brukerliste og administrator.
-- Kjøres én gang i Supabase: SQL Editor -> New query -> lim inn alt -> Run.
-- Kan kjøres på nytt uten å ødelegge noe.

-- 1. Brukerliste med navn og administrator-flagg
create table if not exists public.profiles (
  user_id  uuid primary key references auth.users (id) on delete cascade,
  email    text,
  name     text,
  is_admin boolean not null default false
);
alter table public.profiles enable row level security;

-- Er den innloggede brukeren administrator? (security definer: leser profiles uten å gå i ring med reglene)
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select is_admin from public.profiles where user_id = auth.uid()), false)
$$;
grant execute on function public.is_admin() to authenticated;

drop policy if exists "alle innloggede ser brukerlisten" on public.profiles;
drop policy if exists "egen profil legge" on public.profiles;
drop policy if exists "egen profil endre" on public.profiles;
drop policy if exists "admin endre profiler" on public.profiles;
create policy "alle innloggede ser brukerlisten" on public.profiles for select to authenticated using (true);
-- Hver bruker kan lage og endre sin egen rad, men ikke gjøre seg selv til administrator.
create policy "egen profil legge" on public.profiles for insert to authenticated
  with check (user_id = auth.uid() and is_admin = false);
create policy "egen profil endre" on public.profiles for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid() and is_admin = public.is_admin());
create policy "admin endre profiler" on public.profiles for update to authenticated
  using (public.is_admin()) with check (public.is_admin());
grant select, insert, update on public.profiles to authenticated;
revoke all on public.profiles from anon;

-- Nye brukere får en rad automatisk, så de kan få tildelt jobber med en gang.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (user_id, email) values (new.id, new.email) on conflict (user_id) do nothing;
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

-- Rader for brukere som finnes fra før
insert into public.profiles (user_id, email)
select id, email from auth.users
on conflict (user_id) do update set email = excluded.email;

-- 2. Administrator: Vebjørn (begge e-postadressene hans, den han logger inn med blir admin)
update public.profiles set is_admin = true
where lower(email) in ('vebjorn.fosse@gmail.com', 'vefo@tess.no');

-- 3. Administrator kan lese og endre alle jobber (i tillegg til at hver bruker har sine egne)
drop policy if exists "admin lese alt"   on public.docs;
drop policy if exists "admin legge alt"  on public.docs;
drop policy if exists "admin endre alt"  on public.docs;
drop policy if exists "admin slette alt" on public.docs;
create policy "admin lese alt"   on public.docs for select to authenticated using (public.is_admin());
create policy "admin legge alt"  on public.docs for insert to authenticated with check (public.is_admin());
create policy "admin endre alt"  on public.docs for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "admin slette alt" on public.docs for delete to authenticated using (public.is_admin());

-- Kontroll: viser brukerlisten. Den som skal være administrator skal ha is_admin = true.
select email, name, is_admin from public.profiles order by is_admin desc, email;
