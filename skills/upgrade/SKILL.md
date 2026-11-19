---
name: upgrade
description: Mettre à jour le cadre Izanagi d'un projet déjà posé. Applique les migrations une à une sur une branche, montre les écarts au gabarit et ouvre une PR.
disable-model-invocation: true
---

# Upgrade

Tu mets à jour le cadre d'un projet qui a déjà Izanagi. Les scripts de `${CLAUDE_PLUGIN_ROOT}/scripts/migrations/` font les migrations, `install.sh` compare le projet au gabarit. Toi, tu enchaînes les étapes, tu lis les écarts et tu rends compte. Tu n'écrases un fichier modifié par le projet qu'avec l'accord de l'utilisateur.

Tout se fait sur une branche `task/izanagi-upgrade` et finit par une PR. Tu ne pousses rien sur la branche principale.

## 1. Situer le projet

Lis la version du cadre, la première ligne qui s'applique :

| Constat | Version du cadre |
|---|---|
| `.izanagi/config.env` existe | sa clé `izanagi_version` |
| `docs/agents/jalon.md` existe | avant la 0.4 |
| aucun des deux | pas de cadre : renvoie à `/izanagi:init` et arrête-toi |

Lis la version du plugin dans `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`.

Arrête-toi, en disant pourquoi, si :

- l'arbre de travail a des changements non commités (`git status --porcelain`), hors des journaux non suivis de `.izanagi/journal/` ;
- la branche courante porte un flux en cours (`bash "${CLAUDE_PLUGIN_ROOT}/scripts/state.sh" get` affiche un état) ;
- le dépôt n'a pas de dépôt distant, puisque la mise à jour finit par une PR.

Reviens ensuite sur la branche principale à jour et crée `task/izanagi-upgrade`. Chaque commit de la mise à jour va sur cette branche, y compris quand il n'y a aucune migration à lancer.

Fin : tu es sur `task/izanagi-upgrade`, et tu annonces en une ligne la version du cadre, celle du plugin et les migrations à lancer.

## 2. Migrer

Si la version du cadre vaut celle du plugin, il n'y a pas de migration à lancer : passe à la section 3.

