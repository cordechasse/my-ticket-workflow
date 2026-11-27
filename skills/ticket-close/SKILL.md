---
name: ticket-close
description: Clôture un ticket ou une chore. Rejeu des flows Maestro de reproduction d'un bug, revue avant clôture (qualité du code, fuites et CPU par deux sous-agents, conformité à la demande du ticket et à ses commentaires), pourquoi durable en commentaires de code, synthèse dans le commit qui supprime docs/tickets/<slug>/, commentaire au lecteur validé, fusion --no-ff sur la base contrôlée avec la version du ticket, push avec passage au statut à livrer, suppression du worktree, des branches et du simulateur dédié.
argument-hint: "[session]"
disable-model-invocation: true
effort: high
---

# ticket-close

Langue : français pour chaque texte visible, du premier au dernier message (FORMAT § « Langue »).

Lis d'abord, depuis la racine du dépôt, `.claude/workflow/FORMAT.md` et `.claude/workflow/RULES.md`.

À la clôture, le dossier du ticket disparaît. Ce qui doit survivre va là où on le relira :
- le pourquoi qui contraint le code : commentaires de code
- la synthèse pour les développeurs : message du commit de clôture
- ce que le lecteur doit savoir : commentaire du ticket.

Le reste se retrouve dans l'historique git (FORMAT § « Retrouver un ticket clos »).

Branche `chore/` (FORMAT § « Session de chore ») : cible `develop`, ni tracker ni commentaire au lecteur. Les releases ouvertes recevront `develop` quand une session les touchera (RULES § « Rôle de `develop` »).
- Avec un dossier de session : toutes les étapes, avec ces écarts. Étape 1 : cible `develop`, sans lecture du tracker ni des versions publiées, et reproduction sautée. Étape 2 : conformité sans tracker (§ « Chore »). Étape 4 : sujet sans clé. Étape 5, formulaire 3 et points du commentaire au lecteur de l'audit : sautés. Étape 8 : la pull request ne publie aucun commentaire, et le push de `develop` du formulaire 6 n'écrit rien dans le tracker.
- Chore qui modifie le paquet partagé (FORMAT § « Session de chore », point « Paquet partagé ») : § « Paquet partagé », à la fin de l'étape 7.
- Sans dossier de session (chore démarrée à la main) : l'étape 0 est sautée, l'étape 1 se limite à la cible et au working tree, l'étape 2 aux axes qualité et performance (§ « Chore »), puis passe à l'étape 8.

Une branche de ticket sans dossier de session suit § « Clôture sans correctif » si l'analyse a conclu que l'app n'est pas en cause. Sinon elle s'arrête là : rien à clôturer, propose `/ticket-start`.

Six formulaires (AskUserQuestion) jalonnent la clôture, plus celui de création du simulateur dédié quand le rejeu de l'étape 1 le demande, celui du paquet partagé pour une chore qui le modifie, et ceux de la pause de l'étape 0. Chacun vaut accord pour ce qu'il affiche, et rien de plus.

**Onglet** : dès la session trouvée (étape 0), avant tout formulaire, `.claude/scripts/herdr-tab.sh "<nom court>"`, nom court de sa branche (FORMAT § « Nom court, onglet herdr et simulateur »). La première phase de la clôture porte aussi ce nom court : `session-phase.sh "<phase>" "<nom court>"`.

**Phase** (FORMAT § « Phase dans la status line ») : au début des étapes 0 à 7, écris la phase de l'étape : `clôture : pause` (seulement si la pause a lieu), `clôture : état des lieux`, `clôture : revue`, `clôture : commentaires de code`, `clôture : message de clôture`, `clôture : commentaire au lecteur`, `clôture : audit`, `clôture : commits`, puis `clôture : paquet` (§ « Paquet partagé », s'il a lieu). Efface-la (`session-phase.sh --clear`) :
- au début de l'étape 8, avant `ExitWorktree` : la fusion et le nettoyage suivent leurs formulaires, sans phase
- à chaque arrêt avant l'étape 8, quelle qu'en soit la cause. Par exemple : commit de la pause refusé, écart de cohérence, formulaire refusé, « Corriger plus tard », « Annuler », arrêt demandé par l'utilisateur
- quand « Corriger maintenant » rend la main pour corriger, avec ou sans lot « Revue de clôture » : la relance de la clôture réécrit la phase
- dans « Clôture sans correctif », avant `ExitWorktree`.

## 0. Pause si TICKET.md est en retard

