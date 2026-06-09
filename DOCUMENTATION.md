# ShelfGuide - Documentation complete

## 1. Objectif du produit

ShelfGuide est une application SaaS de controle et d'amelioration de l'execution
en rayon. Elle transforme les resultats d'audits de rayons en actions adaptees a
trois niveaux de responsabilite:

- **Chef de rayon**: detecter, prendre en charge et corriger les anomalies.
- **Manager magasin**: prioriser, assigner et suivre le travail des equipes.
- **Direction HQ**: comparer le reseau, mesurer les risques et piloter les
  objectifs strategiques.

L'application est une SPA unique. Une seule page de connexion determine le role
de l'utilisateur dans Supabase, puis l'envoie automatiquement vers son espace.

## 2. Stack technique

| Domaine | Technologie |
| --- | --- |
| Interface | React 19, TypeScript |
| Build | Vite 7 |
| Routage | React Router DOM 7 |
| Backend et authentification | Supabase |
| Base de donnees | PostgreSQL via Supabase |
| Temps reel | Supabase Realtime |
| PDF | jsPDF et jspdf-autotable |
| QR Code | qrcode.react |
| Styles | CSS global, variables CSS, responsive design |
| Police | Inter |
| Deploiement | Vercel |

## 3. Architecture finale

```text
shelfguideDashboards/
|-- index.html
|-- package.json
|-- tsconfig.json
|-- vite.config.ts
|-- vercel.json
|-- DOCUMENTATION.md
|-- accounts.txt                    # Local uniquement, ignore par Git
|-- src/
|   |-- main.tsx
|   |-- routes.tsx
|   |-- assets/
|   |   `-- shelfguide-logo.jpeg
|   |-- components/
|   |   `-- common/
|   |       |-- DashboardLayout.tsx
|   |       |-- LoadingScreen.tsx
|   |       |-- PageHeader.tsx
|   |       |-- RouteGuards.tsx
|   |       |-- Sidebar.tsx
|   |       `-- SurfaceCard.tsx
|   |-- contexts/
|   |   `-- AuthContext.tsx
|   |-- pages/
|   |   |-- Auth/
|   |   |   `-- LoginPage.tsx
|   |   |-- Chef/
|   |   |   |-- ChefDashboard.tsx
|   |   |   |-- config.ts
|   |   |   |-- dashboard.ts
|   |   |   `-- report.ts
|   |   |-- Manager/
|   |   |   |-- ManagerDashboard.tsx
|   |   |   |-- config.ts
|   |   |   |-- dashboard.ts
|   |   |   `-- report.ts
|   |   `-- HQ/
|   |       |-- HQDashboard.tsx
|   |       |-- config.ts
|   |       |-- dashboard.ts
|   |       `-- report.ts
|   |-- services/
|   |   |-- supabase.ts
|   |   `-- tasks.ts
|   |-- styles/
|   |   `-- global.css
|   |-- types/
|   |   `-- pilot.ts
|   `-- utils/
|       |-- shelfguideCalculations.ts
|       `-- shelfguideCalculations.test.ts
`-- supabase/
    |-- config.toml
    |-- migrations/
    |   |-- 202606070001_create_profiles.sql
    |   `-- 202606080001_pilot_store_operations.sql
    `-- tests/
        `-- rls_pilot.sql
```

## 4. Demarrage de l'application

`src/main.tsx` monte l'application dans cet ordre:

```text
React.StrictMode
  -> AuthProvider
    -> AppRouter
      -> Route publique ou route protegee
        -> DashboardLayout
          -> Sidebar + contenu du dashboard
```

Les trois dashboards sont charges avec `React.lazy` et `Suspense`. Le navigateur
ne telecharge donc que le bundle necessaire au role actuellement consulte.

## 5. Authentification et roles

### 5.1 Source d'identite

Supabase Auth gere:

- l'email;
- le mot de passe;
- la session;
- le rafraichissement automatique du token;
- la persistance de la session dans le navigateur.

La table `public.profiles` complete `auth.users` avec:

| Colonne | Type | Description |
| --- | --- | --- |
| `id` | UUID | Identique a l'identifiant `auth.users.id` |
| `role` | enum | `chef`, `manager` ou `hq` |
| `full_name` | text | Nom affiche dans la sidebar |
| `created_at` | timestamptz | Date de creation |
| `updated_at` | timestamptz | Derniere modification |

