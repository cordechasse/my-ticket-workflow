---
name: ticket-start
description: Démarre un ticket du tracker du projet. Ticket créé si besoin, release de sa version créée au premier ticket de la version (après accord), branche et worktree depuis cette base, ticket au statut en cours, reproduction Maestro d'un bug sur simulateur, puis séance d'analyse avec l'utilisateur et TICKET.md dans docs/tickets/<slug>/.
argument-hint: "[<clé>] [sujet]"
effort: high
disable-model-invocation: true
---

# ticket-start

Langue : français pour chaque texte visible, du premier au dernier message (FORMAT § « Langue »).

Lis d'abord, depuis la racine du dépôt, `.claude/workflow/FORMAT.md` (ticket, branche, worktree, commits, format de `TICKET.md`, conduite de session) et `.claude/workflow/RULES.md` (base selon la version du ticket), puis `.claude/workflow.yml` et les adaptateurs qu'il désigne (FORMAT § « Configuration »). Respecte FORMAT.md à la lettre.

## 1. Session existante

Cherche `branch: <branche courante>` dans `docs/tickets/*/TICKET.md`, puis dans `docs/tickets/*/STATE.md` (ancien format, que `ticket-resume` convertit). Trouvée : annonce-le en une ligne et invoque `ticket-resume` pour cette session. Le skill s'arrête là.

## 2. Ticket

Clé `<clé>` (ou le numéro seul) prise dans `$ARGUMENTS`, sinon dans le nom de la branche courante et proposée, sinon demandée (AskUserQuestion). Sans ticket, la session ne démarre pas.

