-- ============================================================================
-- Desactivar pago en efectivo y tarjeta contra entrega
-- Fecha: 2026-08-16 · Revisado contra la BD el 2026-08-18
-- Motivo: decisión de negocio — todo el cobro pasa por Culqi.
--
-- ⚠️ NO APLICAR TODAVÍA. Ver "Estado al 2026-08-18" abajo.
-- ============================================================================

-- ─── 1. Estado actual ────────────────────────────────────────────────────────
select code, name, is_online, is_active
from payment_methods
order by code;

-- ─── 2. Pedidos vivos que quedarían con un método desactivado ───────────────
select o.id, o.status, o.payment_status, pm.code, o.total, o.created_at
from orders o
join payment_methods pm on pm.id = o.payment_method_id
where pm.code in ('cash', 'card_pos')
  and o.status not in ('delivered', 'cancelled', 'failed')
order by o.created_at desc;

-- ─── 3. El cambio ────────────────────────────────────────────────────────────
begin;

update payment_methods
   set is_active = false
 where code in ('cash', 'card_pos');

-- Verificación dentro de la transacción: deben quedar exactamente 3 activos.
-- Si no cuadra, `rollback` en vez de `commit`.
select code, name, is_online, is_active
from payment_methods
order by code;

commit;

-- ─── 4. Rollback (si hiciera falta revertir después del commit) ─────────────
-- update payment_methods
--    set is_active = true
--  where code in ('cash', 'card_pos');


-- ============================================================================
-- ESTADO AL 2026-08-18 (verificado contra la BD, no aplicar aún)
-- ============================================================================
--
-- El script sigue sin aplicarse: los 5 métodos están is_active = true.
--
-- ⛔ RECOMENDACIÓN: no aplicarlo mientras el cobro en línea esté roto.
--    Hoy el efectivo es la única vía de cobro que funciona de punta a punta;
--    apagarlo deja al negocio sin ninguna. Evidencia:
--
--    a) Los pedidos #1017–#1021 (2026-08-12) se crearon con
--       payment_method_id = NULL. `create_order_from_quote` acepta
--       p_payment_method_id como opcional y el checkout no lo está enviando.
--       Quedaron en status 'placed' / payment_status 'pending'.
--
--    b) La tabla `payments` está vacía pese a que hay un cargo Culqi exitoso
--       en `payment_attempts` (chr_test_7uzitCj8zp93g4MG, status 'paid',
--       2026-06-26). Nada mueve orders.payment_status a 'paid'.
--
--    Ambas cosas viven fuera de este repo (checkout del cliente + webhook de
--    Culqi). Hasta que se arreglen, desactivar el efectivo agrava el problema.
--
-- ✅ CORRECCIÓN al análisis de impacto original sobre ACME-DRIVER:
--    El análisis daba por hecho que la app no se veía afectada citando
--    `order.dart:242 isCashOnDelivery`. Esa función no existía. Lo que había
--    era `mustCollectPayment`, con esta regla:
--        payment_status != 'paid' && payment_method_code != 'card_online'
--    Es decir, la app mandaba COBRAR en efectivo cualquier pedido con Yape,
--    Plin o sin método registrado. Sobre los pedidos reales de la BD eso son
--    6 pedidos que el repartidor habría cobrado dos veces
--    (`node scripts/audit-payments.js` lo reproduce).
--
--    Corregido: la app ahora lee `payment_methods.is_online` y solo cobra
--    cuando is_online = false y el pedido no está pagado. Sigue sin filtrar
--    por is_active, así que este script no la afecta: los pedidos históricos
--    en efectivo se siguen cobrando bien.
--
-- ⚠️ OJO CON `plin`: quedó is_online = true pero el checkout de Culqi no lo
--    soporta. Como la app del repartidor ahora confía en is_online, un pedido
--    con Plin se le muestra como "pagado en línea — no cobrar" y nadie cobra
--    nunca. Antes de aplicar este script hay que decidir:
--      · si Plin se paga por transferencia al repartidor → is_online = false
--      · si Plin no se usa                              → sumarlo al in (...)
--    update payment_methods set is_online = false where code = 'plin';
-- ============================================================================
