# Adaptateur versions publiées : tags git

Source qui dit si un numéro de version est publié, pour RULES § « Versions », sans accès au store. Une version publiée porte le **tag de publication** `vX.Y.Z`, annoté, posé sur le commit du build publié (§ « Marquer une version publiée »). Ni un tag de build, ni le statut de la version du tracker ne prouvent la publication.

## Lire les versions publiées

Après le fetch des tags (RULES § « Lire l'état »), une fois par exécution du skill, dans un appel Bash à part :

```bash
versions=$(mktemp -t published-versions)
template=$(yq '.releases.build_tag' .claude/workflow.yml); template=${template//\{environment\}/prod}
for tag in $(git tag --list 'v*' | rg -e '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V); do
  v=${tag#v}
  tv=${template//\{version\}/$v}; prefix=${tv%%\{build\}*}; suffix=${tv#*\{build\}}
  build=""
  for b in $(git tag --points-at "$tag^{commit}"); do
    n=${b#"$prefix"}; n=${n%"$suffix"}
    [[ $b == "$prefix"*"$suffix" && $n =~ ^[0-9]+$ ]] && build=$n
  done
  jq -nc --arg v "$v" --arg b "$build" '{version: $v, build: $b, published: true}'
done | jq -s '{versions: .}' > "$versions"
echo "versions=$versions"
```

- Le JSON a la forme attendue par RULES § « Lire l'état ». Il liste seulement les versions publiées.
- `build` : numéro du tag de build prod (RULES § « Versions ») du même commit que le tag de publication. Vide si aucun tag de build prod n'y est posé.
- `^{commit}` est nécessaire : sans lui, `--points-at` d'un tag annoté rend seulement ce tag.
- **Version publiée non marquée** : une version approuvée par le store sans tag de publication passe pour ouverte. Un skill qui touche une release dont le dernier tag de build date de plus de 2 semaines demande donc à l'utilisateur si la version est publiée, et renvoie vers `version-close` si oui.

## Marquer une version publiée

Par `version-close`, avant toute fusion. Tag `vX.Y.Z` déjà présent : rien à faire.

Formulaire de publication : chaque tag de build prod de la version (RULES § « Versions »), le plus récent en premier, avec son commit (sha court, date), puis « Pas encore publiée ». « Pas encore publiée » : arrêt de `version-close`.

Build choisi, après confirmation du push :

```bash
git tag -a vX.Y.Z -m "X.Y.Z publiée sur le store (build <n>)" "<tag du build>^{commit}"
git push origin vX.Y.Z
```
