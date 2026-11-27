#!/usr/bin/env bash
#
# Created by Nicolas Bush on 21/11/2026.
#
# Appel à l'API REST GitHub du dépôt `tracker.project` de .claude/workflow.yml, pour les opérations
# que le MCP GitHub n'expose pas (milestones, réécriture d'un commentaire). Le token vient de
# GITHUB_PERSONAL_ACCESS_TOKEN, comme pour le MCP.
#
# Usage : .claude/scripts/github-api.sh <MÉTHODE> <chemin sous /repos/<tracker.project>> [corps JSON]
#   .claude/scripts/github-api.sh GET 'milestones?state=all&per_page=100'
#   .claude/scripts/github-api.sh POST milestones '{"title":"1.5.0","description":"Mode hors ligne"}'
#   .claude/scripts/github-api.sh PATCH milestones/3 '{"title":"1.5.0"}'
#   .claude/scripts/github-api.sh PATCH issues/comments/42 '{"body":"…"}'

set -euo pipefail

root="$(git rev-parse --show-toplevel)"
repository="$(yq '.tracker.project' "$root/.claude/workflow.yml")"
readonly repository

if [ -z "$repository" ] || [ "$repository" = "null" ]; then
    echo "Clé tracker.project absente de .claude/workflow.yml." >&2
    exit 1
fi

if [ -z "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]; then
    echo "GITHUB_PERSONAL_ACCESS_TOKEN absent : à définir dans le profil du shell." >&2
    exit 1
fi

if [ $# -lt 2 ]; then
    echo "Usage : $0 <MÉTHODE> <chemin> [corps JSON]" >&2
    exit 1
fi

method="$1"
path="$2"
body="${3:-}"

arguments=(
    --silent --show-error --fail-with-body
    --request "$method"
    --header "Accept: application/vnd.github+json"
    --header "Authorization: Bearer $GITHUB_PERSONAL_ACCESS_TOKEN"
    --header "X-GitHub-Api-Version: 2022-11-28"
)
[ -n "$body" ] && arguments+=(--data "$body")

curl "${arguments[@]}" "https://api.github.com/repos/$repository/$path"
