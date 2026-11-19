# Type : desktop

Application de bureau (Tauri, Electron, Qt, egui, WPF).

## Couches de test

- Unitaire : la logique, hors interface (`cargo test`, `vitest`, `pytest`).
- Intégration : les modules avec leurs vraies dépendances (fichiers, base locale), hors fenêtre (`cargo test` dans `tests/`, `vitest`, `pytest`).
- Fonctionnelle : sans objet par défaut, le test manuel en tient lieu. Un projet qui veut piloter la fenêtre réelle l'ajoute plus tard (Playwright pour Electron, `tauri-driver` pour Tauri). Ces tests demandent un affichage, et sous Linux la CI emploie `xvfb-run`.

## Test manuel par défaut

Lancer l'application en mode développement (`npm run tauri dev`, `npm start`, `cargo run`) sur chaque système cible, à la main.

## Sections de CODING_STANDARDS.md

- **Perte de données à la fermeture.** La fermeture de la fenêtre ou un plantage perd un travail non enregistré.
- **Écart entre systèmes.** Un chemin, un séparateur de ligne ou une police se comporte autrement sous Windows, Linux et macOS.
- **Appel bloquant sur le fil d'interface.** Une opération longue fige la fenêtre.

## Sécurité

Classes de failles que le relecteur sécurité cherche dans le diff, au niveau de risque élevé.

- **Pont trop large.** La couche web d'une application Tauri ou Electron gagne un accès au système de fichiers ou aux commandes qu'aucune fonction n'utilise, ou `nodeIntegration` est activé.
- **Contenu distant dans la fenêtre.** Une page chargée depuis le réseau reçoit les droits de l'application.
- **Stockage local en clair.** Un jeton ou une donnée personnelle est écrit dans un fichier de réglages plutôt que dans le trousseau du système.
- **Commande construite à partir d'une entrée.** Un nom de fichier ou un texte saisi entre dans une commande système sans échappement.
- **Mise à jour non vérifiée.** L'application télécharge et lance une mise à jour sans vérifier sa signature.

## Prérequis

La toolchain de la pile, plus les bibliothèques système du cadre graphique (WebView2 et outils C++ sous Windows, `libwebkit2gtk` sous Linux pour Tauri).
