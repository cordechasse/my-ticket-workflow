#!/bin/bash
# Created by Nicolas Bush on 13/11/2026.
#
# Status line de Claude Code, déclarée dans .claude/settings.json.
# Session de ticket (docs/tickets/*/TICKET.md dont `branch:` est la branche courante) :
#   APP-1234 mode-hors-ligne │ 1✓ › 2✓ › ▶ 3 (Titre) › 4 │ build à jour
#   #42 mode-hors-ligne │ ▶ 1 (Titre)                   (clé sans préfixe : `#<numéro>`)
# Phase d'un skill de ticket ou de version, écrite par session-phase.sh, après le chemin de fer :
#   APP-1234 mode-hors-ligne │ 1✓ › 2✓ │ clôture : revue
#   APP-1235 slug │ démarrage : exploration                       (avant TICKET.md)
#   APP-1235 slug │ démarrage : version                           (avant la branche, sur develop)
#   CHORE mise-a-jour-skills │ ▶ 1 (Titre)                        (chore, sans ticket)
# Hors session : le nom de la branche, la phase d'un skill de version et l'état du build :
#   release/1.4.2 │ staging 1.4.2 : build │ build à jour
# Skill sans version (triage du support, par exemple), quelle que soit la session : son nom et sa
# phase, d'après RULES § « Onglet herdr et phase », point « Skill sans version ».
#   <action> │ <étape>
# Hors dépôt git : ligne vide.
# Entrée : le JSON de Claude Code sur stdin. Lancé à chaque message de l'assistant : il reste rapide.

export LC_ALL=en_US.UTF-8

input=$(cat)
directory=$(jq -r '.workspace.current_dir // .cwd // empty' <<<"$input")
session=$(jq -r '.session_id // empty' <<<"$input")
[ -d "$directory" ] || exit 0
root=$(git -C "$directory" rev-parse --show-toplevel 2>/dev/null) || exit 0
branch=$(git -C "$root" branch --show-current 2>/dev/null)
[ -n "$branch" ] || branch=$(git -C "$root" rev-parse --short HEAD 2>/dev/null)

# État du dernier build MobileBuildMCP, écrit par .claude/hooks/build-state.sh : « build à jour »
# si l'empreinte du code depuis le sha du build n'a pas changé. Pas de fichier d'état : rien.
build=""
git_dir=$(git -C "$root" rev-parse --absolute-git-dir)
state_file="$git_dir/claude-build-state"
if [ -f "$state_file" ]; then
  read -r built_sha built_fingerprint <"$state_file"
  fingerprint=$("$(dirname "$0")"/build-fingerprint.sh "$root" "$built_sha" 2>/dev/null)
  if [ "$fingerprint" = "$built_fingerprint" ]; then build="build à jour"; else build="build périmé"; fi
fi

ticket_file=""
for file in "$root"/docs/tickets/*/TICKET.md; do
  if [ -f "$file" ] && grep -qxF "branch: $branch" "$file"; then
    ticket_file="$file"
    break
  fi
done

# Phase du skill en cours et nom court du ticket, écrits par session-phase.sh, un fichier par
# session dans le dossier commun aux worktrees : la phase d'une autre session n'apparaît pas.
phase=""
name=""
if [ -n "$session" ]; then
  sessions_dir="$(git -C "$root" rev-parse --path-format=absolute --git-common-dir)/claude-sessions"
  [ -f "$sessions_dir/$session.phase" ] && phase=$(head -1 "$sessions_dir/$session.phase")
  [ -f "$sessions_dir/$session.name" ] && name=$(head -1 "$sessions_dir/$session.name")
fi

# Préfixe de la clé d'un ticket, `tracker.key_prefix` de la config du workflow (`APP-`, ou vide
# pour une clé faite du seul numéro). Sans `yq` ou sans config : préfixe vide, et une branche dont
# la clé a un préfixe s'affiche telle quelle tant que TICKET.md n'existe pas.
prefix=$(yq -r '.tracker.key_prefix // ""' "$root/.claude/workflow.yml" 2>/dev/null) || prefix=""

# Skill sans lien avec la branche (triage du support, par exemple) : son nom, posé comme nom
# court, remplace la branche, la session de ticket et l'état du build, sans rapport avec son travail.
if [ -n "$name" ] && [ -n "$phase" ] && [[ ! $name =~ ^("$prefix"[0-9]+|CHORE)_ ]]; then
  echo "$name │ $phase"
  exit 0
fi

# Clé du frontmatter, « CHORE » pour une session sans ticket. Sans TICKET.md (démarrage avant
# l'écriture du fichier), la clé vient du nom de branche si une phase est écrite, au format
# `<type>/<clé>_<slug>` ou à l'ancien format `<type>/<slug>-<clé>` (préfixe non vide), sinon du nom
# court de la session (`APP-1_slug`, `CHORE_slug`), posé avant le choix de la branche.
source=$branch
if [ -n "$ticket_file" ]; then
  key=$(sed -n 's/^ticket: #*//p' "$ticket_file" | head -1)
  [ -n "$key" ] && [ "$key" != "none" ] || key="CHORE"
