# Modele Supabase du pilote ShelfGuide

## Tables

| Table | Responsabilite |
| --- | --- |
| `profiles` | Role applicatif lie a `auth.users` |
| `stores` | Referentiel magasin, format et geolocalisation |
| `shelves` | Referentiel des rayons d'un magasin |
| `store_members` | Utilisateurs actifs autorises dans un magasin |
| `shelf_members` | Rayons precis autorises pour un chef |
| `shelfguide_analyses` | Resultats bruts des audits |
| `action_tasks` | Workflow partage d'une anomalie |
| `task_events` | Journal d'audit immuable |
| `task_photos` | Metadonnees des preuves stockees dans Storage |
| `task_comments` | Commentaires operationnels facultatifs |

## Workflow

```text
open -> in_progress -> corrected -> verified
                    \-> rejected -> in_progress
```

- Le Chef peut prendre en charge une tache non assignee de son rayon.
- Le Chef peut passer de `in_progress` a `corrected`.
- Le Manager peut assigner, valider ou rejeter dans son magasin.
- Une tache `verified` est terminale.
- HQ consulte le reseau mais ne modifie pas les taches operationnelles.

## Journal d'audit

Des triggers inserent automatiquement dans `task_events`:

- creation de tache;
- changement de statut;
- changement d'assignation;
- upload d'une photo;
- ajout d'un commentaire;
- modification des informations de pilotage.

Le client React n'a aucun droit direct d'insertion ou de modification sur
`task_events`.

## RLS

### Chef

- magasin actif dans `store_members`;
- rayon actif dans `shelf_members`;
- lecture des analyses et taches de ces rayons;
- modification d'une tache assignee a lui ou encore non assignee;
- aucun acces aux autres rayons.

### Manager

- appartenance active avec `member_role = manager`;
- lecture de tous les rayons, analyses, membres et taches du magasin;
- assignation et validation des taches du magasin;
- aucun acces aux autres magasins.

### HQ

- lecture de tous les magasins, rayons, analyses, taches, evenements et photos;
- pas de modification des workflows terrain depuis le client.

### Utilisateur invalide

Sans ligne `profiles` valide, aucune fonction d'autorisation ne retourne vrai.

## Photos

Le bucket `task-proofs` est prive. Le chemin obligatoire est:

```text
store_id/task_id/uuid.extension
```

Les politiques Storage verifient:

1. que la tache existe;
2. que le premier dossier correspond au magasin de la tache;
3. que l'utilisateur peut consulter ou modifier cette tache.

Les images sont affichees avec des URL signees temporaires, jamais avec une URL
publique permanente.

## Compatibilite des analyses

La migration ajoute `store_id` et `shelf_id` a `shelfguide_analyses`.
`action_tasks.analysis_id` reste un texte pour accepter un identifiant
d'analyse existant de type UUID, bigint ou texte.

Si la table historique contient un seul magasin, la migration le rattache
automatiquement au magasin pilote. Avec plusieurs magasins, le rattachement
doit etre fait explicitement avant l'ouverture du pilote.
