---
name: version-close
description: Ferme une version publiée. Marque sa publication si la source le demande, passe le statut du commentaire de clôture de ses tickets à « Publié dans la X.Y.Z », fusionne release/X.Y.Z dans develop (--no-ff), puis dans releases.closed_release_also_into, pousse après confirmation, supprime la release et signale les tickets non finis.
argument-hint: "[X.Y.Z]"
disable-model-invocation: true
---

# version-close

Lis d'abord `.claude/workflow/RULES.md` (racine du dépôt), puis la config et les adaptateurs `tracker-<tracker.provider>` et `published-<releases.published>` (FORMAT § « Configuration »).

**Onglet et phase** (RULES § « Onglet herdr et phase ») : action `close`, version confirmée à l'étape 2. Étapes 1 à 6 : `état`, `version`, `préconditions`, `tracker`, `fusion`, `suppression`.

La clôture ramène dans `develop` tout ce que la release a reçu : tickets, bump, correctifs de recette, hotfix. La branche `releases.closed_release_also_into`, si la clé en nomme une, reçoit ensuite la release (RULES § « Rôle de `develop` »). Ces fusions sont les cibles de la clôture. Elle ne touche pas les releases ouvertes supérieures : chacune reçoit `develop` à sa prochaine mise à jour (RULES § « Releases en parallèle »). Chaque ticket est fusionné une seule fois, dans sa release. Dans le tracker, le skill écrit le statut des commentaires de clôture (étape 4), puis ce que prévoit l'adaptateur § « Publier une version » (étape 6). Le lecteur (`tracker.reader`) reporte les tickets non finis.

## 1. Lire l'état

Git et versions publiées (RULES § « Lire l'état »).

## 2. Version à fermer

Candidates : chaque `origin/release/V`, avec l'état de sa version, « publiée » ou « non publiée » (RULES § « Versions », « Version publiée »). Formulaire (RULES § « Confirmation des numéros »), l'argument en premier.

`origin/release/X.Y.Z` absente : refus, sans rien toucher. Elle est déjà fermée, ou jamais créée.

Version non publiée : adaptateur `published-<releases.published>` § « Marquer une version publiée ». Il refuse, et la release reste ouverte : ses correctifs continuent d'y arriver. Ou il marque la publication : relis alors les versions publiées (adaptateur § « Lire les versions publiées »), qui donnent le build publié.

## 3. Préconditions

Refus au premier qui s'applique :
- `release/X.Y.Z` existe en local et diffère de `origin/release/X.Y.Z`. En avance : des correctifs ne sont pas poussés. En retard : `git pull --ff-only` à faire
- `release/X.Y.Z` est extraite dans un worktree (RULES § « Checkout d'une branche ») : changer de branche là-bas d'abord, sinon la branche locale ne pourra pas être supprimée.

Pour information :
- commits de la release postérieurs au build publié (`git log --oneline <tag du build publié>..origin/release/X.Y.Z`, RULES § « Versions », « Build publié ») : jamais livrés, ils partent dans `develop` avec le reste
- release déjà contenue dans une cible (`git merge-base --is-ancestor origin/release/X.Y.Z origin/<cible>`) : la fusion dans cette cible est sautée.

## 4. Tracker

Version du tracker de numéro X.Y.Z, non archivée : adaptateur § « Lire les versions » et § « Nom d'une version ». Ses tickets : adaptateur § « Chercher des tickets », tickets d'une version, toutes les pages.

À signaler, sans rien écrire :
- les tickets dont le statut logique n'est ni `dans-un-build` ni `fait` (RULES § « Statuts »), avec leur statut : le lecteur les reporte sur une autre version ou les ferme
- les tickets dont la branche existe encore et n'est pas intégrée sur `origin/release/X.Y.Z` (RULES § « Ticket intégré sur une ref ») : du travail resté hors de la version
- les signalements de l'adaptateur § « Publier une version ».

Statut des commentaires : pour chaque ticket de la version, statut `Publié dans la X.Y.Z` (RULES § « Statuts », « Remplacer un statut »). Un statut `Aucune modification de l'app dans la version …` ou `Rien à faire` reste tel quel : l'app ne contient rien de ce ticket. Formulaire avant toute écriture : liste (clé, statut actuel ou « sans commentaire de clôture », action), tout écrire ou ne rien écrire. Aucune transition.

## 5. Fusionner dans les cibles

Pour chaque cible, `develop` puis `releases.closed_release_also_into`, sauf si elle contient déjà la release (étape 3) : RULES § « Fusion entre branches longues », avec pour source `origin/release/X.Y.Z`. Le formulaire de `develop` affiche aussi les signalements de l'étape 4. Conflit ou push refusé : arrêt, rien n'est supprimé.

Après les push, pour chaque cible :

```bash
git fetch -q origin
git merge-base --is-ancestor origin/release/X.Y.Z origin/<cible> && echo "release contenue dans origin/<cible>"
```

## 6. Supprimer la release et publier la version

Seulement si `origin/release/X.Y.Z` est contenue dans chaque cible (étape 3 ou 5), et après confirmation, en choix multiple si l'adaptateur tracker publie la version :
- supprimer la release, distante et locale :
  ```bash
  git push origin --delete release/X.Y.Z
  git rev-parse -q --verify refs/heads/release/X.Y.Z >/dev/null && git branch -D release/X.Y.Z
  ```
  `-D` est sûr ici : la branche locale est identique à la distante (étape 3), elle-même contenue dans `origin/develop`. Les tags de build de la version (gabarit `releases.build_tag`) restent, ils gardent l'historique des builds.
- publier la version dans le tracker : adaptateur § « Publier une version ».

## 7. Fin

Résumé : publication marquée, statuts écrits dans le tracker, fusions (sha), push, release supprimée, version publiée dans le tracker, signalements à transmettre au lecteur. Rappel : chaque release ouverte supérieure recevra la version fermée par `develop`, à sa prochaine mise à jour.
