# Tests

[Guide](README.md) · [Démarrer](demarrer.md) · [Les flux](flux.md) · [Tests](tests.md) · [Garde-fous](garde-fous.md) · [Release](release.md)

Chaque projet posé par Izanagi a une vérification, `scripts/check.sh`, qui lance le format, le lint et les tests couche par couche. Les flux la lancent à chaque étape, le hook pre-push et le hook d'arrêt de l'implémenteur aussi, et la CI la relance sur chaque système cible.

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

Chaque fiche de `references/types/` dit ce que chaque couche teste pour son type d'application, ou qu'une couche est sans objet. `init` ne déclare que les couches qui ont un sens pour le type, et écrit un premier test dans chacune. Pour un jeu, la couche fonctionnelle lance le binaire par ses entrées hors partie (`--version`, un fichier passé en argument) ; la partie jouée reste au test manuel.

## La double boucle

Une tranche qui change un comportement visible porte dans le plan une ligne `**Acceptation :**`, un scénario écrit à la couche fonctionnelle. Le skill `tdd` le fait écrire en premier et voir en échec. Puis viennent les cycles rouge, vert, refactor des couches unitaire et intégration, jusqu'à ce que le scénario passe à la fin de la tranche. C'est la double boucle : la boucle externe dit quand la tranche est finie, la boucle interne fait avancer le code.

Une tranche n'a pas cette ligne quand le projet n'a aucune couche fonctionnelle, ou quand le comportement ne se voit que par une voie que cette couche ne traverse pas (la partie jouée d'un jeu). Le plan dit alors pourquoi, et le test manuel en tient lieu.

Le relecteur `reviewer-spec` contrôle que chaque test est à la couche que la couture demande. Un test glissé à la mauvaise couche est un constat Important.

## Mutation

`scripts/mutation.sh` du plugin mute le code du diff et liste les mutants que les tests des couches unitaire et intégration laissent survivre, avec `cargo-mutants`, Stryker ou `mutmut` selon la pile. La passe tourne avant la revue de jalon, et avant la revue de `task` et de `fix` au seul niveau de risque élevé. `reviewer-standards` classe chaque survivant : Important s'il touche une couture convenue, Mineur sinon. La passe ne fait jamais échouer la vérification ni la CI.

Deux clés de `.izanagi/config.env` la règlent. `mutation=oui` l'active, et `init` l'écrit quand toutes les piles des composants ont un gabarit. `mutation_delai` borne sa durée, en minutes (15 par défaut). Son rapport cite ce qui n'a pas été muté, faute d'outil ou de temps. `/izanagi:doctor` contrôle l'outil de chaque pile et donne sa commande d'installation.

## Règles par langage

`docs/CODING_STANDARDS.md` porte les règles communes à tous les langages. Chaque langage des composants a son fichier `docs/standards/<langage>.md`, pour les règles propres au projet. Le plugin porte des règles générales pour Rust, TypeScript et Python, dans `references/langages/`. Le relecteur et l'implémenteur lisent les deux couches. Une ligne `Écarte : R<n>, parce que <raison>` dans le fichier du projet désactive une règle du plugin.

`/izanagi:retro` range une règle valable hors du projet sous `## À proposer au plugin`, et `/izanagi:contribuer` la propose au plugin par une PR.

Comme la branche principale ne reçoit plus de push direct, un jalon passe par des PR du début à la fin : le cadrage et le plan sur une branche `jalon/<nom>-cadrage`, puis le jalon lui-même.
