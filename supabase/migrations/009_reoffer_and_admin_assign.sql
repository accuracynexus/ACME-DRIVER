-- ============================================================
-- ACME-DRIVER · Migración 009
-- (A) Re-oferta con enfriamiento y (B) asignación manual del
--     administrador.
--
-- Contexto: la flota son 2 repartidores. La regla original de
-- 002 excluía PARA SIEMPRE a quien rechazaba o dejaba expirar
-- una oferta, así que bastaban dos timeouts para que un pedido
-- se quedara sin ningún candidato posible y girara en
-- ready_for_pickup hasta que alguien lo tocara a mano.
-- Idempotente.
-- ============================================================

-- ── Parámetros de re-oferta ─────────────────────────────────
-- Se cuentan desde assigned_at (cuándo se hizo la oferta), no
-- desde que murió: a la espera real hay que restarle el timeout
-- de la oferta (45 s). Con 120 s, un repartidor que dejó expirar
-- vuelve a ser candidato ~75 s después.
insert into public.system_settings (key, value_json, description)
select v.key, v.val::jsonb, v.descr
from (values
  ('dispatch_reoffer_expired_seconds',  '120',
   'Segundos antes de volver a ofrecer un pedido a quien dejó expirar la oferta'),
  ('dispatch_reoffer_rejected_seconds', '600',
   'Segundos antes de volver a ofrecer un pedido a quien lo rechazó expresamente')
) as v(key, val, descr)
where not exists (select 1 from public.system_settings s where s.key = v.key);

-- ── Despachar UN pedido al mejor repartidor disponible ───────
-- Igual que en 008, pero la exclusión por rechazo/expiración
-- ahora caduca en vez de ser permanente.
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
  v_cool_expired int := public._dispatch_param('dispatch_reoffer_expired_seconds', 120);
  v_cool_rejected int := public._dispatch_param('dispatch_reoffer_rejected_seconds', 600);
  v_driver uuid;
  v_assignment_id uuid;
  v_order_code bigint;
begin
  select b.geom, o.order_code
    into v_branch_geom, v_order_code
  from public.orders o
  join public.merchant_branches b on b.id = o.branch_id
  where o.id = p_order_id;

  if v_branch_geom is null then
    return null;
  end if;

  if exists (
    select 1 from public.order_assignments oa
    where oa.order_id = p_order_id and oa.status in ('assigned', 'accepted')
  ) then
    return null;
  end if;

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
      -- enfriamiento tras rechazar o dejar expirar ESTE pedido:
      -- no se le insiste de inmediato, pero vuelve a ser candidato
      and not exists (
        select 1 from public.order_assignments oa2
        where oa2.order_id = p_order_id
          and oa2.driver_id = d.user_id
          and oa2.status in ('rejected', 'cancelled')
          and oa2.assigned_at > now() - make_interval(secs => case
                when oa2.status = 'rejected' then v_cool_rejected
                else v_cool_expired
              end)
      )
  ) cand
  where cand.dist_m <= v_max_radius_m
  order by
    (v_w_dist * (cand.dist_m / nullif(v_max_radius_m, 0))
     + v_w_load * (cand.load::numeric / nullif(v_max_concurrent, 0))) asc,
    cand.last_seen_at asc nulls last
  limit 1;

  if v_driver is null then
    return null;
  end if;

  insert into public.order_assignments (order_id, driver_id, status, assigned_at)
  values (p_order_id, v_driver, 'assigned', now())
  returning id into v_assignment_id;

  update public.orders
     set status = 'assigned', updated_at = now()
   where id = p_order_id
     and status in ('confirmed', 'preparing', 'ready_for_pickup', 'assigned');

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

