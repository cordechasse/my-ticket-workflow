# Format des sessions de travail

Référence partagée par `ticket-start`, `chore`, `ticket-pause`, `ticket-resume` et `ticket-close`.

## Langue

Français, du premier au dernier message de chaque skill de ticket, avant même la lecture de ce fichier. La règle couvre chaque texte que l'utilisateur voit : réponses, messages courts entre deux appels d'outil, formulaires. Un rapport de sous-agent, une notification de tâche de fond ou un message système en anglais ne change pas la langue de la session. Le prompt d'un sous-agent demande son rapport en français.

## Configuration

Les valeurs propres au projet sont dans `.claude/workflow.yml`, lues par `yq` (`yq '.tracker.key_prefix' .claude/workflow.yml`). Une clé de config se cite par son chemin (`tracker.states`). Le comportement propre à un service est dans `.claude/workflow/adapters/` : `tracker-<tracker.provider>.md`, `forge-<forge.provider>.md`, `published-<releases.published>.md`. Un skill lit la config, puis ces seuls adaptateurs.

- `<clé>` : clé d'un ticket, `tracker.key_prefix` suivi du numéro. Les exemples de ce fichier et de RULES prennent `key_prefix: "APP-"` (`APP-1234`).
- Le lecteur : `tracker.reader`, qui lit les tickets et les commentaires de clôture. Son profil : `tracker.reader_profile`.
- `develop` : la branche `releases.integration_branch`.

**Modules** : `modules` de la config liste les parties optionnelles du workflow (`maestro`, `simulator`, `translations`, `crash_reporter`, `poc`). Une étape optionnelle d'un skill commence par sa condition, « Module `<m>`. ». Module `false`, `none` ou absent : l'étape est sautée, sans message ni question, et la section de la règle dit ce qui la remplace. Une valeur autre que `true` nomme le service (`poeditor`, `crashlytics`). Un skill dont tout le rôle dépend d'un module absent s'arrête dès son début, avec un message qui nomme le module.

**Contenu du paquet** : les fichiers du paquet ne citent aucun nom, aucune valeur et aucun exemple d'un projet qui l'utilise : clé de ticket, nom d'une personne, identifiant de compte, nom ou chemin de l'app. Une valeur propre au projet va dans `.claude/workflow.yml`. Un fait propre au projet va dans ses memories ou ses fichiers locaux. Les exemples prennent des valeurs neutres (`APP-1234`, `com.example.app`).

## Emplacement

`<racine du repo>/docs/tickets/<slug>/`

- `slug` = nom de la branche, `/` remplacé par `-` (`feature/APP-1234_mode-hors-ligne` → `feature-APP-1234_mode-hors-ligne`).
- Une session = une branche. La correspondance fait foi via le champ `branch:` de `TICKET.md`, pas via le nom du dossier.
- Les fichiers sont commités avec le code, sur la branche du ticket.
- Ticket en cours : le fichier de travail `TICKET.md`, plus le dossier `maestro/` des flows de reproduction pour un ticket `Bug` (§ « Flows de reproduction »). Ticket clos : plus de dossier, `ticket-close` le supprime avant la fusion. Les branches d'intégration ne contiennent donc aucun fichier de ticket.

## Retrouver un ticket clos

Le contexte d'un ticket clos vit dans l'historique git, retrouvé par sa clé :

```
git log --all --full-history --grep='<clé>' --diff-filter=D --format='%h %s' -- docs/tickets/
```

- `--full-history` est obligatoire. À la fusion, `docs/tickets/` est identique au premier parent : sans cette option, git ne suit pas la branche du ticket, et la clôture reste introuvable une fois la branche supprimée.
- Le commit trouvé est le commit de clôture. Son message porte la synthèse du ticket (`git show -s <hash>`).
- Les fichiers de travail se lisent dans son parent : `git show <hash>^:docs/tickets/<slug>/<fichier>`. Flows de reproduction d'un `Bug` : `git ls-tree --name-only <hash>^ docs/tickets/<slug>/maestro/` les liste, `git show <hash>^:docs/tickets/<slug>/maestro/<flow>.yaml` en donne un.
- Selon l'âge du ticket, `git ls-tree --name-only <hash>^ docs/tickets/<slug>/` donne le format :
  - `TICKET.md` : format actuel. Le détail compacté (options, lots finis, tests validés) se relit par `git log -p -- docs/tickets/<slug>/TICKET.md`.
  - `SPEC.md`, `DECISIONS.md`, `STATE.md`, `TESTS.md` : ancien format à 4 fichiers, lus de la même façon.
  - aucun fichier de travail : format plus ancien, la clôture conservait un `SUMMARY.md`, lisible dans le commit de clôture lui-même (`git show <hash>:docs/tickets/<slug>/SUMMARY.md`).
- Ticket voisin (autre clé, même sujet) : `git log --format='%h %s' -- <fichiers concernés>` donne les clés `#<clé>` des tickets qui les ont touchés, puis la recherche ci-dessus pour chacune.

## Ticket, branche et fusion

