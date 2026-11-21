<p align="center">
  <img src="docs/assets/logo-wordmark.svg" alt="Izanagi" width="480">
</p>

# Izanagi

Plugin Claude Code qui pose le cadre de travail d'un projet, conduit ses jalons et applique ses règles par des hooks. Les réglages d'un projet et l'état de son flux en cours sont dans son dossier `.izanagi/`.

## Skills

- `/izanagi:init` démarre un projet de toute pile et pose son cadre. Il sait traiter deux cas :
  - Dans un dossier vide, il mène un entretien de départ, recommande une pile, lance le créateur officiel de cette pile, puis propose `gh repo create` et ne le lance que sur ton accord.
  - Dans un projet existant sans Izanagi, il détecte les composants et pose le cadre sans toucher au code.
- `/izanagi:jalon [phase]` conduit un jalon : cadrage, plan, tranches, revue de jalon, test, clôture. Dans le plan, chaque couture porte sa couche de test. Une tranche qui change un comportement visible commence par un scénario d'acceptation à la couche fonctionnelle, écrit et vu en échec avant les cycles des couches plus basses, puis vu passer à la fin de la tranche. C'est la double boucle du skill `tdd`. Chaque tranche passe une revue convergente (trois tours au plus, re-revue sur le seul diff des corrections). `/izanagi:jalon convergente` lance cette revue seule, pour une PR hors jalon.
- `/izanagi:task [issue ou description]` conduit un petit changement, de l'issue à la PR, sans spec ni plan : cadrage en cinq questions au plus, implémentation testée, revue, patch monté. Si le changement dépasse une tranche ou touche plusieurs coutures, il s'arrête au cadrage et propose un jalon.
- `/izanagi:fix [issue ou description du bug]` conduit un correctif : un diagnostic qui prouve la cause par un test de régression rouge, le correctif, la revue, la PR. Lancé pendant un jalon, il part de la branche du jalon et y revient. Les retours de test d'un jalon passent par lui.
- `/izanagi:retro [branche]` tire les leçons d'un flux : il lit le journal, les rapports de revue, les refus des hooks (`.izanagi/refus.log`) et les lignes `Correction :` que les flux notent quand tu reprends l'agent. Il te propose une règle par leçon, dans le fichier qui convient (`docs/CODING_STANDARDS.md`, `docs/standards/<langage>.md`, `CLAUDE.md`…), et ne l'écrit qu'avec ton accord. Une leçon sur Izanagi lui-même devient un brouillon d'issue, ouvert seulement sur ton accord. La clôture d'un jalon le lance. `task` et `fix` te demandent « une leçon à garder ? » quand la revue a pris plus d'un tour ou qu'un hook a refusé quelque chose.
- `/izanagi:contribuer [langage]` propose au plugin, par une PR vers le dépôt d'Izanagi, les règles de langage que `retro` a rangées sous `## À proposer au plugin` dans `docs/standards/<langage>.md`. Il les réécrit sans rien du projet (nom, chemins, code), te montre le diff complet, et ne pousse rien sans ton accord. Sans droit d'écriture sur le dépôt, il passe par un fork.
- `/izanagi:grilling [sujet]` t'interroge par tours sur un plan ou une décision, jusqu'à ce que chaque point soit tranché. Le cadrage d'un jalon le lance aussi.
- `/izanagi:upgrade` met à jour le cadre d'un projet déjà posé. Il applique les migrations une à une sur une branche `task/izanagi-upgrade`, montre les écarts au gabarit, n'écrase un fichier modifié qu'avec ton accord et ouvre une PR.
- `/izanagi:status` liste les flux ouverts, d'après les branches `jalon/*`, `task/*` et `fix/*`, avec la phase, la tranche et le tour de revue de chacun.
- `/izanagi:doctor` contrôle le poste et le cadre : outils, hooks, réglages, version du cadre, contrat de vérification, cohérence de l'état avec git. Il propose la correction de chaque écart.

Les flux chargent huit autres skills du plugin, absents du menu des commandes : `brainstorming` écrit la spec, `domain-modeling` tient `CONTEXT.md`, `planning` écrit le plan en tranches, `task-loop` exécute les tâches d'une tranche, `tdd` fixe les règles de test, `review` conduit la revue convergente, `diagnosing` cherche la cause d'un bug et `merge-conflicts` résout un conflit. Cinq sous-agents font le travail délégué : `implementer`, `reviewer-standards`, `reviewer-spec`, `reviewer-security` et `diagnostician`. Les trois relecteurs sont en lecture seule. `reviewer-security` ne tourne qu'au niveau de risque élevé, contre la section « Sécurité » de la fiche du type d'application.

