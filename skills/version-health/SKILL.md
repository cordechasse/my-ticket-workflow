---
name: version-health
description: Lit la stabilité d'une version publiée dans Crashlytics, à âge égal avec la version publiée précédente. Taux d'utilisateurs sans crash, issues signalées par des règles fixes, chacune vérifiée (notes Crashlytics, tracker, événement, code de la version), puis, après accord, ticket du tracker et note Crashlytics.
argument-hint: "[X.Y.Z]"
effort: high
disable-model-invocation: true
---

# version-health

Langue : français pour chaque texte visible, du premier au dernier message.

**Module `crash_reporter`** (FORMAT § « Configuration »), avant toute lecture : `yq '.modules.crash_reporter' .claude/workflow.yml`. Autre valeur que `crashlytics` : arrêt, avec « version-health lit Crashlytics : module crash_reporter absent ou différent dans .claude/workflow.yml ».

Puis lis, depuis la racine du dépôt :
- `.claude/workflow/RULES.md` § « Lire l'état » (tracker), § « Versions » (tags de build), § « Confirmation des numéros », § « Onglet herdr et phase » et § « Statuts » (« Écrire dans un ticket »)
- `.claude/workflow/FORMAT.md` § « Configuration » et § « Ticket » : lecteur, description, reporter
- la config et l'adaptateur `tracker-<tracker.provider>`
- la memory `reference_crashlytics_mcp` : pièges de lecture propres à l'app (fonction d'envoi des non fatales, erreurs attendues, codes d'erreur).

**Onglet et phase** (RULES § « Onglet herdr et phase ») : action `version-health`, version confirmée à l'étape 1. Étapes 1 à 6 : `préparation`, `lecture`, `signalement`, `vérification`, `bilan`, `écritures`.

Le skill lit, puis propose. Les seules écritures sont un ticket du tracker et une note Crashlytics, chacun après un formulaire. Les seuils de l'étape 3 sont fixes : deux lectures de deux versions se comparent.

Crashlytics, app prod : `crashlytics.app_id`, projet `crashlytics.project`. Les données couvrent les 90 derniers jours. Lien d'une issue : `https://console.firebase.google.com/project/<crashlytics.project>/crashlytics/app/ios:<app.bundle_id>/issues/<issueId>`.

## 1. Préparer

1. Lis `firebase://guides/crashlytics/reports` (`firebase_read_resources`) : prérequis des rapports.
2. `crashlytics_get_report`, `releaseVersions`, des 90 derniers jours à maintenant, `pageSize` 20. Erreur d'authentification : arrêt. L'utilisateur lance `! npx -y firebase-tools@latest login --reauth` : la CLI affiche une URL, la page donne un code, puis `! npx -y firebase-tools@latest login <code>`, puis `/mcp` pour reconnecter `firebase`. `/mcp` seul ne renouvelle pas le jeton. Le rapport rend 3 versions au plus, même avec `pageSize` 20 : le formulaire et la référence s'en contentent.
3. Versions candidates : les `displayName` `X.Y.Z (build)` sans `-` (un `-` marque un build POC). Une version présente avec plusieurs builds garde celui qui a le plus d'utilisateurs.
4. Formulaire de version (RULES § « Confirmation des numéros ») : l'argument en premier, sinon la version la plus haute, puis les 2 suivantes.
5. Référence : la version candidate juste inférieure à la version lue.
6. **J0** de chaque version : `appSummary` filtré sur la version (`versionDisplayNames`), `TIME_GRANULARITY_DAY`, des 90 derniers jours à maintenant. J0 est le premier jour où `totalUsersCount` atteint 100. Le premier jour lu l'atteint déjà : la publication est antérieure aux 90 jours, la version n'a pas de J0. Avant J0, les utilisateurs sont des testeurs ou des installations avant la publication.
7. **D** : nombre de jours complets de J0 à hier inclus, 7 au plus. La journée en cours est exclue. La fenêtre d'une version va de son J0 à J0 + D, en jours UTC.

Arrêts :
- version sans J0 : « moins de 100 utilisateurs par jour, version pas encore publiée »
- D = 0 : « publiée aujourd'hui, relancer demain ».

Référence sans J0 dans les 90 jours : le skill continue sans référence. Le bilan le dit, et R3 ne s'applique pas.

## 2. Lire

Sur la fenêtre de chaque version (§ 1, point 7), filtrée sur cette version :
- `appSummary` avec `issueErrorTypes` = `FATAL` : taux d'utilisateurs sans crash (`crashFreeUsersPercentage`)
- `topIssues` avec `FATAL`, `pageSize` 20
- `topIssues` avec `NON_FATAL`, `pageSize` 20.

Part d'utilisateurs touchés par une issue : `impactedUsersCount` / `totalUsersCount` du groupe.

