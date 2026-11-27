#!/usr/bin/env bash
# Created by Nicolas Bush on 27/11/2026.
#
# Contrôle de l'installation du paquet dans un projet, à lancer après une installation, une
# montée de version ou une édition du paquet (README § « Contrôle ») :
# - config `.claude/workflow.yml` contre `workflow/config-schema.yml`, adaptateurs désignés
# - status line et hooks du paquet déclarés dans `.claude/settings.json`
# - liens (`link.sh --check`), memories citées par le paquet, hook `commit-msg` installé
# - copie du paquet : ni `CLAUDE.md` ni `AGENTS.md`, aucune édition locale non renvoyée, commit
#   d'origine égal au tag de `VERSION`
# - fichiers locaux du projet : chemins `.claude/…` et `docs/…` et skills cités qui n'existent pas.
# Usage, depuis un dossier du projet : .claude/scripts/check.sh
# Sortie : code 0 sans rien afficher, ou code 1 et une ligne par écart. Une ligne d'information
# sur stderr signale un contrôle sauté (dépôt du paquet injoignable), sans changer le code.
# Variable d'environnement : `MY_TICKET_WORKFLOW_URL` remplace l'URL du dépôt du paquet (essais).

set -uo pipefail

# Recherches sur du texte accentué (`…`, `«`), même lancé depuis un client sans locale.
export LC_ALL=en_US.UTF-8

# Dossier du paquet dans le projet, préfixe du `git subtree`.
readonly PREFIX=".claude/vendor/my-ticket-workflow"
readonly PACKAGE_URL="${MY_TICKET_WORKFLOW_URL:-git@github.com:cordechasse/my-ticket-workflow.git}"
readonly CONFIG=".claude/workflow.yml"
readonly SETTINGS=".claude/settings.json"

# Commandes intégrées de Claude Code, citées par `/<nom>` sans être des skills du projet.
readonly BUILTIN_COMMANDS=" add-dir agents artifacts clear compact config context cost doctor
 exit export fast help hooks ide init login logout mcp memory model permissions plugin resume
 review status terminal-setup theme usage vim "

root=$(git rev-parse --show-toplevel) || exit 1
cd "$root" || exit 1

issues=0

# Écart trouvé : une ligne, et le code de sortie passe à 1.
report() {
	echo "$1"
	issues=1
}

# `yq` de mikefarah en v4 : la variante Python n'a pas la même syntaxe, et ses erreurs se liraient
# comme des écarts de config.
if ! yq --version 2>/dev/null | grep -q 'mikefarah.* v4\.'; then
	echo "yq de mikefarah en v4 requis (brew install yq) : $(yq --version 2>&1 | head -1)."
	exit 1
fi
if [ ! -d "$PREFIX" ]; then
	echo "Paquet absent : $PREFIX (README § « Installation »)."
	exit 1
fi

# --- Config ---

# Vrai si le module est actif : ni `false`, ni `none`, ni absent (FORMAT § « Configuration »).
module_on() {
	local value
	value=$(yq -r ".modules.$1 // \"none\"" "$CONFIG")
	[ "$value" != "false" ] && [ "$value" != "none" ]
}

if [ ! -f "$CONFIG" ]; then
	report "Config absente : $CONFIG (README § « Configuration »)."
