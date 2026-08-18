// Aplica el catálogo de métodos de pago acordado: solo queda activo lo que
// el checkout de Culqi realmente puede cobrar (tarjeta online y Yape).
// Usage: node scripts/apply-payment-catalog.js [--dry-run] [--rollback]
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: './.env' });

const admin = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);
const dryRun = process.argv.includes('--dry-run');
const rollback = process.argv.includes('--rollback');

// Códigos que se desactivan y por qué.
const DISABLE = {
  cash: 'decisión de negocio: no se acepta efectivo',
  card_pos: 'decisión de negocio: no se acepta tarjeta contra entrega',
  plin: 'el checkout de Culqi no ofrece Plin (CartPage.tsx: paymentMethods)',
};

const show = async (label) => {
  const { data } = await admin
    .from('payment_methods')
    .select('code, name, is_online, is_active')
    .order('code');
  console.log(`\n--- ${label} ---`);
  for (const m of data) {
    console.log(
      `  ${m.code.padEnd(12)} ${String(m.is_active ? 'ACTIVO' : 'inactivo').padEnd(9)}` +
      ` is_online=${m.is_online}`
    );
  }
  return data;
};

async function main() {
  await show('antes');

  if (dryRun) return console.log('\n(dry-run, no se modificó nada)');

  const codes = Object.keys(DISABLE);
  const { error } = await admin
    .from('payment_methods')
    .update({ is_active: rollback })
    .in('code', codes);

  if (error) return console.error('ERROR:', error.message);
  console.log(
    `\n${rollback ? 'Reactivados' : 'Desactivados'}: ${codes.join(', ')}`
  );
  if (!rollback) {
    for (const [code, reason] of Object.entries(DISABLE)) {
      console.log(`  · ${code}: ${reason}`);
    }
  }

  const after = await show('después');
  const active = after.filter((m) => m.is_active).map((m) => m.code);
  const expected = rollback
    ? ['card_online', 'card_pos', 'cash', 'plin', 'yape']
    : ['card_online', 'yape'];
  const ok = JSON.stringify(active) === JSON.stringify(expected);
  console.log(
    `\n${ok ? '✅' : '❌'} Activos: ${active.join(', ')} (esperado: ${expected.join(', ')})`
  );
  process.exit(ok ? 0 : 1);
}

main().catch(console.error);
