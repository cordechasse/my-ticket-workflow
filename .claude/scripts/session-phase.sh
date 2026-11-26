#!/bin/bash
# Created by Nicolas Bush on 17/11/2026.
#
# Phase d'un skill de ticket (ticket-start, chore, ticket-resume, ticket-close), de version
# (version-*) ou d'un skill sans version, affichée par statusline.sh : l'étape en cours, que les lots
# de TICKET.md ne disent pas. Le nom court du ticket ou de la chore l'accompagne tant que la
# session n'est pas sur sa branche : la status line l'affiche à la place de la branche courante
# (develop…). Un nom qui n'est pas celui d'un ticket (skill sans version) remplace toute la ligne.
# Usage, depuis un dossier du dépôt :
#   session-phase.sh "<phase>" ["<nom court>"]   écrit la phase, et le nom court s'il est donné
#   session-phase.sh --clear                     supprime la phase et le nom court
# Fichiers rangés par session Claude Code, dans <git-common-dir>/claude-sessions/<session>.phase
# et .name : une session ne voit jamais la phase d'une autre, même dans le même checkout. Le
# dossier commun à tous les worktrees garde la phase quand la session entre dans un worktree.
# Un /clear change de session : l'ancienne phase n'est plus lue. ticket-detect.sh purge les
# fichiers anciens.
# Un script plutôt qu'une commande à la main : une session dans un worktree refuse `$(…)`.

session=${CLAUDE_CODE_SESSION_ID:-}
if [ -z "$session" ]; then
  echo "session-phase.sh : CLAUDE_CODE_SESSION_ID absente, phase non écrite" >&2
  exit 1
fi

common_dir=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || {
  echo "session-phase.sh : pas de dépôt git dans $PWD" >&2
  exit 1
}
directory="$common_dir/claude-sessions"
phase_file="$directory/$session.phase"
name_file="$directory/$session.name"

case "$1" in
  "")
    echo "Usage : session-phase.sh \"<phase>\" [\"<nom court>\"] | --clear" >&2
    exit 1
    ;;
  --clear)
    rm -f "$phase_file" "$name_file"
    ;;
  *)
    mkdir -p "$directory"
    printf '%s\n' "$1" >"$phase_file"
    [ -z "$2" ] || printf '%s\n' "$2" >"$name_file"
    ;;
esac
