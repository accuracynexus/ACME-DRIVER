# Backend ACME-DRIVER (Supabase)

Migraciones SQL que habilitan la app del repartidor sobre la base de datos
compartida del ecosistema **ACME PEDIDOS**. Son **aditivas**: crean funciones,
políticas RLS y un bucket de storage. **No alteran ni borran columnas/tablas existentes.**

## Orden de ejecución

Ejecuta los archivos en orden en el **SQL Editor** de Supabase
(Dashboard → SQL Editor → New query → pegar → Run):

| Archivo | Qué hace |
|---|---|
| `migrations/001_storage_driver_documents.sql` | Bucket privado `driver-documents` + políticas + `is_admin()` |
| `migrations/002_dispatch.sql` | Lógica de asignación (oferta + balanceo distancia/carga) y RPCs del repartidor |
| `migrations/003_rls.sql` | Políticas RLS para el rol `driver` |
| `migrations/004_cron.sql` | pg_cron: expira ofertas y auto-despacha (requiere extensión pg_cron) |
| `migrations/005_dev_helpers.sql` | *(opcional, solo desarrollo)* helpers de prueba |

> Si `004_cron.sql` falla porque tu pg_cron no acepta intervalos en segundos,
> cambia `'30 seconds'`/`'15 seconds'` por `'* * * * *'`.

## Cómo funciona la asignación (dispatch)

Modelo **oferta con timeout**:

1. Un pedido pasa a `ready_for_pickup` (lo hace la app del comercio, o
   `dev_mark_order_ready` en pruebas).
2. `dispatch_order(order_id)` elige al **mejor repartidor**:
   - Filtra: `is_verified`, perfil `is_active`, `is_online`, estado `available`,
     dentro del radio máximo, sin otra oferta pendiente, sin haber rechazado ese pedido,
     y por debajo del tope de pedidos simultáneos.
   - **Score = peso_distancia · distancia_norm + peso_carga · carga_norm** (menor = mejor).
     La carga (`_driver_active_load`) reparte el trabajo: quien tiene menos pedidos es preferido.
   - Crea la oferta en `order_assignments` y notifica al repartidor.
3. El repartidor **acepta** (`driver_accept_assignment`) o **rechaza**
   (`driver_reject_assignment`). Si no responde, `expire_stale_offers` (cron)
   la vence y reasigna al siguiente.

### Parámetros ajustables (tabla `system_settings`)

| key | default | significado |
|---|---|---|
| `dispatch_offer_timeout_seconds` | 45 | segundos para aceptar |
| `dispatch_max_radius_km` | 8 | radio máximo de oferta |
| `dispatch_max_concurrent_orders` | 3 | tope de pedidos activos por repartidor |
| `dispatch_weight_distance` | 0.6 | peso de la distancia |
| `dispatch_weight_load` | 0.4 | peso de la carga (balanceo) |

Edita `value_json` para cambiarlos en caliente.

## Aprobación de repartidores (admin)

Al registrarse, el repartidor queda con `drivers.is_verified = false` y sus
documentos en `driver_documents.status = 'pending'`. La app lo deja en pantalla
**"Cuenta en revisión"**.

Para **habilitarlo**, el administrador (rol `admin`/`super_admin`) revisa los
documentos y ejecuta:

```sql
-- Aprobar documentos
update driver_documents set status = 'approved', updated_at = now()
where driver_id = '<USER_ID>';

-- Habilitar al repartidor
update drivers set is_verified = true, updated_at = now()
where user_id = '<USER_ID>';
```

## Prueba rápida del flujo (desarrollo)

```sql
-- 1) Ver carga de repartidores
select * from dev_driver_loads();

-- 2) Despachar un pedido existente (lo pone ready y ofrece al mejor)
select dev_mark_order_ready('<ORDER_ID>');

-- 3) Ver la oferta creada
select * from order_assignments where order_id = '<ORDER_ID>' order by assigned_at desc;
```
