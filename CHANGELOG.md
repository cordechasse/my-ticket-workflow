# CHANGELOG

Numéros au format `X.Y.Z`, fixés par la migration qu'une montée demande au projet :
- majeur : migration requise (clé de config obligatoire ou renommée, hook à déclarer, fichier
  local à écrire)
- mineur : ajout sans obligation
- correctif : aucun geste.

Chaque version a un tag annoté `vX.Y.Z`. Montée de version : README § « Montée de version ».

## 1.1.0 (2026-11-27)

### Changements
- RULES § « Créer une release » : le bump remplace le seul numéro de chaque ligne de version, après
  une indentation éventuelle, et garde la suite de la ligne (`;`, commentaire). Un fichier peut
  porter plusieurs lignes de version (une par configuration de build), et chacune doit recevoir le
  nouveau numéro.
- `ticket-close` : le § « Liste pour le lecteur » de `translations.rules` peut fixer le titre, les
  colonnes et les clés de la liste des traductions du commentaire au lecteur. Sans lui, la liste
  garde son texte.
- FORMAT § « Notes » : le § « Ligne de Traductions » de `translations.rules` peut redéfinir le
  contenu d'une ligne de « Traductions » de `TICKET.md`. Sans lui, la ligne garde les textes de
  chaque langue.
- RULES § « Ticket sans modification de l'app » : la clé se cherche dans le sujet des commits
  seul, et `docs/`, `.claude/` et `maestro/` sont exclus. Un commit d'outillage, ou un autre ticket
  qui cite la clé, ne compte plus comme une modification de l'app.
- `setup_claude_memory.sh` crée le lien de la memory pour le CLI de Claude Code aussi, depuis le
  checkout principal, avec l'identifiant de projet calculé comme `check.sh`.
- `ticket-close` publie le paquet seulement quand son arbre diffère du dernier commit de squash
  du subtree : une chore qui tire seulement une version publiée n'a rien à publier.
- Exemples, prérequis et renvois de titres corrigés (README, FORMAT, RULES, `check.sh`,
  `statusline.sh`).

### Migration
Aucun geste requis. Pour le lien de la memory du CLI, relancer l'installation du projet (son
appel à `setup_claude_memory.sh`).

## 1.0.0 (2026-11-27)

### Changements
- Disposition à la racine : `skills/`, `workflow/`, `scripts/`, `hooks/`, `rules/`, `docs/`. Le
  paquet n'a plus de dossier `.claude/`.
- Intégration par `git subtree --squash` sous `.claude/vendor/my-ticket-workflow`, et liens
  relatifs depuis `.claude/` et `docs/` du projet. `sync.sh` et `.claude/workflow.lock` sont
  retirés.
- `.claude/settings.json` sort du paquet : le projet garde le sien, avec les entrées du README.
- `commit-msg-hook.sh` et `setup_claude_memory.sh` sont dans `scripts/`, donc sous
  `.claude/scripts/` du projet. `setup_claude_memory.sh` calcule la racine du projet par git.
- FORMAT § « Configuration » : règle « Contenu du paquet », aucune valeur d'un projet.
- `scripts/link.sh` crée les liens du projet d'après le contenu du paquet, et liste les écarts.
- `ticket-close` publie le paquet modifié par une chore avant sa fusion : `subtree push`, fusion
  et tag dans le dépôt du paquet, `subtree pull` du tag (FORMAT § « Session de chore »).
- `scripts/check.sh` contrôle l'installation : config contre `workflow/config-schema.yml`,
  adaptateurs, réglages, liens, memories, hook `commit-msg`, copie du paquet, fichiers locaux.
- `scripts/commit-msg-relay.sh` : hook `commit-msg` installé une fois dans le dossier des hooks,
  commun aux worktrees. Il lance le hook du paquet de la branche courante.
- Dépôt du paquet lu en HTTPS, poussé en SSH. Clés facultatives `package.url` et
  `package.push_url` pour un fork ou un essai.
- `ticket-close` publie une version calculée depuis le dernier tag du dépôt du paquet, vérifie que
  le tag n'existe pas, et pousse `main` et le tag ensemble (`push --atomic`).
- `hooks/ticket-detect.sh` signale en une ligne un lien du paquet manquant au démarrage.

### Migration
Depuis une copie installée par `sync.sh` :
1. Supprimer les copies du paquet, `.claude/scripts/sync.sh` et `.claude/workflow.lock`.
2. Sortir des dossiers liés chaque fichier local : un script local de `.claude/scripts/` va dans
   `scripts/` du projet, une règle locale reste dans `.claude/rules/`, hors de `paquet/`.
3. Ajouter le paquet : README § « Installation », étapes 1 et 5 (le relais vient au point 4).
4. Dans l'installation du projet, remplacer la copie de `scripts/commit-msg-hook.sh` par celle
   du relais (README § « Installation », étape 4).
5. Comparer `.claude/settings.json` aux entrées du README.
6. Lancer `.claude/scripts/check.sh` jusqu'à ce qu'il soit muet.
