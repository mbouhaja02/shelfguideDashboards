import { createClient } from '@supabase/supabase-js';
import { config } from 'dotenv';

config({ path: '.env.demo.local' });
config();

const supabaseUrl = process.env.SUPABASE_URL;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !serviceRoleKey) {
  throw new Error(
    'Define SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in .env.demo.local. Never prefix the service key with VITE_.',
  );
}

const accounts = [
  {
    role: 'chef',
    email: process.env.DEMO_CHEF_EMAIL ?? 'chef.demo@shelfguide.ma',
    password: process.env.DEMO_CHEF_PASSWORD,
    fullName: process.env.DEMO_CHEF_NAME ?? 'Chef de rayon pilote',
  },
  {
    role: 'manager',
    email: process.env.DEMO_MANAGER_EMAIL ?? 'manager.demo@shelfguide.ma',
    password: process.env.DEMO_MANAGER_PASSWORD,
    fullName: process.env.DEMO_MANAGER_NAME ?? 'Manager magasin pilote',
  },
  {
    role: 'hq',
    email: process.env.DEMO_HQ_EMAIL ?? 'hq.demo@shelfguide.ma',
    password: process.env.DEMO_HQ_PASSWORD,
    fullName: process.env.DEMO_HQ_NAME ?? 'Direction ShelfGuide',
  },
];

for (const account of accounts) {
  if (!account.password || account.password.length < 12) {
    throw new Error(`A password of at least 12 characters is required for ${account.role}.`);
  }
}

const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false,
  },
});

async function findUser(email) {
  for (let page = 1; page <= 20; page += 1) {
    const { data, error } = await supabase.auth.admin.listUsers({ page, perPage: 100 });
    if (error) throw error;
    const user = data.users.find((candidate) => candidate.email?.toLowerCase() === email.toLowerCase());
    if (user) return user;
    if (data.users.length < 100) return null;
  }
  return null;
}

async function upsertUser(account) {
  const existing = await findUser(account.email);
  if (existing) {
    const { data, error } = await supabase.auth.admin.updateUserById(existing.id, {
      password: account.password,
      email_confirm: true,
      app_metadata: { ...existing.app_metadata, role: account.role },
      user_metadata: { ...existing.user_metadata, full_name: account.fullName },
    });
    if (error) throw error;
    return data.user;
  }

  const { data, error } = await supabase.auth.admin.createUser({
    email: account.email,
    password: account.password,
    email_confirm: true,
    app_metadata: { role: account.role },
    user_metadata: { full_name: account.fullName },
  });
  if (error) throw error;
  return data.user;
}

const users = new Map();
for (const account of accounts) {
  const user = await upsertUser(account);
  users.set(account.role, user);

  const { error } = await supabase
    .from('profiles')
    .upsert({
      id: user.id,
      role: account.role,
      full_name: account.fullName,
    });
  if (error) throw error;
}

const { data: store, error: storeError } = await supabase
  .from('stores')
  .select('id')
  .eq('code', 'CASA-PILOT-001')
  .single();
if (storeError) throw storeError;

const membershipRows = ['chef', 'manager'].map((role) => ({
  store_id: store.id,
  user_id: users.get(role).id,
  member_role: role,
  is_active: true,
}));

const { error: membershipError } = await supabase
  .from('store_members')
  .upsert(membershipRows, { onConflict: 'store_id,user_id' });
if (membershipError) throw membershipError;

const { data: shelves, error: shelfError } = await supabase
  .from('shelves')
  .select('id')
  .eq('store_id', store.id)
  .eq('is_active', true);
if (shelfError) throw shelfError;

const chefId = users.get('chef').id;
const { error: shelfMembershipError } = await supabase
  .from('shelf_members')
  .upsert(
    shelves.map((shelf) => ({
      shelf_id: shelf.id,
      user_id: chefId,
      is_active: true,
    })),
    { onConflict: 'shelf_id,user_id' },
  );
if (shelfMembershipError) throw shelfMembershipError;

console.log('Pilot users and memberships are ready.');