### 5.2 AuthContext

`AuthContext.tsx` centralise:

- `session`: session Supabase courante;
- `user`: utilisateur authentifie;
- `profile`: profil et role;
- `loading`: chargement initial;
- `profileError`: profil absent ou role invalide;
- `signIn(email, password)`;
- `signOut()`;
- `refreshProfile()`.

Au demarrage, le contexte lit la session existante. Il ecoute ensuite
`onAuthStateChange`. A chaque connexion, il recupere la ligne `profiles` ayant
le meme `id` que l'utilisateur.

### 5.3 Regles de securite

- Les roles valides sont strictement `chef`, `manager` et `hq`.
- Une ligne de profil ne peut etre lue que par son propre utilisateur.
- Le role n'est pas choisi dans le formulaire de connexion.
- Le role ne doit pas etre modifiable directement par le client.
- La cle `service_role` ne doit jamais etre placee dans une variable `VITE_*`.
- Seule la cle publique Supabase, ou publishable key, est utilisee dans React.

La migration cree aussi un trigger qui ajoute automatiquement un profil lors de
la creation d'un utilisateur Supabase.

## 6. Routes

| Route | Acces | Comportement |
| --- | --- | --- |
| `/login` | Public | Affiche la connexion; redirige si deja connecte |
| `/` | Tous | Redirection automatique selon le role |
| `/chef/*` | Role `chef` | Dashboard d'execution terrain |
| `/manager/*` | Role `manager` | Dashboard de pilotage magasin |
| `/hq/*` | Role `hq` | Dashboard strategique reseau |
| `*` | Tous | Redirection vers `/` |

### Protection des routes

`RouteGuards.tsx` applique les regles suivantes:

1. Une session en cours de chargement affiche l'ecran de chargement.
2. Un visiteur non connecte est envoye vers `/login`.
3. Un utilisateur sans profil valide voit une erreur d'acces.
4. Un utilisateur qui ouvre une route d'un autre role est renvoye vers sa
   propre route.

Exemple: un chef qui ouvre `/hq` est redirige vers `/chef`.

## 7. Navigation commune

La sidebar est unique et recoit le role courant. Elle construit ensuite les
liens adaptes.

### Chef de rayon

- Vue d'ensemble
- Actions
- Categories
- Audits
- Historique

### Manager

- Vue d'ensemble
- Heatmap
- Classement
- Alertes
- Audits
- Historique

### HQ

- Vue d'ensemble
- Magasins
- Categories
- Carte
- Objectifs
- Alertes
- Historique

La sidebar affiche egalement le logo ShelfGuide, le nom ou l'email de
l'utilisateur, son role, l'etat de synchronisation et la deconnexion.

## 8. Source des donnees

Les trois dashboards lisent la table:

```sql
public.shelfguide_analyses
```

Requete generale:

```text
SELECT *
ORDER BY audit_date DESC
LIMIT selon le dashboard
```

| Dashboard | Limite |
| --- | ---: |
| Chef | 300 analyses |
| Manager | 500 analyses |
| HQ | 1000 analyses |

Des filtres facultatifs par magasin et categorie peuvent etre fournis par les
variables d'environnement.

### 8.1 Donnees brutes communes

| Champ | Utilisation |
| --- | --- |
| `id` | Identifiant de l'analyse |
| `store_name` | Magasin audite |
| `shelf_name` | Rayon audite |
| `category` | Categorie produit |
| `audit_date` | Date et heure de l'audit |
| `status` | Etat brut de l'analyse |
| `severity` | Niveau de severite brut |
| `recommendation` | Action recommandee |
| `empty_spaces` | Nombre d'espaces vides |
| `raw_products_detected` | Produits detectes avant analyse |
| `products_analyzed` | Produits effectivement analyses |
| `front_products` | Produits correctement presentes |
| `back_products` | Produits mal orientes ou en retrait |
| `product_groups` | Groupes de produits detectes |
| `empty_ratio_percent` | Pourcentage de vide |
| `back_ratio_percent` | Pourcentage de produits mal orientes |
| `weighted_loss_percent` | Perte ponderee calculee en amont |
| `weighted_profitability_percent` | Performance ponderee |
| `shelf_loss_percent` | Perte du rayon |
| `shelf_profitability_percent` | Performance du rayon |
| `money_value_available` | Presence d'une valeur financiere exploitable |