`init` pose `CLAUDE.md`, `AGENTS.md`, `.izanagi/config.env`, `docs/agents/*` (tracker, libellés de tri, domaine, vault, harnais), un squelette de `docs/CODING_STANDARDS.md`, le hook `.githooks/pre-push`, `scripts/check.sh` et la CI. Un projet à plusieurs composants reçoit aussi `scripts/dev.sh`, qui les lance ensemble.

Un projet posé a trois fichiers propres à Izanagi :

- `.izanagi/config.env` porte les réglages, une valeur par ligne (`clé=valeur`) : version du cadre, chemin de la spec, lieu des décisions, dossier des plans, branche principale, commande de vérification, commande et lieu du test manuel, taille d'une tranche, chemins sensibles, fichier de version, chemin du vault ou `non`, une clé par hook, `navigateur` (`oui` quand une couche fonctionnelle emploie Playwright), les clés de la mutation, `mutation` et `mutation_delai`, et celles de la release, `langue_publique` et `version_composant`.
- `.izanagi/state.env` porte l'état du flux de la branche courante : flux, nom, phase, tranche, tour de revue, niveau de risque. Il est versionné sur la branche du flux, et la branche principale n'en porte jamais. Seul `scripts/state.sh` du plugin l'écrit.
- `docs/agents/harness.md` décrit le harnais : composants, systèmes cibles, type d'application, commande de déploiement, et le tableau des couches de test, avec le dossier et la commande de chaque couche de chaque composant.

Le journal d'un jalon, `.izanagi/journal/<plan>.md`, est versionné sur la branche du jalon. La clôture le supprime avec l'état, dans le dernier commit avant la fusion.

`AGENTS.md` donne à un autre agent de code la spec, la commande de vérification et les règles de relecture. Il ne décrit pas les flux d'Izanagi.

## Niveaux de risque

Une tranche, un petit changement ou un correctif porte un niveau de risque, qui règle sa revue et son test manuel :

| Niveau | Exemples | Revue | Test manuel |
|---|---|---|---|
| faible | documentation, renommage, configuration | un relecteur, un tour | non |
| normal | comportement nouveau | deux relecteurs, trois tours au plus | oui |
| élevé | données, sécurité, migration, API publique | trois relecteurs, Sécurité compris, trois tours au plus, puis tu relis le diff | oui |

Le plan d'un jalon donne le niveau de chaque tranche. `task` et `fix` en proposent un au départ. Tu peux le changer à tout moment.

La clé `chemins_sensibles` de `.izanagi/config.env` liste des motifs de chemins, séparés par des virgules (`db/migrations/*, src/auth/*`). Un diff qui touche un de ces chemins est de niveau élevé, quel que soit le niveau déclaré.

## Hooks

Le plugin installe quatre hooks. Chacun sort sans rien faire hors d'un projet Izanagi.

- **Au démarrage d'une session**, le premier ajoute au contexte l'état du flux de la branche courante. Il avertit aussi quand le cadre du projet est en retard sur le plugin.
- **Avant un `git push`**, le deuxième refuse un push qui vise la branche principale, `git push --all` et `git push --mirror` compris. Un push de tag et une suppression de branche passent.
- **Avant une commande Bash**, le troisième te demande de confirmer un geste destructeur : `git reset --hard`, `git clean -f`, `git push --force` sans `--force-with-lease`, `git branch -D`, `git checkout .` ou `git restore .` sur un arbre modifié, `rm -rf` sur la racine du dépôt ou hors de lui. Il demande aussi avant la lecture d'un fichier de secrets par une commande Bash (`cat`, `source`, `cp`…) : `.env*` sauf `.env.example`, `*.pem`, `*.key`, `id_rsa*`, `id_ed25519*`, `id_ecdsa*`, `credentials*`. Le motif `.env*` couvre aussi `.envrc`.
- **À l'arrêt de l'implémenteur**, le quatrième relance la vérification du projet. Un échec renvoie l'implémenteur au travail, avec la fin de la sortie. Le hook laisse passer un implémenteur qui se déclare bloqué, et cesse de bloquer après deux refus.

