// Probe: storage buckets, order_evidences insert, chat RPC + messages as driver.
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: './.env' });

const admin = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);
const anon = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY);
const DRIVER = '9c633335-cf3b-40e1-b3b3-0f003dc61c9f';

const show = (label, { data, error }) =>
  console.log(`\n== ${label} ==\n` + (error ? 'ERROR: ' + (error.message || JSON.stringify(error)) : JSON.stringify(data, null, 1)?.slice(0, 2500)));

async function main() {
  // Buckets (admin)
  show('buckets', await admin.storage.listBuckets());

  await anon.auth.signInWithPassword({ email: 'driver.test@acme.dev', password: 'AcmeDriver123!' });

  // Find an order of this driver (delivered one from earlier test)
  const { data: myOrders } = await admin.from('orders').select('id,order_code,status').eq('current_driver_id', DRIVER).limit(3);
  console.log('\nmy orders:', JSON.stringify(myOrders));
  const orderId = myOrders?.[0]?.id;
  if (!orderId) return console.log('no order for driver');

  // Evidence insert as driver
  show('order_evidences insert (driver)', await anon.from('order_evidences').insert({
    order_id: orderId, driver_id: DRIVER, evidence_type: 'delivery_photo',
    file_url: 'https://example.com/test.jpg', note: 'probe',
  }).select());

  // Chat RPC
  const conv = await anon.rpc('get_or_create_order_conversation', { p_order_id: orderId });
  show('get_or_create_order_conversation', conv);
  const convId = conv.data;
  if (convId) {
    show('participants', await anon.from('conversation_participants').select('*').eq('conversation_id', convId));
    show('send message (driver)', await anon.from('messages').insert({
      conversation_id: convId, sender_id: DRIVER, message_type: 'text', content: 'Hola, soy tu repartidor (probe)',
    }).select());
    show('read messages', await anon.from('messages').select('*').eq('conversation_id', convId).order('created_at'));
    show('conversations (mine)', await anon.from('conversations').select('*').eq('id', convId));
  }

  // Storage upload test as driver (try likely buckets)
  const { data: buckets } = await admin.storage.listBuckets();
  for (const b of buckets || []) {
    const path = `evidence-probe/${Date.now()}.txt`;
    const res = await anon.storage.from(b.name).upload(path, Buffer.from('probe'), { contentType: 'text/plain' });
    console.log(`upload to '${b.name}':`, res.error ? 'ERROR: ' + res.error.message : 'OK ' + res.data.path);
    if (!res.error) await admin.storage.from(b.name).remove([path]);
  }
}
main().catch(console.error);
