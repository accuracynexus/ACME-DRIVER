-- ============================================================
-- ACME-DRIVER · Migración 002
-- Lógica de asignación de pedidos (dispatch) con balanceo
-- por distancia (PostGIS) + carga actual del repartidor.
-- Modelo: OFERTA con timeout. El sistema ofrece al mejor
-- repartidor; si no acepta a tiempo, se reasigna al siguiente.
-- ============================================================

-- ── Parámetros configurables ────────────────────────────────
-- Se guardan en system_settings (key / value_json) para poder ajustarlos
-- sin redeploy. Si no existen, las funciones usan defaults.
-- (insert idempotente sin depender de un índice único sobre key)
insert into public.system_settings (key, value_json, description)
select v.key, v.val::jsonb, v.descr
from (values
  ('dispatch_offer_timeout_seconds', '45',  'Segundos que el repartidor tiene para aceptar una oferta'),
  ('dispatch_max_radius_km',         '8',   'Radio máximo (km) para ofrecer un pedido a un repartidor'),
  ('dispatch_max_concurrent_orders', '3',   'Máximo de pedidos activos simultáneos por repartidor'),
  ('dispatch_weight_distance',       '0.6', 'Peso de la distancia en el score de asignación'),
  ('dispatch_weight_load',           '0.4', 'Peso de la carga en el score de asignación')
) as v(key, val, descr)
where not exists (select 1 from public.system_settings s where s.key = v.key);

create or replace function public._dispatch_param(p_key text, p_default numeric)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select (value_json #>> '{}')::numeric from public.system_settings where key = p_key limit 1),
    p_default
  );
$$;

