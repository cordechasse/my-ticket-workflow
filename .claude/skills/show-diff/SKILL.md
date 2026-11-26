---
name: show-diff
description: Ouvre l'outil Git de l'utilisateur (Sublime Merge, Fork…) sur le worktree courant, puis explique chaque modification de la branche depuis sa base, non commité compris. Pendant un lot de ticket, propose la branche complète ou le lot en cours. Au premier lancement, demande l'outil et l'enregistre dans le git config du clone. À utiliser pour voir, relire ou expliquer les modifications de la branche ou du lot.
---

# show-diff

Le skill lit le dépôt et ouvre une application. Il écrit une seule chose : la clé `my-ticket-workflow.gitClient` du git config, au premier lancement.

Une commande git simple par appel, avec les chemins et les hashs écrits en clair. Une session entrée dans un worktree refuse les commandes composées et les `$(…)`. Lance les appels indépendants dans le même message.

## 1. Ouvrir l'outil Git

1. `git rev-parse --show-toplevel` donne le worktree courant.
2. `git config --get my-ticket-workflow.gitClient` donne l'outil enregistré.
3. Aucun outil enregistré :
   - liste les clients Git installés : `ls -1 /Applications ~/Applications 2>/dev/null | grep -iE '^(Fork|Tower|Sublime Merge|GitKraken|Sourcetree|GitHub Desktop|SmartGit|GitUp)\.app$'`
   - formulaire (AskUserQuestion) : un client installé par option, 4 au plus, dans l'ordre alphabétique. Moins de 2 clients installés : complète avec des clients connus, marqués « non installé ». « Other » sert à saisir le nom d'une autre application
   - enregistre la réponse : `git config my-ticket-workflow.gitClient "<application>"`. Sans `--global` ni `--worktree`, la clé va dans le `.git/config` du clone, partagé par tous ses worktrees
   - dis en une ligne où le choix est enregistré, et comment le changer : `git config --unset my-ticket-workflow.gitClient`, puis `/show-diff` repose la question.
4. `open -a "<application>" <worktree>`. Échec : montre la sortie d'erreur, propose `git config --unset my-ticket-workflow.gitClient`, puis passe à l'étape 2. L'explication ne dépend pas de l'outil.

## 2. Trouver le diff

La base est la branche d'où part la branche courante (`git branch --show-current`). Le premier cas qui s'applique donne la base :

| Branche courante | Base |
|---|---|
| Aucune (HEAD détachée) | Aucune : le non commité seulement, `<départ>` = `HEAD` |
| Un `docs/tickets/*/TICKET.md` porte `branch: <branche>` | Son champ `base:` |
| `chore/*` | `develop` |
| `develop`, `main`, `release/*`, `poc/*` | La branche elle-même : ses commits non poussés |
| Autre | RULES § « Base d'une branche a posteriori » (`.claude/workflow/RULES.md`), avec les `origin/release/*` comme releases ouvertes |

La base a posteriori n'a pas besoin de la version du ticket en cas d'égalité : les candidats à égalité ont le même point de départ, donc le même diff.

`git merge-base origin/<base> HEAD` donne le point de départ de la branche, noté `<départ>`. Sans `origin/<base>` (branche jamais poussée) : la ref locale `<base>`.

### Périmètre

Le `TICKET.md` de la branche a, dans « Lots », un lot `▶` et au moins un lot `✓` : formulaire (AskUserQuestion), « Branche complète » ou « Lot N en cours », avec le titre du lot `▶` en description. Sinon, le périmètre est la branche complète.

Lot en cours : `git log --no-walk --ignore-missing --format='%h %s' -1 <hashs des lots ✓>` donne le commit le plus récent des lots finis. Il remplace `<départ>` pour la suite. L'ordre des lots dans le fichier ne compte pas : un lot peut changer de place. `--ignore-missing` écarte le hash d'un lot fait dans un repo lié. Sortie vide : le périmètre est la branche complète, dis-le en une ligne.

### Listes

Branche complète :
- `git log --oneline --no-merges <départ>..HEAD` donne les commits de la branche
- `git diff -M --stat <départ>` donne les fichiers modifiés depuis le départ, index et working tree compris
- `git ls-files --others --exclude-standard` donne les fichiers non suivis.

Lot en cours :
- `git log --oneline --no-merges --first-parent <départ>..HEAD` donne les commits du lot. `--first-parent` écarte les commits apportés par une fusion de la base
- `git log --no-merges --first-parent --name-only --format= <départ>..HEAD` et `git diff --name-only HEAD` donnent les fichiers du lot, commités ou non. Chaque chemin compte une fois
- `git ls-files --others --exclude-standard` donne les fichiers non suivis
- `git log --oneline --merges --first-parent <départ>..HEAD` donne les fusions de la base pendant le lot. Pour chacune, `git diff --name-only <fusion>^1 <fusion>` donne les fichiers qu'elle modifie.

Aucun commit, aucun fichier modifié, aucun fichier non suivi : dis-le, et arrête-toi là.

## 3. Expliquer

Lis le diff fichier par fichier : `git diff -M <départ> -- <fichier>`. Un fichier non suivi se lit en entier. Sans lecture du diff, la ligne de `git diff -M --stat <départ> -- <fichier>` suffit pour :
- un `project.pbxproj`, un `Package.resolved`, un asset (`*.xcassets`, image) ou un fichier binaire
- le dossier de travail du ticket (`docs/tickets/<slug>/`).

Un fichier du lot modifié aussi par une fusion de la base : son diff contient des modifications de la base. `git diff <fusion>^1 <fusion> -- <fichier>` montre lesquelles.

Le pourquoi de chaque modification vient de la conversation, de `TICKET.md` (sujets analysés, lots) et des messages des commits. Une modification venue d'une fusion de la base a pour pourquoi « apportée par la fusion de `<base>` ». Sans source, écris « raison non tracée ». N'invente jamais une raison.

Réponse :
- en tête, en une ligne : l'outil ouvert, le worktree, la base, le périmètre (branche complète ou lot N), le nombre de commits et de fichiers
- les fichiers hors périmètre, signalés en tête : scheme (`*.xcscheme`), `xcuserdata`, config locale (`CLAUDE.local.md`, `.claude/settings.local.json`), `project.pbxproj` modifié sans raison connue
- les fusions de la base pendant le lot, signalées en tête, avec les fichiers du lot qu'elles modifient aussi
- un titre par fichier, dans l'ordre des chemins. Les fichiers non suivis viennent ensuite, marqués « non suivi »
- sous chaque titre, une ligne par modification : `<fichier>:<ligne>` (ligne du working tree), ce qui change, puis pourquoi. Un hunk peut contenir plusieurs modifications, car git fusionne les modifications dont les lignes de contexte se touchent. Des modifications identiques (même renommage répété) tiennent en une ligne, avec leur nombre.
