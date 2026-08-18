// Audita, contra los pedidos REALES, qué le diría la app al repartidor sobre
// el cobro. Compara la regla anterior (bug de doble cobro) con la actual.
// Usage: node scripts/audit-payments.js
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: './.env' });

const admin = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);

// Regla anterior (order.dart, antes del fix)
const oldRule = (o) =>
  o.payment_status !== 'paid' && (o.payment_method?.code ?? '') !== 'card_online';

// Regla actual: solo se cobra contra entrega (is_online = false) y sin pagar.
const newAction = (o) => {
  if (o.payment_status === 'paid') return 'PAGADO';
  if (o.payment_method?.is_online === false) return 'COBRAR';
  if (o.payment_method?.is_online === true) return 'PAGADO EN LÍNEA';
  return 'VERIFICAR';
};

async function main() {
  const { data: orders, error } = await admin
    .from('orders')
    .select('order_code, status, payment_status, total, payment_method:payment_methods(code,name,is_online)')
    .order('created_at', { ascending: false })
    .limit(50);
  if (error) return console.error(error.message);

  let doubleCharges = 0;
  console.log('pedido | estado           | método      | ANTES   | AHORA');
  console.log('-------|------------------|-------------|---------|----------------');
  for (const o of orders) {
    const before = oldRule(o) ? 'cobrar' : 'no';
    const after = newAction(o);
    const wrong = before === 'cobrar' && after !== 'COBRAR';
    if (wrong) doubleCharges++;
    console.log(
      `#${String(o.order_code).padEnd(5)} | ${String(o.status).padEnd(16)} | ` +
      `${String(o.payment_method?.code ?? '(ninguno)').padEnd(11)} | ` +
      `${before.padEnd(7)} | ${after}${wrong ? '   ← evitaba doble cobro' : ''}`
    );
  }

  console.log(
    `\nPedidos en los que la regla anterior habría hecho cobrar de más: ${doubleCharges}`
  );
  const collect = orders.filter((o) => newAction(o) === 'COBRAR');
  console.log(`Pedidos que sí requieren cobro contra entrega: ${collect.length}` +
    (collect.length ? ` (${collect.map((o) => '#' + o.order_code).join(', ')})` : ''));
}

main().catch(console.error);