1. Liste les scripts de `${CLAUDE_PLUGIN_ROOT}/scripts/migrations/`. Chacun porte dans son nom la version qu'il atteint (`0.4.0.sh`). Garde ceux dont la version dépasse celle du cadre, dans l'ordre des versions. Un cadre d'avant la 0.4 les prend tous.
2. Pour chaque script, dans l'ordre :

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/migrations/<version>.sh" <racine du projet>
   ```

   Lis sa sortie. Une ligne `à fusionner <fichier>` désigne un fichier du projet que le script n'a pas réécrit : la section 3 le traite. Une ligne `non reconnu : …` cite une ligne de l'ancien `docs/agents/jalon.md` que le script n'a pas su lire, et une ligne `à compléter : <clé>` une clé restée vide dans `.izanagi/config.env`. Une ligne `à ranger   <chemin>` cite un fichier de test que la migration 0.7.0 n'a mis dans aucune couche : garde la liste pour la section 3. Montre les lignes `non reconnu` et `à compléter` à l'utilisateur, remplis la clé avec sa réponse, puis supprime `docs/agents/jalon.md` avec `git rm`, sur son accord. Commite ensuite (`chore(izanagi): migration <version>`), en nommant à `git add` les fichiers des lignes `écrit`, jamais avec `git add -A`. Les fichiers des lignes `supprimé` sont déjà en index, et les nommer à `git add` ferait échouer la commande. Contrôle avec `git status --short` que l'index ne contient aucun journal avant de commiter.
3. Si `izanagi_version` de `.izanagi/config.env` est encore en retard sur le plugin après la dernière migration, écris-y la version du plugin et commite.

**Journaux.** La migration 0.4.0 cesse de faire ignorer `.izanagi/journal/*.md` par git, et peut y déplacer un journal d'avant la 0.3 (ligne `déplacé`). Ces journaux apparaissent alors comme fichiers non suivis. Ne les commite pas sur `task/izanagi-upgrade` : la branche principale ne porte jamais de journal. Chacun appartient à la branche de son jalon, où il se commite après la mise à jour.

Fin : chaque migration a son commit, `izanagi_version` vaut la version du plugin, et aucun journal n'est commité.

## 3. Comparer au gabarit

Écris un fichier de valeurs dans le scratchpad, une valeur par ligne :

- chaque ligne `clé=valeur` de `.izanagi/config.env`, hors commentaires ;
- de `docs/agents/harness.md` : chaque ligne `- composant : <nom> | <chemin> | <pile> | <lancement>` devient `composant=<nom>|<chemin>|<pile>|<lancement>|<couches>|<ancienne>`, sans les espaces autour des `|`. `<couches>` liste, séparées par des virgules et dans l'ordre du fichier, les couches des lignes `- couche : <nom> | <couche> | <dossier> | <commande>` de ce composant (`unitaire,integration`). Pour un composant Python ou TypeScript, `<ancienne>` est la commande de sa ligne `- couche : <nom> | unitaire | …`, que la migration 0.7.0 a copiée de l'ancien `check.sh` : tant que la couche unitaire du gabarit ne peut pas tourner (Python sans test dans `tests/unitaires/`, TypeScript sans script `test:unitaire` dans `package.json`), `install.sh` garde cette commande dans l'étape unitaire, et la vérification reste verte sans déplacer de test. Pour un composant Rust ou d'une autre pile, laisse `<ancienne>` vide. Une ligne `- couche : projet | fonctionnelle | <dossier> | <commande>` donne `fonctionnel_projet=<dossier>|<commande>`. Hors de `<ancienne>`, ne lis que les deux premiers champs des lignes d'un composant : la commande d'une couche Rust est une phrase, pas une commande à lancer. La ligne « Systèmes cibles » donne `systemes`, et le type donne `type` ;
- `projet_dossier` : le nom avant `-wsl` ou `-target` dans la ligne `.cache/` de `scripts/check.sh`.

Tu compares ainsi le projet au gabarit à valeurs égales : un écart affiché vient du gabarit ou d'un ajout du projet, jamais d'une valeur changée.

**Projet sans `harness.md`**, posé en 0.1. Détecte les composants comme `/izanagi:init` le fait pour un projet existant (un `Cargo.toml` donne `rust`, un `package.json` donne `typescript`, un `pyproject.toml` donne `python`). Dans `.github/workflows/ci.yml`, `ubuntu-latest` donne `linux`, `windows-latest` donne `windows` et `macos-latest` donne `macos`. Demande à l'utilisateur le type d'application, parmi les fiches de `${CLAUDE_PLUGIN_ROOT}/references/types/`.

Lance ensuite :

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/install.sh" <racine du projet> <fichier de valeurs>
```

Le script pose les fichiers qui manquent (`créé`) et écrit un rapport pour ceux qui diffèrent (`différent`). Pour chaque fichier `différent`, lis `<rapport>/diff/<chemin>.diff`. Le côté `projet/` est le fichier en place, le côté `gabarit/` le gabarit rendu. Classe chaque bloc :

- **Ajout du projet** (lignes en `-` seules) : du contenu propre au projet, comme une règle de `CODING_STANDARDS.md`. C'est attendu ; résume-le en une ligne.
- **Manque au projet** (lignes en `+` seules) : une convention du gabarit absente du projet. Cite-la et propose de l'ajouter.
- **Divergence** (les deux) : le projet et le gabarit disent la même chose autrement. Cite les deux versions.

Tu fais la modification que l'utilisateur désigne, et elle seule. Pour reprendre un fichier en entier, remplace-le par `<rapport>/rendu/<chemin>`.

Ce que chaque version a changé dans les gabarits, à présenter ainsi :

- **Depuis la 0.2**, pour un projet posé en 0.1 seulement. `scripts/check.sh` et `.github/workflows/ci.yml` vérifient par composant, acceptent `--host` et `--clean`, et la CI tourne en matrice de systèmes. Propose de les reprendre en entier. La 0.1 gardait les builds Rust de WSL dans `~/.cache/<projet_dossier>-target`, que `check.sh` n'utilise plus. Sous Windows, propose de supprimer ce cache, et lance sur l'accord de l'utilisateur :

  ```bash
  wsl.exe --exec bash -c 'rm -rf "$HOME/.cache/<projet_dossier>-target"'
  ```

- **Depuis la 0.3.** `CLAUDE.md` dit que les skills `izanagi:*` priment sur tout autre skill de même rôle. `docs/agents/domain.md` nomme `izanagi:domain-modeling`. Si le projet a un vault, `docs/agents/vault.md` nomme les lignes `Décision :` du journal.
- **Depuis la 0.4.** `CLAUDE.md` renvoie à `.izanagi/config.env`. `AGENTS.md` est nouveau. Dans `docs/CODING_STANDARDS.md`, la liste des chemins hors revue cite `.izanagi/` : ajoute ce chemin à celle du projet et garde le chemin de ses plans.

- **Depuis la 0.5.** `.izanagi/config.env` porte la clé `chemins_sensibles`, que la migration ajoute vide. Demande à l'utilisateur où sont les données, la sécurité, les migrations et l'API publique du projet, et écris les motifs qu'il donne, séparés par des virgules (`db/migrations/*, src/auth/*`). Un diff qui touche un de ces chemins passe la revue du niveau de risque élevé (`${CLAUDE_PLUGIN_ROOT}/references/risk.md`). La clé peut rester vide.
- **Depuis la 0.6.** La migration ajoute `hook_destructif=demande` à `.izanagi/config.env` et `refus.log` à `.izanagi/.gitignore`, et pose `.claude/settings.json`. Si elle affiche `à fusionner .claude/settings.json`, le projet a déjà ce fichier : ajoute à sa liste `permissions.deny` les règles qui lui manquent, avec l'outil Edit, dans l'ordre de `${CLAUDE_PLUGIN_ROOT}/templates/core/.claude/settings.json`, sans toucher aux autres clés. La pose crée `.gitleaks.toml`, `.github/dependabot.yml`, `.github/workflows/securite.yml` et un `docs/standards/<langage>.md` par pile. `scripts/check.sh` gagne la recherche de secrets, et `.github/workflows/ci.yml` les actions épinglées par SHA, l'installation de `gitleaks` et le job `audit` : propose de les reprendre en entier, en gardant les commandes qu'une pile sans gabarit a écrites. Rappelle d'installer `gitleaks` (`/izanagi:doctor` donne la commande). Liste ensuite les lignes de `docs/CODING_STANDARDS.md` qui nomment une construction propre à un langage (un mot-clé, un type de la bibliothèque standard, un outil de la pile), et propose de déplacer chacune dans `docs/standards/<langage>.md`, une par une, sur l'accord de l'utilisateur.

  Pour chaque `docs/standards/<langage>.md`, compare les règles de la section `## À proposer au plugin` à celles de `${CLAUDE_PLUGIN_ROOT}/references/langages/<langage>.md`. Une règle que le plugin porte désormais, même reformulée, se retire du projet : montre les deux versions et retire-la sur l'accord de l'utilisateur.
- **Depuis la 0.7.** La migration écrit dans `.izanagi/config.env` la clé `mutation` (`oui` quand toutes les piles des composants ont un gabarit), `mutation_delai=15` et `navigateur` (`oui` si un `playwright.config.*` existe). Dans `docs/agents/harness.md`, elle remplace la ligne « Couches de test » par la section des couches : chaque composant y reçoit la couche unitaire avec son ancienne commande de tests, et une couche intégration ou fonctionnelle quand son dossier contient déjà des tests. Elle n'écrit ni `scripts/check.sh` ni `.github/workflows/ci.yml`. Le fichier de valeurs prend donc les couches dans les lignes `- couche :` de `harness.md`, comme le dit le début de cette section.

  `scripts/check.sh` et `.github/workflows/ci.yml` sortent `différent`. Montre l'écart de chacun : le gabarit lance une étape `-- <composant> : <couche>` par couche déclarée à la place de l'étape `tests`, accepte `--complet`, et la CI lance `bash scripts/check.sh --host --complet` et gagne le job `couverture`. Dis à l'utilisateur qu'un `ci.yml` posé en 0.6 lance `--host` seul : `check-contract.sh` le signale (règle 7) tant que `ci.yml` n'est pas repris du gabarit. Propose de reprendre les deux fichiers en entier, en gardant les commandes qu'une pile sans gabarit a écrites. Tant que la couche unitaire du gabarit ne peut pas tourner, l'étape unitaire reprise garde l'ancienne commande de tests du projet, et `harness.md` sort `identique`.

  Liste ensuite les lignes `à ranger` de la migration. Chacune est un fichier de test hors du dossier de toute couche, que la migration n'a pas déplacé. Ne le déplace pas non plus (décision 114) : propose à l'utilisateur une tâche du projet (`/izanagi:task`) qui range ces fichiers dans le dossier de leur couche. La migration ne déclare pas une couche que la commande du gabarit ne saurait lancer : un dossier `tests/integration/` TypeScript sans script `test:integration`, ou un `tests/fonctionnel_*.rs` sans feature `fonctionnel`, donne des lignes `à ranger`.

  Dans cette tâche, une fois les fichiers rangés, le projet ajoute ce que la commande du gabarit attend, et une ligne `- couche :` dans `harness.md` pour chaque couche nouvelle, puis relance `/izanagi:upgrade` pour reprendre `check.sh` et `harness.md` avec les couches rangées :

  - TypeScript : dans `package.json`, les scripts `test:unitaire`, `test:integration` et `test:fonctionnel` des couches déclarées, et dans la configuration Vitest un projet `test.projects` par couche (`unitaire`, `integration`, `fonctionnel`), comme le décrit `${CLAUDE_PLUGIN_ROOT}/references/interview.md` ;
  - Python : les dossiers `tests/unitaires/`, `tests/integration/` et `tests/fonctionnels/`, sans deux fichiers de test du même nom ;
  - Rust : pour une couche fonctionnelle, la feature `fonctionnel = []` dans `[features]` de `Cargo.toml` et une entrée `[[test]]` avec `required-features = ["fonctionnel"]` par fichier `tests/fonctionnel_<nom>.rs`. Les couches unitaire et intégration de Rust ne demandent rien.

  Rappelle de lancer `/izanagi:doctor` : il contrôle l'outil de mutation de chaque pile quand `mutation=oui` (`cargo-mutants`, Stryker, `mutmut`) et les navigateurs Playwright quand une couche fonctionnelle les emploie, et donne la commande d'installation.

Une pile sans gabarit rend toujours `check.sh` et `ci.yml` `différent`, car le gabarit garde `# À ÉCRIRE` là où le projet a ses commandes. Ne classe pas ces blocs : le contrôle de la section 4 les couvre.

Si `docs/agents/harness.md` vient d'être créé, chaque composant n'y a que la couche unitaire. Propose d'ajouter les couches de la fiche du type que le projet teste déjà, en écrivant le cinquième champ de chaque `composant=`, puis relance `install.sh`.

Commite les reprises acceptées (`chore(izanagi): cadre <version du plugin>`), en nommant à `git add` les fichiers créés ou repris.

Fin : chaque écart est repris ou laissé sur décision de l'utilisateur.

## 4. Contrôler

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-contract.sh" <racine du projet>
```

Chaque ligne `contrat : <fichier> : <règle>` est un écart. Rapporte-le et propose la correction, que tu fais sur l'accord de l'utilisateur.

Lance ensuite `bash scripts/check.sh --host --complet`, comme la CI. S'il échoue, rapporte l'échec tel quel, sans le masquer ni l'attribuer à la mise à jour sans preuve.

Pour chaque `scripts/*.sh` et `.githooks/*` créé ou repris, lance `git add --chmod=+x <fichier>`.

Fin : tu connais le résultat du contrôle du contrat et de `check.sh --host --complet`.

## 5. Ouvrir la PR

Pousse `task/izanagi-upgrade` et ouvre la PR vers la branche principale (`gh pr create`, corps passé par `--body-file`). Le corps liste les migrations lancées, les fichiers repris, les écarts laissés avec leur raison, et colle la sortie de `check.sh --host --complet`.

Rends compte à l'utilisateur :

- la version de départ et la version atteinte ;
- les migrations et ce que chacune a fait ;
- les écarts repris et ceux laissés ;
- ce qui reste à faire après la fusion : sur chaque branche de flux ouverte (`jalon/*`, `task/*`, `fix/*`), fusionner la branche principale pour y amener le nouveau cadre. `/izanagi:jalon` crée ensuite l'état d'un jalon commencé avant la 0.4 ;
- les journaux restés non suivis dans `.izanagi/journal/`, à commiter chacun sur la branche de son jalon.

Fin : la PR est ouverte et l'utilisateur a le bilan.
