# Type : api

API ou service réseau, sans interface graphique.

## Couches de test

- Tests unitaires de la logique métier (`cargo test`, `vitest`, `pytest`).
- Tests d'intégration des routes : requête HTTP réelle contre le service lancé sur un port local, avec une base de test (`supertest` avec vitest, `httpx` avec pytest, `reqwest` en Rust).

## Test manuel par défaut

Lancer le service (`npm run dev`, `uv run fastapi dev`, `cargo run`), puis appeler une route avec `curl` depuis un second terminal.

## Sections de CODING_STANDARDS.md

- **Entrée non validée.** Une route accepte un corps ou un paramètre sans contrôle de type ni de taille.
- **Contrat cassé.** Un champ de réponse change de nom ou de type sans que les clients soient prévenus.
- **Migration non rejouable.** Un changement de schéma échoue sur une base déjà migrée, ou perd des données.
- **Secret dans le dépôt.** Une clé ou un mot de passe est écrit dans le code ou dans un fichier suivi.

## Sécurité

Classes de failles que le relecteur sécurité cherche dans le diff, au niveau de risque élevé.

- **Injection.** Une entrée de la requête entre dans une requête SQL, une commande système ou un chemin de fichier sans paramètre lié ni validation.
- **Contrôle d'accès absent.** Une route lit ou modifie une ressource sans vérifier que l'appelant y a droit, ou se fie à un identifiant fourni par le client.
- **Authentification affaiblie.** Un jeton n'est pas vérifié (signature, expiration, audience), ou un mot de passe est stocké sans hachage lent.
- **Fuite dans les réponses ou les journaux.** Une erreur renvoie une trace interne, ou un journal écrit un jeton, un mot de passe ou une donnée personnelle.
- **Requête vers une adresse fournie.** Le service appelle une URL donnée par le client sans liste d'hôtes permis.
- **Secret dans le dépôt.** Une clé ou un mot de passe est écrit dans le code ou dans un fichier suivi.

## Prérequis

La toolchain de la pile, et la base de données de test (service local, conteneur ou SQLite). Ajoute le port utilisé à la documentation du projet.
