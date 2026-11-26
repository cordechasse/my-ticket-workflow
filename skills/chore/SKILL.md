---
name: chore
description: Démarre une chore, de l'outillage interne sans ticket (skills Claude, scripts, outils de build et de CI). Branche chore/<description> et worktree depuis develop, onglet herdr, séance d'analyse avec l'utilisateur et TICKET.md dans docs/tickets/<slug>/. La suite passe par ticket-pause, ticket-resume et ticket-close.
argument-hint: "[description]"
effort: high
disable-model-invocation: true
---

# chore

Langue : français pour chaque texte visible, du premier au dernier message (FORMAT § « Langue »).

Une chore suit le déroulé de `ticket-start`, sans ticket. Lis d'abord, depuis la racine du dépôt :
- `.claude/skills/ticket-start/SKILL.md` : les étapes suivies
- `.claude/workflow/FORMAT.md`, § « Session de chore » en particulier
- `.claude/workflow/RULES.md` § « Rôle de `develop` ».

Chaque étape de `ticket-start` s'applique, avec les écarts ci-dessous. Une étape absente de cette liste s'applique telle quelle.

## 1. Session existante

Branche courante `chore/*` avec une session (`branch:` dans `docs/tickets/*/TICKET.md`) : annonce-le en une ligne et invoque `ticket-resume`. Le skill s'arrête là.

Branche de ticket, avec ou sans session : la chore ne la reprend pas. Elle part de `develop`, dans son propre worktree (étape 4).

## 2. Sujet

Remplace l'étape « Ticket ». Sujet pris dans `$ARGUMENTS`, sinon demandé (AskUserQuestion). Description de branche proposée : 2 à 4 mots en kebab-case, sans accent.
- Branche `chore/<description>` ou dossier du worktree déjà présents : signale-le, puis propose de reprendre cette branche ou de choisir un autre nom.
- Sujet limité aux memories (`.claude/context/`) : FORMAT § « Session de chore » prévoit un commit direct sur `develop`, sans session. Propose-le. Accepté : le skill s'arrête là.
- **Onglet et phase**, dès la description proposée, avant tout formulaire : `.claude/scripts/herdr-tab.sh "CHORE_<description>"` et `.claude/scripts/session-phase.sh "démarrage : branche" "CHORE_<description>"`, depuis le dossier de la session (FORMAT § « Nom court, onglet herdr et simulateur »). Branche `chore/*` courante sans session : sa description. Sujet limité aux memories : rien n'est renommé avant la réponse au formulaire de ce cas.

## 3. Base

Remplace l'étape « Version et base ». La base est toujours `develop` : ni tracker, ni versions publiées, ni release. `git fetch -q origin develop`, puis la branche part de `origin/develop`. `develop` n'a aucune source à fusionner (RULES § « Mise à jour d'une base »).

## 4. Branche et worktree

Selon la branche courante :
- **Branche `chore/*` sans session** (démarrée à la main) : formulaire, démarrer la session sur cette branche, ou créer `chore/<description>` (point suivant). Le premier choix est recommandé si le sujet correspond à la branche.
- **Autre branche** : formulaire avec la branche `chore/<description>`, la base (sha court, sujet et date de `origin/develop`) et le dossier `../<nom du dépôt principal>-<description>` (FORMAT § « Worktree »). Accord : session dans un worktree, `ExitWorktree` (`keep`) d'abord. Puis, depuis le dépôt principal, `git worktree add --no-track -b chore/<description> <dossier> origin/develop`, et `EnterWorktree` avec `path`.

Aucun statut de ticket. Description changée au formulaire : renomme l'onglet, et réécris la phase avec le nouveau nom court `CHORE_<description>` (FORMAT § « Nom court, onglet herdr et simulateur »).

## 5. Exploration

Comme dans `ticket-start`. Les sessions closes voisines comprennent les chores closes (FORMAT § « Session de chore »). Sujet sur les skills ou les règles : lis aussi `docs/SKILLS.md`, `docs/WORKFLOW.md` et les memories liées de `.claude/context/`.

## 6. Reproduction

Sautée : une chore n'est jamais un `Bug`.

## 7. Séance d'analyse

Comme dans `ticket-start`. Module `simulator` : le simulateur dédié est proposé seulement si un lot lance l'app.

Analyse qui montre que la chore est inutile : aucun `TICKET.md`. Efface la phase (`session-phase.sh --clear`), puis nettoyage, après accord : `ExitWorktree` (`keep`), `git worktree remove <dossier>`, `git branch -D chore/<description>`. Rien n'a été poussé. Les étapes 8 à 10 sont sautées.

## 8. Écriture

`TICKET.md` au format de FORMAT § « Session de chore » : `ticket: none`, `base: develop`, titre `# Chore — <sujet>`, « Reproduction » à `N/A — chore`, aucun test `(recette)`.

## 9. Audit

Comme dans `ticket-start`, sans le point du ticket `Bug`.

## 10. Fin

Comme dans `ticket-start`, avec le commit de démarrage sans clé : `docs(ticket): démarrage, <sujet>`. La ligne `ticket-close` du bloc de fin rappelle la cible : fusion `--no-ff` dans `develop`.