Session : `$ARGUMENTS`, sinon celle de la branche courante, sinon la liste des tickets en cours (`docs/tickets/*/TICKET.md` de ce checkout et de chaque worktree). Trouvée dans `docs/tickets/*/STATE.md` seulement : ancien format, propose `/ticket-resume`, qui le convertit, et arrête-toi.

`TICKET.md` est en retard sur le travail dans l'un de ces cas :
- `git status --short -- docs/tickets/<slug>/` le montre modifié
- `git log -1 --format=%h -- docs/tickets/<slug>/TICKET.md` donne son dernier commit, et `git log --oneline <hash>..HEAD` n'est pas vide.

En retard : invoque `ticket-pause`, sans son rappel final sur `/clear`. Tu refuses le commit de `TICKET.md` : la clôture s'arrête, car `git rm` refuse un fichier modifié et le parent du commit de clôture doit garder le dernier état (FORMAT § « Retrouver un ticket clos »). Un commit de code refusé reste un reste à faire de l'étape 1.

## 1. État des lieux

1. Lis `TICKET.md` en entier.
2. Reste à faire, s'il y en a :
   - working tree sale (repo et `related_repos`)
   - raison de « Clôture : pas encore » dans « Statut », questions ouvertes
   - lots sans `✓` dans « Lots »
   - tests manuels non cochés ou KO
   - module `translations` : traductions « à traduire » (FORMAT § « Traductions »).
