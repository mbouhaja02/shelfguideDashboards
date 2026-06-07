import type { ReactNode } from 'react';
import type { UserRole } from '../../contexts/AuthContext';
import { Sidebar } from './Sidebar';

export function DashboardLayout({
  role,
  className,
  error,
  refreshing,
  lastUpdated,
  children,
}: {
  role: UserRole;
  className: string;
  error?: string | null;
  refreshing?: boolean;
  lastUpdated?: Date | null;
  children: ReactNode;
}) {
  return (
    <main className={`app-frame ${className}`}>
      <Sidebar role={role} error={error} refreshing={refreshing} lastUpdated={lastUpdated} />
      <section className="workspace">{children}</section>
    </main>
  );
}
