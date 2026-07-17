// Verificación end-to-end del recorrido del driver con las MISMAS
// consultas que usa la app Flutter. Requiere .env con service role.
// Usage: node scripts/verify-e2e.js
const { execSync } = require('child_process');
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: './.env' });

const admin = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);
const anon = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY);
const DRIVER = '9c633335-cf3b-40e1-b3b3-0f003dc61c9f';

// SELECT idéntico al de order_remote_datasource.dart
const SELECT = `
  id, order_id, status, assigned_at, accepted_at, completed_at,
  order:orders (
    id, order_code, status, subtotal, delivery_fee, total,
    payment_status, special_instructions, placed_at,
    payment_method:payment_methods ( code, name ),
    branch:merchant_branches ( id, name, phone, lat, lng ),
    delivery:order_delivery_details ( address_snapshot, reference_snapshot,
      lat, lng, recipient_name, recipient_phone,
      estimated_distance_km, estimated_time_min ),
    items:order_items ( product_name_snapshot, quantity, unit_price, line_total )
  )`;

let failures = 0;
const check = (label, ok, detail = '') => {
  console.log(`${ok ? '✅' : '❌'} ${label}${detail ? ' — ' + detail : ''}`);
  if (!ok) failures++;
};

// JPEG mínimo válido (1x1)
const TINY_JPEG = Buffer.from(
  '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AKp//2Q==',
  'base64');