3. Cible d'intégration :
   - ticket : champ `ticket:` de `TICKET.md`, sinon la clé du nom de branche
   - état git, tracker et versions publiées (RULES § « Lire l'état »), version du ticket
   - cible = base de la branche a posteriori (RULES § « Base d'une branche a posteriori »)
   - cohérence (RULES § « Cohérence base et version à l'intégration ») : un écart arrête la clôture avant toute écriture, avec l'écart expliqué et les sorties de RULES. Une sortie que le skill sait faire (création de la release, fusion entre branches longues) se propose dans un formulaire, puis le contrôle reprend. Sinon, la clôture reprendra une fois l'écart réglé.
4. Reproduction (FORMAT § « Flows de reproduction »), d'après le dossier `maestro/` et la section « Reproduction » de « Tests » :
   - flows présents : simulateur du rejeu (FORMAT § « Nom court, onglet herdr et simulateur »). Module `simulator` : simulateur dédié trouvé, il est réutilisé. Absent : formulaire de création, coût affiché (2 à 4 Go, build complet du worktree, certificat `simulator.root_cert`, mise en route de la memory `reference_dedicated_simulator`). Refus : rejeu non fait. Puis `session_set_defaults` (`projectPath` du worktree, `simulatorId` du simulateur du rejeu), `build_run_sim` de la branche et rejeu de chaque flow. Résultat par flow : vert, ou étape en échec et observation.
   - sans flow (non reproduit ou sauté) : les 3 lignes sont reprises (raison, constat, test unitaire rouge).
   - ni flow ni lignes « sans flow » : rien à rejouer. Pour un ticket `Bug` (session plus ancienne que la reproduction), une ligne le dit.
   - test unitaire du correctif (FORMAT § « Flows de reproduction », point « Tests unitaires ») : présent dans « Tests », ou `Sans test unitaire` avec sa raison.

   Sont des restes à faire : un flow rouge, le rejeu non fait, le bug non reproduit, un test unitaire rouge encore « à écrire », un correctif sans test unitaire ni raison. Une reproduction sautée sur accord n'en est pas un.

## 2. Revue

La revue contrôle le travail de la branche avant toute écriture de clôture, sur trois axes : qualité du code, fuites et CPU, conformité à la demande.

Diff revu : `git diff origin/<cible>...HEAD` dans le dépôt. Dans chaque `related_repos`, le diff part de la base de sa branche, confirmée par l'utilisateur quand elle n'est pas évidente. Les fichiers générés en sont exclus : en-tête « Generated » ou « DO NOT EDIT », `project.pbxproj`, `Package.resolved`, `.strings`, assets. Un constat porte sur une ligne que la branche ajoute ou modifie. Un défaut du code existant n'en est pas un.

Revue sautée :
- un lot de « Lots » sans `✓` : le code est incomplet, le formulaire 1 le dit
- un diff sans fichier Swift : seul l'axe conformité reste.

Relance après un lot « Revue de clôture » terminé : son titre donne le hash de la revue précédente. Les sous-agents revoient seulement les commits de `<hash>..HEAD`, sans les fusions de la base (`git log --no-merges -p <hash>..HEAD`). La session contrôle que chaque étape du lot est cochée, avec son commit. La conformité est refaite en entier : le ticket a pu changer.

### Qualité, fuites et CPU

Deux sous-agents `general-purpose`, en effort `high` (paramètre `effort` de chaque appel), lancés dans le même message pour travailler en parallèle. Chacun reçoit :
- les chemins des dépôts, la plage du diff et la liste des fichiers revus
- son axe et ses règles, ci-dessous
- la consigne de relever seulement les lignes ajoutées ou modifiées par la branche
- le format de retour, en français : un constat par entrée, avec `fichier:ligne`, règle, constat, correction proposée, certitude (prouvé à la lecture, ou suspicion).

Aucun ne reçoit `TICKET.md` ni le raisonnement de la session : leur lecture reste neuve.

**Qualité** :
- `swiftformat --lint` et `swiftlint lint --quiet` sur les fichiers Swift revus, depuis la racine de leur dépôt. Seuls les écarts sur une ligne du diff comptent.
- règles : `~/.claude/CLAUDE.md` s'il existe, `CLAUDE.md` du dépôt, les règles de `.claude/rules/` dont les `paths:` couvrent un fichier du diff, et les memories `feedback_*` de `.claude/context/` qui portent sur l'écriture du code (chemins choisis dans `MEMORY.md`)
- points relus : nommage, `///`, en-tête des fichiers créés, commentaires (le pourquoi, sans historique ni référence de chantier), couches View → ViewModel → UseCase → Repository, isolation d'acteur, texte sans clé de traduction, code de debug oublié (`print`, `dump`, code commenté, `TODO` ajouté), tests des UseCases et ViewModels touchés
- surcomplexité : protocole à une seule implémentation sans test qui l'injecte, générique ou paramètre de configuration utilisé une seule fois, couche de pure délégation (UseCase qui transmet au Repository sans rien ajouter, wrapper), code ajouté mais jamais appelé, imbrication profonde, fonction longue, `switch` aux branches quasi identiques, réimplémentation locale d'une abstraction partagée existante. Pour chaque type, fonction ou fichier ajouté, le sous-agent cherche une version plus simple qui fait la même chose, et la donne comme correction.

**Fuites et CPU** :
- cycles de rétention : closure stockée qui capture `self` fortement (`sink`, observer, `Timer`, completion gardée, `Task` en propriété), delegate non `weak`, coordinator enfant jamais retiré de son parent
- tâches et abonnements jamais arrêtés : `Task` sans annulation, `for await` sans fin, observer NotificationCenter ou KVO, mises à jour de position
- CPU : travail répété dans `body` (formatter, tri, filtre), timer ou polling fréquent, calcul à chaque position GPS, décodage sur le main actor, précision et `distanceFilter` de `CLLocationManager`
- mémoire : cache sans limite, collection qui grandit sans borne pendant un suivi, image non réduite.

La session vérifie chaque constat dans le code avant de le présenter. Un constat non confirmé est écarté, et le formulaire 1 donne leur nombre. Une suspicion confirmée comme plausible, mais que la lecture ne prouve pas, devient une vérification ciblée pour l'utilisateur : écran, gestes, outil (Memory Graph d'Xcode, jauge CPU du Debug Navigator) et résultat attendu. Aucune mesure Instruments n'est lancée.

### Conformité

Dans la session, pendant le travail des sous-agents. Sources, dans cet ordre :
1. la description du ticket (adaptateur § « Lire un ticket »)
2. ses commentaires (adaptateur § « Lire les commentaires »), du plus ancien au plus récent. Un commentaire qui demande, modifie ou complète crée une exigence ou en remplace une, quel que soit son auteur. Un commentaire `# Statut` donne ce qui a été livré avant : il n'est pas une demande.
3. « Objectif et périmètre » et les sujets tranchés de `TICKET.md`.

Chaque exigence a une preuve (commit, fichier, test unitaire, test `(recette)` validé) et un statut :
- couverte
- partielle ou absente : reste à faire
- exclue : un sujet tranché ou un commentaire du ticket le décide, cité en source. Sans cette source, elle est absente.

Un changement du diff qui ne répond à aucune exigence est listé « hors demande ». Une exigence simple couverte par un volume disproportionné (nouveaux fichiers, types ou couches) est listée « disproportionnée », avec le volume constaté. L'étape 5 reprend les commentaires du ticket lus ici.

### Formulaire 1

La réponse affiche l'état des lieux, puis deux tableaux :
- conformité : `| # | Exigence | Source | Preuve | Statut |`, puis les changements hors demande et les exigences disproportionnées
- constats : `| # | Axe | Fichier:ligne | Constat | Correction |`, suspicions marquées, vérification ciblée sous le tableau.

**Formulaire 1** : session, ticket, cible, résultat du rejeu, reste à faire, nombre d'exigences non couvertes et de constats. Options :
- **Corriger maintenant** : les constats deviennent le lot « Revue de clôture ». La session le conduit (FORMAT § « Conduite de session ») : début de lot, diff, test par l'utilisateur, commits. Puis elle relance la clôture à l'étape 0.
- **Corriger plus tard** : le lot est écrit, puis `ticket-pause`. La clôture s'arrête, `/ticket-resume` reprendra le lot.
- **Clôturer** : reste à faire, exigences non couvertes et constats vont dans « Non fait ».
- **Annuler**.

Par « Other », l'utilisateur nomme les constats à corriger. Les autres sont écartés, avec la raison qu'il donne. Sans constat ni exigence non couverte : clôturer ou annuler.

Lot écrit à la fin de « Lots », au format de FORMAT § « Lots » :

```markdown
### Lot <n> ▶ Revue de clôture (revue sur <hash court de HEAD>)
- Objectif : corriger les constats de la revue de clôture
- Étapes :
  1. [ ] `<fichier:ligne>` : <constat>. Correction : <correction>
  2. [ ] Vérifier <suspicion> : <écran, gestes, outil, résultat attendu>
- Constats écartés : <n°> <constat> (<raison>)
- Critères d'acceptation : chaque étape cochée, avec son commit
```

### Chore

- Avec un dossier de session : la conformité compare le diff à « Objectif et périmètre » et aux sujets tranchés de `TICKET.md`, sans tracker. Le reste de l'étape s'applique, lot « Revue de clôture » compris.
- Sans dossier de session : axes qualité et performance seulement, quand le diff touche du Swift. Formulaire 1 : corriger maintenant (sans lot, puis relance de la clôture), intégrer quand même, ou annuler.

## 3. Commentaires de code

Passe en revue les sujets tranchés et non remplacés de « Sujets analysés », et les « Pièges » de « Notes ». Garde ceux qui restent vrais après le ticket, contraignent le code futur, et dont le pourquoi ne se lit pas dans le code.

Pour chacun, un commentaire là où un développeur, ou une session future, risquerait de défaire le choix. Il donne le pourquoi en absolu, dans le contexte de l'app, sans `Sn`, `D-0xx`, lot, scénario ni renvoi à la spec ou au ticket. Rien quand le code ou un commentaire existant le dit déjà.

**Formulaire 2** : liste (fichier, symbole, commentaire) à valider. Une décision sans place dans le code va dans le message de clôture.

## 4. Message de clôture

Au format de `docs/COMMITS.md` :

```
docs(ticket): clôture, <sujet> #<clé>

<Résumé, 3 à 5 lignes : objectif, ce qui a été livré>

Décisions :
- <sujet tranché> : <pourquoi en une phrase>

Non fait / reporté :
- <reste à faire, questions ouvertes, « À ne pas oublier », risques restants, tests manuels non effectués, flows de reproduction rouges ou non rejoués, bug non reproduit sur simulateur avec sa raison, correctif sans test unitaire (aucune protection durable contre une régression) avec sa raison, exigence partielle, absente ou exclue avec sa source, constat de la revue non corrigé, vérification ciblée non faite>

Traductions :
- <clé> : <statut par langue>

Fichiers de travail : git show <hash de ce commit>^:docs/tickets/<slug>/
```

- « Décisions » : les sujets tranchés et non remplacés de « Sujets analysés », une ligne chacune, sans leur numéro `Sn`. Les sujets remplacés restent dans l'historique.
- Section vide : `Rien.` (« Non fait ») ou `Aucune.` (« Décisions », « Traductions »).
- « Traductions » : module `translations`. Sans lui, la section est retirée du message.
- Les fichiers et commits du ticket se retrouvent par `git log --grep='<clé>'` : le message ne les liste pas.

## 5. Commentaire au lecteur

Le lecteur (`tracker.reader`, profil `tracker.reader_profile`) lit ce commentaire. Il veut un texte très court, pas un compte rendu. Une seule version, en gestes dans l'app, sans noms de types, de fichiers ou de modules, ni `Sn`, `D-0xx`, lot ou renvoi à la spec.

Avant de rédiger, reprends les commentaires du ticket lus à l'étape 2. Chaque correction qui y est annoncée, au fil des livraisons, a sa section, avec ses limites connues. Une correction d'un défaut absent de la version publiée n'en a pas.

Sources, sans recherche dans l'historique git :
- étapes de reproduction : flows de `maestro/`, section « Reproduction », tests `(recette)`
- « Ce qui change » d'une `Task` : « Objectif et périmètre » et tests `(recette)`
- module `translations` : traductions à compléter, « Traductions » de « Notes »
- demandes non livrées : tableau de conformité de l'étape 2.

Le commentaire commence par le paragraphe `# Statut`, de texte `En attente de livraison`. Le skill de build staging puis `version-close` remplacent ce texte au fil des livraisons (RULES § « Statuts », « Remplacer un statut »). Le contenu suit sous `# Évolutions/Corrections`.

Un ticket `Bug`, ou une `Task` qui corrige un défaut visible en prod, a une section par problème corrigé. Chaque section donne la correction, puis sa recette. Plusieurs problèmes : titres numérotés. Un seul problème : même structure, sans numéro.

```
# Statut
En attente de livraison

# Évolutions/Corrections
## 1. <problème en quelques mots>
### Livré
<une phrase : ce qui change pour l'utilisateur>
### Recette
<recette au format de son cas>
### Nouvelles traductions à compléter dans POEditor
| Clé | Usage | Texte FR |
| --- | --- | --- |
| <clé> | <où le texte s'affiche> | <texte FR> |

## 2. <problème en quelques mots>
### Livré
<une phrase : ce qui change pour l'utilisateur>
### Recette
<recette au format de son cas>
```

Problème reproduit dans l'app : les étapes pour reproduire le bug. Le lecteur le reproduit sur la version en prod, puis vérifie sur TestFlight que le bug a disparu.

```
Pour reproduire, sur la version en prod :
1. <geste dans l'app>
2. <geste dans l'app>
Constat dans la <X.Y.Z+build> : <ce qui se passe>.
Correction : <ce qui se passe avec le correctif>.
```

`<X.Y.Z+build>` : la version publiée et son build, lus dans les versions publiées à l'étape 1 (RULES § « Lire l'état »), par exemple `1.4.1+162`.

Les étapes viennent du flow Maestro, de la section « Reproduction » ou du test `(recette)` du problème, reformulées en gestes dans l'app. Chaque recette donne toutes ses étapes, même si elles répètent celles d'une autre section : jamais de « refaire les étapes du point 1 », qui ne dit pas où s'arrêter.

Les étapes se font dans l'app iOS seulement, jamais sur un autre outil. Un chemin de navigation s'écrit avec `>` : « Réglages > Compte > Notifications ». Une étape qui passe par un menu réservé au staging (menu de debug) s'écrit « Pour reproduire, sur la version en staging <X.Y.Z+build> : » : la version staging porte le même numéro et le même build que la prod. Le menu doit exister dans cette version : une ligne ajoutée par le ticket n'y est pas.

Problème sur une donnée envoyée au serveur, sans effet visible dans l'app iOS : un exemple de valeur avant et après, et l'appel réseau à regarder. La donnée corrigée est dans « Livré ».

```
Pour tester : <geste dans l'app qui déclenche l'appel>, puis regarder les appels
<MÉTHODE> <endpoint>, champ <champ>.
Constat dans la <X.Y.Z+build> : <valeur réelle> est envoyée à <valeur fausse>.
Correction : elle part à <valeur juste>.
```

L'exemple vient du test `(recette)` du problème, ou des tests unitaires de « Tests ».

Problème non reproductible, ou reproduit seulement avec un patch temporaire dans le code :

```
Non reproductible dans l'app. La correction est validée par les tests unitaires.
```

Sans test unitaire (raison dans « Tests ») : « La correction est validée sur simulateur, avec l'erreur forcée dans le code. » Un constat connu par une source (rapport de crash, ticket de support) se cite avant, avec le texte de l'erreur et la cause probable : « Constat dans la <X.Y.Z+build> : <ce qui se passe> (<source>). Cause probable : <cause>. »

Ticket sans modification de l'app (cause serveur, analyse seule) :

```
# Statut
En attente de livraison

# Évolutions/Corrections
Aucune modification de l'app : <cause> (voir l'analyse ci-dessus).
```

Ticket `Task` sans défaut visible en prod (nouvelle fonction, évolution) :

```
# Statut
En attente de livraison

# Évolutions/Corrections
## Ce qui change
<1 à 3 lignes : ce qui change dans l'app et où le voir>
```

Une demande venue du ticket (description ou commentaire), exclue, partielle ou absente au tableau de conformité de l'étape 2, a sa ligne sous `# Non livré`. Cette section suit `# Évolutions/Corrections`, quel que soit le modèle du commentaire. Elle est absente quand tout est livré.

```
# Non livré
- <demande, en gestes dans l'app> : <ce qui manque, ou la raison de l'exclusion, en une phrase>
```

La raison d'une exclusion vient de sa source (sujet tranché, commentaire du ticket).

Le commentaire ne contient ni parcours de non-régression, ni décisions, ni reste à faire hors « Non livré ». Ces points sont le travail du développeur et restent dans le message de clôture. Il ne pose aucune question : tout est décidé avant la clôture. Une question encore ouverte est un reste à faire du formulaire 1.

« Nouvelles traductions à compléter dans POEditor » : module `translations` (`poeditor`). Facultatif : seulement dans la section du problème qui ajoute des clés à traduire par le lecteur (« Traductions » de « Notes »). Une ligne par clé. C'est la seule liste des textes à traduire côté iOS (fichier `translations.rules` de la config, liste destinée au lecteur).

## 6. Audit

- [ ] Chaque sujet tranché et non remplacé est dans un commentaire de code validé ou dans « Décisions ».
- [ ] Chaque lot de « Lots » est dans le résumé ou dans « Non fait ».
- [ ] Chaque section du commentaire au lecteur vient d'une source de l'étape 5, sans recherche dans l'historique git. Chaque test `(recette)` a sa section.
- [ ] Module `translations` : « Traductions » couvre chaque clé du relevé du script (FORMAT § « Traductions »), et chaque langue non traduite est aussi dans « Non fait ».
- [ ] Les commentaires de code et le commentaire au lecteur respectent leurs règles (étapes 3 et 5).
- [ ] Le commentaire au lecteur commence par `# Statut` et `En attente de livraison`, puis `# Évolutions/Corrections` avec une section par problème corrigé (« Livré », puis « Recette » au format de son cas), ou `## Ce qui change` pour une `Task` sans défaut, puis `# Non livré` s'il y a lieu, et rien d'autre.
- [ ] Module `translations` : chaque clé à traduire par le lecteur est dans « Nouvelles traductions à compléter dans POEditor » de sa section.
- [ ] Ticket `Bug` : chaque flow de reproduction est vert au rejeu de l'étape 1, sinon il est dans « Non fait », comme le rejeu non fait et le bug non reproduit. Un correctif `Sans test unitaire` est dans « Non fait », avec sa raison.
- [ ] Revue (étape 2) : chaque exigence partielle, absente ou exclue, chaque constat non corrigé et chaque vérification ciblée non faite est dans « Non fait ». Une revue sautée pour un lot sans `✓` y est aussi. Chaque demande venue du ticket et non livrée est aussi sous `# Non livré` du commentaire au lecteur.

Annonce `Audit : N corrections`.

## 7. Validation et commits

**Formulaire 3** : commentaire au lecteur. L'utilisateur le valide ou le fait retoucher, autant de fois qu'il veut. Validé, il est écrit hors du dépôt pour l'étape 8 :

```bash
reader_comment=$(mktemp -t reader-comment) && cat > "$reader_comment" <<'TXT'
<texte validé>
TXT
echo "reader_comment=$reader_comment"
```

**Formulaire 4** : message de clôture et commits, dans cet ordre :
1. les commentaires de code du formulaire 2, s'il y en a : `docs(<scope>): … #<clé>`
2. la suppression de `docs/tickets/<slug>/` (`git rm -r`, hors fichiers « ne jamais commiter » de `TICKET.md`), avec le message de clôture.

Procédure de commit : FORMAT § « Commits ».

### Paquet partagé

Chore dont la branche modifie le paquet : `git diff --quiet origin/develop...HEAD -- .claude/vendor/my-ticket-workflow` échoue. Sinon, section sautée. Le paquet est publié avant la fusion dans `develop` : un autre projet ne tire qu'une version taguée, et `develop` ne porte jamais une édition du paquet non renvoyée.

`<préfixe>` : `.claude/vendor/my-ticket-workflow`. `<url>` : constante `PACKAGE_URL` de `.claude/scripts/check.sh`. Une commande git par appel.

1. **Version** : `X.Y.Z` depuis `<préfixe>/VERSION`, selon les règles en tête de `<préfixe>/CHANGELOG.md` (majeur : migration requise, mineur : ajout sans obligation, correctif : aucun geste). Entrée `## X.Y.Z (AAAA-MM-JJ)` du CHANGELOG, « Changements » et « Migration », écrite ou complétée d'après les commits du paquet (`git log --oneline origin/develop..HEAD -- <préfixe>`), et `VERSION`. Commit du paquet seul : `docs: version X.Y.Z`.
2. **Formulaire du paquet** : version, entrée du CHANGELOG en entier, puis les gestes des points 3 à 5. Refus : la clôture s'arrête avant la fusion, rien n'est poussé.
3. **Renvoi** : `git subtree push --prefix <préfixe> <url> <branche>`. Il pousse la branche `<branche>` dans le dépôt du paquet.
4. **Publication**, dans un clone temporaire du paquet :
   ```bash
   pkg=$(mktemp -d -t paquet) && git clone -q <url> "$pkg" && echo "pkg=$pkg"
   git -C "$pkg" merge --no-ff origin/<branche> -m "Merge branch '<branche>'"
   git -C "$pkg" tag -a vX.Y.Z -m "Version X.Y.Z"
   git -C "$pkg" push origin main vX.Y.Z
   git -C "$pkg" push origin --delete <branche>
   ```
   Conflit (le paquet a reçu la version d'un autre projet) : `git -C "$pkg" merge --abort`, arrêt, clone gardé et fichiers présentés. Fin : `rm -rf "$pkg"`.
5. **Retour** : `git subtree pull --prefix <préfixe> <url> vX.Y.Z --squash -m "Merge du paquet my-ticket-workflow vX.Y.Z"`, puis `.claude/scripts/link.sh`. Le contrôle est muet, sauf le hook `commit-msg` du checkout, que le `make setup` (ou l'équivalent du projet) recopie après la fusion.

## 8. Intégration

Session dans le worktree du ticket : `ExitWorktree` (`keep`) d'abord. La suite se lance depuis le dépôt principal, et le worktree du ticket pourra être retiré.

Refais le fetch et le contrôle de cohérence de l'étape 1 : une release a pu être coupée ou publiée entre-temps. Working tree du ticket propre, sinon arrête-toi et signale-le.

**Formulaire 5** : mode d'intégration, le recommandé en premier (celui de `CLAUDE.local.md`, sinon la pull request) :
- **Fusion directe** dans `<cible>`, locale, sans push
- **Pull request** : push de la branche, commentaire au lecteur publié, pull request créée ou son lien
- **Pas maintenant** : arrêt, worktree, branche et simulateur dédié gardés.

### Fusion directe

Module `poc`, ticket d'une version POC : la cible est `poc/<nom>`, jamais `develop` (RULES § « POC »). `poc/<nom>` ne figure dans aucun nettoyage du formulaire 6.

1. Checkout de la cible (RULES § « Checkout d'une branche ») :
   - extraite dans un dossier : `<dir>` = ce dossier, working tree propre, sinon arrête-toi
   - extraite nulle part : worktree temporaire, `wt=$(mktemp -d -t merge-<clé>) && git worktree add -q "$wt" <cible> && echo "wt=$wt"`, et `<dir>` = ce chemin.

   La cible locale n'est pas en avance sur origin (`git -C <dir> rev-list --count origin/<cible>..<cible>` à 0), sinon arrête-toi : le push embarquerait ces commits.
2. Fusion :
   ```bash
   git -C <dir> pull -q --ff-only origin <cible>
   git -C <dir> merge --no-ff <branche> -m "Merge branch '<branche>' into <cible> #<clé>"
   git -C <dir> log -1 --format='%h %p %s'
   ```
   Le commit a deux parents et la cible ne contient plus `docs/tickets/<slug>/`. Conflit : arrête-toi et présente les fichiers. Dans un worktree temporaire, `git -C <dir> merge --abort` puis `git worktree remove "$wt"`.

**Formulaire 6** (choix multiple), chemins et tailles (`du -sh`) affichés :
- pousser `<cible>`, puis commentaire au lecteur et passage au statut `a-livrer`
- supprimer le worktree et la branche locale du ticket
- supprimer la branche distante, si `origin/<branche>` existe (avec le push seulement)
- supprimer les dossiers de build du worktree : chaque ligne de `.claude/scripts/worktree-derived-data.sh <racine du worktree>` (DerivedData MobileBuildMCP et Xcode, workspace MobileBuildMCP du worktree), avec sa taille, plus les runs finis de `test-products` des workspaces trouvés. Le script se lance avant la suppression du worktree
- supprimer le simulateur dédié `<nom court>`, s'il existe (FORMAT § « Nom court, onglet herdr et simulateur »).

Sans push : ni commentaire ni transition, le ticket reste `en-cours` et le récapitulatif le signale.

### Pull request

1. `git push -u origin <branche>`, puis commentaire au lecteur, sans transition.
2. Création de la pull request (adaptateur `forge-<forge.provider>` § « Pull request »), titre `<Sujet> #<clé>`.
3. Rappel : règles de fusion de l'adaptateur forge, § « Pull request ». Le ticket reste `en-cours` : le skill de build staging le passera au statut `dans-un-build` quand il sera dans un build (RULES § « Statuts »).

**Formulaire 6** (choix multiple), chemins et tailles affichés : supprimer le worktree et la branche locale, supprimer les dossiers de build du worktree (même liste qu'en fusion directe), supprimer le simulateur dédié s'il existe.

### Exécution du formulaire 6

Dans cet ordre, pour chaque choix retenu :
1. Push : `git -C <dir> push origin <cible>`. Push refusé : arrêt de tout le nettoyage. La fusion reste locale dans `<dir>` (worktree temporaire compris, chemin affiché), à pousser à la main ou par une relance de l'étape 8.
2. Commentaire au lecteur (fichier `reader_comment` de l'étape 7) puis transition, selon RULES § « Statuts » (« Écrire dans un ticket »).
3. Branche distante : après `git merge-base --is-ancestor origin/<branche> origin/<cible>`, `git push origin --delete <branche>`.
4. Worktree du ticket : `git worktree remove <dossier>`, sans `--force`. Refus : il reste des fichiers non suivis, présente-les et arrête le nettoyage.
5. Branche locale, si ses commits sont conservés ailleurs (`git merge-base --is-ancestor <branche> <cible>` en fusion directe, `<branche> origin/<branche>` en PR) : `git branch -D <branche>`. `-D` car `-d` compare avec la branche courante du dépôt principal et refuse une branche fusionnée dans une release. Contrôle négatif : la branche reste, et c'est signalé.
6. Dossiers de build : chaque chemin de la liste du formulaire 6, `rm -rf <chemin>`. Puis les runs finis de `test-products`, dans chaque workspace d'une ligne `mobilebuildmcp` encore sur le disque (workspace partagé du dépôt principal, `<workspace>/DerivedData/<dossier>`) : chaque marqueur `<workspace>/test-products/<run>.mobilebuildmcp-completed` donne le dossier `<workspace>/test-products/<run>`, supprimé avec son marqueur. Un run sans marqueur est en cours dans une autre session : il reste.
7. Simulateur dédié : `xcrun simctl shutdown <udid>` s'il est `Booted`, puis `xcrun simctl delete <udid>`.
8. Worktree temporaire de la fusion, s'il y en a un : `git worktree remove "$wt"`.

## 9. Fin

Récapitulatif : commits, fusion (sha), push, écritures dans le tracker, ce qui a été supprimé et ce qui reste.

## Clôture sans correctif

Cas : l'analyse montre que l'app n'est pas en cause (cas isolé, cause sur l'appareil ou chez l'utilisateur : heure, réglage, réseau), et l'utilisateur décide de ne pas traiter le ticket. La branche n'a aucun commit hors de sa base (`git rev-list --count origin/<base>..<branche>` à 0). Ce cas se présente pendant la séance d'analyse de `ticket-start`, ou ici, sur une branche de ticket sans dossier de session. Il n'y a ni `TICKET.md`, ni commit, ni fusion, ni push.

1. **Preuve** : la cause, sa preuve (code lu, source du constat) et sa limite (source non lue, par exemple). L'utilisateur confirme qu'il ne traite pas le ticket. Efface la phase (`session-phase.sh --clear`), que la clôture vienne de `ticket-start` ou de ce skill.
2. **Commentaire au lecteur** : texte entier dans la réponse, validé par l'utilisateur. Sans noms de types ni de fichiers, comme à l'étape 5 :

   ```
   # Statut
   Rien à faire

   # Analyse
   <cause en 2 ou 3 phrases>

   # Décision
   Cas isolé, non traité dans l'app. Réponse au client : <geste à conseiller>.
   ```
3. **Tracker** (RULES § « Statuts », « Écrire dans un ticket ») : commentaire, puis statut `a-livrer`. La version du ticket reste : le lecteur peut décider de traiter le ticket. Sans commit, le skill de build staging ne retient pas le ticket, et `version-close` garde le statut « Rien à faire ».
4. **Nettoyage**, après accord : contrôle (working tree propre, aucun commit hors de la base), `ExitWorktree` (`keep`), liste des dossiers de build (`.claude/scripts/worktree-derived-data.sh <racine du worktree>`, avant la suppression du worktree), `git worktree remove <dossier>`, `git branch -D <branche>`, puis ces dossiers de build (exécution du formulaire 6, point 6) et le simulateur dédié s'il existe. Rien n'a été poussé : il n'y a pas de branche distante.

Récapitulatif : commentaire, transition, suppressions.
