# Journal des modifications

Ce fichier suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/) et le projet suit le [versionnage sémantique](https://semver.org/lang/fr/).

## [0.8.2] - 2026-11-24

### Modifié

- Au niveau de risque faible, un constat Important fait monter le niveau à normal : la correction est relue par les relecteurs Standards et Spec, puis testée à la main. Avant, elle partait sans relecture ni test manuel (décision 142, qui remplace la décision 39).

### Corrigé

- La revue de jalon prend le niveau normal au minimum. Un jalon dont toutes les tranches étaient de niveau faible était relu par le seul relecteur Standards, sans relecteur Spec (décision 141).
- Le template de PR, celui du dépôt et celui posé dans un projet, nommait le niveau du milieu « moyen » au lieu de « normal ». Un projet déjà posé garde son template : corrige la ligne à la main.

## [0.8.1] - 2026-11-21

### Modifié

- `izanagi:grilling` remet `❓` devant chaque question et `➡️` devant chaque recommandation, pour repérer les questions d'un long tour.

### Corrigé

- La migration 0.7.0 trouve les tests d'intégration des membres d'un espace de travail Cargo (`crates/<membre>/tests/`). Avant, elle ne cherchait que dans `tests/` et déclarait la couche intégration « sans objet », ce qui sortait ces tests de `check.sh --complet`. Un projet déjà migré garde sa section « Couches de test ». S'il lui manque la ligne `- couche : <composant> | integration | tests | …`, ajoute-la à la main.

## [0.8.0] - 2026-11-21

### Ajouté

- `/izanagi:jalon` et `/izanagi:fix` écrivent la section de la version dans `CHANGELOG.md` à la clôture, dans la langue de la clé `langue_publique`.
- Un projet posé reçoit `release.yml`, qui crée la release GitHub avec les notes du changelog et le livrable du type d'application, et `deploiement.yml`, qui lance à la main la commande de déploiement d'un tag.
- Le projet reçoit aussi un template de PR, un `dependabot.yml` qui suit les dépendances de chaque composant et une analyse Semgrep en CI et chaque semaine.
- Le contrat de vérification compte deux règles de plus (12 et 13), et `/izanagi:upgrade` migre un projet vers la 0.8.0.

## [0.7.0] - 2026-11-19

### Ajouté

- Trois couches de test (unitaire, intégration, fonctionnelle), avec une étape de `check.sh` par couche et l'option `--complet`.
- La mutation sur le diff montre au relecteur les tests qui ne vérifient rien.
- Les skills `tdd`, `planning` et `review` donnent à chaque test sa couche et la vérifient en revue.

## [0.6.0] - 2026-11-19

### Ajouté

- `check.sh` cherche les secrets avec `gitleaks`, et la CI audite les dépendances chaque semaine puis ouvre une issue `securite` en cas d'échec.
- Un hook demande confirmation avant une commande destructrice ou la lecture d'un fichier de secrets, et `init` écrit les règles `permissions.deny` des fichiers de secrets.
- Le sous-agent `reviewer-security` relit les changements à risque élevé.
- `/izanagi:retro` tire des règles de chaque flux, et `/izanagi:contribuer` remonte les règles d'un langage au plugin.

### Modifié

- Les actions de la CI sont épinglées par SHA.

## [0.5.0] - 2026-11-13

### Ajouté

- Un niveau de risque (faible, normal, élevé) règle la profondeur de revue d'une tranche, calculé par `risk.sh` sur le diff.
- `/izanagi:task` conduit un petit changement et `/izanagi:fix` un correctif, avec une cause prouvée par un test rouge.

## [0.4.1] - 2026-11-13

### Corrigé

- Le hook de push laisse passer, avec un avertissement, une commande de plus de 20 000 caractères au lieu de la découper pendant plusieurs secondes.
- `status` nomme la branche de cadrage, et `doctor` contrôle les hooks.

## [0.4.0] - 2026-11-13

### Ajouté

- L'état d'un jalon vit dans `.izanagi/state.env` et un journal versionné, lus par `/izanagi:status` et `/izanagi:doctor`.
- Trois hooks appliquent les règles du cadre, dont le contrôle du push vers la branche principale.
- `/izanagi:upgrade` met à jour un projet posé, et `init` pose un `AGENTS.md`.

## [0.3.0] - 2026-11-12

### Ajouté

- Neuf skills et quatre sous-agents du plugin remplacent les skills externes et conduisent un jalon du cadrage au tag.

### Retiré

- Les prérequis de skills externes (Superpowers, skills de Matt Pocock).

## [0.2.0] - 2026-11-09

### Ajouté

- `init` démarre un projet sur un dossier vide, après un entretien qui choisit la pile et le type d'application.
- Gabarits testés pour Rust, TypeScript et Python, et une fiche par type d'application.
- Le contrat de vérification fixe ce que fait `check.sh`, y compris la vérification sous WSL depuis Windows.

## [0.1.1] - 2026-11-07

### Corrigé

- Trois défauts relevés en migrant un projet réel. Le nom du cache WSL est filtré, le chemin du vault est cité et `pose.sh` refuse une branche qui contient `"` ou `\`.

## [0.1.0] - 2026-11-07

### Ajouté

- `/izanagi:init` pose `CLAUDE.md`, `docs/agents/`, le hook `pre-push`, et pour Rust `check.sh` et la CI.
- `/izanagi:jalon` conduit un jalon, avec une revue convergente de trois tours au plus pour chaque tranche.
