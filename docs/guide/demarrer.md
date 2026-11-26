# Démarrer

[Guide](README.md) · [Démarrer](demarrer.md) · [Les flux](flux.md) · [Tests](tests.md) · [Garde-fous](garde-fous.md) · [Release](release.md)

## Prérequis

Izanagi n'a aucun prérequis de skill. Il lui faut :

- le CLI `gh`, connecté au compte qui porte le dépôt, et Git Bash sous Windows ;
- bash 4 ou plus récent. Le bash 3.2 livré avec macOS ne suffit pas aux scripts du plugin : installe un bash récent (`brew install bash`) ;
- les outils de la pile choisie (`cargo`, `node`, `uv`…), et `gitleaks` pour un projet qui a du code. `init` donne la commande d'installation d'un outil absent et attend ton accord avant de la lancer.

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

Dans un projet Izanagi, les skills `izanagi:*` priment sur les skills de même rôle d'un autre plugin, Superpowers compris. Le `CLAUDE.md` posé le dit.

## Installation

```bash
claude plugin marketplace add Alextradus/izanagi
```

```bash
claude plugin install izanagi@izanagi
```

Depuis un clone local, remplace `Alextradus/izanagi` par le chemin du clone : Claude Code lit alors les fichiers en place, et `/reload-plugins` prend une modification en compte.

## Poser le cadre : `/izanagi:init`

`/izanagi:init` se lance une fois par projet. Il reconnaît trois cas :

- **Un dossier vide.** Il mène un entretien de départ (deux séries de questions au plus) : ce que tu construis, pour qui, sur quels systèmes. Il recommande une pile, lance le créateur officiel de cette pile (`cargo init`, `npm create vite`, `uv init`…), pose le cadre, écrit un premier test par couche, puis propose `gh repo create` et ne le lance que sur ton accord.
- **Un projet existant sans Izanagi.** Il détecte les composants par leurs manifestes (`Cargo.toml`, `package.json`, `pyproject.toml`, ou du code d'une autre pile), te pose en une fois les questions qui restent (type d'application, spec, test manuel, vault, langue publique) et pose le cadre sans toucher au code. Il ne déclare que les couches de test dont le dossier a déjà des tests.
- **Un projet qui a déjà un cadre Izanagi.** Il s'arrête et te renvoie à `/izanagi:upgrade`.

`init` n'installe jamais un outil de lui-même : quand un outil manque, il donne la commande officielle et attend ton accord. Il n'écrase jamais un fichier : `scripts/install.sh` pose chaque gabarit manquant et compare les autres au gabarit, puis `init` te montre les écarts.

À la fin, `init` lance la vérification, contrôle le contrat de vérification et active le hook `pre-push` (`git config core.hooksPath .githooks`). Lance ensuite `/izanagi:doctor` : aucune ligne `écart` n'est attendue.

## Ce qu'un projet posé contient

`init` pose `CLAUDE.md`, `AGENTS.md`, `.izanagi/config.env`, `docs/agents/*` (tracker, libellés de tri, domaine, vault, harnais), un squelette de `docs/CODING_STANDARDS.md`, le hook `.githooks/pre-push`, `scripts/check.sh` et la CI. Un projet à plusieurs composants reçoit aussi `scripts/dev.sh`, qui les lance ensemble.

Un projet posé a trois fichiers propres à Izanagi :

- `.izanagi/config.env` porte les réglages, une valeur par ligne (`clé=valeur`) : version du cadre, chemin de la spec, lieu des décisions, dossier des plans, branche principale, commande de vérification, commande et lieu du test manuel, taille d'une tranche, chemins sensibles, fichier de version, chemin du vault ou `non`, une clé par hook, `navigateur` (`oui` quand une couche fonctionnelle emploie Playwright), les clés de la mutation, `mutation` et `mutation_delai`, et celles de la release, `langue_publique` et `version_composant`.
- `.izanagi/state.env` porte l'état du flux de la branche courante : flux, nom, phase, tranche, tour de revue, niveau de risque. Il est versionné sur la branche du flux, et la branche principale n'en porte jamais. Seul `scripts/state.sh` du plugin l'écrit.
- `docs/agents/harness.md` décrit le harnais : composants, systèmes cibles, type d'application, commande de déploiement, et le tableau des couches de test, avec le dossier et la commande de chaque couche de chaque composant.

Le journal d'un jalon, `.izanagi/journal/<plan>.md`, est versionné sur la branche du jalon. La clôture le supprime avec l'état, dans le dernier commit avant la fusion.

`AGENTS.md` donne à un autre agent de code la spec, la commande de vérification et les règles de relecture. Il ne décrit pas les flux d'Izanagi.

## Piles

Trois piles ont un gabarit complet : Rust, TypeScript avec Node (npm) et Python (uv). Pour chacune, `scripts/check.sh` lance l'installation depuis le verrou, le format, le lint, puis une étape par couche de test déclarée dans `harness.md`.

Pour une autre pile (Go, Java, C#, Swift…), `init` pose une section `# À ÉCRIRE` et la remplit en suivant `references/verification-contract.md`, qui fixe ce que `check.sh` et la CI doivent faire. Le script `check-contract.sh` du plugin contrôle ce contrat.

`scripts/check.sh` accepte trois options :

- `--host` vérifie le système courant seulement. Le hook pre-push l'utilise. Si le système courant n'est pas une cible, `check.sh` le saute ; sous Windows, il vérifie alors la copie WSL quand `linux` est une cible.
- `--complet` ajoute les couches fonctionnelles et se combine avec `--host`.
- `--clean` vide le cache WSL du projet.

Sous Windows, quand `linux` est un système cible, `check.sh` copie l'arbre de travail dans `~/.cache/<projet_dossier>-wsl` et y lance la vérification.

## Garder le cadre à jour

- `/izanagi:upgrade` met à jour le cadre d'un projet déjà posé. Il applique les migrations une à une sur une branche `task/izanagi-upgrade`, montre les écarts au gabarit, n'écrase un fichier modifié qu'avec ton accord et ouvre une PR. Le hook de démarrage t'avertit quand le cadre est en retard sur le plugin.
- `/izanagi:doctor` contrôle le poste et le cadre : outils, hooks, réglages, version du cadre, contrat de vérification, cohérence de l'état avec git. Il propose la correction de chaque écart.
- `/izanagi:status` liste les flux ouverts, d'après les branches `jalon/*`, `task/*` et `fix/*`, avec la phase, la tranche et le tour de revue de chacun.
