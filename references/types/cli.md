# Type : cli

Outil en ligne de commande.

## Couches de test

- Tests unitaires de la logique, sans entrée-sortie (`cargo test`, `vitest`, `pytest`).
- Tests de bout en bout du binaire : lancer la commande avec des arguments et vérifier le code de sortie, stdout et stderr (`assert_cmd` en Rust, `execa` avec vitest en TypeScript, `subprocess` avec pytest en Python).

## Test manuel par défaut

Lancer la commande avec un cas réel, dans un terminal, depuis le dossier du projet (`cargo run -- <args>`, `npm run dev`, `uv run <commande>`).

## Sections de CODING_STANDARDS.md

- **Code de sortie faux.** Une erreur sort avec 0, ou un succès avec un code non nul.
- **Écriture sur le mauvais flux.** Un message d'erreur part sur stdout, ou une donnée sur stderr, et casse les tubes.
- **Destruction sans confirmation.** La commande écrase ou supprime des fichiers sans option explicite.

## Prérequis

La toolchain de la pile (rustup, node, uv). Aucun outil de plus.
