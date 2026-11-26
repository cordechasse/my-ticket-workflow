# Skills Claude Code : tickets, versions et revue

Ce document explique ce que fait chaque skill, quand le lancer, comment il se déroule et ce qu'il modifie. Le modèle de branches et de versions qu'ils appliquent est décrit dans [`WORKFLOW.md`](WORKFLOW.md), les conventions de commit dans [`COMMITS.md`](COMMITS.md). Les skills propres au projet sont dans `SKILLS-LOCAL.md`, fichier local du projet, s'il existe.

Les valeurs propres au projet sont dans `.claude/workflow.yml`, citées ici par leur chemin (`tracker.states`), et le geste propre à un service dans `.claude/workflow/adapters/` (FORMAT § « Configuration »). Les exemples suivent les conventions de [`WORKFLOW.md`](WORKFLOW.md) :
- clé de ticket `APP-1234`, pour `tracker.key_prefix` = `APP-`
- `develop` pour `releases.integration_branch`
- statuts logiques de `tracker.states` : `en-cours`, `a-livrer`, `dans-un-build`, `fait` (RULES § « Statuts »)
- le lecteur : `tracker.reader`, qui lit les tickets, valide la recette et soumet la version au store.

Les builds passent par des skills propres au projet : le **skill de build staging** et, s'il existe, le **skill de build prod**, décrits dans `SKILLS-LOCAL.md`.

## 1. Une version de bout en bout

Les commandes d'une version, dans l'ordre. Exemple de la 1.6.0 avec deux tickets et un correctif de recette :

```text
/version-start 1.6.0 Mode hors ligne         version 1.6.0 dans le tracker, avec son but
/ticket-start APP-1                           premier ticket : release/1.6.0 créée (bump 1.6.0),
                                              puis branche, worktree, TICKET.md, ticket en-cours
/ticket-pause                                 fin de session : état sauvegardé, commits proposés
/ticket-resume                                reprise (proposée d'office à l'ouverture d'une session)
/ticket-close                                 fusion dans release/1.6.0, ticket a-livrer
/ticket-start APP-2                           part de release/1.6.0
/ticket-close
skill de build staging                        build 1.6.0+N.staging, tickets dans-un-build
/ticket-start APP-3                           correctif de recette, part de release/1.6.0
/ticket-close                                 fusion dans release/1.6.0
skill de build staging                        nouveau build de recette
skill de build prod, s'il existe              Release Candidate 1.6.0+N.prod
                                              lecteur : validation, soumission au store, publication
/version-close                                tickets « Publié dans la 1.6.0 », release fusionnée
                                              dans develop, puis supprimée
/version-health 1.6.0                        module crash_reporter, J+3 puis J+7 : stabilité lue
                                              dans le rapport de crash, ticket et note proposés
```

Le commentaire de clôture d'un ticket suit sa livraison. Son statut passe de « En attente de livraison » (`/ticket-close`) à « Dispo dans la version 1.6.0+N » (skill de build staging), puis à « Publié dans la 1.6.0 » (`/version-close`).

