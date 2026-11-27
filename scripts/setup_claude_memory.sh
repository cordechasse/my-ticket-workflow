#!/usr/bin/env bash
#
# Redirige l'auto-memory Claude Code (Xcode) vers `.claude/context/` du projet,
# afin que les memories partagées soient versionnées.
#
# Sans effet si Claude Code n'est pas installé (dossier parent absent).

set -e

# Racine du projet par git : le script est atteint par le lien `.claude/scripts` du projet,
# et `dirname "$0"/..` donnerait `<projet>/.claude`.
REPO_DIR="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
CONTEXT_DIR="$REPO_DIR/.claude/context"

# Encode le chemin absolu du projet en identifiant de projet Claude Code
# (remplace '/' et '_' par '-').
ENCODED_ID="$(printf '%s' "$REPO_DIR" | sed 's/[\/_]/-/g')"
CLAUDE_ROOT="$HOME/Library/Developer/Xcode/CodingAssistant/ClaudeAgentConfig/projects/$ENCODED_ID"
LOCAL_MEMORY="$CLAUDE_ROOT/memory"

if [ ! -d "$HOME/Library/Developer/Xcode/CodingAssistant" ]; then
    echo "[claude-memory] Claude Code d'Xcode non installé, rien à faire."
    exit 0
fi

if [ ! -d "$CONTEXT_DIR" ]; then
    echo "[claude-memory] $CONTEXT_DIR introuvable, rien à faire."
    exit 0
fi

mkdir -p "$CLAUDE_ROOT"

# Lien déjà correct : rien à faire
if [ -L "$LOCAL_MEMORY" ] && [ "$(readlink "$LOCAL_MEMORY")" = "$CONTEXT_DIR" ]; then
    echo "[claude-memory] lien déjà en place."
    exit 0
fi

# Dossier réel existant : sauvegardé avant d'être remplacé par le lien
if [ -d "$LOCAL_MEMORY" ] && [ ! -L "$LOCAL_MEMORY" ]; then
    BACKUP="$LOCAL_MEMORY.backup.$(date +%Y%m%d%H%M%S)"
    mv "$LOCAL_MEMORY" "$BACKUP"
    echo "[claude-memory] dossier existant sauvegardé dans $BACKUP"
fi

rm -f "$LOCAL_MEMORY"
ln -s "$CONTEXT_DIR" "$LOCAL_MEMORY"
echo "[claude-memory] lien créé : $LOCAL_MEMORY -> $CONTEXT_DIR"
