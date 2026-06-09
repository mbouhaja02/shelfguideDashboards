# Deploiement du magasin pilote ShelfGuide

## 1. Prerequis

- un projet Supabase de production ou de preproduction;
- un projet Vercel relie au depot Git;
- Node.js compatible avec Vite 7;
- acces administrateur Supabase;
- comptes Chef, Manager et HQ avec mots de passe uniques;
- sauvegarde de la base avant migration.

Ne jamais placer une cle `service_role` dans React, Vercel ou une variable
prefixee par `VITE_`.

## 2. Variables du frontend

Le depot contient `.env.production` avec uniquement la configuration publique
Supabase. Un deploiement Vercel Hobby fonctionne donc sans configuration
manuelle supplementaire.

Pour utiliser un autre projet Supabase, remplacer ces valeurs dans Vercel pour
Production et Preview:

```env
VITE_SUPABASE_URL=https://PROJECT_REF.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
```

Une cle `anon` peut remplacer la publishable key:

```env
VITE_SUPABASE_ANON_KEY=ey...
```

Les variables Vercel remplacent automatiquement les valeurs publiques du
fichier `.env.production`.

## 3. Appliquer les migrations

Ordre obligatoire:

1. `supabase/migrations/202606070001_create_profiles.sql`
2. `supabase/migrations/202606080001_pilot_store_operations.sql`

Avec la CLI Supabase:

```bash
supabase login
supabase link --project-ref PROJECT_REF
supabase db push
```

Sans CLI, ouvrir le SQL Editor Supabase et executer les deux fichiers dans le
meme ordre.

La seconde migration cree:

- les tables operationnelles;
- les triggers d'audit;
- les politiques RLS;
- le bucket prive `task-proofs`;
- le magasin `CASA-PILOT-001`;
- six rayons initiaux;
- les publications Realtime.

## 4. Verifier le rattachement des analyses

Verifier les lignes non rattachees:

```sql
select
  store_name,
  shelf_name,
  count(*) as analyses
from public.shelfguide_analyses
where store_id is null or shelf_id is null
group by store_name, shelf_name
order by store_name, shelf_name;
```

Pour rattacher un nom de magasin au pilote:

```sql
update public.shelfguide_analyses a
set store_id = s.id
from public.stores s
where s.code = 'CASA-PILOT-001'
  and a.store_name = 'NOM EXACT DANS LES ANALYSES';
```

Pour rattacher les rayons par nom:

```sql
update public.shelfguide_analyses a
set shelf_id = sh.id
from public.shelves sh
where sh.store_id = a.store_id
  and lower(trim(sh.name)) = lower(trim(a.shelf_name))
  and a.shelf_id is null;
```

Une analyse sans `store_id` ou `shelf_id` est volontairement invisible sous
RLS.

## 5. Creer les comptes pilote

### Option Dashboard Supabase

Dans Authentication > Users:

1. creer les trois utilisateurs;
2. confirmer leurs emails;
3. verifier les lignes creees dans `profiles`;
4. appliquer les roles `chef`, `manager`, `hq`.

```sql
update public.profiles
set role = 'chef', full_name = 'Nom du chef'
where id = (select id from auth.users where email = 'chef@magasin.ma');

update public.profiles
set role = 'manager', full_name = 'Nom du manager'
where id = (select id from auth.users where email = 'manager@magasin.ma');

update public.profiles
set role = 'hq', full_name = 'Nom HQ'
where id = (select id from auth.users where email = 'hq@entreprise.ma');
```

### Option script local

Creer `.env.demo.local` depuis `.env.demo.example`, puis:

```bash
npm run seed:demo
```

Ce script est un outil d'administration local. Il utilise
`SUPABASE_SERVICE_ROLE_KEY` sans prefixe `VITE_`. Le fichier local reste ignore
par Git et la cle n'entre jamais dans le bundle React.

## 6. Affecter les membres

Le script precedent effectue l'affectation des comptes demo. Pour de vrais
comptes:

```sql
insert into public.store_members (store_id, user_id, member_role)
select s.id, u.id, 'chef'::public.app_role
from public.stores s
cross join auth.users u
where s.code = 'CASA-PILOT-001'
  and u.email = 'chef@magasin.ma'
on conflict (store_id, user_id)
do update set member_role = excluded.member_role, is_active = true;

insert into public.store_members (store_id, user_id, member_role)
select s.id, u.id, 'manager'::public.app_role
from public.stores s
cross join auth.users u
where s.code = 'CASA-PILOT-001'
  and u.email = 'manager@magasin.ma'
on conflict (store_id, user_id)
do update set member_role = excluded.member_role, is_active = true;
```

