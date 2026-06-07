import { lazy, Suspense, type ReactNode } from 'react';
import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import { LoadingScreen } from './components/common/LoadingScreen';
import { PublicOnlyRoute, RoleGuard, RootRedirect } from './components/common/RouteGuards';
import LoginPage from './pages/Auth/LoginPage';

const ChefDashboard = lazy(() => import('./pages/Chef/ChefDashboard'));
const ManagerDashboard = lazy(() => import('./pages/Manager/ManagerDashboard'));
const HQDashboard = lazy(() => import('./pages/HQ/HQDashboard'));

function LazyPage({ children }: { children: ReactNode }) {
  return <Suspense fallback={<LoadingScreen />}>{children}</Suspense>;
}

export function AppRouter() {
  return (
    <BrowserRouter>
      <Routes>
        <Route
          path="/login"
          element={(
            <PublicOnlyRoute>
              <LoginPage />
            </PublicOnlyRoute>
          )}
        />
        <Route path="/" element={<RootRedirect />} />
        <Route
          path="/chef/*"
          element={(
            <RoleGuard role="chef">
              <LazyPage><ChefDashboard /></LazyPage>
            </RoleGuard>
          )}
        />
        <Route
          path="/manager/*"
          element={(
            <RoleGuard role="manager">
              <LazyPage><ManagerDashboard /></LazyPage>
            </RoleGuard>
          )}
        />
        <Route
          path="/hq/*"
          element={(
            <RoleGuard role="hq">
              <LazyPage><HQDashboard /></LazyPage>
            </RoleGuard>
          )}
        />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
