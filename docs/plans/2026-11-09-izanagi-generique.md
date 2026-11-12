# Izanagi 0.2 générique : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** `/izanagi:init` démarre n'importe quel projet, quel que soit le langage ou le type d'application, et pose un harnais (vérification, CI, réglages) qui respecte un contrat unique.

**Architecture :** `scripts/install.sh` (ex-`pose.sh`) assemble `scripts/check.sh` et la CI à partir d'un squelette commun et d'un fragment par pile et par composant. `scripts/check-contract.sh` contrôle un harnais posé, qu'il vienne d'un gabarit ou qu'il ait été écrit par Claude. Le skill `init` mène l'entretien, choisit la pile, lance l'outil de création, appelle les deux scripts et rend un bilan avec les prochaines étapes.

**Tech Stack :** Bash (Git Bash sous Windows, bash sous Linux), GitHub Actions, skills Claude Code en Markdown.

**Spec :** `docs/specs/2026-11-09-izanagi-generique-design.md` (les numéros « D1 » à « D19 » renvoient à ses décisions).

## Global Constraints

- Noms de fichiers nouveaux ou internes en anglais ; contenu, messages et commentaires en français (D16).
- Inchangés : `docs/agents/jalon.md`, `/izanagi:jalon`, les clés `projet`, `projet_dossier`, `spec`, `decisions`, `plans`, `branche`, `verification`, `test_manuel`, `lieu_test`, `taille_tranche`, `fichier_version`, `vault`, `hors_revue` (D17).
- Aucune mention d'un autre projet réel dans le dépôt (D18).
- `install.sh` n'écrase jamais un fichier existant et n'écrit rien si une valeur manque.
- Les scripts posés gardent des fins de ligne LF (`.gitattributes` existant).
- Version finale : `0.2.0` dans `.claude-plugin/plugin.json`.
- Chaque tâche finit avec `bash tests/install.sh` (et, à partir de la tâche 5, `bash tests/check-contract.sh`) qui passent, puis `claude plugin validate .`.

## Review Focus

- Un chemin de composant avec une espace (`apps/mon front`) : la section de `check.sh` doit faire `cd` correctement. Test ajouté à la tâche 2.
- Un nom de composant avec un caractère hors `[a-z0-9-]` : `install.sh` refuse avant toute écriture. Test ajouté à la tâche 2.
- Deux composants de la même pile : le fragment `ci-setup.yml` de la pile n'entre qu'une fois dans la CI. Test ajouté à la tâche 4.
- `systemes` contient une valeur inconnue (`bsd`) : `install.sh` refuse avant toute écriture. Test ajouté à la tâche 2.
- Un fichier supprimé du projet reste dans la copie WSL et fausse les tests : la synchronisation doit le retirer. Pas testable sans WSL, donc vérifié à la main au scénario Rust de la tâche 9.

---

## Fichiers

| Fichier | Rôle |
|---|---|
| `scripts/install.sh` | pose et compare les gabarits ; assemble `check.sh`, la CI et `dev.sh` |
| `scripts/check-contract.sh` | contrôle un harnais posé contre le contrat |
| `templates/core/` | fichiers posés dans tout projet (inchangé, plus `docs/agents/harness.md`) |
| `templates/code/scripts/check.sh` | squelette de `check.sh`, posé s'il y a au moins un composant |
| `templates/code/.github/workflows/ci.yml` | squelette de la CI, posé s'il y a au moins un composant |
| `templates/multi/scripts/dev.sh` | lance tous les composants, posé à partir de deux |
| `templates/<pile>/defaults.env` | valeurs par défaut de la pile |
| `templates/<pile>/fragments/check-section.sh` | section de `check.sh` d'un composant de cette pile |
| `templates/<pile>/fragments/ci-setup.yml` | étapes d'installation de la pile dans la CI |
| `templates/core/fragments/` | fragments de repli `# À ÉCRIRE` pour une pile sans gabarit |
| `references/verification-contract.md` | le contrat (D6 à D8) |
| `references/interview.md` | questions de l'entretien, choix de la pile, outils de création |
| `references/types/*.md` | une fiche par type d'application (D12) |
| `references/finding.md` | ex-`constat.md` |
| `skills/init/SKILL.md` | réécrit |
| `tests/install.sh` | ex-`tests/pose.sh`, étendu |
| `tests/check-contract.sh` | tests du contrôle du contrat |