elif [ -n "$phase" ] && [[ $branch =~ ^[a-z]+/(${prefix}[0-9]+)_ ]]; then
  key=${BASH_REMATCH[1]}
elif [ -n "$phase" ] && [ -n "$prefix" ] && [[ $branch =~ -(${prefix}[0-9]+)$ ]]; then
  key=${BASH_REMATCH[1]}
elif [ -n "$phase" ] && [[ $branch == chore/* ]]; then
  key="CHORE"
elif [[ $name =~ ^(${prefix}[0-9]+|CHORE)_ ]]; then
  key=${BASH_REMATCH[1]}
  source=$name
else
  echo "$branch${phase:+ │ $phase}${build:+ │ $build}"
  exit 0
fi

# Slug : branche ou nom court sans préfixe `<type>/` ni clé, au format actuel
# (`feature/APP-1_slug`) comme à l'ancien (`feature/slug-APP-1`).
slug=${source#*/}
slug=${slug#"$key"_}
slug=${slug%-"$key"}

# Clé affichée : une clé faite du seul numéro prend un `#` (`#61`), comme en fin de sujet de commit.
label=$key
[[ $key =~ ^[0-9]+$ ]] && label="#$key"

# Chemin de fer, lu dans les lignes `- Lot N ✓ …`, `### Lot N ▶ <titre> (<module>)` et `- Lot N …`
# de la section « Lots » : `1✓ › 2✓ › ▶ 3 @TITLE@ › 4`. Le titre du lot en cours sort à part,
# sur une seconde ligne, pour être tronqué avant d'être inséré à la place de @TITLE@.
# Sans TICKET.md, pas de chemin de fer : la phase seule dit où en est la session.
lots=""
[ -n "$ticket_file" ] && lots=$(
  awk '
    /^## Lots/ { inside = 1; next }
    /^## / { inside = 0 }
    !inside || $0 !~ /^(- |### )Lot [0-9]+/ { next }
    {
      rest = $0
      sub(/^(- |### )Lot /, "", rest)
      number = rest
      sub(/[^0-9].*/, "", number)
      rest = substr(rest, length(number) + 1)
      if (rest ~ /^ ✓/) {
        item = number "✓"
      } else if (rest ~ /^ ▶/) {
        item = "▶ " number " @TITLE@"
        title = rest
        sub(/^ ▶ */, "", title)
        sub(/ — .*/, "", title)
        sub(/ \([^)]*\)$/, "", title)
        gsub(/`/, "", title)
      } else {
        item = number
      }
      railway = railway (railway == "" ? "" : " › ") item
    }
    END { print railway; print title }
  ' "$ticket_file"
)
railway=$(head -1 <<<"$lots")
title=$(sed -n 2p <<<"$lots")

# Ligne trop large pour le terminal : le titre du lot est tronqué en premier, puis le slug.
width=${COLUMNS:-200}
compose() {
  local lots=${railway/ @TITLE@/${title:+ ($title)}}
  echo "$label $slug${lots:+ │ $lots}${phase:+ │ $phase}${build:+ │ $build}"
}
line=$(compose)
overflow=$((${#line} - width))
if [ "$overflow" -gt 0 ] && [ -n "$title" ]; then
  keep=$((${#title} - overflow - 1))
  if [ "$keep" -gt 0 ]; then title="${title:0:$keep}…"; else title=""; fi
  line=$(compose)
  overflow=$((${#line} - width))
fi
keep=$((${#slug} - overflow - 1))
if [ "$overflow" -gt 0 ] && [ "$keep" -gt 0 ]; then
  slug="${slug:0:$keep}…"
  line=$(compose)
fi

echo "$line"
