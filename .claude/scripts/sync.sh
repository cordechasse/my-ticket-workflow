#!/bin/bash
# Created by Nicolas Bush on 26/11/2026.
#
# Copie le paquet de skills entre son dépôt (my-ticket-workflow) et le projet courant :
#   recevoir  paquet → projet
#   publier   fichiers du projet → commit du paquet
# Sans --apply, le script affiche son plan et n'écrit rien. Avec --apply, il copie, commite dans le
# paquet puis écrit le lock, pour que le lock porte toujours un commit qui existe. Il ne pousse jamais.
#
# Lock `.claude/workflow.lock` du projet : 1re ligne « commit <sha du paquet> », puis une ligne
# « <sha256>  <chemin> » par fichier du paquet à ce commit, au format de `shasum -a 256`. Un fichier
# du projet dont le hash diffère du lock est une retouche locale, que le prochain publier envoie.
#
# Fichiers du paquet : `git ls-files` de son dépôt, mêmes chemins que dans le projet, sauf les
# fichiers propres au dépôt (EXCLUDED_FILES).
#
# Usage : sync.sh recevoir|publier [--apply] [chemin…]
#   chemin : fichier du projet à publier (1er publier, ou fichier ajouté au paquet)
# Dépôt du paquet : $MY_TICKET_WORKFLOW_DIR, sinon ../my-ticket-workflow à côté du projet.

set -euo pipefail

# Fichiers du dépôt du paquet qui ne vont jamais dans un projet.
EXCLUDED_FILES=(LICENSE README.md)

usage() {
  echo "Usage : sync.sh recevoir|publier [--apply] [chemin…]" >&2
  exit 1
}

die() {
  echo "$1" >&2
  exit 1
}

