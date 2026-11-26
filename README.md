# my-ticket-workflow

Skills Claude Code pour conduire un projet iOS par tickets et par versions : démarrage, pause,
reprise et clôture d'un ticket, chores d'outillage, planification et clôture des versions, revue
du diff. Les textes des skills sont en français.

Le paquet ne contient aucune valeur propre à un projet. Chaque projet garde une copie versionnée du
paquet, plus sa configuration `.claude/workflow.yml`. Les skills lisent la copie du projet, jamais
ce dépôt.

## Contenu

```text
.claude/workflow/FORMAT.md, RULES.md     règles communes aux skills
.claude/workflow/adapters/               geste propre à un service (Jira, GitHub, Bitbucket…)
.claude/skills/                          ticket-*, chore, version-*, show-diff
.claude/scripts/, .claude/hooks/         status line, phase, onglet herdr, synchronisation
.claude/settings.json                    status line et hooks
.claude/rules/manual-tests.md            protocole des tests manuels
scripts/                                 hook commit-msg, redirection des memories
docs/SKILLS.md, WORKFLOW.md, COMMITS.md  usage des skills, cycle git, format des commits
```

`docs/SKILLS.md` décrit chaque skill. `docs/WORKFLOW.md` § 7 décrit la mise en place d'un projet.

## Prérequis

- Claude Code, `git`, `bash`, `jq`, `yq` (v4), `ruby` (relevé des traductions).
- Tracker : MCP Atlassian (Jira), ou MCP GitHub et `GITHUB_PERSONAL_ACCESS_TOKEN` (issues GitHub).
- Projet iOS : MobileBuildMCP (builds, simulateur dédié) et Xcode.
- Modules optionnels (`modules` de la config) : Maestro (`maestro`), Crashlytics par le MCP
  Firebase (`crash_reporter`), POEditor (`translations`).
- herdr, facultatif : nom de l'onglet de la session.

## Installation dans un projet

1. Cloner ce dépôt à côté du projet (`../my-ticket-workflow`), ou poser `MY_TICKET_WORKFLOW_DIR`.
2. Depuis la racine du projet, dans une branche d'outillage :

   ```sh
   ../my-ticket-workflow/.claude/scripts/sync.sh recevoir           # plan, diff des fichiers écrasés
   ../my-ticket-workflow/.claude/scripts/sync.sh recevoir --apply   # copie, écrit .claude/workflow.lock
   ```

3. Écrire `.claude/workflow.yml`, puis suivre `docs/WORKFLOW.md` § 7 (statuts du tracker, tags de
   build, hook `commit-msg`, memories citées).

Exemple de configuration, pour un tracker Jira et une forge GitHub :

```yaml
tracker:
  provider: jira
  site: example.atlassian.net
  project: APP
  key_prefix: "APP-"
  reader: Alex
  reader_profile: "le responsable produit, qui ne lit pas le code"
  types: { bug: Bug, task: Task }
  states:
    en-cours: { name: In Progress, transition: 21 }
    a-livrer: { name: Ready for release, transition: 51 }
    dans-un-build: { name: In build, transition: 41 }
    fait: { name: Done, transition: 31 }
forge:
  provider: github
releases:
  published: git-tags
  integration_branch: develop
  closed_release_also_into: main
  version_file: Config/Base.xcconfig
  version_line: "MARKETING_VERSION = "
  build_tag: "{version}+{build}.{environment}"
app:
  bundle_id: com.example.app
  staging_bundle_id: com.example.app.staging
simulator:
  device_type: com.apple.CoreSimulator.SimDeviceType.iPhone-16
modules:
  maestro: true
  simulator: true
  translations: none
  crash_reporter: none
  poc: false
```

Chaque clé est décrite dans `.claude/workflow/FORMAT.md` § « Configuration » et dans les
adaptateurs qu'elle désigne.

## Synchronisation

Les skills évoluent dans un projet, puis passent aux autres :

```text
my-ticket-workflow ──recevoir──▶ projet
                   ◀──publier───
```

- `sync.sh publier` envoie au paquet les fichiers modifiés depuis le lock, et commite ici.
  `publier --apply <chemin>` ajoute un fichier au paquet.
- `sync.sh recevoir` copie dans le projet les fichiers du paquet qui diffèrent.
- Sans `--apply`, le script montre son plan et n'écrit rien. Il ne pousse jamais.

Gardes et lock : `docs/WORKFLOW.md` § 7.

## Licence

MIT, voir `LICENSE`.
