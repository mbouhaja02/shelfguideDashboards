import type { ReactNode } from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { roleHome, useAuth, type UserRole } from '../../contexts/AuthContext';
import { isSupabaseConfigured } from '../../services/supabase';
import { LoadingScreen } from './LoadingScreen';
import { PageHeader } from './PageHeader';
import { SurfaceCard } from './SurfaceCard';

function AccessError() {
  const { error, signOut, refreshProfile } = useAuth();

  return (
    <main className="access-error-page">
      <SurfaceCard>
        <PageHeader eyebrow="Acces ShelfGuide" title="Profil non autorise" subtitle={error ?? 'Role utilisateur indisponible.'} />
        <div className="access-error-actions">
          <button type="button" onClick={() => void refreshProfile()}>Recharger le profil</button>
          <button type="button" className="secondary" onClick={() => void signOut()}>Se deconnecter</button>
        </div>
      </SurfaceCard>
    </main>
  );
}

export function PublicOnlyRoute({ children }: { children: ReactNode }) {
  const { user, role, loading } = useAuth();

  if (loading) return <LoadingScreen />;
  if (user) return <Navigate to={role ? roleHome(role) : '/'} replace />;
  return children;
}

export function RootRedirect() {
  const { user, role, loading } = useAuth();

  if (loading) return <LoadingScreen />;
  if (!user) return <Navigate to="/login" replace />;
  if (!role) return <AccessError />;
  return <Navigate to={roleHome(role)} replace />;
}

export function RoleGuard({ role: expectedRole, children }: { role: UserRole; children: ReactNode }) {
  const { user, role, loading } = useAuth();
  const location = useLocation();

  if (!isSupabaseConfigured) return <AccessError />;
  if (loading) return <LoadingScreen />;
  if (!user) return <Navigate to="/login" replace state={{ from: location.pathname }} />;
  if (!role) return <AccessError />;
  if (role !== expectedRole) return <Navigate to={roleHome(role)} replace />;
  return children;
}
