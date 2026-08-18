-- ============================================================================
-- Catálogo de métodos de pago: dejar activo solo lo que Culqi puede cobrar
-- Fecha original: 2026-08-16 · Revisado contra la BD y el código: 2026-08-18
--
-- Equivalente ejecutable: node scripts/apply-payment-catalog.js
--                         node scripts/apply-payment-catalog.js --rollback
-- ============================================================================

-- ─── 1. Estado actual ────────────────────────────────────────────────────────
select code, name, is_online, is_active
from payment_methods
order by code;

-- ─── 2. Pedidos vivos que quedarían con un método desactivado ───────────────
select o.id, o.status, o.payment_status, pm.code, o.total, o.created_at
from orders o
join payment_methods pm on pm.id = o.payment_method_id
where pm.code in ('cash', 'card_pos', 'plin')
  and o.status not in ('delivered', 'cancelled', 'failed')
order by o.created_at desc;

-- ─── 3. El cambio ────────────────────────────────────────────────────────────
begin;

update payment_methods
   set is_active = false
 where code in ('cash', 'card_pos', 'plin');

-- Deben quedar exactamente 2 activos: card_online y yape.
-- Si no cuadra, `rollback` en vez de `commit`.
select code, name, is_online, is_active
from payment_methods
order by code;

commit;

-- ─── 4. Rollback ─────────────────────────────────────────────────────────────
-- update payment_methods
--    set is_active = true
--  where code in ('cash', 'card_pos', 'plin');


-- ============================================================================
-- ANÁLISIS VERIFICADO (2026-08-18)
-- ============================================================================
--
-- ✅ APLICARLO ES SEGURO. Corrijo mi propia advertencia anterior: dije que no
--    se aplicara porque el efectivo sería la única vía de cobro que funciona.
--    Al leer el checkout resultó falso — el cliente nunca puede elegir
--    efectivo. En src/modules/public/cart/CartPage.tsx el checkout abre Culqi
--    con paymentMethods = { tarjeta, yape, bancaMovil, agente, billetera,
--    cuotealo } y la cotización se pide con payment_method: 'card' fijo.
--    Efectivo y tarjeta POS solo son alcanzables a mano desde el admin, así
--    que desactivarlos no le quita al cliente ninguna forma de pagar.
--
-- ➕ SE AGREGA `plin` A LA LISTA. Estaba activo con is_online = true, pero
--    Culqi no lo ofrece en el checkout. Como la app del repartidor ahora
--    confía en is_online, un pedido con Plin se mostraría "pagado en línea"
--    y nadie lo cobraría nunca. Si en el futuro Plin se cobra por
--    transferencia al repartidor, va como is_online = false, no como true.
--
-- ============================================================================
-- LO QUE ESTE SCRIPT NO ARREGLA (vive en ACME-WEB, no en este repo)
-- ============================================================================
--
-- 1. TODO PEDIDO SE CREA CON payment_method_id = NULL.
--    · create_order_from_quote declara p_payment_method_id uuid DEFAULT NULL
--      (supabase/migrations/202606230001_fix_create_order_from_quote_enum_cast.sql:13)
--      e inserta lo que reciba.
--    · El frontend nunca lo manda: CourierCreateOrderRequest
--      (src/core/services/courierPaymentService.ts:128) solo lleva quote_id,
--      fulfillment_type, special_instructions, recipient_name,
--      recipient_phone y address. No hay campo de método de pago.
--    · Resultado en la BD: los pedidos #1017–#1021 (2026-08-12) tienen
--      payment_method_id NULL y quedaron en status 'placed'.
--
-- 2. EL COBRO DE CULQI NO SE REGISTRA.
--    · La tabla `payments` está vacía.
--    · En `payment_attempts` hay una sola fila en toda la BD
--      (chr_test_7uzitCj8zp93g4MG, 'paid', 2026-06-26). Para #1017–#1021 no
--      hay ni un intento: el checkout creó el pedido y nunca llegó a cobrar.
--    · Nada mueve orders.payment_status a 'paid'.
--
-- 3. LOS ENDPOINTS DEL CHECKOUT NO ESTÁN EN EL REPO.
--    El frontend llama a /api/courier/orders, /api/courier/quotes y
--    /api/courier/payments/*, pero `git ls-tree HEAD api/` en ACME-WEB solo
--    devuelve customer-addresses.ts y manage-merchant-access.ts. Además
--    vercel.json reescribe /(.*) a /index.html, así que una ruta /api que no
--    exista como función devuelve el HTML de la SPA en vez de JSON.
--    Hasta que ese backend esté versionado no se puede arreglar el punto 1.
--
-- Mientras tanto, la app del repartidor está protegida: un pedido sin método
-- registrado se le muestra como "Pago sin confirmar — no cobres" en vez de
-- mandarlo a cobrar. Ver test/payment_action_test.dart.
-- ============================================================================
