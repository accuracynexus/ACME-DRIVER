// Cancela los pedidos de prueba creados por seed-test-order.js que quedaron
// vivos en la BD. Solo toca filas marcadas como prueba, para no rozar nunca
// un pedido real.
// Usage: node scripts/cleanup-test-orders.js [--dry-run]
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: './.env' });

const admin = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);
const MARKER = 'Pedido de prueba ACME-DRIVER';
const dryRun = process.argv.includes('--dry-run');

async function main() {
  const { data: orders, error } = await admin
    .from('orders')
    .select('id, order_code, status, special_instructions, total')
    .eq('special_instructions', MARKER)
    .not('status', 'in', '(delivered,cancelled,failed)');

  if (error) return console.error(error.message);
  if (!orders.length) return console.log('No hay pedidos de prueba vivos.');

  console.log(`Pedidos de prueba vivos: ${orders.map((o) => '#' + o.order_code).join(', ')}`);
  if (dryRun) return console.log('(dry-run, no se modificó nada)');

  for (const o of orders) {
    // Guarda de seguridad: nunca tocar algo que no lleve la marca de prueba.
    if (o.special_instructions !== MARKER) continue;

    const { error: upErr } = await admin
      .from('orders')
      .update({ status: 'cancelled', cancelled_at: new Date().toISOString() })
      .eq('id', o.id);

    if (upErr) {
      console.log(`  #${o.order_code}: ERROR ${upErr.message}`);
      continue;
    }

    // Liberar la oferta asociada para que no quede colgada.
    await admin
      .from('order_assignments')
      .update({ status: 'cancelled', reason: 'Pedido de prueba cancelado' })
      .eq('order_id', o.id)
      .in('status', ['assigned', 'accepted']);

    console.log(`  #${o.order_code}: cancelado`);
  }
}

main().catch(console.error);
