-- ============================================================
-- ACME-DRIVER · Migración 005 (OPCIONAL · solo desarrollo)
-- Helpers para probar el flujo de dispatch sin la app merchant.
-- Puedes NO ejecutar este archivo en producción.
-- ============================================================

-- Marca un pedido como listo para recoger y lo despacha al instante.
create or replace function public.dev_mark_order_ready(p_order_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.orders
     set status = 'ready_for_pickup', updated_at = now()
   where id = p_order_id;
  return public.dispatch_order(p_order_id);
end;
$$;

grant execute on function public.dev_mark_order_ready(uuid) to authenticated, service_role;

-- Diagnóstico: carga actual de cada repartidor online.
create or replace function public.dev_driver_loads()
returns table (driver_id uuid, full_name text, is_online boolean, state public.driver_state, active_load int)
language sql
security definer
set search_path = public
as $$
  select d.user_id, p.full_name, dcs.is_online, dcs.status, public._driver_active_load(d.user_id)
  from public.drivers d
  join public.profiles p on p.user_id = d.user_id
  left join public.driver_current_state dcs on dcs.driver_id = d.user_id
  order by public._driver_active_load(d.user_id) desc;
$$;

grant execute on function public.dev_driver_loads() to authenticated, service_role;
