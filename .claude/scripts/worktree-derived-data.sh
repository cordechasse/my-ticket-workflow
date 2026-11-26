#!/bin/bash
# Created by Nicolas Bush on 24/11/2026.
#
# Liste les dossiers de build d'un worktree, une ligne « <source> <chemin> » par dossier :
#   mobilebuildmcp  DerivedData d'un workspace MobileBuildMCP dont le WorkspacePath est le worktree
#   xcode           DerivedData d'Xcode dont le WorkspacePath est le worktree
#   workspace       workspace MobileBuildMCP propre au worktree (session Claude lancée dans le worktree)
# MobileBuildMCP nomme son workspace d'après le dossier de lancement de la session Claude : après un
# EnterWorktree, le DerivedData du worktree est dans le workspace du dépôt principal. Seul le
# WorkspacePath de chaque DerivedData relie donc un dossier au worktree.
# Utilisé par ticket-close (suppression) et par le skill local de lancement de l'app, s'il existe (choix du DerivedData).
#
# Usage : worktree-derived-data.sh <racine du worktree>

root="${1:?Usage : worktree-derived-data.sh <racine du worktree>}"
root="${root%/}"
workspaces="$HOME/Library/Developer/MobileBuildMCP/workspaces"

# Projet Xcode : le seul `*.xcodeproj` à la racine du worktree. Aucun ou plusieurs : rien ne relie
# un DerivedData au worktree, le script s'arrête sans rien lister.
projects=("$root"/*.xcodeproj)
if [[ ${#projects[@]} -ne 1 || ! -d "${projects[0]}" ]]; then
  echo "Projet Xcode introuvable ou ambigu à la racine de $root : un seul *.xcodeproj attendu." >&2
  exit 1
fi

# Le disque ignore la casse, et un même projet peut porter une casse différente dans le dépôt
# principal et dans un worktree. La comparaison l'ignore aussi.
lowercase() { tr '[:upper:]' '[:lower:]' <<<"$1"; }
project="$(lowercase "${projects[0]}")"

# Écrit « <source> <dossier> » pour chaque info.plist dont le WorkspacePath est le projet du worktree.
list_derived_data() {
  local source="$1"
  shift
  for plist in "$@"; do
    path=$(/usr/libexec/PlistBuddy -c 'Print :WorkspacePath' "$plist" 2>/dev/null) || continue
    [[ "$(lowercase "$path")" == "$project" ]] && echo "$source $(dirname "$plist")"
  done
}

list_derived_data mobilebuildmcp "$workspaces"/*/DerivedData/*/info.plist
list_derived_data xcode "$HOME"/Library/Developer/Xcode/DerivedData/*/info.plist

# Workspace nommé « <dossier du worktree>-<hash de 12 caractères> ». Le motif fixe évite que
# « …-APP-123 » capte « …-APP-1234-<hash> ».
for workspace in "$workspaces/$(basename "$root")"-????????????; do
  [[ -d "$workspace" ]] && echo "workspace $workspace"
done

exit 0
