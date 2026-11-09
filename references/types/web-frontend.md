# Type : web-frontend

Application web côté navigateur.

## Couches de test

- Tests unitaires et de composants (vitest, avec Testing Library).
- Tests de bout en bout dans un navigateur réel (Playwright). La CI ne les lance que si `scripts/check.sh` les inclut ; ajoute alors l'installation des navigateurs à la CI.

## Test manuel par défaut

`npm run dev`, puis ouvrir l'adresse affichée dans son navigateur.

## Sections de CODING_STANDARDS.md

- **État perdu au rechargement.** Une donnée saisie ou un filtre actif disparaît après un rechargement ou un retour arrière.
- **Régression d'accessibilité.** Un contrôle n'a pas de nom accessible, ou n'est plus atteignable au clavier.
- **Écart entre navigateurs.** Une fonction marche dans Chromium et casse dans Firefox ou WebKit.

## Prérequis

node et npm, puis `npx playwright install` pour les navigateurs des tests de bout en bout.