### 8.2 Donnees facultatives du Chef

| Champ | Utilisation |
| --- | --- |
| `reserve_stock_status` | Produit disponible ou non en reserve |
| `warehouse_stock_status` | Rupture ou disponibilite entrepot |
| `planogram_url` | Planogramme de reference |
| `reference_image_url` | Photo de facing conforme |
| `product_sku` | Reference ou code-barres produit |

### 8.3 Donnees facultatives du HQ

| Champ | Utilisation |
| --- | --- |
| `store_format` | Hyper, Super, Proximite, Express, etc. |
| `latitude` | Position geographique du magasin |
| `longitude` | Position geographique du magasin |

### 8.4 Normalisation

Avant affichage, chaque ligne est normalisee:

- les nombres invalides deviennent `0`;
- les chaines absentes recoivent une valeur lisible;
- les pourcentages sont limites entre `0` et `100`;
- les dates invalides sont gerees sans bloquer l'interface;
- les valeurs par defaut sont `Magasin`, `Rayon`, `Autre`, `Moyen` et
  `medium` selon le champ.

## 9. Calculs partages

Les formules communes se trouvent dans
`src/utils/shelfguideCalculations.ts`.

### 9.1 Score de conformite

Priorite des sources:

1. `weighted_profitability_percent`;
2. `shelf_profitability_percent`;
3. sinon:

```text
conformite = 100 - (taux_vide x 0.72) - (taux_arriere x 0.28)
```

Le resultat est limite entre `0` et `100`.

### 9.2 Taux de remplissage

```text
remplissage = 100 - taux_vide
```

### 9.3 Taux de perte

Priorite des sources:

1. `weighted_loss_percent`;
2. `shelf_loss_percent`;
3. sinon:

```text
perte = (taux_vide x 0.75) + (taux_arriere x 0.25)
```

### 9.4 Severite derivee

**Critique** si:

- le statut brut est critique ou eleve;
- ou le taux de vide est superieur ou egal a 18%;
- ou la conformite est inferieure a 65%.

**Moyen** si:

- le statut brut est moyen;
- ou le taux de vide est superieur ou egal a 8%;
- ou le taux arriere est superieur ou egal a 8%;
- ou la conformite est inferieure a 85%.

Sinon l'etat est **Bon**.

### 9.5 Priorite derivee

**Haute** si l'etat est critique, si le vide atteint 15%, si le taux arriere
atteint 12%, ou si la conformite descend sous 70%.

**Moyenne** si l'etat est moyen, si le vide ou le taux arriere atteint 5%, si
la conformite descend sous 85%, ou si une recommandation existe.

Sinon la priorite est **Faible**.

### 9.6 Type d'anomalie

Les controles sont executes dans cet ordre:

1. **Audit incomplet**: aucun produit detecte ou analyse.
2. **Rupture visible**: vide >= 10% ou au moins 4 espaces vides.
3. **Produit mal oriente**: taux arriere >= 7% ou au moins 4 produits arriere.
4. **Performance faible**: conformite < 75%.
5. **Conforme**.

### 9.7 Resume partage

Chaque dashboard peut produire:

- nombre d'audits;
- nombre de magasins uniques;
- conformite moyenne;
- nombre d'analyses critiques;
- total d'espaces vides;
- total de produits mal orientes;
- moyenne des taux de vide;
- moyenne des taux arriere.

Les montants sont formates en dirhams marocains et les dates en francais.

## 10. Dashboard Chef de rayon

### 10.1 Mission

Le dashboard Chef est centre sur l'execution immediate. Il doit repondre a trois
questions:

1. Quel probleme traiter en premier?
2. Le produit est-il disponible?
3. Comment prouver que la correction est terminee?

### 10.2 Informations affichees

- score terrain;
- nombre d'actions ouvertes;
- espaces vides;
- produits mal orientes;
- heure du dernier audit;
- action prioritaire;
- liste des actions;
- etat de stock;
- aide visuelle de facing;
- categories les plus exposees;
- historique des audits.

### 10.3 Score de priorite des actions

