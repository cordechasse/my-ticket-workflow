---
name: version-start
description: Planifie une version du tracker, numéro `X.Y.Z` et but. La crée, réutilise celle qui porte déjà ce numéro ou renomme un placeholder, et refuse un numéro déjà publié. À utiliser pour planifier une version, numéroter un placeholder, ou depuis version-hotfix.
argument-hint: "[X.Y.Z] [But]"
---

# version-start

Lis d'abord `.claude/workflow/RULES.md` (racine du dépôt), puis la config et les adaptateurs `tracker-<tracker.provider>` et `published-<releases.published>` (FORMAT § « Configuration »).

**Onglet et phase** (RULES § « Onglet herdr et phase ») : action `start`, version confirmée à l'étape 2. Étapes 1 à 5 : `état`, `numéro`, `contrôles`, `version du tracker`, `écriture`.

Le skill écrit dans le tracker seulement, une version par exécution, après confirmation. Publier, archiver ou supprimer une version reste le rôle du lecteur (`tracker.reader`).

## 1. Lire l'état

Deux lectures indépendantes, dans le même message :
- Versions publiées : RULES § « Lire l'état », dans un appel Bash à part. Échec : arrêt.
- Tracker : toutes les versions, archivées comprises (adaptateur § « Lire les versions »).

Classe chaque version du tracker d'après son nom (adaptateur § « Nom d'une version ») :
- **numérotée** : elle porte un numéro `X.Y.Z`
- module `poc`, **version POC** : ignorée, elle ne reçoit jamais de numéro (RULES § « POC »)
- **placeholder** : ni numérotée ni POC, ni publiée ni archivée
- les placeholders publiés ou archivés sont ignorés.

## 2. Numéro

`X.Y.Z` et `<But>` viennent de `$ARGUMENTS`, le but peut manquer.

Formulaire du numéro (RULES § « Confirmation des numéros ») :
- numéro fourni : en premier
- sinon, recommandé : la version mineure suivante du plus grand numéro connu, tracker et versions publiées confondus (`sort -V`). Avec 1.6.0 dans le tracker : 1.7.0
- « Other » pour saisir un autre numéro. Un numéro qui n'a pas la forme `X.Y.Z` est redemandé.

## 3. Contrôles

Dans cet ordre, arrêt au premier qui s'applique :

| Cas | Effet |
|---|---|
| X.Y.Z publiée (RULES § « Versions », « Version publiée ») | Refus, le numéro est consommé. Correctif : `/version-hotfix`, sinon un autre numéro |
| Plusieurs versions du tracker non archivées portent X.Y.Z | Arrêt avec la liste (id, nom, état) : doublon à faire résoudre par le lecteur |
| Une version du tracker non archivée porte X.Y.Z, publiée ou non | Réutilisation : affiche son id et son nom, rien n'est écrit. But différent du but fourni : signalé, sans renommer |
| X.Y.Z n'existe que dans des versions archivées | Arrêt avec la liste : le lecteur la désarchive ou la supprime |

## 4. Placeholder ou création

Placeholders existants : liste-les tous (id, nom). Puis, dans un formulaire, avant toute création :
- jusqu'à trois placeholders, les plus proches du but en premier, chacun avec son nom après numérotation
- « Créer `<nom>` » en dernier, nom de la version X.Y.Z et de son but (« Créer X.Y.Z » si le but manque)
- « Other » pour désigner un autre placeholder.

Nom après numérotation : X.Y.Z et le but du placeholder (adaptateur § « Nom d'une version »). But fourni différent : propose les deux noms dans une seconde question.

La numérotation garde l'id et les tickets du placeholder (RULES § « Versions »).

Sans placeholder : confirmation de la création, nom complet affiché.

Création choisie et but manquant, avec ou sans placeholders : demande le but dans un formulaire (« Other » pour le saisir), puis confirme le nom complet. Une version se crée toujours avec son but.

## 5. Écrire

Après le « oui », une seule écriture (adaptateur § « Créer ou modifier une version ») : numérotation du placeholder, ou création de la version X.Y.Z avec son but. Aucun autre champ. Relis ensuite la version et vérifie son nom.

## 6. Fin

Une ligne : action (créée, numérotée, réutilisée), id et nom. Appelé par `version-hotfix` : rends-lui cette ligne.

Rappelle que la version peut servir de version du ticket, et que sa release sera créée par `/ticket-start` au premier ticket de la version, ou par `/version-hotfix` pour un correctif.