Les hooks du push et de la commande Bash sont des garde-fous contre un geste fait par habitude : ils ne voient que la commande tapée, et une commande construite pour les tromper (variable, alias, `eval`) passe. Ils ne surveillent pas le réseau.

Les hooks du push et de la vérification bloquent par défaut, et celui des commandes destructrices demande. Pour qu'un hook avertisse au lieu de bloquer, écris `hook_push=avertit`, `hook_verification=avertit` ou `hook_destructif=avertit` dans `.izanagi/config.env`. `hook_destructif=bloque` refuse au lieu de demander.

Chaque refus, avertissement ou demande d'un hook s'ajoute à `.izanagi/refus.log`, que git ignore et que `/izanagi:retro` lit.

`init` écrit aussi dans `.claude/settings.json` du projet des règles `permissions.deny`, que Claude Code applique lui-même : ses outils ne lisent ni n'écrivent les fichiers de secrets ci-dessus.

## Sécurité du projet

- `scripts/check.sh` cherche des secrets avec `gitleaks` dans les commits de la branche absents de la branche principale, avant de vérifier les composants. Un faux positif s'écarte dans `.gitleaks.toml`, avec sa raison.
- Le job `audit` de la CI audite les dépendances de chaque composant. Une faille haute ou critique fait échouer la PR (`cargo audit`, `npm audit`). Pour Python, `pip-audit` ne filtre pas par gravité : toute faille connue fait échouer la PR.
- `.github/workflows/securite.yml` relance chaque lundi l'audit et `gitleaks` sur tout l'historique. En cas d'échec, il ouvre une issue `securite` ou commente celle qui est ouverte.
- Le job `analyse` de la CI lance Semgrep CE avec les règles du registre (`p/default`). Il affiche tous les constats, et un constat de sévérité ERROR fait échouer la PR. Un faux positif s'écarte par un commentaire `# nosemgrep: <règle>` sur sa ligne, avec la raison juste au-dessus. `securite.yml` relance aussi cette analyse chaque lundi.
- Les actions de la CI sont épinglées par SHA. Chaque lundi, `.github/dependabot.yml` propose leurs mises à jour et celles des dépendances de chaque composant (`cargo`, `npm`, `uv`). Les mineures et les patchs d'un composant se groupent en une PR, et chaque majeure a la sienne. La CI les vérifie comme les autres PR, et tu les fusionnes. Une majeure qui casse la vérification passe par `/izanagi:task`, sur la PR de Dependabot.
- Au niveau de risque élevé, un troisième relecteur, `reviewer-security`, cherche dans le diff les failles que liste la fiche du type d'application.

## Règles par langage

`docs/CODING_STANDARDS.md` porte les règles communes à tous les langages. Chaque langage des composants a son fichier `docs/standards/<langage>.md`, pour les règles propres au projet. Le plugin porte des règles générales pour Rust, TypeScript et Python, dans `references/langages/`. Le relecteur et l'implémenteur lisent les deux couches. Une ligne `Écarte : R<n>, parce que <raison>` dans le fichier du projet désactive une règle du plugin.

`/izanagi:retro` range une règle valable hors du projet sous `## À proposer au plugin`, et `/izanagi:contribuer` la propose au plugin par une PR.

Comme la branche principale ne reçoit plus de push direct, un jalon passe par des PR du début à la fin : le cadrage et le plan sur une branche `jalon/<nom>-cadrage`, puis le jalon lui-même.

## Piles

Trois piles ont un gabarit complet : Rust, TypeScript avec Node (npm) et Python (uv). Pour chacune, `scripts/check.sh` lance l'installation depuis le verrou, le format, le lint, puis une étape par couche de test déclarée dans `harness.md`.

