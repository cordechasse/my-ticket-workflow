#!/usr/bin/env bash
#
# Redirige l'auto-memory Claude Code (Xcode) vers `.claude/context/` du repo,
# afin que les memories partagees soient versionnees.
#
# Sans effet si Claude Code n'est pas installe (dossier parent absent).

set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONTEXT_DIR="$REPO_DIR/.claude/context"

# Encode le chemin absolu du repo en identifiant de projet Claude Code
# (remplace '/' et '_' par '-').
ENCODED_ID="$(printf '%s' "$REPO_DIR" | sed 's/[\/_]/-/g')"
CLAUDE_ROOT="$HOME/Library/Developer/Xcode/CodingAssistant/ClaudeAgentConfig/projects/$ENCODED_ID"
LOCAL_MEMORY="$CLAUDE_ROOT/memory"

if [ ! -d "$HOME/Library/Developer/Xcode/CodingAssistant" ]; then
    echo "[claude-memory] Xcode Claude Code non installe, skip."
    exit 0
fi

if [ ! -d "$CONTEXT_DIR" ]; then
    echo "[claude-memory] $CONTEXT_DIR introuvable, skip."
    exit 0
fi

mkdir -p "$CLAUDE_ROOT"

# Si deja un symlink correct, ne rien faire
if [ -L "$LOCAL_MEMORY" ] && [ "$(readlink "$LOCAL_MEMORY")" = "$CONTEXT_DIR" ]; then
    echo "[claude-memory] symlink deja en place."
    exit 0
fi

# Sauvegarder le contenu existant si ce n'est pas deja un symlink
if [ -d "$LOCAL_MEMORY" ] && [ ! -L "$LOCAL_MEMORY" ]; then
    BACKUP="$LOCAL_MEMORY.backup.$(date +%Y%m%d%H%M%S)"
    mv "$LOCAL_MEMORY" "$BACKUP"
    echo "[claude-memory] backup du dossier existant vers $BACKUP"
fi

rm -f "$LOCAL_MEMORY"
ln -s "$CONTEXT_DIR" "$LOCAL_MEMORY"
echo "[claude-memory] symlink cree : $LOCAL_MEMORY -> $CONTEXT_DIR"
