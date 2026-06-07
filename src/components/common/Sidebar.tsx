import { useEffect, useState } from 'react';
import { useLocation } from 'react-router-dom';
import logoUrl from '../../assets/shelfguide-logo.jpeg';
import { useAuth, type UserRole } from '../../contexts/AuthContext';

interface SidebarProps {
  role: UserRole;
  error?: string | null;
  refreshing?: boolean;
  lastUpdated?: Date | null;
}

const roleContent: Record<UserRole, {
  brand: string;
  label: string;
  links: Array<{ hash: string; label: string }>;
}> = {
  chef: {
    brand: 'ShelfGuide Terrain',
    label: 'Chef de rayon',
    links: [
      { hash: 'overview', label: 'Tour terrain' },
      { hash: 'actions', label: 'Actions' },
      { hash: 'categories', label: 'Categories' },
      { hash: 'audits', label: 'Audits' },
      { hash: 'timeline', label: 'Evolution' },
    ],
  },
  manager: {
    brand: 'ShelfGuide',
    label: 'Manager cockpit',
    links: [
      { hash: 'overview', label: 'Vue magasin' },
      { hash: 'heatmap', label: 'Heatmap' },
      { hash: 'ranking', label: 'Priorites rayons' },
      { hash: 'alerts', label: 'Alertes' },
      { hash: 'audits', label: 'Derniers audits' },
      { hash: 'timeline', label: 'Evolution' },
    ],
  },
  hq: {
    brand: 'ShelfGuide HQ',
    label: 'Network command',
    links: [
      { hash: 'overview', label: 'Reseau' },
      { hash: 'stores', label: 'Magasins' },
      { hash: 'categories', label: 'Categories' },
      { hash: 'map', label: 'Carte' },
      { hash: 'objectives', label: 'Objectifs' },
      { hash: 'alerts', label: 'Alertes' },
      { hash: 'timeline', label: 'Evolution' },
    ],
  },
};

export function Sidebar({ role, error = null, refreshing = false, lastUpdated = null }: SidebarProps) {
  const { user, profile, signOut } = useAuth();
  const location = useLocation();
  const [hash, setHash] = useState(location.hash.slice(1) || 'overview');
  const content = roleContent[role];

  useEffect(() => {
    const updateHash = () => setHash(window.location.hash.slice(1) || 'overview');
    updateHash();
    window.addEventListener('hashchange', updateHash);
    return () => window.removeEventListener('hashchange', updateHash);
  }, [location.pathname]);

  return (
    <aside className="sidebar">
      <div className="brand">
        <div className="brand-mark logo-mark">
          <img src={logoUrl} alt="Logo ShelfGuide" />
        </div>
        <div>
          <strong>{content.brand}</strong>
          <span>{content.label}</span>
        </div>
      </div>

      <nav className="side-nav" aria-label={`Navigation ${content.label}`}>
        {content.links.map((link) => (
          <a
            className={hash === link.hash ? 'active' : ''}
            href={`/${role}#${link.hash}`}
            key={link.hash}
          >
            {link.label}
          </a>
        ))}
      </nav>

      <div className="sidebar-account">
        <div className="sidebar-user">
          <span>{(profile?.full_name || user?.email || role).slice(0, 2).toUpperCase()}</span>
          <div>
            <strong>{profile?.full_name || user?.email || 'Utilisateur'}</strong>
            <small>{content.label}</small>
          </div>
        </div>
        <button type="button" onClick={() => void signOut()}>Se deconnecter</button>
      </div>

      <div className={`sync-card ${error ? 'offline' : 'online'}`}>
        <span className="sync-dot" />
        <strong>{error ? 'Connexion a verifier' : refreshing ? 'Synchronisation' : 'Supabase live'}</strong>
        <small>
          {lastUpdated
            ? new Intl.DateTimeFormat('fr-FR', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' }).format(lastUpdated)
            : 'En attente'}
        </small>
      </div>
    </aside>
  );
}
