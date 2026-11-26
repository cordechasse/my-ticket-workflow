# Workflow Git et cycle de version

Ce document décrit le parcours complet d'un ticket et d'une version, de la création de la version dans le tracker jusqu'à la clôture de la release. Chaque étape est un skill Claude Code (`/version-…`, `/ticket-…`), décrit dans [`SKILLS.md`](SKILLS.md). Les règles qu'ils appliquent sont dans [`.claude/workflow/RULES.md`](../.claude/workflow/RULES.md), les conventions de message de commit dans [`COMMITS.md`](COMMITS.md), le format des fichiers de session dans [`.claude/workflow/FORMAT.md`](../.claude/workflow/FORMAT.md).

Les valeurs propres au projet sont dans `.claude/workflow.yml`, citées ici par leur chemin (`tracker.states`). Le geste propre à un service est dans `.claude/workflow/adapters/` (FORMAT § « Configuration »). Les correspondances entre services sont au § 4. Conventions des exemples :
- clé de ticket `APP-1234`, pour `tracker.key_prefix` = `APP-`
- `develop` pour `releases.integration_branch`
- tags de build au gabarit `{version}+{build}.{environment}` (`releases.build_tag`)
- le lecteur : `tracker.reader`, qui lit les tickets, valide la recette et soumet la version au store.

Les builds staging et prod passent par des skills propres au projet, hors du paquet : le **skill de build staging** et, s'il existe, le **skill de build prod**. Leur nom et leur usage sont dans `SKILLS-LOCAL.md`, fichier local du projet.

## 1. Vue d'ensemble

| Élément | Rôle | Durée de vie |
|---|---|---|
| `release/X.Y.Z` | Version X.Y.Z : reçoit ses tickets, ses correctifs de recette, et les releases ouvertes inférieures. Source des builds staging et prod | Du premier ticket de la version à sa clôture |
| `develop` | Outillage (`chore/`) et versions fermées : le code de la dernière version publiée. Aucun ticket n'y est fusionné | Permanente |
| `releases.closed_release_also_into` | Facultative, `main` quand elle est la branche par défaut de la forge : reçoit aussi chaque release fermée, après `develop` | Permanente |
| `poc/<nom>` | Module `poc`. Intégration d'un POC : reçoit les tickets de sa version POC, source de ses builds POC. Jamais fusionnée dans `develop` ni dans une release | Permanente |
| `feature/…`, `fix/…`, `chore/…` | Un ticket, ou de l'outillage pour `chore/` | Du démarrage à la clôture du ticket |
| Tag de build | Posé par la CI sur chaque build, au gabarit `releases.build_tag` : `1.5.0+165.staging`. Une version qui contient `-` est un build POC (`1.5.0-poc.<nom>+170.staging`), ignoré par les règles de version des releases | Permanent |
| Tag de build prod | `{environment}` = `prod` (`1.5.0+168.prod`), ou chaque tag de build quand le gabarit n'a pas `{environment}` : **Release Candidate**, que le lecteur valide ou refuse. Il ne prouve pas la publication | Permanent |
| Tag de publication `vX.Y.Z` | Source `releases.published` = `git-tags` seulement : posé par `/version-close` sur le build publié | Permanent |

Principes :
- La base d'un ticket est déterminée par la **version du ticket** dans le tracker : `release/X.Y.Z`, créée par le premier ticket de la version.
- Plusieurs releases peuvent être ouvertes. La release n est fusionnée dans la n+1, jamais l'inverse : une release contient toujours les releases ouvertes inférieures.
- Toute intégration se fait par `git merge --no-ff`, avec la clé du ticket dans le message de merge. Il n'y a pas de squash, pour que l'historique des fichiers de session reste lisible dans git après la clôture.
- Tout numéro de version déterminé par un skill est **confirmé dans un formulaire à choix** avant toute écriture.
- Aucune écriture externe (push, suppression distante, tracker) n'a lieu sans confirmation explicite.
- Les skills ne déplacent jamais le checkout du développeur : une release se crée dans un worktree temporaire, une fusion se fait là où la branche cible est extraite.

## 2. Cycle d'une version

