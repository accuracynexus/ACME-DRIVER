-- ============================================================
-- ACME-DRIVER · Migración 006
-- Chat del pedido para el repartidor.
-- El chat ya existe (conversations/conversation_participants/messages),
-- pero las RLS no dejan que el driver se agregue como participante
-- (solo el creador de la conversación puede). Esta función SECURITY DEFINER
-- resuelve el acceso de forma segura e idempotente.
-- ============================================================

-- Obtiene (o crea) la conversación order_chat de un pedido y asegura
-- al repartidor asignado como participante. Devuelve el conversation_id.
create or replace function public.get_or_create_order_conversation(p_order_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_conv_id uuid;
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;

  -- Solo el repartidor asignado al pedido puede abrir su chat.
  if not exists (
    select 1 from public.orders o
    where o.id = p_order_id and o.current_driver_id = v_uid
  ) then
    raise exception 'No autorizado: no eres el repartidor de este pedido';
  end if;

  -- Buscar la conversación order_chat existente del pedido.
  select id into v_conv_id
  from public.conversations
  where order_id = p_order_id
    and conversation_type = 'order_chat'
  order by created_at asc
  limit 1;

  -- Si no existe, crearla.
  if v_conv_id is null then
    insert into public.conversations (order_id, conversation_type, status, created_by)
    values (p_order_id, 'order_chat', 'open', v_uid)
    returning id into v_conv_id;
  end if;

  -- Asegurar al repartidor como participante (idempotente).
  if not exists (
    select 1 from public.conversation_participants
    where conversation_id = v_conv_id and user_id = v_uid
  ) then
    insert into public.conversation_participants
      (conversation_id, user_id, participant_role, joined_at)
    values (v_conv_id, v_uid, 'driver', now());
  end if;

  return v_conv_id;
end;
$$;

grant execute on function public.get_or_create_order_conversation(uuid) to authenticated;