-- ── Carga activa del repartidor (base del balanceo) ──────────
-- Cuenta pedidos en curso (aceptados, recogidos o en camino).
create or replace function public._driver_active_load(p_driver uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::int
  from public.orders o
  where o.current_driver_id = p_driver
    and o.status in ('driver_accepted', 'picked_up', 'on_the_way');
$$;

-- ── Despachar UN pedido al mejor repartidor disponible ───────
-- Devuelve el id de la asignación creada, o null si no hay candidato.
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

-- ── Aceptar oferta (lo invoca el repartidor) ─────────────────
create or replace function public.driver_accept_assignment(p_assignment_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_order_id uuid;
begin
  select order_id into v_order_id
  from public.order_assignments
  where id = p_assignment_id and driver_id = v_uid and status = 'assigned'
  for update;

  if v_order_id is null then
    raise exception 'Oferta no válida o ya expirada';
  end if;

  update public.order_assignments
     set status = 'accepted', accepted_at = now()
   where id = p_assignment_id;

  update public.orders
     set status = 'driver_accepted',
         current_driver_id = v_uid,
         accepted_at = coalesce(accepted_at, now()),
         updated_at = now()
   where id = v_order_id;

  update public.driver_current_state
     set status = 'busy', current_order_id = v_order_id, updated_at = now()
   where driver_id = v_uid;

  insert into public.order_status_history (order_id, from_status, to_status, actor_user_id, actor_type, note)
  values (v_order_id, 'assigned', 'driver_accepted', v_uid, 'driver', 'Repartidor aceptó la oferta');

  return v_order_id;
end;
$$;

grant execute on function public.driver_accept_assignment(uuid) to authenticated;

-- ── Rechazar oferta + re-despachar al siguiente ──────────────
create or replace function public.driver_reject_assignment(p_assignment_id uuid, p_reason text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_order_id uuid;
begin
  select order_id into v_order_id
  from public.order_assignments
  where id = p_assignment_id and driver_id = v_uid and status = 'assigned'
  for update;

  if v_order_id is null then
    raise exception 'Oferta no válida';
  end if;

  update public.order_assignments
     set status = 'rejected', rejected_at = now(), reason = coalesce(p_reason, 'Rechazado por repartidor')
   where id = p_assignment_id;

  -- volver el pedido a un estado ofrecible y reasignar
  update public.orders set status = 'ready_for_pickup', updated_at = now()
   where id = v_order_id and status = 'assigned';

  perform public.dispatch_order(v_order_id);
end;
$$;

grant execute on function public.driver_reject_assignment(uuid, text) to authenticated;

-- ── Expirar ofertas vencidas y reasignar (cron) ──────────────
create or replace function public.expire_stale_offers()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_timeout int := public._dispatch_param('dispatch_offer_timeout_seconds', 45)::int;
  r record;
  v_count int := 0;
begin
  for r in
    select id, order_id from public.order_assignments
    where status = 'assigned'
      and assigned_at < now() - make_interval(secs => v_timeout)
  loop
    update public.order_assignments
       set status = 'cancelled', reason = 'Tiempo de oferta agotado'
     where id = r.id;

    update public.orders set status = 'ready_for_pickup', updated_at = now()
     where id = r.order_id and status = 'assigned';

    perform public.dispatch_order(r.order_id);
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

grant execute on function public.expire_stale_offers() to service_role;

-- ── Auto-despachar pedidos listos sin asignar (cron / trigger) ─
create or replace function public.auto_dispatch_ready_orders()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_count int := 0;
begin
  for r in
    select o.id from public.orders o
    where o.status = 'ready_for_pickup'
      and o.fulfillment_type = 'delivery'
      and not exists (
        select 1 from public.order_assignments oa
        where oa.order_id = o.id and oa.status in ('assigned', 'accepted')
      )
    order by o.placed_at asc nulls last
    limit 50
  loop
    perform public.dispatch_order(r.id);
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

grant execute on function public.auto_dispatch_ready_orders() to service_role;

-- ── Avanzar estado del pedido (lo invoca el repartidor) ──────
-- Transiciones válidas: driver_accepted→picked_up→on_the_way→delivered
create or replace function public.driver_advance_order_status(p_order_id uuid, p_to_status public.order_status)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_from public.order_status;
begin
  select status into v_from
  from public.orders
  where id = p_order_id and current_driver_id = v_uid
  for update;

  if v_from is null then
    raise exception 'Pedido no asignado a este repartidor';
  end if;

  -- validar transición
  if not (
    (v_from = 'driver_accepted' and p_to_status = 'picked_up') or
    (v_from = 'picked_up'       and p_to_status = 'on_the_way') or
    (v_from = 'on_the_way'      and p_to_status = 'delivered')
  ) then
    raise exception 'Transición no permitida: % → %', v_from, p_to_status;
  end if;

  update public.orders
     set status = p_to_status,
         picked_up_at = case when p_to_status = 'picked_up' then now() else picked_up_at end,
         delivered_at = case when p_to_status = 'delivered' then now() else delivered_at end,
         updated_at = now()
   where id = p_order_id;

  insert into public.order_status_history (order_id, from_status, to_status, actor_user_id, actor_type)
  values (p_order_id, v_from, p_to_status, v_uid, 'driver');

  if p_to_status = 'picked_up' then
    update public.order_assignments set picked_up_at = now()
     where order_id = p_order_id and driver_id = v_uid and status = 'accepted';
  end if;

  if p_to_status = 'delivered' then
    update public.order_assignments set status = 'completed', completed_at = now()
     where order_id = p_order_id and driver_id = v_uid and status = 'accepted';
    -- liberar al repartidor
    update public.driver_current_state
       set status = 'available', current_order_id = null, updated_at = now()
     where driver_id = v_uid;
  end if;
end;
$$;

grant execute on function public.driver_advance_order_status(uuid, public.order_status) to authenticated;

-- ── Estado online / disponibilidad del repartidor ───────────
create or replace function public.driver_set_online(p_online boolean, p_lat numeric default null, p_lng numeric default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  insert into public.driver_current_state (driver_id, status, is_online, last_lat, last_lng, last_seen_at, updated_at)
  values (
    v_uid,
    case when p_online then 'available'::public.driver_state else 'offline'::public.driver_state end,
    p_online, p_lat, p_lng, now(), now()
  )
  on conflict (driver_id) do update
    set is_online = excluded.is_online,
        -- no degradar a 'available' si está 'busy' con un pedido en curso
        status = case
                   when not p_online then 'offline'::public.driver_state
                   when public.driver_current_state.current_order_id is not null then 'busy'::public.driver_state
                   else 'available'::public.driver_state
                 end,
        last_lat = coalesce(excluded.last_lat, public.driver_current_state.last_lat),
        last_lng = coalesce(excluded.last_lng, public.driver_current_state.last_lng),
        last_seen_at = now(),
        updated_at = now();
end;
$$;

grant execute on function public.driver_set_online(boolean, numeric, numeric) to authenticated;

-- ── Ping de ubicación GPS ────────────────────────────────────
create or replace function public.driver_ping_location(
  p_lat numeric, p_lng numeric,
  p_order_id uuid default null,
  p_accuracy numeric default null,
  p_speed numeric default null,
  p_heading numeric default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  insert into public.driver_locations (driver_id, order_id, lat, lng, accuracy_m, speed_kmh, heading, recorded_at)
  values (v_uid, p_order_id, p_lat, p_lng, p_accuracy, p_speed, p_heading, now());

  update public.driver_current_state
     set last_lat = p_lat, last_lng = p_lng, last_seen_at = now(), updated_at = now()
   where driver_id = v_uid;
end;
$$;

grant execute on function public.driver_ping_location(numeric, numeric, uuid, numeric, numeric, numeric) to authenticated;

-- ── Registro atómico de repartidor (tras auth.signUp) ────────
create or replace function public.register_driver(
  p_full_name text,
  p_phone text,
  p_dni text,
  p_email text,
  p_vehicle_type_code text,
  p_license_number text default null,
  p_plate text default null,
  p_brand text default null,
  p_model text default null,
  p_color text default null,
  p_birthday date default null,
  p_notifications boolean default true,
  p_location boolean default true
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_vehicle_type uuid;
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;

  select id into v_vehicle_type from public.vehicle_types where code = p_vehicle_type_code limit 1;

  insert into public.profiles (user_id, email, full_name, phone, dni, birthday, default_role, is_active, notifications_enabled, location_enabled)
  values (v_uid, p_email, p_full_name, p_phone, p_dni, p_birthday, 'driver', true, p_notifications, p_location)
  on conflict (user_id) do update
    set full_name = excluded.full_name,
        phone = excluded.phone,
        dni = excluded.dni,
        birthday = excluded.birthday,
        default_role = 'driver',
        notifications_enabled = excluded.notifications_enabled,
        location_enabled = excluded.location_enabled,
        updated_at = now();

  insert into public.drivers (user_id, document_number, license_number, vehicle_type_id, is_verified, status)
  values (v_uid, p_dni, p_license_number, v_vehicle_type, false, 'offline')
  on conflict (user_id) do update
    set document_number = excluded.document_number,
        license_number = excluded.license_number,
        vehicle_type_id = excluded.vehicle_type_id,
        updated_at = now();

  if p_plate is not null and length(trim(p_plate)) > 0 then
    insert into public.vehicles (driver_id, vehicle_type_id, plate, brand, model, color, is_active)
    values (v_uid, v_vehicle_type, upper(p_plate), p_brand, p_model, p_color, true)
    on conflict do nothing;
  end if;

  insert into public.driver_current_state (driver_id, status, is_online)
  values (v_uid, 'offline', false)
  on conflict (driver_id) do nothing;
end;
$$;

grant execute on function public.register_driver(text, text, text, text, text, text, text, text, text, text, date, boolean, boolean) to authenticated;

-- ── Alta / actualización de un documento del repartidor ──────
create or replace function public.submit_driver_document(
  p_document_type text,
  p_file_url text,
  p_document_number text default null,
  p_expires_at timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
begin
  -- reemplazar el documento previo del mismo tipo (re-subida)
  delete from public.driver_documents
   where driver_id = v_uid and document_type = p_document_type;

  insert into public.driver_documents (driver_id, document_type, document_number, file_url, status, expires_at)
  values (v_uid, p_document_type, p_document_number, p_file_url, 'pending', p_expires_at)
  returning id into v_id;

  return v_id;
end;
$$;

grant execute on function public.submit_driver_document(text, text, text, timestamptz) to authenticated;