```text
/version-start : version X.Y.Z dans le tracker
  │
  ▼
Premier /ticket-start de la version : release/X.Y.Z créée, numéro de version changé
  │
  ▼
Tickets sur release/X.Y.Z : /ticket-start → /ticket-close ◄──────────────┐
  │                                                                       │
  ▼                                                                       │
Skill de build staging : build X.Y.Z+N, tickets → dans-un-build           │
  │                                                                       │
  ▼                                                                       │
Recette OK ?                                                              │
  ├── non : correctif ────────────────────────────────────────────────────┤
  │ oui                                                                   │
  ▼                                                                       │
Skill de build prod, s'il existe : Release Candidate X.Y.Z+N              │
  │                                                                       │
  ▼                                                                       │
RC validée par le lecteur et approuvée par le store ?                     │
  ├── non : correctif ────────────────────────────────────────────────────┘
  │ oui : publiée
  ▼
/version-close : publication marquée, merge dans develop, suppression de release/X.Y.Z
```

Sans skill de build prod, chaque build staging est candidat à la prod (RULES § « Versions », point « Tag de build prod »).

### Historique git d'un cycle nominal

Exemple : la 1.5.0 avance dans sa release, puis la 1.6.0 démarre pendant la recette de la 1.5.0.

```text
develop             release/1.5.0                      release/1.6.0
   │
   ● 1.4.2 publiée
   ├──────────────► ● bump 1.5.0
   │                ● #APP-1 ◄── feature/APP-1
   ● chore          │
   ├──────────────► ● fusion de develop
   │                ● #APP-2 ◄── feature/APP-2
   │                │ tag 1.5.0+165.staging
   │                ├─────────────────────────────────► ● bump 1.6.0
   │                ● #APP-4 ◄── fix/APP-4              ● #APP-6 ◄── feature/APP-6
   │                │ tag 1.5.0+166.staging            │
   │                ├─────────────────────────────────► ● fusion de 1.5.0 (1.6.0 touchée)
   │                │                                   ● #APP-7 ◄── feature/APP-7
   │                ● #APP-5 ◄── fix/APP-5              │
   │                │ tag 1.5.0+168.staging et .prod   │
   ● close 1.5.0 ◄─┘                                   │
   │                  (release/1.5.0 supprimée)        │
   └──────────────────────────────────────────────────► ● fusion de develop (1.6.0 touchée)
                                                        │ tag 1.6.0+169.staging

● : commit
#APP-n : fusion de la branche du ticket (commits de lot, puis de clôture)
« touchée » : une session démarre ou reprend un ticket de la version, ou lance son build
```

| Phase | Ce qui se passe | Commandes |
|---|---|---|
| **Ouverture** | Le premier ticket de la version 1.5.0 (`#APP-1`) crée `release/1.5.0` depuis `develop`, aucune release n'étant ouverte, avec le bump de version. Création et push après accord. | `/ticket-start` |
| **Développement et recette** | Les tickets 1.5.0 partent de `release/1.5.0` et y sont fusionnés, chacun à son rythme. Une chore fusionnée dans `develop` y arrive par la mise à jour suivante. Chaque build staging (165, 166, 168) part de la release. Les correctifs de recette (`#APP-4`, `#APP-5`) suivent le même chemin que les tickets. | `/ticket-start`, `/ticket-close`, skill de build staging |
| **Version suivante en parallèle** | Le premier ticket 1.6.0 (`#APP-6`) crée `release/1.6.0` depuis `release/1.5.0`. Ensuite, chaque fois qu'une session touche la 1.6.0, la fusion de `release/1.5.0` est proposée si elle a avancé : ici au démarrage de `#APP-7`. Travailler sur la 1.5.0 ne touche jamais la 1.6.0. | `/ticket-start`, `/ticket-resume`, skill de build staging |
| **Livraison** | Le build 168 devient la Release Candidate, le tag `.prod` reprend son numéro. Le lecteur la valide et la soumet au store. Un refus, du lecteur ou du store, donne un correctif sur `release/1.5.0` puis une nouvelle RC sous le même numéro. La version est publiée quand le store l'approuve. | skill de build prod |
| **Clôture** | Après la publication, `/version-close` la marque si la source `releases.published` le demande, fusionne `release/1.5.0` dans `develop`, puis la supprime. `release/1.6.0` reçoit `develop`, avec les derniers correctifs 1.5.0, quand une session la touche : ici avant le build 169. La version du tracker est publiée selon le service (§ 4). | `/version-close` |

