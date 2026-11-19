# Entretien de départ

Lu par `init` sur un dossier vide. Il pose une dizaine de questions au plus, en deux appels à AskUserQuestion au plus. La spec du projet n'est pas écrite ici : elle vient au cadrage du premier jalon.

## Questions

Premier appel, le besoin :

- le problème à résoudre ;
- le type d'application (voir `references/types/`) ;
- les utilisateurs et leurs appareils ;
- les contraintes : performance, hors ligne, hébergement, budget.

Second appel, la technique :

- les langages que l'utilisateur connaît ou veut apprendre ;
- les systèmes cibles (Windows et Linux par WSL sont proposés par défaut, macOS en option) ;
- le nom du projet, et si `init` crée le dépôt GitHub (privé par défaut).

Ne repose pas une question dont la réponse est déjà dans le message de l'utilisateur.

## Choisir la pile

Recommande une pile et justifie-la en une ou deux phrases. L'utilisateur tranche. Les critères, par ordre de poids :

1. Les langages que l'utilisateur connaît ou veut apprendre.
2. Le type d'application : un front web demande TypeScript, une CLI ou un outil système va bien en Rust, un outil de données ou de ML va bien en Python.
3. Les plateformes ciblées. Un mobile ou un jeu impose souvent le moteur ou le SDK.
4. Les contraintes : performance, hors ligne, taille du binaire.

Les piles de référence (Rust, TypeScript avec npm, Python avec uv) ont des gabarits testés. Une pile hors de ces trois est permise. Le contrat de vérification (`references/verification-contract.md`) la gouverne alors : la section `# À ÉCRIRE` se remplit avec les commandes officielles de la pile.

## Créer le projet

`init` lance l'outil officiel après l'accord de l'utilisateur, dans le dossier du composant.

| Pile | Commande |
|---|---|
| Rust | `cargo init` |
| TypeScript, front | `npm create vite@latest . -- --template <react-ts\|vue-ts\|svelte-ts\|vanilla-ts>` |
| TypeScript, API | `npm init -y`, puis `typescript`, `tsx` et un framework au choix |
| Python | `uv init` |

## Ce qu'`init` ajoute après la création

- **TypeScript.** `prettier`, `vitest` et `@vitest/coverage-v8` en dépendances de développement. Le job `couverture` de la CI lance `vitest --coverage`, qui demande `@vitest/coverage-v8`. Dans `package.json`, les scripts `format:check` (`prettier --check .`), `lint`, `test` (`vitest run`) et un script par couche déclarée : `test:unitaire` (`vitest run --project unitaire`), `test:integration` (`vitest run --project integration`) et `test:fonctionnel` (`vitest run --project fonctionnel`, ou `playwright test` quand la couche fonctionnelle emploie Playwright). La configuration Vitest (`vitest.config.ts`, ou `vite.config.ts` pour un front Vite) déclare dans `test.projects` un projet nommé par couche déclarée : `unitaire` avec `include: ['src/**/*.test.ts']`, `integration` avec `include: ['tests/integration/**/*.test.ts']`, `fonctionnel` avec `include: ['tests/fonctionnels/**/*.test.ts']`. Pour un front, ajoute l'extension `.tsx` aux motifs, et le projet `integration` prend `environment: 'jsdom'`, avec `jsdom` et la Testing Library du framework (`@testing-library/react`, `@testing-library/vue`, `@testing-library/svelte`) en dépendances de développement. Quand la couche fonctionnelle emploie Playwright, ajoute `@playwright/test` et un `playwright.config.ts` dont `testDir` vaut `tests/fonctionnels` et dont `webServer` lance `npm run dev`. Si le modèle de création a déjà un script `lint` (Vite fournit `oxlint`), garde-le. Sinon, ajoute `eslint` avec `typescript-eslint` et un `eslint.config.js`. Écris un `.prettierrc.json` qui contient `{ "endOfLine": "auto" }` : avec `core.autocrlf`, un clone Windows reçoit des fins de ligne CRLF, que prettier refuse par défaut. `package-lock.json` doit exister et être commité, car la vérification lance `npm ci`.
- **Python.** `ruff` et `pytest` en dépendances de développement (`uv add --dev ruff pytest`). Un dossier par couche déclarée : `tests/unitaires/`, `tests/integration/` et `tests/fonctionnels/`. La vérification lance `pytest` sur chacun. Deux fichiers de test de dossiers différents ne portent pas le même nom : sans `__init__.py`, pytest refuse ce doublon dans son mode d'import par défaut. `uv.lock` doit être commité.
- **Rust.** `cargo fmt`, `clippy` et `cargo test` sont déjà là. La couche unitaire vit dans les modules `#[cfg(test)]`, la couche d'intégration dans `tests/<nom>.rs`. Un test de `tests/` n'importe que la bibliothèque du paquet : pour un binaire, mets la logique dans `src/lib.rs`. Pour une couche fonctionnelle, ajoute à `Cargo.toml` la feature `fonctionnel = []` dans `[features]`, et une entrée `[[test]]` par fichier `tests/fonctionnel_<nom>.rs`, avec `name = "fonctionnel_<nom>"`, `path = "tests/fonctionnel_<nom>.rs"` et `required-features = ["fonctionnel"]`. Pour une cli, ajoute `assert_cmd` en dépendance de développement (`cargo add --dev assert_cmd`). `Cargo.lock` doit être commité.
- **Autre pile.** Les outils de format, de lint et de test choisis pour remplir la section `# À ÉCRIRE`, avec une commande par couche déclarée.
- **Toute pile, `.gitignore`.** Le `.gitignore` de la racine ignore `node_modules/`, `.venv/`, `target/` et `dist/`. `init` ajoute les lignes qui manquent, sans en retirer aucune. Dans un dépôt git existant, `cargo init <dossier>` et `npm init -y` n'écrivent pas de `.gitignore`, et la copie WSL de `check.sh` prend tous les fichiers non ignorés.
- **Toute pile, premier test.** Un premier test réel par couche déclarée de chaque composant, dans le dossier de la couche, qui affirme un résultat du code créé. Pour les couches unitaire et d'intégration, il appelle une fonction de l'exemple ou importe le paquet. Pour la couche fonctionnelle, il lance `--help` pour une cli et vérifie le code de sortie, appelle une route de santé pour une api, et charge la page pour un front. Une étape de couche ne tolère pas un dossier vide : `pytest` sort avec 5 quand il ne trouve aucun test, `vitest` avec 1 quand il ne trouve aucun fichier de test, et `check.sh` échoue sur une couche Rust sans test.