```text
(100 - conformite)
+ taux_vide x 1.7
+ taux_arriere x 1.3
+ espaces_vides x 3
+ produits_arriere x 2
+ poids_priorite x 12
+ poids_anomalie x 4
```

Poids de priorite: Haute `3`, Moyenne `2`, Faible `1`.

Poids d'anomalie:

- rupture visible: `5`;
- performance faible: `4`;
- produit mal oriente: `3`;
- audit incomplet: `2`;
- conforme: `1`.

La liste est triee du score le plus eleve au plus faible.

### 10.4 Indicateur de stock

- Reserve disponible reconnue: **En reserve**.
- Reserve indisponible et entrepot indisponible: **En rupture entrepot**.
- Information insuffisante: **Stock non synchronise**.

### 10.5 Planogramme

Pour une anomalie de facing, le dashboard affiche:

1. `planogram_url` si disponible;
2. sinon `reference_image_url`;
3. sinon une representation visuelle generique.

### 10.6 Workflow de resolution

Etat initial:

```text
A traiter
```

Premier clic:

```text
Pris en charge
```

Deuxieme clic:

```text
Corrige
```

Une photo de preuve peut etre jointe. Le workflow est stocke dans
`action_tasks`, chaque transition est journalisee dans `task_events` et la
preuve est envoyee dans le bucket prive:

```text
task-proofs
```

Le statut peut ensuite etre valide ou rejete par le Manager. Une tache validee
devient terminale.

### 10.7 Scanner

Le bouton flottant ouvre un scanner rapide:

- utilisation de `BarcodeDetector` si le navigateur le supporte;
- saisie manuelle en solution de secours;
- declaration d'une anomalie hors liste;
- association possible avec le SKU du produit.
- creation immediate d'une ligne `action_tasks` partagee avec le Manager.

### 10.8 Filtres

- periode: aujourd'hui, 7 jours, 30 jours, tout;
- rayon;
- categorie;
- priorite;
- urgences uniquement;
- recherche textuelle;
- seuils de vide et de produits arriere.

### 10.9 Exports

- export CSV;
- rapport PDF;
- partage par QR Code;
- conservation des filtres principaux dans l'URL.

## 11. Dashboard Manager magasin

### 11.1 Mission

Le manager orchestre les ressources du magasin. Il ne corrige pas chaque
probleme lui-meme: il identifie les zones a risque, assigne les responsables et
controle le rythme de resolution avant les pics clients.

### 11.2 Informations affichees

- score du magasin;
- couverture des audits du jour;
- rayons a risque;
- corrections du jour;
- audits du mois;
- actions ouvertes;
- heatmap simplifiee du magasin;
- alertes avant le pic client;
- classement des rayons;
- assignations des equipes;
- gains rapides;
- estimation des pertes et du temps economise;
- anomalies recurrentes.

### 11.3 Consolidation par rayon

Les analyses sont groupees par:

```text
magasin + rayon
```

La ligne la plus recente represente l'etat actuel. La ligne precedente permet de
calculer la tendance:

```text
tendance = conformite_actuelle - conformite_precedente
```

Une baisse d'au moins 8 points force une priorite haute. Une baisse d'au moins
4 points peut faire monter une priorite faible vers moyenne.

### 11.4 Score de priorite

```text
(100 - conformite)
+ taux_vide x 1.5
+ taux_arriere x 1.2
+ baisse_de_tendance x 2
+ poids_priorite x 10
+ poids_anomalie x 4
```

### 11.5 Heatmap magasin

La heatmap presente jusqu'a 18 rayons analyses:

- vert: situation saine;
- jaune: vigilance;
- rouge: risque important.

Il s'agit d'un plan visuel simplifie, pas encore d'un plan physique construit a
partir des coordonnees reelles des rayons.

### 11.6 Assignation

Chaque action peut etre attribuee a un membre actif du magasin. Les noms et
roles proviennent de `store_members` et `profiles`. Pour un Chef, la liste est
limitee aux personnes autorisees sur le rayon par `shelf_members`.

L'assignation est stockee dans:

```text
action_tasks.assigned_to
```

Elle est partagee entre appareils et cree automatiquement un evenement
`assigned` dans `task_events`. Le Manager peut aussi consulter une preuve avec
une URL Storage signee, puis valider ou rejeter la correction.