Pendant la recette, la version suivante peut démarrer : le premier `/ticket-start` d'un ticket de la version 1.7.0 crée `release/1.7.0` depuis `release/1.6.0`. Ensuite, chaque fois qu'une session touche la 1.7.0 (démarrage ou reprise d'un de ses tickets, build), elle propose de fusionner `release/1.6.0` et `develop` s'ils ont avancé. Travailler sur la 1.6.0 ne touche jamais la 1.7.0.

Correctif d'une version déjà publiée (source `releases.published`) :

```text
/version-hotfix 1.6                          version 1.6.1 dans le tracker, release/1.6.1
                                              depuis le build publié
/ticket-start APP-4                           part de release/1.6.1
/ticket-close
skill de build staging
skill de build prod, s'il existe
/version-close
```

## 2. Vue d'ensemble

| Skill | Rôle | Lancement | Git | Tracker | Externe |
|---|---|---|---|---|---|
| `/ticket-start` | Démarrer un ticket | Manuel | `release/X.Y.Z`, bump et push au premier ticket d'une version, branche, worktree, commit de démarrage | Création du ticket, type corrigé, version du ticket, `en-cours` | |
| `/ticket-pause` | Sauvegarder l'avancement | Manuel ou automatique | Commits proposés | | |
| `/ticket-resume` | Reprendre un ticket | Manuel ou automatique | Worktree si besoin. Retards proposés à la fusion : release sur ses sources, puis branche sur la release | Type corrigé, session plus ancienne que la reproduction seulement | |
| `/ticket-close` | Clôturer et intégrer un ticket | Manuel | Commits de clôture, fusion, push, suppressions | Commentaire au lecteur au statut « En attente de livraison », `a-livrer` | |
| `/ticket-check` | Vérifier un ticket déjà traité | Manuel | Lecture seule | Lecture seule | |
| `/chore` | Démarrer une chore (outillage sans ticket) | Manuel | Branche `chore/`, worktree et commit de démarrage, depuis `develop` | | |
| `/version-start` | Planifier une version | Manuel ou automatique | | Création ou renommage d'une version | |
| `/version-hotfix` | Ouvrir un correctif de production | Manuel | `release/X.Y.(Z+1)`, bump, push | Version `X.Y.(Z+1)` | |
| `/version-close` | Fermer une version publiée | Manuel | Fusion dans `develop` (et `releases.closed_release_also_into`), push, suppression de la release. Source `git-tags` : tag `vX.Y.Z` | Statut du commentaire de clôture | |
| `/version-health` | Lire la stabilité d'une version publiée (module `crash_reporter`) | Manuel | Lecture seule | Création d'un `Bug` après accord | Rapport de crash en lecture, note après accord |
| `/show-diff` | Relire les modifications de la branche | Manuel ou automatique | Lecture seule. Clé `my-ticket-workflow.gitClient` du git config au premier lancement | | Outil Git de l'utilisateur |

**Lancement** : un skill manuel se lance seulement en tapant `/nom`. C'est le cas de tous ceux qui poussent, publient ou écrivent dans le tracker. Un skill « manuel ou automatique » peut aussi être lancé par Claude quand la demande y correspond (« on fait une pause »), ou par un autre skill : `ticket-start` appelle `ticket-resume`, `version-hotfix` appelle `version-start`.

**Principes communs**
- Chaque écriture externe (push, suppression distante, tracker, publication) et chaque commit attend un accord explicite dans un formulaire. Un formulaire vaut accord pour ce qu'il affiche, et rien de plus.
- Tout numéro de version calculé par un skill est soumis dans un formulaire à choix, le recommandé en premier.
- Le checkout de l'utilisateur reste sur sa branche. Un ticket vit dans son worktree (`../<dépôt>-APP-<n>`, FORMAT § « Worktree »), une release se crée dans un worktree temporaire, une fusion se fait là où la branche cible est extraite.
- Sources de vérité : la source `releases.published` pour la publication d'une version, le tracker pour les versions et la version de chaque ticket, `origin` pour les branches.
- Une écriture dans le tracker pose toujours le commentaire avant le statut : une relance rattrape un commentaire manqué sans le doubler.

## 3. Skills de ticket

Ils tiennent le dossier de travail du ticket dans `docs/tickets/<slug>/`, sur la branche du ticket :

| Fichier | Contenu |
|---|---|
| `TICKET.md` | Statut, contexte, objectif et périmètre, sujets analysés, parcours, lots, tests, notes (pièges, traductions) |
| `maestro/*.yaml` | Ticket `Bug` : flows Maestro qui prouvent le bug (rouges), puis son correctif (verts) |

`TICKET.md` reste court : un seul lot détaillé, celui en cours. Un sujet tranché, un lot fini ou un test validé tient en une ligne, et son détail se relit dans l'historique git. Format complet : [`FORMAT.md`](../.claude/workflow/FORMAT.md) § « TICKET.md ». Un ticket ouvert avant ce format a 4 fichiers (`SPEC.md`, `DECISIONS.md`, `STATE.md`, `TESTS.md`) : `/ticket-resume` les convertit à la reprise.

Pendant le code, Claude suit la conduite de session (FORMAT § « Conduite de session ») :
- il annonce chaque lot avec la chaîne des lots, ses fichiers et ses étapes, puis attend ton accord
- il suit le plan au plus simple, et signale tout ajout avant de l'écrire
- il montre un bloc `diff` après chaque modification
- il propose les tests manuels un par un, au format de [`.claude/rules/paquet/manual-tests.md`](../.claude/rules/paquet/manual-tests.md)
- il finit chaque lot par un bloc qui dit si `/clear` et `/ticket-close` sont possibles.

Ce dossier n'arrive jamais dans `develop` ni dans une release : la clôture le supprime avant la fusion, et la synthèse passe dans le message du commit de clôture.

Une chore, de l'outillage sans ticket, a le même dossier et le même suivi, sans tracker : `/chore` la démarre (§ « chore » ci-dessous).

### ticket-start

**Rôle** : démarrer un ticket. Il relie le travail à un ticket du tracker, choisit la branche de base d'après la version du ticket, crée la branche dans son worktree, puis analyse le ticket avec toi en séance, un sujet à la fois. Pour un bug, il le reproduit d'abord sur le simulateur dédié, avec des flows Maestro (modules `simulator` et `maestro`). Ces flows s'ajoutent aux tests unitaires, obligatoires pour un correctif.

**Quand** : au début de tout ticket, nouveau ou rouvert après un refus en recette.

**Usage** : `/ticket-start APP-1234`, `/ticket-start APP-1234 mode hors ligne` ou `/ticket-start mode hors ligne` (le skill propose alors de créer le ticket). Lancé depuis une branche qui a déjà une session, il bascule sur `/ticket-resume`.

```text
/ticket-start
  │
  ▼
Session existante sur la branche ?
  ├── oui ──► /ticket-resume
  │ non
  ▼
Ticket du tracker
  ├── clé fournie ──► Lecture du ticket (clôture précédente relue si rouvert) ──┐
  │ aucun                                                                       │
  ▼                                                                             │
Brouillon validé, puis création                                                 │
  │                                                                             │
  ├─────────────────────────────────────────────────────────────────────────────┘
  ▼
Type Bug ou Task jugé d'après le sujet
  ├── mal typé ──► Changement de type proposé, écrit après accord
  │
  ▼
Version confirmée, version du ticket écrite si elle change
  │
  ▼
Base selon la version du ticket
  ├── version publiée, ligne hotfix ou version en suspens ──► Arrêt → /version-hotfix
  ├── version sans release ──► Création et push de release/X.Y.Z après accord
  │                            (refus : pas de branche)
  │ release/X.Y.Z ou poc/<nom>
  ▼
Base en retard sur ses sources (releases inférieures, develop) ?
  ├── oui ──► Fusion proposée pour chacune, facultative
  │
  ▼
Branche et worktree depuis origin/base, ticket en-cours
  │
  ▼
Exploration du code et des tickets clos voisins
  │
  ▼
Type Bug ?
  ├── oui ──► Preuve du bug, dans cet ordre :
  │           1. flows Maestro rouges sur le simulateur dédié (créé après
  │              accord), dans docs/tickets/slug/maestro/
  │           2. sinon test unitaire rouge, première étape du correctif
  │           3. sinon constat (rapport de crash, support, capture)
  │           Flow sauté sur accord pour un bug trivial
  │ non
  ▼
Séance d'analyse en texte, sans formulaire : liste des sujets, puis un sujet
par réponse (contexte, options en schéma et code, avis, ta décision),
parcours et lots, tests (simulateur dédié créé si besoin, après accord)
  │
  ▼
Écriture de TICKET.md, puis audit
  │
  ▼
Bloc de fin et annonce du lot 1, puis les questions en dernier :
commit « démarrage » (formulaire en fin de tour), lancement du lot 1
```

La règle complète de choix de la base est dans [`WORKFLOW.md`](WORKFLOW.md), § 3 « Choix de la branche de base ».

| Impact | Détail |
|---|---|
| Git | Premier ticket d'une version : `release/X.Y.Z` créée depuis la release ouverte inférieure (sinon `origin/develop`) avec le commit `chore(release): X.Y.Z`, et poussée, après accord. Branche `<type>/APP-<n>_<description>` créée depuis `origin/<base>`, sans suivi distant. Worktree `../<dépôt>-APP-<n>`, dans lequel la session entre. Commit `docs(ticket): démarrage, … #APP-<n>`, non poussé |
| Fichiers | `docs/tickets/<slug>/TICKET.md`, plus `maestro/` (flows de reproduction) pour un `Bug`. `TICKET.md` garde la base dans `base:` |
| Onglet et simulateur | Nom court du ticket : la branche sans `<type>/` (`APP-<n>_<description>`). Onglet herdr de la session renommé ainsi dès le ticket lu, avant tout formulaire, puis renommé encore si la description change au formulaire de branche. Module `simulator` : simulateur dédié de ce nom créé après accord, avec le certificat `simulator.root_cert`. Pour un `Bug`, il est proposé dès la reproduction |
| Tracker | Ticket créé si besoin (assigné à toi, reporter `tracker.reporter`), type `Bug` ou `Task` corrigé après accord s'il ne correspond pas au sujet, version du ticket écrite si elle change, statut `en-cours` |

Arrêts : version publiée, ligne hotfix sans release, version sans release plus basse qu'une release ouverte, aucune version choisie, création de la release refusée. Avertissement sans arrêt : version placeholder, base sur la release ouverte la plus récente (le ticket ne pourra être intégré qu'une fois la version numérotée). Module `poc`, version POC : base `origin/poc/<nom>`, nommée par la description de la version ; sans description, formulaire parmi les `origin/poc/*` ou nouveau POC (`poc/<nom>` créée depuis la release ouverte la plus récente, choisie dans un formulaire s'il y en a plusieurs, sinon `origin/develop`, et poussée), puis description écrite, chaque écriture après accord.

### ticket-pause

**Rôle** : sauvegarder l'état du ticket pour qu'une session neuve reprenne sans rien perdre. Il recoupe la conversation avec git, pas seulement avec la mémoire de Claude.

**Quand** : en fin de session, avant un `/clear`, ou avant de passer à un autre ticket.

**Usage** : `/ticket-pause`, ou simplement « on fait une pause ».

```text
/ticket-pause
  │
  ▼
Session de la branche courante ?
  ├── non ──► Propose /ticket-start
  ├── ancien format ──► Propose /ticket-resume, qui le convertit
  │ oui
  ▼
Sources : commits depuis last_commit, git status et diff, liste de tâches
  │
  ▼
TICKET.md : Statut réécrit, sujets, lots, tests et traductions à jour,
puis compacté, dépassement des limites signalé
  │
  ▼
Audit croisé contre git
  │
  ▼
Résumé : état, prochaine action, questions ouvertes
  │
  ▼
Changements non commités ?
  ├── non ──► Rien à commiter
  │ oui
  ▼
Découpage proposé, commits après accord : code d'abord, puis fichiers de session
```

| Impact | Détail |
|---|---|
| Git | Commits proposés à chaque pause (code, puis `docs(ticket): pause, …`), après accord. Aucun push |
| Fichiers | `TICKET.md` : « Statut » réécrit, sujets, lots, tests et « Traductions » complétés. Sujets tranchés, lots finis et tests validés compactés en une ligne, sauf les tests `(recette)` |
| Tracker | Aucun |

### ticket-resume

**Rôle** : reprendre un ticket là où il s'était arrêté, et tenir `TICKET.md` à jour pendant la session.

**Quand** : à l'ouverture d'une session sur un ticket en cours. Le hook de démarrage le propose de lui-même quand ta première demande porte sur le ticket de la branche courante.

**Usage** : `/ticket-resume`, ou `/ticket-resume <slug>` pour un ticket d'un autre worktree.

```text
Ouverture de session ou /clear (hook ticket-detect)
  ┆ demande liée au ticket
  ▼
/ticket-resume
  │
  ▼
Session : argument, branche courante, ou choix parmi les tickets en cours
  │
  ▼
Branche extraite ici ?
  ├── non ──► Entrée dans son worktree (créé si besoin, après accord) ──┐
  │ oui                                                                 │
  ├─────────────────────────────────────────────────────────────────────┘
  ▼
Lecture de TICKET.md
  ├── ancien format ──► Conversion des 4 fichiers en TICKET.md,
  │                     relue par toi, puis commit après accord
  │
  ▼
Écarts avec git signalés : commits hors session, fichiers, rebase,
retards : release sur ses sources, branche sur la release (base: de TICKET.md)
  │
  ▼
Ticket Bug sans flow Maestro ni note « non reproduit » ?
  ├── oui ──► Reproduction proposée en premier (type contrôlé
  │           si la session est plus ancienne que la reproduction)
  │ non
  ▼
Réponse : écarts, état (parcours, résumé), prochaine action, retards,
simulateur dédié réutilisé, puis les questions en dernier, dans l'ordre
des actions : fusions (facultatives), création du simulateur,
reproduction, lot suivant. Chaque recommandation sous sa question.
Attente de ton accord
  │
  ▼
Pendant la session : conduite de session (lots annoncés, diffs, tests
avec leurs étapes), sujets, résultats de test et traductions notés
au fil de l'eau, hors route signalé
```

| Impact | Détail |
|---|---|
| Git | Worktree créé pour la branche du ticket si aucun ne la tient, après accord. Release en retard sur une release inférieure ou sur `develop` : fusion et push, après accord. Branche en retard sur sa release : `Merge branch '<base>' into <branche> #APP-<n>`, après accord. Jamais imposé. Reproduction d'un bug dont le correctif est déjà commité : `switch --detach` sur la base de la branche le temps d'un rejeu rouge, puis retour sur la branche. Ancien format : `git rm` des 4 fichiers et commit `docs(ticket): conversion au format TICKET.md #APP-<n>`, après accord |
| Onglet et simulateur | Onglet herdr renommé au nom court du ticket dès la session trouvée, avant tout formulaire. Simulateur dédié réutilisé s'il existe, sinon créé après accord |
| Fichiers | Pendant la session : « Sujets analysés », « Tests » et « Traductions » de `TICKET.md` mis à jour dès qu'un sujet est tranché, qu'un test manuel a un résultat ou qu'une clé change. « Statut » et ligne du lot réécrits en fin de lot. Reproduction faite à la reprise : flows dans `maestro/`, « Reproduction » et critère du lot de correctif écrits tout de suite |
| Tracker | Type `Bug` ou `Task` corrigé après accord, seulement pour une session plus ancienne que la reproduction |

**Hook `ticket-detect`** (`.claude/hooks/ticket-detect.sh`) : à chaque ouverture de session et après `/clear`, il cherche une session dont `branch:` est la branche courante (dans `TICKET.md`, ou dans `STATE.md` pour l'ancien format) et affiche son « Statut » à Claude. Il purge aussi les phases de plus de 2 jours (status line, ci-dessous). Claude propose alors la reprise si ta demande porte sur le ticket. Sinon, il traite la demande et te prévient que rien n'est tracé dans les fichiers du ticket.

**Status line** (`.claude/scripts/statusline.sh`, déclarée dans `.claude/settings.json`) : en bas
du terminal, elle affiche la session de ticket de la branche courante, l'étape en cours d'un
démarrage, d'une clôture, d'un skill de version ou d'un skill sans version, et l'état du dernier
build.

```text
APP-1234 mode-hors-ligne │ 1✓ › 2✓ › ▶ 3 (Titre du lot) › 4 │ build à jour
APP-1235 mon-sujet │ démarrage : version            (sur develop, avant la branche)
APP-1235 mon-sujet │ démarrage : séance d'analyse   (avant TICKET.md)
CHORE mise-a-jour-skills │ ▶ 1 (Titre du lot) › 2   (chore)
APP-1234 mode-hors-ligne │ 1✓ › 2✓ › 3✓ │ clôture : revue
release/1.4.2 │ staging 1.4.2 : build             (skill de version)
<action> │ <étape>                                  (skill sans version)
develop │ build périmé                              (hors session de ticket)
```

- Clé : `ticket:` du frontmatter, `CHORE` pour une chore. Slug : la branche sans type ni clé.
- Chemin de fer : lu dans « Lots » de `TICKET.md`. Il est à jour en fin de lot et à chaque pause.
- Phase : `ticket-start`, `chore`, `ticket-resume`, `ticket-close`, les skills `version-*` et
  les skills sans version écrivent leur étape par `.claude/scripts/session-phase.sh` dès leur premier
  geste, et l'effacent à la fin ou à l'arrêt. Un fichier par session Claude Code, dans
  `.git/claude-sessions/` : une autre session du même checkout ne voit pas la phase. Les skills
  de ticket y ajoutent le nom court, affiché à la place de la branche tant que la session n'est
  pas sur la branche du ticket (`develop` au démarrage). Une conversation coupée laisse une
  phase que la session suivante ne lit pas, et que le hook `ticket-detect` purge après 2 jours
  (FORMAT § « Phase dans la status line »).
- Ligne trop large : le titre du lot est tronqué par `…`, puis le slug.
- Build : le hook `build-state` (`.claude/hooks/build-state.sh`, `PostToolUse` sur `build_sim` et
  `build_run_sim` de MobileBuildMCP) écrit l'empreinte du code après un build réussi, dans
  `<git-dir du worktree>/claude-build-state`. La status line la recalcule : `build à jour` si le
  code n'a pas changé depuis, `build périmé` sinon. Les fichiers de `docs/`, `.claude/` et
  `maestro/` ne comptent pas : une pause de ticket ne périme pas le build. Sans build depuis la
  création du worktree, la partie build n'apparaît pas.
- Limite : un build lancé depuis Xcode ou par `xcodebuild` à la main n'est pas vu. La ligne peut
  alors dire « périmé » à tort.
- Réglages lus dans le dossier où Claude démarre : une session lancée dans le dépôt principal puis
  entrée dans un worktree garde la status line et les hooks du dépôt principal. Lance Claude dans
  le worktree du ticket.

### ticket-close

**Rôle** : clôturer un ticket et l'intégrer. Il revoit d'abord le travail de la branche : qualité du code, fuites et CPU, conformité à la demande du ticket et à ses commentaires. Puis il range ce qui doit survivre là où on le relira (pourquoi durable dans le code, synthèse dans le commit de clôture, explication au lecteur dans le tracker), supprime le dossier de travail, fusionne la branche sur sa base et nettoie.

**Quand** : quand le ticket est fini et testé. Il accepte de clôturer avec du reste à faire, qui part alors dans « Non fait ».

**Usage** : `/ticket-close`, ou `/ticket-close <slug>`. Fonctionne aussi sur une chore (branche `chore/`, démarrée par `/chore` ou à la main) : ni tracker ni commentaire au lecteur, cible `develop`, commits sans clé. Les releases ouvertes recevront `develop` quand une session les touchera. Cas isolé où l'app n'est pas en cause : clôture sans correctif, sans commit ni fusion. Commentaire au lecteur au statut « Rien à faire », `a-livrer`, version du ticket gardée pour que le lecteur décide, worktree et branche supprimés.

```text
/ticket-close
  │
  ▼
TICKET.md en retard (modifié, ou commit après son dernier commit) ?
  ├── oui ──► /ticket-pause (commit de TICKET.md refusé : arrêt)
  │
  ▼
État des lieux : reste à faire, cible recalculée, cohérence avec la version
  ├── écart ──► Arrêt, sorties expliquées (création de release ou fusion
  │             entre branches longues proposée quand elle règle l'écart)
  │
  ▼
Ticket Bug : rejeu des flows Maestro de reproduction sur le simulateur dédié
(recréé après accord s'il manque). Flow rouge, rejeu non fait, bug
non reproduit, correctif sans test unitaire ni raison : reste à faire
  │
  ▼
Revue du diff de la branche (sautée si un lot n'est pas fini)
  ├── qualité ─────────► sous-agent ──┐
  ├── fuites et CPU ───► sous-agent ──┼── constats vérifiés dans le code
  └── conformité ──────► session ─────┘   (description et commentaires du ticket)
  │
  ▼
1. Corriger maintenant, corriger plus tard, clôturer ou annuler ?
  ├── corriger ──► lot « Revue de clôture » dans TICKET.md, puis relance
  │                (maintenant : dans la session ; plus tard : /ticket-pause)
  │
  ▼
2. Commentaires de code (pourquoi durable)
  │
  ▼
Message de clôture et commentaire au lecteur rédigés, puis audit
  │
  ▼
3. Commentaire au lecteur validé
  │
  ▼
4. Commits : commentaires de code, puis clôture qui supprime docs/tickets/slug/
  │
  ▼
5. Mode ?
  ├── pas maintenant ──► Arrêt, branche gardée
  ├── pull request ────► Push de la branche, commentaire au lecteur, lien de PR
  │                       │
  │                       ▼
  │                     6. Suppression worktree, branche locale, dossiers de build,
  │                        simulateur dédié
  │ fusion directe
  ▼
merge --no-ff dans la cible, là où elle est extraite (sinon worktree temporaire)
  │
  ▼
6. Push, commentaire au lecteur, statut a-livrer,
   suppression worktree, branches, dossiers de build, simulateur dédié
```

Les numéros sont ceux des six formulaires de validation. Le dernier est à choix multiple : chaque action se coche à part. Le formulaire de création du simulateur dédié n'a pas de numéro : il apparaît seulement quand le rejeu en a besoin. Les formulaires de la pause du début n'en ont pas non plus.

Le commentaire au lecteur commence par `# Statut`, de texte « En attente de livraison », que le skill de build staging puis `/version-close` remplacent au fil des livraisons. Suit `# Évolutions/Corrections` : une section `##` par problème corrigé, avec ce qui est livré et sa recette, tirée des tests `(recette)` de `TICKET.md`. Une demande du ticket exclue, partielle ou absente a sa ligne sous `# Non livré`, à la fin. Il ne contient ni décisions, ni autre reste à faire, ni question : ces points vont dans le message de clôture.

| Impact | Détail |
|---|---|
| Git, branche du ticket | Commit `docs(<scope>): …` des commentaires de code. Commit `docs(ticket): clôture, … #APP-<n>` qui supprime `docs/tickets/<slug>/` et porte la synthèse (décisions, non fait, traductions) |
| Git, cible | Commit de merge `--no-ff` dans `release/X.Y.Z`, `poc/<nom>` (ticket d'une version POC) ou `develop` (branche `chore/`), `Merge branch '<branche>' into <cible> #APP-<n>`, poussé après accord |
| Rejeu | Ticket `Bug`, module `maestro` : build de la branche et rejeu des flows de `docs/tickets/<slug>/maestro/` sur le simulateur dédié, recréé après accord s'il manque. Les flows disparaissent avec le dossier, sans copie dans `maestro/flows/` |
| Revue | Deux sous-agents en parallèle (qualité, fuites et CPU) sur `origin/<cible>...HEAD`, avec `swiftformat --lint` et `swiftlint lint` sans écriture. Conformité lue dans le tracker (description, commentaires). Aucune mesure Instruments : une suspicion devient une vérification à faire dans Xcode. Constats à corriger : lot « Revue de clôture » ajouté à `TICKET.md` |
| Nettoyage | Worktree du ticket, branche locale, branche distante, dossiers de build (DerivedData MobileBuildMCP et Xcode retrouvés par `worktree-derived-data.sh`, workspace MobileBuildMCP du worktree, runs finis de `test-products`), simulateur dédié, chacun après accord |
| Tracker | Commentaire au lecteur (statut, puis livré, recette et traductions de chaque problème, demandes non livrées) au push, puis statut `a-livrer` en fusion directe. En pull request, commentaire seul : le ticket reste `en-cours` jusqu'au build staging |

Arrêts : version du ticket incohérente avec la base de la branche (placeholder, version publiée entre-temps, branche partie de la mauvaise base), constats de la revue à corriger plus tard, working tree sale au moment de l'intégration, conflit de fusion, cible locale en avance sur origin.

### ticket-check

**Rôle** : vérifier un ticket déjà traité, en lecture seule. Le code du ticket doit être dans la release de sa version, et chaque demande du ticket doit être couverte. Il relève le reste à faire (message de clôture, tests, traductions, commentaire au lecteur, labels) sans rien écrire, ni dans git ni dans le tracker : le commentaire au lecteur et le statut `a-livrer` restent à `/ticket-close`.

**Quand** : ticket fusionné par pull request, fusion restée sans push, ticket traité hors des skills.

**Usage** : `/ticket-check APP-1234`, ou `/ticket-check` seul sur la branche du ticket (clé proposée).

```text
/ticket-check
  │
  ▼
Ticket : titre, description, type, statut, labels, version, commentaires
  │
  ▼
Release de la version du ticket (tag du build publié si la version est
publiée, poc/<nom> pour une version POC)
  │
  ▼
Commits du ticket : fusions, commits avec la clé, sinon commits sans clé
retenus dans un formulaire
  │
  ▼
Diff du ticket, relu avec le code actuel de la release
  │
  ▼
Points bloquants : intégration, demande non couverte
Reste à faire : clôture, tests, traductions, code, commentaire au lecteur, forme
  │
  ▼
Verdict OK ou Non OK, avec la sortie de chaque point bloquant
```

| Impact | Détail |
|---|---|
| Git | Lecture seule. Aucun build ni test : les tests verts relèvent de `/ticket-close` |
| Onglet | Onglet herdr renommé au nom court de la branche du ticket |
| Tracker | Lecture seule |

### chore

**Rôle** : démarrer une chore, du travail d'outillage interne sans ticket (skills Claude, scripts, outils de build et de CI). Il suit le déroulé de `/ticket-start`, sans ticket ni version : branche et worktree depuis `develop`, exploration, séance d'analyse, `TICKET.md`. La suite passe par `/ticket-pause`, `/ticket-resume` et `/ticket-close`, comme pour un ticket.

**Quand** : au début de tout changement d'outillage. Exception : un changement limité aux memories (`.claude/context/`) se commite directement sur `develop`, et le skill le propose.

**Usage** : `/chore <sujet>`, ou `/chore` seul (le sujet est alors demandé). Lancé depuis une branche `chore/` qui a déjà une session, il bascule sur `/ticket-resume`. Lancé depuis une branche de ticket, il démarre la chore à part, depuis `develop`.

```text
/chore
  │
  ▼
Branche chore/ avec une session ?
  ├── oui ──► /ticket-resume
  │ non
  ▼
Sujet, puis description de branche proposée
  ├── memories seules ──► commit direct sur develop, sans session
  │
  ▼
Branche chore/description et worktree depuis origin/develop, après accord
  │
  ▼
Exploration du code, des skills et des chores closes voisines
  │
  ▼
Séance d'analyse en texte, sans formulaire : sujets, parcours et lots, tests
  ├── chore inutile ──► worktree et branche supprimés après accord
  │
  ▼
Écriture de TICKET.md (ticket: none), puis audit
  │
  ▼
Bloc de fin et annonce du lot 1, puis les questions en dernier :
commit « démarrage » (formulaire en fin de tour), lancement du lot 1
```

| Impact | Détail |
|---|---|
| Git | Branche `chore/<description>` créée depuis `origin/develop`, sans suivi distant. Worktree `../<dépôt>-<description>`, dans lequel la session entre. Commit `docs(ticket): démarrage, …`, sans clé, non poussé |
| Fichiers | `docs/tickets/chore-<description>/TICKET.md`, avec `ticket: none` et `base: develop` |
| Onglet et simulateur | Onglet herdr renommé `CHORE_<description>` dès la description proposée, avant tout formulaire. Simulateur dédié seulement si un lot lance l'app, après accord |
| Tracker | Aucun |

Clôture : `/ticket-close` fusionne la chore en `--no-ff` dans `develop`, sans commentaire au lecteur ni statut. Les releases ouvertes recevront `develop` quand une session les touchera.

## 4. Skills de version

Ils lisent l'état avant toute décision : git (`fetch --prune` et tags forcés), le tracker, et la source `releases.published` des versions publiées (RULES § « Lire l'état »). `version-health` lit le rapport de crash et le tracker, sans la source des versions publiées. Les règles qu'ils appliquent sont dans [`RULES.md`](../.claude/workflow/RULES.md), le geste propre à un service dans les adaptateurs `tracker-<tracker.provider>` et `published-<releases.published>`.

| Clé | Valeur | Version dans le service |
|---|---|---|
| `tracker.provider` | `jira` | Version Jira de nom `X.Y.Z - <But>`, publiée par le lecteur |
| `tracker.provider` | `github` | Milestone de titre `X.Y.Z`, but en description, fermé par `version-close` |
| `releases.published` | `app-store-connect` | Publiée à l'approbation par Apple, lue par la lane fastlane `app_store_versions` |
| `releases.published` | `git-tags` | Publiée quand le tag annoté `vX.Y.Z` existe, posé par `version-close` |

**Onglet et phase** : dès l'étape 1, chaque skill renomme l'onglet herdr de la session `<action>`, ou `<action>-<version>` si la version est dans ses arguments, puis `<action>-<version>` une fois la version confirmée (`start-1.7.0`, `hotfix-1.4.3`, `close-1.4.1`, `version-health-1.4.2`). Le nom reste après le skill. La status line de la session affiche l'étape en cours (`release/1.4.1 │ close 1.4.1 : fusion`), effacée à la fin ou à l'arrêt. `version-start` appelé par `version-hotfix` ne touche ni l'un ni l'autre. Les skills de build du projet suivent la même règle. Règles : `RULES.md` § « Onglet herdr et phase ».

### version-start

**Rôle** : créer dans le tracker la version X.Y.Z et son but, qui servira de version du ticket, ou donner son numéro à un placeholder (version sans numéro, `2.X.0 - Mode sombre` dans Jira). Module `poc` : une version POC (`POC - …`) n'est jamais proposée, elle ne reçoit pas de numéro.

**Quand** : en début de cycle, avant les tickets de la version. Aussi appelé par `/version-hotfix`. Sa release n'est créée qu'au premier `/ticket-start` de la version.

**Usage** : `/version-start 1.7.0 Mode sombre`, ou `/version-start` (propose la mineure suivante).

```text
/version-start
  │
  ▼
Lecture des versions publiées et de toutes les versions du tracker
  │
  ▼
Numéro confirmé (par défaut, mineure suivante)
  │
  ▼
Contrôles
  ├── publiée ──────────────────► Refus → /version-hotfix
  ├── en double ou archivée ────► Arrêt : le lecteur tranche
  ├── existe déjà ──────────────► Réutilisée, rien n'est écrit
  │ libre
  ▼
Placeholders ?
  ├── oui ──► Numéroter un placeholder ou créer ──┐
  │ non                                           │
  ▼                                               │
Confirmer la création                             │
  │                                               │
  ├───────────────────────────────────────────────┘
  ▼
Écriture dans le tracker, relecture
```

| Impact | Détail |
|---|---|
| Git | Aucun |
| Tracker | Une version créée avec son but, ou un placeholder numéroté (même id, mêmes tickets). Ni date ni état : la publication relève du lecteur ou de `/version-close`, selon l'adaptateur |

### version-hotfix

**Rôle** : ouvrir le correctif d'une version déjà publiée. La release du correctif part du build que les utilisateurs ont reçu, pas de `develop`.

**Quand** : bug en production sur une version publiée, dont le numéro est donc consommé.

**Usage** : `/version-hotfix 1.6`, ou `/version-hotfix` (propose la ligne de la dernière version publiée).

```text
/version-hotfix
  │
  ▼
Dernière version publiée de la ligne, son build publié → X.Y.(Z+1)
  │
  ▼
Tag du build publié présent, hotfix pas encore ouvert ?
  ├── non ──► Arrêt
  │ oui
  ▼
/version-start X.Y.(Z+1) Fix : version du tracker
  │
  ▼
Confirmation unique : création et push
  │
  ▼
Worktree temporaire : release/X.Y.(Z+1) depuis le tag du build publié,
commit de bump, push
```

| Impact | Détail |
|---|---|
| Git | Branche `release/X.Y.(Z+1)` depuis le tag du build publié (gabarit `releases.build_tag`, environnement `prod`), commit `chore(release): X.Y.(Z+1)`, poussée après accord |
| Tracker | Version X.Y.(Z+1) de but `Fix` créée ou réutilisée, via `/version-start` |

Ensuite, le cycle est celui d'une recette : `/ticket-start` des correctifs (ils partent de la nouvelle release), le skill de build staging, le skill de build prod s'il existe, `/version-close`. Les releases ouvertes supérieures reçoivent le hotfix quand une session les touche (fusion proposée), avec un conflit attendu sur la ligne de version (`releases.version_line`), résolu à la main en gardant leur version.

### version-close

**Rôle** : fermer une version publiée. Une seule fusion ramène dans `develop` tout ce que la release a reçu (tickets, bump, correctifs de recette ou de hotfix), puis dans `releases.closed_release_also_into` si la clé nomme une branche. La release est ensuite supprimée. Les releases ouvertes supérieures ne sont pas touchées : elles reçoivent `develop` quand une session les touche.

**Quand** : une fois la version publiée sur le store. Source `git-tags` : le skill marque la publication par le tag `vX.Y.Z`, sur le build choisi.

**Usage** : `/version-close`, ou `/version-close 1.6.0`.

```text
/version-close
  │
  ▼
Release ouverte choisie, publiée ou non
  │
  ▼
Publiée (releases.published) ?
  ├── non ──► app-store-connect : refus. git-tags : build publié choisi,
  │           tag vX.Y.Z poussé, ou arrêt
  │ oui
  ▼
Release locale = origin, extraite nulle part ?
  ├── non ──► Arrêt
  │ oui
  ▼
Signalements du tracker : tickets non finis, branches non intégrées,
publication de la version (adaptateur)
  │
  ▼
Confirmation, puis statut « Publié dans la X.Y.Z » dans le commentaire
de clôture de chaque ticket de la version
  │
  ▼
Confirmation, puis merge --no-ff dans develop, puis dans
releases.closed_release_also_into, et push
(là où la cible est extraite, sinon worktree temporaire)
  ├── conflit ou push refusé ──► Arrêt, rien n'est supprimé
  │
  ▼
Après confirmation : suppression de release/X.Y.Z (tags gardés),
publication de la version dans le tracker (adaptateur)
```

| Impact | Détail |
|---|---|
| Git | Commit de merge `Merge branch 'release/X.Y.Z' into develop`, et dans `releases.closed_release_also_into`, poussés après accord. `release/X.Y.Z` supprimée sur origin et en local, seulement une fois contenue dans chaque cible. Tags de build conservés. Source `git-tags` : tag `vX.Y.Z` poussé après accord |
| Tracker | Pour chaque ticket de la version : statut `Publié dans la X.Y.Z` dans le commentaire de clôture, ou dans un commentaire séparé si le ticket n'a pas de commentaire `# Statut`. Un statut `Aucune modification de l'app…` reste tel quel. Aucune transition : les tickets non finis sont signalés au lecteur. Publication de la version : signalée au lecteur (Jira), ou milestone fermé après accord (GitHub) |

### version-health

**Rôle** : module `crash_reporter`. Dire si des bugs sont remontés dans une version publiée. Le skill lit le rapport de crash à âge égal avec la version publiée précédente, signale les issues par des règles fixes, vérifie chacune, puis propose un ticket et une note. La méthode reste la même d'une version à l'autre : deux bilans se comparent. Service géré : `crashlytics`. Module absent : le skill s'arrête dès son début, avec un message.

**Quand** : à J+3 puis à J+7 après la publication sur le store. J0 est le premier jour où la version atteint 100 utilisateurs. Un crash nouveau confirmé mène à `/version-hotfix`, une hausse confirmée à `/ticket-start`.

**Usage** : `/version-health`, ou `/version-health 1.6.0`. Sans argument, le skill propose la version la plus haute lue dans le rapport de crash, hors POC.

```text
/version-health
  │
  ▼
Version confirmée, référence = version publiée précédente
  │
  ▼
J0 de chaque version, D = jours complets depuis J0 (7 au plus)
  ├── pas de J0, ou D = 0 ──► Arrêt
  │
  ▼
Taux sans crash et issues, sur les D jours qui suivent chaque J0
  │
  ▼
Règles R1 à R4 : crash nouveau, régression, erreur en hausse, erreur nouvelle
  │
  ▼
Vérification de chaque issue signalée (5 au plus) : notes, tracker,
événement, commits de la version sur le fichier fautif
  │
  ▼
Bilan : récapitulatif, une section par issue, conclusion
  │
  ▼
Un formulaire par issue : Bug et note, note seule, ou rien
```

| Impact | Détail |
|---|---|
| Git | Lecture seule : tags récupérés, `log` entre les tags de build prod des deux versions (`releases.build_tag`) |
| Tracker | `Bug` créé après accord, assigné à toi, reporter `tracker.reporter`, version du ticket choisie une fois par lancement, avec un commentaire « Analyse ». Aucun commentaire sur un ticket existant |
| Rapport de crash | Note sur l'issue après accord : « Suivi par APP-<n> » ou « En observation ». Une issue qui a déjà une note n'a aucune question |

Les seuils des règles sont fixes, dans le `SKILL.md` du skill (§ « Signaler »).

## 5. Skill de revue

### show-diff

**Rôle** : ouvrir ton outil Git sur le worktree courant, puis expliquer chaque modification de la branche depuis sa base, non commité compris. L'explication suit les fichiers dans l'ordre des chemins, une modification par ligne, avec le pourquoi. Pendant un lot de ticket, le skill propose la branche complète ou le lot en cours seul.

**Quand** : avant un commit ou une clôture, pour relire ce que Claude a modifié.

**Usage** : `/show-diff`, ou une demande comme « montre-moi les modifs ».

```text
/show-diff
  │
  ▼
Outil Git enregistré (git config my-ticket-workflow.gitClient) ?
  ├── non ──► Formulaire parmi les clients installés, choix enregistré
  │ oui
  ▼
open -a <outil> <worktree>
  │
  ▼
Base : base: de TICKET.md, develop pour chore/*, la branche elle-même pour
une branche longue, sinon base a posteriori (RULES)
  │
  ▼
Lot ▶ et lot ✓ dans TICKET.md ?
  ├── oui ──► Formulaire : branche complète, ou lot en cours depuis le dernier lot ✓
  │ non
  ▼
Diff depuis le point de départ (branche ou lot) : commits, index, working tree,
fichiers non suivis
  │
  ▼
Explication par fichier puis par modification, fichiers hors périmètre signalés en tête
```

Le choix de l'outil vaut pour tous les worktrees du clone. Pour le changer : `git config --unset my-ticket-workflow.gitClient`, puis `/show-diff` repose la question.

| Impact | Détail |
|---|---|
| Git | Lecture seule. Au premier lancement, clé `my-ticket-workflow.gitClient` écrite dans le `.git/config` du clone, jamais versionnée |
| Externe | L'outil Git choisi s'ouvre sur le worktree |

## 6. Fichiers de référence

| Fichier | Contenu | Lu par |
|---|---|---|
| [`.claude/workflow.yml`](../.claude/workflow.yml) | Valeurs du projet : tracker, forge, releases, identifiants de l'app, modules (FORMAT § « Configuration ») | Skills et scripts du paquet, par `yq` |
| [`.claude/workflow.lock`](../.claude/workflow.lock) | Commit du paquet reçu ou publié, et sha256 de chacun de ses fichiers (WORKFLOW § 7) | `sync.sh` |
| [`.claude/scripts/sync.sh`](../.claude/scripts/sync.sh) | Copie du paquet entre le dépôt `my-ticket-workflow` et le projet : `recevoir`, `publier`, plan sans `--apply` (WORKFLOW § 7) | L'utilisateur, dans une chore |
| [`.claude/workflow/adapters/`](../.claude/workflow/adapters/) | Geste propre à un service : `tracker-<tracker.provider>`, `forge-<forge.provider>`, `published-<releases.published>` | Skills qui écrivent dans le tracker, la forge ou lisent les versions publiées |
| [`.claude/rules/paquet/manual-tests.md`](../.claude/rules/paquet/manual-tests.md) | Protocole de chaque test manuel : annonce, un test à la fois, résultat écrit | Claude Code, chargé à chaque session (sans `paths:`) |
| [`.claude/workflow/FORMAT.md`](../.claude/workflow/FORMAT.md) | Format des fichiers de travail, conventions de ticket, de branche, de worktree, de commit et de fusion | Skills `ticket-*`, `chore`, `version-health` (§ « Ticket »), skills locaux qui créent un ticket |
| [`.claude/workflow/RULES.md`](../.claude/workflow/RULES.md) | Lecture de l'état, définitions (version publiée, ouverte, à ouvrir), onglet herdr et phase des skills de version et des skills sans version, rôle de `develop`, releases en parallèle, création d'une release, fusion entre branches longues, base d'un ticket, cohérence à l'intégration, statuts logiques | `ticket-start`, `chore`, `ticket-close`, skills `version-*`, `show-diff` (§ « Base d'une branche a posteriori »), skills locaux de build et de support |
| [`.claude/hooks/ticket-detect.sh`](../.claude/hooks/ticket-detect.sh) | Détection du ticket de la branche courante à l'ouverture de session | Claude Code (`.claude/settings.json`) |
| [`.claude/hooks/build-state.sh`](../.claude/hooks/build-state.sh) | Empreinte du code écrite après un build MobileBuildMCP réussi | Claude Code (`.claude/settings.json`) |
| [`.claude/scripts/statusline.sh`](../.claude/scripts/statusline.sh) | Status line : session de ticket, chemin de fer des lots, phase du skill, état du build | Claude Code (`.claude/settings.json`) |
| [`.claude/scripts/session-phase.sh`](../.claude/scripts/session-phase.sh) | Écriture et effacement de la phase et du nom court d'un skill de ticket, de version ou sans version, par session | `ticket-start`, `chore`, `ticket-close`, `ticket-resume`, skills `version-*`, skills locaux |
| [`.claude/scripts/herdr-tab.sh`](../.claude/scripts/herdr-tab.sh) | Renommage de l'onglet herdr de la session, sans bloquer hors herdr | `ticket-start`, `chore`, `ticket-resume`, `ticket-close`, skills `version-*`, skills locaux |
| [`.claude/scripts/build-fingerprint.sh`](../.claude/scripts/build-fingerprint.sh) | Empreinte du code d'un dépôt depuis un commit | `build-state.sh`, `statusline.sh` |
| [`.claude/scripts/worktree-derived-data.sh`](../.claude/scripts/worktree-derived-data.sh) | Dossiers de build d'un worktree : DerivedData MobileBuildMCP et Xcode reliés par leur `WorkspacePath`, workspace MobileBuildMCP propre au worktree | `ticket-close`, skill local de lancement de l'app |
| [`.claude/scripts/ticket-translations.rb`](../.claude/scripts/ticket-translations.rb) | Relevé des clés de traduction modifiées par la branche | `ticket-pause`, `ticket-close` |
| [`.claude/scripts/github-api.sh`](../.claude/scripts/github-api.sh) | Appel à l'API REST GitHub pour les opérations absentes du MCP (milestones, réécriture d'un commentaire) | Adaptateur `tracker-github` |

**Memories du projet citées par le paquet**, dans `.claude/context/`. Leur contenu est propre au projet : chaque projet qui active le module écrit la sienne.

| Memory | Contenu | Module | Lu par |
|---|---|---|---|
| `reference_dedicated_simulator` | Mise en route de l'app sur un simulateur neuf : compte, alertes système à passer dans un flow, environnement de la CLI Maestro | `simulator`, `maestro` | `ticket-start`, `ticket-close`, FORMAT (simulateur dédié, flows de reproduction) |
| `reference_crashlytics_mcp` | Lecture du rapport de crash : fonction d'envoi des erreurs non fatales, erreurs attendues, codes d'erreur | `crash_reporter` | `version-health` |

Une règle se modifie à un seul endroit : dans `RULES.md` ou `FORMAT.md` si elle est partagée, sinon dans le `SKILL.md` concerné. Ce document décrit leur comportement : il se met à jour avec eux.
