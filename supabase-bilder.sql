-- Tess Mobilservice: lagring av bilder på jobber og slanger.
-- Kjøres én gang i Supabase: SQL Editor -> New query -> lim inn alt -> Run.
-- Kan kjøres på nytt uten å ødelegge noe.

-- 1. Privat lagringsplass «photos» (maks 5 MB per bilde, bare bildeformater)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('photos', 'photos', false, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

-- 2. Hvem kan bruke bildene til en jobb: den jobben tilhører (egen eller tildelt), og administrator.
--    Bildene ligger i mappen <jobb-id>/, så tilgangen følger jobben også når den tildeles noen andre.
create or replace function public.can_use_job(job_id text) returns boolean
language sql stable security definer set search_path = public as $$
  select public.is_admin()
      or exists (select 1 from public.docs d where d.id = job_id and d.user_id = auth.uid() and not d.deleted)
$$;
grant execute on function public.can_use_job(text) to authenticated;

drop policy if exists "bilder lese"   on storage.objects;
drop policy if exists "bilder legge"  on storage.objects;
drop policy if exists "bilder endre"  on storage.objects;
drop policy if exists "bilder slette" on storage.objects;
create policy "bilder lese"   on storage.objects for select to authenticated
  using (bucket_id = 'photos' and public.can_use_job((storage.foldername(name))[1]));
create policy "bilder legge"  on storage.objects for insert to authenticated
  with check (bucket_id = 'photos' and public.can_use_job((storage.foldername(name))[1]));
create policy "bilder endre"  on storage.objects for update to authenticated
  using (bucket_id = 'photos' and public.can_use_job((storage.foldername(name))[1]))
  with check (bucket_id = 'photos' and public.can_use_job((storage.foldername(name))[1]));
create policy "bilder slette" on storage.objects for delete to authenticated
  using (bucket_id = 'photos' and public.can_use_job((storage.foldername(name))[1]));

-- Kontroll
select id, public, file_size_limit from storage.buckets where id = 'photos';