`install.sh` ne pose jamais un fichier de `fragments/` ni `defaults.env`.

---

### Task 1 : Renommages et retrait des mentions de projet réel

**Files :**
- Rename : `scripts/pose.sh` → `scripts/install.sh`, `tests/pose.sh` → `tests/install.sh`, `templates/core/valeurs.defaut` → `templates/core/defaults.env`, `templates/rust/valeurs.defaut` → `templates/rust/defaults.env`, `references/constat.md` → `references/finding.md`
- Modify : `skills/jalon/SKILL.md:127`, `skills/init/SKILL.md` (chemins seulement), `README.md:3`

**Interfaces :**
- Produces : `scripts/install.sh <projet> <fichier-valeurs>`, même sortie que `pose.sh` aujourd'hui, messages d'erreur préfixés `install.sh :`.

- [ ] **Step 1 :** `git mv` des cinq fichiers. Dans `install.sh`, remplace `valeurs.defaut` par `defaults.env` et le préfixe des messages `pose.sh :` par `install.sh :`. Remplace l'exemple de la ligne 68 par « (`Mon Projet` donne `mon-projet`) ».
- [ ] **Step 2 :** Dans `tests/install.sh`, remplace les valeurs `projet` et `projet_dossier` d'un projet réel par `projet=Atelier\nprojet_dossier=atelier-editeur` et l'attente du cache WSL par `cache/atelier-editeur-target"`. Mets à jour le chemin du script testé.
- [ ] **Step 3 :** Mets à jour les renvois : `references/finding.md` dans `skills/jalon/SKILL.md`, `scripts/install.sh` et `defaults.env` dans `skills/init/SKILL.md`. Dans `README.md:3`, retire la phrase qui nomme le projet d'origine ; la phrase devient « Toute valeur propre à un projet se lit dans ses fichiers `docs/agents/`. »
- [ ] **Step 4 :** Vérifie : `bash tests/install.sh` affiche `install.sh : tous les cas passent`, et la recherche de l'ancien nom du projet dans le dépôt ne rend rien.
- [ ] **Step 5 :** Commit `refactor: noms anglais pour les fichiers internes, plus de projet réel cité`.

### Task 2 : Composants multiples et squelette de `check.sh` (système courant)

**Files :**
- Modify : `scripts/install.sh`
- Create : `templates/code/scripts/check.sh`, `templates/code/.github/workflows/ci.yml` (déplacés depuis `templates/rust/`, puis réécrits), `templates/rust/fragments/check-section.sh`, `templates/rust/fragments/ci-setup.yml`, `templates/core/fragments/check-section.sh`, `templates/core/fragments/ci-setup.yml`
- Delete : `templates/rust/scripts/check.sh`, `templates/rust/.github/workflows/ci.yml`
- Test : `tests/install.sh`

**Interfaces :**
- Consumes : `install.sh` de la tâche 1.
- Produces :
  - valeurs nouvelles : `composant=<nom>|<chemin>|<pile>|<lancement>`, répétable, dans l'ordre du fichier ; `<nom>` suit `^[a-z0-9-]+$`, `<chemin>` est relatif à la racine (`.` pour la racine), `<lancement>` peut être vide. `systemes=<liste>`, sous-ensemble de `linux,windows,macos` séparé par des virgules, défaut `linux,windows` dans `templates/core/defaults.env`.
  - compatibilité 0.1 : sans ligne `composant=` et avec `pile=<p>` différent de `aucune`, `install.sh` crée le composant `<p>|.|<p>|`.
  - valeurs calculées pour les gabarits : `{{sections}}` (sections de tous les composants, à la suite), `{{appels}}` (une ligne `verifier_<nom_avec_underscores>` par composant), `{{ci_os}}` (liste YAML `[ubuntu-latest, windows-latest]`, avec `linux` → `ubuntu-latest`, `windows` → `windows-latest`, `macos` → `macos-latest`), `{{ci_setup}}` (fragments `ci-setup.yml` des piles, une fois par pile, dans l'ordre d'apparition).
  - fragment de section : définit `verifier_{{id}}()` ; variables `{{composant}}`, `{{id}}` (le nom avec `-` remplacé par `_`), `{{chemin}}`. Il commence par la ligne `# --- composant {{composant}} ({{pile}}) ---`.
  - sortie : après les lignes `créé`/`identique`/`différent`, une ligne `à écrire   <composant> (<pile>)` par composant sans gabarit de pile, puis `composants : <nom>(<pile>), …` (ou `composants : aucun`) à la place de la ligne `pile : …`, puis `rapport : <dossier>`.
  - `templates/code/` est posé s'il y a au moins un composant.