Chaque ticket n'est fusionné qu'une fois, dans sa release. Aucun correctif n'est cherry-pické : il atteint les releases supérieures par leurs mises à jour, et `develop` par la clôture.

### Pourquoi une release par version, dès son premier ticket

- La base d'un ticket se lit dans la version du ticket : `release/X.Y.Z`, sans calcul d'une version « portée par `develop` ».
- Un ticket de la version suivante s'intègre tout de suite dans sa release, sans attendre la coupe de la version en cours.
- Les releases en parallèle ne divergent pas : la n+1 reçoit la n à sa création, puis chaque fois qu'une session touche la n+1, toujours dans ce sens. Travailler sur la n ne touche jamais la n+1.
- Un ticket pas encore fusionné qui glisse à la version suivante change seulement de version du ticket : la release suivante contient la précédente.
- `develop` reste stable : le code publié et l'outillage.

Contrepartie : aucune coupe ne gèle le contenu d'une version. Ce sont les versions des tickets qui le définissent : seuls les tickets de la version entrent dans sa release.

### Hotfix d'une version publiée

Exemple : un crash en production sur la 1.5.0, alors que la 1.6.0 avance dans `release/1.6.0` (`#APP-7`). Les points `#APP-n` sont les fusions de ticket, `close` les fusions de `/version-close`.

```text
develop             release/1.6.0                release/1.5.1
   │                    │
   ● close 1.5.0       │                         ● bump 1.5.1, depuis le tag 1.5.0+168.prod
   │                    ● #APP-7                  │
   │                    │                         ● #APP-8 ◄── fix/APP-8
   │                    │                         │ tag 1.5.1+170.staging et .prod
   │                    ● fusion de 1.5.1 ◄──────┤ (1.6.0 touchée)
   ● close 1.5.1 ◄─────┼─────────────────────────┘
   │                    │
```

Ordre des étapes :
1. `/version-hotfix` crée **d'abord la release du correctif**, avant tout ticket. Il crée ou réutilise la version 1.5.1 du tracker (via `/version-start`), puis crée `release/1.5.1` depuis le tag du build publié (ici `1.5.0+168.prod`, RULES § « Versions »), y commite le bump 1.5.1 et la pousse.
2. `/ticket-start` du correctif `#APP-8`, avec la version 1.5.1 : la base calculée est `release/1.5.1`.
3. `/ticket-close` fusionne `#APP-8` dans `release/1.5.1`.
4. Skill de build staging, recette, puis skill de build prod. Entre-temps, quand une session touche la 1.6.0 (ticket ou build), la fusion de `release/1.5.1` dans `release/1.6.0` est proposée. Elle entre en conflit sur la ligne de version (`releases.version_line` dans `releases.version_file`) : la fusion s'arrête, le conflit se résout à la main en gardant 1.6.0.
5. `/version-close` fusionne `release/1.5.1` dans `develop`, puis supprime la branche. Ce qui manquerait encore à `release/1.6.0` lui arrive par `develop`, à sa prochaine mise à jour.

Le hotfix part du tag : le travail 1.6.0 (`#APP-7`) n'entre pas dans le correctif. La branche `release/1.5.0` n'existe plus depuis sa clôture, seul le tag de son build publié sert de point de départ. Une recette en cours sur une autre version n'est pas bloquée.

## 3. Cycle d'un ticket

### Statuts

Statuts logiques de RULES § « Statuts ». Leur valeur dans le service : `tracker.states.<statut>.name` (§ 4).

```text
(initial)
  │ /ticket-start
  ▼
en-cours
  ├── fusion directe : /ticket-close (fusion poussée)
  │     │
  │     ▼
  │   a-livrer
  │     │ skill de build staging (ticket intégré au build)
  │     ▼
  │   dans-un-build
  │     ├── validé à la main, par qui valide la recette ──► fait
  │     └── refusé en recette, à la main ──► en-cours
  │
  └── pull request : skill de build staging ──► dans-un-build
      (pull request fusionnée, ticket intégré au build)
```

