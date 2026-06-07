import { useState, type FormEvent } from 'react';
import logoUrl from '../../assets/shelfguide-logo.jpeg';
import { SurfaceCard } from '../../components/common/SurfaceCard';
import { useAuth } from '../../contexts/AuthContext';
import { isSupabaseConfigured } from '../../services/supabase';

export default function LoginPage() {
  const { signIn, error: authError } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSubmitting(true);
    setFormError(null);

    try {
      await signIn(email, password);
    } catch (error: unknown) {
      setFormError(error instanceof Error ? error.message : 'Connexion impossible.');
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <main className="login-page">
      <section className="login-brand">
        <img src={logoUrl} alt="ShelfGuide" />
        <div>
          <p>ShelfGuide</p>
          <h1>La bonne vue, pour la bonne decision.</h1>
          <span>Execution terrain, pilotage magasin et strategie reseau dans une seule application.</span>
        </div>
      </section>

      <SurfaceCard className="login-card">
        <div className="login-card-heading">
          <span>Connexion securisee</span>
          <h2>Acceder a ShelfGuide</h2>
        </div>

        <form onSubmit={handleSubmit}>
          <label>
            <span>Email</span>
            <input
              type="email"
              autoComplete="email"
              placeholder="nom@entreprise.ma"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              required
            />
          </label>
          <label>
            <span>Mot de passe</span>
            <input
              type="password"
              autoComplete="current-password"
              placeholder="Votre mot de passe"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              required
            />
          </label>

          {formError || authError ? <div className="login-error">{formError || authError}</div> : null}
          {!isSupabaseConfigured ? <div className="login-error">Ajoutez les variables Supabase dans le fichier .env.</div> : null}

          <button type="submit" disabled={submitting || !isSupabaseConfigured}>
            {submitting ? 'Connexion...' : 'Se connecter'}
          </button>
        </form>
      </SurfaceCard>
    </main>
  );
}
