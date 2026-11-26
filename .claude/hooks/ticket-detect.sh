#!/bin/bash
# SessionStart hook : détecte une session docs/tickets/ liée à la branche courante
# et demande à Claude de proposer la reprise (skills ticket-*).

root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0

# Phases et noms courts des sessions (session-phase.sh), un fichier par session : une nouvelle
# conversation ou un /clear change de session, et l'ancienne phase n'est plus lue. Les fichiers
# des conversations coupées depuis plus de 2 jours sont purgés.
sessions_dir="$(git -C "$root" rev-parse --path-format=absolute --git-common-dir)/claude-sessions"
[ -d "$sessions_dir" ] && find "$sessions_dir" -type f -mtime +2 -delete
branch=$(git -C "$root" branch --show-current 2>/dev/null)
[ -n "$branch" ] || exit 0

# STATE.md : ancien format à 4 fichiers, que ticket-resume convertit en TICKET.md.
ticket=""
for file in "$root"/docs/tickets/*/TICKET.md "$root"/docs/tickets/*/STATE.md; do
  [ -f "$file" ] || continue
  if grep -qxF "branch: $branch" "$file"; then
    ticket="$file"
    break
  fi
done
[ -n "$ticket" ] || exit 0

case "$ticket" in
  */TICKET.md) section="## Statut"; label="Statut enregistré" ;;
  *) section="## Prochaine action"; label="Prochaine action enregistrée" ;;
esac

session=$(basename "$(dirname "$ticket")")
last_pause=$(sed -n 's/^last_pause: //p' "$ticket" | head -1)
status=$(awk -v title="$section" 'index($0, title) == 1 {inside=1; next} /^## /{inside=0} inside' "$ticket" | sed '/^[[:space:]]*$/d' | head -10)

cat <<EOF
SESSION DE TRAVAIL DÉTECTÉE : "$session" (branche $branch, dernière pause : ${last_pause:-inconnue})
$label :
${status:-(non renseigné)}

Instruction : ne pose pas de question de reprise par défaut. Selon le premier message de l'utilisateur :
- Il invoque ticket-resume, ticket-pause ou ticket-close : rien à faire de plus.
- Il porte sur ce ticket (son sujet, ses lots, sa prochaine action, le code qu'il touche) ou demande de reprendre : propose la reprise (AskUserQuestion). Oui : invoque le skill ticket-resume avec "$session". Non : traite-le comme hors route.
- Sinon, il est hors route : traite sa demande et préviens-le en une ligne que rien n'est tracé dans docs/tickets/$session/ tant qu'il ne lance pas ticket-resume ou ticket-pause. Rappelle-le en une ligne avant chaque commit sur cette branche.
Dans le doute sur le lien avec le ticket, propose la reprise.
EOF