else
	# Feuilles de la config, une par ligne : `<chemin>\t<valeur>`.
	leaves=$(yq -r '.. | select(tag != "!!map") | [(path | join(".")), .] | @tsv' "$CONFIG")
	schema="$PREFIX/workflow/config-schema.yml"
	# Règles du schéma, une par ligne : `<chemin>|<required>|<required_if>|<values>`. Séparateur
	# `|` et non tabulation : `read` fusionne les tabulations, et un champ vide décalerait les autres.
	rules=$(yq -r 'to_entries | .[] | [.key, (.value.required // false),
		(.value.required_if // ""), ((.value.values // []) | join(" "))] | join("|")' "$schema")

	while IFS=$'\t' read -r key _; do
		cut -d'|' -f1 <<<"$rules" | grep -qxF "$key" ||
			report "Clé inconnue : $key (renommée ou retirée, CHANGELOG)."
	done <<<"$leaves"

	while IFS='|' read -r key required required_if values; do
		line=$(awk -F'\t' -v key="$key" '$1 == key' <<<"$leaves")
		if [ -z "$line" ]; then
			if [ "$required" = "true" ]; then
				report "Clé requise absente : $key."
			elif [ -n "$required_if" ] && module_on "$required_if"; then
				report "Clé requise par le module $required_if absente : $key."
			fi
			continue
		fi
		value=${line#*	}
		if [ -n "$values" ] && [[ " $values " != *" $value "* ]]; then
			report "Valeur hors liste : $key = $value (permises : $values)."
		fi
	done <<<"$rules"

	# Adaptateur de chaque service désigné par la config.
	for pair in tracker:tracker.provider forge:forge.provider published:releases.published; do
		kind=${pair%%:*}
		service=$(yq -r ".${pair#*:} // \"\"" "$CONFIG")
		[ -z "$service" ] && continue
		adapter=".claude/workflow/adapters/$kind-$service.md"
		[ -f "$adapter" ] || report "Adaptateur absent : $adapter (${pair#*:} = $service)."
	done
fi

# --- Réglages ---

if [ ! -f "$SETTINGS" ]; then
	report "Réglages absents : $SETTINGS (README § « Réglages »)."
else
	commands=$(jq -r '[.statusLine.command?, (.hooks? // {} | .. | .command? // empty)]
		| map(select(. != null)) | .[]' "$SETTINGS")
	grep -q '\.claude/scripts/statusline\.sh' <<<"$commands" ||
		report "Status line non déclarée dans $SETTINGS (README § « Réglages »)."
	for hook in "$PREFIX"/hooks/*.sh; do
		name=$(basename "$hook")
		grep -qF ".claude/hooks/$name" <<<"$commands" ||
			report "Hook non déclaré dans $SETTINGS : .claude/hooks/$name (README § « Réglages »)."
	done
fi

# --- Liens ---

while IFS= read -r line; do
	[ -n "$line" ] && report "$line"
done < <("$PREFIX/scripts/link.sh" --check)

# --- Memories citées par le paquet ---

# Module dont dépend une memory : les étapes qui la citent sont sautées sans lui.
memory_module() {
	case $1 in
		reference_dedicated_simulator) echo simulator ;;
		reference_crashlytics_mcp) echo crash_reporter ;;
		*) echo "" ;;
	esac
}

# Dossier des memories de Claude Code : celui du checkout principal, partagé par ses worktrees,
# au nom fait du chemin dont chaque caractère hors lettres et chiffres devient `-`.
main_checkout=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
memory_dir="$HOME/.claude/projects/$(sed 's/[^A-Za-z0-9]/-/g' <<<"$main_checkout")/memory"
for memory in $(grep -rhoE '`(reference|feedback|project|user)_[a-z0-9_]+`' "$PREFIX" | tr -d '`' | sort -u); do
	module=$(memory_module "$memory")
	[ -n "$module" ] && [ -f "$CONFIG" ] && ! module_on "$module" && continue
	[ -f "$memory_dir/$memory.md" ] || report "Memory citée par le paquet absente : $memory ($memory_dir)."
done

# --- Hook commit-msg ---

hook_path=$(git rev-parse --path-format=absolute --git-path hooks/commit-msg)
if ! cmp -s "$hook_path" "$PREFIX/scripts/commit-msg-hook.sh"; then
	report "Hook commit-msg absent ou différent de .claude/scripts/commit-msg-hook.sh : $hook_path."
fi

# --- Copie du paquet ---

# Un `.gitignore` qui ignore `vendor/` (gems) ignore aussi le paquet : un fichier ajouté au paquet
# depuis le projet ne serait pas suivi.
if git check-ignore -q --no-index "$PREFIX/VERSION"; then
	report "Paquet ignoré par un .gitignore : ajouter !.claude/vendor/ (README § « Installation »)."
fi

for file in $(find "$PREFIX" -name CLAUDE.md -o -name AGENTS.md); do
	report "Fichier chargé par Claude Code dans le paquet : $file (README § « Contenu »)."
done

# Dernier commit `--squash` du subtree : son arbre est le paquet tel que tiré, et
# `git-subtree-split` donne le commit d'origine dans le dépôt du paquet.
squash=$(git log -1 --format=%H --grep="^git-subtree-dir: $PREFIX/*\$" HEAD)
if [ -z "$squash" ]; then
	report "Aucun commit de subtree pour $PREFIX (README § « Installation »)."
else
	if [ "$(git rev-parse "$squash^{tree}")" != "$(git rev-parse "HEAD:$PREFIX")" ]; then
		report "Paquet modifié dans le projet et pas encore renvoyé (README § « Édition du paquet »)."
	fi
	split=$(git log -1 --format=%B "$squash" | sed -n 's/^git-subtree-split: //p')
	version=$(tr -d '[:space:]' <"$PREFIX/VERSION")
	if tags=$(GIT_SSH_COMMAND="ssh -o ConnectTimeout=5 -o BatchMode=yes" \
		git ls-remote --tags "$PACKAGE_URL" "refs/tags/v$version" "refs/tags/v$version^{}" 2>/dev/null); then
		# Tag annoté : la ligne `^{}` donne le commit. Tag léger : la seule ligne.
		tagged=$(grep '\^{}$' <<<"$tags" | cut -f1)
		[ -z "$tagged" ] && tagged=$(head -1 <<<"$tags" | cut -f1)
		if [ -z "$tagged" ]; then
			report "Tag v$version absent du dépôt du paquet ($PACKAGE_URL)."
		elif [ "$tagged" != "$split" ]; then
			report "Paquet tiré de ${split:0:7}, pas du tag v$version (${tagged:0:7}) : git subtree pull d'un tag."
		fi
	else
		echo "Information : dépôt du paquet injoignable, commit d'origine non comparé au tag v$version." >&2
	fi
fi

# --- Fichiers locaux du projet ---

# Fichiers propres au projet qui citent l'outillage : hors liens vers le paquet, hors fichiers de
# ticket (leur historique cite des chemins disparus).
local_files() {
	local file
	for file in CLAUDE.md AGENTS.md "$CONFIG" docs/*.md .claude/rules/*.md; do
		[ -f "$file" ] && [ ! -L "$file" ] && echo "$file"
	done
	for file in .claude/skills/*; do
		[ -d "$file" ] && [ ! -L "$file" ] && find "$file" -name '*.md'
	done
}

while IFS= read -r file; do
	# Les citations `§ « … »` nomment une section, pas un fichier : retirées avant la recherche.
	text=$(sed 's/§ « [^»]*»//g' "$file")
	# Chemins dans un code en ligne (`ruby .claude/…` compris) ou dans la cible d'un lien Markdown,
	# `../` retirés : un lien de `docs/` vers `../.claude/…` part de la racine. Un modèle
	# (`<slug>`, `*`, `{version}`, `…`, `$VAR`) n'est pas un chemin.
	paths=$({ grep -oE '`[^`]+`' <<<"$text"; grep -oE '\]\([^)]+\)' <<<"$text"; } |
		grep -oE "(^|[\`( \"'])(\.\./)*(\.claude|docs)/[^\`() \"']*" |
		sed -E "s/^[\`( \"']//; s/^(\.\.\/)+//; s/[.,;:]+$//" | grep -v '[<>*{}$…]' | sort -u)
	for path in $paths; do
		[ -e "${path%/}" ] || report "Chemin absent : $path (cité dans $file)."
	done
	for name in $(grep -oE '`/[a-z][a-z0-9-]*[ `]' <<<"$text" | sed 's/^`\///; s/[ `]$//' | sort -u); do
		[[ $BUILTIN_COMMANDS == *" $name "* ]] && continue
		[ -e ".claude/skills/$name" ] || [ -e "$HOME/.claude/skills/$name" ] ||
			report "Skill absent : /$name (cité dans $file)."
	done
done < <(local_files)

exit $issues
