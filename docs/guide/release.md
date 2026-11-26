# Release et livraison

[Guide](README.md) · [Démarrer](demarrer.md) · [Les flux](flux.md) · [Tests](tests.md) · [Garde-fous](garde-fous.md) · [Release](release.md)

La clôture d'un jalon écrit la section de la version dans `CHANGELOG.md`, au format Keep a Changelog, et te la fait relire. Elle pose ensuite le tag `vX.Y.Z` sur le commit de fusion et ne le pousse qu'avec ton accord. Un correctif de `/izanagi:fix` fait de même quand tu choisis de le publier. `/izanagi:task` ne publie jamais. Son changement part dans la prochaine version. La première release crée `CHANGELOG.md`. Un projet migré n'y reçoit pas ses versions passées.

La clé `langue_publique` de `.izanagi/config.env` donne la langue du changelog et des notes de version, `fr` ou `en`. `init` la demande, et elle vaut `fr` par défaut.

Au push du tag, `.github/workflows/release.yml` contrôle que le tag vaut la version du fichier de version, puis `scripts/notes-de-version.sh` extrait la section de la version dans `CHANGELOG.md`. Un tag faux, ou une version sans section, arrête le workflow avant toute publication. Sinon, il construit le livrable et crée la release GitHub avec ces notes. Avec plusieurs composants, la version se lit dans celui que nomme la clé `version_composant`, le premier par défaut.

Le livrable dépend du type d'application, d'après sa fiche dans `references/types/` :

| Type | Livrable |
|---|---|
| cli | Rust : une archive des binaires par système cible, jointe à la release. TypeScript : le paquet sur npm. Python : le paquet sur PyPI. |
| library | le paquet sur crates.io, npm ou PyPI |
| api, web-frontend, plugin | aucun fichier, le tag et la release marquent la version |
| data-ml, desktop, game, mobile | aucun par défaut, le projet écrit le sien dans le job `livrable` de `release.yml` |

La publication sur un registre passe par la publication de confiance, sans jeton stocké en secret. Toi seul peux la configurer, côté registre, avant le premier tag.

Izanagi ne choisit pas d'hébergeur. Pour une api ou un front web, `init` demande la commande qui déploie un tag. La ligne « Déploiement » de `docs/agents/harness.md` porte cette commande, ou « à préciser ». Quand elle porte une commande, le projet reçoit `.github/workflows/deploiement.yml`, que tu lances à la main sur un tag (`gh workflow run deploiement.yml -f tag=vX.Y.Z`). Le workflow contrôle la forme du tag avant le checkout, puis lance la commande telle quelle. Pour revenir en arrière, relance le même workflow avec le tag précédent. Les secrets que la commande lit sont des secrets du dépôt GitHub, que toi seul peux poser. GitHub ne les met pas dans l'environnement de la commande, donc elle les écrit en expression `${{ secrets.NOM }}`, par exemple `FLY_API_TOKEN=${{ secrets.FLY_API_TOKEN }} flyctl deploy`.

`.github/pull_request_template.md` donne à chaque PR quatre titres : Quoi, Pourquoi, Vérification et Risque. Les PR que les flux ouvrent suivent ces titres.

`check-contract.sh` demande `release.yml` à un projet qui a des composants, et `deploiement.yml` quand la ligne « Déploiement » porte une commande. Il contrôle dans les deux que chaque action est épinglée par SHA et que chaque job déclare ses permissions.
