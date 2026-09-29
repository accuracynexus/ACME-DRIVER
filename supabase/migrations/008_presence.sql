-- ============================================================
-- ACME-DRIVER · Migración 008
-- Presencia real del repartidor.
--
-- Problema: dispatch_order confiaba solo en is_online, que es un
-- flag pegajoso (si la app muere nadie lo baja). Resultado: se
-- ofrecen pedidos a repartidores fantasma y esas ofertas expiran
-- a los 45 s mientras el pedido espera.
--
-- Ahora se exige además una señal reciente (last_seen_at). Esto
-- REQUIERE el latido de presencia del cliente (Timer.periodic en
-- location_provider.dart): sin él, un repartidor quieto quedaría
-- fuera del reparto aunque esté disponible.
-- Idempotente.
-- ============================================================

-- ── Nuevo parámetro configurable ────────────────────────────
-- Holgura sobre el latido del cliente (45 s): tolera un latido
-- perdido más la latencia de red antes de dar a alguien por ido.
insert into public.system_settings (key, value_json, description)
select v.key, v.val::jsonb, v.descr
from (values
  ('dispatch_presence_timeout_seconds', '150',
   'Segundos sin señal tras los cuales un repartidor deja de considerarse presente')
) as v(key, val, descr)
where not exists (select 1 from public.system_settings s where s.key = v.key);

-- ── Despachar UN pedido al mejor repartidor disponible ───────
-- Igual que en 002 pero exigiendo presencia fresca.
create or replace function public.dispatch_order(p_order_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_branch_geom geography;
  v_max_radius_m numeric := public._dispatch_param('dispatch_max_radius_km', 8) * 1000;
  v_max_concurrent int := public._dispatch_param('dispatch_max_concurrent_orders', 3);
  v_w_dist numeric := public._dispatch_param('dispatch_weight_distance', 0.6);
  v_w_load numeric := public._dispatch_param('dispatch_weight_load', 0.4);
  v_presence_timeout int := public._dispatch_param('dispatch_presence_timeout_seconds', 150);
  v_driver uuid;
  v_assignment_id uuid;
  v_order_code bigint;
begin
  -- Pedido + geometría del local de recojo
  select b.geom, o.order_code
    into v_branch_geom, v_order_code
  from public.orders o
  join public.merchant_branches b on b.id = o.branch_id
  where o.id = p_order_id;

  if v_branch_geom is null then
    return null; -- sin local georreferenciado no se puede asignar por distancia
  end if;

  -- Si ya hay una oferta o aceptación viva para este pedido, no re-ofrecer
  if exists (
    select 1 from public.order_assignments oa
    where oa.order_id = p_order_id and oa.status in ('assigned', 'accepted')
  ) then
    return null;
  end if;

  -- Elegir al mejor candidato
  select cand.user_id
    into v_driver
  from (
    select
      d.user_id,
      st_distance(
        v_branch_geom,
        st_setsrid(st_makepoint(dcs.last_lng::float8, dcs.last_lat::float8), 4326)::geography
      ) as dist_m,
      public._driver_active_load(d.user_id) as load,
      dcs.last_seen_at
    from public.drivers d
    join public.profiles p             on p.user_id = d.user_id and p.is_active
    join public.driver_current_state dcs on dcs.driver_id = d.user_id
    where d.is_verified
      and dcs.is_online
      and dcs.status = 'available'
      and dcs.last_lat is not null
      and dcs.last_lng is not null
      -- presencia real: el flag is_online no basta, exigimos latido reciente
      and dcs.last_seen_at is not null
      and dcs.last_seen_at > now() - make_interval(secs => v_presence_timeout)
      and public._driver_active_load(d.user_id) < v_max_concurrent
      -- sin otra oferta pendiente (un repartidor evalúa una oferta a la vez)
      and not exists (
        select 1 from public.order_assignments oa
        where oa.driver_id = d.user_id and oa.status = 'assigned'
      )
      -- que no haya rechazado / expirado ya este mismo pedido
      and not exists (
        select 1 from public.order_assignments oa2
        where oa2.order_id = p_order_id
          and oa2.driver_id = d.user_id
          and oa2.status in ('rejected', 'cancelled')
      )
  ) cand
  where cand.dist_m <= v_max_radius_m
  order by
    (v_w_dist * (cand.dist_m / nullif(v_max_radius_m, 0))
     + v_w_load * (cand.load::numeric / nullif(v_max_concurrent, 0))) asc,
    cand.last_seen_at asc nulls last
  limit 1;

  if v_driver is null then
    return null; -- nadie disponible ahora; cron reintentará
  end if;

  -- Crear la oferta
  insert into public.order_assignments (order_id, driver_id, status, assigned_at)
  values (p_order_id, v_driver, 'assigned', now())
  returning id into v_assignment_id;

  -- Marcar el pedido como asignado (solo desde estados válidos previos)
  update public.orders
     set status = 'assigned', updated_at = now()
   where id = p_order_id
     and status in ('confirmed', 'preparing', 'ready_for_pickup', 'assigned');

  -- Notificar al repartidor
  insert into public.notifications (user_id, channel, type, title, body, entity_type, entity_id, status)
  values (
    v_driver, 'push', 'order_offer',
    'Nuevo pedido disponible',
    'Tienes una nueva oferta de entrega #' || coalesce(v_order_code::text, ''),
    'order', p_order_id, 'queued'
  );

  return v_assignment_id;
end;
$$;

grant execute on function public.dispatch_order(uuid) to authenticated, service_role;

-- ── Barrer repartidores fantasma ─────────────────────────────
-- Baja el flag de quienes dejaron de latir (app cerrada, sin red,
-- batería agotada) para que is_online deje de mentir en el perfil
-- y en cualquier panel que lo lea. No toca a los que están 'busy'
-- con un pedido en curso: esos se resuelven por el flujo del pedido.
create or replace function public.mark_stale_drivers_offline()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_presence_timeout int := public._dispatch_param('dispatch_presence_timeout_seconds', 150);
  v_count int;
begin
  update public.driver_current_state
     set is_online = false,
         status = 'offline'::public.driver_state,
         updated_at = now()
   where is_online
     and status <> 'busy'
     and (last_seen_at is null
          or last_seen_at < now() - make_interval(secs => v_presence_timeout));
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

grant execute on function public.mark_stale_drivers_offline() to service_role;

-- Nota: este pg_cron solo acepta formato cron clásico o intervalos
-- de '[1-59] seconds'; '1 minute' es rechazado. Usamos cron estándar.
select cron.schedule(
  'acme_mark_stale_drivers',
  '* * * * *',
  $$ select public.mark_stale_drivers_offline(); $$
);
