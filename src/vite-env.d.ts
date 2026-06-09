/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_SUPABASE_URL?: string;
  readonly VITE_SUPABASE_ANON_KEY?: string;
  readonly VITE_SUPABASE_PUBLISHABLE_KEY?: string;
  readonly VITE_STORE_NAME?: string;
  readonly VITE_CATEGORY?: string;
  readonly VITE_PEAK_HOUR?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
