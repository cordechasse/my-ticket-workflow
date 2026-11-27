#!/usr/bin/env bash
# Created by Nicolas Bush on 27/11/2026.
#
# Liens relatifs qui rendent le paquet visible à Claude Code depuis le projet (README § « Liens ») :
# chaque skill, les dossiers `workflow`, `scripts` et `hooks`, le dossier `rules` sous
# `.claude/rules/paquet`, et chaque doc. La liste suit le contenu du paquet : un skill ou une doc
# ajoutés par une version reçoivent leur lien sans retouche du script.
# Un fichier ou un dossier réel à la place d'un lien est signalé, jamais touché. Un lien vers une
# autre cible est remplacé. Un lien mort est listé : il se retire à la main.
# Usage, depuis un dossier du projet :
#   .claude/scripts/link.sh           crée les liens manquants, puis lance check.sh
#   .claude/scripts/link.sh --check   liste les liens manquants ou faux et les liens morts, sans
#                                     rien créer : code 0 muet, code 1 et une ligne par écart

set -uo pipefail

# Dossier du paquet dans le projet, préfixe du `git subtree`.
readonly PREFIX=".claude/vendor/my-ticket-workflow"

check_only=false
[ "${1:-}" = "--check" ] && check_only=true

# Racine du projet par git : `$0` passe par le lien `.claude/scripts`, et un `cd` relatif à `$0`
# donnerait `.claude/` du projet.
root=$(git rev-parse --show-toplevel) || exit 1
cd "$root" || exit 1

if [ ! -d "$PREFIX" ]; then
	echo "Paquet absent : $PREFIX (README § « Installation »)."
	exit 1
fi

issues=0

# Écart trouvé : une ligne, et le code de sortie passe à 1.
report() {
	echo "$1"
	issues=1
}

# Un lien attendu : `<chemin du lien>` vers `<cible relative au dossier du lien>`.
ensure_link() {
	local link=$1 target=$2
	if [ -L "$link" ]; then
		[ "$(readlink "$link")" = "$target" ] && return
		if $check_only; then
			report "Lien vers une autre cible : $link → $(readlink "$link"), attendu $target."
			return
		fi
		ln -sfn "$target" "$link" && echo "Lien remplacé : $link → $target"
		return
	fi
	if [ -e "$link" ]; then
		report "Fichier local à la place du lien : $link (à déplacer, puis relancer link.sh)."
		return
	fi
	if $check_only; then
		report "Lien manquant : $link."
		return
	fi
	mkdir -p "$(dirname "$link")"
	ln -s "$target" "$link" && echo "Lien créé : $link → $target"
}

for skill in "$PREFIX"/skills/*/; do
	name=$(basename "$skill")
	ensure_link ".claude/skills/$name" "../vendor/my-ticket-workflow/skills/$name"
done
for folder in workflow scripts hooks; do
	ensure_link ".claude/$folder" "vendor/my-ticket-workflow/$folder"
done
ensure_link ".claude/rules/paquet" "../vendor/my-ticket-workflow/rules"
for doc in "$PREFIX"/docs/*.md; do
	name=$(basename "$doc")
	ensure_link "docs/$name" "../.claude/vendor/my-ticket-workflow/docs/$name"
done

# Liens morts dans les dossiers où le paquet pose ses liens : skill ou doc retirés par une
# version, ou cible déplacée.
for link in .claude/* .claude/skills/* .claude/rules/* docs/*; do
	[ -L "$link" ] && [ ! -e "$link" ] && report "Lien mort : $link → $(readlink "$link")."
done

if $check_only; then
	exit $issues
fi
[ $issues -eq 0 ] || exit 1
exec "$root/.claude/scripts/check.sh"