- [ ] **Step 1 : tests en échec** dans `tests/install.sh` :
  - pose avec `composant=cli|.|rust|cargo run` et `systemes=linux,windows` : `check.sh` contient `# --- composant cli (rust) ---` et `verifier_cli`, `ci.yml` contient `os: [ubuntu-latest, windows-latest]` et `run: bash scripts/check.sh --host`, et ne contient plus `cargo test` ;
  - pose avec `pile=rust` sans `composant=` : même `check.sh` que le cas précédent, au nom de composant près (`rust`) ;
  - pose avec `composant=outil|.|zig|` : sortie avec `à écrire   outil (zig)`, `check.sh` contenant `# À ÉCRIRE : outil (zig)` ;
  - sur ce projet `zig`, remplace la ligne `# À ÉCRIRE` par `true` puis lance `scripts/check.sh --host` : sortie 0 ; avec `false` : sortie différente de 0 ; `scripts/check.sh --inconnu` : sortie 2 ;
  - chemin avec espace : `composant=web|apps/mon front|zig|` avec `true` à la place de `# À ÉCRIRE` et un `pwd > "$racine/vu"` ajouté : `vu` vaut le chemin `apps/mon front` (crée le dossier avant) ;
  - refus avant écriture : `composant=Web|.|rust|`, puis `systemes=linux,bsd` ; dans les deux cas, sortie différente de 0, message contenant `refusé`, dossier cible vide ;
  - sans composant ni pile : ni `scripts/check.sh` ni `ci.yml` posés, sortie `composants : aucun` ;
  - ajuste les comptes `créé`/`identique` existants au nouveau nombre de fichiers.
- [ ] **Step 2 :** lance `bash tests/install.sh`. Attendu : échec sur le premier nouveau cas.
- [ ] **Step 3 : squelette `templates/code/scripts/check.sh`.** Garde l'en-tête d'usage, `cd` à la racine, l'analyse des arguments (`--host`, `--clean`, aucun ; sinon usage et `exit 2`) et la détection `windows`/`linux`/`macos` par `uname -s`. Puis `{{sections}}`, une fonction `verifier_tout` qui contient `{{appels}}`, l'appel de `verifier_tout` sur le système courant avec la ligne `== <système>` avant et `<système> : tout passe` après. À cette tâche, `--clean` affiche `rien à vider` et sort avec 0, et le chemin WSL est absent : la tâche 3 les ajoute. Le script s'arrête au premier échec (`set -euo pipefail`).
- [ ] **Step 4 : fragment Rust `check-section.sh`.** `verifier_{{id}}()` lance dans un sous-shell `cd "{{chemin}}"`, puis `cargo fmt --all --check`, `cargo clippy --workspace --all-targets --locked -q -- -D warnings`, `cargo test --workspace --locked`, chacune précédée de `echo "-- {{composant}} : <étape>"`. Le fragment de repli `templates/core/fragments/check-section.sh` a la même structure, mais remplace les trois commandes cargo par la seule ligne `# À ÉCRIRE : {{composant}} ({{pile}}), format, lint, tests` dans le sous-shell après le `cd`.
- [ ] **Step 5 : squelette de CI.** Garde `on`, `permissions`, `concurrency` et la branche citée de l'actuel `ci.yml`. Un seul job `check` avec `strategy.matrix.os: {{ci_os}}`, `fail-fast: false`, `runs-on: ${{ matrix.os }}`, puis `actions/checkout@v4`, `{{ci_setup}}`, et l'étape `run: bash scripts/check.sh --host`. Fragment Rust `ci-setup.yml` : `dtolnay/rust-toolchain@stable` avec `rustfmt, clippy`, puis `Swatinem/rust-cache@v2`, indenté pour s'insérer dans `steps`. Fragment de repli : `      # À ÉCRIRE : installation de {{pile}}`.
- [ ] **Step 6 : `install.sh`.** Lecture des lignes `composant=` répétables (le tableau associatif garde la dernière valeur pour les autres clés), validation du nom et de `systemes` avant toute écriture, calcul des quatre valeurs ci-dessus, `templates/code/` ajouté aux sources s'il y a un composant, fichiers de `fragments/` et `defaults.env` jamais posés.
- [ ] **Step 7 :** `bash tests/install.sh` passe.
- [ ] **Step 8 :** Commit `feat: check.sh et CI assemblés par composant`.

