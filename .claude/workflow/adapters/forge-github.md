# Adaptateur forge : GitHub

Gestes GitHub des opérations de forge. Le dépôt se déduit de `git remote get-url origin` (`<propriétaire>/<dépôt>`). Les règles de fusion sont dans FORMAT § « Fusion ».

## Pull request

- Création : MCP GitHub, pull request de base `<cible>` et de head `<branche>`, corps = commentaire au lecteur. Échec : lien `https://github.com/<propriétaire>/<dépôt>/compare/<cible>...<branche>`, que l'utilisateur ouvre.
- Titre : `<Sujet> #<clé>`, sans clé pour une branche `chore/`.
- Fusion, à la main dans GitHub : « Create a merge commit », clé du ticket gardée dans le message, branche supprimée après la fusion.
- La fusion se fait hors session : le ticket ne change pas de statut à la création de la pull request (RULES § « Statuts »).

## Chercher une pull request

MCP GitHub, pull requests ouvertes dont la head est `<branche>`. MCP absent ou en échec : contrôle sauté, une ligne le dit.
