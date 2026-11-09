---
name: init
description: Poser le cadre Izanagi dans un projet (conventions, réglages de jalon, vérifications, CI), ou montrer ses écarts au gabarit.
disable-model-invocation: true
---

# Init

Tu poses le cadre Izanagi dans le projet courant. Le script `${CLAUDE_PLUGIN_ROOT}/scripts/install.sh` fait l'écriture : il pose chaque gabarit manquant et compare les autres au gabarit. Il n'écrase jamais un fichier. Toi, tu réunis les valeurs, tu lances le script et tu rends compte. Les gabarits sont dans `${CLAUDE_PLUGIN_ROOT}/templates/` : `core/` pour tout projet, un dossier par pile, `vault/` quand le projet a un vault.

## 1. Situer le projet

- **Dépôt git.** Sans dépôt à la racine, propose `git init -b main` et attends l'accord de l'utilisateur.
- **Pile.** `Cargo.toml` à la racine donne `rust`. Sinon la pile est `aucune` : seul le cœur est posé, et `scripts/check.sh` et la CI restent à écrire par le projet. Dis-le à l'utilisateur.
- **Première pose ou relance.** `docs/agents/jalon.md` existe : c'est une relance.

## 2. Réunir les valeurs

Écris les valeurs dans un fichier du scratchpad avec l'outil Write, une par ligne (`clé=valeur`) :

| Clé | Sens | D'où elle vient |
|---|---|---|
| `pile` | `rust` ou `aucune` | étape 1 |
| `projet` | nom du projet, tel qu'il s'affiche | `name` de `Cargo.toml`, sinon le nom du dossier |
| `projet_dossier` | nom de dossier tiré du projet (cache de build) | pile Rust : `name` de `Cargo.toml` ; sinon omets-la, le script la dérive de `projet` |
| `spec` | chemin de la spec, qui fait foi | question |
| `branche` | branche principale | `git symbolic-ref --short HEAD`, sinon `main` |
| `test_manuel` | commande qui installe ou lance la branche pour l'essayer | question ; défaut de la pile Rust : `cargo install --path . --locked` |
| `lieu_test` | où l'utilisateur essaie, en complément de phrase (« dans WSL », « dans son terminal ») | question |
| `vault` | chemin du vault Obsidian du projet, ou `non` | question |

Les autres clés ont un défaut dans `templates/core/defaults.env` et `templates/<pile>/defaults.env`. Une ligne de ton fichier les remplace. `decisions` se lit après « dans » : donne-la avec son article (« le §14 de la spec »). Le script calcule lui-même `vault_cite` et `ligne_vault`.

- **Arguments** : une valeur donnée en argument de `/izanagi:init` (`spec=…`, `vault=non`) vaut réponse ; ne pose pas sa question.
- **Première pose** : pose les questions restantes parmi les quatre (spec, test manuel, lieu, vault) en un seul appel à AskUserQuestion, chacune avec sa valeur proposée en premier. Pour la spec, propose `docs/superpowers/specs/<date>-<projet>-design.md` : c'est le chemin où `superpowers:brainstorming` l'écrira.
- **Relance** : reprends chaque valeur dans le `docs/agents/jalon.md` et le titre du `CLAUDE.md` existants, sans rien demander, et sans les accents graves qui entourent un chemin. Tu compares ainsi le projet au gabarit à valeurs égales, et les écarts affichés viennent du gabarit ou des ajouts du projet, jamais d'une valeur changée.

## 3. Poser

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/install.sh" <racine du projet> <fichier de valeurs>
```

Le script rend une ligne par gabarit (`créé`, `identique`, `différent`), la pile, et le dossier de rapport. S'il sort en erreur sur une valeur manquante, ajoute-la au fichier de valeurs et relance.

## 4. Lire les écarts

Pour chaque fichier `différent`, lis `<rapport>/diff/<chemin>.diff`. Le côté `projet/` est le fichier en place, le côté `gabarit/` le gabarit rendu. Classe chaque bloc :

- **Ajout du projet** (lignes en `-` seules) : du contenu propre au projet, comme une règle de `CODING_STANDARDS.md`. C'est attendu ; résume-le en une ligne.
- **Manque au projet** (lignes en `+` seules) : une convention du gabarit absente du projet. Cite-la.
- **Divergence** (les deux) : le projet et le gabarit disent la même chose autrement. Cite les deux versions.

Laisse les fichiers tels quels. Si l'utilisateur veut reprendre un manque ou une divergence, fais la modification qu'il désigne, et elle seule.

## 5. Activer

- **Hook** : si `scripts/check.sh` existe, lance `git config core.hooksPath .githooks`.
- **Bit exécutable** : pour chaque `scripts/*.sh` et `.githooks/*` créé à l'étape 3, `git add --chmod=+x <fichier>`. Sous Windows, git ne voit pas le bit posé sur le disque, et un clone Linux aurait un hook qui ne se lance pas.

## 6. Rendre compte

Donne à l'utilisateur :

- les fichiers créés, identiques et différents, avec les écarts de l'étape 4 ;
- ce qui reste à remplir : les sections de `docs/CODING_STANDARDS.md` qui gardent un commentaire `<!--` du gabarit ; la spec si son fichier n'existe pas (propose `superpowers:brainstorming`, ou `/izanagi:jalon` qui l'enchaîne) ; `scripts/check.sh` et la CI si la pile est `aucune` ; pour Rust, `Cargo.lock` à commiter, puisque la vérification passe `--locked` ;
- les prérequis absents de ta liste de skills : `mattpocock-skills:*` et `superpowers:*`. `retro` ne figure jamais dans cette liste, car seul l'utilisateur le lance : ne le signale pas.

Fin : l'utilisateur a le bilan. Propose un commit `chore: cadre Izanagi` des fichiers créés, et fais-le sur son accord.