**Erreur d'une issue `NON_FATAL`** : son `subtitle` jusqu'au premier ` - ` (`com.example.syncFailed (1)`, `SomeSDK.ErrorCode (2)`). Crashlytics peut grouper la même erreur sous une autre issue d'une version à l'autre (titre de la fonction d'envoi changé, par exemple). Part d'une erreur : somme des `impactedUsersCount` de ses issues / `totalUsersCount`. Un utilisateur touché par deux de ses issues compte deux fois : la part est un majorant.

Les erreurs non fatales n'entrent pas dans le taux sans crash : l'app envoie aussi des erreurs attendues (memory `reference_crashlytics_mcp`).

## 3. Signaler

| Règle | Type | Condition | Seuil |
|---|---|---|---|
| R1 | `FATAL` | `firstSeenVersion` = la version lue | Dès 1 utilisateur |
| R2 | Tous | `SIGNAL_REGRESSED` dans `signals` | Dès 1 utilisateur |
| R3 | `NON_FATAL` | Part de l'erreur ≥ 1,5 × celle de la référence (0 si l'erreur en est absente) | 10 utilisateurs ou plus |
| R4 | `NON_FATAL` | `firstSeenVersion` = la version lue, et erreur absente de la référence | 3 utilisateurs ou plus |

R3 et R4 portent sur l'erreur (§ 2), pas sur l'issue : une erreur signalée avec plusieurs issues fait une seule ligne, sous l'issue qui a le plus d'utilisateurs.

R4 sans référence : l'erreur est absente de la référence si chacune de ses issues a `firstSeenVersion` = la version lue. Une seule issue plus ancienne suffit à écarter R4.

Taux sans crash : en tête du bilan s'il est sous 99,5 %, ou en baisse de plus de 0,2 point par rapport à la référence.

Une ligne de log ou de breadcrumb n'est jamais un signal. Elle va seulement dans le détail de l'issue qui la porte.

## 4. Vérifier

Pour chaque issue signalée, 5 au plus, triées par utilisateurs touchés. Au-delà, une ligne par issue, sans vérification.

1. **V1, notes** : `crashlytics_list_notes`. Une note existe, et l'issue n'est pas en R2 : issue « connue », la dernière note est citée, V2 à V4 sont sautées et l'étape 5 ne pose aucune question. En R2, la régression est postérieure à la note : les vérifications continuent.
2. **V2, tracker** : adaptateur § « Chercher des tickets », par texte, avec l'`issueId`, puis avec chacun de ces termes :
   - `NON_FATAL` : le domaine de l'erreur sans préfixe (`syncFailed` pour `com.example.syncFailed`)
   - 1 ou 2 termes métier en français tirés du titre (écran, fonction).

   Ticket trouvé : clé, statut et version du ticket (adaptateur § « Lire un ticket »). Puis Claude classe le ticket :
   - **suit l'issue** : sa description ou ses commentaires citent l'issue, son erreur ou son crash
   - **lié** : il touche le même code ou la même fonction, sans traiter l'issue.
3. **V3, événement** : `crashlytics_batch_get_events` avec le `sampleEvent` du rapport. Retenir l'appareil, l'OS, la mémoire libre, les 5 derniers logs et le `blameFrame`. Le code `(N)` d'une erreur de l'app se lit avec la memory `reference_crashlytics_mcp`.
4. **V4, code**, sur le fichier fautif :
   - `FATAL` : le `blameFrame.file`, si `blameFrame.owner` = `DEVELOPER`. Sinon V4 est sautée.
   - `NON_FATAL` : le `blameFrame` pointe toujours vers la fonction d'envoi de l'app (memory `reference_crashlytics_mcp`), jamais vers la cause. Le fichier fautif est l'émetteur : `rg -l --type swift '<domaine>'` avec la clé `nserror-domain` de l'événement. Aucun fichier (erreur système, `NSURLErrorDomain`) : « émetteur hors de l'app », V4 est sautée. Plus de 3 fichiers : « émetteur non unique », V4 est sautée.

   Puis :
   - `git fetch -q --tags --force origin`
   - tags de build prod des deux builds (RULES § « Versions ») : `git tag -l '<tag>'`
   - chemin : `git ls-files '*/<fichier fautif>'`, sauf pour un émetteur, dont `rg` donne déjà le chemin
   - `git log --oneline <tag de référence>..<tag lu> -- <chemin>`. Des commits : la cause probable est parmi eux, lis leur diff sur ce fichier. Aucun commit : le code n'a pas changé, la cause est ailleurs (données, OS, appareil).

Cause probable : 1 à 3 lignes, tirées de V3 et V4. Sans élément : « cause inconnue ».

## 5. Bilan

Réponse dans le terminal, dans cet ordre.

Bloc de tête :

```text
<X.Y.Z> (<build>)   J0 <JJ/MM>, <D> jours lus   │ réf. <X.Y.Z> (<build>), J0 <JJ/MM>, mêmes <D> jours
Sans crash          <taux> %                    │ réf. <taux> %     <✓ ou ⚠️ et la raison>
```

**Tableau récapitulatif** : une ligne par issue `FATAL` de la version lue, puis une ligne par erreur non fatale (§ 2), 10 au plus, triées par utilisateurs de la version lue. Au-delà, une ligne « <n> autres erreurs non fatales ». Les signalées viennent d'abord dans chaque groupe. Une erreur absente de la version lue n'est pas listée.

