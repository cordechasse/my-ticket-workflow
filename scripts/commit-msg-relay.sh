#!/usr/bin/env bash
# Created by Nicolas Bush on 27/11/2026.
#
# Hook commit-msg installé par le projet dans le dossier des hooks de git, commun à tous les
# worktrees (README § « Installation »). Il lance le hook du paquet de la branche courante : chaque
# worktree suit la version du paquet de sa branche, sans recopie à chaque montée. Une branche sans
# le paquet n'a pas de contrôle des messages.
# Git lance un hook depuis la racine du worktree (`man githooks`) : le chemin relatif suffit.

hook=".claude/scripts/commit-msg-hook.sh"
[ -x "$hook" ] || exit 0
exec "$hook" "$@"
