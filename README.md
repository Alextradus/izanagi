# Izanagi

Plugin Claude Code qui pose le cadre de travail d'un projet et conduit ses jalons. Toute valeur propre à un projet se lit dans ses fichiers `docs/agents/`.

## Skills

- `/izanagi:init` pose dans le projet courant `CLAUDE.md`, `docs/agents/*` (tracker, libellés de tri, domaine, réglages de jalon, vault), un squelette de `docs/CODING_STANDARDS.md`, le hook `.githooks/pre-push`, et pour une pile connue `scripts/check.sh` et la CI. Une relance pose ce qui manque, n'écrase rien et montre les écarts au gabarit.
- `/izanagi:jalon [phase]` conduit un jalon : cadrage, plan, tranches, revue de jalon, test, clôture. Chaque tranche passe une revue convergente (trois tours au plus, re-revue sur le seul diff des corrections). `/izanagi:jalon convergente` lance cette revue seule, pour une PR hors jalon.

Les réglages d'un projet sont dans `docs/agents/jalon.md` : chemin de la spec, lieu des décisions, branche principale, commande de vérification, commande et lieu du test manuel, taille d'une tranche, fichier de version, chemin du vault ou `non`.

Piles : le cœur sert à tout projet. Rust a son gabarit (`scripts/check.sh` lance format, clippy et tests sous Windows puis WSL ; CI Linux et Windows). Pour une autre pile, `scripts/check.sh` et la CI restent à écrire.

## Prérequis

Le plugin lance ces skills sans les copier. Installe-les avant le premier jalon :

- les skills de Matt Pocock (`mattpocock-skills:*`) : `grilling`, `domain-modeling`, `prototype`, `research`, `codebase-design`, `tdd`, `diagnosing-bugs`, `resolving-merge-conflicts`, `code-review`, `wizard` ;
- Superpowers (`superpowers:*`) : `brainstorming`, `writing-plans`, `subagent-driven-development`, `finishing-a-development-branch` ;
- `retro`, proposé à la clôture d'un jalon ;
- le CLI `gh`, connecté au compte qui porte le dépôt, et Git Bash sous Windows.

## Installation

```bash
claude plugin marketplace add Alextradus/izanagi
```

```bash
claude plugin install izanagi@izanagi
```

Depuis un clone local, remplace `Alextradus/izanagi` par le chemin du clone : Claude Code lit alors les fichiers en place, et `/reload-plugins` prend une modification en compte.

## Feuille de route

Hors v0.1 :

- un template de PR ;
- des niveaux de risque, qui règlent la profondeur de revue d'une tranche ;
- le traitement des bugs du test manuel quand le projet a des évals.

## Contribuer

Izanagi n'a pas de jalons. Chaque changement passe par une PR, relue par `/izanagi:jalon convergente`. La version suit semver dans `.claude-plugin/plugin.json`, avec un tag `vX.Y.Z` par version. Avant de pousser :

```bash
claude plugin validate .
```
