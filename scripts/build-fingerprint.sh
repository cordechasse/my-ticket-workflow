#!/bin/bash
# Created by Nicolas Bush on 13/11/2026.
#
# Empreinte du code d'un dépôt par rapport à un commit, pour savoir si le dernier build est à jour.
# Usage : build-fingerprint.sh <dossier du dépôt> <sha>
# Sortie : un hash. Il ne change pas tant que le code compilé reste le même, même après un commit
# de ce code : le diff est pris entre <sha> et le working tree, pas depuis HEAD.
# Code = tout le dépôt sauf docs/, .claude/ et maestro/ : une pause de ticket ne périme pas le build.
# Fichiers non suivis inclus, noms et contenu. Écrit par le hook build-state.sh, relu par
# statusline.sh.

cd "$1" || exit 1
sha=$2
code=(. ':!docs' ':!.claude' ':!maestro')

{
  git diff --binary "$sha" -- "${code[@]}"
  untracked=$(git -c core.quotePath=false ls-files --others --exclude-standard -- "${code[@]}")
  echo "$untracked"
  [ -n "$untracked" ] && git hash-object --stdin-paths <<<"$untracked"
} | shasum | cut -d ' ' -f 1
