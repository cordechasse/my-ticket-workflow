---
name: ticket-check
description: Vérifie un ticket déjà traité, en lecture seule. Le code doit être dans la release de la version du ticket, et chaque demande du ticket doit être couverte. Relève le reste à faire (message de clôture, tests, traductions, commentaire au lecteur, labels). N'écrit rien, ni dans git ni dans le tracker. Cas d'usage : ticket fusionné par pull request, fusion restée sans push, ticket traité hors des skills.
argument-hint: "<clé>"
disable-model-invocation: true
---

# ticket-check

Lis d'abord, depuis la racine du dépôt, `.claude/workflow/FORMAT.md` et `.claude/workflow/RULES.md`, puis la config et les adaptateurs `tracker-<tracker.provider>`, `forge-<forge.provider>` et `published-<releases.published>` (FORMAT § « Configuration »).

Le contrôle se fait en lecture seule : git, tracker et code. Le skill ne lance ni build ni test : les tests verts relèvent de `ticket-close`, qui les exige avant la fusion. Il n'écrit rien, ni dans git ni dans le tracker : le commentaire au lecteur et le statut `a-livrer` reviennent à `ticket-close` (RULES § « Statuts »). Seule écriture : le nom de l'onglet herdr, sans demander (étape 3).

Verdict :
- **OK** : le code du ticket est dans la release de sa version, et chaque demande du ticket est couverte ou reportée par une décision écrite. Le reste à faire est listé, sans bloquer.
- **Non OK** : au moins un point bloquant (étape 5), avec la sortie de chacun.

Un formulaire (AskUserQuestion) au plus : le choix des commits trouvés par le titre (étape 3).

Session entrée dans un worktree : une commande git simple par appel, chemins et sha écrits en clair (FORMAT § « Worktree »).

## 1. Ticket

Clé `<clé>` prise dans `$ARGUMENTS` (la clé, ou le numéro seul précédé de `tracker.key_prefix`), sinon dans le nom de la branche courante et proposée, sinon demandée (AskUserQuestion).

Lis le ticket (adaptateur § « Lire un ticket ») : titre, description, type, statut logique, labels, version du ticket. Puis tous ses commentaires (adaptateur § « Lire les commentaires »). Ticket introuvable : arrêt.

Affiche en une ligne : clé, type, titre, version du ticket, statut logique, labels.

## 2. Version

1. État git et versions publiées (RULES § « Lire l'état »).
2. Version du ticket (RULES § « Versions ») :
   - version ouverte : `<release>` = `origin/release/X.Y.Z` dans la suite
   - version publiée : le ticket est livré avec elle, ou il est à refaire en hotfix (`/version-hotfix`). `<release>` = le tag du build publié (RULES § « Versions », « Build publié »)
   - module `poc`, version POC : `<release>` = `origin/poc/<nom>` (RULES § « POC »)
   - placeholder, version à ouvrir, ou aucune version : point bloquant, avec les sorties de RULES § « Cohérence base et version à l'intégration ». Le contrôle continue sur la release ouverte la plus récente, pour lister le reste à faire.

## 3. Commits du ticket

Cherche, dans cet ordre, sur `<release>` :
1. **Fusions** du ticket, sur la ligne principale de la release :
   ```bash
   git log <release> --merges --first-parent --format='%h %ad %s' --date=short | rg -e '#<clé>([^0-9]|$)'
   ```
   Pour chaque fusion `<m>`, les commits du ticket sont `git log --oneline <m>^1..<m>^2`.
2. **Commits sans fusion** : sujets qui portent la clé (RULES § « Ticket intégré sur une ref », reverts retirés).
3. **Commits sans clé** (ticket traité avant `docs/COMMITS.md`) : sujets sans aucune clé de ticket, qui reprennent les mots-clés du titre du ticket.
   ```bash
   git log <release> -i -E --grep='<mot>|<mot>' --format='%h %ad %s' --date=short
   ```
   **Formulaire** : candidats affichés (sha, date, sujet, fichiers touchés). L'utilisateur garde ceux du ticket ou en donne d'autres. Aucun commit retenu : ticket non intégré.

Rien dans `<release>` : même recherche sur les autres releases ouvertes et sur `origin/develop`. Trouvé ailleurs : écart de RULES § « Cohérence base et version à l'intégration ».

Hors de `<release>`, relève aussi :
- la branche du ticket (RULES § « Ticket intégré sur une ref », point « Branche du ticket »), et ses commits hors de la release, `docs/tickets/` exclu : `git log --oneline <release>..<branche> -- . ':!docs/tickets'`
- un dossier de session sur cette branche (`git ls-tree -r --name-only <branche> -- docs/tickets/`) : le ticket n'est pas clos
- une fusion locale non poussée : `git log --oneline origin/release/X.Y.Z..release/X.Y.Z`, si la branche locale existe
- une pull request ouverte dont la branche du ticket est la head (adaptateur forge § « Chercher une pull request »).

**Onglet herdr** : renomme l'onglet de la session au nom court de la branche du ticket, sans bloquer hors herdr (FORMAT § « Nom court, onglet herdr et simulateur »). Nom de la branche lu dans `git branch -a`, sinon dans le sujet de sa fusion (`Merge branch '<branche>'`, ou la branche citée par la fusion d'une pull request). Aucun nom trouvé : `<clé>` seule.

**Clôture** : FORMAT § « Retrouver un ticket clos ». Trouvée : lis son message en entier, et `TICKET.md` de son parent pour les tests `(recette)` et la section « Reproduction ». Ticket rouvert, plusieurs clôtures : la plus récente fait foi, les autres donnent le contexte.

