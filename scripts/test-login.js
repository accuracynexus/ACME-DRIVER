const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: './.env' });

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  console.error('Missing SUPABASE_URL or SUPABASE_ANON_KEY in .env');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseAnonKey);

async function testLogin(email, password) {
  try {
    console.log('Attempting to sign in...');
    const { data, error } = await supabase.auth.signInWithPassword({
      email: email,
      password: password,
    });

    if (error) throw error;

    console.log('Login successful!');
    console.log('User:', data.user.email);
    console.log('Session:', data.session ? 'Active' : 'None');

    // Test fetching profile
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', data.user.id)
      .single();

    if (profileError) throw profileError;
    console.log('Profile:', profile);

    // Test fetching driver
    const { data: driver, error: driverError } = await supabase
      .from('drivers')
      .select('*')
      .eq('user_id', data.user.id);

    if (driverError) throw driverError;
    console.log('Driver:', driver);

  } catch (error) {
    console.error('Login failed:', error.message);
  }
}

// Test with the created user
const email = 'maansuor1sj@gmail.com';
const password = 'Max123';

testLogin(email, password);