En pull request, `/ticket-close` ne voit pas la fusion : le ticket reste en `en-cours`, et le skill de build staging le passe en `dans-un-build` quand son code est dans un build.

### Choix de la branche de base (`/ticket-start`)

```text
/ticket-start
  │
  ▼
Version du ticket renseignée ?
  ├── non ──► Formulaire : versions candidates
  │             │
  │             ▼
  │           Version choisie ?
  │             ├── non ──► Pas de branche
  │ oui         │ oui
  ├─────────────┘
  ▼
Formulaire : confirmation de la version
  │
  ▼
Version POC (« POC - … », module poc) ?
  ├── oui ──► Base : origin/poc/<nom>, nommée par la description ───────────┐
  │ non                                                                     │
  ▼                                                                         │
Placeholder ?                                                               │
  ├── oui ──► Base : release ouverte la plus récente, avertissement ────────┤
  │ non                                                                     │
  ▼                                                                         │
Version déjà publiée ? (source releases.published)                          │
  ├── oui ──► Arrêt : version publiée → /version-hotfix                     │
  │ non                                                                     │
  ▼                                                                         │
release/X.Y.Z ouverte ?                                                     │
  ├── oui ──► Base : origin/release/X.Y.Z ──────────────────────────────────┤
  │ non                                                                     │
  ▼                                                                         │
Ligne hotfix, ou version plus basse qu'une release ouverte ?                │
  ├── oui ──► Arrêt : /version-hotfix, ou version à clarifier               │
  │ non                                                                     │
  ▼                                                                         │
Formulaire : créer et pousser release/X.Y.Z                                 │
(depuis la release ouverte inférieure, sinon develop)                       │
  ├── non ──► Pas de branche                                                │
  │ oui                                                                     │
  ▼                                                                         │
Base : origin/release/X.Y.Z                                                 │
  ├─────────────────────────────────────────────────────────────────────────┘
  ▼
Branche créée, ticket en-cours
```

À l'intégration, `/ticket-close` recalcule la base de la branche et vérifie qu'elle porte toujours la version du ticket : la version du ticket a pu changer, ou la version être publiée entre-temps. Au démarrage et à chaque reprise, la release est d'abord comparée à ses sources (releases inférieures, `develop`), puis la branche à la release : chaque retard donne une fusion proposée, jamais imposée. Déroulé complet : [`SKILLS.md`](SKILLS.md).

## 4. Règles de version

