#!/bin/bash
# Created by Nicolas Bush on 17/11/2026.
#
# Renomme l'onglet herdr de la session Claude Code : nom court d'un ticket ou d'une chore,
# `<action>-X.Y.Z` d'un skill de version, ou `<action>` d'un skill sans version
# (FORMAT § « Nom court, onglet herdr et simulateur »).
# Usage : herdr-tab.sh "<nom>"
# Jamais bloquant pour le skill :
#   - session hors herdr (HERDR_TAB_ID absente) : rien, code 0, sans message
#   - commande herdr absente ou en erreur : une ligne sur stderr, code 1, que le skill reprend
#     dans son résumé, sans nouvel essai.
# Un script plutôt qu'une commande à la main : une session dans un worktree refuse `$(…)`.

name=$1
if [ -z "$name" ]; then
  echo "Usage : herdr-tab.sh \"<nom>\"" >&2
  exit 1
fi

[ -n "$HERDR_TAB_ID" ] || exit 0

if ! command -v herdr >/dev/null 2>&1; then
  echo "herdr-tab.sh : commande herdr introuvable, onglet non renommé" >&2
  exit 1
fi

if ! error=$(herdr tab rename "$HERDR_TAB_ID" "$name" 2>&1 >/dev/null); then
  echo "herdr-tab.sh : renommage de l'onglet refusé par herdr (${error:-sans message})" >&2
  exit 1
fi