async function main() {
  // 1. Login
  const { data: sess, error: siErr } = await anon.auth.signInWithPassword({
    email: 'driver.test@acme.dev', password: 'AcmeDriver123!' });
  check('Login driver', !siErr, siErr?.message);

  // 2. Perfil (queries de auth_remote_datasource)
  const { data: profile } = await anon.from('profiles').select().eq('user_id', DRIVER).maybeSingle();
  check('Perfil con rol driver', profile?.default_role === 'driver');
  const { data: driverRow } = await anon.from('drivers')
    .select('*, vehicle_type:vehicle_types(code, name)').eq('user_id', DRIVER).maybeSingle();
  check('Fila drivers + vehicle_type', !!driverRow?.vehicle_type?.name, driverRow?.vehicle_type?.name);

  // 3. Online + ping
  const on = await anon.rpc('driver_set_online', { p_online: true, p_lat: -12.7845, p_lng: -74.9666 });
  check('driver_set_online', !on.error, on.error?.message);
  const ping = await anon.rpc('driver_ping_location', { p_lat: -12.7845, p_lng: -74.9666, p_accuracy: 5, p_speed: 12, p_heading: 90 });
  check('driver_ping_location', !ping.error, ping.error?.message);
  const { data: st } = await anon.from('driver_current_state').select().eq('driver_id', DRIVER).single();
  check('Estado disponible y ubicado', st?.is_online === true && Number(st?.last_lat).toFixed(3) === '-12.784' + '', `lat=${st?.last_lat}`);

  // 4. Sembrar y despachar pedido nuevo
  execSync('node scripts/seed-test-order.js', { stdio: 'pipe' });

  // 5. Ofertas (query de la app)
  const { data: offers, error: offErr } = await anon.from('order_assignments')
    .select(SELECT).eq('driver_id', DRIVER).eq('status', 'assigned')
    .order('assigned_at', { ascending: false });
  check('Oferta visible con datos completos', !offErr && offers.length > 0, offErr?.message ?? `${offers?.length} ofertas`);
  const offer = offers[0];
  check('Oferta trae local con coords', !!offer?.order?.branch?.lat);
  check('Oferta trae punto de entrega', !!offer?.order?.delivery?.lat);
  check('Oferta trae método de pago', !!offer?.order?.payment_method?.code, offer?.order?.payment_method?.name);
  check('Oferta trae items', (offer?.order?.items?.length ?? 0) > 0);

  // 6. Aceptar
  const acc = await anon.rpc('driver_accept_assignment', { p_assignment_id: offer.id });
  check('driver_accept_assignment', !acc.error, acc.error?.message);
  const orderId = offer.order.id;

  // 7. Entrega activa (query de la app)
  const { data: active } = await anon.from('order_assignments').select(SELECT)
    .eq('driver_id', DRIVER).eq('status', 'accepted')
    .order('accepted_at', { ascending: false }).limit(1);
  check('Entrega activa visible', active?.length === 1 && active[0].order.status === 'driver_accepted', active?.[0]?.order?.status);

  // 8. Chat
  const conv = await anon.rpc('get_or_create_order_conversation', { p_order_id: orderId });
  check('Conversación del pedido', !conv.error && !!conv.data, conv.error?.message);
  const msg = await anon.from('messages').insert({
    conversation_id: conv.data, sender_user_id: DRIVER, message_type: 'text',
    body: 'Voy en camino a recoger tu pedido 🛵' }).select().single();
  check('Enviar mensaje de chat', !msg.error, msg.error?.message);
  const { data: msgs } = await anon.from('messages').select().eq('conversation_id', conv.data).order('created_at');
  check('Leer mensajes del chat', (msgs?.length ?? 0) > 0, `${msgs?.length} mensajes`);

  // 9. Avanzar estados con ping intermedio (como hace la app)
  for (const s of ['picked_up', 'on_the_way']) {
    const r = await anon.rpc('driver_advance_order_status', { p_order_id: orderId, p_to_status: s });
    check(`Avance a ${s}`, !r.error, r.error?.message);
    await anon.rpc('driver_ping_location', { p_lat: -12.786, p_lng: -74.970, p_order_id: orderId });
  }

  // 10. Evidencia (igual que evidence_service.dart)
  const path = `${DRIVER}/evidence-${orderId}-${Date.now()}.jpg`;
  const up = await anon.storage.from('driver-documents').upload(path, TINY_JPEG, { contentType: 'image/jpeg' });
  check('Subir foto de evidencia', !up.error, up.error?.message);
  const signed = await anon.storage.from('driver-documents').createSignedUrl(path, 60 * 60 * 24 * 365 * 5);
  check('URL firmada de evidencia', !signed.error, signed.error?.message);
  const ev = await anon.from('order_evidences').insert({
    order_id: orderId, driver_id: DRIVER, evidence_type: 'delivery_photo',
    file_url: signed.data.signedUrl }).select();
  check('Registrar order_evidences', !ev.error, ev.error?.message);

  // 11. Entregar
  const del = await anon.rpc('driver_advance_order_status', { p_order_id: orderId, p_to_status: 'delivered' });
  check('Entrega final', !del.error, del.error?.message);
  const { data: finalOrder } = await admin.from('orders').select('status,delivered_at').eq('id', orderId).single();
  check('Pedido delivered en BD', finalOrder?.status === 'delivered');
  const { data: st2 } = await anon.from('driver_current_state').select().eq('driver_id', DRIVER).single();
  check('Driver liberado (available)', st2?.status === 'available' && st2?.current_order_id === null);

  // 12. Historial y rastro para las otras apps
  const { data: hist } = await anon.from('order_assignments').select(SELECT)
    .eq('driver_id', DRIVER).in('status', ['completed', 'cancelled'])
    .order('assigned_at', { ascending: false }).limit(50);
  check('Historial con entregas', (hist?.length ?? 0) > 0, `${hist?.length} registros`);
  const { data: locs } = await admin.from('driver_locations').select('id').eq('order_id', orderId);
  check('Rastro GPS del pedido (driver_locations)', (locs?.length ?? 0) > 0, `${locs?.length} pings`);
  const { data: shist } = await admin.from('order_status_history').select('to_status').eq('order_id', orderId).order('created_at');
  check('Historial de estados completo', JSON.stringify(shist?.map(h => h.to_status).slice(-4)) === JSON.stringify(['driver_accepted', 'picked_up', 'on_the_way', 'delivered']));

  // 13. Dejar una oferta fresca para probar la app manualmente
  execSync('node scripts/seed-test-order.js', { stdio: 'pipe' });
  const { data: fresh } = await anon.from('order_assignments').select('id,order:orders(order_code)').eq('driver_id', DRIVER).eq('status', 'assigned');
  check('Oferta fresca lista para la app', (fresh?.length ?? 0) > 0, `pedido #${fresh?.[0]?.order?.order_code}`);

  console.log(failures === 0 ? '\n🎉 TODO OK' : `\n⚠️ ${failures} fallos`);
  process.exit(failures === 0 ? 0 : 1);
}
main().catch(e => { console.error(e); process.exit(1); });
