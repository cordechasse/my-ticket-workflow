---
name: ticket-resume
description: Reprend un ticket ou une chore depuis docs/tickets/<slug>/TICKET.md. Convertit l'ancien format à 4 fichiers, signale les écarts avec git et une reproduction de bug manquante, propose la prochaine action, puis suit la conduite de session. À utiliser pour reprendre un ticket, ou quand le hook de démarrage détecte une session.
argument-hint: "[session]"
effort: high
---

# ticket-resume

Langue : français pour chaque texte visible, du premier au dernier message (FORMAT § « Langue »).

Lis d'abord `.claude/workflow/FORMAT.md` (racine du dépôt).

## 1. Choisir la session

1. `$ARGUMENTS` fourni : `docs/tickets/$ARGUMENTS/`.
2. Sinon : la session dont `branch:` = branche courante, dans `TICKET.md`, ou dans `STATE.md` pour l'ancien format.
3. Sinon : liste les tickets en cours de ce checkout et de chaque worktree de `git worktree list` (`<worktree>/docs/tickets/*/TICKET.md`, ou `STATE.md` pour l'ancien format : slug, branche, `last_pause`, dossier) et demande laquelle (AskUserQuestion). Aucune session : dis-le et propose `/ticket-start`, ou `/chore` sur une branche `chore/`.

**Onglet et phase**, dès la session trouvée, avant tout formulaire : `.claude/scripts/herdr-tab.sh "<nom court>"` et `.claude/scripts/session-phase.sh "reprise" "<nom court>"`, nom court de la branche de la session, depuis le dossier de la session (FORMAT § « Nom court, onglet herdr et simulateur », § « Phase dans la status line »). Ils remplacent un nom ou une phase qu'un démarrage ou une clôture interrompus ont pu laisser.

Branche de la session différente de la branche courante, proposée dans un formulaire :
- un worktree la tient : y entrer (`EnterWorktree` avec `path`)
- aucun : lui en créer un (FORMAT § « Worktree »), `git worktree add <dossier> <branche>`, puis `EnterWorktree` avec `path`.

Le checkout du dépôt principal reste sur sa branche. Pièges d'une session dans un worktree : FORMAT § « Worktree ».
## 2. Charger

Lis `TICKET.md` en entier. Absent et `STATE.md` présent : ancien format, convertis-le d'abord (ci-dessous).

### Conversion de l'ancien format

Le ticket a 4 fichiers : `SPEC.md`, `DECISIONS.md`, `STATE.md`, `TESTS.md`. Un de ces fichiers est modifié et non commité : propose d'abord son commit, pour que l'historique garde l'ancien état.

Lis les 4 fichiers. DECISIONS.md très long : titres et statuts d'abord, puis le détail des seules décisions reprises. Écris `TICKET.md` au format de FORMAT § « TICKET.md », dans ses limites (§ « Taille ») :

| Section | Source |
|---|---|
| Frontmatter | celui de STATE.md, `last_pause` et `last_commit` gardés |
| Statut | « Prochaine action », « En cours », « Questions ouvertes » de STATE.md |
| Contexte | « Contexte et objectif », « Dépôts et mise en place », « Architecture cible » de SPEC.md, la part qui décrit l'existant |
| Objectif et périmètre | « Contexte et objectif », « Périmètre », « Contraintes », « Comportements attendus et cas limites » de SPEC.md |
| Sujets analysés | décisions structurantes actées et non remplacées, compactées et renumérotées `S1`, `S2`… Les tactiques et les décisions remplacées ne sont pas reprises. Une décision encore ouverte : sujet ouvert. |
| Parcours | construit depuis « Architecture cible » et « Lots » de SPEC.md |
| Lots | lot fini en une ligne, avec les hashes de « Fait » de STATE.md. Lot en cours détaillé. Lot à venir en 1 ou 2 lignes. |
| Tests | TESTS.md. Test manuel validé compacté. « Reproduction » reprise telle quelle. |
| Notes | « Pièges et connaissances acquises » de STATE.md, « Risques », « Traductions », « À ne pas oublier » de SPEC.md |

Une référence `D-0xx` dans le texte repris devient la référence du sujet (`Sn`), ou disparaît si la décision n'est pas reprise.

Tests `(recette)` (FORMAT § « Tests ») : propose ceux qui servent de recette au lecteur (`tracker.reader`), en général un par problème corrigé ou par changement visible d'une `Task`. Ils gardent leurs étapes, validés ou non.

Puis `git rm -q` des 4 fichiers. `maestro/` reste en place.

Présente la conversion :
- nombre de lignes par section, et le total
- sujets repris, avec leur ancienne référence `D-0xx`
- décisions non reprises, par catégorie (tactiques, remplacées), avec leur nombre
- tests `(recette)` proposés.

L'utilisateur relit `TICKET.md` dans son éditeur, et donne ses corrections en texte. Validé : propose le commit `docs(ticket): conversion au format TICKET.md #<clé>` (FORMAT § « Commits »), avant la suite de la reprise. Le détail non repris se relit dans l'historique git des 4 fichiers.

## 3. Écarts avec git

Pour le repo et chaque `related_repos` :
- `git log --oneline <last_commit>..HEAD` : commits faits hors session
- `git status --short` comparé à « En cours » de « Statut »
- `last_commit` absent de l'historique (rebase, reset).

Retards, pour le repo seulement (RULES § « Mise à jour d'une base »), une commande git par appel :
- base : `base:` de `TICKET.md`. Absente : base a posteriori (RULES § « Base d'une branche a posteriori »), avec les `origin/release/*` comme releases ouvertes et la version du ticket lue dans le tracker en cas d'égalité
- `git fetch --prune origin`
- retard de la base sur ses sources (point 1) : releases inférieures et `develop` pas encore contenues
- retard de la branche sur la base (point 2).

Signale les écarts sans corriger `TICKET.md` : la prochaine pause les intégrera.

## 4. Reproduction (ticket `Bug`)

Section « Reproduction » de « Tests » (FORMAT § « Tests ») :
- `N/A — ticket Task` ou `N/A — chore` : rien à faire.
- flows listés, présents dans `maestro/` : rien à faire ici. Le simulateur se décide à l'étape 5.
- lignes « sans flow » (non reproduit ou sauté, constat, test unitaire rouge) : rappelées dans le résumé. Test unitaire rouge « à écrire » : il reste la première étape du lot de correctif.
- absente (session plus ancienne que la reproduction) : type du ticket jugé comme à l'étape 2 de `ticket-start` (point « Type », changement proposé en cas d'écart). `Task` : rien à faire. `Bug` : reproduction manquante.
- vide, ou ni flow ni lignes « sans flow » : reproduction manquante.

Ticket `Bug`, dans tous les cas : un correctif sans test unitaire dans « Tests » ni ligne `Sans test unitaire` est signalé, et le test est proposé comme critère du lot de correctif (FORMAT § « Flows de reproduction », point « Tests unitaires »).

Reproduction manquante : elle devient la première action proposée, avant la « Prochaine action » de « Statut ». Une fois acceptée, procédure de l'étape 6 de `ticket-start` (simulateur dédié, chemin, flows, essais limités), avec un cas de plus :
- correctif déjà commité (lot de correctif `✓` dans « Lots », `git log --oneline origin/<base>..HEAD`) : un flow écrit maintenant serait vert sur la branche et ne prouverait pas le bug. Working tree propre : `git merge-base HEAD origin/<base>`, puis `git switch --detach <hash>` (hash écrit en clair), build et rejeu, rouge attendu sur l'assertion. Ensuite `git switch <branche>`, build et rejeu, vert attendu : case « Correctif » cochée. Working tree sale : rejeu sur la branche seulement, et `Bug confirmé : non prouvé, correctif déjà présent (<hash>)` dans « Reproduction ».

Résultat écrit tout de suite, sans attendre la pause : flows dans `maestro/`, section « Reproduction » (flows, ou les 3 lignes « sans flow »), et dans « Lots » les critères du lot de correctif : « flows de reproduction verts » pour un bug reproduit, test unitaire rouge en première étape s'il sert de preuve.

## 5. Présenter et attendre

Efface la phase `reprise` (`.claude/scripts/session-phase.sh --clear`) : le chemin de fer de `TICKET.md` prend le relais. Un arrêt avant cette étape l'efface aussi.

Une seule réponse, dans l'ordre de FORMAT § « Conduite de session », point « Ordre d'une réponse ». Une partie vide est omise.

1. **Alertes** : écarts avec git (étape 3), reproduction manquante, correctif de `Bug` sans test unitaire (étape 4).
2. **État** :
   - la chaîne des lots de « Parcours », `✓` et `▶` à jour, et la position (`Lot N sur M, reste : <lots suivants>.`)
   - résumé en 3 lignes depuis « Statut » : lot en cours et étape, fait depuis la dernière pause, reste
   - reproduction (étape 4) : flows et état, ou raison de la non-reproduction
   - questions ouvertes de « Statut » qui ne bloquent pas la prochaine action, en une ligne.
3. **Proposition** :
   - prochaine action. Début d'un lot : l'annonce de FORMAT § « Conduite de session », règle 1, sans sa question
   - retards, chacun avec sa fusion proposée, facultative : d'abord chaque source en retard sur la base, puis la branche en retard sur la base (nombre de commits, fusions de tickets apportées)
   - module `simulator` : simulateur dédié (FORMAT § « Nom court, onglet herdr et simulateur »). Il existe, il est réutilisé (nom, udid). Sinon, sa création est la question 3.
4. **Questions**, en dernier, numérotées dans l'ordre où les actions se font. Chaque recommandation est sous sa question (FORMAT § « Conduite de session », point « Recommandation ») :
   1. fusion de chaque source dans la base
   2. fusion de la base dans la branche
   3. module `simulator` : création du simulateur dédié, coût affiché, puis la recommandation : oui si la prochaine action ou un lot à venir passe par l'app sur simulateur, si la reproduction manque, ou si un flow de reproduction n'a pas encore sa ligne « Correctif » cochée (FORMAT § « Flows de reproduction »)
   4. reproduction manquante
   5. questions ouvertes de « Statut » qui bloquent la prochaine action
   6. la prochaine action, en dernier (`On lance le lot N ?` au début d'un lot).

Attends la réponse avant d'écrire du code. Simulateur accepté : crée-le avant la prochaine action. Reproduction manquante acceptée : fais-la avant la prochaine action (étape 4).

Fusions acceptées, avant la prochaine action, dans cet ordre :
1. Sources dans la base : `ExitWorktree` (`keep`), RULES § « Fusion entre branches longues » depuis le dépôt principal, puis `EnterWorktree` avec `path`. Puis `git fetch -q origin <base>`.
2. Base dans la branche : RULES § « Mise à jour d'une base », point 2, seule commande git de l'appel. Working tree sale : signale-le et passe, la fusion attendra un commit ou une pause.

Refusée : rien n'est fusionné, et la question revient à la reprise suivante.

## 6. Pendant la session

Jusqu'à la fin de la conversation : FORMAT § « Conduite de session ». Avant un `/clear` en cours de lot, ou en fin de travail : rappelle `/ticket-pause`.