# Arguments : l'action d'abord, puis --apply et les chemins dans n'importe quel ordre.
[[ $# -ge 1 ]] || usage
action="$1"
shift
[[ "$action" == "recevoir" || "$action" == "publier" ]] || usage
apply=false
paths=()
for argument in "$@"; do
  case "$argument" in
    --apply) apply=true ;;
    -*) usage ;;
    # Chemin relatif à la racine du projet, sans « ./ » : la forme de `git ls-files` et du lock.
    /* | *..*) die "Chemin relatif à la racine du projet attendu : $argument." ;;
    *) paths+=("${argument#./}") ;;
  esac
done

project_root="$(git rev-parse --show-toplevel)" || die "Lance sync.sh depuis un dépôt git."
lock_file="$project_root/.claude/workflow.lock"

# Dépôt du paquet. Un worktree de ticket est frère du dépôt principal : ../my-ticket-workflow
# désigne le même clone depuis l'un ou l'autre.
package_dir="${MY_TICKET_WORKFLOW_DIR:-$project_root/../my-ticket-workflow}"
[[ -d "$package_dir" ]] || die "Dépôt du paquet introuvable : $package_dir. Clone-le, ou pose MY_TICKET_WORKFLOW_DIR."
package_dir="$(cd "$package_dir" && pwd)"
git -C "$package_dir" rev-parse --git-dir >/dev/null 2>&1 || die "$package_dir n'est pas un dépôt git."

# Écrit les fichiers du paquet, un chemin par ligne, triés.
package_files() {
  local excluded=()
  for file in "${EXCLUDED_FILES[@]}"; do
    excluded+=(-e "$file")
  done
  git -C "$package_dir" ls-files | grep -vxF "${excluded[@]}" | sort || true
}

# Écrit le commit du paquet noté dans le lock, ou rien sans lock.
lock_commit() {
  [[ -f "$lock_file" ]] || return 0
  sed -n '1s/^commit //p' "$lock_file"
}

# Écrit les lignes « <sha256>  <chemin> » du lock, ou rien sans lock.
lock_entries() {
  [[ -f "$lock_file" ]] || return 0
  tail -n +2 "$lock_file"
}

# Écrit le sha256 d'un fichier du lock, ou rien s'il n'y est pas.
lock_hash() {
  lock_entries | awk -v path="$1" '{ hash = $1; sub(/^[0-9a-f]+  /, ""); if ($0 == path) print hash }'
}

# Écrit le sha256 actuel d'un fichier du projet, ou rien s'il n'existe pas.
project_hash() {
  [[ -f "$project_root/$1" ]] || return 0
  shasum -a 256 "$project_root/$1" | cut -d ' ' -f 1
}

# Écrit le sha256 d'un fichier du paquet, ou rien s'il n'existe pas.
package_hash() {
  [[ -f "$package_dir/$1" ]] || return 0
  shasum -a 256 "$package_dir/$1" | cut -d ' ' -f 1
}

# Réécrit le lock : commit du paquet, puis le sha256 de chaque fichier du paquet. Les hashes viennent
# du paquet, pas du projet : une retouche locale gardée par recevoir reste visible au publier suivant.
# Écriture dans un fichier temporaire puis mv : un lock à moitié écrit ne reste jamais.
write_lock() {
  local commit="$1"
  shift
  local temporary="$lock_file.tmp"
  {
    echo "commit $commit"
    [[ $# -eq 0 ]] || (cd "$package_dir" && printf '%s\n' "$@" | sort | while IFS= read -r path; do
      shasum -a 256 -- "$path"
    done)
  } >"$temporary"
  mv "$temporary" "$lock_file"
}

# Arrête le script si le dépôt du paquet a des modifications non commitées : une copie les mêlerait
# au commit du paquet.
require_clean_package() {
  [[ -z "$(git -C "$package_dir" status --porcelain)" ]] \
    || die "Le dépôt du paquet a des modifications non commitées : $package_dir."
}

# Arrête le script si origin a des commits du paquet que le clone n'a pas encore. Sans branche
# suivie (dépôt neuf), rien à comparer.
require_package_up_to_date() {
  git -C "$package_dir" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1 || return 0
  git -C "$package_dir" fetch -q
  local behind
  behind="$(git -C "$package_dir" rev-list --count 'HEAD..@{u}')"
  [[ "$behind" -eq 0 ]] \
    || die "Le paquet a $behind commit(s) sur origin absents du clone : git pull dans $package_dir, puis sync.sh recevoir."
}

# publier : copie dans le paquet les fichiers modifiés depuis le lock et les chemins donnés, retire
# du paquet les fichiers supprimés du projet, commite, puis réécrit le lock sur ce commit.
publish() {
  require_clean_package
  require_package_up_to_date

  # Garde : le lock doit porter le commit courant du paquet. Sinon le paquet a reçu une autre
  # publication, que la copie écraserait. Sans lock, seul un paquet vide peut naître d'un projet.
  local head locked
  head="$(git -C "$package_dir" rev-parse HEAD)"
  locked="$(lock_commit)"
  if [[ -z "$locked" ]]; then
    [[ -z "$(package_files)" ]] || die "Pas de lock et paquet non vide : sync.sh recevoir d'abord."
  elif [[ "$locked" != "$head" ]]; then
    die "Le paquet a avancé depuis le lock (${locked:0:9} → ${head:0:9}) : sync.sh recevoir d'abord."
  fi

  # Plan : chaque fichier du paquet comparé au lock, puis les chemins donnés.
  local changed=() removed=()
  while IFS= read -r path; do
    local current
    current="$(project_hash "$path")"
    if [[ -z "$current" ]]; then
      removed+=("$path")
    elif [[ "$current" != "$(lock_hash "$path")" ]]; then
      changed+=("$path")
    fi
  done < <(package_files)
  for path in "${paths[@]+"${paths[@]}"}"; do
    [[ -f "$project_root/$path" ]] || die "Fichier absent du projet : $path."
    local known=false
    for candidate in "${changed[@]+"${changed[@]}"}"; do
      [[ "$candidate" == "$path" ]] && known=true
    done
    [[ "$known" == true ]] || changed+=("$path")
  done

  if [[ ${#changed[@]} -eq 0 && ${#removed[@]} -eq 0 ]]; then
    echo "Rien à publier : le projet est identique au lock."
    return 0
  fi
  for path in "${changed[@]+"${changed[@]}"}"; do echo "copié   $path"; done
  for path in "${removed[@]+"${removed[@]}"}"; do echo "retiré  $path"; done
  if [[ "$apply" == false ]]; then
    echo "Plan seul : relance avec --apply pour publier."
    return 0
  fi

  # Copie, retrait, puis un seul commit du paquet.
  for path in "${changed[@]+"${changed[@]}"}"; do
    mkdir -p "$package_dir/$(dirname "$path")"
    cp -p "$project_root/$path" "$package_dir/$path"
    git -C "$package_dir" add -- "$path"
  done
  for path in "${removed[@]+"${removed[@]}"}"; do
    git -C "$package_dir" rm -q -- "$path"
  done
  git -C "$package_dir" commit -q -m "Publication de $(( ${#changed[@]} + ${#removed[@]} )) fichier(s)" \
    -m "$(printf '%s\n' "${changed[@]+"${changed[@]}"}" "${removed[@]+"${removed[@]}"}")"

  # Le lock suit le nouveau commit, avec tous les fichiers du paquet.
  local files=()
  while IFS= read -r path; do files+=("$path"); done < <(package_files)
  write_lock "$(git -C "$package_dir" rev-parse HEAD)" "${files[@]+"${files[@]}"}"
  echo "Publié : commit $(git -C "$package_dir" rev-parse --short HEAD) du paquet, lock réécrit. Push à faire dans $package_dir."
}

# Avertit pour chaque memory citée par un fichier du paquet (« memory `<nom>` ») et absente de
# `.claude/context/` du projet. Son contenu est propre au projet : le paquet ne la porte pas.
warn_missing_memories() {
  local names
  names="$(cd "$package_dir" && package_files | while IFS= read -r path; do
    grep -o 'memory `[a-z_]*`' "$path" || true
  done | sed 's/memory `\(.*\)`/\1/' | sort -u)"
  for name in $names; do
    [[ -f "$project_root/.claude/context/$name.md" ]] \
      || echo "Memory citée absente : .claude/context/$name.md (à écrire si son module est actif)." >&2
  done
}

# recevoir : copie dans le projet les fichiers du paquet qui diffèrent, supprime les fichiers retirés
# du paquet, puis réécrit le lock sur le commit du paquet. Une retouche locale sur un fichier que le
# paquet n'a pas changé est gardée, pour le publier suivant. Rien n'est commité dans le projet.
receive() {
  [[ ${#paths[@]} -eq 0 ]] || die "recevoir ne prend pas de chemin : il reçoit tout le paquet."
  require_clean_package
  require_package_up_to_date

  local head locked
  head="$(git -C "$package_dir" rev-parse HEAD)"
  locked="$(lock_commit)"

  # Garde : un fichier retouché dans le projet (modifié ou supprimé) et changé dans le paquet depuis
  # le lock est un conflit, que la copie écraserait. Retouché dans le projet seul : gardé.
  local kept=() conflicts=()
  while IFS= read -r path; do
    local locked_hash
    locked_hash="$(lock_hash "$path")"
    [[ "$(project_hash "$path")" == "$locked_hash" ]] && continue
    if [[ "$(package_hash "$path")" == "$locked_hash" ]]; then
      kept+=("$path")
    else
      conflicts+=("$path")
    fi
  done < <(lock_entries | sed 's/^[0-9a-f]*  //')
  is_kept() {
    local candidate
    for candidate in "${kept[@]+"${kept[@]}"}"; do [[ "$candidate" == "$1" ]] && return 0; done
    return 1
  }
  if [[ ${#conflicts[@]} -gt 0 ]]; then
    printf 'Changé dans le projet et dans le paquet : %s\n' "${conflicts[@]}" >&2
    die "Mets ces retouches de côté, sync.sh recevoir, puis réapplique-les et sync.sh publier."
  fi

  # Plan : un fichier du paquet absent du projet est ajouté, un fichier connu du lock est mis à
  # jour, un fichier local inconnu du lock est écrasé (1er recevoir), avec son diff dans le plan.
  local copied=() overwritten=() removed=()
  while IFS= read -r path; do
    local current
    current="$(project_hash "$path")"
    [[ "$current" == "$(package_hash "$path")" ]] && continue
    is_kept "$path" && continue
    if [[ -n "$current" && -z "$(lock_hash "$path")" ]]; then
      overwritten+=("$path")
    else
      copied+=("$path")
    fi
  done < <(package_files)
  # Fichier du lock retiré du paquet : intact d'après la garde, donc supprimé.
  while IFS= read -r path; do
    package_files | grep -qxF "$path" && continue
    [[ -f "$project_root/$path" ]] && removed+=("$path")
  done < <(lock_entries | sed 's/^[0-9a-f]*  //')

  if [[ ${#copied[@]} -eq 0 && ${#overwritten[@]} -eq 0 && ${#removed[@]} -eq 0 && "$locked" == "$head" ]]; then
    echo "Rien à recevoir : le projet est à jour du paquet."
    warn_missing_memories
    return 0
  fi
  for path in "${copied[@]+"${copied[@]}"}"; do echo "copié   $path"; done
  for path in "${overwritten[@]+"${overwritten[@]}"}"; do echo "écrasé  $path"; done
  for path in "${removed[@]+"${removed[@]}"}"; do echo "retiré  $path"; done
  for path in "${kept[@]+"${kept[@]}"}"; do echo "gardé   $path (retouche locale, à publier)"; done
  local from="${locked:0:9}"
  [[ "$locked" == "$head" ]] || echo "lock    ${from:-aucun} → ${head:0:9}"
  if [[ "$apply" == false ]]; then
    for path in "${overwritten[@]+"${overwritten[@]}"}"; do
      diff -u "$project_root/$path" "$package_dir/$path" || true
    done
    echo "Plan seul : relance avec --apply pour recevoir."
    return 0
  fi

  # Copie dans un fichier temporaire puis mv : le fichier remplacé change d'inode, et un script en
  # cours d'exécution, sync.sh compris, continue de lire l'ancien.
  for path in "${copied[@]+"${copied[@]}"}" "${overwritten[@]+"${overwritten[@]}"}"; do
    mkdir -p "$project_root/$(dirname "$path")"
    cp -p "$package_dir/$path" "$project_root/$path.sync-tmp"
    mv "$project_root/$path.sync-tmp" "$project_root/$path"
  done
  # Suppression, puis les dossiers devenus vides (dossier d'un skill retiré).
  for path in "${removed[@]+"${removed[@]}"}"; do
    rm "$project_root/$path"
    (cd "$project_root" && rmdir -p "$(dirname "$path")" 2>/dev/null) || true
  done

  local files=()
  while IFS= read -r path; do files+=("$path"); done < <(package_files)
  write_lock "$head" "${files[@]+"${files[@]}"}"
  echo "Reçu : commit ${head:0:9} du paquet, lock réécrit. À commiter dans le projet."
  warn_missing_memories
}

case "$action" in
  publier) publish ;;
  recevoir) receive ;;
esac