| Id | Type | Raison | Occurrences | Suivi |
|---|---|---|---|---|
| #1 | Crash | `loadItems`, `NSInvalidArgumentException` | 1 | note du 01/01 |
| #2 | Non fatale | `syncFailed (1)` | 63 | |

- Id : `#1`, `#2`… dans l'ordre du tableau, repris par la liste des issues.
- Raison : crash, la fonction du titre et l'exception du `subtitle`. Non fatale, l'erreur (§ 2).
- Occurrences : `eventsCount` dans la fenêtre de la version lue, somme de ses issues pour une erreur.
- Suivi : `note du JJ/MM`, `<clé>`, ou vide.

**Liste des issues** : une section `### Issue #<n> - <type>` (`Crash` ou `Non fatale`) par ligne du tableau qui porte une règle ou un suivi, en liste. Les autres lignes n'ont pas de section. Aucune ligne concernée : pas de liste.

```markdown
### Issue #1 - Crash
- Issue 0000abcd (<lien de l'issue>)
- Utilisateurs : 1 sur 1 000 (0,1 %), réf. 0. Règle : R1.
- V1 : note du 01/01. « Argument nul… »
- Cause probable : liste vide au premier lancement.
```

- Issue : les 8 premiers caractères de l'`issueId`, puis le lien entre parenthèses. Une erreur groupée sous plusieurs issues : une ligne par issue.
- Utilisateurs : version lue et référence, avec la part (§ 2). Sans référence : `réf. —`. Non fatale, le ratio. Règle déclenchée, ou « aucune ».
- Issue vérifiée (§ 4) : une ligne par vérification faite (V1 à V4), puis « Cause probable ». Une vérification sautée porte sa raison. Issue non vérifiée : rien de plus.

`### En conclusion` : 2 ou 3 phrases. La version est stable ou non, et pourquoi. Ce qui reste à décider, ou « rien à faire ». Version de moins de 7 jours lus : nouvelle lecture proposée à J0 + 7, avec sa date.

## 6. Écrire

Issues concernées : les issues vérifiées sans note (§ 4, point 1), et celles en R2.

**Prérequis du tracker**, si au moins une issue n'a pas de ticket : accès et utilisateur (adaptateur § « Accès »), versions non publiées (adaptateur § « Lire les versions »).

**Version des Bugs créés** : un formulaire, une fois, avant le premier formulaire d'issue, si au moins une issue n'a pas de ticket. Options : les 3 premières versions non publiées du tracker en ordre `sort -V` de leur nom, placeholders et POC compris, puis « Backlog, sans version ». Aucune version non publiée : pas de formulaire, backlog. Le choix vaut pour tous les Bugs créés pendant le lancement.

**Un formulaire par issue**, le texte complet dans le `preview` :
- ticket qui suit l'issue (V2) : note « Suivi par <clé> » (recommandé), ou rien
- ticket lié seulement, ou aucun ticket : créer un `Bug` puis la note avec sa clé, note « En observation » sans ticket, ou rien. La recommandation suit la gravité : R1 ou R2 sur plusieurs utilisateurs, créer ; un seul utilisateur et une cause externe (mémoire, OS), observer. Erreur attendue dont la part est stable toutes issues confondues, observer. Un ticket lié est cité dans la note « En observation » et dans la description du Bug.

Une demande de modification (champ « Other ») : Claude corrige et repose le formulaire.

**Note Crashlytics** (`crashlytics_create_note`), 2 lignes au plus :

```text
Suivi par <clé> (<statut>). Lu le <JJ/MM> sur la <X.Y.Z> : <n> util. en <D> jours, <règle>.
En observation : <cause probable en une phrase>. Pas de ticket tant que <condition>.
```

**Bug créé** : adaptateur § « Créer un ticket », type `bug`, avec la version choisie, ou au backlog. Puis le commentaire « Analyse » (adaptateur § « Ajouter un commentaire »), puis la note Crashlytics avec la clé. Le statut du ticket reste tel quel.

Description (Markdown, lecteur : `tracker.reader`, titre sans nom de type ni de fichier) :

```markdown
# Origine
- Version <X.Y.Z>, prod, <n> occurrences, <n> utilisateurs en <D> jours
- Crashlytics : [issue <8 premiers caractères de l'issueId>](<lien>)

# Problème
<1 à 2 lignes : ce que l'utilisateur subit>
```

Commentaire « Analyse » :

```markdown
# Analyse (version-health)
## Événement
<appareil>, iOS <version>, mémoire libre <n> Mo, 5 derniers logs
## Code
<fichier fautif (V4) : ligne du blameFrame ou émetteur>, commits de la version sur ce fichier ou « aucun »
## Cause probable
<1 à 3 lignes>
```

Une écriture qui échoue arrête son issue. Le skill le dit et passe à l'issue suivante.

## 7. Fin

Efface la phase (`session-phase.sh --clear`). Dernière ligne de la réponse : les écritures faites (clés créées, notes posées), ou « aucune écriture ».