| Notion | Définition |
|---|---|
| Version du tracker | Un numéro `X.Y.Z` et un but, portés selon le service (tableau ci-dessous). Un nom `POC - <But>` est une **version POC** (module `poc`) : elle regroupe les tickets d'un POC, ne reçoit jamais de numéro, et sa description nomme sa branche `poc/<nom>`. Un autre nom sans numéro en tête est un **placeholder** : on peut démarrer un ticket dessus, pas le fusionner. |
| Version **ouverte** | `release/X.Y.Z` existe sur origin et la version n'est pas publiée. Elle y reçoit ses tickets, recette comprise. |
| Version **à ouvrir** | Version du tracker numérotée, ni publiée, ni ouverte, ni ligne hotfix (Z>0 alors qu'une `X.Y.*` est publiée, sans release `X.Y.*` inférieure ouverte). Sa release se crée au démarrage de son premier ticket. |
| Version **publiée** | La source `releases.published` dit que le numéro est consommé (tableau ci-dessous). Un tag de build prod n'est qu'une Release Candidate et ne compte pas, ni le statut de la version dans le tracker. |
| Ticket **intégré** sur une branche | Si la branche du ticket existe encore : sa pointe est contenue dans la branche. Sinon : le sujet d'un commit de la branche cite `#<clé>`, hors revert. Le corps des commits ne compte pas, il cite souvent d'autres tickets. |
| Numéro de version de l'app | La ligne `releases.version_line` dans `releases.version_file`, modifiée uniquement à la création d'une release (`/ticket-start`, `/version-hotfix`), dans son premier commit. |

**Contenu d'une release** : les tickets de sa version, `develop` (chores et clôtures) et les releases ouvertes inférieures. Le skill de build staging ne fait avancer que les tickets de la version du build : ceux d'une version inférieure, arrivés par la fusion de sa release, restent tels quels.

**Correspondances par service** (adaptateurs `tracker-<tracker.provider>` et `forge-<forge.provider>`) :

| Notion | Jira | GitHub |
|---|---|---|
| Version du ticket | champ `fixVersions`, une seule version | milestone de l'issue |
| Nom d'une version | `X.Y.Z - <But>` (`1.5.0 - Nouvel écran de profil`) | titre `X.Y.Z`, but dans la description |
| Statut d'un ticket | statut Jira, posé par la transition `tracker.states.<statut>.transition` | label, un seul à la fois. `fait` : issue fermée à la main |
| Type d'un ticket | type d'issue | label |
| Version publiée dans le tracker | publiée à la main par le lecteur | milestone fermé par `/version-close` |
| Pull request | Bitbucket : lien ouvert par l'utilisateur | GitHub : créée par le MCP GitHub, lien en secours |

**Versions publiées** (adaptateur `published-<releases.published>`) :

| Source | Version publiée | Marquage par `/version-close` |
|---|---|---|
| `app-store-connect` | approuvée par Apple : App Store Connect n'accepte plus de build pour ce numéro | rien à écrire |
| `git-tags` | tag annoté `vX.Y.Z` sur le commit du build publié | tag posé et poussé, après le choix du build |

## 5. Les skills

Rôle, usage, déroulé, impacts et gardes de chaque skill : [`SKILLS.md`](SKILLS.md).

## 6. Cas particuliers

| Situation | Conduite |
|---|---|
| Ticket refusé en recette | Retour en `en-cours` à la main, reprise par `/ticket-start` (réouverture), correction, puis `/ticket-close` sur la même base. |
| Hotfix pendant le développement d'une version | Deux releases ouvertes : chacune porte sa version, la version du ticket choisit la base. La release supérieure reçoit le hotfix quand une session la touche (fusion proposée), puis par `develop` après la clôture du hotfix. |
| Correctif de recette | Il arrive dans la release suivante quand une session la touche (fusion proposée), dans `develop` à `/version-close`. Pas de cherry-pick. |
| Correctif nécessaire tout de suite dans la release suivante | Démarrer ou reprendre un ticket de la version suivante : la fusion est proposée. Sinon, la faire à la main (`RULES.md` § « Fusion entre branches longues »). |
| Ticket reporté à une version supérieure, branche non fusionnée | Changer sa version dans le tracker. `/ticket-close` propose de fusionner la release d'origine dans la release supérieure si elle ne la contient pas encore, puis fusionne le ticket. |
| Ticket avancé à une version inférieure, branche non fusionnée | Changer sa version, puis déplacer ses commits : `git rebase --onto origin/release/<inférieure> $(git merge-base origin/release/<supérieure> <branche>) <branche>`. Possible seulement si la branche ne dépend pas du contenu de la version supérieure. |
| Ticket déjà fusionné, à changer de version | Il part avec la version qui l'a reçu, et les versions supérieures le contiennent aussi. Pour le sortir de cette version : revert de sa fusion dans la release, puis nouvelle branche depuis la release visée. |
| Branche de ticket en retard sur sa release | `/ticket-resume` propose d'abord de mettre la release à jour (releases inférieures, `develop`), puis de la fusionner dans la branche, sans obligation. |
| Outillage (chore) | Branche `chore/` depuis `develop`, démarrée par `/chore`, fusionnée dans `develop` par `/ticket-close`, puis chaque release ouverte reçoit `develop` quand une session la touche (fusion proposée) : les scripts de build et les skills tournent depuis la release. |
| POC | Module `poc`. Une version `POC - <But>` du tracker et sa branche `poc/<nom>`, jouant le rôle d'une release (règles : `RULES.md` § « POC »). `/ticket-start` part de `poc/<nom>`, ou la crée au premier ticket depuis sa release de référence (la plus récente, ou choisie s'il y en a plusieurs ouvertes) ; `/ticket-close` y fusionne, jamais dans `develop`. Le skill de build staging builde depuis `poc/<nom>` : la release de référence y est fusionnée d'abord et donne le numéro de version (sans release ouverte : `develop` et un commit de version), puis seuls les tickets de la version POC passent en `dans-un-build`. Jamais promu en prod. |
| Conflit sur la ligne de version | Attendu quand les deux branches d'une fusion ont changé la version : hotfix fusionné dans une release supérieure, release qui n'est pas la base de la release cible. La fusion s'arrête, la cible garde sa version. |
| Version absente du tracker au démarrage d'un ticket | `/version-start` d'abord. |