- **Ticket existant** : lis-le (adaptateur § « Lire un ticket »), affiche en une ligne clé, type, titre et statut. Introuvable, hors du projet `tracker.project` ou titre sans rapport avec le sujet : signale-le et redemande.
- **Pas de ticket** : rédige un brouillon selon FORMAT § « Ticket » (type, titre, description, version), fais-le valider (AskUserQuestion), puis crée-le (adaptateur § « Créer un ticket »).
- **Réouverture** (ticket déjà travaillé) : cherche sa clôture (FORMAT § « Retrouver un ticket clos »). Trouvée : lis le message de clôture et les fichiers de travail de son parent, annonce-le, et pars de là pour l'exploration et la séance d'analyse.
- **Type** : juge d'après le titre et la description si le ticket décrit un bug (comportement actuel faux, crash, régression) ou une tâche (FORMAT § « Ticket »). Brouillon : le type jugé va dans le brouillon. Ticket existant mal typé : formulaire avec le type actuel, le type proposé et la raison. Accepté : changement de type (adaptateur § « Créer un ticket »). Le tracker refuse : avertissement, l'utilisateur change le type à la main, et la session suit quand même le type validé. Refusé : le type du tracker reste. Le type validé donne le préfixe de branche (étape 4, `fix` pour un `Bug`) et décide de la reproduction (étape 6).
- **Onglet et phase**, dès le ticket lu ou le brouillon rédigé, avant tout formulaire : choisis la description de branche (2 à 4 mots en kebab-case, sans accent, d'après le titre), puis `.claude/scripts/herdr-tab.sh "<clé>_<description>"` et `.claude/scripts/session-phase.sh "démarrage : ticket" "<clé>_<description>"`, depuis le dossier de la session (FORMAT § « Nom court, onglet herdr et simulateur », § « Phase dans la status line »). L'étape 4 propose cette description.

## 3. Version et base

Phase : `démarrage : version`.

1. Lis l'état git, le tracker et les versions publiées (RULES § « Lire l'état »), puis la version du ticket.
2. Formulaire de version (RULES § « Confirmation des numéros ») : la version actuelle du ticket en premier si elle est unique, sinon les candidats de RULES § « Base d'un ticket selon sa version ». Une version différente de la version actuelle s'écrit dans le tracker (adaptateur § « Changer la version d'un ticket ») après un « oui » explicite.
3. Base : tableau de RULES § « Base d'un ticket selon sa version ». Arrêt : explique-le, aucune branche n'est créée. Avertissement : affiche-le, puis continue. Module `poc`, version POC : POC du ticket selon RULES § « POC » (description de la version, formulaire parmi les `origin/poc/*`, nouveau POC), chaque écriture, branche ou tracker, après un « oui ».
4. Version à ouvrir (premier ticket de la version) : `release/X.Y.Z` créée et poussée selon RULES § « Créer une release », depuis le dépôt principal, après l'accord de son formulaire. Refus ou échec : arrêt, aucune branche de ticket n'est créée.
5. Mise à jour de la base, avant la branche (RULES § « Mise à jour d'une base », point 1) : chaque source en retard (release inférieure, `develop`) est proposée à la fusion dans un formulaire, depuis le dépôt principal. Refus : la branche part de la base telle quelle.

## 4. Branche, worktree et statut

Phase : `démarrage : branche`.

Selon la branche courante :
- **Branche principale** (`develop`, `main`, `master`, `release/*`, `poc/*`) : propose la branche du ticket dans son worktree (FORMAT § « Worktree »), préfixe selon le type validé, description de l'étape 2, nom, base et dossier affichés. Puis `git worktree add --no-track -b <branche> <dossier> origin/<base>` et `EnterWorktree` avec `path`. Le travail continue sur la branche principale seulement sur accord explicite.
- **Branche de ticket sans la clé** : propose de la renommer (`git branch -m`). Branche déjà poussée : le renommage impose de supprimer et repousser le distant, signale-le et demande avant d'y toucher.
- **Branche de ticket existante** : calcule sa base a posteriori (RULES § « Base d'une branche a posteriori »). Différente de la base de l'étape 3 : signale l'écart et les sorties de RULES § « Cohérence base et version à l'intégration », sans rien déplacer.

Propose le passage au statut `en-cours`, dans le formulaire de la branche s'il y en a un (RULES § « Statuts », adaptateur § « Écrire un statut »). Ticket déjà `en-cours` ou plus loin : il reste tel quel. `dans-un-build` ou `fait` : signale la réouverture, le retour en arrière se fait à la main.

Nom court de la branche retenue différent de celui de l'étape 2 (description changée au formulaire, branche existante) : renomme l'onglet, et réécris la phase avec ce nom court (FORMAT § « Nom court, onglet herdr et simulateur »).

Pièges d'une session dans un worktree (`EnterWorktree`, commandes git, MobileBuildMCP) : FORMAT § « Worktree ».

## 5. Exploration

Phase : `démarrage : exploration` (FORMAT § « Phase dans la status line »).

Sujet : `$ARGUMENTS` sans la clé, sinon le titre du ticket. Avant toute question, explore :
- les modules, types et flux touchés
- les docs existantes (`docs/`, README)
- les tickets clos qui ont touché les mêmes fichiers (FORMAT § « Retrouver un ticket clos », ticket voisin) : lis leur message de clôture quand le sujet recoupe
- les repos liés si le sujet en implique (demande leur chemin s'il est introuvable).

Résultat présenté en 10 lignes au plus, avec un schéma ASCII du flux touché : il prépare « Contexte » de `TICKET.md`. Une réponse lue dans le code se pose en confirmation (« J'ai vu X, je pars de là ? »).

## 6. Reproduction (ticket `Bug`)

Type validé `Task` : étape sautée. Sinon, phase `démarrage : reproduction`, puis, avant la séance d'analyse, cherche la preuve du bug dans l'ordre de FORMAT § « Flows de reproduction » : flow Maestro, sinon test unitaire rouge, sinon constat. Module `maestro` : points 1 à 5. Sans lui : point 6.
1. **Réouverture** : flows du ticket clos (FORMAT § « Retrouver un ticket clos ») copiés dans `docs/tickets/<slug>/maestro/` et rejoués en premier. Rouges sur leur assertion : le bug est encore là. Verts : ils ne couvrent pas le cas refusé en recette, un nouveau flow est obligatoire. Dans les deux cas, ils restent dans le dossier, et chaque parcours non vu au premier passage (recette, analyse) reçoit son flow.
2. **Proportion** : bug trivial (FORMAT, point « Proportion ») : formulaire qui recommande de sauter le flow, raison affichée. Sauté : point 6.
3. **Simulateur dédié**, module `simulator` (FORMAT § « Nom court, onglet herdr et simulateur ») : existant, réutilisé. Sinon proposé ici, coût affiché, avec celui du premier build du worktree. Accepté : création, `session_set_defaults` (`projectPath` du worktree, `simulatorId`), `build_run_sim`, puis mise en route de l'app (memory `reference_dedicated_simulator`). Refusé : bug « non reproduit sur simulateur », raison « simulateur refusé », puis point 6.
4. **Chemin** : à partir du ticket et de l'exploration, pilote l'app (MobileBuildMCP `snapshot_ui` et `tap`, ou `inspect_screen` du serveur maestro). Flows d'exploration jetables dans le scratchpad. Essais limités (FORMAT) : sans résultat, bug « non reproduit sur simulateur », puis point 6.
5. **Flows** : un par chemin qui confirme le bug, au format de FORMAT, puis rejeu. Rouge sur l'assertion du comportement attendu : bug confirmé, étape et observation gardées pour « Tests » de `TICKET.md`. Rouge à une autre étape, ou vert : le flow ne prouve rien, corrige-le avant de conclure.
6. **Sans flow** (sauté, refusé, non reproduit) : la source du constat (lien du rapport de crash, ticket de support, capture) est gardée pour « Tests » de `TICKET.md`. La stack trace ou la condition observée permet un test unitaire rouge : il devient la première étape du lot de correctif (`Test unitaire rouge : à écrire.`). Sinon : `Test unitaire rouge : aucun, <raison>.`
7. Résultat annoncé en 2 lignes : chemins confirmés, ou raison et preuve retenue (test unitaire rouge, constat).

## 7. Séance d'analyse

Phase : `démarrage : séance d'analyse`.

Claude est un partenaire (FORMAT § « Conduite de session ») : il présente, analyse et conseille, l'utilisateur décide. Aucun formulaire pendant la séance : chaque décision se prend en texte, sous « À décider ».

1. **Sujets** : liste des sujets à trancher, une ligne chacun, et les choix jugés évidents dans « Choix contestables ». Accord de l'utilisateur sur la liste.
   - Ticket `Bug` : le premier sujet confirme le chemin reproduit, ou la raison de la non-reproduction.
   - Ticket d'un seul lot sans choix d'architecture : aucun sujet d'architecture.
2. **Un sujet par réponse** : première ligne `Sn — <question>` (FORMAT § « Conduite de session », point « Sujet en tête »), puis contexte (schéma ASCII, code actuel), options (schéma, extrait de code, coût), analyse. Question sous « À décider », avec la recommandation sous ses options (FORMAT § « Conduite de session », point « Recommandation »). La décision s'écrit tout de suite dans « Sujets analysés », compactée (FORMAT § « Sujets analysés »).
3. **Parcours et lots** : schéma avant / cible et chaîne des lots (FORMAT § « Parcours »), puis la liste ordonnée, 1 à 2 lignes par lot (objectif, critère). Seul le lot 1 est détaillé : fichiers, signatures en bloc de code, étapes. Accord de l'utilisateur.
   - Ticket `Bug` : le lot de correctif a pour critères « test unitaire du correctif vert » et, si le bug est reproduit sur simulateur, « flows de reproduction verts ». Sans flow, il commence par le test unitaire rouge, s'il est possible. Claude rejoue les flows quand le correctif est prêt, avant le test de l'utilisateur et avant le commit.
4. **Tests** : tests unitaires et manuels prévus, chacun avec ses étapes. Ticket `Bug` : le test unitaire du correctif, ou la raison de son absence (FORMAT § « Flows de reproduction », point « Tests unitaires »). Module `simulator` : simulateur dédié, sauf s'il est réglé à l'étape 6, question sous « À décider », coût affiché, recommandation sous la question selon le besoin (oui si Claude doit piloter l'app). Oui : création tout de suite, ou réutilisation s'il existe déjà.

La séance est finie quand chaque section de `TICKET.md` se remplit sans deviner. Ce qui reste inconnu va dans « Questions ouvertes » du Statut.

Analyse qui montre que l'app n'est pas en cause (cas isolé) et ticket que l'utilisateur ne traite pas : la session suit `ticket-close` § « Clôture sans correctif ». Les étapes 8 à 10 sont sautées.

## 8. Écriture

Phase : `démarrage : écriture`.

`docs/tickets/<slug>/TICKET.md`, au format de FORMAT § « TICKET.md », dans ses limites de taille :
- frontmatter complet : `base` = base de l'étape 3, `last_commit` = HEAD, `simulator`.
- « Statut » : lot 1 annoncé, « Prochaine action » = sa première étape.
- « Contexte » : l'exploration de l'étape 5.
- « Sujets analysés » : chaque sujet tranché, compacté. Un sujet resté ouvert garde ses options et figure dans « Questions ouvertes » du Statut.
- « Parcours » et « Lots » : validés à l'étape 7, le lot 1 seul détaillé.
- « Tests » : tests prévus. « Reproduction » : résultat de l'étape 6, sinon `N/A — ticket Task`.
- « Notes », « Traductions » : module `translations`. Les clés prévues (texte connu ou « à définir »), sinon `N/A — aucun texte prévu pour l'instant`.
- `maestro/` : flows de l'étape 6, pour un ticket `Bug` reproduit.

## 9. Audit

Phase : `démarrage : audit`.

Relis `TICKET.md` contre la séance et corrige chaque manque :
- [ ] Chaque décision de l'utilisateur est dans « Sujets analysés », avec son pourquoi et les options écartées.
- [ ] « Parcours » montre l'avant, la cible et chaque lot.
- [ ] Chaque lot a un critère d'acceptation vérifiable. Le lot 1 a ses fichiers, ses signatures et ses étapes.
- [ ] Chaque comportement nouveau a un test, unitaire ou manuel. Chaque test manuel a objectif, préconditions, étapes et attendu.
- [ ] Ticket `Bug` : chaque flow est rouge sur son assertion, ou « Reproduction » a les 3 lignes « sans flow » (raison, constat, test unitaire rouge). Le lot de correctif a ses critères : test unitaire du correctif vert, sauf `Sans test unitaire` avec sa raison, et flows verts s'il y en a.
- [ ] Les limites de FORMAT § « Taille » sont respectées.

Annonce `Audit : N ajouts` avec la liste.

## 10. Fin

Efface la phase (`session-phase.sh --clear`) : le chemin de fer de `TICKET.md` prend le relais.

Une seule réponse, dans l'ordre de FORMAT § « Conduite de session », point « Ordre d'une réponse » :

1. Bloc de fin de démarrage :

```text
Parcours     : chaîne des lots, ▶ sur le lot 1
Fichiers     : TICKET.md (<N> lignes), flows de reproduction s'il y en a
Simulateur   : <nom court> (<udid>), ou aucun
À toi        : relire TICKET.md, valider le commit
/clear       : possible après le commit
ticket-close : pas encore — lots à faire
```

2. Annonce du lot 1 (FORMAT § « Conduite de session », règle 1), sans sa question.
3. Questions, en dernier :
   1. le commit `docs(ticket): démarrage, <sujet> #<clé>` (FORMAT § « Commits »), message montré en entier. Aucun push.
   2. `On lance le lot 1 ?`

   Le formulaire du commit s'ouvre en fin de tour, après le texte de la réponse.

Attends l'accord avant de coder. La suite de la conversation suit FORMAT § « Conduite de session ».
