# my-ticket-workflow

Skills Claude Code pour conduire un projet iOS par tickets et par versions : démarrage, pause,
reprise et clôture d'un ticket, chores d'outillage, planification et clôture des versions, revue
du diff. Les textes des skills sont en français.

Le paquet ne contient aucune valeur propre à un projet. Chaque projet l'intègre par
`git subtree --squash` à une version taguée, sous `.claude/vendor/my-ticket-workflow`, et le
rend visible à Claude Code par des liens relatifs. Il garde sa configuration
`.claude/workflow.yml` et son `.claude/settings.json`.

## Contenu

```text
workflow/FORMAT.md, RULES.md     règles communes aux skills
workflow/adapters/               geste propre à un service (Jira, GitHub, Bitbucket…)
skills/                          ticket-*, chore, version-*, show-diff
scripts/, hooks/                 status line, phase, onglet herdr, hook commit-msg, memories
rules/manual-tests.md            protocole des tests manuels
docs/SKILLS.md, WORKFLOW.md, COMMITS.md  usage des skills, cycle git, format des commits
VERSION, CHANGELOG.md            version du paquet, migration de chaque version
```

Le paquet n'a ni `CLAUDE.md` ni `AGENTS.md` : Claude Code les chargerait dès la lecture d'un de
ses fichiers. Les chemins cités par les skills sont ceux du projet (`.claude/workflow/FORMAT.md`),
atteints par les liens.

`docs/SKILLS.md` décrit chaque skill. `docs/WORKFLOW.md` § 7 décrit la mise en place d'un projet.

## Prérequis

- Claude Code, `git`, `bash`, `jq`, `yq` (v4), `ruby` (relevé des traductions).
- Tracker : MCP Atlassian (Jira), ou MCP GitHub et `GITHUB_PERSONAL_ACCESS_TOKEN` (issues GitHub).
- Projet iOS : MobileBuildMCP (builds, simulateur dédié) et Xcode.
- Modules optionnels (`modules` de la config) : Maestro (`maestro`), Crashlytics par le MCP
  Firebase (`crash_reporter`), POEditor (`translations`).
- herdr, facultatif : nom de l'onglet de la session.

## Installation dans un projet

Depuis la racine du projet, dans une branche d'outillage, working tree propre :

1. Ajouter le paquet à sa dernière version :

   ```sh
   git subtree add --prefix .claude/vendor/my-ticket-workflow \
     git@github.com:cordechasse/my-ticket-workflow.git v1.0.0 --squash
   ```

2. Créer les 18 liens relatifs (§ « Liens »).
3. Déclarer les entrées de `.claude/settings.json` (§ « Réglages »).
4. Copier `.claude/scripts/commit-msg-hook.sh` dans `.git/hooks/commit-msg`, dans l'installation
   du projet (`make setup`, par exemple).
5. Écrire `.claude/workflow.yml`, puis suivre `docs/WORKFLOW.md` § 7 (statuts du tracker, tags de
   build, memories citées).

### Liens

Chaque lien est relatif à son dossier, pour rester valide dans un autre clone ou un worktree.

| Lien dans le projet           | Cible                                                |
|-------------------------------|------------------------------------------------------|
| `.claude/skills/<skill>` (11) | `../vendor/my-ticket-workflow/skills/<skill>`        |
| `.claude/workflow`            | `vendor/my-ticket-workflow/workflow`                 |
| `.claude/scripts`             | `vendor/my-ticket-workflow/scripts`                  |
| `.claude/hooks`               | `vendor/my-ticket-workflow/hooks`                    |
| `.claude/rules/paquet`        | `../vendor/my-ticket-workflow/rules`                 |
| `docs/<doc>.md` (3)           | `../.claude/vendor/my-ticket-workflow/docs/<doc>.md` |

Les 11 skills : `chore`, `show-diff`, `ticket-check`, `ticket-close`, `ticket-pause`,
`ticket-resume`, `ticket-start`, `version-close`, `version-health`, `version-hotfix`,
`version-start`. Les 3 docs : `SKILLS.md`, `WORKFLOW.md`, `COMMITS.md`.

Les dossiers `.claude/scripts`, `.claude/hooks` et `.claude/workflow` appartiennent au paquet en
entier. Un script local va dans `scripts/` du projet. Une règle locale va dans `.claude/rules/`,
hors de `paquet/`. Un skill local va dans `.claude/skills/`, à côté des liens.

### Réglages

Le projet garde son `.claude/settings.json`. Il déclare la status line et les hooks du paquet :

```json
{
  "statusLine": {
    "type": "command",
    "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/scripts/statusline.sh"
  },
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|clear",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/ticket-detect.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "mcp__MobileBuildMCP__build_(run_)?sim",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/build-state.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

Une version qui ajoute un hook le dit dans « Migration » de `CHANGELOG.md`.

### Configuration

Exemple, pour un tracker Jira et une forge GitHub :

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

## Montée de version

Dans une branche d'outillage du projet, working tree propre :

1. Lire `CHANGELOG.md` du paquet, de la version installée
   (`.claude/vendor/my-ticket-workflow/VERSION`) à la version visée.
2. Tirer la version :

   ```sh
   git subtree pull --prefix .claude/vendor/my-ticket-workflow \
     git@github.com:cordechasse/my-ticket-workflow.git vX.Y.Z --squash
   ```

3. Créer les liens d'un skill ou d'une doc ajoutés, retirer les liens morts.
4. Suivre chaque « Migration » du CHANGELOG, dans l'ordre des versions.

## Édition du paquet depuis un projet

Le paquet s'édite dans le projet, sous `.claude/vendor/my-ticket-workflow/` ou par ses liens. Un
commit touche le paquet ou le projet, jamais les deux : `git subtree push` extrait alors des
commits propres.

```text
projet ──subtree push──▶ branche du paquet ──fusion, tag vX.Y.Z──▶ main
projet ◀──subtree pull vX.Y.Z --squash──────────────────────────── main
```

1. Renvoyer l'édition vers une branche du paquet :

   ```sh
   git subtree push --prefix .claude/vendor/my-ticket-workflow \
     git@github.com:cordechasse/my-ticket-workflow.git <branche>
   ```

2. Dans le paquet : fusion dans `main`, entrée de `CHANGELOG.md`, `VERSION`, tag annoté `vX.Y.Z`
   poussé.
3. Dans le projet : § « Montée de version » vers `vX.Y.Z`.

Les autres projets tirent la version taguée à leur rythme.

## Licence

MIT, voir `LICENSE`.
