// Creates a test order near the test driver and dispatches it.
// Usage: node scripts/seed-test-order.js [--no-dispatch]
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: './.env' });

const admin = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);

async function main() {
  const { data: branch } = await admin.from('merchant_branches')
    .select('id,merchant_id,name,lat,lng').eq('name', 'Jugueria La Bahia de Ada').single();
  const { data: customer } = await admin.from('customers').select('user_id').limit(1).single();
  const { data: pm } = await admin.from('payment_methods').select('id').eq('code', 'cash').single();
  const { data: product } = await admin.from('products')
    .select('id,name,base_price').eq('merchant_id', branch.merchant_id).limit(1).maybeSingle();

  const subtotal = Number(product?.base_price ?? 20);
  const deliveryFee = 5;

  const { data: order, error: oErr } = await admin.from('orders').insert({
    customer_id: customer.user_id,
    merchant_id: branch.merchant_id,
    branch_id: branch.id,
    payment_method_id: pm.id,
    status: 'preparing',
    payment_status: 'pending',
    fulfillment_type: 'delivery',
    subtotal,
    delivery_fee: deliveryFee,
    total: subtotal + deliveryFee,
    currency: 'PEN',
    placed_at: new Date().toISOString(),
    special_instructions: 'Pedido de prueba ACME-DRIVER',
  }).select().single();
  if (oErr) { console.error('order insert:', oErr); return; }
  console.log('order created:', order.id, 'code', order.order_code);

  if (product) {
    await admin.from('order_items').insert({
      order_id: order.id, product_id: product.id,
      product_name_snapshot: product.name,
      unit_price: subtotal, quantity: 1, line_total: subtotal,
    });
  }

  // Delivery point ~500m from the branch (Huancavelica center)
  const { error: dErr } = await admin.from('order_delivery_details').insert({
    order_id: order.id,
    address_snapshot: 'Jr. Torre Tagle 340, Huancavelica',
    district_snapshot: 'Huancavelica',
    city_snapshot: 'Huancavelica',
    region_snapshot: 'Huancavelica',
    lat: -12.7891,
    lng: -74.9722,
    recipient_name: 'Cliente Prueba',
    recipient_phone: '999888777',
    estimated_distance_km: 0.8,
    estimated_time_min: 10,
  });
  if (dErr) console.error('delivery details:', dErr);

  const { data: ready, error: rErr } = await admin.rpc('dev_mark_order_ready', { p_order_id: order.id });
  console.log('dev_mark_order_ready:', rErr ? rErr.message : JSON.stringify(ready));

  if (!process.argv.includes('--no-dispatch')) {
    const { data: disp, error: dispErr } = await admin.rpc('dispatch_order', { p_order_id: order.id });
    console.log('dispatch_order:', dispErr ? dispErr.message : JSON.stringify(disp));
  }

  const { data: asg } = await admin.from('order_assignments').select('*').eq('order_id', order.id);
  console.log('assignments:', JSON.stringify(asg, null, 1));
  const { data: o2 } = await admin.from('orders').select('id,status,current_driver_id').eq('id', order.id).single();
  console.log('order after:', JSON.stringify(o2));
  const { data: notifs } = await admin.from('notifications').select('user_id,type,title,body,entity_id').order('created_at', { ascending: false }).limit(3);
  console.log('recent notifications:', JSON.stringify(notifs, null, 1));
}

main().catch(console.error);
