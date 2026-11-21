---
name: init
description: Démarrer un projet avec Izanagi, d'un dossier vide (entretien, choix de la pile, création) ou d'un projet existant sans Izanagi, et poser son harnais (conventions, réglages, vérifications, CI). Un projet qui a déjà un cadre Izanagi passe par /izanagi:upgrade.
disable-model-invocation: true
---

# Init

Tu démarres un projet avec Izanagi, ou tu poses son cadre dans un projet existant. Le script `${CLAUDE_PLUGIN_ROOT}/scripts/install.sh` fait l'écriture : il pose chaque gabarit manquant et compare les autres au gabarit. Il n'écrase jamais un fichier. Toi, tu mènes l'entretien, tu réunis les valeurs, tu lances le script, tu remplis ce qu'il laisse à écrire et tu rends compte. Les gabarits sont dans `${CLAUDE_PLUGIN_ROOT}/templates/`, les références dans `${CLAUDE_PLUGIN_ROOT}/references/`.

Tu n'installes jamais un outil de toi-même. Quand un outil manque (rustup, node, uv, gh, Playwright…), donne sa commande d'installation officielle et attends l'accord de l'utilisateur avant de la lancer.

## 1. Situer le projet

Reconnais le cas, le premier qui s'applique :

| Constat | Cas |
|---|---|
| aucun fichier hors `.git` et `.claude/` | dossier vide |
| `.izanagi/config.env` ou `docs/agents/jalon.md` existe | projet Izanagi |
| sinon | projet existant sans Izanagi |

Un projet Izanagi a déjà son cadre. Dis-le en une ligne, renvoie l'utilisateur à `/izanagi:upgrade`, qui met le cadre à jour et montre ses écarts au gabarit, puis arrête-toi.

Sans dépôt git à la racine, propose `git init -b main` et attends l'accord de l'utilisateur.

Fin : tu annonces le cas en une ligne.

## 2. Réunir les réponses

Une valeur donnée en argument de `/izanagi:init` (`type=cli`, `vault=non`) vaut réponse : ne pose pas sa question.

- **Dossier vide.** Mène l'entretien de `references/interview.md` : deux appels à AskUserQuestion au plus, sans reposer une question déjà réglée par le message de l'utilisateur.
- **Projet existant.** Détecte les composants (voir plus bas). Pose en un seul appel à AskUserQuestion le type d'application, la spec, le test manuel avec son lieu, le vault et la langue publique. Pour le type `api` ou `web-frontend`, ajoute la commande de déploiement (« à préciser » si l'utilisateur ne la connaît pas). Avec plusieurs composants, ajoute celui qui porte la version du projet. Chaque question a sa valeur proposée en premier : la fiche du type le plus probable pour le type, le test manuel et le lieu ; `docs/specs/<date>-<projet>-design.md` pour la spec, chemin où `izanagi:brainstorming` l'écrira ; `non` pour le vault, `fr` pour la langue publique, le premier composant pour la version. Les systèmes cibles viennent de `.github/workflows/ci.yml` s'il existe, sinon ils valent `linux,windows`.

**Détection des composants.** Un `Cargo.toml` donne `rust`, un `package.json` donne `typescript`, un `pyproject.toml` donne `python`. Cherche-les à la racine et un niveau en dessous, hors `node_modules`, `target` et `.venv`. Un manifeste sous un workspace racine de même pile (workspace Cargo, `workspaces` de npm) n'est pas un composant à part. Du code sans ces manifestes (`go.mod`, `pom.xml`, `build.gradle`, `*.csproj`, `Package.swift`…) donne aussi un composant. Propose-le avec le nom de sa pile (`go`, `java`, `csharp`, `swift`), et `install.sh` lui écrira une section `# À ÉCRIRE`. Le composant de la racine a pour nom sa pile et pour chemin `.`. Un composant d'un sous-dossier a pour nom celui du dossier. Noms et piles suivent `[a-z0-9-]`, et une pile ne vaut jamais `aucune`, `core`, `code`, `vault` ni `multi`. Le lancement vient du manifeste : `npm run dev` si `package.json` a un script `dev`, `cargo run` pour un binaire Rust, l'entrée de `[project.scripts]` pour Python, rien sinon. Si un projet TypeScript n'a pas de `package-lock.json` (pnpm, yarn), dis à l'utilisateur que le gabarit lance `npm ci`.