### 11.7 Alertes de flux client

L'heure de pointe par defaut est `17:30`, modifiable par configuration. Le
dashboard calcule le temps restant et met en avant les corrections a terminer
avant ce pic.

Estimation d'impact:

```text
impact = (espaces_vides + produits_arriere) x 65 MAD
```

Le cout unitaire de 65 MAD est une hypothese configurable, pas une donnee
comptable certifiee.

### 11.8 Quick Wins

Le filtre Gains rapides retient principalement:

- les problemes de produits mal orientes;
- un taux de vide faible;
- un taux arriere significatif;
- une correction potentiellement rapide avec un impact visible.

### 11.9 Simulation operationnelle

```text
cout_rupture_journalier = total_espaces_vides x 65 MAD
heures_economisees = nombre_audits x 12 minutes / 60
```

La recuperation estimee depend du gain de conformite simule et de l'ecart entre
la conformite actuelle et 100%.

### 11.10 Filtres et exports

- periode;
- magasin;
- statut;
- type d'anomalie;
- recherche;
- Quick Wins;
- CSV, PDF et QR Code.

## 12. Dashboard HQ

### 12.1 Mission

Le dashboard HQ donne une vue strategique du reseau. Il permet de comparer des
magasins comparables, de reperer les zones a fort risque financier et de simuler
l'effet d'un objectif de conformite plus ambitieux.

### 12.2 Informations affichees

- score reseau;
- nombre de magasins;
- magasins critiques;
- audits du mois;
- taux de remplissage;
- pertes potentielles;
- classement des magasins;
- performance par categorie;
- cohortes de magasins;
- carte OpenStreetMap;
- simulateur d'objectif;
- matrice Risque / Performance;
- plans d'action 24 h, 48 h, 7 jours et 30 jours.

### 12.3 Consolidation par magasin

Les analyses sont groupees par magasin. Pour chaque groupe, l'application
calcule:

- conformite moyenne;
- taux de vide moyen;
- taux arriere moyen;
- nombre de rayons;
- nombre d'audits;
- volume de produits;
- anomalies critiques et moyennes;
- anomalie dominante;
- priorite globale.

### 12.4 Cohortes

Le champ `store_format` est normalise vers:

- Hyper;
- Super;
- Proximite;
- Express ou format urbain equivalent.

Si le format est absent, une estimation est produite:

- Hyper: au moins 20 rayons ou 1000 produits;
- Super: au moins 8 rayons ou 300 produits;
- Proximite: en dessous de ces seuils.

Cette estimation permet un benchmark coherent, mais elle doit idealement etre
remplacee par un referentiel magasin officiel.

### 12.5 Score de risque magasin

```text
(100 - conformite)
+ taux_vide x 1.5
+ taux_arriere x 1.2
+ anomalies_critiques x 8
+ anomalies_moyennes x 3
+ poids_priorite_max x 8
+ poids_anomalie_dominante x 4
```

- score >= 70 ou au moins 3 critiques: priorite haute;
- score >= 35 ou au moins 3 moyens: priorite moyenne;
- sinon: priorite faible.

### 12.6 Carte geographique

La carte utilise OpenStreetMap et se concentre sur la region de Casablanca.
L'emprise initiale est approximativement:

```text
longitude: -8.15 a -7.05
latitude:   33.25 a 34.02
```

Si `latitude` et `longitude` existent, la position est reelle. Sinon,
l'application utilise une position indicative pour conserver une visualisation
exploitable. Les halos thermiques representent le niveau de risque du magasin.

Une vraie heatmap regionale exige des coordonnees fiables pour chaque magasin.

### 12.7 Simulateur What-If

Le curseur de conformite cible varie de 85% a 98%.

```text
perte_journaliere = total_espaces_vides x cout_unitaire
gain_annuel =
  perte_journaliere x 365
  x ((cible - conformite_actuelle) / (100 - conformite_actuelle))
```

La fraction est limitee entre `0` et `1`. Le resultat est une projection, pas un
engagement financier.

### 12.8 Matrice Risque / Performance

- axe X: conformite;
- axe Y: perte financiere potentielle;
- chaque point: un magasin;
- quadrant prioritaire: conformite inferieure a 85% et perte superieure ou
  egale a 50% de la perte maximale observee.

