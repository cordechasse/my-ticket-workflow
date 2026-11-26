---
name: version-hotfix
description: Ouvre le correctif d'une version publiée. Version du tracker X.Y.(Z+1) via version-start, puis release/X.Y.(Z+1) depuis le tag du build publié avec le commit de bump, poussée après confirmation, sans toucher au checkout.
argument-hint: "[X.Y ou X.Y.Z]"
disable-model-invocation: true
---

# version-hotfix

Lis d'abord `.claude/workflow/RULES.md` (racine du dépôt), puis la config et l'adaptateur `published-<releases.published>` (FORMAT § « Configuration »).

**Onglet et phase** (RULES § « Onglet herdr et phase ») : action `hotfix`, version confirmée à l'étape 2, `<version>` = X.Y.(Z+1). Étapes 1 à 5 : `état`, `version`, `contrôles`, `version du tracker`, `release`.

Le hotfix part du tag du build publié (RULES § « Versions », « Build publié »), le build que les utilisateurs ont reçu : ni `develop`, ni le dernier tag de build prod, qui peut être une Release Candidate jamais publiée.

## 1. Lire l'état

Git et versions publiées (RULES § « Lire l'état »). Le tracker est lu par `version-start` à l'étape 4.

## 2. Version à corriger

La version corrigée est la dernière version publiée de sa ligne X.Y (`published: true`, la plus grande en `sort -V`). Le hotfix porte X.Y.(Z+1).

Formulaire (RULES § « Confirmation des numéros ») :
- argument `X.Y` ou `X.Y.Z` : sa ligne en premier
- sinon : la ligne de la dernière version publiée, recommandée
- chaque option affiche la version corrigée, son build publié et le numéro du hotfix (`1.4.1, build 162 → 1.4.2`).

Ligne sans version publiée : arrêt, ce n'est pas un hotfix. Une version ouverte se corrige sur sa release avec `/ticket-start`.

## 3. Contrôles

Refus au premier qui s'applique, sans rien écrire :

| Cas | Commande | Message |
|---|---|---|
| Tag du build publié absent | `git tag --list "<tag du build publié>"` | Le build publié n'a pas de tag : base introuvable |
| `origin/release/X.Y.(Z+1)` existe | `git rev-parse -q --verify origin/release/X.Y.(Z+1)` | Hotfix déjà ouvert : ses correctifs partent de cette release (`/ticket-start`) |
| `release/X.Y.(Z+1)` existe en local | `git rev-parse -q --verify refs/heads/release/X.Y.(Z+1)` | Branche locale d'une ancienne tentative : à pousser ou supprimer d'abord |

## 4. Version du tracker

Invoque le skill `version-start` avec `X.Y.(Z+1) Fix` : il réutilise la version de ce numéro, propose de numéroter un placeholder ou crée la version X.Y.(Z+1) de but `Fix`, après confirmation. Il s'arrête ou l'utilisateur refuse : arrête-toi aussi, une release a toujours sa version du tracker.

## 5. Créer et pousser

RULES § « Créer une release », avec `v` = X.Y.(Z+1) et `base` = le tag du build publié. Un seul formulaire vaut accord pour la création et le push.

## 6. Fin

Une ligne : `release/X.Y.(Z+1)` créée depuis le tag du build publié, poussée ou non, identique sur origin, version du tracker.

Puis la suite :
- correctifs : `/ticket-start` avec la version du ticket X.Y.(Z+1), la branche part de `release/X.Y.(Z+1)`
- builds : les skills de build du projet, staging puis prod
- releases ouvertes supérieures : elles reçoivent le hotfix quand une session touche leur version, fusion proposée (RULES § « Releases en parallèle »)
- après la publication : `/version-close` fusionne la release dans `develop`.
