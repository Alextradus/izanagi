# Type : desktop

Application de bureau (Tauri, Electron, Qt, egui, WPF).

## Couches de test

- Tests unitaires de la logique, hors interface (`cargo test`, `vitest`, `pytest`).
- Tests de la fenêtre : pilotage de l'interface réelle (Playwright pour Electron, `tauri-driver` pour Tauri). Ils demandent un affichage ; sous Linux, la CI utilise `xvfb-run`.

## Test manuel par défaut

Lancer l'application en mode développement (`npm run tauri dev`, `npm start`, `cargo run`) sur chaque système cible, à la main.

## Sections de CODING_STANDARDS.md

- **Perte de données à la fermeture.** La fermeture de la fenêtre ou un plantage perd un travail non enregistré.
- **Écart entre systèmes.** Un chemin, un séparateur de ligne ou une police se comporte autrement sous Windows, Linux et macOS.
- **Appel bloquant sur le fil d'interface.** Une opération longue fige la fenêtre.

## Prérequis

La toolchain de la pile, plus les bibliothèques système du cadre graphique (WebView2 et outils C++ sous Windows, `libwebkit2gtk` sous Linux pour Tauri).
