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

## Prérequis

node et npm, puis `npx playwright install` pour les navigateurs des tests fonctionnels.
