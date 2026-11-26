# CHANGELOG

Numéros au format `X.Y.Z`, fixés par la migration qu'une montée demande au projet :
- majeur : migration requise (clé de config obligatoire ou renommée, hook à déclarer, fichier
  local à écrire)
- mineur : ajout sans obligation
- correctif : aucun geste.

Chaque version a un tag annoté `vX.Y.Z`. Montée de version : README § « Montée de version ».

## 1.0.0 (non publiée)

### Changements
- Disposition à la racine : `skills/`, `workflow/`, `scripts/`, `hooks/`, `rules/`, `docs/`. Le
  paquet n'a plus de dossier `.claude/`.
- Intégration par `git subtree --squash` sous `.claude/vendor/my-ticket-workflow`, et liens
  relatifs depuis `.claude/` et `docs/` du projet. `sync.sh` et `.claude/workflow.lock` sont
  retirés.
- `.claude/settings.json` sort du paquet : le projet garde le sien, avec les entrées du README.
- `commit-msg-hook.sh` et `setup_claude_memory.sh` sont dans `scripts/`, donc sous
  `.claude/scripts/` du projet. `setup_claude_memory.sh` calcule la racine du projet par git.
- FORMAT § « Configuration » : règle « Contenu du paquet », aucune valeur d'un projet.

### Migration
Depuis une copie installée par `sync.sh` :
1. Supprimer les copies du paquet, `.claude/scripts/sync.sh` et `.claude/workflow.lock`.
2. Sortir des dossiers liés chaque fichier local : un script local de `.claude/scripts/` va dans
   `scripts/` du projet, une règle locale reste dans `.claude/rules/`, hors de `paquet/`.
3. Ajouter le paquet : README § « Installation », étapes 1 et 2.
4. Remplacer `scripts/commit-msg-hook.sh` par `.claude/scripts/commit-msg-hook.sh` dans
   l'installation du projet (copie dans `.git/hooks/commit-msg`).
5. Comparer `.claude/settings.json` aux entrées du README.
