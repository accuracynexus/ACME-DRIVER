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
-- DÓNDE VIVE EL COBRO (verificado el 2026-08-18)
-- ============================================================================
--
-- El backend de pagos NO está en ACME-WEB: es un proyecto aparte en Vercel.
--   · Repo:      github.com/gcpaccori/ACME-OPERACIONE  (FastAPI / Python)
--   · Desplegado: https://acme-operacione.vercel.app   (/health responde ok)
--   · ACME-WEB lo llama con VITE_ACME_API_URL, que por defecto apunta ahí
--     (src/core/services/courierPaymentService.ts:3).
--   Las 4 rutas que usa el frontend existen en el backend y coinciden:
--     /api/courier/quote · /api/courier/orders
--     /api/courier/payments/order · /api/courier/payments/charge
--
-- El circuito de cobro está COMPLETO y es correcto:
--   1. POST /api/courier/orders crea el pedido SIN método de pago. Es a
--      propósito: todavía no se sabe con qué va a pagar el cliente
--      (services_courier_orders.py, order_payload).
--   2. POST /api/courier/payments/order resuelve el método con
--      get_online_payment_method_id() y llama a update_order_payment(...,
--      payment_status="pending"), que es lo que rellena
--      orders.payment_method_id (routes_courier_payments.py:107-118).
--   3. POST /api/courier/payments/charge marca 'paid' o 'failed' y actualiza
--      payments, payment_transactions y el pedido de forma síncrona
--      (routes_courier_payments.py:216-253). El webhook /api/webhooks/culqi
--      es respaldo, no la vía principal.
--
-- Entonces payment_method_id = NULL no es un bug del backend: significa que
-- ese pedido nunca pasó del paso 1. Los #1017–#1021 (2026-08-12) se quedaron
-- ahí, y por eso no tienen ni una fila en payments ni en payment_attempts.
--
-- ✅ BLOQUEO 1 (resuelto el 2026-08-18): CORS + enrutado del backend.
--    El checkout se mudó a https://www.acmepedidos.com, pero el backend solo
--    permitía *.vercel.app y lo que trajera FRONTEND_URLS. Toda llamada del
--    navegador moría en la preflight sin cabecera Access-Control-Allow-Origin,
--    empezando por /api/courier/quote, que es el primer paso del checkout:
--    sin cotización no hay pedido y sin pedido no hay cobro. Eso explica que
--    no haya pedidos nuevos después del 2026-08-12.
--    Resuelto sin tocar el código de CORS: el backend ya lee FRONTEND_URLS y
--    la suma a los orígenes permitidos (main.py, allowed_origins()). Se creó
--    esa variable en el proyecto Vercel acme-operacione:
--      FRONTEND_URLS=https://www.acmepedidos.com,https://acmepedidos.com
--
--    Al desplegar apareció un segundo problema, más grave: el backend devolvía
--    404 en TODAS las rutas, incluidas / y /health, aunque el middleware de
--    CORS sí respondía. Comparando los builds salió la causa. El MISMO commit
--    (1c84221), con el mismo preset "fastapi", emitió lambdas distintas:
--        2026-07-03  output: type=lambda path=index
--        2026-08-18  output: type=lambda path=fastapi
--    vercel.json reescribía /(.*) hacia /api/index, así que cuando Vercel dejó
--    de llamar "index" al lambda, todas las peticiones iban a algo inexistente.
--    Producción llevaba desde el 3 de julio sin redesplegarse, por eso el fallo
--    no se veía: seguía sirviendo el build viejo.
--    Arreglado quitando el rewrite obsoleto de vercel.json (el preset fastapi
--    enruta solo hacia la app ASGI). Verificado en producción: /, /health y las
--    4 rutas del checkout responden, y la preflight desde www.acmepedidos.com
--    y desde el apex devuelve Access-Control-Allow-Origin.
--
-- ⚠️ BLOQUEO 2 (pendiente): LAS LLAVES DE CULQI SON DE PRUEBA.
--    El bundle desplegado de ACME-WEB (assets/index-*.js) trae una llave
--    'pk_test' de Culqi — modo sandbox — y ninguna 'pk_live'. El único cobro
--    que existe en toda la BD es de sandbox (chr_test_7uzitCj8zp93g4MG, con
--    statement_descriptor "GICPACCORI DEV"). Con llaves de prueba no entra
--    dinero real por más que el circuito funcione.
--    Para cobrar de verdad hay que poner en Vercel las credenciales de
--    producción: VITE_CULQI_PUBLIC_KEY (pk_live) y, en ACME-OPERACIONE,
--    CULQI_PRIVATE_KEY (sk_live) — más VITE_CULQI_RSA_ID y
--    VITE_CULQI_RSA_PUBLIC_KEY si se quiere cobro con tarjeta.
--
-- ✅ ESTE SCRIPT ES COMPATIBLE CON ESE BACKEND:
--    get_online_payment_method_id() (services_courier_payments.py:103) filtra
--    is_active = true AND is_online = true y prefiere, en orden: culqi,
--    culqi_online, card_online, yape. Al desactivar cash, card_pos y plin
--    siguen quedando card_online y yape, así que la función sigue resolviendo
--    y el cobro no se ve afectado. Ojo: si algún día se desactivan también
--    card_online y yape, esa función devuelve None y el pago se rompe.
--
-- Mientras tanto, la app del repartidor está protegida: un pedido sin método
-- registrado se le muestra como "Pago sin confirmar — no cobres" en vez de
-- mandarlo a cobrar. Ver test/payment_action_test.dart.
-- ============================================================================
