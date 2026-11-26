#!/bin/bash
# Created by Nicolas Bush on 13/11/2026.
#
# Hook PostToolUse des builds MobileBuildMCP (build_sim, build_run_sim), déclaré dans
# .claude/settings.json. Build réussi : écrit « <sha de HEAD> <empreinte du code> » dans
# <git-dir du worktree>/claude-build-state, que statusline.sh compare au code courant.
# Build en échec : Claude Code n'appelle pas ce hook. Le statut est quand même contrôlé.
# Le dossier vient de `cwd` : avec les defaults MobileBuildMCP, `tool_input` est vide.
# Limite : un build lancé depuis Xcode ou par xcodebuild à la main n'est pas vu.

input=$(cat)
status=$(jq -r '.tool_response | fromjson? | .data.summary.status // empty' <<<"$input")
[ "$status" = "SUCCEEDED" ] || exit 0

directory=$(jq -r '.cwd // empty' <<<"$input")
root=$(git -C "$directory" rev-parse --show-toplevel 2>/dev/null) || exit 0
git_dir=$(git -C "$root" rev-parse --absolute-git-dir) || exit 0
sha=$(git -C "$root" rev-parse HEAD) || exit 0
fingerprint=$("$(dirname "$0")"/../scripts/build-fingerprint.sh "$root" "$sha") || exit 0

echo "$sha $fingerprint" >"$git_dir/claude-build-state"
