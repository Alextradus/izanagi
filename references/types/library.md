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

## Sécurité

Classes de failles que le relecteur sécurité cherche dans le diff, au niveau de risque élevé.

- **Défaut non sûr.** Une fonction publique désactive par défaut une vérification (certificat TLS, échappement, limite de taille).
- **Entrée non bornée.** Une fonction publique accepte une entrée sans limite de taille ou de profondeur, et un appelant peut épuiser la mémoire ou le processeur.
- **Désérialisation non sûre.** La bibliothèque charge des données par un format qui exécute du code.
- **Dépendance ajoutée sans besoin.** Le diff ajoute une dépendance que tous les clients hériteront, pour un usage marginal.
- **Script d'installation.** Le paquet gagne un script lancé à l'installation (`postinstall`, `build.rs` qui télécharge).

## Prérequis

La toolchain de la pile. Pour publier : un compte sur le registre (crates.io, npm, PyPI). `init` ne publie rien.
