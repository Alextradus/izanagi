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

## Sécurité

Classes de failles que le relecteur sécurité cherche dans le diff, au niveau de risque élevé.

- **Commande construite à partir d'une entrée.** Un argument ou le contenu d'un fichier entre dans une commande shell sans échappement.
- **Chemin hors du dossier attendu.** Un chemin lu dans une archive ou un fichier d'entrée contient `..` ou un chemin absolu, et l'outil écrit hors du dossier cible.
- **Désérialisation non sûre.** Un fichier d'entrée est chargé par un format qui exécute du code (`pickle`, `yaml.load` sans chargeur sûr).
- **Secret en argument ou dans la sortie.** Un jeton passe par la ligne de commande, visible dans la liste des processus, ou s'affiche dans la sortie ou un journal.
- **Fichier temporaire prévisible.** Un fichier temporaire a un nom fixe dans un dossier partagé, au lieu de `mktemp` ou de l'équivalent de la pile.

## Prérequis

La toolchain de la pile (rustup, node, uv). Aucun outil de plus.
