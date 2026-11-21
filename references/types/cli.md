# Type : cli

Outil en ligne de commande.

## Couches de test

- Unitaire : la logique, sans entrée-sortie (`cargo test`, `vitest`, `pytest`).
- Intégration : les modules avec le vrai système de fichiers, dans un dossier temporaire que le test crée (`cargo test` dans `tests/`, `vitest`, `pytest` avec `tmp_path`).
- Fonctionnelle : le binaire lancé avec des arguments. Le test vérifie le code de sortie, stdout et stderr (`assert_cmd` en Rust, `execa` avec vitest, `subprocess` avec pytest).

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

## Livrable

La release publie ce que la pile du composant produit, selon les systèmes de `systemes`.

- Rust : une archive des binaires par système, construite par `cargo build --release` sur ce système et jointe à la release.
- TypeScript : le paquet, publié sur npm.
- Python : le paquet, publié sur PyPI.

La publication sur un registre passe par la publication de confiance, sans jeton stocké en secret. Elle se configure côté registre (npmjs.com, PyPI), et seul l'utilisateur peut le faire. Le skill `wizard` guide cette configuration, à faire avant le premier tag.

## Prérequis

La toolchain de la pile (rustup, node, uv). Aucun outil de plus.