### 12.9 Filtres et exports

- periode;
- magasin;
- categorie;
- cohorte;
- niveau de performance;
- CSV, PDF et QR Code.

## 13. Synchronisation temps reel

Chaque dashboard:

1. charge les analyses au montage;
2. s'abonne aux changements PostgreSQL de `shelfguide_analyses`;
3. recharge les donnees apres une insertion, modification ou suppression;
4. effectue aussi un rafraichissement periodique toutes les 15 secondes.

L'interface utilise un squelette pendant le chargement, puis affiche les donnees
avec une transition.

## 14. Design system

### 14.1 Style general

Le design recherche une apparence:

- moderne;
- professionnelle;
- lisible en situation operationnelle;
- dense sans etre surchargee;
- coherente entre les trois roles.

La hierarchie visuelle privilegie les urgences, les chiffres cles et les actions
disponibles. Les dashboards partagent le meme cadre, mais le contenu change
selon le niveau de decision.

### 14.2 Palette principale

| Token | Valeur | Usage |
| --- | --- | --- |
| Bleu principal | `#1D4ED8` | Selection, marque, liens |
| Bleu action | `#3B82F6` | Actions secondaires |
| Bleu CTA | `#4184F5` | Boutons principaux |
| Bleu nuit | `#000E27` | Sidebar, fond sombre |
| Fond clair | `#EEF4FE` | Fond de page |
| Carte | `#FCFDFE` | Surfaces principales |
| Bleu doux | `#EAF1FF` | Fonds d'accent |
| Bordure | `#C6D3EB` | Separateurs |
| Texte | `#162642` | Titres et contenu |
| Texte secondaire | `#7C8798` | Labels |
| Succes | `#16835A` | Etats sains |
| Alerte | `#D97706` | Vigilance |
| Danger | `#DC2626` | Critique |

Le theme sombre utilise notamment `#000E27` pour le fond et `#061A35` pour les
surfaces.

### 14.3 Composants

- sidebar fixe et responsive;
- cartes de KPI;
- cartes de surface communes;
- badges de statut;
- tableaux et listes de classement;
- filtres segmentes;
- champs de recherche;
- graphiques CSS et SVG;
- modales et panneaux;
- boutons avec icones;
- QR Code;
- scanner flottant pour le Chef.

### 14.4 Mouvement

- apparition progressive au chargement;
- leger deplacement vertical des cartes;
- ombre renforcee au survol;
- compteurs animes;
- revelation des graphiques;
- transition d'etat de la navigation;
- retour visuel au clic;
- pulsation des statuts actifs;
- squelette pendant le chargement;
- entree adoucie des modales.

`prefers-reduced-motion` est respecte pour les utilisateurs qui limitent les
animations.

### 14.5 Responsive

Le CSS contient des adaptations pour grands ecrans, laptops, tablettes et
mobiles. Les points de rupture principaux couvrent environ:

```text
1320, 1080, 960, 860, 700, 640, 620 et 520 px
```

Sur mobile:

- les grilles passent sur une colonne;
- la navigation se compacte;
- les tableaux deviennent scrollables ou sont transformes en blocs;
- les actions tactiles gardent une zone de clic suffisante;
- la page de connexion empile la presentation et le formulaire.

### 14.6 Page de connexion

La page est divisee en deux zones:

- a gauche: fond bleu nuit, logo ShelfGuide, promesse produit;
- a droite: carte blanche contenant email, mot de passe, erreurs et bouton de
  connexion.

Le role n'est pas demande a l'utilisateur. Il est lu dans Supabase.

## 15. Fonctions transversales

Les dashboards proposent selon le contexte:

- recherche globale avec raccourci `Ctrl+K` ou `Cmd+K`;
- theme clair ou sombre;
- mode plein ecran;
- actualisation manuelle;
- actualisation temps reel;
- export CSV;
- generation PDF;
- partage par QR Code;
- conservation de certains filtres dans l'URL;
- etats vides et messages d'erreur;
- formatage francais des dates et montants.

## 16. Variables d'environnement

Variables recommandees dans Vercel:

```env
VITE_SUPABASE_URL=https://VOTRE-PROJET.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=VOTRE_CLE_PUBLIQUE
```

Variables facultatives:

