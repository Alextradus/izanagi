# Izanagi

Plugin Claude Code qui pose le cadre de travail d'un projet et conduit ses jalons. Toute valeur propre à un projet se lit dans ses fichiers `docs/agents/`.

## Skills

- `/izanagi:init` démarre un projet de toute pile et pose son cadre. Il sait traiter quatre cas :
  - Dans un dossier vide, il mène un entretien de départ, recommande une pile, lance le créateur officiel de cette pile, puis propose `gh repo create` et ne le lance que sur ton accord.
  - Dans un projet existant, il détecte les composants et pose le cadre sans toucher au code.
  - Sur une relance, il pose ce qui manque, n'écrase rien et montre les écarts au gabarit.
  - Sur un projet 0.1, il propose de reprendre `scripts/check.sh` et la CI du gabarit 0.2.
- `/izanagi:jalon [phase]` conduit un jalon : cadrage, plan, tranches, revue de jalon, test, clôture. Chaque tranche passe une revue convergente (trois tours au plus, re-revue sur le seul diff des corrections). `/izanagi:jalon convergente` lance cette revue seule, pour une PR hors jalon.
- `/izanagi:grilling [sujet]` t'interroge par tours sur un plan ou une décision, jusqu'à ce que chaque point soit tranché. Le cadrage d'un jalon le lance aussi.

Les phases d'un jalon chargent huit autres skills du plugin, absents du menu des commandes : `brainstorming` écrit la spec, `domain-modeling` tient `CONTEXT.md`, `planning` écrit le plan en tranches, `task-loop` exécute les tâches d'une tranche, `tdd` fixe les règles de test, `review` conduit la revue convergente, `diagnosing` cherche la cause d'un bug et `merge-conflicts` résout un conflit. Quatre sous-agents font le travail délégué : `implementer`, `reviewer-standards`, `reviewer-spec` et `diagnostician`. Les deux relecteurs sont en lecture seule.

`init` pose `CLAUDE.md`, `docs/agents/*` (tracker, libellés de tri, domaine, réglages de jalon, vault, harnais), un squelette de `docs/CODING_STANDARDS.md`, le hook `.githooks/pre-push`, `scripts/check.sh` et la CI. Un projet à plusieurs composants reçoit aussi `scripts/dev.sh`, qui les lance ensemble.

Les réglages d'un projet sont dans `docs/agents/jalon.md` : chemin de la spec, lieu des décisions, branche principale, commande de vérification, commande et lieu du test manuel, taille d'une tranche, fichier de version, chemin du vault ou `non`. `docs/agents/harness.md` décrit le harnais : composants, systèmes cibles, type d'application et couches de test.

## Piles

Trois piles ont un gabarit complet : Rust, TypeScript avec Node (npm) et Python (uv). Pour chacune, `scripts/check.sh` lance l'installation depuis le verrou, le format, le lint et les tests, et la CI exécute `check.sh --host` sur chaque système cible.

Pour une autre pile (Go, Java, C#, Swift…), `init` pose une section `# À ÉCRIRE` et la remplit en suivant `references/verification-contract.md`, qui fixe ce que `check.sh` et la CI doivent faire. Le script `check-contract.sh` du plugin contrôle ce contrat.

`scripts/check.sh` accepte deux options :

- `--host` vérifie le système courant seulement. Le hook pre-push l'utilise. Si le système courant n'est pas une cible, `check.sh` le saute ; sous Windows, il vérifie alors la copie WSL quand `linux` est une cible.
- `--clean` vide le cache WSL du projet.

Sous Windows, quand `linux` est un système cible, `check.sh` copie l'arbre de travail dans `~/.cache/<projet_dossier>-wsl` et y lance la vérification.

## Prérequis

Izanagi n'a aucun prérequis de skill. Il lui faut :

- le CLI `gh`, connecté au compte qui porte le dépôt, et Git Bash sous Windows ;
- les outils de la pile choisie (`cargo`, `node`, `uv`…). `init` donne la commande d'installation d'un outil absent et attend ton accord avant de la lancer.

### Skills optionnels

Quatre skills du plugin `mattpocock-skills` aident à certaines étapes. Un jalon les lance s'ils sont installés et fait sinon un geste de remplacement :

- `codebase-design` aide à choisir la forme d'une couture pendant le plan ;
- `prototype` répond à une question du cadrage par un essai exécutable ;
- `research` établit un fait sur un outil ou une bibliothèque ;
- `wizard` guide une étape que toi seul peux faire, comme créer un jeton ou un secret de CI.

`init` signale ceux qui manquent et propose de les installer :

```bash
claude plugin install mattpocock-skills
```

La clôture d'un jalon propose aussi `/retro`, si tu as un skill de ce nom.

Dans un projet Izanagi, les skills `izanagi:*` priment sur les skills de même rôle d'un autre plugin, Superpowers compris. Le `CLAUDE.md` posé le dit.

## Installation

```bash
claude plugin marketplace add Alextradus/izanagi
```

```bash
claude plugin install izanagi@izanagi
```

Depuis un clone local, remplace `Alextradus/izanagi` par le chemin du clone : Claude Code lit alors les fichiers en place, et `/reload-plugins` prend une modification en compte.

## Feuille de route

`docs/specs/2026-11-12-izanagi-harness-design.md` fixe les deux versions suivantes :

- la 0.4 apporte un état du flux versionné, trois hooks, `status`, `doctor`, `upgrade` et un `AGENTS.md` ;
- la 0.5 apporte les niveaux de risque, qui règlent la profondeur de revue, et les flux `task` et `fix`.

Restent sans version prévue : un template de PR, la release et le déploiement d'un projet, et des évals du plugin sur un projet témoin.

## Contribuer

Izanagi n'a pas de jalons. Chaque changement passe par une PR, relue par `/izanagi:jalon convergente`. La version suit semver dans `.claude-plugin/plugin.json`, avec un tag `vX.Y.Z` par version. Avant de pousser :

```bash
claude plugin validate .
```

```bash
bash tests/install.sh && bash tests/check-contract.sh && bash tests/skills.sh
```

`tests/skills.sh` contrôle la structure du plugin : les onze skills, les quatre sous-agents, les outils des relecteurs et l'absence de renvoi à un skill externe obligatoire.

Les skills et les sous-agents dérivent des skills de Matt Pocock et de Superpowers, tous deux sous licence MIT. `NOTICE` cite les deux sources.
