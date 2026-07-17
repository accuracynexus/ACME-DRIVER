// Probe: authenticate as test driver and exercise driver RPCs / RLS reads.
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: './.env' });

const url = process.env.SUPABASE_URL;
const admin = createClient(url, process.env.SUPABASE_SERVICE_ROLE_KEY);
const anon = createClient(url, process.env.SUPABASE_ANON_KEY);

const TEST_EMAIL = 'driver.test@acme.dev';
const TEST_PASS = 'AcmeDriver123!';
const TEST_ID = '9c633335-cf3b-40e1-b3b3-0f003dc61c9f';

async function main() {
  // Ensure known password on the seed test driver
  const { error: upErr } = await admin.auth.admin.updateUserById(TEST_ID, {
    password: TEST_PASS,
    email_confirm: true,
  });
  if (upErr) console.log('updateUser error:', upErr.message);

  const { data: sess, error: siErr } = await anon.auth.signInWithPassword({
    email: TEST_EMAIL,
    password: TEST_PASS,
  });
  if (siErr) { console.log('signin error:', siErr.message); return; }
  console.log('signed in as', sess.user.email, sess.user.id);

  const show = async (label, p) => {
    const { data, error } = await p;
    console.log(`\n== ${label} ==`);
    if (error) console.log('ERROR:', error.message);
    else console.log(JSON.stringify(data, null, 1)?.slice(0, 3000));
  };

  await show('current_is_driver', anon.rpc('current_is_driver'));
  await show('dev_driver_loads', anon.rpc('dev_driver_loads'));
  await show('profiles (own)', anon.from('profiles').select('*').eq('user_id', TEST_ID));
  await show('drivers (own)', anon.from('drivers').select('*').eq('user_id', TEST_ID));
  await show('driver_current_state (own)', anon.from('driver_current_state').select('*').eq('driver_id', TEST_ID));
  await show('vehicles (own)', anon.from('vehicles').select('*').eq('driver_id', TEST_ID));
  await show('order_assignments (mine)', anon.from('order_assignments').select('*').eq('driver_id', TEST_ID).limit(5));
  await show('orders (visible)', anon.from('orders').select('id,order_code,status,current_driver_id').limit(5));
  await show('notifications (mine)', anon.from('notifications').select('*').eq('user_id', TEST_ID).limit(5));
  await show('merchant_branches (read)', anon.from('merchant_branches').select('id,name,lat,lng').limit(3));
  await show('order_delivery_details (read)', anon.from('order_delivery_details').select('*').limit(3));
  await show('driver_set_online(true)', anon.rpc('driver_set_online', { p_online: true, p_lat: -12.784, p_lng: -74.966 }));
  await show('driver_ping_location', anon.rpc('driver_ping_location', { p_lat: -12.784, p_lng: -74.966 }));
  await show('driver_settlements (mine)', anon.from('driver_settlements').select('*').eq('driver_id', TEST_ID).limit(3));
  await show('vehicle_types', anon.from('vehicle_types').select('*'));
}

main().catch(e => console.error(e));
