# Izanagi 0.2 : un harnais pour toute pile et tout type d'application

Décisions prises le 2026-11-09 lors d'un entretien (grilling). Elles font foi pour la 0.2.0.

## But

Tout projet démarre par `/izanagi:init`. Sur un dossier vide, `init` aide à choisir la pile, crée le projet avec l'outil officiel de cette pile et pose un harnais réglé sur le type d'application. Sur un projet existant, il détecte la pile et pose ou compare le harnais, comme en 0.1.

## Décisions

### Démarrage

1. `/izanagi:init` reste la seule commande. Il prend le chemin « dossier vide » ou « projet existant » selon ce qu'il trouve. Le dossier vide est le cas principal.
2. Sur un dossier vide, `init` mène un entretien d'une dizaine de questions au plus, posées par groupes. Il couvre le problème à résoudre, le type d'application, les utilisateurs et leurs appareils, les contraintes (performance, hors ligne, hébergement, budget), les langages que l'utilisateur connaît ou veut apprendre, et les systèmes cibles. Windows et Linux (WSL) sont proposés par défaut. La spec du projet n'est pas écrite ici : elle reste au cadrage du premier jalon.
3. `init` recommande une pile et justifie son choix. L'utilisateur tranche. `init` lance ensuite l'outil de création officiel de la pile (`cargo init`, `npm create vite`, `uv init`…). Le plugin n'a pas de squelette d'application à lui.
4. Sur un dossier vide, `init` propose `gh repo create` (privé par défaut) et le lance si l'utilisateur accepte. La CI reste sur GitHub Actions seulement.
5. Quand un outil manque (rustup, node, uv, Playwright…), `init` donne la commande d'installation et attend l'accord de l'utilisateur avant de la lancer. Il n'installe jamais rien de lui-même.

### Contrat de vérification

6. `references/verification-contract.md` fixe ce que `scripts/check.sh` doit faire :
   - sans argument, vérifier sur tous les systèmes cibles atteignables depuis le poste ; avec `--host`, sur le système courant seulement (c'est le mode du hook pre-push) ; un système courant hors des cibles est sauté, et sous Windows `--host` vérifie alors la copie WSL si `linux` est une cible ; avec `--clean`, vider le cache WSL du projet ; tout autre argument fait sortir le script avec le code 2 ;
   - ne poser aucune question et ne demander aucune saisie ;
   - pour chaque composant, passer le format (en vérification, sans réécrire), le lint, puis les tests, et s'arrêter au premier échec ;
   - sortir avec 0 si tout passe, avec un autre code sinon ;
   - installer les dépendances depuis le fichier de verrou.
7. La CI lance `bash scripts/check.sh --host` dans une matrice qui a un job par système cible. Elle ne recopie aucune commande de vérification.
8. Sous Windows, quand Linux est un système cible, `check.sh` copie l'arbre de travail dans WSL, dans `~/.cache/<projet_dossier>-wsl`, puis vérifie cette copie. La copie prend les fichiers suivis et les fichiers non suivis qui ne sont pas ignorés, et retire de la copie les fichiers disparus. Les dépendances installées (`node_modules`, `.venv`, `target`) restent dans le cache d'une vérification à l'autre. Cette règle vaut pour toutes les piles.

### Harnais

9. Les piles de référence, avec des gabarits testés, sont Rust, TypeScript/Node (avec npm) et Python (avec uv). Pour toute autre pile, Claude écrit la partie propre à la pile en suivant le contrat.
10. `check.sh` est assemblé à partir d'un squelette commun et d'une section par composant, tirée du fragment de la pile de ce composant. La CI suit le même principe : un squelette, puis les étapes d'installation de chaque pile. Pour une pile sans gabarit, le script de pose écrit une section marquée `# À ÉCRIRE`, que `init` remplit ensuite.
11. Un dépôt peut avoir plusieurs composants, par exemple un front et une API. Il garde un seul `scripts/check.sh`. Quand il y a au moins deux composants, `scripts/dev.sh` les lance tous, et `test_manuel` vaut `scripts/dev.sh`. `jalon` ne change pas.
12. Chaque type d'application a une fiche dans `references/types/<type>.md`. La fiche donne les couches de test, le test manuel par défaut, les sections de `CODING_STANDARDS.md` et les prérequis du type. La liste de départ est : CLI, API ou service, front web, application de bureau, mobile, bibliothèque, jeu, data/ML, plugin ou extension. Pour un type hors de la liste, Claude part de la fiche la plus proche. Le déploiement n'entre pas dans cette version.
13. `docs/agents/harness.md` garde les choix faits à l'entretien : type, composants (nom, chemin, pile, commande de lancement), systèmes cibles, couches de test. À la relance, `init` relit ce fichier au lieu de reposer les questions. Il compare aux gabarits ce qui vient d'un gabarit, et contrôle le reste avec le script de contrôle du contrat.
14. Pour un projet posé en 0.1, qui n'a pas de `harness.md`, `init` écrit ce fichier à partir de ce qu'il détecte (pile, systèmes visibles dans la CI, valeurs de `jalon.md`). Il demande seulement le type d'application.

### Fin d'`init`

15. Le bilan finit par une liste ordonnée des prochaines étapes, propre au projet, avec la commande exacte de chaque étape. L'ordre est le suivant : commit du cadre, outils à installer, sections de `CODING_STANDARDS.md` à remplir, puis premier `/izanagi:jalon`. `init` propose de lancer tout de suite la première étape qui ne demande pas d'accord.

### Nommage

16. Les nouveaux fichiers et les fichiers internes du plugin ont des noms anglais. `scripts/pose.sh` devient `scripts/install.sh`, `valeurs.defaut` devient `defaults.env`, `references/constat.md` devient `references/finding.md`. Le contenu reste en français.
17. Ce qui est déjà posé dans les projets garde son nom : `docs/agents/jalon.md`, `/izanagi:jalon`, et les clés de valeurs en français (`projet`, `branche`…).
18. Le plugin ne mentionne plus aucun projet réel.

### Livraison

19. La version est la 0.2.0. Ses critères de réception sont les suivants :
    - à la relance sur un projet posé en 0.1, les seuls écarts sont `scripts/check.sh` et `.github/workflows/ci.yml` en `différent`, et `docs/agents/harness.md` en `créé` ; `init` présente les deux premiers comme la mise à jour du gabarit 0.2 et propose de les reprendre ;
    - trois scénarios passent en bac à sable : une CLI Rust, un front et une API en TypeScript, un outil data en Python ;
    - un test automatique contrôle qu'un harnais posé respecte le contrat.