-- ── (B) Asignación manual por el administrador ───────────────
-- Salta el reparto automático por completo: ni radio, ni carga,
-- ni presencia. Es una decisión humana y el sistema la obedece.
-- Lo único que sigue exigiendo es que el repartidor esté
-- verificado y su cuenta activa.
--
-- p_force = false (por defecto): le llega como OFERTA y la
--   acepta desde la app, igual que una automática.
-- p_force = true: se le asigna directo, sin pedirle confirmación.
create or replace function public.admin_assign_order(
  p_order_id uuid,
  p_driver_id uuid,
  p_force boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_assignment_id uuid;
  v_order_code bigint;
  v_order_status public.order_status;
  v_prev_driver uuid;
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede asignar pedidos a mano';
  end if;

  select order_code, status, current_driver_id
    into v_order_code, v_order_status, v_prev_driver
  from public.orders where id = p_order_id
  for update;

  if v_order_code is null then
    raise exception 'El pedido no existe';
  end if;

  if v_order_status in ('delivered', 'cancelled', 'failed') then
    raise exception 'El pedido ya está cerrado (%), no se puede asignar', v_order_status;
  end if;

  if not exists (
    select 1 from public.drivers d
    join public.profiles p on p.user_id = d.user_id
    where d.user_id = p_driver_id and d.is_verified and p.is_active
  ) then
    raise exception 'El repartidor no existe, no está verificado o su cuenta está inactiva';
  end if;

  -- Anular cualquier oferta o asignación viva de este pedido
  update public.order_assignments
     set status = 'cancelled',
         reason = 'Reasignado por el administrador'
   where order_id = p_order_id
     and status in ('assigned', 'accepted');

  -- Si otro repartidor lo tenía en curso, liberarlo
  if v_prev_driver is not null and v_prev_driver <> p_driver_id then
    update public.driver_current_state
       set status = case when status = 'busy' then 'available'::public.driver_state else status end,
           current_order_id = null,
           updated_at = now()
     where driver_id = v_prev_driver and current_order_id = p_order_id;
  end if;

  insert into public.order_assignments (order_id, driver_id, status, assigned_at, accepted_at)
  values (
    p_order_id, p_driver_id,
    case when p_force then 'accepted' else 'assigned' end::public.assignment_status,
    now(),
    case when p_force then now() else null end
  )
  returning id into v_assignment_id;

  if p_force then
    update public.orders
       set status = 'driver_accepted',
           current_driver_id = p_driver_id,
           accepted_at = coalesce(accepted_at, now()),
           updated_at = now()
     where id = p_order_id;

    update public.driver_current_state
       set status = 'busy', current_order_id = p_order_id, updated_at = now()
     where driver_id = p_driver_id;
  else
    update public.orders
       set status = 'assigned', updated_at = now()
     where id = p_order_id
       and status in ('confirmed', 'preparing', 'ready_for_pickup', 'assigned');
  end if;

  insert into public.order_status_history (order_id, from_status, to_status, actor_user_id, actor_type, note)
  values (
    p_order_id, v_order_status,
    case when p_force then 'driver_accepted' else 'assigned' end::public.order_status,
    v_uid, 'admin',
    case when p_force then 'Asignado directamente por el administrador'
         else 'Ofrecido por el administrador' end
  );

  insert into public.notifications (user_id, channel, type, title, body, entity_type, entity_id, status)
  values (
    p_driver_id, 'push',
    case when p_force then 'order_assigned' else 'order_offer' end,
    case when p_force then 'Pedido asignado' else 'Nuevo pedido disponible' end,
    case when p_force then 'Se te asignó la entrega #' else 'Tienes una nueva oferta de entrega #' end
      || coalesce(v_order_code::text, ''),
    'order', p_order_id, 'queued'
  );

  return v_assignment_id;
end;
$$;

grant execute on function public.admin_assign_order(uuid, uuid, boolean) to authenticated;

-- ── Candidatos para el panel del administrador ───────────────
-- Lista los repartidores con su presencia real y su distancia al
-- local del pedido, para que el admin elija con criterio en vez
-- de a ciegas. Ordena por presente y cercano primero.
create or replace function public.admin_list_drivers_for_order(p_order_id uuid)
returns table (
  driver_id uuid,
  full_name text,
  phone text,
  is_online boolean,
  state public.driver_state,
  seconds_since_seen numeric,
  is_present boolean,
  active_load int,
  distance_km numeric
)
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  v_branch_geom geography;
  v_presence_timeout int := public._dispatch_param('dispatch_presence_timeout_seconds', 150);
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede consultar los candidatos';
  end if;

  select b.geom into v_branch_geom
  from public.orders o
  join public.merchant_branches b on b.id = o.branch_id
  where o.id = p_order_id;

  return query
  select
    d.user_id,
    p.full_name,
    p.phone,
    coalesce(dcs.is_online, false),
    coalesce(dcs.status, 'offline'::public.driver_state),
    round(extract(epoch from (now() - dcs.last_seen_at))::numeric, 0),
    (dcs.last_seen_at is not null
     and dcs.last_seen_at > now() - make_interval(secs => v_presence_timeout)),
    public._driver_active_load(d.user_id),
    case
      when v_branch_geom is null or dcs.last_lat is null or dcs.last_lng is null then null
      else round((st_distance(
        v_branch_geom,
        st_setsrid(st_makepoint(dcs.last_lng::float8, dcs.last_lat::float8), 4326)::geography
      ) / 1000)::numeric, 2)
    end
  from public.drivers d
  join public.profiles p on p.user_id = d.user_id
  left join public.driver_current_state dcs on dcs.driver_id = d.user_id
  where d.is_verified and p.is_active
  order by 7 desc, 9 asc nulls last;
end;
$$;

grant execute on function public.admin_list_drivers_for_order(uuid) to authenticated;
