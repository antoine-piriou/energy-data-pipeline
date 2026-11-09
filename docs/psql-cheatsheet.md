# psql : aide-mémoire

`psql` est le client en ligne de commande de PostgreSQL. On y tape soit du **SQL** (qui se termine par `;`), soit des **méta-commandes** (qui commencent par `\` et n'ont pas de `;`).

## 1. Se connecter

Depuis un terminal PowerShell, **à la racine du dépôt** (important pour les chemins relatifs de `\i` et `\copy`) :

```powershell
cd C:\Users\Antoine\Documents\Documents_personels\PROJETS\FDR26-27\energy_data_pipeline\energy-data-pipeline
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -d energy
```

Le mot de passe de `postgres` est demandé, et rien ne s'affiche pendant la saisie : c'est normal.

Pour avoir les accents correctement (le terminal est en page de code 850), tape d'abord dans psql :

```
\! chcp 65001
```

## 2. Lire l'invite (prompt)

| Invite | Signification |
|---|---|
| `energy=#` | Prêt, connecté à la base `energy` en superutilisateur |
| `energy-#` | Requête commencée mais pas terminée : il manque le `;` |
| `energy(#` | Une parenthèse est encore ouverte |
| `energy'#` | Une apostrophe est encore ouverte |

Si tu es bloqué sur `energy-#`, tape `;` puis Entrée. Pour tout annuler, utilise `\r` (vide le buffer) ou **Ctrl+C**.

## 3. Lancer les scripts du projet

```
\i sql/00_schema.sql               -- crée les tables
\i sql/01_load.sql                 -- charge le CSV eco2mix
\i sql/02_emission_factors.sql     -- facteurs d'émission
\i sql/queries/q01_daily_peak.sql  -- une requête
```

`\i` exécute un fichier comme si tu l'avais tapé. Le chemin est relatif au dossier où psql a été lancé.

## 4. Explorer la base

| Commande | Rôle |
|---|---|
| `\l` | Liste les bases |
| `\c energy` | Se connecte à une autre base |
| `\dt` | Liste les tables |
| `\d eco2mix` | Colonnes, types et index d'une table |
| `\d+ eco2mix` | Idem, avec les commentaires (`COMMENT ON`) |
| `\di` | Liste les index |
| `\df` | Liste les fonctions |

## 5. Rendre l'affichage lisible

| Commande | Rôle |
|---|---|
| `\x` | Bascule l'affichage vertical (pratique pour les lignes larges) |
| `\x auto` | Vertical seulement quand ça ne tient pas en largeur |
| `\timing` | Affiche la durée de chaque requête |
| `\pset null '(null)'` | Rend les NULL visibles au lieu de cases vides |

Quand le résultat est long, il s'ouvre dans un **pager** : Espace fait défiler, `q` quitte.

## 6. Écrire et corriger une requête

| Commande | Rôle |
|---|---|
| Flèche haut | Rappelle la requête précédente |
| `\e` | Ouvre la dernière requête dans un éditeur (Notepad), qui s'exécute à la fermeture |
| `\g` | Relance la dernière requête |
| `\p` | Affiche le buffer en cours |

Le plus confortable est d'écrire la requête dans un fichier `.sql` dans VS Code, puis de la lancer avec `\i`.

## 7. Importer et exporter

```
\copy ma_table FROM 'data/fichier.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8')
\copy (SELECT * FROM eco2mix LIMIT 10) TO 'extrait.csv' WITH (FORMAT csv, HEADER true)
```

`\copy` lit le fichier **côté client** (ton PC, avec tes droits), alors que `COPY` lit côté serveur. On utilise `\copy`, qui doit tenir sur une seule ligne.

## 8. Mesurer une requête (pour le L6)

```sql
EXPLAIN (ANALYZE, BUFFERS) SELECT ...;
```

`EXPLAIN` seul affiche le plan prévu. `ANALYZE` exécute vraiment la requête et donne les temps réels. `BUFFERS` indique les pages lues en cache ou sur disque.

## 9. Transactions (pour tester sans casser)

```sql
BEGIN;
DELETE FROM eco2mix WHERE ...;   -- essai
SELECT count(*) FROM eco2mix;    -- vérifier
ROLLBACK;                        -- tout annuler (ou COMMIT; pour garder)
```

Après une erreur dans une transaction, tout est bloqué (`current transaction is aborted`) jusqu'au `ROLLBACK`.

## 10. Aide et sortie

| Commande | Rôle |
|---|---|
| `\?` | Aide sur les méta-commandes |
| `\h SELECT` | Syntaxe d'une commande SQL |
| `\! cls` | Efface l'écran (lance une commande Windows) |
| `\q` | Quitte psql |
