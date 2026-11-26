# Adaptateur versions publiées : App Store Connect

Source qui dit si un numéro de version est publié, pour RULES § « Versions ». App Store Connect fait foi, ni les tags ni le statut de la version du tracker.

## Lire les versions publiées

Versions App Store de l'app prod (`app.bundle_id`), une fois par exécution du skill, dans un appel Bash à part (≈ 20 s), par la lane fastlane `app_store_versions` :

```bash
versions=$(mktemp -t app-store-versions) && log=$(mktemp -t app-store-versions-log)
bundle exec fastlane ios app_store_versions output:"$versions" < /dev/null > "$log" 2>&1 || tail -20 "$log"
echo "versions=$versions"
```

- Le JSON a la forme attendue par RULES § « Lire l'état » : `{"versions": [{"version", "state", "build", "published"}]}`.
- `published` vaut vrai à partir de l'approbation par Apple : App Store Connect n'accepte plus de build pour ce numéro. Une version en préparation, en revue ou refusée par Apple n'est pas publiée.
- `build` : numéro du build publié.
- Échec (réseau, clé d'API, état inconnu) : arrêt, avec le message de la lane. Les tags ne remplacent jamais cette lecture : un tag de build en prod ne prouve pas la publication.

## Marquer une version publiée

Rien à écrire : App Store Connect fait foi. Version non publiée (en préparation, en revue, refusée par Apple) : refus de `version-close`.
