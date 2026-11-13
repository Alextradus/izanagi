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

   Lis sa sortie. Une ligne `non reconnu : …` cite une ligne de l'ancien `docs/agents/jalon.md` que le script n'a pas su lire, et une ligne `à compléter : <clé>` une clé restée vide dans `.izanagi/config.env`. Montre-les à l'utilisateur, remplis la clé avec sa réponse, puis supprime `docs/agents/jalon.md` avec son accord. Commite ensuite (`chore(izanagi): migration <version>`), en nommant à `git add` les fichiers des lignes `écrit`, jamais avec `git add -A`. Les fichiers des lignes `supprimé` sont déjà en index, et les nommer à `git add` ferait échouer la commande. Contrôle avec `git status --short` que l'index ne contient aucun journal avant de commiter.
3. Si `izanagi_version` de `.izanagi/config.env` est encore en retard sur le plugin après la dernière migration, écris-y la version du plugin et commite.

**Journaux.** La migration 0.4.0 cesse de faire ignorer `.izanagi/journal/*.md` par git, et peut y déplacer un journal d'avant la 0.3 (ligne `déplacé`). Ces journaux apparaissent alors comme fichiers non suivis. Ne les commite pas sur `task/izanagi-upgrade` : la branche principale ne porte jamais de journal. Chacun appartient à la branche de son jalon, où il se commite après la mise à jour.

Fin : chaque migration a son commit, `izanagi_version` vaut la version du plugin, et aucun journal n'est commité.

## 3. Comparer au gabarit

Écris un fichier de valeurs dans le scratchpad, une valeur par ligne :

- chaque ligne `clé=valeur` de `.izanagi/config.env`, hors commentaires ;
- de `docs/agents/harness.md` : chaque ligne `- composant : <nom> | <chemin> | <pile> | <lancement>` devient `composant=<nom>|<chemin>|<pile>|<lancement>`, sans les espaces autour des `|`. La ligne « Systèmes cibles » donne `systemes`, le type donne `type`, les couches donnent `couches` ;
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

Une pile sans gabarit rend toujours `check.sh` et `ci.yml` `différent`, car le gabarit garde `# À ÉCRIRE` là où le projet a ses commandes. Ne classe pas ces blocs : le contrôle de la section 4 les couvre.

Si `docs/agents/harness.md` vient d'être créé avec la valeur `à préciser` pour les couches de test, propose de la remplir avec les couches de la fiche du type.

Commite les reprises acceptées (`chore(izanagi): cadre <version du plugin>`), en nommant à `git add` les fichiers créés ou repris.

Fin : chaque écart est repris ou laissé sur décision de l'utilisateur.

## 4. Contrôler

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-contract.sh" <racine du projet>
```

Chaque ligne `contrat : <fichier> : <règle>` est un écart. Rapporte-le et propose la correction, que tu fais sur l'accord de l'utilisateur.

Lance ensuite `bash scripts/check.sh --host`. S'il échoue, rapporte l'échec tel quel, sans le masquer ni l'attribuer à la mise à jour sans preuve.

Pour chaque `scripts/*.sh` et `.githooks/*` créé ou repris, lance `git add --chmod=+x <fichier>`.

Fin : tu connais le résultat du contrôle du contrat et de `check.sh --host`.

## 5. Ouvrir la PR

Pousse `task/izanagi-upgrade` et ouvre la PR vers la branche principale (`gh pr create`, corps passé par `--body-file`). Le corps liste les migrations lancées, les fichiers repris, les écarts laissés avec leur raison, et colle la sortie de `check.sh --host`.

Rends compte à l'utilisateur :

- la version de départ et la version atteinte ;
- les migrations et ce que chacune a fait ;
- les écarts repris et ceux laissés ;
- ce qui reste à faire après la fusion : sur chaque branche de flux ouverte (`jalon/*`, `task/*`, `fix/*`), fusionner la branche principale pour y amener le nouveau cadre. `/izanagi:jalon` crée ensuite l'état d'un jalon commencé avant la 0.4 ;
- les journaux restés non suivis dans `.izanagi/journal/`, à commiter chacun sur la branche de son jalon.

Fin : la PR est ouverte et l'utilisateur a le bilan.