Pour une autre pile (Go, Java, C#, Swift…), `init` pose une section `# À ÉCRIRE` et la remplit en suivant `references/verification-contract.md`, qui fixe ce que `check.sh` et la CI doivent faire. Le script `check-contract.sh` du plugin contrôle ce contrat.

`scripts/check.sh` accepte trois options :

- `--host` vérifie le système courant seulement. Le hook pre-push l'utilise. Si le système courant n'est pas une cible, `check.sh` le saute ; sous Windows, il vérifie alors la copie WSL quand `linux` est une cible.
- `--complet` ajoute les couches fonctionnelles et se combine avec `--host`.
- `--clean` vide le cache WSL du projet.

Sous Windows, quand `linux` est un système cible, `check.sh` copie l'arbre de travail dans `~/.cache/<projet_dossier>-wsl` et y lance la vérification.

## Couches de test

Un projet a trois couches de test, définies par ce que le test traverse :

- la couche unitaire teste un module ou une fonction dans le processus, sans réseau, disque ni base ;
- la couche intégration teste le composant avec ses vraies dépendances (base de test, système de fichiers, HTTP local), par son interface de code ou ses routes ;
- la couche fonctionnelle teste le produit tel que l'utilisateur le touche : le binaire lancé, le service HTTP lancé, ou le navigateur avec Playwright.

Les couches se séparent par dossier :

| Pile | Unitaire | Intégration | Fonctionnelle |
|---|---|---|---|
| Rust | modules `#[cfg(test)]` de `src/` | `tests/*.rs` | `tests/fonctionnel_*.rs`, avec la feature `fonctionnel` |
| TypeScript | projet Vitest `unitaire` | projet Vitest `integration` | `npm run test:fonctionnel`, Vitest ou Playwright |
| Python | `tests/unitaires/` | `tests/integration/` | `tests/fonctionnels/` |

`scripts/check.sh` lance les couches unitaire et intégration de chaque composant. `scripts/check.sh --complet` lance en plus les couches fonctionnelles, puis l'entrée fonctionnelle du projet, un scénario qui traverse plusieurs composants. Chaque couche est une étape annoncée `-- <composant> : <couche>`. Le hook pre-push et le hook d'arrêt de l'implémenteur lancent la version courte. La fin de chaque tranche, `task` et `fix` avant leur revue, et la CI lancent `--complet`.

La CI lance `bash scripts/check.sh --host --complet` sur chaque système cible. Les tests Playwright n'y tournent que sur `ubuntu-latest`. Son job `couverture`, sur `ubuntu-latest` seul, relance la vérification complète avec la mesure de couverture (`cargo llvm-cov`, `vitest --coverage`, `pytest-cov`) et écrit le taux de chaque composant dans le résumé du job. Il n'a pas de seuil et ne fait jamais échouer la PR.

## Mutation

`scripts/mutation.sh` du plugin mute le code du diff et liste les mutants que les tests des couches unitaire et intégration laissent survivre, avec `cargo-mutants`, Stryker ou `mutmut` selon la pile. La passe tourne avant la revue de jalon, et avant la revue de `task` et de `fix` au seul niveau de risque élevé. `reviewer-standards` classe chaque survivant : Important s'il touche une couture convenue, Mineur sinon. La passe ne fait jamais échouer la vérification ni la CI.

Deux clés de `.izanagi/config.env` la règlent. `mutation=oui` l'active, et `init` l'écrit quand toutes les piles des composants ont un gabarit. `mutation_delai` borne sa durée, en minutes (15 par défaut). Son rapport cite ce qui n'a pas été muté, faute d'outil ou de temps. `/izanagi:doctor` contrôle l'outil de chaque pile et donne sa commande d'installation.

## Release et livraison

La clôture d'un jalon écrit la section de la version dans `CHANGELOG.md`, au format Keep a Changelog, et te la fait relire. Elle pose ensuite le tag `vX.Y.Z` sur le commit de fusion et ne le pousse qu'avec ton accord. Un correctif de `/izanagi:fix` fait de même quand tu choisis de le publier. `/izanagi:task` ne publie jamais. Son changement part dans la prochaine version. La première release crée `CHANGELOG.md`. Un projet migré n'y reçoit pas ses versions passées.

La clé `langue_publique` de `.izanagi/config.env` donne la langue du changelog et des notes de version, `fr` ou `en`. `init` la demande, et elle vaut `fr` par défaut.

Au push du tag, `.github/workflows/release.yml` contrôle que le tag vaut la version du fichier de version, puis `scripts/notes-de-version.sh` extrait la section de la version dans `CHANGELOG.md`. Un tag faux, ou une version sans section, arrête le workflow avant toute publication. Sinon, il construit le livrable et crée la release GitHub avec ces notes. Avec plusieurs composants, la version se lit dans celui que nomme la clé `version_composant`, le premier par défaut.

Le livrable dépend du type d'application, d'après sa fiche dans `references/types/` :

| Type | Livrable |
|---|---|
| cli | Rust : une archive des binaires par système cible, jointe à la release. TypeScript : le paquet sur npm. Python : le paquet sur PyPI. |
| library | le paquet sur crates.io, npm ou PyPI |
| api, web-frontend, plugin | aucun fichier, le tag et la release marquent la version |
| data-ml, desktop, game, mobile | aucun par défaut, le projet écrit le sien dans le job `livrable` de `release.yml` |

La publication sur un registre passe par la publication de confiance, sans jeton stocké en secret. Toi seul peux la configurer, côté registre, avant le premier tag.

Izanagi ne choisit pas d'hébergeur. Pour une api ou un front web, `init` demande la commande qui déploie un tag. La ligne « Déploiement » de `docs/agents/harness.md` porte cette commande, ou « à préciser ». Quand elle porte une commande, le projet reçoit `.github/workflows/deploiement.yml`, que tu lances à la main sur un tag (`gh workflow run deploiement.yml -f tag=vX.Y.Z`). Le workflow contrôle la forme du tag avant le checkout, puis lance la commande telle quelle. Pour revenir en arrière, relance le même workflow avec le tag précédent. Les secrets que la commande lit sont des secrets du dépôt GitHub, que toi seul peux poser. GitHub ne les met pas dans l'environnement de la commande, donc elle les écrit en expression `${{ secrets.NOM }}`, par exemple `FLY_API_TOKEN=${{ secrets.FLY_API_TOKEN }} flyctl deploy`.

`.github/pull_request_template.md` donne à chaque PR quatre titres : Quoi, Pourquoi, Vérification et Risque. Les PR que les flux ouvrent suivent ces titres.

`check-contract.sh` demande `release.yml` à un projet qui a des composants, et `deploiement.yml` quand la ligne « Déploiement » porte une commande. Il contrôle dans les deux que chaque action est épinglée par SHA et que chaque job déclare ses permissions.

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

## Feuille de route

La 0.5 clôt le chantier que fixe `docs/specs/2026-11-12-izanagi-harness-design.md`. La 0.6 ajoute la sécurité et l'auto-amélioration, d'après `docs/specs/2026-11-18-izanagi-0.6-securite-amelioration.md`. La 0.7 ajoute les couches de test, la couverture et la mutation, d'après `docs/specs/2026-11-19-izanagi-0.7-couches-de-test.md`. La 0.8 ajoute le changelog, la release, le livrable par type, le déploiement, le template de PR, le suivi des dépendances par Dependabot et l'analyse Semgrep, d'après `docs/specs/2026-11-20-izanagi-0.8-release-livraison.md`.

La 1.0 est la version où le harnais mène un projet de son cadrage jusqu'à une version publiée et livrée. Elle sortira après un projet mené de bout en bout. Ce projet démarre sur la 0.7 et y fait la réception de la 0.7. Il passe ensuite en 0.8 par `/izanagi:upgrade`, ce qui essaie la migration 0.8.0, et sa première release sert de réception à la 0.8.

Ce que la 0.8 n'ajoute pas passe en 1.x et ne retarde pas la 1.0 : des évals du plugin sur un projet témoin, une CI pour les tests d'Izanagi, les migrations de base de données, l'observabilité, la pile Go, entre autres. La spec de la 0.8 en donne la liste.

## Contribuer

Izanagi n'a pas de jalons. Chaque changement passe par une PR, relue par `/izanagi:jalon convergente`. La version suit semver dans `.claude-plugin/plugin.json`, avec un tag `vX.Y.Z` par version. Avant de pousser :

```bash
claude plugin validate .
```

```bash
bash tests/install.sh && bash tests/check-contract.sh && bash tests/skills.sh && bash tests/state.sh && bash tests/hooks.sh && bash tests/risk.sh && bash tests/tools.sh
```

`tests/skills.sh` contrôle la structure du plugin : les dix-huit skills, les cinq sous-agents, les outils des relecteurs et l'absence de renvoi à un skill externe obligatoire. `tests/state.sh` teste `scripts/state.sh`, `tests/hooks.sh` les quatre hooks, `tests/risk.sh` le calcul du niveau de risque, et `tests/tools.sh` les migrations, `status.sh`, `doctor.sh`, `refus.sh`, `mutation.sh` et la recherche de secrets de `check.sh`. Ce dernier prend plus de dix minutes sous Windows.

Les skills et les sous-agents dérivent des skills de Matt Pocock et de Superpowers, tous deux sous licence MIT. `NOTICE` cite les deux sources.
