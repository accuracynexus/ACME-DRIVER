# ACME-DRIVER

App Flutter para repartidores del ecosistema ACME PEDIDOS, conectada a Supabase.

## Funcionalidad

- **Auth**: login / registro multi-paso (crea el perfil con el RPC `register_driver`), recuperación de contraseña. Solo permite cuentas con rol `driver`.
- **Estado del repartidor**: toggle en línea / fuera de línea (`driver_set_online`). Mientras está en línea la app envía la ubicación cada 10 s (`driver_ping_location`).
- **Ofertas de pedidos**: los pedidos que el backend asigna (`order_assignments` en estado `assigned`) aparecen en la pestaña Pedidos y generan una notificación local en el dispositivo. Se pueden aceptar (`driver_accept_assignment`) o rechazar (`driver_reject_assignment`).
- **Entrega activa con mapa**: mapa (OpenStreetMap vía flutter_map, sin API key) con marcadores del local, punto de entrega y posición del repartidor en vivo. Botones para navegar (Google Maps) y llamar al cliente. Avance de estados: `driver_accepted → picked_up → on_the_way → delivered` (`driver_advance_order_status`).
- **Historial**: entregas completadas/canceladas desde `order_assignments`.
- **Ganancias**: resumen hoy / semana / total (suma de `delivery_fee` de entregas completadas) + liquidaciones (`driver_settlements`).
- **Notificaciones in-app**: lista desde la tabla `notifications` con marcar leído y badge de no leídas.

## Sincronización

La app refresca ofertas y pedido activo cada 12 s (polling) y además intenta suscribirse a Realtime sobre `order_assignments`. Si en el proyecto Supabase habilitan Realtime para las tablas `order_assignments` y `notifications` (Dashboard → Database → Replication → publicación `supabase_realtime`), las actualizaciones llegan al instante sin cambiar código.

## Configuración

1. Copia `.env.example` a `.env` y completa `SUPABASE_URL` y `SUPABASE_ANON_KEY`.
2. `flutter pub get`
3. `flutter run`

## Scripts de desarrollo (Node)

Requieren `npm install` y el `.env` con `SUPABASE_SERVICE_ROLE_KEY`:

- `node scripts/seed-test-order.js` — crea un pedido de prueba cerca del driver de prueba y lo despacha (genera la oferta). Úsalo para probar el flujo completo en la app.
- `node scripts/dev-probe.js` / `dev-probe2.js` / `dev-probe3.js` — diagnósticos del backend (RPCs, RLS, realtime).

Driver de prueba: `driver.test@acme.dev` / `AcmeDriver123!`

## Pendiente / futuro

- **Push FCM en segundo plano**: hoy las notificaciones son locales (la app debe estar abierta). Para push reales hace falta crear un proyecto Firebase, añadir `google-services.json`, reintroducir `firebase_messaging` y un backend que envíe los push (las filas ya quedan en `notifications` con `channel='push'` y `status='queued'`).
- Subida de evidencia de entrega (`order_evidences`) con foto.
- Chat del pedido (`get_or_create_order_conversation`, `messages`).