## 4. Diff du ticket

- Avec fusion : `git diff --stat <m>^1 <m>` pour chaque fusion `<m>`, soit ce que la fusion apporte à la release.
- Sans fusion : `git show --stat <commit>` pour chaque commit retenu.

`docs/tickets/` est exclu. Lis ensuite le diff des fichiers de code et de test. Diff long : lis les fichiers un par un, dans l'ordre des demandes du ticket.

Relis aussi le code de `<release>` aux endroits touchés (`git show <release>:<fichier>`). Un commit plus récent, d'un autre ticket, a pu défaire ou compléter le changement.

## 5. Contrôles

### Points bloquants

1. **Intégration**, chaque point bloque :
   - aucun commit du ticket dans `<release>`
   - un commit de code de la branche du ticket hors de `<release>`, ou une pull request ouverte : sortie `/ticket-close`, ou fusion de la pull request
   - un dossier de session sur la branche du ticket : sortie `/ticket-resume`, puis `/ticket-close`
   - une fusion locale non poussée : sortie, push de `release/X.Y.Z` (relance de `/ticket-close` étape 8, ou à la main)
   - le ticket trouvé dans une autre branche que la release de sa version : sorties de RULES § « Cohérence base et version à l'intégration ».
2. **Couverture** : liste les demandes du ticket, une ligne chacune. Une demande est un problème ou une demande de la description, ou une demande ajoutée ou précisée dans un commentaire (client, recette refusée). Pour chacune, l'état et sa preuve :
   - `couverte` : le changement qui la remplit (fichier, symbole, comportement), vérifié dans le code de `<release>`. Ticket `Bug` : le changement traite la cause décrite (ticket, rapport de crash, message de clôture), pas seulement son symptôme.
   - `reportée` : décision écrite de la reporter (commentaire du ticket, « Non fait / reporté » de la clôture), avec sa source. Elle va dans le reste à faire, sans bloquer.
   - `non couverte` : aucun changement ni décision. Ce point bloque.

   Ticket sans changement hors de `docs/` (cause hors de l'app) : la demande est couverte par l'analyse, dite dans un commentaire `Aucune modification de l'app` ou `Rien à faire`, ou dans le message de clôture.

### Reste à faire, sans blocage

- **Clôture** : chaque ligne de « Non fait / reporté », vérifiée dans le code et l'historique de `<release>`. Une ligne réglée depuis sort du reste à faire, avec le commit qui la règle.
- **Tests** : un test unitaire ajouté ou modifié dans le diff pour chaque logique touchée (UseCase, ViewModel, calcul). Ticket `Bug` : test du correctif présent, sinon sa raison dans la clôture (`Sans test unitaire`). Changement de mise en page seul : rien attendu.
- **Traductions** : module `translations`, relevé ci-dessous.
- **Code** : `TODO`, `FIXME` ou un marqueur de debug (`print`, `dump`, `[DEBUG]`, `.debug()`) ajoutés dans le diff.
- **Ticket** : question d'un commentaire restée sans réponse. Labels autres que ceux du type et du statut, signalés.
- **Commentaire au lecteur** : absent (corps qui commence par `# Statut`, RULES § « Statuts », « Remplacer un statut », ou ligne `Aucune modification de l'app`), ou une correction du diff sans sa section (`ticket-close` § « 5. Commentaire au lecteur »).
- **Forme** : commit de code sans `#<clé>` en fin de sujet (`docs/COMMITS.md`), fusion sans `--no-ff` ou sans clé, `docs/tickets/` présent dans `<release>`, pas de commit de clôture. Ticket traité avant ces conventions : une seule ligne le dit, sans le détail.

**Relevé des traductions** : `ruby .claude/scripts/ticket-translations.rb <base> <ref>`, depuis la racine du dépôt, sha écrits en clair. Le script compare `<ref>` à son point de départ depuis `<base>` (`git merge-base`), sans build ni checkout :
- fusion `<m>` : `<base>` = sha de `<m>^1`, `<ref>` = sha de `<m>^2`
- commit sans fusion `<c>` : `<base>` = sha de `<c>^`, `<ref>` = sha de `<c>`, une fois par commit qui touche les localisations ou du code Swift.

Le script donne l'état à la fin du ticket. Relis chaque clé relevée à la pointe de `<release>`, dans le dossier `translations.localizables` :

```bash
git grep -n -F '"<clé de traduction>"' <release> -- <translations.localizables>
```

Une langue traduite depuis, par la synchronisation des traductions, sort du reste à faire. Chaque `L10n.missingTranslation` relevé et encore présent dans `<release>` reste à faire.

## 6. Verdict

Réponse, dans cet ordre :
1. Verdict en une ligne : `OK`, ou `Non OK : <points bloquants>`.
2. Intégration : `<release>`, fusions (sha, date) ou commits retenus, branche et pull request restantes.
3. Couverture : tableau `Demande | Source | État | Preuve`, la preuve en fichier et symbole, ou en source de la décision.
4. Reste à faire : une ligne par point, avec sa source (clôture, script, diff, ticket).

Non OK : la sortie de chaque point bloquant. Une demande non couverte repart par `/ticket-start <clé>` (réouverture).

Rappel, avec le statut logique lu à l'étape 1 : `ticket-close` pose `a-livrer` au push d'une fusion directe, le skill de build staging pose `dans-un-build`, et `fait` se pose à la main après la recette (RULES § « Statuts »).
