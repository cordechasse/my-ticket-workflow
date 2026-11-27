#!/usr/bin/env bash
#
# Redirige l'auto-memory de Claude Code (CLI et Xcode) vers `.claude/context/` du projet,
# afin que les memories partagées soient versionnées.
#
# Sans effet pour un client Claude Code absent (dossier racine introuvable).

set -e

# Checkout principal par git : le script est atteint par le lien `.claude/scripts` du projet, et
# Claude Code range les memories d'un worktree avec celles du checkout principal (`check.sh` aussi).
REPO_DIR="$(dirname "$(git -C "$(dirname "$0")" rev-parse --path-format=absolute --git-common-dir)")"
CONTEXT_DIR="$REPO_DIR/.claude/context"

if [ ! -d "$CONTEXT_DIR" ]; then
    echo "[claude-memory] $CONTEXT_DIR introuvable, rien à faire."
    exit 0
fi

# Identifiant de projet Claude Code : chemin absolu du projet, chaque caractère hors lettres et
# chiffres remplacé par `-`, comme `check.sh`.
ENCODED_ID="$(printf '%s' "$REPO_DIR" | sed 's/[^A-Za-z0-9]/-/g')"

# Crée le lien <racine>/projects/<id>/memory → .claude/context pour un client Claude Code.
link_memory() {
    local client="$1"
    local root="$2"
    local project_dir="$root/projects/$ENCODED_ID"
    local local_memory="$project_dir/memory"

    if [ ! -d "$root" ]; then
        echo "[claude-memory] $client : Claude Code absent, rien à faire."
        return
    fi

    mkdir -p "$project_dir"

    if [ -L "$local_memory" ] && [ "$(readlink "$local_memory")" = "$CONTEXT_DIR" ]; then
        echo "[claude-memory] $client : lien déjà en place."
        return
    fi

    # Un dossier réel existant est sauvegardé, jamais supprimé.
    if [ -d "$local_memory" ] && [ ! -L "$local_memory" ]; then
        local backup
        backup="$local_memory.backup.$(date +%Y%m%d%H%M%S)"
        mv "$local_memory" "$backup"
        echo "[claude-memory] $client : dossier existant sauvegardé dans $backup"
    fi

    rm -f "$local_memory"
    ln -s "$CONTEXT_DIR" "$local_memory"
    echo "[claude-memory] $client : lien créé, $local_memory -> $CONTEXT_DIR"
}

link_memory "CLI" "$HOME/.claude"
link_memory "Xcode" "$HOME/Library/Developer/Xcode/CodingAssistant/ClaudeAgentConfig"
