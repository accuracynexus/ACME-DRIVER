-- ============================================================
-- ACME-DRIVER · Migración 003
-- Políticas RLS ADITIVAS para el rol "driver".
-- No alteran columnas ni rompen políticas de otros clientes
-- (las policies se combinan con OR). Idempotente.
--
-- NOTA: se asume que las tablas compartidas (orders, etc.) ya
-- tienen RLS habilitado en la plataforma. Para las tablas
-- propias del repartidor sí habilitamos RLS explícitamente.
-- ============================================================

create or replace function public.current_is_driver()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles p
    where p.user_id = auth.uid() and p.default_role = 'driver'
  );
$$;

grant execute on function public.current_is_driver() to authenticated;

-- ── profiles: el repartidor lee/edita su propio perfil ───────
drop policy if exists "driver_profile_select_own" on public.profiles;
create policy "driver_profile_select_own" on public.profiles
  for select to authenticated using (user_id = auth.uid());

drop policy if exists "driver_profile_update_own" on public.profiles;
create policy "driver_profile_update_own" on public.profiles
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ── drivers: lectura propia (el registro se hace vía RPC) ────
drop policy if exists "driver_row_select_own" on public.drivers;
create policy "driver_row_select_own" on public.drivers
  for select to authenticated using (user_id = auth.uid());

-- ── driver_current_state (tabla propia) ──────────────────────
alter table public.driver_current_state enable row level security;
drop policy if exists "dcs_all_own" on public.driver_current_state;
create policy "dcs_all_own" on public.driver_current_state
  for all to authenticated using (driver_id = auth.uid()) with check (driver_id = auth.uid());

-- ── driver_locations (tabla propia) ──────────────────────────
alter table public.driver_locations enable row level security;
drop policy if exists "dloc_insert_own" on public.driver_locations;
create policy "dloc_insert_own" on public.driver_locations
  for insert to authenticated with check (driver_id = auth.uid());
drop policy if exists "dloc_select_own" on public.driver_locations;
create policy "dloc_select_own" on public.driver_locations
  for select to authenticated using (driver_id = auth.uid());

-- ── driver_documents (tabla propia) ──────────────────────────
alter table public.driver_documents enable row level security;
drop policy if exists "ddoc_all_own" on public.driver_documents;
create policy "ddoc_all_own" on public.driver_documents
  for all to authenticated using (driver_id = auth.uid()) with check (driver_id = auth.uid());
drop policy if exists "ddoc_admin_read" on public.driver_documents;
create policy "ddoc_admin_read" on public.driver_documents
  for select to authenticated using (public.is_admin());

-- ── vehicles (tabla propia) ──────────────────────────────────
alter table public.vehicles enable row level security;
drop policy if exists "veh_all_own" on public.vehicles;
create policy "veh_all_own" on public.vehicles
  for all to authenticated using (driver_id = auth.uid()) with check (driver_id = auth.uid());

-- ── driver_settlements / items (solo lectura propia) ─────────
alter table public.driver_settlements enable row level security;
drop policy if exists "dsettle_select_own" on public.driver_settlements;
create policy "dsettle_select_own" on public.driver_settlements
  for select to authenticated using (driver_id = auth.uid());

alter table public.driver_settlement_items enable row level security;
drop policy if exists "dsettle_item_select_own" on public.driver_settlement_items;
create policy "dsettle_item_select_own" on public.driver_settlement_items
  for select to authenticated using (
    exists (select 1 from public.driver_settlements ds
            where ds.id = settlement_id and ds.driver_id = auth.uid())
  );

-- ── order_assignments: el repartidor ve sus ofertas/asig. ────
drop policy if exists "oa_select_own" on public.order_assignments;
create policy "oa_select_own" on public.order_assignments
  for select to authenticated using (driver_id = auth.uid());

-- ── orders: ve los suyos (asignados u ofertados) ─────────────
drop policy if exists "orders_select_driver" on public.orders;
create policy "orders_select_driver" on public.orders
  for select to authenticated using (
    current_driver_id = auth.uid()
    or exists (
      select 1 from public.order_assignments oa
      where oa.order_id = orders.id and oa.driver_id = auth.uid()
    )
  );

-- ── order_delivery_details: ligado al pedido del repartidor ──
drop policy if exists "odd_select_driver" on public.order_delivery_details;
create policy "odd_select_driver" on public.order_delivery_details
  for select to authenticated using (
    exists (
      select 1 from public.orders o
      where o.id = order_delivery_details.order_id
        and (
          o.current_driver_id = auth.uid()
          or exists (select 1 from public.order_assignments oa
                     where oa.order_id = o.id and oa.driver_id = auth.uid())
        )
    )
  );

-- ── merchant_branches: lectura para repartidores (datos recojo)
drop policy if exists "branches_select_driver" on public.merchant_branches;
create policy "branches_select_driver" on public.merchant_branches
  for select to authenticated using (public.current_is_driver());

-- ── vehicle_types: catálogo de lectura ───────────────────────
drop policy if exists "vtypes_select_auth" on public.vehicle_types;
create policy "vtypes_select_auth" on public.vehicle_types
  for select to authenticated using (true);

-- ── notifications: propias ───────────────────────────────────
drop policy if exists "notif_select_own" on public.notifications;
create policy "notif_select_own" on public.notifications
  for select to authenticated using (user_id = auth.uid());
drop policy if exists "notif_update_own" on public.notifications;
create policy "notif_update_own" on public.notifications
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ── order_evidences: el repartidor sube/lee la suya ──────────
drop policy if exists "evid_insert_own" on public.order_evidences;
create policy "evid_insert_own" on public.order_evidences
  for insert to authenticated with check (driver_id = auth.uid());
drop policy if exists "evid_select_own" on public.order_evidences;
create policy "evid_select_own" on public.order_evidences
  for select to authenticated using (driver_id = auth.uid());

-- ── cash_collections: el repartidor registra/lee la suya ─────
drop policy if exists "cash_insert_own" on public.cash_collections;
create policy "cash_insert_own" on public.cash_collections
  for insert to authenticated with check (driver_id = auth.uid());
drop policy if exists "cash_select_own" on public.cash_collections;
create policy "cash_select_own" on public.cash_collections
  for select to authenticated using (driver_id = auth.uid());
