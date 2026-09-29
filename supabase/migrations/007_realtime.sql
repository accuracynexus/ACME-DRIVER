-- ============================================================
-- ACME-DRIVER · Migración 007
-- Habilita realtime para las tablas que la app del repartidor
-- escucha con .stream(): sin esto la oferta (order_assignments)
-- se crea en la BD pero la app nunca recibe el evento y expira
-- a los 45 s sin mostrarse. Idempotente.
-- ============================================================

do $$
declare
  t text;
begin
  foreach t in array array['order_assignments', 'messages', 'notifications']
  loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end
$$;

-- Necesario para que los filtros del stream (driver_id = ...) también
-- apliquen a eventos UPDATE/DELETE, que solo traen la fila completa
-- con replica identity full.
alter table public.order_assignments replica identity full;
alter table public.messages           replica identity full;
alter table public.notifications      replica identity full;

-- Los eventos siguen respetando RLS: cada repartidor solo recibe
-- cambios de filas que sus políticas de SELECT le permiten ver.