Une session est toujours reliée à un ticket du tracker (section `tracker` de la config, gestes dans l'adaptateur `tracker-<tracker.provider>`). Seule exception : la chore, de l'outillage interne sans ticket (§ « Session de chore »).

### Ticket

- Type : `Bug` pour un correctif, `Task` pour tout le reste. Leur nom dans le service : `tracker.types.bug` et `tracker.types.task`. Le type d'un ticket existant peut être faux : `ticket-start` le juge d'après le titre et la description, et propose de le changer en cas d'écart. Le type validé par l'utilisateur décide du préfixe de branche (`fix` pour un `Bug`) et de la reproduction sur simulateur (§ « Flows de reproduction »), même quand le tracker refuse le changement.
- Lecteur : `tracker.reader`, `tracker.reader_profile`. Titre technique accepté, sans noms de types ni de fichiers.
- Description courte : 2 à 5 lignes (objectif ou problème, périmètre en une phrase). Pour un crash, un paragraphe « Origine » (version, environnement, nombre d'occurrences si connu, lien du rapport de crash). Les détails techniques vont dans des commentaires séparés, hors de la description.
- Assigné à l'utilisateur, rattaché à une seule version, la version du ticket (RULES § « Versions »), confirmée dans un formulaire. Seule exception : un `Bug` créé par le skill de triage du support peut partir au backlog, sans version, au choix de l'utilisateur ou faute de version non publiée.
- Reporter : `tracker.reporter`, pour tout ticket créé par les skills. Clé absente : le tracker pose son défaut. Non bloquant : si le tracker le refuse, le ticket est créé sans, avec un avertissement.
- Statuts et écritures dans le tracker : `.claude/workflow/RULES.md` § « Statuts ». Cycle complet : `docs/WORKFLOW.md`.

### Branche

`<type>/<clé>_<description-kebab-case>`
- `type` : `feature`, `fix` ou `chore`.
- Exemples : `feature/APP-1234_mode-hors-ligne`, `fix/APP-3456_crash-startup`.
- Les branches créées avant cette convention (`<type>/<description>-<clé>`) gardent leur nom jusqu'à leur clôture.
- Outillage interne sans ticket : `chore/<description-kebab-case>`, sans clé.

### Worktree

Chaque branche de ticket vit dans son propre worktree, frère du dépôt principal : `<parent du dépôt principal>/<nom du dépôt principal>-<clé>` (`../mon-app-APP-1234` pour le dépôt `mon-app`), ou suffixé par la description pour une branche `chore/`, et jamais sous `.claude/worktrees/`. Le checkout du dépôt principal reste sur sa branche. Le worktree et la branche locale sont supprimés à la clôture.

Pièges d'une session Claude Code dans un worktree :
- `EnterWorktree` avec `path` refuse un worktree hors de `.claude/worktrees/` quand la session est déjà dans un autre worktree : `ExitWorktree` (`keep`) d'abord.
- Une session entrée dans un worktree refuse les commandes git composées (`cd … &&`), les commandes dont un argument vient d'une variable ou d'un `$(…)`, et `git -C` vers un autre dossier : une commande git simple par appel, chemins écrits en clair, et `ExitWorktree` (`keep`) avant d'agir sur un autre checkout.
- Git dans une lib liée (`related_repos`) : `ExitWorktree` (`keep`), la commande sous la forme exacte `git -C <chemin de la lib> <sous-commande>`, puis `EnterWorktree` avec `path`. En mode auto, seules les sous-commandes autorisées par les permissions de l'utilisateur passent. Les autres (souvent `merge`, `reset`, `rebase`, `branch -D`) se font par une commande `! cd <lib> && git …` lancée par l'utilisateur.
- MobileBuildMCP : au premier build, `session_set_defaults` avec le `projectPath` du worktree, et le `simulatorId` du simulateur dédié s'il existe. Sinon les defaults pointent vers le dépôt principal, et le build ne contient pas le code du ticket. Le DerivedData va dans le workspace MobileBuildMCP du dossier où la session a été lancée : celui du dépôt principal après un `EnterWorktree`. `.claude/scripts/worktree-derived-data.sh <racine du worktree>` le retrouve, avec celui d'Xcode.

### Nom court, onglet herdr et simulateur

Nom court : la branche sans son préfixe `<type>/` (`feature/APP-1234_mode-hors-ligne` → `APP-1234_mode-hors-ligne`). Pour une chore, le préfixe `chore/` devient `CHORE_` (`chore/mise-a-jour-skills` → `CHORE_mise-a-jour-skills`), sur le modèle de la clé d'un ticket. Le nom court nomme l'onglet herdr de la session et le simulateur dédié du ticket.

**Onglet herdr** : Claude renomme l'onglet herdr de sa session dès le premier geste du skill, avant tout formulaire, sans demander : `.claude/scripts/herdr-tab.sh "<nom court>"`, lancé depuis la racine du dossier de la session. L'utilisateur voit ainsi tout de suite le ticket de l'onglet. Le nom court est celui de la branche, ou celui qu'elle aura :
- `ticket-start` : dès le ticket lu ou créé, nom court proposé d'après le titre (`<clé>_<description proposée>`)
- `chore` : dès la description de branche proposée (`CHORE_<description>`)
- `ticket-resume`, `ticket-close` : dès la session trouvée, nom court de sa branche.

Nom changé ensuite (description modifiée au formulaire de branche) : nouveau renommage, avec la phase et son nom court (§ « Phase dans la status line »). Les skills `version-*` et les skills sans version appellent aussi le script, avec leur propre nom (RULES § « Onglet herdr et phase »). Étape jamais bloquante :
- session lancée hors herdr : le script ne fait rien, sans message
- commande `herdr` absente ou en erreur (code 1, une ligne sur stderr) : étape sautée, une ligne dans le résumé, sans nouvel essai ni question
- script absent (release qui n'a pas encore reçu `develop`) : étape sautée, sans message.

**Simulateur dédié** : module `simulator`. Sans lui : ni simulateur dédié, ni question de création ou de suppression, `simulator: none` dans `TICKET.md`, et Claude pilote l'app sur le simulateur des defaults MobileBuildMCP (`session_show_defaults`).

Les simulateurs existants sont partagés avec l'utilisateur. Pour piloter l'app (scénarios manuels, Maestro, captures), Claude utilise le simulateur du ticket, créé après un « oui ». Coût : 2 à 4 Go une fois l'app installée et utilisée, et de la mémoire tant qu'il est démarré. Il est supprimé à la clôture.

Recherche : `xcrun simctl list devices -j | jq -r '.devices[][] | select(.name == "<nom court>") | "\(.udid) \(.state)"'`. Trouvé : il est réutilisé, sans création.

Création, une commande par appel, valeurs écrites en clair :
1. Version du SDK de l'Xcode sélectionné : `xcrun --sdk iphonesimulator --show-sdk-version` (`26.5` donne le runtime `iOS-26-5`).
2. `xcrun simctl create "<nom court>" <simulator.device_type> com.apple.CoreSimulator.SimRuntime.iOS-<version>`, qui affiche l'udid.
3. Certificat racine `simulator.root_cert`, celui d'un proxy de debug par exemple : `xcrun simctl boot <udid>`, `xcrun simctl keychain <udid> add-root-cert "<simulator.root_cert, ~ développé>"`, puis `xcrun simctl shutdown <udid>` (`build_run_sim` le démarre au besoin). Clé absente : étape sautée. Fichier absent : étape sautée, et signalée.
4. MobileBuildMCP : `session_set_defaults` avec `simulatorId` = `<udid>` et le `projectPath` du worktree.

Mise en route dans l'app (compte staging, pilotage Maestro) : memory `reference_dedicated_simulator`.

Suppression (`ticket-close`) : `xcrun simctl shutdown <udid>` s'il est `Booted`, puis `xcrun simctl delete <udid>`.

### Phase dans la status line

La status line (`.claude/scripts/statusline.sh`) montre le chemin de fer des lots de `TICKET.md`. Pendant un démarrage, une clôture, un skill `version-*` ou un skill sans version, elle montre aussi l'étape en cours du skill, sa phase :

```text
APP-1235 mon-sujet │ démarrage : version                    (sur develop, avant la branche)
APP-1235 mon-sujet │ démarrage : exploration                (avant TICKET.md)
APP-1236 slug │ 1✓ › 2✓ │ clôture : revue
release/1.4.2 │ staging 1.4.2 : build                         (skill de version)
<action> │ <étape>                                             (skill sans version)
```

- Écriture : `.claude/scripts/session-phase.sh "<phase>" "<nom court>"`, lancé depuis la racine du dossier de la session, quelle que soit sa branche, sans `$(…)`. Le nom court accompagne la première phase d'un skill de ticket ou de chore, puis chaque changement de nom. La status line l'affiche à la place de la branche tant que la session n'est pas sur la branche du ticket. Les skills `version-*` n'en donnent pas : la branche reste affichée. Un skill sans version donne son `<action>`, qui remplace toute la ligne (RULES § « Onglet herdr et phase », point « Skill sans version »).
- Rangement par session : le script écrit `<git-common-dir>/claude-sessions/<session>.phase` et `.name`, avec `CLAUDE_CODE_SESSION_ID`. Une autre session du même checkout ne voit pas la phase. Le dossier commun aux worktrees garde la phase quand la session entre dans un worktree ou en sort.
- Effacement : `.claude/scripts/session-phase.sh --clear`, qui supprime la phase et le nom court. Un skill qui s'arrête, quelle qu'en soit la cause, ou qui rend la main à la conduite de session efface sa phase. Une phase restée d'une conversation coupée n'est plus lue : la conversation suivante, ou un `/clear`, a une autre session. Le hook `ticket-detect` purge les fichiers de plus de 2 jours.
- Script absent (worktree d'une release qui n'a pas encore reçu `develop`) : phases sautées sans message jusqu'à la fin du skill. Autre échec (`CLAUDE_CODE_SESSION_ID` absente, par exemple) : une ligne, sans nouvel essai. L'étape n'est jamais bloquante.
- Phases de `ticket-start` et `chore` : `démarrage : ticket` (`ticket-start`), `démarrage : version` (`ticket-start`), `démarrage : branche`, `démarrage : exploration`, `démarrage : reproduction`, `démarrage : séance d'analyse`, `démarrage : écriture`, `démarrage : audit`.
- Phase de `ticket-resume` : `reprise`, de la session trouvée jusqu'à la conduite de session.
- Phases de `ticket-close` : `clôture : <étape>`, liste et effacements dans son skill.
- Phases des skills `version-*` : `<action> <version> : <étape>`, règle dans RULES § « Onglet herdr et phase », liste dans chaque skill.
- Phases d'un skill sans version : `<étape>`, avec son `<action>` comme nom court, règle dans RULES § « Onglet herdr et phase », point « Skill sans version », liste dans le skill.

### Commits

Format de `docs/COMMITS.md` (Conventional Commits, clé `#<clé>` en fin de sujet). Fichiers de session : `docs(ticket): démarrage|pause|clôture, …`. Procédure commune aux skills :
- Commit seulement après un « oui » explicite (AskUserQuestion). Le push revient aux seuls skills qui le prévoient (`ticket-close`, `version-*`), après un accord à part.
- Sujet mesuré avant d'être montré : `.claude/scripts/commit-msg-hook.sh /dev/stdin <<'EOF'`, le message, `EOF`. Sujet signalé trop long (code 1, ou avertissement d'un ancien script) : Claude raccourcit le sujet et mesure à nouveau, sans le dire. Seul un sujet conforme est montré à l'utilisateur.
- Commit refusé par le hook après le « oui » : Claude raccourcit le sujet, relance `git commit` sans redemander, puis montre le sujet final. Rien n'a été créé, donc pas d'amend.
- Chemins explicites (`git add <chemins>`), puis `git diff --cached --stat` relu. Les fichiers que `TICKET.md` marque « ne jamais commiter » (override local…) restent hors du commit, et c'est signalé.
- Un `git commit` par appel, code de sortie et `git log -1` vérifiés avant le suivant.
- Un commit touche le paquet partagé ou le projet, jamais les deux (§ « Session de chore », point « Paquet partagé »).
- Un hook pre-commit qui reformate annule le commit : relis le diff produit, re-stage, relance. Le hook reste actif (pas de `--no-verify`).

### Fusion

Toujours `--no-ff`, même quand un fast-forward est possible, pour que le commit de merge cite le ticket :

```
git merge --no-ff <branche> -m "Merge branch '<branche>' into <cible> #<clé>"
```

`<cible>` est la base de la branche : `release/X.Y.Z` de la version du ticket, `poc/<nom>` pour un ticket d'une version POC, jamais fusionnée ailleurs (RULES § « POC »), ou `develop` pour une branche `chore/` sans ticket (RULES § « Rôle de `develop` »). Pull request : adaptateur `forge-<forge.provider>` § « Pull request ».

### Session de chore

Une chore est de l'outillage interne sans ticket : skills Claude, scripts, outils de build et de CI. Le ticket s'adresse au lecteur, que l'outillage ne concerne pas. `/chore` la démarre. `ticket-pause`, `ticket-resume` et `ticket-close` la suivent ensuite comme un ticket, avec ces écarts :
- Branche `chore/<description-kebab-case>`, dans un worktree suffixé par la description (§ « Worktree »). La base et la cible sont toujours `develop` (RULES § « Rôle de `develop` »).
- Ni ticket, ni version du ticket, ni lecture des versions publiées, ni commentaire au lecteur.
- `TICKET.md` : `ticket: none`, `base: develop`, titre `# Chore — <sujet>`. « Reproduction » porte `N/A — chore`. Aucun test `(recette)` : le lecteur ne recette pas l'outillage.
- Commits et fusions : chaque sujet et chaque message de fusion cité par un skill ou par RULES perd sa clé `#<clé>` (`docs(ticket): pause, <avancement>`, `Merge branch 'chore/<description>' into develop`).
- Chore close : `git log --all --full-history --diff-filter=D --format='%h %s' -- docs/tickets/chore-<description>/` donne le commit de clôture. La suite est celle d'un ticket clos (§ « Retrouver un ticket clos »).

**Paquet partagé** : les skills, les règles et les scripts du workflow forment un paquet commun à plusieurs projets, intégré par `git subtree --squash` sous `.claude/vendor/my-ticket-workflow/` et atteint par des liens (`docs/WORKFLOW.md` § 7). Une chore qui le modifie l'édite en place, sous ce dossier ou par ses liens. Un commit touche le paquet ou le projet, jamais les deux : `git subtree push` extrait alors les commits du paquet sans ceux du projet. À la clôture, `ticket-close` renvoie l'édition au dépôt du paquet, publie une version taguée, puis la tire dans la chore (`ticket-close` § « Paquet partagé »). `.claude/scripts/check.sh` contrôle l'installation : muet quand tout est en place.

Outillage touché pendant une session de ticket : demande hors route (§ « Conduite de session », règle 7). Il se fait dans une chore depuis `develop`, jamais sur la branche du ticket ni sur un `poc/<nom>`. La branche du ticket le reçoit ensuite par sa base, si elle en a besoin (RULES § « Mise à jour d'une base »).

Changement limité aux memories (`.claude/context/`) : un commit direct sur `develop`, sans branche ni session, puis un push après un accord à part. Une chore coûterait plus de va-et-vient que le changement.

## Fichiers

| Fichier | Rôle |
|---|---|
| `TICKET.md` | Analyse, décisions, lots, tests et état du ticket |
| `maestro/*.yaml` | Ticket `Bug`, module `maestro` : flows qui prouvent le bug, puis son correctif. Corrigés seulement si le flow est invalide. |

## TICKET.md

Deux lecteurs : l'utilisateur, qui le relit dans son éditeur, et une session neuve après un `/clear`. Le fichier se suffit à lui-même : le raisonnement de la conversation ne survit pas.

```markdown
---
branch: <branche>
ticket: <clé> | none
base: <release/X.Y.Z | poc/<nom> | develop>
last_pause: YYYY-MM-DD HH:MM
last_commit: <hash court de HEAD à la pause>
simulator: <nom court> (<udid>) | none
related_repos: []
---
# <clé> — <sujet>

## Statut
## Contexte
## Objectif et périmètre
## Sujets analysés
## Parcours
## Lots
## Tests
## Notes
```

Une section sans contenu porte `N/A — <raison>`.

### Frontmatter

- `base` : la branche d'où part le ticket et où il sera fusionné, écrite par `ticket-start`. `ticket-resume` y mesure le retard de la branche.
- `simulator` : le simulateur dédié (§ « Nom court, onglet herdr et simulateur »), `none` sans simulateur.
- `related_repos` : vide (`[]`) si la session ne touche qu'un repo. Une session transverse vit dans un seul repo (celui où l'implémentation est enracinée) et déclare les autres ici, en chemin absolu, avec leur branche et leur `last_commit` :

```yaml
related_repos:
  - path: <chemin absolu du repo lié>
    branch: <branche>
    last_commit: <hash court>
```

Claude se lance toujours depuis le repo racine de la session.

### Statut

10 lignes au plus, réécrit en fin de lot et à chaque pause. C'est la première chose lue à la reprise.

```markdown
## Statut
Lot 2/4 en cours — <titre>, étape 3.
Prochaine action : <fichier, symbole, état actuel (stub, test rouge…), geste à faire>.
En cours (non commité) : `<fichier>` — <état>.
Questions ouvertes : S4 — <question en une ligne>.
À toi : <une seule action attendue de l'utilisateur, ou « rien »>.
/clear : possible | pas encore — <raison>.
Clôture : possible | pas encore — <raison>.
```

- Prochaine action : exécutable par une session neuve qui n'a lu que `TICKET.md`.
- `/clear` possible : `TICKET.md` à jour après la dernière modification (`ticket-pause` fait).
- Clôture possible : tous les lots terminés, tests unitaires verts, tests manuels validés par l'utilisateur, flows de reproduction verts (`Bug`), working tree propre.

### Contexte

40 lignes au plus. L'existant que le ticket touche : modules, types et flux, en schéma ASCII et en extraits du code actuel. Puis, s'il y en a : repos liés, override local, conventions applicables. La cible va dans « Parcours ».

### Objectif et périmètre

Objectif, inclus, exclu, contraintes (plateforme, performance, compatibilité), comportements attendus et cas limites.

### Sujets analysés

Un sujet est un choix structurant : arbitrage de l'utilisateur ou du lecteur, choix d'architecture ou de frontière entre modules, revirement, alternative tentante écartée pour une raison invisible dans le code. Un choix local ne s'écrit pas : le code et le message de commit suffisent.

Sujet ouvert, pendant la discussion :

```markdown
### S2 — <question>
<contexte : schéma ASCII, code actuel>
- A <option> : <schéma, extrait de code, coût>
- B <option> : <schéma, extrait de code, coût>
Avis : <option recommandée et pourquoi, ou « Décision de <lecteur> » si ce n'est pas à l'équipe de trancher>
**Décision :** à trancher.
```

Sujet tranché, compacté tout de suite :

```markdown
### S2 — <question>
Options : A <option> ; B <option>.
**Décision (YYYY-MM-DD) :** <option> — <pourquoi>. Écartée : <option> (<raison>).
```

- Numérotation continue, jamais réutilisée.
- Un sujet tranché garde son texte. Revirement : nouveau sujet, et l'ancien reçoit `Remplacé par Sn.` en fin de décision.
- Le schéma et le code des options ne restent pas après la décision : ils se relisent dans l'historique git de `TICKET.md`.

### Parcours

25 lignes au plus. La vue d'ensemble du chantier, lue avant la liste des lots : l'état actuel et la cible en schéma, la chaîne des lots avec le module touché par chacun, puis 2 ou 3 lignes sur l'ordre des lots.

```text
Avant : ProfileView ──▶ ProfileLoader ──▶ URLSession          (aucun cache)
Cible : ProfileView ──▶ ProfileRepository [cache] ──▶ URLSession

Lot 1 ✓  ProfileRepository et cache mémoire      ProfileData
  │
Lot 2 ▶  ProfileView branchée sur le repository  ProfileFeature
  │
Lot 3    Purge du cache à la déconnexion          Settings

Le repository vient d'abord : il se teste seul, sans toucher l'écran.
```

- `✓` lot terminé, `▶` lot en cours. Les marques suivent « Lots ».
- Un lot ajouté, retiré ou déplacé met le parcours à jour dans la même réponse.

### Lots

Un seul lot détaillé à la fois : celui en cours. L'ordre du fichier fait foi, les numéros restent stables quand un lot change de place.

```markdown
## Lots
- Lot 1 ✓ <titre> — <hash>, <hash>
### Lot 2 ▶ <titre> (<repo ou module>)
- Objectif : <une ligne>
- Fichiers : `<chemin>` (créé | modifié) — <changement en une phrase>
- Signatures : <bloc de code des types et méthodes nouveaux ou modifiés>
- Étapes :
  1. [x] <étape>
  2. [ ] <étape>
- Critères d'acceptation : <vérifiables>
- Lot 3 <titre> — <objectif et critère, en une ou deux lignes>
```

- Lot à venir : 1 à 2 lignes. Son détail s'écrit au début du lot, avec l'utilisateur (§ « Conduite de session »).
- Lot terminé : une ligne, avec le hash court de chacun de ses commits, sans plage `a..b` (les fusions de la base s'y intercalent). Le détail retiré se relit dans l'historique git de `TICKET.md`.
- L'implémentation se lit dans le code et dans `git log` : la clé du ticket est dans chaque commit.

### Tests

```markdown
## Tests
### Commandes et prérequis
<commandes de test exactes, options, device, doublures>

### Reproduction (Maestro)
<ticket Bug seulement, sinon N/A — ticket Task, ou N/A — chore>
Simulateur : <nom court> (<udid>)
#### R-01 — <comportement vérifié> — `maestro/<fichier>.yaml`
- Préconditions : <compte, position, données>
- Bug confirmé : échec à `<commande>`, <observation> (<date>, <hash>)
- [ ] Correctif : vert (<date>, <hash>)

### Tests unitaires
- [ ] `<Suite>/<test>` — <ce qui est couvert> (Lot N)

### Tests manuels
#### T1 — <titre>
- Objectif :
- Préconditions :
- Étapes : 1. … 2. …
- Attendu :
- [ ] Fait — résultat : <OK | KO + observation, date>
```

- Test manuel validé : compacté en une ligne, `- [x] T1 — <titre> — OK (<date>)`. Ses étapes se relisent dans l'historique git de `TICKET.md`.
- Exception, test `(recette)` : marqué ainsi dans son titre à l'écriture (`#### T1 — <titre> (recette)`), il sert de recette au lecteur dans le commentaire de `ticket-close`. Il garde ses étapes jusqu'à la clôture, validé ou non. En général, un par problème corrigé ou par changement visible d'une `Task`.
- Numérotation stable : elle sert de référence dans les échanges et les commits. Un protocole à plusieurs scénarios homogènes peut être un tableau avec une colonne « Fait ».

« Reproduction » : une entrée par flow (§ « Flows de reproduction »). La ligne « Correctif » se coche au rejeu qui suit le correctif, et se décoche si un rejeu suivant échoue. Flow écrit à la reprise alors que le correctif est déjà commité, avec un working tree sale qui empêche de prouver le rouge : `Bug confirmé : non prouvé, correctif déjà présent (<hash>)` (`ticket-resume`, étape 4). Le rejeu de clôture ne s'écrit pas ici : le dossier disparaît dans le même commit, le résultat va dans le formulaire 1 et le message de clôture de `ticket-close`.

Sans flow, la section porte à la place 3 lignes :
- `Non reproduit sur simulateur : <raison>. Essais : <liste>.`, ou `Reproduction sur simulateur sautée : <raison>.` (bug trivial, sur accord)
- `Constaté : <source et lien : rapport de crash, ticket de support, capture>.`
- `Test unitaire rouge : <Suite>/<test> (<date>, <hash>).`, ou `Test unitaire rouge : à écrire.` tant que le lot de correctif ne l'a pas fait, ou `Test unitaire rouge : aucun, <raison>.`

« Tests unitaires », correctif d'un `Bug` que le test unitaire ne peut pas couvrir : `Sans test unitaire : <raison>.` (§ « Flows de reproduction », point « Tests unitaires »).

### Notes

```markdown
## Notes
### Pièges
- <comportement d'API, souci de build, fausse piste : tout ce qui a coûté plus d'un essai>
### Risques
### Traductions
### À ne pas oublier
<sujets hors périmètre, rappels et points à traiter plus tard>
```

« Traductions » : module `translations`. Sans lui, la section porte `N/A — module translations absent`, sans relevé ni liste au lecteur.

Création d'un terme, tags, export, branche abandonnée, contenu d'une ligne de « Traductions » et liste des traductions du commentaire au lecteur (`ticket-close`, étape 5) : fichier `translations.rules` de la config.

« Traductions » informe le lecteur des textes à valider ou traduire. Elle est tenue au fil de l'eau, dès qu'une clé est ajoutée, modifiée ou supprimée, et couvre toute la branche, toutes sessions confondues :
- une ligne par clé : usage (écran, contexte), texte dans chaque langue (avant → après pour une modification), statut, sujet lié (`Sn`). Le § « Ligne de Traductions » de `translations.rules` peut redéfinir ce contenu, par exemple sans les textes quand l'app a beaucoup de langues
- statut explicite par langue : une valeur vide ou absente est « à traduire »
- relevé de contrôle : `ruby .claude/scripts/ticket-translations.rb <base>`, avec la base du ticket (`release/X.Y.Z`, ou `poc/<nom>`). Sans argument, le script compare à `releases.integration_branch`, ce qui ne convient qu'à une branche `chore/`. Il lit le dossier des fichiers de localisation dans `translations.localizables`. Il compare clé par clé les fichiers de localisation au point de départ de la branche (`git merge-base`), working tree compris, signale les langues absentes, vides ou restées inchangées quand une autre a changé, et liste les `L10n.missingTranslation` ajoutés ou retirés. Le script fait foi, sans relevé à la main
- les différences importées d'autres chantiers par la synchronisation des traductions (module `translations`) ne sont pas listées : une phrase les signale
- les clés existantes réutilisées sans modification sont citées en une ligne, avec les corrections de traduction repérées.

### Taille

Un document trop long n'est plus relu. Limites : « Statut » 10 lignes, « Contexte » 40 lignes, « Parcours » 25 lignes, document 250 lignes.
- Compactage au fil de l'eau : sujet tranché, lot terminé, test manuel validé (sauf `(recette)`).
- `ticket-pause` compacte ce qui ne l'est pas encore, puis signale un dépassement restant avec les sections qui pèsent le plus.

## Conduite de session

Claude est un partenaire : il présente le contexte, l'analyse et les options, avec schémas ASCII et extraits de code, puis il donne son avis. L'utilisateur décide. Ces règles valent de la fin de `ticket-start` jusqu'à la fin de la conversation, et après `ticket-resume`.

**Ordre d'une réponse** : chaque réponse d'un skill de ticket suit cet ordre. Une partie vide n'apparaît pas.

```text
0 Sujet        Sn — <question>, si la réponse porte sur un sujet ouvert
1 Alertes      écart, retard, test rouge, reproduction manquante
2 État         parcours ✓ ▶, ce qui est fait, résumé
3 Proposition  prochaine action, annonce de lot sans sa question,
               avis qui ne répond à aucune question
4 Questions    toujours en dernier, numérotées dans l'ordre où les actions
               se font : une action qui en précède une autre a sa question
               avant la sienne. Recommandation sous les options
```

**Recommandation** : une question à options porte sa recommandation juste sous ses options, jamais avant la question : `_Recommandation :_ <option>, <raison et coût>`. L'utilisateur lit ainsi les options, puis l'avis qui les départage.

**Sujet en tête** : une réponse qui présente un sujet ouvert de « Sujets analysés », ou qui y revient, commence par `Sn — <question>` sur une ligne, avant les alertes. La partie « Questions » la répète, avec ses options et la recommandation.

Un formulaire (AskUserQuestion) s'ouvre en fin de tour, après le texte complet de la réponse, et la partie « Questions » l'annonce en une ligne. La recommandation est écrite sous cette ligne, car le formulaire ouvert masque la réponse. Dans le formulaire, l'option recommandée vient en premier, avec « (Recommandé) ». Un texte à valider (message de commit, commentaire) est montré en entier avant sa question.

1. **Début de lot** : jamais un simple « On lance le lot N ? ». L'annonce remet l'utilisateur dans le chantier, dans cet ordre :
   - le lot précédent : `Le lot N-1, qui avait pour but de <but>, est terminé (<hash>).` (omis pour le lot 1)
   - la chaîne des lots de « Parcours », `✓` sur les lots finis, `▶` sur le lot N, puis la position en une ligne (`Lot N sur M, reste : <lots suivants>.`)
   - le but du lot N en une ou deux lignes
   - les fichiers touchés, les signatures nouvelles et les étapes numérotées, écrits aussi dans « Lots »
   - la question `On lance le lot N ?`, la dernière des questions de la réponse. Accord de l'utilisateur avant de coder.
2. **Plan au plus simple** : le plan le plus direct qui remplit les critères d'acceptation. Un ajout absent du plan (type, protocole, helper, paramètre, fichier) est signalé en une ligne, avec sa raison, et attend l'accord avant d'être écrit.
3. **Après chaque modification** : un bloc `diff` dans la réponse (`git diff -- <fichier>`). Fichier créé : un bloc dans le langage du fichier. Au-delà de 40 lignes, seuls les hunks qui portent le changement, le reste nommé en une ligne.
4. **Étapes** : cochées au fil des réponses, dans la réponse et dans « Lots ».
5. **Test manuel** : proposé ou cité selon `.claude/rules/paquet/manual-tests.md`. Jamais l'identifiant seul.
6. **Au fil de l'eau** : un sujet tranché ou ajouté s'écrit tout de suite dans « Sujets analysés », une clé de traduction dans « Traductions », le résultat d'un test manuel donné par l'utilisateur dans « Tests ». Ils survivent ainsi à une compaction de la conversation.
7. **Hors route** : une demande hors du périmètre est signalée en une ligne, avec le choix : l'intégrer (avec un sujet), la noter dans « À ne pas oublier », ou la faire sans trace.
8. **Fin de lot** : le bloc ci-dessous dans la réponse, puis « Statut » et la ligne du lot (après son commit) dans `TICKET.md`. Les questions (commit du lot, lot suivant) viennent après le bloc.

```text
Parcours     : chaîne des lots, ✓ sur le lot fini, ▶ sur le suivant
Changements  : git diff --stat du lot, puis le diff clé de chaque fichier
Tests        : verts / rouges / à faire par l'utilisateur (tableau d'annonce,
               .claude/rules/paquet/manual-tests.md)
À toi        : <une seule action>
/clear       : possible | pas encore — <raison>
ticket-close : possible | pas encore — <raison>
```

## Flows de reproduction

Ticket `Bug` seulement (type validé, § « Ticket »). Le niveau 1 demande le module `maestro`. Sans lui, la preuve commence au niveau 2, et « Reproduction » porte `Reproduction sur simulateur sautée : module maestro absent.` La preuve du bug se cherche dans cet ordre :
1. flow Maestro rouge sur le simulateur dédié (cette section)
2. sinon test unitaire rouge, écrit d'après la stack trace ou la condition observée (index hors limites, valeur nulle, données reçues), au début du lot de correctif
3. sinon constat seul, avec sa source (rapport de crash, ticket de support, capture).

Les flows Maestro prouvent sur simulateur que le bug existe, puis que le correctif le supprime. `ticket-start` les écrit (étape « Reproduction »), ou `ticket-resume` s'ils manquent. Claude les rejoue quand le correctif est prêt (critère d'acceptation du lot de correctif), puis `ticket-close` les rejoue à l'état des lieux.

- **Emplacement** : `docs/tickets/<slug>/maestro/<comportement-vérifié>.yaml` (ex. `import-fichier-nom-accentue.yaml`), un flow par chemin qui confirme le bug. Ils disparaissent avec le dossier à la clôture, sans copie dans `maestro/flows/`. Après la clôture : § « Retrouver un ticket clos ».
- **Sens** : le flow vérifie le comportement correct (`assertVisible`, `assertNotVisible`, `extendedWaitUntil`…). Avec le bug, il échoue sur cette assertion. Après le correctif, il passe. Pour un crash, l'assertion suit l'action qui fait planter l'app. Un échec à une autre étape (élément introuvable, réseau, alerte système) veut dire que le flow n'est pas encore valide : corrige-le avant de conclure.
- **En-tête** en commentaires : auteur (`git config user.name`) et date du jour, rôle, préconditions, usage. Il décrit le comportement vérifié tel qu'il doit être, sans clé de ticket ni historique. Puis `appId:` `app.staging_bundle_id`, `launchApp` avec `stopApp: true`, et les étapes `optional` de la memory `reference_dedicated_simulator` (alertes système propres à l'app).
- **Données** : le flow crée ce dont il a besoin et le supprime à la fin, sans rien laisser sur le compte staging. Ce que le flow ne peut pas créer (compte de test gratuit ou abonné, position, réglage) va dans ses préconditions et dans « Tests » de `TICKET.md`.
- **Simulateur** : le simulateur dédié, ou celui qui le remplace sans module `simulator` (§ « Nom court, onglet herdr et simulateur »), avec un build du worktree installé.
- **Rejeu** : outil `run` du serveur maestro, avec `files` (chemins absolus des flows) et `device_id` (udid du simulateur dédié). Si le serveur échoue (« Device became unreachable during deviceInfo »…) : CLI `maestro --udid <udid> test <flows>`, avec l'environnement de la memory `reference_dedicated_simulator` (`JAVA_HOME`, `MAESTRO_CLI_NO_ANALYTICS=1`).
- **Proportion** : pour un bug trivial (texte faux, crash dont la stack trace donne la ligne exacte), le coût du simulateur, du build et de l'exploration dépasse le gain. Claude peut alors recommander de sauter le flow, avec la raison, et l'utilisateur décide. Sauté : la preuve passe au niveau 2.
- **Essais limités** : après 2 à 3 essais de reproduction sans résultat, arrête-toi et préviens l'utilisateur. Le bug est alors « non reproduit sur simulateur », avec la raison et les essais faits dans « Tests » de `TICKET.md`, et la preuve passe au niveau 2. Exemples de raison : crash rare, course entre threads, comportement propre au device réel (GPS réel, arrière-plan, mémoire), données d'un compte client, simulateur refusé.
- **Tests unitaires** : les flows s'ajoutent aux tests unitaires, ils ne les remplacent pas. Ils disparaissent à la clôture : le test unitaire du correctif (UseCase, ViewModel…) est la seule protection durable contre une régression, il est donc obligatoire. Exception : code que le test unitaire ne peut pas couvrir (mise en page pure, par exemple), avec `Sans test unitaire : <raison>.` dans « Tests » de `TICKET.md`. Le bug n'a alors aucune protection durable après la clôture, et le message de clôture le dit.
