import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from 'react';
import type { Session, User } from '@supabase/supabase-js';
import { isSupabaseConfigured, supabaseClient } from '../services/supabase';

export type UserRole = 'chef' | 'manager' | 'hq';

export interface UserProfile {
  id: string;
  role: UserRole;
  full_name: string | null;
  created_at: string;
  updated_at: string;
}

interface AuthContextValue {
  session: Session | null;
  user: User | null;
  profile: UserProfile | null;
  role: UserRole | null;
  loading: boolean;
  error: string | null;
  signIn: (email: string, password: string) => Promise<void>;
  signOut: () => Promise<void>;
  refreshProfile: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | null>(null);

function isRole(value: unknown): value is UserRole {
  return value === 'chef' || value === 'manager' || value === 'hq';
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const requestId = useRef(0);

  const loadProfile = useCallback(async (userId: string | null) => {
    const currentRequest = ++requestId.current;

    if (!userId || !supabaseClient) {
      setProfile(null);
      setLoading(false);
      return;
    }

    setLoading(true);
    setError(null);

    const { data, error: profileError } = await supabaseClient
      .from('profiles')
      .select('id, role, full_name, created_at, updated_at')
      .eq('id', userId)
      .maybeSingle();

    if (currentRequest !== requestId.current) return;

    if (profileError) {
      setProfile(null);
      setError(`Profil utilisateur inaccessible : ${profileError.message}`);
    } else if (!data || !isRole(data.role)) {
      setProfile(null);
      setError('Aucun role ShelfGuide valide n’est associe a ce compte.');
    } else {
      setProfile(data as UserProfile);
    }

    setLoading(false);
  }, []);

  useEffect(() => {
    if (!supabaseClient) {
      setError('Configuration Supabase manquante.');
      setLoading(false);
      return;
    }

    let mounted = true;

    void supabaseClient.auth.getSession().then(({ data, error: sessionError }) => {
      if (!mounted) return;
      if (sessionError) {
        setError(sessionError.message);
        setLoading(false);
        return;
      }

      setSession(data.session);
      void loadProfile(data.session?.user.id ?? null);
    });

    const {
      data: { subscription },
    } = supabaseClient.auth.onAuthStateChange((_event, nextSession) => {
      if (!mounted) return;
      setSession(nextSession);
      window.setTimeout(() => {
        if (mounted) void loadProfile(nextSession?.user.id ?? null);
      }, 0);
    });

    return () => {
      mounted = false;
      subscription.unsubscribe();
    };
  }, [loadProfile]);

  const signIn = useCallback(async (email: string, password: string) => {
    if (!supabaseClient) throw new Error('Configuration Supabase manquante.');

    setError(null);
    const { error: signInError } = await supabaseClient.auth.signInWithPassword({
      email: email.trim(),
      password,
    });

    if (signInError) throw signInError;
  }, []);

  const signOut = useCallback(async () => {
    if (!supabaseClient) return;
    const { error: signOutError } = await supabaseClient.auth.signOut();
    if (signOutError) throw signOutError;
  }, []);

  const refreshProfile = useCallback(async () => {
    await loadProfile(session?.user.id ?? null);
  }, [loadProfile, session?.user.id]);

  const value = useMemo<AuthContextValue>(
    () => ({
      session,
      user: session?.user ?? null,
      profile,
      role: profile?.role ?? null,
      loading,
      error,
      signIn,
      signOut,
      refreshProfile,
    }),
    [session, profile, loading, error, signIn, signOut, refreshProfile],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const context = useContext(AuthContext);
  if (!context) throw new Error('useAuth doit etre utilise dans AuthProvider.');
  return context;
}

export function roleHome(role: UserRole): string {
  return `/${role}`;
}
