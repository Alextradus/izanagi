# Type : library

Bibliothèque publiée pour d'autres développeurs (crate, paquet npm, paquet PyPI).

## Couches de test

- Tests unitaires de chaque fonction publique (`cargo test`, `vitest`, `pytest`).
- Tests d'API publique : un exemple ou un test qui importe la bibliothèque comme un client, sans accès aux éléments privés (`tests/` en Rust, doctests, un projet d'exemple).

## Test manuel par défaut

Écrire un court programme d'essai qui importe la bibliothèque, depuis un dossier voisin du projet, et l'exécuter.

## Sections de CODING_STANDARDS.md

- **Rupture d'API publique.** Un renommage ou une signature modifiée casse les clients sans changement de version majeure.
- **Panique ou exception non documentée.** Une fonction publique plante sur une entrée valide ou n'annonce pas ses erreurs.
- **Dépendance superflue.** Le paquet impose à ses clients une dépendance lourde pour un usage marginal.

## Prérequis

La toolchain de la pile. Pour publier : un compte sur le registre (crates.io, npm, PyPI). `init` ne publie rien.