**Couches de test.** Les couches de chaque composant viennent de la section « Couches de test » de la fiche de son type, sans celles que la fiche dit sans objet. Dans un projet existant, garde seulement les couches dont le dossier a déjà des tests (les dossiers par pile sont dans « Ce qu'`init` ajoute après la création » de `references/interview.md`), car une étape de couche échoue sur un dossier vide.

Fin : tu as le type, les composants avec leurs couches et les systèmes cibles.

## 3. Choisir la pile et créer le projet

Cette section ne concerne que le dossier vide.

1. Recommande une pile et justifie-la en une phrase, selon les critères de `references/interview.md`. Attends le choix de l'utilisateur.
2. Vérifie les outils de la pile (`cargo --version`, `node --version`, `uv --version`) et `gitleaks version`, que `scripts/check.sh` lance pour chercher des secrets. Pour installer `gitleaks` : `winget install Gitleaks.Gitleaks` sous Windows, `brew install gitleaks` sous macOS, le binaire de la page des versions (https://github.com/gitleaks/gitleaks/releases) sous Linux. Sous Windows, quand `linux` est une cible, vérifie-les aussi dans WSL avec `wsl.exe --exec bash -lc 'command -v cargo node npm uv'`. Un chemin qui commence par `/mnt/` est un outil de Windows, que `check.sh` retire du PATH : compte-le comme absent. Pour chaque outil absent, donne la commande d'installation et attends l'accord avant de la lancer.
3. Sur l'accord de l'utilisateur, lance l'outil de création de `references/interview.md` dans le dossier de chaque composant : `.` pour un seul composant, un sous-dossier par composant sinon (`web/`, `api/`).
4. Vérifie que le `.gitignore` de la racine ignore `node_modules/`, `.venv/`, `target/` et `dist/`. Ajoute les lignes qui manquent, sans en retirer aucune. Écrits sans `/` au début, ces motifs couvrent les dossiers de tous les composants. Dans un dépôt git existant, `cargo init <dossier>` et `npm init -y` n'écrivent pas de `.gitignore`. Sans ces lignes, la copie WSL de `check.sh` emporterait les dépendances de Windows et le commit du cadre les prendrait.
5. Ajoute les outils et les scripts que `interview.md` liste pour la pile (« Ce qu'`init` ajoute après la création »), puis un premier test réel par couche déclarée de chaque composant, dans le dossier de la couche, selon la règle « premier test » de `interview.md`. Pour la couche fonctionnelle, ce test lance `--help` pour une cli, appelle une route de santé pour une api et charge la page pour un front. Sans ces tests, la première vérification échoue sur un dossier vide. Avec une ligne `fonctionnel_projet`, écris aussi un premier scénario dans son dossier.
6. Produis le fichier de verrou : `cargo generate-lockfile`, `npm install` ou `uv lock`.
7. Si l'utilisateur a voulu le dépôt GitHub, propose `gh repo create <nom> --private --source . --remote origin` et lance-le seulement sur son accord.

Fin : chaque composant existe sur le disque avec son fichier de verrou et un test par couche déclarée, et le `.gitignore` de la racine ignore ses dépendances.

## 4. Écrire les valeurs

Écris les valeurs dans un fichier du scratchpad avec l'outil Write, une par ligne (`clé=valeur`) :

| Clé | Sens | D'où elle vient |
|---|---|---|
| `composant` | `<nom>\|<chemin>\|<pile>\|<lancement>\|<couches>`, une ligne par composant ; `<couches>` parmi `unitaire,integration,fonctionnelle` | sections 2 et 3 ; les couches viennent de la section « Couches de test » de la fiche du type, sans les couches sans objet |
| `navigateur` | `oui` quand une couche fonctionnelle emploie Playwright | fiche du type (un front), sinon omets-la |
| `fonctionnel_projet` | `<dossier>\|<commande>` des scénarios qui traversent plusieurs composants | `references/interview.md`, seulement avec plusieurs composants dont l'un a une couche fonctionnelle |
| `systemes` | sous-ensemble de `linux,windows,macos` | section 2 |
| `type` | identifiant d'une fiche de `references/types/` | section 2 |
| `projet` | nom du projet, tel qu'il s'affiche | entretien, `name` du manifeste racine, sinon le nom du dossier |
| `projet_dossier` | nom de dossier du cache WSL | `scripts/check.sh` existant (le nom avant `-wsl` dans `.cache/`), sinon `name` de `Cargo.toml` ; sinon omets-la |
| `spec` | chemin de la spec, qui fait foi | réponse, sinon la spec existante, sinon `docs/specs/<date>-<projet>-design.md` |
| `branche` | branche principale | `git symbolic-ref --short HEAD`, sinon `main` |
| `test_manuel` | commande qui lance la branche pour l'essayer | réponse, sinon la fiche du type |
| `lieu_test` | où l'utilisateur essaie, en complément de phrase | réponse, sinon la fiche du type |
| `vault` | chemin du vault Obsidian du projet, ou `non` | réponse ou argument, sinon `non` |
| `chemins_sensibles` | motifs des chemins dont tout changement est de niveau de risque élevé, séparés par des virgules | réponse, sinon vide |
| `langue_publique` | langue du changelog et des notes de version, `fr` ou `en` | réponse ou argument, sinon `fr` |
| `deploiement` | commande qui déploie un tag, sur une ligne | seulement pour `api` et `web-frontend` : réponse, sinon omets-la (valeur `à préciser`, pas de `deploiement.yml`) |
| `version_composant` | nom du composant qui porte la version du projet, lue par `release.yml` | seulement avec plusieurs composants : réponse, sinon omets-la (le premier composant) |
| `fichier_version` | fichier qui porte la version | seulement si les piles diffèrent ou si une pile n'a pas de gabarit |

N'écris pas la ligne `pile=` de la 0.1, car les lignes `composant=` la remplacent. N'écris pas non plus `mutation` : `install.sh` met `oui` quand toutes les piles des composants ont un gabarit (Rust, TypeScript, Python), `non` sinon. Les autres clés ont un défaut dans `templates/core/defaults.env` et `templates/<pile>/defaults.env`, et une ligne de ton fichier le remplace. `decisions` se lit après « dans », donc donne-la avec son article.

**Test manuel tiré de la fiche.** La section « Test manuel par défaut » de la fiche du type donne les deux valeurs. `test_manuel` est la commande entre accents graves qui correspond à la pile du composant. `lieu_test` est le lieu de la phrase, mis en complément (« dans un terminal », « dans son navigateur »). Écris-les pour un seul composant, quelle que soit sa pile. Avec au moins deux composants, `test_manuel` vaut `scripts/dev.sh`. Omets alors la clé et garde `lieu_test`. Si aucun de ces composants n'a de lancement, `dev.sh` sort avec le code 1. Écris alors `test_manuel` dans le fichier de valeurs, avec la commande de la fiche.

**Version.** Avec plusieurs composants, le script prend `fichier_version` dans la dernière pile lue, sans chemin. Écris celui du composant qui porte la version du projet, avec son chemin (« `version` du `api/package.json`, avec `api/package-lock.json` commité »). Une pile sans gabarit n'en a pas, écris-le aussi.

Fin : le fichier de valeurs est écrit.

## 5. Poser

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/install.sh" <racine du projet> <fichier de valeurs>
```

Le script rend une ligne par gabarit (`créé`, `identique`, `différent`), une ligne `à écrire   <composant> (<pile>)` par composant d'une pile sans gabarit, la ligne `composants : …` et le dossier de rapport. S'il sort en erreur sur une valeur manquante ou refusée, corrige le fichier de valeurs et relance.

## 6. Écrire les sections `À ÉCRIRE`

Pour chaque ligne `à écrire` dont le marqueur `# À ÉCRIRE` est encore dans `scripts/check.sh` ou `.github/workflows/ci.yml`, remplis la section du composant et l'installation de sa pile dans la CI. Suis « Remplir une section `# À ÉCRIRE` » de `references/verification-contract.md`.

Fin : aucun `À ÉCRIRE` ne reste dans les fichiers que tu as remplis.

## 7. Lire les écarts

Pour chaque fichier `différent`, lis `<rapport>/diff/<chemin>.diff`. Le côté `projet/` est le fichier en place, le côté `gabarit/` le gabarit rendu. Classe chaque bloc :

- **Ajout du projet** (lignes en `-` seules) : du contenu propre au projet, comme une règle de `CODING_STANDARDS.md`. C'est attendu ; résume-le en une ligne.
- **Manque au projet** (lignes en `+` seules) : une convention du gabarit absente du projet. Cite-la.
- **Divergence** (les deux) : le projet et le gabarit disent la même chose autrement. Cite les deux versions.

Un `.claude/settings.json` déjà présent sort `différent` quand il porte d'autres réglages du projet. Ajoute à sa liste `permissions.deny` les règles du gabarit qui lui manquent, avec l'outil Edit, sans toucher aux autres clés. Ces règles empêchent les outils de Claude Code de lire ou d'écrire les fichiers de secrets (`.env*` sauf `.env.example`, `*.pem`, `*.key`, `id_rsa*`, `id_ed25519*`, `id_ecdsa*`, `credentials*`). Garde l'ordre du gabarit : une règle `!` n'exclut que des chemins des règles qui la précèdent.

Une pile sans gabarit rend toujours `check.sh` et `ci.yml` `différent`, car le gabarit garde `# À ÉCRIRE` là où le projet a ses commandes. Le contrôle de la section 8 les couvre, donc ne classe pas ces blocs.

Laisse les autres fichiers tels quels. Si l'utilisateur veut reprendre un manque ou une divergence, fais la modification qu'il désigne, et elle seule.

## 8. Contrôler

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-contract.sh" <racine du projet>
```

Chaque ligne `contrat : <fichier> : <règle>` est un écart. Si le fichier a été créé par `install.sh` ou rempli à la section 6, corrige-le et relance jusqu'à `contrat : respecté`. Si le fichier était déjà là, rapporte l'écart et propose la correction, que tu fais seulement sur l'accord de l'utilisateur. `contrat : aucun composant, rien à vérifier` signifie que `harness.md` ne déclare aucun composant. Si le projet a du code, reprends la détection de la section 2, réécris le fichier de valeurs avec les composants trouvés et relance la section 5. `harness.md` sort alors `différent`, car `install.sh` l'a posé sans composant. Remplace-le par `<rapport>/rendu/docs/agents/harness.md`, puis reprends les sections 6 à 8.

Lance ensuite `bash scripts/check.sh --host --complet` une fois : la version complète lance aussi les couches fonctionnelles. S'il échoue, rapporte l'échec tel quel, sans le masquer ni l'attribuer au harnais sans preuve. Un `command not found` dans la partie `linux` d'une vérification complète signale un outil absent de WSL : donne sa commande d'installation pour Linux, puis `scripts/check.sh --clean` pour repartir d'un cache propre.

Fin : les écarts au contrat sont corrigés ou rapportés, et tu connais le résultat de `check.sh --host --complet`.

## 9. Activer

- **Hook.** Si `scripts/check.sh` existe, lance `git config core.hooksPath .githooks`.
- **Bit exécutable.** Pour chaque `scripts/*.sh` (dont `scripts/dev.sh`) et `.githooks/*` créé à la section 5, lance `git add --chmod=+x <fichier>`. Sous Windows, git ne voit pas le bit posé sur le disque, et un clone Linux aurait un hook qui ne se lance pas.

## 10. Rendre compte

Donne à l'utilisateur :

- les fichiers créés, identiques et différents, avec les écarts de la section 7 et ceux du contrat restés ouverts ;
- les valeurs prises sans question (spec, test manuel, lieu, vault), modifiables dans `.izanagi/config.env` ;
- les skills optionnels absents de ta liste de skills, parmi `mattpocock-skills:codebase-design`, `mattpocock-skills:prototype`, `mattpocock-skills:research` et `mattpocock-skills:wizard`. Dis en une ligne ce que chacun apporte : une aide sur la forme d'une couture, un essai exécutable pendant le cadrage, une recherche de faits sur un outil, un guide pour une étape que seul l'utilisateur peut faire. Ils viennent tous du même plugin, qui s'installe avec `claude plugin install mattpocock-skills`. Propose cette commande et lance-la seulement sur l'accord de l'utilisateur. Aucun flux d'Izanagi n'en dépend.

Finis par la liste ordonnée des prochaines étapes, propres au projet, chacune avec sa commande exacte. Saute celles qui sont déjà faites :

1. Commit du cadre : `git add <fichiers> && git commit -m "chore: cadre Izanagi"`. Sur un dossier vide, le commit prend aussi le projet créé et son fichier de verrou.
2. Outils à installer : chaque outil refusé à la section 3 et chaque prérequis de la fiche du type (`npx playwright install`), avec sa commande.
3. Pour un type à registre (`library`, ou `cli` en TypeScript ou en Python), l'utilisateur configure la publication de confiance sur le registre avant le premier tag. Lui seul peut le faire. Propose `mattpocock-skills:wizard` pour le guider.
4. Pour un type `desktop`, `game`, `mobile` ou `data-ml`, le projet écrit le job `livrable` de `.github/workflows/release.yml` avant la première release. Tant que ce job garde son `À ÉCRIRE`, il sort avec 1 et la release échoue.
5. Sections de `docs/CODING_STANDARDS.md` à remplir : celles qui gardent un commentaire `<!--` du gabarit. Propose les classes de défaillance de la section « Sections de CODING_STANDARDS.md » de la fiche du type. Les fichiers `docs/standards/<langage>.md` peuvent rester vides : les règles générales du plugin pour Rust, TypeScript et Python s'appliquent déjà, et les rétrospectives des jalons les compléteront.
6. Premier jalon : `/izanagi:jalon`. Le cadrage écrit la spec, avec `izanagi:brainstorming`.

Propose de lancer tout de suite la première étape que tu peux faire toi-même, en général le commit, et fais-la sur son accord.

Fin : l'utilisateur a le bilan et la liste des prochaines étapes.