```env
VITE_STORE_NAME=Nom du magasin
VITE_CATEGORY=Nom de la categorie
VITE_PEAK_HOUR=17:30
```

Le projet contient actuellement une configuration publique de secours dans le
client Supabase. Pour une exploitation propre, les variables Vercel restent la
source recommandee.

Ne jamais utiliser:

```env
VITE_SUPABASE_SERVICE_ROLE_KEY=...
```

Toute variable prefixee par `VITE_` est incluse dans le JavaScript envoye au
navigateur.

## 17. Supabase

### Migration

Le fichier:

```text
supabase/migrations/202606070001_create_profiles.sql
```

cree:

- l'enum des roles;
- la table `profiles`;
- les triggers de creation et de mise a jour;
- les politiques RLS;
- les profils manquants pour les utilisateurs deja existants.

La migration peut etre executee dans le SQL Editor Supabase ou avec la CLI
Supabase apres liaison du projet.

### Comptes de demonstration

Les identifiants de demonstration sont conserves localement dans:

```text
accounts.txt
```

Ce fichier est ignore par Git. Il ne doit pas etre publie sur GitHub ni integre
au bundle Vite.

### Securite des analyses

La table `shelfguide_analyses` doit disposer de politiques RLS correspondant au
modele d'organisation reel. La protection des routes React ameliore
l'experience utilisateur, mais elle ne remplace jamais les politiques de base
de donnees.

Modele cible recommande:

- Chef: uniquement son magasin et ses rayons autorises;
- Manager: toutes les analyses de son magasin;
- HQ: toutes les analyses du reseau;
- ecriture des corrections et assignations dans des tables dediees.

## 18. Deploiement Vercel

`vercel.json` configure:

- le framework Vite;
- la commande `npm run build`;
- le dossier de sortie `dist`;
- une reecriture de toutes les routes vers `index.html`.

La reecriture est indispensable pour ouvrir directement `/chef`, `/manager` ou
`/hq` sans erreur 404.

Commandes locales:

```bash
npm install
npm run dev
npm run build
npm run preview
```

Le deploiement Git suit normalement:

```bash
git add .
git commit -m "Document and configure ShelfGuide"
git push origin main
```

Vercel reconstruit ensuite automatiquement le projet connecte au depot.

## 19. Donnees locales et donnees partagees

| Fonction | Stockage actuel | Partage multi-appareils |
| --- | --- | --- |
| Session utilisateur | Supabase Auth | Oui |
| Role et nom | Supabase `profiles` | Oui |
| Analyses | Supabase `shelfguide_analyses` | Oui |
| Workflow Chef | Supabase `action_tasks` | Oui |
| Photo de correction | Storage prive + `task_photos` | Oui |
| Anomalie manuelle scanner | Supabase `action_tasks` | Oui |
| Assignation Manager | `action_tasks.assigned_to` | Oui |
| Journal d'audit | Supabase `task_events` | Oui |
| Theme | navigateur | Non necessaire |
| Filtres URL | URL | Partageable |

## 20. Limites actuelles et prochaines evolutions

### Priorite haute

1. Appliquer et valider la migration pilote sur l'environnement Supabase cible.
2. Completer le rattachement `store_id` et `shelf_id` des analyses historiques.
3. Completer les coordonnees geographiques reelles des magasins.
4. Relier les stocks reserve et entrepot a une source back-office fiable.
5. Mettre en place les sauvegardes et alertes d'exploitation.

### Priorite moyenne

1. Ajouter la surface et les horaires au referentiel `stores`.
2. Construire la heatmap Manager a partir d'un vrai plan de magasin.
3. Remplacer les hypotheses financieres par des couts et marges reels.
4. Ajouter des notifications pour les assignations et retards.
5. Ajouter une gestion administrative des membres et rayons.

### Qualite technique

1. Executer les tests RLS avec Supabase local dans la CI.
2. Executer le parcours Playwright avec des comptes pilote dedies.
3. Ajouter des tests de routes pour chaque role.
4. Decouper progressivement le grand fichier CSS en couches ou modules.
5. Ajouter des tests de reprise apres coupure reseau.

## 21. Lecture produit en une phrase

ShelfGuide convertit une analyse brute du rayon en trois niveaux de decision:

```text
Voir et corriger -> Distribuer et piloter -> Comparer et decider
```
