# Guide d'Izanagi

Le [README](../../README.md) donne les bases : installer le plugin, poser un projet, le workflow de tous les jours. Ce guide entre dans le détail.

| Page | Ce qu'elle couvre |
|---|---|
| [Démarrer](demarrer.md) | prérequis, installation, `/izanagi:init` dans un dossier vide ou un projet existant, les fichiers posés, les piles, `upgrade`, `doctor` et `status` |
| [Les flux](flux.md) | le schéma du workflow, le jalon phase par phase, `task`, `fix`, la revue convergente, les niveaux de risque, l'attente de la CI, la rétrospective, les skills internes et les sous-agents |
| [Tests](tests.md) | les trois couches de test, la double boucle, la mutation, les règles par langage |
| [Garde-fous](garde-fous.md) | les quatre hooks et la sécurité posée dans le projet |
| [Release](release.md) | le changelog, la release GitHub, le livrable par type d'application, le déploiement |

## Vocabulaire

- **Cadre** : ce qu'`init` pose dans un projet (réglages, vérification, CI, hooks, conventions).
- **Flux** : un travail conduit par Izanagi sur sa branche, jusqu'à la PR fusionnée : un jalon, un petit changement (`task`) ou un correctif (`fix`).
- **Jalon** : une fonctionnalité livrée en plusieurs tranches, du cadrage au tag.
- **Tranche** : une part d'un jalon, avec sa branche, sa revue, sa PR et son test par toi.
- **Couture** : l'interface par laquelle un test prouve un comportement (une fonction publique, une route, la ligne de commande).
- **Couche de test** : unitaire, intégration ou fonctionnelle, selon ce que le test traverse.
- **Revue convergente** : des relecteurs en parallèle, puis des tours de correction jusqu'à un tour sans constat Important.
- **Niveau de risque** : faible, normal ou élevé ; il règle la profondeur de la revue et le test manuel.
- **Journal** : la trace d'un flux, versionnée sur sa branche, que la rétrospective lit.

## Les décisions

Chaque comportement du plugin vient d'une décision numérotée d'une spec de `docs/specs/`. Le critère de la 1.0 est dans [`2026-11-26-izanagi-1.0-critere.md`](../specs/2026-11-26-izanagi-1.0-critere.md).
