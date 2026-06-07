import type { HTMLAttributes, ReactNode } from 'react';

export function SurfaceCard({
  children,
  className = '',
  ...props
}: HTMLAttributes<HTMLElement> & { children: ReactNode }) {
  return (
    <article className={`surface-card ${className}`.trim()} {...props}>
      {children}
    </article>
  );
}
