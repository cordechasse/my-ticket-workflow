#!/usr/bin/env bash
#
# Hook commit-msg : vérifie le message au format de docs/COMMITS.md.
# Refuse un sujet trop long (sortie 1), pour qu'il se corrige avant le commit et jamais par
# un `git commit --amend`. Les autres écarts avertissent seulement (sortie 0).
# Usage : commit-msg-hook.sh <fichier du message>

# Longueur en caractères (et non en octets) des sujets accentués, même lancé depuis un client git sans locale.
# Un poste Linux sans `en_US.UTF-8` a toujours `C.UTF-8`.
if locale -a 2>/dev/null | grep -qiE '^en_US\.utf-?8$'; then
	export LC_ALL=en_US.UTF-8
else
	export LC_ALL=C.UTF-8
fi

readonly TYPES="feat|fix|perf|refactor|style|test|docs|build|ci|chore|revert"
readonly MAX_SUBJECT_LENGTH=72

# Lignes du message sans les commentaires de git (`git commit -v` ajoute aussi le diff après la ligne de coupe).
lines=()
while IFS= read -r line || [ -n "$line" ]; do
	[[ "$line" == "# ------------------------ >8 ------------------------"* ]] && break
	[[ "$line" == "#"* ]] && continue
	lines+=("$line")
done < "$1"

subject="${lines[0]}"

# Message vide (commit abandonné par git) ou généré par git : hors convention.
[ -z "$subject" ] && exit 0
[[ "$subject" =~ ^(Merge\ |Revert\ \"|fixup!\ |squash!\ |amend!\ ) ]] && exit 0

# Préfixe de la clé d'un ticket, `tracker.key_prefix` de la config du workflow : `APP-` donne la
# clé `#APP-12` en fin de sujet, un préfixe vide donne `#12`. Sans `yq` ou sans config, le préfixe
# est vide et la clé d'une branche à préfixe n'est pas vérifiée, sans message : le hook est partagé
# par tous les worktrees, et une branche qui n'a pas encore reçu la config afficherait un
# avertissement à chaque commit. `check.sh` signale une config absente.
config="$(git rev-parse --show-toplevel 2>/dev/null)/.claude/workflow.yml"
prefix=$(yq -r '.tracker.key_prefix // ""' "$config" 2>/dev/null) || prefix=""

warnings=()

if ! [[ "$subject" =~ ^($TYPES)(\([a-z0-9][a-z0-9-]*\))?!?:\ [^\ ] ]]; then
	warnings+=("Sujet hors format : <type>(<scope>): <description>, type parmi ${TYPES//|/, }.")
fi

description="${subject% #"$prefix"[0-9]*}"
too_long=false
if [ "${#description}" -gt "$MAX_SUBJECT_LENGTH" ]; then
	warnings+=("Sujet de ${#description} caractères, clé du ticket exclue (${MAX_SUBJECT_LENGTH} au plus) : le détail va dans le corps.")
	too_long=true
fi

if [ "${#lines[@]}" -gt 1 ] && [ -n "${lines[1]}" ]; then
	warnings+=("Pas de ligne vide entre le sujet et le corps.")
fi

# Clé de la branche, au format `<type>/<clé>_<description>`, ou à l'ancien format
# `<type>/<description>-<clé>` quand le préfixe n'est pas vide. Le préfixe entre guillemets est
# comparé tel quel, sans valeur de regex pour ses caractères (`.`, `+`).
branch=$(git branch --show-current 2>/dev/null)
branch_ticket=""
if [[ $branch =~ ^[a-z]+/("$prefix"[0-9]+)_ ]] || { [ -n "$prefix" ] && [[ $branch =~ -("$prefix"[0-9]+)$ ]]; }; then
	branch_ticket=${BASH_REMATCH[1]}
fi
if [ -n "$branch_ticket" ] && ! [[ "$subject" =~ \ \#"$branch_ticket"$ ]]; then
	warnings+=("Clé #${branch_ticket} de la branche absente de la fin du sujet.")
fi

[ "${#warnings[@]}" -eq 0 ] && exit 0

{
	echo "⚠️  Message de commit hors convention (docs/COMMITS.md) :"
	for warning in "${warnings[@]}"; do
		echo "   - $warning"
	done
} >&2

# Sujet trop long : git n'enregistre pas le commit, l'index reste tel quel.
if [ "$too_long" = true ]; then
	echo "   ❌ Commit refusé, staging intact : raccourcis le sujet, puis relance git commit." >&2
	exit 1
fi

echo "   Commit conservé. Pour corriger : git commit --amend" >&2
exit 0