## 7. Mise en place d'un projet

Les skills, les règles et leurs scripts forment un paquet commun à plusieurs projets, tenu dans le dépôt `my-ticket-workflow`. Chaque projet en garde une copie versionnée : les skills lisent toujours les fichiers du projet, jamais le dépôt du paquet. `.claude/scripts/sync.sh` copie le paquet dans un sens ou dans l'autre :

```text
my-ticket-workflow ──recevoir──▶ projet (.claude/, docs/, scripts/) + .claude/workflow.lock
                   ◀──publier───
```

- **Installation** : cloner `my-ticket-workflow` à côté du projet (`../my-ticket-workflow`), ou poser `MY_TICKET_WORKFLOW_DIR`. Puis, dans une chore : `.claude/scripts/sync.sh recevoir` montre le plan, et le diff des fichiers locaux qu'il écrase, puis `recevoir --apply` copie. Le 1er `recevoir` se lance depuis le script du clone : `../my-ticket-workflow/.claude/scripts/sync.sh recevoir`.
- **Lock** : `.claude/workflow.lock`, commité avec le projet. 1re ligne `commit <sha du paquet>`, puis le sha256 de chaque fichier du paquet à ce commit. Un fichier dont le hash diffère est une retouche locale.
- **Évolution** : un fichier du paquet se modifie dans le projet, dans une chore. Après sa fusion dans `develop`, `sync.sh publier` montre les fichiers modifiés depuis le lock, puis `publier --apply` les copie et les commite dans le paquet. Un fichier ajouté au paquet : `publier --apply <chemin>`. Un fichier supprimé du projet est retiré du paquet. Le push du paquet se fait à la main.
- **Gardes** : `publier` refuse un paquet qui a avancé depuis le lock (`recevoir` d'abord). `recevoir` garde une retouche locale sur un fichier que le paquet n'a pas changé, et refuse un fichier changé des deux côtés. Les deux refusent un clone sale ou en retard sur origin.
- **Hors du paquet** : `.claude/workflow.yml`, les skills locaux, `SKILLS-LOCAL.md`, `CLAUDE.md`, les memories et `.claude/settings.local.json`. `recevoir` signale une memory citée par le paquet et absente de `.claude/context/`.

Le paquet ne contient ni la configuration du projet, ni l'état de ses services. Avant le premier skill :
1. **Configuration** : `.claude/workflow.yml`, avec les modules du projet (`modules`). Un service sans adaptateur dans `.claude/workflow/adapters/` demande d'abord son adaptateur.
2. **Statuts** : chaque statut logique de `tracker.states` existe dans le tracker. Jira : un statut par clé, et une transition globale vers lui, dont l'id va dans `transition`. GitHub : un label au nom de `name`, et un label par type de `tracker.types`.
3. **Versions du tracker** : chaque version non publiée porte un nom au format de l'adaptateur (§ 4), ou devient un placeholder.
4. **Tags de build** : la CI pose un tag au gabarit `releases.build_tag` sur chaque build.
5. **Versions publiées** : `app-store-connect` demande la lane `app_store_versions` et sa clé d'API. `git-tags` demande le tag `vX.Y.Z` sur chaque version publiée qui a encore sa `release/*` sur origin : sans lui, elle passe pour ouverte.
6. **Numéro de version** : `releases.version_file` contient la ligne `releases.version_line`.
7. **Hook `commit-msg`** : `scripts/commit-msg-hook.sh` copié dans `.git/hooks/commit-msg` par l'installation du projet.
8. **Fichiers locaux** : les memories citées par le paquet (SKILLS § « Fichiers de référence »), et `SKILLS-LOCAL.md`, cité par le `CLAUDE.md` du projet.
