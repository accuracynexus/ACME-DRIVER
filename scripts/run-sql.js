const { Client } = require('pg');
require('dotenv').config({ path: './.env' });

const dbUrl = process.env.SUPABASE_DB_URL;

if (!dbUrl) {
  console.error('Missing SUPABASE_DB_URL in .env');
  process.exit(1);
}

const client = new Client({
  connectionString: dbUrl,
});

async function runSQL(sql) {
  try {
    await client.connect();
    const res = await client.query(sql);
    console.log('SQL executed successfully:');
    console.log(res.rows);
  } catch (error) {
    console.error('Error executing SQL:', error);
  } finally {
    await client.end();
  }
}

// Example usage: node scripts/run-sql.js "SELECT * FROM your_table"
const sql = process.argv[2];
if (!sql) {
  console.log('Usage: node scripts/run-sql.js "<SQL query>"');
  process.exit(1);
}

runSQL(sql);