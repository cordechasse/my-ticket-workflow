# Règles de branches et de versions

Référence partagée par `ticket-start`, `ticket-close` et les skills `version-*` : une règle se modifie ici seulement.

Les commandes se lancent depuis la racine du dépôt, dans l'outil Bash. Les variables shell ne survivent pas à l'appel : affiche les chemins créés (`echo`) et recopie-les dans les appels suivants. Une session entrée dans un worktree n'accepte qu'une commande git simple par appel (`.claude/workflow/FORMAT.md` § « Worktree ») : les blocs de ce fichier s'y lancent alors une commande git par appel.

## Lire l'état

**Git** : avant toute lecture de branche ou de tag, en un seul appel :

```bash
git fetch --prune origin && git fetch --tags --force origin
```

- `--prune` : une `release/*` supprimée sur origin ne compte plus comme ouverte.
- `--tags --force` : la CI peut déplacer un tag, et un fetch simple laisserait un tag local sur son ancien commit.
- Les branches se lisent sur `origin/<branche>` : le local peut être en retard, ou en avance d'une fusion non poussée.

**Tracker** (adaptateur `tracker-<tracker.provider>`, FORMAT § « Configuration ») : versions non publiées (§ « Lire les versions »), version d'un ticket (§ « Lire un ticket »).

**Versions publiées** (adaptateur `published-<releases.published>`, § « Lire les versions publiées ») : une fois par exécution du skill. Le résultat est un fichier JSON, noté `$versions` dans les blocs de ce fichier :

```json
{"versions": [{"version": "X.Y.Z", "build": "<numéro>", "published": true}]}
```

- `jq -c '.versions[]' "$versions"` le liste. L'adaptateur peut ajouter d'autres champs.
- Échec de la lecture : arrêt, avec son message. Aucune autre source ne la remplace.

## Versions

**Tags de build** : gabarit `releases.build_tag`. `{version}` vaut `X.Y.Z`, ou `X.Y.Z-poc.<nom>` pour un build POC, `{build}` le numéro de build, et `{environment}`, facultatif, vaut `staging` ou `prod`. Un tag qui contient `-` est un tag POC : il n'entre dans aucune règle de version, hors § « POC ».

**Version du ticket** : la version du tracker à laquelle le ticket est rattaché, une seule (adaptateur § « Lire un ticket »).