Affecter ensuite les rayons du Chef:

```sql
insert into public.shelf_members (shelf_id, user_id)
select sh.id, u.id
from public.shelves sh
join public.stores s on s.id = sh.store_id
cross join auth.users u
where s.code = 'CASA-PILOT-001'
  and u.email = 'chef@magasin.ma'
  and sh.code in ('BOISSONS', 'EPICERIE', 'FRAIS')
on conflict (shelf_id, user_id)
do update set is_active = true;
```

## 7. Completer le referentiel

Avant ouverture:

```sql
update public.stores
set
  address = 'ADRESSE CONFIRMEE',
  latitude = 33.573100,
  longitude = -7.589800
where code = 'CASA-PILOT-001';
```

Adapter les rayons:

```sql
select code, name, category
from public.shelves
where store_id = (
  select id from public.stores where code = 'CASA-PILOT-001'
)
order by display_order;
```

Desactiver un rayon absent au lieu de le supprimer:

```sql
update public.shelves
set is_active = false
where store_id = (
  select id from public.stores where code = 'CASA-PILOT-001'
)
and code = 'CODE_A_DESACTIVER';
```

## 8. Tests avant deploiement

```bash
npm ci
npm test
npm run build
```

Tests RLS avec Supabase local:

```bash
supabase start
supabase db reset
supabase test db
```

Parcours Playwright contre une base pilote:

```bash
E2E_CHEF_EMAIL=... \
E2E_CHEF_PASSWORD=... \
E2E_MANAGER_EMAIL=... \
E2E_MANAGER_PASSWORD=... \
npm run test:e2e
```

Sous PowerShell:

```powershell
$env:E2E_CHEF_EMAIL="..."
$env:E2E_CHEF_PASSWORD="..."
$env:E2E_MANAGER_EMAIL="..."
$env:E2E_MANAGER_PASSWORD="..."
npm run test:e2e
```

Le test couvre connexion Chef, prise en charge, photo, correction et validation
Manager.

## 9. Deployer sur Vercel

Verifier:

```bash
git status
git ls-files accounts.txt .env .env.local .env.demo.local
npm run build
```

La commande `git ls-files` ne doit retourner aucun fichier secret.

Puis:

```bash
git add .
git commit -m "Prepare ShelfGuide pilot deployment"
git push origin main
```

Vercel utilise `vercel.json`:

- build: `npm run build`;
- sortie: `dist`;
- toutes les routes reecrites vers `/index.html`.

Tester directement:

- `/login`
- `/chef`
- `/manager`
- `/hq`

Un rechargement navigateur sur chaque route doit fonctionner sans 404.

## 10. Checklist magasin pilote

### Securite

- [ ] Aucun secret dans les variables `VITE_*`
- [ ] `accounts.txt` absent de Git
- [ ] RLS active sur toutes les tables exposees
- [ ] Chef limite a ses rayons
- [ ] Manager limite a son magasin
- [ ] HQ en lecture operationnelle
- [ ] Bucket `task-proofs` prive

### Donnees

- [ ] Adresse et coordonnees confirmees
- [ ] Liste reelle des rayons chargee
- [ ] Analyses rattachees par `store_id` et `shelf_id`
- [ ] Membres actifs correctement affectes
- [ ] Aucun compte de test inutile actif

### Terrain

- [ ] Connexion testee sur le Wi-Fi et la 4G du magasin
- [ ] Prise en charge visible instantanement chez le Manager
- [ ] Photo mobile inferieure a 10 Mo envoyee avec succes
- [ ] Correction visible sur un second appareil
- [ ] Validation et rejet Manager testes
- [ ] Reconnexion apres perte reseau testee

### Exploitation

- [ ] `npm test` vert
- [ ] `npm run build` vert
- [ ] Test RLS vert avec Supabase local
- [ ] Parcours Playwright vert avec comptes pilote
- [ ] Sauvegarde Supabase active
- [ ] Responsable d'incident et canal de support definis

## 11. Controle apres ouverture

Rechercher les taches sans journal:

```sql
select t.id
from public.action_tasks t
left join public.task_events e on e.task_id = t.id
where e.id is null;
```

Rechercher les photos sans objet Storage:

```sql
select p.id, p.storage_path
from public.task_photos p
left join storage.objects o
  on o.bucket_id = 'task-proofs'
 and o.name = p.storage_path
where o.id is null;
```

Suivre les taches en retard:

```sql
select id, title, status, priority, due_at
from public.action_tasks
where due_at < now()
  and status not in ('verified')
order by due_at;
```
