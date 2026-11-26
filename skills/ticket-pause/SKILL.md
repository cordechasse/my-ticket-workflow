---
name: ticket-pause
description: Met en pause le ticket ou la chore de la branche courante, à tout moment, lot terminé ou non. Met à jour docs/tickets/<slug>/TICKET.md (statut, sujets, lots, tests) en contrôlant contre git, le compacte, puis propose les commits. À utiliser pour une pause, une sauvegarde de l'avancement ou avant un /clear.
---

# ticket-pause

Langue : français pour chaque texte visible, du premier au dernier message (FORMAT § « Langue »).

Lis d'abord `.claude/workflow/FORMAT.md` (racine du dépôt).

## 1. Localiser la session

Cherche `branch: <branche courante>` dans `docs/tickets/*/TICKET.md`, et lis ce fichier. Aucune session : propose `/ticket-start`, ou `/chore` sur une branche `chore/`, et arrête-toi. Trouvée dans `docs/tickets/*/STATE.md` seulement : ancien format, propose `/ticket-resume`, qui le convertit, et arrête-toi.

## 2. Collecter les sources

La mémoire de la conversation ne suffit pas. Récupère, pour le repo et chaque `related_repos` (avec son propre `last_commit`) :
- `git log --oneline <last_commit>..HEAD`
- `git status --short`, `git diff --stat` et `git diff --cached --stat`
- la liste de tâches de la conversation, si elle existe.

## 3. Mettre à jour

Dans `TICKET.md` :
- Frontmatter : `last_pause` = maintenant, `last_commit` = HEAD (et HEAD de chaque repo lié). `base` absent (session plus ancienne) : base a posteriori (RULES § « Base d'une branche a posteriori », avec les `origin/release/*` comme releases ouvertes et la version du ticket lue dans le tracker en cas d'égalité), puis écrite.
- « Statut » : réécrit entièrement (FORMAT § « Statut »). Le lot en cours peut être inachevé : « Prochaine action » donne l'étape et son état exact.
- « Sujets analysés » : sujets nouveaux, et `Remplacé par Sn.` sur ceux qui ont été renversés.
- « Lots » : étapes cochées. Lot terminé et commité : une ligne avec ses hashes, et le lot suivant reste à 1 ou 2 lignes jusqu'à son annonce. « Parcours » suit les mêmes marques.
- « Tests » : tests écrits ou à écrire, ceux qui passent cochés, résultats des tests manuels et de « Reproduction » (rejeux de flows, test unitaire rouge écrit).
- « Notes » : pièges nouveaux. Module `translations` : « Traductions » est tenue à jour dans tous les cas (FORMAT § « Traductions »).
- « Objectif et périmètre », « Contexte » : seulement si le périmètre ou l'existant a changé, toujours avec le sujet qui l'explique.

Puis compacte ce qui ne l'est pas encore (FORMAT § « Taille ») : sujet tranché, lot terminé, test manuel validé sauf `(recette)`.

## 4. Audit

Seconde passe, point par point, chaque manque corrigé :
- [ ] Chaque commit de `last_commit..HEAD` (tous repos) est dans la ligne d'un lot terminé, ou couvre une étape cochée du lot en cours.
- [ ] Chaque fichier modifié ou non suivi de `git status` est dans « En cours » de « Statut ».
- [ ] Chaque choix structurant de la conversation est dans « Sujets analysés », avec son pourquoi et les options écartées. Cherche activement : choix entre options, réponses de l'utilisateur, approches abandonnées, « on part sur… », revirements.
- [ ] Chaque test écrit ou évoqué est dans « Tests », chaque comportement nouveau a un test. Chaque flow de `maestro/` a son entrée dans « Reproduction ».
- [ ] Chaque erreur ou blocage qui a demandé plus d'un essai est dans « Pièges ».
- [ ] Chaque question sans réponse est dans « Questions ouvertes » de « Statut ».
- [ ] « Prochaine action » est exécutable par une session neuve qui n'a lu que `TICKET.md` (fichier, symbole, état, geste).
- [ ] Les lignes `/clear` et « Clôture » de « Statut » suivent leurs conditions (FORMAT § « Statut »).
- [ ] « Parcours » et « Lots » portent les mêmes marques `✓` et `▶`.
- [ ] Module `translations` : « Traductions » liste chaque clé du relevé du script lancé avec la base du ticket (FORMAT § « Traductions »). Chaque langue non traduite est « à traduire ».
- [ ] Les limites de FORMAT § « Taille » sont tenues. Sinon, le dépassement est signalé avec les sections qui pèsent le plus.

Annonce `Audit : N ajouts` avec la liste, ou `Audit : rien à ajouter`.

## 5. Résumé

3 lignes : où on en est, prochaine action, questions ouvertes.

## 6. Commits

`git status` propre (repo et `related_repos`) : dis `Rien à commiter`. Sinon, propose toujours les commits, même sans demande :
1. Découpage, un commit par sujet, au format de `docs/COMMITS.md` : le code et ses tests (un commit par changement cohérent), puis `TICKET.md` et `maestro/`, puis les autres fichiers de contexte (memories versionnées…).
2. Formulaire : découpage proposé, un seul commit, ou staging seulement.
3. Validé : commits de code d'abord. Puis, dans `TICKET.md`, remplace les « non commité » de « Statut » et de « Lots » par les hashes obtenus, et mets `last_commit` au dernier commit de code. Puis le commit `docs(ticket): pause, …`, puis les autres.

Procédure de commit : FORMAT § « Commits ». Aucun push. Termine par la liste des commits créés et le `git status` restant, et rappelle que `/clear` est possible.
