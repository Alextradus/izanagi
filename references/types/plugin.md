# Type : plugin

Plugin ou extension d'un hôte : éditeur, navigateur, outil en ligne de commande, application.

## Couches de test

- Tests unitaires de la logique, hors hôte (`vitest`, `pytest`, `cargo test`).
- Tests dans l'hôte réel : charger le plugin dans l'hôte et vérifier son effet (`@vscode/test-electron` pour VS Code, Playwright avec une extension chargée pour Chrome, `claude plugin validate .` pour un plugin Claude Code).

## Test manuel par défaut

Charger le plugin en mode développement dans l'hôte (touche F5 de VS Code, « Charger l'extension non empaquetée » de Chrome, `claude --plugin-dir .`) et déclencher chaque fonction.

## Sections de CODING_STANDARDS.md

- **Version d'hôte non prise en charge.** Le plugin s'appuie sur une API absente d'une version d'hôte qu'il déclare prendre en charge.
- **Manifeste incohérent.** Le manifeste annonce une commande, une permission ou un fichier que le code ne fournit pas, ou l'inverse.
- **Permission excessive.** Le plugin demande plus d'accès que ses fonctions n'en utilisent.

## Prérequis

L'hôte installé, dans la version minimale que le plugin déclare, et la toolchain de la pile.
