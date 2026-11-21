# Type : web-frontend

Application web côté navigateur.

## Couches de test

- Unitaire : la logique hors rendu (vitest).
- Intégration : les composants rendus (vitest, avec Testing Library).
- Fonctionnelle : l'application dans un navigateur réel, avec Playwright. L'option `webServer` de Playwright lance le serveur de développement. La CI installe les navigateurs sur Ubuntu, et `init` écrit `navigateur=oui`.

## Test manuel par défaut

`npm run dev`, puis ouvrir l'adresse affichée dans son navigateur.

## Sections de CODING_STANDARDS.md

- **État perdu au rechargement.** Une donnée saisie ou un filtre actif disparaît après un rechargement ou un retour arrière.
- **Régression d'accessibilité.** Un contrôle n'a pas de nom accessible, ou n'est plus atteignable au clavier.
- **Écart entre navigateurs.** Une fonction marche dans Chromium et casse dans Firefox ou WebKit.

## Sécurité

Classes de failles que le relecteur sécurité cherche dans le diff, au niveau de risque élevé.

- **XSS.** Une donnée externe arrive dans le DOM par `innerHTML`, `dangerouslySetInnerHTML`, `v-html` ou une URL `javascript:`, sans échappement.
- **Jeton exposé.** Un jeton d'authentification est rangé dans `localStorage` ou dans une variable globale lisible par un script tiers.
- **Politique de sécurité affaiblie.** La CSP perd une directive, ou gagne `unsafe-inline` ou `unsafe-eval`.
- **Redirection ouverte.** L'application redirige vers une URL tirée de la requête sans liste d'hôtes permis.
- **Secret dans le paquet livré.** Une clé privée ou un secret d'API entre dans le code envoyé au navigateur.

## Livrable

La release ne joint aucun fichier. Le tag et la release marquent la version, et `deploiement.yml` met cette version en service.

## Déploiement

Izanagi ne choisit pas d'hébergeur. Le projet écrit la commande qui publie le site construit d'un tag, dans l'entrée `deploiement` de `docs/agents/harness.md`, et `deploiement.yml` la lance à la main sur un tag. Tant qu'elle vaut « à préciser », le workflow n'existe pas.

La commande lit des secrets du dépôt, par exemple le jeton de l'hébergeur du site ou l'identifiant du projet chez lui. GitHub ne les met pas dans son environnement. La commande les écrit donc en expression `${{ secrets.NOM }}`, par exemple `FLY_API_TOKEN=${{ secrets.FLY_API_TOKEN }} flyctl deploy`. Le skill `wizard` aide à poser ces secrets dans les réglages du dépôt.

## Prérequis

node et npm, puis `npx playwright install` pour les navigateurs des tests fonctionnels.