### Task 3 : Vérification dans WSL par copie, et `--clean`

**Files :**
- Modify : `templates/code/scripts/check.sh`
- Test : `tests/install.sh`

**Interfaces :**
- Consumes : squelette de la tâche 2, valeurs `{{projet_dossier}}` et `{{systemes}}`.
- Produces : comportement du contrat D6 et D8.

- [ ] **Step 1 : tests en échec** :
  - le `check.sh` rendu contient `.cache/<projet_dossier>-wsl` et ne contient plus `CARGO_TARGET_DIR` ;
  - avec `systemes=windows` seul, le `check.sh` rendu ne lance pas WSL : une variable `cibles="windows"` est présente ;
  - `bash -n` passe sur le `check.sh` rendu pour `projet=Élan d'été & Co/x` (cas hostile déjà présent, adapté).
- [ ] **Step 2 :** lance les tests. Attendu : échec.
- [ ] **Step 3 : implémente dans le squelette**
  - `cibles="{{systemes}}"` ; sans argument, sous Windows et si `linux` figure dans `cibles`, `verifier_wsl` après la vérification locale ; `wsl.exe` absent : `wsl : absent, étape sautée` et sortie 0 ;
  - `verifier_wsl` : la liste `git ls-files -z --cached --others --exclude-standard` passe à `tar --null -T - -cf -`, et l'archive est extraite par `wsl.exe --exec bash -lc` dans `$HOME/.cache/{{projet_dossier}}-wsl`. Le même appel lit la liste précédente `.izanagi-files`, supprime les fichiers qui n'y sont plus, écrit la nouvelle, puis relance `bash scripts/check.sh --host` dans la copie ;
  - `--clean` : sous Windows, `wsl.exe --exec rm -rf "\$HOME/.cache/{{projet_dossier}}-wsl"` et `cache WSL vidé` ; ailleurs, `rien à vider`. Sortie 0.
- [ ] **Step 4 :** `bash tests/install.sh` passe.
- [ ] **Step 5 :** Commit `feat: vérification WSL sur une copie du projet, check.sh --clean`.

### Task 4 : Piles TypeScript et Python, `dev.sh`

**Files :**
- Create : `templates/typescript/defaults.env`, `templates/typescript/fragments/check-section.sh`, `templates/typescript/fragments/ci-setup.yml`, `templates/python/defaults.env`, `templates/python/fragments/check-section.sh`, `templates/python/fragments/ci-setup.yml`, `templates/multi/scripts/dev.sh`
- Modify : `scripts/install.sh`, `templates/rust/defaults.env`
- Test : `tests/install.sh`

**Interfaces :**
- Consumes : fragments et valeurs de la tâche 2.
- Produces :
  - TypeScript : la section lance `npm ci`, `npm run format:check`, `npm run lint`, `npm test`. `init` doit garantir ces trois scripts dans `package.json` (tâche 7). `ci-setup.yml` : `actions/setup-node@v4` avec `node-version: lts/*` et `cache: npm`. `defaults.env` : `fichier_version=` `version` du `package.json`, avec `package-lock.json` commité ; `hors_revue=` `package-lock.json` plus les deux chemins du cœur.
  - Python : la section lance `uv sync --locked`, `uv run ruff format --check`, `uv run ruff check`, `uv run pytest`. `ci-setup.yml` : `astral-sh/setup-uv@v6`. `defaults.env` : `fichier_version=` `version` du `pyproject.toml`, avec `uv.lock` commité ; `hors_revue=` `uv.lock` plus les deux chemins du cœur.
  - Rust `defaults.env` : retire `verification` (identique au cœur).
  - `dev.sh` : posé à partir de deux composants. Pour chaque composant à `lancement` non vide, il lance `(cd "<chemin>" && <lancement>) &`, ferme tous les processus lancés à la sortie (`trap 'kill 0' EXIT`), puis attend avec `wait`. Valeur calculée `{{lancements}}`.
  - valeur `test_manuel` : défaut `scripts/dev.sh` s'il y a au moins deux composants, sauf si le fichier de valeurs la donne.
  - avec plusieurs composants, `{{chemin}}` ne change rien au `defaults.env` lu : `install.sh` lit le `defaults.env` de chaque pile, dans l'ordre des composants, puis le fichier de valeurs.

