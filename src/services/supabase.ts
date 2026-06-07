import { createClient, type SupabaseClient } from '@supabase/supabase-js';

const env = import.meta.env;

const supabaseUrl = (
  env.VITE_SUPABASE_URL ??
  env.NEXT_PUBLIC_SUPABASE_URL ??
  ''
).trim();

const supabaseAnonKey = (
  env.VITE_SUPABASE_ANON_KEY ??
  env.VITE_SUPABASE_PUBLISHABLE_KEY ??
  env.NEXT_PUBLIC_SUPABASE_ANON_KEY ??
  env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ??
  ''
).trim();

export const isSupabaseConfigured = Boolean(supabaseUrl && supabaseAnonKey);

export const supabaseClient: SupabaseClient | null = isSupabaseConfigured
  ? createClient(supabaseUrl, supabaseAnonKey, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: true,
      },
    })
  : null;
