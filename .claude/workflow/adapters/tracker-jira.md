# Adaptateur tracker : Jira

Gestes Jira des opérations de tracker. Les règles (quand écrire, ordre des statuts) sont dans `FORMAT.md` et `RULES.md`. Les valeurs viennent de la section `tracker` de `.claude/workflow.yml`.

## Accès

MCP Atlassian, site `tracker.site`, projet `tracker.project`. Le `cloudId` se lit une fois par `getAccessibleAtlassianResources`, puis se réutilise. Une opération sans outil direct se trouve par `discover`, puis se lance par `executeRead`, `executeWrite` ou `executeDestructive`, `cloudId` au premier niveau, hors de `inputs`. Une liste paginée (versions, recherche, commentaires) se lit jusqu'à sa dernière page.

- Clé d'un ticket : `tracker.key_prefix` suivi du numéro.
- Version du ticket : le champ `fixVersions`.
- L'utilisateur : son accountId vient de `atlassianUserInfo`.

## Lire un ticket

`getJiraIssue` avec `view: "full"`. Les vues `compact` et `evidence` omettent `fixVersions`, même demandé dans `fields`, comme la recherche JQL en vue compacte : le ticket paraîtrait sans version.

- Type : `issuetype.name`, comparé à `tracker.types`.
- Statut : `status.name`. Son statut logique (RULES § « Statuts ») est la clé de `tracker.states` dont le `name` est égal. Aucune clé égale : statut initial.
- Version du ticket : `fixVersions[].name` et `fixVersions[].id`. Description d'une version POC : `fixVersions[].description`.

## Lire les commentaires

`listJiraIssueComments` (via `discover` si besoin), du plus ancien au plus récent. Pour un corps à réécrire (§ « Remplacer la ligne de statut ») : `responseContentFormat: "html"`.

## Ajouter un commentaire

`addOrEditJiraIssueComment`, corps en Markdown.

## Chercher des tickets

`searchJiraIssuesUsingJql`, JQL `project = <tracker.project> AND <condition>`. La vue compacte omet `fixVersions` : la version d'un ticket trouvé se lit par § « Lire un ticket ».
- Tickets d'une version : `fixVersion = <id>`.
- Texte : `text ~ "<terme>"`, une recherche par terme.

## Créer un ticket

`createJiraIssue` dans `tracker.project`, description en Markdown :
- type : valeur de `tracker.types` (`bug` ou `task`)
- assigné : l'utilisateur
- reporter : `additional_fields.reporter` = `{"accountId": "<tracker.reporter>"}`. Jira le refuse (compte introuvable, inactif, champ non modifiable) : création sans reporter, avec un avertissement
- version : `additional_fields.fixVersions` = `[{"id": "<id>"}]`, une seule version. Ticket au backlog : champ absent.

Contrôle : § « Lire un ticket ».

Changer le type d'un ticket existant : `editJiraIssue` sur `issuetype`. Refus de Jira (workflow, schéma de types) : l'utilisateur change le type à la main, et le type validé par l'utilisateur reste celui de la session (FORMAT § « Ticket »).

## Changer la version d'un ticket

`editJiraIssue`, `fixVersions` = `[{"id": "<id>"}]`, une seule version.

## Nom d'une version

Le nom d'une version porte son numéro et son but : `X.Y.Z - <But>` (`1.5.0 - Nouvel écran de profil`).
- Numéro : le préfixe `^[0-9]+\.[0-9]+\.[0-9]+` du nom.
- Version POC : nom `POC - <But>` (`POC - Synchronisation`). Sa description porte le nom de sa branche, `poc/<nom>`.
- Placeholder : tout autre nom (`2.X.0 - Mode sombre`, `2.XX Widgets`). Son but est le nom sans le préfixe de numéro incomplet (`2.X.0 - `, `2.XX `). Numéroté, il prend le nom `X.Y.Z - <but>` : `2.X.0 - Mode sombre` devient `1.7.0 - Mode sombre`.

## Lire les versions

`getJiraProjectVersions` via `executeRead`, `inputs: {"projectIdOrKey": "<tracker.project>", "status": [<états>], "maxResults": 100, "startAt": <n>}` (`status` est un tableau), `responseFields: ["values.id", "values.name", "values.description", "values.released", "values.archived", "isLast"]`. Pagination par `startAt` jusqu'à `isLast: true` : la liste peut dépasser 100 versions.

- Versions non publiées : `["unreleased"]`.
- Toutes les versions : `["released", "unreleased", "archived"]`.
- Une version : `versionId` à la place de `projectIdOrKey`.

État d'une version pour les règles : `unreleased` est ouverte, `released` est publiée dans le tracker, `archived` est archivée. Une version publiée dans le tracker ne l'est pas forcément sur le store (RULES § « Versions »).

## Créer ou modifier une version

Un appel `manageJiraProjectVersion` via `executeDestructive` :
- création : `{"action": "create", "projectIdOrKey": "<tracker.project>", "name": "<nom>"}`
- renommage : `{"action": "update", "versionId": "<id>", "name": "<nom>"}`
- description d'une version POC : `{"action": "update", "versionId": "<id>", "description": "poc/<nom>"}`.

Ni date, ni statut. Relecture ensuite (§ « Lire les versions », par `versionId`) : le champ écrit est vérifié.

## Publier une version

Publier, archiver ou supprimer une version reste le rôle du lecteur : aucune écriture.
- Signalement (`version-close`, étape 4) : version encore `unreleased`, rappel au lecteur de la publier.

## Écrire un statut

Statut logique `<s>` de RULES § « Statuts » : `tracker.states.<s>.name` est le statut Jira, `tracker.states.<s>.transition` l'id de sa transition.

1. Commentaire : § « Lire les commentaires », puis `addOrEditJiraIssueComment` s'il n'existe pas de commentaire au texte identique.
2. Transition : `transitionJiraIssue` avec l'id de la transition.

Prérequis (WORKFLOW § 7) : une transition globale par statut, accessible depuis tous les autres.

## Remplacer la ligne de statut

Lecture et réécriture en HTML, pour garder la mise en forme du commentaire :
1. § « Lire les commentaires » en HTML. Le commentaire de clôture est le plus récent dont le corps commence par le titre `Statut`.
2. Réécriture : `addOrEditJiraIssueComment` avec `commentId` et `contentFormat: "html"`, corps entier.
