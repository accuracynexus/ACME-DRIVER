-- ============================================================
-- ACME-DRIVER · Migración 001
-- Bucket privado para documentos del repartidor + políticas
-- Idempotente: se puede ejecutar varias veces sin error.
-- ============================================================

-- Bucket privado (no público): los archivos solo se leen con URL firmada o por el dueño/admin.
insert into storage.buckets (id, name, public, file_size_limit)
values ('driver-documents', 'driver-documents', false, 10485760) -- 10 MB
on conflict (id) do update set public = excluded.public;

-- Convención de ruta: "{driver_user_id}/{document_type}_{timestamp}.{ext}"
-- El primer segmento de la carpeta debe ser el uid del repartidor autenticado.

-- Helper: ¿el usuario actual es admin?
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles p
    where p.user_id = auth.uid()
      and p.default_role in ('admin', 'super_admin')
  );
$$;

grant execute on function public.is_admin() to authenticated;

-- Limpieza idempotente de políticas previas
drop policy if exists "driver_docs_insert_own" on storage.objects;
drop policy if exists "driver_docs_select_own" on storage.objects;
drop policy if exists "driver_docs_update_own" on storage.objects;
drop policy if exists "driver_docs_delete_own" on storage.objects;
drop policy if exists "driver_docs_admin_all" on storage.objects;

-- El repartidor gestiona solo su propia carpeta
create policy "driver_docs_insert_own" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'driver-documents'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "driver_docs_select_own" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'driver-documents'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "driver_docs_update_own" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'driver-documents'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "driver_docs_delete_own" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'driver-documents'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- El admin puede leer todos los documentos para revisarlos
create policy "driver_docs_admin_all" on storage.objects
  for select to authenticated
  using (bucket_id = 'driver-documents' and public.is_admin());
