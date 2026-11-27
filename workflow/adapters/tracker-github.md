# Adaptateur tracker : GitHub

Gestes GitHub des opérations de tracker. Les règles (quand écrire, ordre des statuts) sont dans `FORMAT.md` et `RULES.md`. Les valeurs viennent de la section `tracker` de `.claude/workflow.yml`.

## Accès

Dépôt `tracker.project`, au format `<propriétaire>/<dépôt>`. Deux accès :
- issues, labels, commentaires, recherche : MCP GitHub
- milestones et réécriture d'un commentaire, que le MCP GitHub n'expose pas : `.claude/scripts/github-api.sh <MÉTHODE> <chemin> [corps JSON]`, chemin relatif à `/repos/<tracker.project>/`. Le script lit le token dans `GITHUB_PERSONAL_ACCESS_TOKEN`, comme le MCP.

Une liste paginée (milestones, recherche, commentaires) se lit jusqu'à sa dernière page : `per_page=100`, puis `page=2`, `page=3`… jusqu'à une page vide.

- Clé d'un ticket : `tracker.key_prefix` (vide en général) suivi du numéro de l'issue.
- Version du ticket : le milestone de l'issue, un seul par issue.
- L'utilisateur : son login vient du MCP GitHub (utilisateur authentifié).
- `tracker.site` et `tracker.reporter` : sans objet. L'auteur d'une issue créée est l'utilisateur.

## Lire un ticket

MCP GitHub, lecture de l'issue par son numéro.

- Type : le label de l'issue égal à une valeur de `tracker.types`. Aucun label de type : type à valider par l'utilisateur (FORMAT § « Ticket »).
- Statut : issue fermée, statut logique `fait`. Issue ouverte : la clé de `tracker.states` dont le `name` est égal à un label de l'issue. Aucune clé égale : statut initial.
- Version du ticket : `milestone.title` et `milestone.number`. Description d'une version POC : `milestone.description`.

## Lire les commentaires

MCP GitHub, commentaires de l'issue, du plus ancien au plus récent. Chaque commentaire porte son `id`, utile à § « Remplacer la ligne de statut ».

## Ajouter un commentaire

MCP GitHub, commentaire sur l'issue, corps en Markdown.

## Chercher des tickets

MCP GitHub, recherche d'issues avec la requête `repo:<tracker.project> is:issue <condition>`. La recherche rend le milestone de chaque issue.
- Tickets d'une version : `milestone:"<titre>"`.
- Texte : `"<terme>"`, une recherche par terme.

## Créer un ticket

MCP GitHub, création d'une issue dans `tracker.project`, description en Markdown :
- type : label de `tracker.types` (`bug` ou `task`)
- assigné : l'utilisateur
- version : `milestone` = numéro du milestone, un seul. Ticket au backlog : champ absent.

Contrôle : § « Lire un ticket ».

Changer le type d'un ticket existant : MCP GitHub, mise à jour des labels de l'issue, le label de l'ancien type retiré, celui du nouveau ajouté. Les autres labels restent.

## Changer la version d'un ticket

MCP GitHub, mise à jour de l'issue, `milestone` = numéro du milestone.

## Nom d'une version

Le titre d'un milestone porte le numéro seul, `X.Y.Z` (`1.5.0`). Le but de la version est dans la description du milestone (`Mode hors ligne`).
- Numéro : le titre entier, s'il suit `^[0-9]+\.[0-9]+\.[0-9]+$`.
- Version POC : titre `POC - <But>` (`POC - Synchronisation`). Sa description porte le nom de sa branche, `poc/<nom>`.
- Placeholder : tout autre titre (`1.X - Mode hors ligne`). Son but est le titre sans le préfixe de numéro incomplet (`1.X - `). Numéroté, il prend le titre `X.Y.Z` et le but va dans sa description : `1.X - Mode hors ligne` devient le titre `1.5.0`, description `Mode hors ligne`.

## Lire les versions

`github-api.sh GET 'milestones?state=<état>&per_page=100&page=<n>'`, puis les champs `number`, `title`, `description`, `state` et `open_issues` + `closed_issues`.

- Versions non publiées : `state=open`.
- Toutes les versions : `state=all`.
- Une version : `github-api.sh GET milestones/<number>`.

État d'une version pour les règles : `open` est ouverte, `closed` est publiée dans le tracker. GitHub n'a pas d'état archivé. Une version publiée dans le tracker ne l'est pas forcément sur le store (RULES § « Versions »).

## Créer ou modifier une version

Un appel `github-api.sh` :
- création : `POST milestones '{"title": "<titre>", "description": "<but>"}'`
- renommage d'un placeholder numéroté : `PATCH milestones/<number> '{"title": "X.Y.Z", "description": "<but>"}'`
- description d'une version POC : `PATCH milestones/<number> '{"description": "poc/<nom>"}'`.

Ni date d'échéance, ni état. Relecture ensuite (§ « Lire les versions », par `number`) : le champ écrit est vérifié.

## Publier une version

`version-close` ferme le milestone de la version publiée.
- Signalement (étape 4) : issues du milestone encore ouvertes avec le label de `dans-un-build`. La version est publiée : elles peuvent être fermées à la main (§ « Écrire un statut », `fait`).
- Écriture (étape 6), après confirmation : `github-api.sh PATCH milestones/<number> '{"state": "closed"}'`, puis relecture (§ « Lire les versions », par `number`). Les issues encore ouvertes restent rattachées au milestone.

## Écrire un statut

Statut logique `<s>` de RULES § « Statuts » : `tracker.states.<s>.name` est le label de l'issue. Un seul label de statut à la fois. `fait` n'a pas de label : c'est l'issue fermée, à la main.

1. Commentaire : § « Lire les commentaires », puis § « Ajouter un commentaire » s'il n'existe pas de commentaire au texte identique.
2. Labels : MCP GitHub, mise à jour des labels de l'issue. Le label du nouveau statut est ajouté, celui de l'ancien statut retiré. Les autres labels restent.

Aucun skill ne ferme une issue.

## Remplacer la ligne de statut

Lecture et réécriture en Markdown :
1. § « Lire les commentaires ». Le commentaire de clôture est le plus récent dont le corps commence par le titre `Statut`.
2. Réécriture : `github-api.sh PATCH issues/comments/<id> '{"body": "<corps entier>"}'`.
