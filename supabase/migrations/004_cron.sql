-- ============================================================
-- ACME-DRIVER · Migración 004
-- Tareas programadas (pg_cron): expirar ofertas vencidas y
-- auto-despachar pedidos listos. Idempotente (cron.schedule
-- reemplaza el job si ya existe por nombre).
--
-- Si tu versión de pg_cron NO soporta intervalos en segundos,
-- reemplaza '30 seconds' / '15 seconds' por '* * * * *' (1 min).
-- ============================================================

create extension if not exists pg_cron;

-- Expirar ofertas no aceptadas a tiempo y reasignar
select cron.schedule(
  'acme_expire_offers',
  '30 seconds',
  $$ select public.expire_stale_offers(); $$
);

-- Despachar automáticamente pedidos en ready_for_pickup sin repartidor
select cron.schedule(
  'acme_auto_dispatch',
  '15 seconds',
  $$ select public.auto_dispatch_ready_orders(); $$
);
