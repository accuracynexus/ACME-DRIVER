// As the test driver: read offer with joins, accept, advance statuses.
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: './.env' });

const anon = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY);

const SELECT = `
  id, status, assigned_at, accepted_at,
  order:orders (
    id, order_code, status, total, delivery_fee, subtotal, special_instructions, placed_at,
    branch:merchant_branches ( id, name, phone, lat, lng ),
    delivery:order_delivery_details ( address_snapshot, reference_snapshot, lat, lng, recipient_name, recipient_phone, estimated_distance_km, estimated_time_min ),
    items:order_items ( product_name_snapshot, quantity, unit_price, line_total )
  )`;

async function main() {
  await anon.auth.signInWithPassword({ email: 'driver.test@acme.dev', password: 'AcmeDriver123!' });

  const show = async (label, p) => {
    const { data, error } = await p;
    console.log(`\n== ${label} ==`);
    console.log(error ? 'ERROR: ' + error.message : JSON.stringify(data, null, 1)?.slice(0, 4000));
    return data;
  };

  const offers = await show('offers (assigned to me)',
    anon.from('order_assignments').select(SELECT).eq('status', 'assigned'));
  if (!offers?.length) return;
  const a = offers[0];

  await show('driver_accept_assignment', anon.rpc('driver_accept_assignment', { p_assignment_id: a.id }));
  await show('assignment after accept', anon.from('order_assignments').select('*').eq('id', a.id));
  await show('order after accept', anon.from('orders').select('id,status,current_driver_id').eq('id', a.order.id));
  await show('driver_current_state', anon.from('driver_current_state').select('*'));

  for (const st of ['picked_up', 'on_the_way', 'delivered']) {
    await show(`advance -> ${st}`, anon.rpc('driver_advance_order_status', { p_order_id: a.order.id, p_to_status: st }));
  }
  await show('order final', anon.from('orders').select('id,status,picked_up_at,delivered_at').eq('id', a.order.id));
  await show('assignment final', anon.from('order_assignments').select('*').eq('id', a.id));
  await show('state final', anon.from('driver_current_state').select('*'));
  await show('status history', anon.from('order_status_history').select('from_status,to_status,actor_type,created_at').eq('order_id', a.order.id).order('created_at'));
  await show('my notifications', anon.from('notifications').select('type,title,body,status,channel,created_at').order('created_at', { ascending: false }).limit(5));
}

main().catch(console.error);