- [ ] **Step 1 : tests en échec** :
  - `composant=api|api|typescript|npm run dev` et `composant=web|web|typescript|npm run dev` : un seul `actions/setup-node` dans `ci.yml`, deux sections dans `check.sh`, `scripts/dev.sh` posé et exécutable, avec `(cd "api" && npm run dev) &` ;
  - `composant=outil|.|python|` seul : `uv sync --locked` dans `check.sh`, `astral-sh/setup-uv` dans `ci.yml`, pas de `dev.sh` ;
  - `jalon.md` du cas à deux composants : `scripts/dev.sh` comme test manuel.
- [ ] **Step 2 :** lance les tests. Attendu : échec.
- [ ] **Step 3 :** écris les fragments, `defaults.env`, `dev.sh` et les deux règles d'`install.sh`.
- [ ] **Step 4 :** `bash tests/install.sh` passe.
- [ ] **Step 5 :** Commit `feat: piles TypeScript et Python, dev.sh pour plusieurs composants`.

### Task 5 : `harness.md` et contrôle du contrat

**Files :**
- Create : `templates/core/docs/agents/harness.md`, `scripts/check-contract.sh`, `tests/check-contract.sh`
- Modify : `scripts/install.sh`, `templates/core/defaults.env`

**Interfaces :**
- Consumes : valeurs des tâches 2 et 4.
- Produces :
  - valeurs : `type` (identifiant d'une fiche, par exemple `web-frontend`), `couches` (phrase, par exemple « unitaires et e2e navigateur (Playwright) »). Défauts dans le cœur : `type=à préciser`, `couches=à préciser`.
  - `harness.md` rendu : type, systèmes cibles, couches de test, test manuel, puis un tableau des composants (nom, chemin, pile, lancement) depuis la valeur calculée `{{tableau_composants}}`. Il contient aussi une ligne par composant au format exact `- composant : <nom> | <chemin> | <pile> | <lancement>`, que `init` relit à la relance et que `check-contract.sh` analyse.
  - `check-contract.sh <projet>` : sortie 0 et `contrat : respecté`, ou une ligne `contrat : <fichier> : <règle enfreinte>` par écart et sortie 1. Les règles sont les suivantes :
    1. `scripts/check.sh` existe, est exécutable et passe `bash -n` ;
    2. `scripts/check.sh --inconnu` sort avec le code 2 ;
    3. il gère `--host` et `--clean` (motifs `--host)` et `--clean)`) ;
    4. aucun `À ÉCRIRE` dans `scripts/check.sh`, `.github/workflows/ci.yml` ni `scripts/dev.sh` ;
    5. chaque composant de `harness.md` a sa ligne `# --- composant <nom> (` dans `check.sh` ;
    6. aucune installation sans verrou : `npm install`, `pip install`, `uv sync` sans `--locked`, `cargo (build|test|clippy)` sans `--locked` ;
    7. `ci.yml` contient `bash scripts/check.sh --host`, et sa ligne `os:` correspond aux systèmes de `harness.md` ;
    8. `harness.md` existe.

- [ ] **Step 1 : tests en échec** dans `tests/check-contract.sh`. Ils posent des projets avec `install.sh`, puis :
  - Rust posé : `contrat : respecté`, sortie 0 ;
  - `zig` posé sans remplir : sortie 1, une ligne avec `À ÉCRIRE` pour `check.sh` et une pour `ci.yml` ;
  - `zig` rempli avec `true` et l'installation de la CI remplie : sortie 0 ;
  - `npm install` ajouté à une section : sortie 1, ligne qui cite le verrou ;
  - ligne `os:` modifiée à la main : sortie 1 ;
  - `harness.md` supprimé : sortie 1.
  - `tests/install.sh` : le `harness.md` rendu contient `- composant : cli | . | rust | cargo run`.
- [ ] **Step 2 :** lance les deux scripts de test. Attendu : échec.
- [ ] **Step 3 :** écris le gabarit, la valeur calculée et `check-contract.sh`.
- [ ] **Step 4 :** les deux scripts de test passent.
- [ ] **Step 5 :** Commit `feat: docs/agents/harness.md et contrôle du contrat`.

### Task 6 : Références (contrat, entretien, types)

**Files :**
- Create : `references/verification-contract.md`, `references/interview.md`, `references/types/{cli,api,web-frontend,desktop,mobile,library,game,data-ml,plugin}.md`
- Modify : `references/versions.md` (ligne « Fichier de verrouillage », générique : `Cargo.lock`, `package-lock.json`, `uv.lock`)

**Interfaces :**
- Produces : les identifiants de type valides pour la valeur `type` sont exactement les noms de fichier sans `.md`.

- [ ] **Step 1 : `verification-contract.md`.** Les règles D6, D7 et D8 de la spec, la liste des règles de `check-contract.sh` (tâche 5) et la forme d'une section de composant (marqueur `# --- composant`, sous-shell, `cd`, format puis lint puis tests). Il se termine par la marche à suivre pour remplir une section `# À ÉCRIRE` d'une pile sans gabarit : chercher les commandes officielles de format, de lint et de test de la pile, avec leur option de verrou.
- [ ] **Step 2 : `interview.md`.** Les questions de D2, posées en deux appels à AskUserQuestion au plus. Il donne les critères de choix de la pile (langages connus, type, plateformes, contraintes) et le tableau des outils de création : Rust `cargo init` ; TypeScript, front `npm create vite@latest . -- --template <react-ts|vue-ts|svelte-ts|vanilla-ts>` ; TypeScript, API `npm init -y` puis `typescript`, `tsx` et un framework au choix ; Python `uv init`. Il liste ensuite ce qu'`init` ajoute après la création : pour TypeScript, `prettier`, `eslint`, `vitest` et les scripts `format:check`, `lint` et `test` ; pour Python, `ruff` et `pytest` en dépendances de développement.
- [ ] **Step 3 : fiches de type.** Chaque fiche a quatre sections, dans cet ordre : « Couches de test », « Test manuel par défaut » (commande et lieu), « Sections de CODING_STANDARDS.md » (deux à quatre classes de défaillance propres au type, au format des lignes du gabarit), « Prérequis ». Exemple pour `web-frontend` : unitaires (vitest) et e2e navigateur (Playwright) ; `npm run dev`, « dans son navigateur » ; état perdu au rechargement, régression d'accessibilité, écart entre navigateurs ; `npx playwright install`. La CI ne lance les e2e que si `check.sh` les inclut.
- [ ] **Step 4 :** relis chaque fichier avec les règles unslop (pas de tiret cadratin, pas de vocabulaire de remplissage). `git grep -n '—' references/` ne rend rien.
- [ ] **Step 5 :** Commit `docs: contrat de vérification, entretien de départ, fiches de type`.

### Task 7 : Réécriture du skill `init`

**Files :**
- Modify : `skills/init/SKILL.md`

**Interfaces :**
- Consumes : `install.sh` et ses valeurs (tâches 2, 4, 5), `check-contract.sh` (tâche 5), `references/interview.md`, `references/types/*.md`, `references/verification-contract.md` (tâche 6).

- [ ] **Step 1 : écris le skill** en sections numérotées :
  1. **Situer.** Il y a quatre cas, à reconnaître dans cet ordre : dossier vide (aucun fichier hors `.git`) ; `docs/agents/harness.md` présent (relance 0.2) ; `docs/agents/jalon.md` présent sans `harness.md` (projet 0.1) ; sinon, projet existant sans Izanagi. Sans dépôt git, proposer `git init -b main`.
  2. **Entretien** (dossier vide seulement), selon `references/interview.md`. **Projet existant** : détecter les composants (`Cargo.toml`, `package.json`, `pyproject.toml` à la racine et un niveau en dessous) et demander seulement le type. **Projet 0.1** : composants par détection, systèmes déduits de `ci.yml`, autres valeurs reprises de `jalon.md`.
  3. **Pile et création** (dossier vide) : recommander la pile en une phrase de justification, attendre le choix, vérifier les outils (commande d'installation et accord avant tout lancement, D5), lancer l'outil de création, puis ajouter les outils et scripts listés dans `interview.md`. Proposer `gh repo create <nom> --private --source . --remote origin` et le lancer seulement sur accord.
  4. **Valeurs** : le tableau de la 0.1, plus `composant` (répétable), `systemes`, `type` et `couches`, pris dans la fiche du type. Une relance 0.2 reprend tout de `harness.md` et `jalon.md` sans rien demander.
  5. **Poser** : `bash "${CLAUDE_PLUGIN_ROOT}/scripts/install.sh" <racine> <fichier de valeurs>`.
  6. **Écrire les sections `À ÉCRIRE`** : pour chaque ligne `à écrire` de la sortie, remplir la section de `check.sh` et l'installation de la CI selon `references/verification-contract.md`.
  7. **Contrôler** : `bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-contract.sh" <racine>`, corriger chaque écart et relancer jusqu'à `contrat : respecté`. Puis lancer `scripts/check.sh --host` une fois, et rapporter un échec sans le masquer.
  8. **Écarts** : reprendre la section 4 de la 0.1. Pour un projet 0.1, présenter `check.sh` et `ci.yml` `différent` comme la mise à jour du gabarit 0.2, et proposer de les reprendre sur accord (D19).
  9. **Activer** : reprendre la section 5 de la 0.1, y compris `scripts/dev.sh` pour le bit exécutable.
  10. **Bilan et prochaines étapes** : fichiers créés, identiques et différents ; prérequis absents. Puis la liste ordonnée D15, chaque étape avec sa commande exacte, en sautant celles qui sont déjà faites. Proposer de lancer la première étape qui ne demande pas d'accord.
- [ ] **Step 2 :** `claude plugin validate .` passe.
- [ ] **Step 3 :** Commit `feat(init): entretien de départ, choix de la pile, harnais générique`.

### Task 8 : README et version

**Files :**
- Modify : `README.md`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`

- [ ] **Step 1 :** README : décrire le nouveau `init` (dossier vide, projet existant, relance) et les piles de référence, renvoyer au contrat pour les autres piles, citer `scripts/check.sh --clean`, retirer le paragraphe « Piles » de la 0.1 et la ligne Rust/WSL, retirer de la feuille de route ce que la 0.2 livre. Dans « Contribuer », la commande de test devient `bash tests/install.sh && bash tests/check-contract.sh`.
- [ ] **Step 2 :** `plugin.json` : version `0.2.0`, mots-clés `["workflow", "jalon", "revue", "harnais"]`, description qui dit que `init` démarre un projet de toute pile.
- [ ] **Step 3 :** `claude plugin validate .` passe, et les deux scripts de test passent.
- [ ] **Step 4 :** Commit `chore: 0.2.0`.

### Task 9 : Réception (manuelle)

Pas de code. Chaque scénario se joue dans un dossier du scratchpad, avec le plugin chargé depuis ce worktree (`claude plugin marketplace add <chemin du worktree>`).

- [ ] **Step 1 : projet 0.1.** Pose un projet avec le `pose.sh` du tag `v0.1.1` (`git show v0.1.1:scripts/pose.sh`), puis lance `/izanagi:init`. Attendu : seuls `scripts/check.sh` et `ci.yml` sont `différent`, `harness.md` est `créé`, et seul le type est demandé.
- [ ] **Step 2 : CLI Rust** depuis un dossier vide. Attendu : `cargo init`, `contrat : respecté`, `scripts/check.sh` passe sous Windows puis WSL. Supprime ensuite un fichier de test, relance `scripts/check.sh` et vérifie qu'il n'est plus dans `~/.cache/<projet>-wsl`. Lance enfin `scripts/check.sh --clean`.
- [ ] **Step 3 : front et API en TypeScript** depuis un dossier vide. Attendu : deux composants, `scripts/dev.sh` lance les deux, et `check.sh` passe sur les deux systèmes.
- [ ] **Step 4 : outil data en Python** depuis un dossier vide. Attendu : `uv init`, ruff et pytest ajoutés, `check.sh` passe.
- [ ] **Step 5 :** note chaque défaut trouvé. Corrige-le dans la tâche concernée, avec un test si la correction touche un script, puis rejoue le scénario.
