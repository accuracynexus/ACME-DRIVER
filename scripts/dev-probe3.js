// Verify realtime subscriptions + notification read update as driver.
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: './.env' });

const anon = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY);
const admin = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);
const TEST_ID = '9c633335-cf3b-40e1-b3b3-0f003dc61c9f';

async function main() {
  await anon.auth.signInWithPassword({ email: 'driver.test@acme.dev', password: 'AcmeDriver123!' });
  await anon.realtime.setAuth();

  let gotNotif = false, gotAssign = false;
  const ch = anon.channel('probe')
    .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'notifications', filter: `user_id=eq.${TEST_ID}` },
      p => { gotNotif = true; console.log('REALTIME notification:', p.new.title); })
    .on('postgres_changes', { event: '*', schema: 'public', table: 'order_assignments', filter: `driver_id=eq.${TEST_ID}` },
      p => { gotAssign = true; console.log('REALTIME assignment:', p.eventType, p.new?.status); })
    .subscribe(s => console.log('channel status:', s));

  await new Promise(r => setTimeout(r, 3000));

  console.log('inserting test notification via admin...');
  const { data: n, error } = await admin.from('notifications').insert({
    user_id: TEST_ID, channel: 'in_app', type: 'test', title: 'Probe', body: 'realtime test', status: 'queued',
  }).select().single();
  if (error) console.log('insert err', error.message);

  await new Promise(r => setTimeout(r, 5000));
  console.log('gotNotif:', gotNotif, 'gotAssign(untested-insert):', gotAssign);

  // driver marks notification read
  const { data: upd, error: uErr } = await anon.from('notifications')
    .update({ status: 'read', read_at: new Date().toISOString() })
    .eq('id', n.id).select();
  console.log('mark read:', uErr ? 'ERROR ' + uErr.message : JSON.stringify(upd));

  await admin.from('notifications').delete().eq('id', n.id);
  process.exit(0);
}
main().catch(console.error);
