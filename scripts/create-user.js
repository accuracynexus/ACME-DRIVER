const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: './.env' });

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in .env');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function createUser(email, password, userData) {
  try {
    // Get all users and find by email
    const { data: users, error: listError } = await supabase.auth.admin.listUsers();
    if (listError) throw listError;

    const existingUser = users.users.find(u => u.email === email);
    let userId;

    if (existingUser) {
      console.log('User already exists:', existingUser.email, 'Confirmed:', existingUser.email_confirmed_at ? 'Yes' : 'No');
      userId = existingUser.id;
      
      // If not confirmed, confirm it
      if (!existingUser.email_confirmed_at) {
        const { error: confirmError } = await supabase.auth.admin.updateUserById(userId, {
          email_confirm: true,
        });
        if (confirmError) throw confirmError;
        console.log('User confirmed successfully');
      }
    } else {
      // Create new user
      const { data, error } = await supabase.auth.admin.createUser({
        email: email,
        password: password,
        user_metadata: userData,
        email_confirm: true,
      });

      if (error) throw error;
      userId = data.user.id;
      console.log('User created successfully:', data.user);
    }

    // Insert or update profile
    const { error: profileError } = await supabase
      .from('profiles')
      .upsert({
        id: userId,
        full_name: userData.name,
        phone: userData.phone,
        role: 'driver', // Assuming role
      });

    if (profileError) throw profileError;
    console.log('Profile updated/created successfully');

    // Insert or update driver
    const { error: driverError } = await supabase
      .from('drivers')
      .upsert({
        user_id: userId,
        vehicle_type: userData.vehicle_type,
        status: 'available', // Assuming
        is_active: true,
      });

    if (driverError) throw driverError;
    console.log('Driver record updated/created successfully');

  } catch (error) {
    console.error('Error:', error);
  }
}

// Usage: node scripts/create-user.js
const email = 'maansuor1sj@gmail.com';
const password = 'Max123';
const userData = {
  name: 'Max Sulca',
  phone: '997168966',
  vehicle_type: 'bicicleta',
};

createUser(email, password, userData);