## Consigner les réponses

`init` écrit un fichier de valeurs, une ligne `clé=valeur` par réponse, et le passe à `scripts/install.sh`.

- `type=<identifiant>` : le nom d'un fichier de `references/types/`, sans `.md` (`cli`, `api`, `web-frontend`, `desktop`, `mobile`, `library`, `game`, `data-ml`, `plugin`). Pour un type hors liste, prends l'identifiant de la fiche la plus proche.
- `systemes=<liste>` : sous-ensemble de `linux,windows,macos`, séparé par des virgules.
- `composant=<nom>|<chemin>|<pile>|<lancement>|<couches>` : une ligne par composant. `<nom>` et `<pile>` suivent `[a-z0-9-]+`. `<pile>` vaut `rust`, `typescript`, `python` ou le nom de la pile choisie (`go`, `java`), sauf `aucune`, `core`, `code`, `vault` et `multi`, que `install.sh` refuse. `<lancement>` est la commande qui démarre le composant (`npm run dev`), vide s'il n'y en a pas. `<couches>` liste les couches déclarées, séparées par des virgules, parmi `unitaire`, `integration` et `fonctionnelle`. Elles viennent de la section « Couches de test » de la fiche du type du composant : une couche « sans objet » n'y figure pas. Un front donne `unitaire,integration,fonctionnelle`, une bibliothèque `unitaire,integration`. Vide, le champ vaut `unitaire`.
- `navigateur=oui` : quand une couche fonctionnelle emploie Playwright (un front). Sans cette ligne, la valeur est `non`.
- `fonctionnel_projet=<dossier>|<commande>` : pour un projet à plusieurs composants dont la fiche d'un composant a une couche fonctionnelle. C'est l'entrée des scénarios qui traversent plusieurs composants (un front et son api), lancée à la racine après les composants. Avec un front, la valeur est `tests/fonctionnels|npx playwright test`. La racine reçoit alors un `package.json` avec `@playwright/test`, son `package-lock.json`, et un `playwright.config.ts` dont `testDir` vaut `tests/fonctionnels` et dont `webServer` lance `bash scripts/dev.sh`. Sans front, prends la commande de test d'une pile du projet qui tourne depuis la racine (`uv run --project api pytest tests/fonctionnels` pour une api Python dans `api/`). `init` écrit un premier scénario dans le dossier.
- `test_manuel=<commande>` : avec un seul composant, la commande que donne l'utilisateur, sinon celle de la section « Test manuel par défaut » de la fiche du type, prise entre accents graves pour la pile du composant. Avec au moins deux composants, la valeur est `scripts/dev.sh` et la ligne s'omet.
- `lieu_test=<complément>` : où l'utilisateur essaie, en complément de phrase (« dans un terminal », « dans son navigateur »), tiré de la section « Test manuel par défaut » de la fiche du type. Aucun défaut ne le fournit.

- `chemins_sensibles=<motifs>` : les chemins dont tout changement demande la revue la plus profonde, séparés par des virgules (`db/migrations/*, src/auth/*`). Demande à l'utilisateur où sont les données, la sécurité, les migrations et l'API publique du projet. Dans un dossier vide, la clé reste vide : rappelle à l'utilisateur de la remplir quand ces dossiers existeront.

Les autres clés (`projet`, `branche`, `spec`) gardent leur nom de la 0.1.
