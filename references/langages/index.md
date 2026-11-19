# Règles par langage

Le relecteur Standards et l'implémenteur lisent ce fichier pour savoir quelles règles valent pour les fichiers d'un diff. Pour chaque langage présent, ils lisent deux couches :

- le fichier du plugin, quand la table en donne un : des règles générales, valables pour tout projet ;
- `docs/standards/<langage>.md` du projet : ses ajouts, et ses exceptions aux règles du plugin, écrites `Écarte : R<n>, parce que <raison>`.

Un langage sans fichier du plugin n'a que les règles du projet.

| Extensions | Langage | Fichier du plugin |
|---|---|---|
| `.rs` | rust | `rust.md` |
| `.ts`, `.tsx`, `.js`, `.jsx`, `.mjs`, `.cjs` | typescript | `typescript.md` |
| `.py` | python | `python.md` |
| `.php` | php | aucun |

Les règles ne portent que sur des jugements qu'aucun outil ne vérifie : rien de ce que `clippy`, `eslint` avec sa configuration recommandée ou `ruff` avec ses règles par défaut attrapent déjà. Chaque règle a un numéro stable, une phrase, un exemple et sa source.
