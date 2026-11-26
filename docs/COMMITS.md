# Messages de commit

Format [Conventional Commits 1.0.0](https://www.conventionalcommits.org/fr/v1.0.0/), description en français.

```
<type>(<scope>): <description> #<clé>

<corps : le pourquoi, ce qui n'est pas visible dans le diff>
```

`<clé>` : la clé du ticket, `tracker.key_prefix` de `.claude/workflow.yml` suivi du numéro (`APP-1234` pour un préfixe `APP-`, `42` pour un préfixe vide).

Le hook `commit-msg` (installé à la mise en place du projet, WORKFLOW § 7) vérifie le sujet. Il refuse le commit si le sujet dépasse 72 caractères, clé du ticket exclue : git ne crée pas le commit, et le staging reste en place. Pour les autres écarts, il affiche un avertissement et garde le commit.

## Sujet

- `type` obligatoire, dans la liste ci-dessous.
- `scope` optionnel, libre, en minuscules : zone de l'app ou de l'outillage (`sync`, `profile`, `ticket`, `claude`, `release`…).
- `!` après le scope pour un changement incompatible (migration de données sans retour, rupture de compatibilité avec l'API) : `feat(sync)!: …`. Un footer `BREAKING CHANGE: …` en fin de message en explique l'impact.
- Description à l'infinitif, en minuscule, sans point final : `corriger…`, `ajouter…`, `ne plus mettre…`.
- 72 caractères au plus, clé du ticket exclue. Le détail (versions d'iOS concernées, écrans touchés, cause) va dans le corps.
- Clé du ticket en fin de sujet, `#<clé>`, sur tout commit d'une branche de ticket. Une branche d'outillage sans ticket (`chore/…`) n'en a pas. Les skills retrouvent par elle les commits d'un ticket (`.claude/workflow/RULES.md` § « Ticket intégré sur une ref »). Avec des issues GitHub (préfixe vide), `#42` devient aussi un lien vers l'issue.

## Types

| Type | Usage |
|---|---|
| `feat` | Comportement ajouté ou modifié, visible par l'utilisateur |
| `fix` | Correction d'un bug ou d'un crash |
| `perf` | Gain de performance, sans changement de comportement |
| `refactor` | Restructuration du code, sans changement de comportement |
| `style` | Mise en forme seule (indentation, ordre des imports) |
| `test` | Tests seuls (unitaires, Maestro, fichiers d'essai) |
| `docs` | Commentaires de code, `docs/`, fichiers de session `docs/tickets/`, memories `.claude/context/` |
| `build` | `Package.swift`, réglages du projet Xcode, dépendances, scripts de build |
| `ci` | CI, lanes et scripts de release |
| `chore` | Version de l'app, outillage (Makefile, hooks git, skills Claude) |
| `revert` | Annulation d'un commit précédent |

Un commit qui mêle deux types se découpe en deux commits.

## Corps

- Séparé du sujet par une ligne vide, lignes de 72 caractères environ.
- Explique le pourquoi et les répercussions : cause du bug, choix écarté, versions d'iOS concernées, rendu inchangé ailleurs.
- Ne renvoie pas à la spec du ticket (lots, `D-0xx`, scénarios) : le message doit se lire sans les fichiers de session, supprimés à la clôture.
- Optionnel pour un commit dont le sujet suffit.
- Issues GitHub : aucun mot-clé de fermeture (`Closes #<n>`, `Fixes #<n>`). GitHub fermerait l'issue à l'arrivée du commit sur la branche par défaut, hors du cycle des skills : une issue se ferme à la main, après la recette.

## Commits des sessions de ticket

| Commit | Sujet |
|---|---|
| Démarrage | `docs(ticket): démarrage, <sujet du ticket> #<clé>` |
| Pause | `docs(ticket): pause, <avancement> #<clé>` |
| Lot de code | `feat`, `fix`… selon le contenu, scope de la zone touchée |
| Clôture | `docs(ticket): clôture, <sujet du ticket> #<clé>` |

`<sujet du ticket>` résume le ticket en peu de mots : ce n'est pas le titre du ticket recopié. Avec le préfixe, il tient dans les 72 caractères (47 pour un démarrage, 49 pour une clôture).

Une session de chore (branche `chore/`, sans ticket) a les mêmes sujets, sans clé.

## Hors convention

- Commits de fusion : `.claude/workflow/FORMAT.md` § « Fusion » (`Merge branch '<branche>' into <cible> #<clé>`, sans clé pour une branche `chore/`).
- `Revert "…"`, `fixup!`, `squash!` et `amend!` générés par git.

## Exemples

```
fix(sync): ne plus perdre les modifications faites hors ligne #APP-1240

Une synchronisation lancée au retour du réseau écrasait les modifications locales.
```

```
feat(settings): ajouter le mode sombre #42

Réglage Clair, Sombre ou Système. Par défaut : Système.
```

```
build: désactiver le cache de compilation en Debug
```

```
chore(release): 1.4.2
```
