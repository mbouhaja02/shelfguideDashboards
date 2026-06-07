export function LoadingScreen({ label = 'Chargement de ShelfGuide...' }: { label?: string }) {
  return (
    <main className="route-loader" aria-live="polite">
      <span className="route-loader-mark" aria-hidden="true" />
      <strong>{label}</strong>
    </main>
  );
}