**Version du tracker** : elle porte un numéro `X.Y.Z` et un but. Le nom qui les porte dépend du service (adaptateur § « Nom d'une version »).
- Une **version POC** regroupe les tickets d'un POC et ne reçoit jamais de numéro (§ « POC »).
- Une version sans numéro, hors POC, est un **placeholder**. Un ticket peut démarrer dessus, depuis la release ouverte la plus récente, mais pas être intégré. Le placeholder devient une version quand on le renomme avec son numéro : il garde son id et ses tickets, sans deuxième version à côté.
- Les numéros se comparent en ordre de version (`sort -V`), jamais en ordre alphabétique : 2.9.0 < 2.10.0.

**Tag de build prod** : tag de build avec `{environment}` = `prod`, ou chaque tag de build quand le gabarit n'a pas `{environment}` (une seule lane : chaque build est candidat à la prod). C'est une Release Candidate, que le lecteur valide ou refuse : il ne prouve pas la publication.

**Version publiée** : `published` vrai dans `$versions` (§ « Lire l'état »). Le numéro est consommé : tout correctif part en X.Y.(Z+1). Seule la source `releases.published` fait foi, ni un tag ni le statut de la version du tracker.

```bash
jq -e --arg v X.Y.Z 'any(.versions[]; .version == $v and .published)' "$versions" >/dev/null   # vrai = publiée
```

Tant que la version n'est pas publiée, sa release reste en recette : le correctif d'une RC refusée, par le lecteur ou par le store, y est fusionné et repart sous le même numéro.

**Build publié** : `build` de la version publiée dans le JSON. Son tag, le **tag du build publié** (`{version}` = X.Y.Z, `{build}` = ce build, `{environment}` = `prod` si le gabarit le contient), est le point de départ du hotfix, et non le dernier tag de build prod, qui peut être une RC jamais publiée.

**Release ouverte** : `origin/release/X.Y.Z` existe et la version X.Y.Z n'est pas publiée. Une `release/*` dont la version est publiée est une branche historique.

```bash
for b in $(git branch -r --list 'origin/release/*' --format='%(refname:short)'); do
  v=${b#origin/release/}
  jq -e --arg v "$v" 'any(.versions[]; .version == $v and .published)' "$versions" >/dev/null || echo "$v"
done
```

Plusieurs releases ouvertes en même temps sont un état normal : une version en recette pendant que la suivante avance, ou un hotfix (§ « Releases en parallèle »).

**Version ouverte** : version dont la release est ouverte. Elle y reçoit ses tickets, de son premier ticket à sa clôture, recette comprise.

**Ligne hotfix** : version X.Y.Z avec Z > 0 alors qu'une version X.Y.* est déjà publiée, et qu'aucune release X.Y.* de version inférieure à X.Y.Z n'est ouverte.

```bash
jq -e --arg p X.Y. 'any(.versions[]; (.version | startswith($p)) and .published)' "$versions" >/dev/null   # vrai = une version X.Y.* est publiée
```

Une release X.Y.* inférieure encore ouverte sort avant X.Y.Z, qui doit la contenir : X.Y.Z est alors une version à ouvrir, et sa release part de la plus haute de ces releases (§ « Créer une release »). Exemple : 1.4.1 publiée, `release/1.4.2` en recette, version du ticket 1.4.3. `release/1.4.3` part de `release/1.4.2`, et non du tag publié de la 1.4.1.

**Version à ouvrir** : version du tracker numérotée, ni publiée, ni ouverte, ni ligne hotfix. Sa release se crée au démarrage de son premier ticket (§ « Base d'un ticket selon sa version »). Un skill n'invente jamais de version : sans version dans le tracker, renvoi vers `version-start`.

## Rôle de `develop`

`develop` reçoit seulement les branches `chore/` (outillage) et les releases fermées (`version-close`). Aucun ticket n'y est fusionné : chaque version vit dans sa release. `develop` porte donc le code de la dernière version publiée, plus l'outillage.

Les outils de build, les scripts et les skills tournent depuis la release : après la fusion d'une chore, chaque release ouverte est en retard sur `develop`. Elle la reçoit quand une session la touche, build compris (§ « Mise à jour d'une base »).

`releases.closed_release_also_into`, si la clé nomme une branche (`main` quand elle est la branche par défaut de la forge), reçoit aussi chaque release fermée, après `develop` (`version-close`), pour porter la dernière version publiée. Aucun autre skill n'y écrit.

## Releases en parallèle

Une release reçoit les releases ouvertes de version inférieure, dans ce sens seulement, jamais l'inverse :
- à sa création : elle part de la release ouverte la plus haute de version inférieure (§ « Créer une release »)
- ensuite, quand une session touche sa version : `ticket-start` ou `ticket-resume` d'un de ses tickets, son build staging. La fusion est alors proposée (§ « Mise à jour d'une base »).

Travailler sur la version n ne touche jamais la n+1 : `ticket-close` d'un ticket de n fusionne seulement dans `release/n`, `version-close` de n seulement dans `develop` (et `releases.closed_release_also_into`). Une release fermée arrive dans les releases supérieures par `develop`, à leur prochaine mise à jour.

Exemple : ticket A en 1.4.2, ticket B en 1.5.0. A est démarré puis clôturé : son code arrive dans `release/1.4.2` seulement. Au démarrage ou à la reprise de B, `release/1.5.0` est en retard sur `release/1.4.2` : la fusion est proposée. Puis, si `feature/B` existe déjà, elle est en retard sur `release/1.5.0` : sa fusion est proposée aussi.

## Mise à jour d'une base

Quand une session touche une version (`ticket-start`, `ticket-resume`, le skill de build staging), elle propose de mettre sa base à jour avant le travail. Chaque fusion se propose à part, avec sa source, sa cible et le nombre de commits apportés. Elle n'est jamais imposée : refusée, rien ne change et la question revient la fois suivante.

1. **Base**, à jour de ses sources (`git fetch --prune origin` fait) :
   - `release/X.Y.Z` : chaque release ouverte de version inférieure (`sort -V`), puis `develop`
   - `poc/<nom>` : sa release de référence (§ « POC »).

   Une source est en retard quand `git merge-base --is-ancestor origin/<source> origin/<base>` échoue. Fusion : § « Fusion entre branches longues ».
2. **Branche du ticket**, après la base : retard = `git rev-list --count HEAD..origin/<base>`, avec les fusions de tickets apportées (`git log --oneline --first-parent HEAD..origin/<base>`, 5 au plus). Fusion, dans le checkout de la branche, working tree propre : `git merge --no-ff origin/<base> -m "Merge branch '<base>' into <branche> #<clé>"`. Conflit : arrêt, fichiers présentés, l'utilisateur résout ou annule (`git merge --abort`). Au démarrage d'un ticket, la branche part de la base à jour : rien à faire.

## Confirmation des numéros

Tout numéro de version déterminé par un skill (version du ticket, ouverture d'une release, hotfix, report de tickets) est soumis à l'utilisateur dans un formulaire à choix (AskUserQuestion) : les candidats calculés, le recommandé en premier. Aucune écriture, git ou tracker, avant la réponse.

## Onglet herdr et phase

Chaque skill `version-*`, et chaque skill sans version (point « Skill sans version »), montre son travail dans l'onglet herdr et dans la status line. Son en-tête « Onglet et phase » donne son `<action>` (`start`, `hotfix`, `staging`, `prod`, `close` ou `version-health`), l'étape où sa version est confirmée et le nom de chaque étape. `<version>` vaut `X.Y.Z`, ou `poc-<nom>` pour un build POC.

- **Phase** : au début de chaque étape listée, `.claude/scripts/session-phase.sh "<action> : <étape>"` tant que la version n'est pas confirmée, puis `"<action> <version> : <étape>"`.
- **Onglet**, au début de l'étape 1, avant tout formulaire : `.claude/scripts/herdr-tab.sh "<action>-<version>"` si `$ARGUMENTS` donne la version, sinon `"<action>"`. Version confirmée (§ « Confirmation des numéros ») différente de ce nom : nouveau renommage `"<action>-<version>"`, puis la phase de l'étape en cours réécrite avec la version. Le nom de l'onglet reste après le skill : le prochain `ticket-start`, `chore`, `ticket-resume` ou `ticket-close` le remplace.
- **Lieu** : les deux scripts se lancent depuis la racine du dossier de la session, quelle que soit sa branche, jamais dans `<dir>` où le skill fusionne ou builde. La phase est rangée par session : une autre session du même dossier ne la voit pas.
- **Effacement** (`session-phase.sh --clear`) : au début de l'étape « Fin », et à chaque arrêt, quelle qu'en soit la cause (refus d'un contrôle, formulaire refusé, échec du build ou de la fusion).
- **Appel par un autre skill** : `version-start` appelé par `version-hotfix` ne renomme pas l'onglet, n'écrit et n'efface aucune phase, même à son arrêt ou à sa fin. La phase `hotfix <version> : version du tracker` reste affichée, et le hotfix gère la suite.
- **Skill sans version** (skills du support, par exemple) : onglet `<action>`, du début à la fin, sans renommage. Phase `.claude/scripts/session-phase.sh "<étape>" "<action>"` : l'action, passée comme nom court, remplace la branche et la session de ticket dans la status line (`<action> │ <étape>`), car le travail du skill n'a pas de lien avec la branche. Son en-tête « Onglet et phase » donne son `<action>` et ses étapes. Sa dernière étape garde sa phase jusqu'à sa fin, puis l'efface. Les autres points s'appliquent tels quels.

Échec d'un script, script absent, phase restée d'une conversation coupée : FORMAT § « Nom court, onglet herdr et simulateur » et § « Phase dans la status line » (`.claude/workflow/FORMAT.md`). Ni l'un ni l'autre ne bloque le skill.

## Checkout d'une branche

Les skills laissent le checkout de l'utilisateur sur sa branche. Une fusion ou un build sur une branche se fait là où elle est extraite :

```bash
held() { git worktree list --porcelain | awk -v b="branch refs/heads/$1" '/^worktree /{d=substr($0,10)} $0==b{print d}'; }
held <branche>
```

La fonction se déclare dans le même appel Bash que son usage. Aucune sortie : la branche n'est extraite nulle part, le skill dit alors comment procéder (worktree temporaire, ou arrêt).

## Créer une release

Sert à `ticket-start` (premier ticket d'une version à ouvrir) et à `version-hotfix` (base : tag du build publié). Tout se passe dans un worktree temporaire, retiré à la fin.

**Base** pour `ticket-start` : `origin/release/V`, V étant la plus haute release ouverte de version inférieure à X.Y.Z (`sort -V`), sinon `origin/develop`. Partir de la release inférieure évite un conflit sur la ligne de version (`releases.version_line` dans `releases.version_file`) aux fusions suivantes, car elle ne change plus cette ligne.

**Contrôles**, refus au premier qui s'applique :
- `release/X.Y.Z` existe en local (`git rev-parse -q --verify refs/heads/release/X.Y.Z`) : branche d'une ancienne tentative, à pousser ou supprimer d'abord
- X.Y.Z publiée (§ « Versions », « Version publiée ») : numéro consommé, renvoi vers `version-hotfix`.

Avertissement, sans arrêt : une version à ouvrir plus basse que X.Y.Z existe. Ouverte plus tard, elle partira de la même base que X.Y.Z, et sa fusion dans `release/X.Y.Z` donnera un conflit sur la ligne de version.

**Confirmation**, un seul formulaire avant toute écriture : version, base (sha court, sujet, date), commit de bump `chore(release): X.Y.Z` (ligne de version) et push sur origin. Il vaut accord pour la création et pour le push. Refus : rien n'est créé.

**Branche et bump**, en un seul appel Bash, `file` et `line` recopiés de `releases.version_file` et `releases.version_line`. Une ligne de version commence par `line`, après une indentation éventuelle, et porte le numéro en chiffres et en points. Le fichier peut en contenir plusieurs (une par configuration de build). Le bump remplace le numéro de chacune et garde la suite de la ligne (`;`, commentaire). Il échoue si le fichier n'a aucune ligne de version, ou si l'une d'elles ne porte pas la nouvelle version (numéro écrit autrement qu'en chiffres) :

```bash
v=X.Y.Z base=<base> file='<releases.version_file>' line='<releases.version_line>'
wt=$(mktemp -d -t "release-$v")
git worktree add -q --no-track -b "release/$v" "$wt" "$base"
sed -i '' -E "s/^([[:space:]]*${line})[0-9]+(\.[0-9]+)*/\1${v}/" "$wt/$file"
all=$(rg -c "^[[:space:]]*${line}" "$wt/$file"); new=$(rg -c "^[[:space:]]*${line}${v}([^0-9.]|$)" "$wt/$file")
[ -n "$all" ] && [ "$all" = "$new" ] || { echo "ÉCHEC : ligne de version non mise à jour"; exit 1; }
git -C "$wt" commit -q -am "chore(release): $v"
echo "wt=$wt"; git -C "$wt" log -1 --stat --format='%h %s'
```

Le diff touche le fichier de version seul. Sinon, ou en cas d'échec : retire le worktree et la branche locale (`git worktree remove --force "$wt"`, `git branch -D "release/$v"`), et arrête-toi.

**Push**, couvert par la confirmation, en un seul appel :

```bash
git -C "$wt" push -u origin "release/$v"
git fetch -q origin "release/$v"
[ "$(git -C "$wt" rev-parse HEAD)" = "$(git rev-parse "origin/release/$v")" ] && echo "release identique sur origin" || echo "ÉCHEC : origin/release/$v diffère du commit de bump"
git worktree remove "$wt"
```

Le build staging part de `origin/release/X.Y.Z` : le contrôle vérifie que la release poussée porte le commit de bump. Échec : signale-le, avec les deux sha.

Push refusé : retire le worktree (`git worktree remove "$wt"`). La branche locale reste, non poussée : indique comment la pousser (`git push -u origin release/X.Y.Z`) ou la supprimer (`git branch -D release/X.Y.Z`).

## Fusion entre branches longues

Sens autorisés, et aucun autre :
- `develop` dans une release ou dans un POC
- une release dans une release supérieure ou dans un POC
- une release fermée dans `develop` (`version-close`).

Un POC n'est jamais fusionné ailleurs, ni dans `develop` ni dans une release. Une release n'est jamais fusionnée dans une release inférieure. Une branche de ticket suit FORMAT § « Fusion ».

Chaque fusion est proposée avec sa source, sa cible et les commits apportés (`git log --oneline origin/<cible>..<source>`). L'accord vaut pour la fusion et le push.

1. Checkout de la cible (§ « Checkout d'une branche ») :
   - extraite dans un dossier : `<dir>` = ce dossier, working tree propre, sinon arrêt
   - extraite nulle part : worktree temporaire, `wt=$(mktemp -d -t merge-<cible sans />) && git worktree add -q "$wt" <cible> && echo "wt=$wt"`, `<dir>` = ce chemin. Sans branche locale, git la crée depuis `origin/<cible>`.

   La cible locale n'est pas en avance sur origin (`git -C <dir> rev-list --count origin/<cible>..<cible>` à 0), sinon arrêt : le push embarquerait ces commits.
2. Fusion, `<source>` = `origin/<branche source>`, ou son sha quand elle va être supprimée (`version-close`) :
   ```bash
   git -C <dir> pull -q --ff-only origin <cible>
   git -C <dir> merge --no-ff <source> -m "Merge branch '<branche source>' into <cible>"
   git -C <dir> log -1 --format='%h %p %s'
   ```
   Message de git pour une fusion de branche, sans clé de ticket. Le commit a deux parents.
3. Conflit : arrêt, fichiers présentés, la résolution revient à l'utilisateur. Dans son checkout, la fusion reste en cours, à résoudre ou à annuler (`git -C <dir> merge --abort`). Dans un worktree temporaire : `git -C "$wt" merge --abort`, puis `git worktree remove --force "$wt"`, et la fusion est à refaire à la main avec la même commande. Un conflit sur la ligne de version (`releases.version_file`) est attendu quand les deux branches ont changé la version (hotfix, release qui n'est pas la base de la cible) : la cible garde la sienne.
4. Push : `git -C <dir> push origin <cible>`, puis `git worktree remove "$wt"` pour un worktree temporaire. Push refusé : la fusion reste locale, chemin affiché, arrêt.

## POC

Module `poc` (FORMAT § « Configuration »). Sans lui : ni version POC, ni branche `poc/*`, ni build POC. Chaque règle de ce fichier et chaque étape de skill propre à un POC sont sans objet.

Un POC est une release particulière : une version POC du tracker, une branche d'intégration `poc/<nom>`, des builds staging, tagués avec `{version}` = `X.Y.Z-poc.<nom>` (§ « Versions »), jamais promus en prod.

**Nom** : `<nom>` est un seul identifiant SemVer (lettres, chiffres, tirets), le même pour la branche, le build staging du POC et les tags (`nouvelle-carte`).

**Version POC** : sa description dans le tracker contient le nom de sa branche, `poc/<nom>`. C'est le lien que lisent `ticket-start` et le skill de build staging. Elle ne reçoit jamais de numéro, et `version-start` ne la propose pas au renommage.

**Branche `poc/<nom>`** : même rôle qu'une `release/X.Y.Z`.
- Elle reçoit les tickets de sa version POC, en `--no-ff`, et, pour se mettre à jour, sa release de référence.
- Elle n'est jamais fusionnée dans `develop` ni dans une `release/*`, et jamais supprimée sur origin : les tags POC sont posés sur ses commits.

**Release de référence d'un POC** : la release ouverte la plus récente (`sort -V`). Plusieurs releases ouvertes : formulaire parmi elles, la plus récente en premier, à chaque création, mise à jour ou build du POC. Aucune release ouverte : `develop`.

**POC d'un ticket** : version POC du ticket, dont la description se lit avec le ticket (adaptateur § « Lire un ticket »).
- Description `poc/<nom>` et `origin/poc/<nom>` existe : c'est le POC du ticket.
- Description vide, ou sans branche sur origin : formulaire parmi les `origin/poc/*`, plus « Nouveau POC ». Le choix est écrit dans la description de la version après un « oui » (adaptateur § « Créer ou modifier une version »).
- Nouveau POC : nom demandé dans un formulaire, puis, après un « oui » avec base et nom affichés, `poc/<nom>` créée depuis `<base>`, sa release de référence (`origin/release/X.Y.Z`, ou `origin/develop`), et poussée (`git branch --no-track poc/<nom> <base> && git push -u origin poc/<nom>`), puis la description écrite.

**Version Apple d'un build POC** : la ligne de version reste au format `X.Y.Z` imposé par Apple. Le POC existe seulement dans le tag et dans les textes du build (libellé de version affiché par l'app, notes de test). Le numéro est celui de la release de base du POC :
1. Base : la release de référence du POC. Fusionnée dans `poc/<nom>`, elle lui apporte son numéro, sans commit de bump.
2. Aucune release ouverte : fusion de `develop` dans `poc/<nom>`, puis commit `chore(poc): version X.Y.Z` sur le fichier de version, X.Y.Z étant la plus basse version à ouvrir (§ « Versions »). La création de `release/X.Y.Z` écrit la même ligne : pas de conflit à la fusion suivante.
3. POC en retard sur sa release de base (`git rev-list --count origin/poc/<nom>..origin/release/X.Y.Z` non nul) : signalé avec le nombre de commits, fusion proposée, build sans fusion possible.
4. Version du POC publiée (§ « Versions ») : refus du build, avec la proposition 1 ou 2.

Les fusions et le commit de bump se font là où `poc/<nom>` est extraite (§ « Checkout d'une branche »), et se poussent après un « oui » : la lane refuse un HEAD absent d'origin.

## Base d'un ticket selon sa version

Le ticket a une seule version. S'il n'en a aucune ou plusieurs, proposer les candidats dans un formulaire : chaque version ouverte, puis chaque version à ouvrir, puis chaque version POC, chaque groupe en ordre `sort -V`. Sans choix, pas de branche.

Dans cet ordre :

| Version du ticket | Base | Message |
|---|---|---|
| Version POC | `poc/<nom>` (§ « POC ») | |
| Placeholder | release ouverte la plus récente, sinon `develop` | Avertissement : le ticket ne pourra pas être intégré tant que la version n'a pas de numéro |
| Version publiée | aucune, arrêt | Renvoi vers `version-hotfix` : le correctif part dans une nouvelle version X.Y.(Z+1) |
| Version ouverte | `release/X.Y.Z` | |
| Ligne hotfix sans release | aucune, arrêt | Renvoi vers `version-hotfix` : la release part du build publié |
| Version à ouvrir, plus basse qu'une version ouverte | aucune, arrêt | Version en suspens ou version du ticket à corriger : demander |
| Version à ouvrir | `release/X.Y.Z`, créée après accord (§ « Créer une release ») | Création refusée : pas de branche |

La branche se crée depuis `origin/<base>`.

## Base d'une branche a posteriori

Retrouve la base d'une branche de ticket déjà créée. On compare les **points de départ** contre `develop`, contre chaque release ouverte et contre chaque `origin/poc/*`, car la pointe d'une base cesse d'être ancêtre de la branche dès qu'un autre ticket y est intégré :

```bash
branch=<branche du ticket>
git rev-parse -q --verify "$branch" >/dev/null || branch="origin/$branch"
printf '%s %s\n' develop "$(git merge-base origin/develop "$branch")"
for v in <versions des releases ouvertes>; do
  printf '%s %s\n' "release/$v" "$(git merge-base "origin/release/$v" "$branch")"
done
for p in $(git branch -r --list 'origin/poc/*' --format='%(refname:short)'); do
  printf '%s %s\n' "${p#origin/}" "$(git merge-base "$p" "$branch")"
done
```

- On retient le candidat dont le point de départ descend de tous les autres (`git merge-base --is-ancestor <autre> <candidat>`).
- **Égalité** : plusieurs candidats ont le même point de départ. C'est le cas d'une branche partie d'une release qui n'a rien reçu depuis (premier ticket d'une version, premier correctif d'un hotfix), d'une branche partie d'une release fusionnée depuis dans une release supérieure, et d'une branche partie de `develop` fusionnée depuis dans une release. La version du ticket départage, jamais un repli par défaut sur `develop`. Une version du ticket qu'aucun candidat ne porte (placeholder, version à ouvrir) départage vers la release la plus récente parmi les candidats à égalité, sinon vers `develop`.

## Cohérence base et version à l'intégration

La version du ticket est celle que porte la base :
- `release/X.Y.Z` porte X.Y.Z
- `poc/<nom>` porte la version POC dont la description la nomme (§ « POC »)
- `develop` ne porte aucune version : seules les branches `chore/` y sont intégrées (§ « Rôle de `develop` »).

Tout écart arrête l'intégration, avec l'écart expliqué et les sorties possibles. Rien n'est écrit, ni dans git ni dans le tracker, sans accord. Une sortie qui écrit se fait après un « oui », puis le contrôle reprend :

| Écart | Sorties |
|---|---|
| Version du ticket placeholder | Donner son numéro à la version dans le tracker (`version-start`), ou changer la version du ticket, ou garder la branche en attente |
| Version du ticket POC, branche partie d'une autre base | Déplacer les seuls commits du ticket sur le POC : `git rebase --onto origin/poc/<nom> <base>`, affiché, jamais exécuté |
| Branche partie de `poc/<nom>`, version du ticket non POC | La fusion embarquerait le code du POC : changer la version du ticket pour la version POC, ou refaire la branche depuis sa base avec les seuls commits du ticket (`cherry-pick`) |
| Base `release/X.Y.Z` devenue publiée | Correctif à refaire en hotfix (`version-hotfix`), puis branche déplacée sur la nouvelle release |
| Version du ticket à ouvrir, sans release | Créer la release (§ « Créer une release ») |
| Branche partie de `develop`, version du ticket ouverte | Fusionner `develop` dans `release/X.Y.Z` (§ « Fusion entre branches longues ») : elle n'apporte que des chores et des clôtures, et la base devient la release par égalité |
| Branche partie d'une release inférieure à la version du ticket | Fusionner cette release dans `release/X.Y.Z` (§ « Fusion entre branches longues »), ce que la règle des releases en parallèle prévoit déjà : la base devient la release par égalité |
| Branche partie d'une release supérieure à la version du ticket | La fusion embarquerait le contenu de la version supérieure : déplacer les seuls commits du ticket (`git rebase --onto origin/release/X.Y.Z <base>`, affiché, jamais exécuté), ou changer la version du ticket |

La version du ticket se change sur décision de l'utilisateur ou du lecteur, jamais pour rendre une fusion possible : ce serait livrer le travail dans la mauvaise version.

## Ticket intégré sur une ref

**Branche du ticket**, locale ou distante :

```bash
p='<tracker.key_prefix>' n=<numéro>
git branch -a --list "*${p}${n}[_-]*" "*${p}${n}"
```

Accolades obligatoires sous zsh : `$n[_-]` y serait un indice de tableau.

Si elle existe encore, le ticket est intégré sur `<ref>` quand la pointe de la branche est ancêtre de `<ref>` (`git merge-base --is-ancestor <branche> <ref>`). Cette règle couvre un ticket rouvert, dont les anciens commits portent déjà la clé.

Sinon, chercher la clé dans le **sujet** des commits, car les corps citent souvent d'autres tickets :

```bash
git log <ref> --format='%H %s' | rg -e '#<clé>([^0-9]|$)'
```

- La borne après le numéro est obligatoire : sans elle, `#APP-136` trouve aussi 1360 à 1369.
- Retirer les reverts : un sujet qui commence par `Revert "`, et tout commit annulé plus loin (`git log <ref> --grep='This reverts commit <sha complet>' --format=%h` renvoie quelque chose).
- Aucun commit restant : non intégré.

## Statuts

Statuts logiques, dans l'ordre où un ticket avance. Leur valeur dans le service est `tracker.states.<statut>`, et l'adaptateur `tracker-<tracker.provider>` § « Écrire un statut » dit comment la poser.

| Statut | Posé par |
|---|---|
| (initial) | création du ticket |
| `en-cours` | `ticket-start` |
| `a-livrer` | `ticket-close`, au push d'une fusion directe (dans une `release/*` ou un `poc/<nom>`), après le commentaire au lecteur, ou à une clôture sans correctif (statut « Rien à faire ») |
| `dans-un-build` | le skill de build staging, après le statut `Dispo dans la version X.Y.Z+N` (build POC : `X.Y.Z-poc.<nom>+N`), ou `Aucune modification de l'app dans la version X.Y.Z+N` pour un ticket sans commit hors `docs/` |
| `fait` | à la main, par la personne qui valide |

- Un skill fait seulement avancer un ticket, dans l'ordre du tableau. Un ticket déjà au statut visé, ou plus loin, reste tel quel. Un retour en arrière (refus en recette, renvoi en `en-cours`) se fait à la main.
- Un build ne fait avancer que les tickets de sa version : ceux arrivés par la fusion d'une autre branche longue (release inférieure dans une release, release ou `develop` dans un POC) restent tels quels.

**Écrire dans un ticket**, dans cet ordre (gestes : adaptateur § « Écrire un statut ») :
1. Commentaire, sauf si le ticket a déjà un commentaire au texte identique : lis ses commentaires d'abord.
2. Statut.

Le commentaire passe d'abord : une relance rattrape un commentaire manqué sans le doubler, alors qu'un ticket qui a déjà changé de statut peut sortir de la recherche qui le retrouvait.

**Remplacer un statut**. Le commentaire de clôture de `ticket-close` commence par un paragraphe `# Statut` suivi d'une ligne de texte. Son cycle :

```text
En attente de livraison ──▶ Dispo dans la version X.Y.Z+N ──▶ Publié dans la X.Y.Z
     ticket-close             skill de build staging           version-close
```

Un ticket clos sans correctif garde le statut « Rien à faire » : il n'a aucun commit dans les builds, et `version-close` ne le remplace pas.

Gestes de lecture et de réécriture : adaptateur § « Remplacer la ligne de statut ».
1. Commentaire de clôture : le plus récent dont le corps commence par `# Statut`.
2. Trouvé : remplace seulement la ligne de texte qui suit `# Statut`, puis réécris le corps entier. Le reste du corps ne change pas. Statut déjà au texte visé : rien.
3. Absent (ticket clos avant ce format, ou commentaire à la main) : ajoute un commentaire séparé au texte du statut, sauf si un commentaire au texte identique existe déjà.

## Contenu d'une release

`release/X.Y.Z` reçoit les tickets de version X.Y.Z, `develop` (chores et clôtures) et les releases ouvertes de version inférieure (§ « Releases en parallèle »). Une fonctionnalité d'une autre version n'y entre pas : sa branche part de la release de sa propre version du ticket. Avant la fusion, un report vers une version supérieure demande seulement de changer la version du ticket, car la release supérieure contient l'inférieure. Un report vers une version inférieure demande de déplacer les commits du ticket (§ « Cohérence base et version à l'intégration »). Après la fusion, la fonctionnalité part avec la version qui l'a reçue.
