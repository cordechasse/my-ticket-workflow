# Tests manuels

Protocole de chaque test manuel proposé à l'utilisateur, en session de ticket ou non :

1. Annonce : tableau de 3 colonnes, Index (`T1`, `T2`… de `TICKET.md`), Nom (quelques mots), Objectif.
2. Accord de l'utilisateur.
3. Un seul test à la fois, sous le titre `T<n> — <nom>` :
   - **Objectif** : ce que le test valide, et par quelle action
   - **Préconditions** : compte, état de l'app, position, données
   - **Étapes** : gestes numérotés
   - **Attendu** : en UI (écran, titre, message) ou en fonctionnel (le traitement en cours continue)
   - **Non développé** : ce qui n'est pas encore fait, et dans quel lot.
4. Résultat donné : écrit dans « Tests » de `TICKET.md` en session de ticket, puis le test suivant.

Une ligne sans contenu (aucune précondition, tout développé) est omise. Jamais plusieurs tests d'un coup, même en fin de lot.
