import type { GroupKey } from './dashboard';

export const dashboardConfig = {
  title: 'Dashboard manager magasin',
  subtitle: 'Vue magasin, priorites operationnelles et performance par rayon.',
  eyebrow: 'ShelfGuide magasin',
  scopeLabel: 'Perimetre manager magasin',
  storeName: import.meta.env.VITE_STORE_NAME?.trim() || '',
  category: '',
  primaryGroup: 'shelf_name' as GroupKey,
  primaryTitle: 'Classement des rayons',
  secondaryGroup: 'category' as GroupKey,
  secondaryTitle: 'Performance par categorie',
  riskTitle: 'Escalades magasin',
  recentTitle: 'Activite recente',
  limit: 500,
  refreshMs: 15000,
  // Hypotheses ajustables pour la valorisation business reseau.
  costPerFacing: 65, // MAD de CA potentiel/jour par facing vide
  minPerManualAudit: 12, // minutes economisees par audit automatise vs manuel
  networkLabel: 'Reseau Franprix - Maroc',
  peakHour: import.meta.env.VITE_PEAK_HOUR?.trim() || '17:30',
  teamMembers: (() => {
    const configured = import.meta.env.VITE_TEAM_MEMBERS?.split(',').map((name: string) => name.trim()).filter(Boolean) ?? [];
    return configured.length > 0 ? configured.slice(0, 8) : ['Equipe A', 'Equipe B'];
  })(),
};
