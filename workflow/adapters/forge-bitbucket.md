# Adaptateur forge : Bitbucket

Gestes Bitbucket des opérations de forge. Le dépôt se déduit de `git remote get-url origin` (`<workspace>/<repo>`). Les règles de fusion sont dans FORMAT § « Fusion ».

## Pull request

- Création : par le lien `https://bitbucket.org/<workspace>/<repo>/pull-requests/new?source=<branche>&dest=<cible>`, que l'utilisateur ouvre. Aucun outil ne crée la pull request.
- Titre : `<Sujet> #<clé>`, sans clé pour une branche `chore/`.
- Fusion, à la main dans Bitbucket : stratégie « Merge commit », clé du ticket gardée dans le message, « Close source branch » coché.
- La fusion se fait hors session : le ticket ne change pas de statut à la création de la pull request (RULES § « Statuts »).

## Chercher une pull request

Aucun outil ne lit les pull requests : contrôle sauté. Une ligne le dit, avec le lien `https://bitbucket.org/<workspace>/<repo>/pull-requests/?state=OPEN`, que l'utilisateur ouvre.
