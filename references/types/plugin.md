# Type : plugin

Plugin ou extension d'un hôte : éditeur, navigateur, outil en ligne de commande, application.

## Couches de test

- Unitaire : la logique, hors hôte (`vitest`, `pytest`, `cargo test`).
- Intégration : le plugin contre un hôte simulé, ou contre l'hôte réel si l'hôte le permet (`@vscode/test-electron` pour VS Code, `claude plugin validate .` pour un plugin Claude Code).
- Fonctionnelle : sans objet par défaut. Le test manuel dans l'hôte en tient lieu.

## Test manuel par défaut

Charger le plugin en mode développement dans l'hôte (touche F5 de VS Code, « Charger l'extension non empaquetée » de Chrome, `claude --plugin-dir .`) et déclencher chaque fonction.

## Sections de CODING_STANDARDS.md

- **Version d'hôte non prise en charge.** Le plugin s'appuie sur une API absente d'une version d'hôte qu'il déclare prendre en charge.
- **Manifeste incohérent.** Le manifeste annonce une commande, une permission ou un fichier que le code ne fournit pas, ou l'inverse.
- **Permission excessive.** Le plugin demande plus d'accès que ses fonctions n'en utilisent.

## Sécurité

Classes de failles que le relecteur sécurité cherche dans le diff, au niveau de risque élevé.

- **Permission excessive.** Le manifeste gagne une permission ou un hôte qu'aucune fonction du diff n'utilise.
- **Contenu de l'hôte exécuté.** Le plugin évalue ou injecte comme du code un texte lu dans l'hôte (page, document, sortie d'outil).
- **Commande construite à partir d'une entrée.** Une donnée de l'hôte entre dans une commande système sans échappement.
- **Secret stocké en clair.** Un jeton est rangé dans les réglages en clair au lieu du stockage de secrets de l'hôte.
- **Code téléchargé à l'exécution.** Le plugin charge et lance du code distant, hors de la revue de son magasin.

## Prérequis

L'hôte installé, dans la version minimale que le plugin déclare, et la toolchain de la pile.
