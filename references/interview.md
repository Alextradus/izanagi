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

- **TypeScript.** `prettier`, `eslint` et `vitest` en dépendances de développement, et les scripts `format:check`, `lint` et `test` dans `package.json`. `package-lock.json` doit exister et être commité, car la vérification lance `npm ci`.
- **Python.** `ruff` et `pytest` en dépendances de développement (`uv add --dev ruff pytest`). `uv.lock` doit être commité.
- **Rust.** Rien. `cargo fmt`, `clippy` et `cargo test` sont déjà là. `Cargo.lock` doit être commité.
- **Autre pile.** Les outils de format, de lint et de test choisis pour remplir la section `# À ÉCRIRE`.
- **Toute pile.** Un premier test réel par composant, qui affirme un résultat du code créé (une fonction de l'exemple, l'import du paquet). Sans lui, la première vérification échoue : `pytest` sort avec 5 quand il ne trouve aucun test, `vitest` avec 1 quand il ne trouve aucun fichier de test.

## Consigner les réponses

`init` écrit un fichier de valeurs, une ligne `clé=valeur` par réponse, et le passe à `scripts/install.sh`.

- `type=<identifiant>` : le nom d'un fichier de `references/types/`, sans `.md` (`cli`, `api`, `web-frontend`, `desktop`, `mobile`, `library`, `game`, `data-ml`, `plugin`). Pour un type hors liste, prends l'identifiant de la fiche la plus proche.
- `couches=<texte>` : les couches de test retenues, tirées de la fiche du type et ajustées à la pile, par exemple `unitaires (vitest), e2e (Playwright)`.
- `systemes=<liste>` : sous-ensemble de `linux,windows,macos`, séparé par des virgules.
- `composant=<nom>|<chemin>|<pile>|<lancement>` : une ligne par composant. `<nom>` et `<pile>` suivent `[a-z0-9-]+`. `<pile>` vaut `rust`, `typescript`, `python` ou le nom de la pile choisie (`go`, `java`), sauf `aucune`, `core`, `code`, `vault` et `multi`, que `install.sh` refuse. `<lancement>` est la commande qui démarre le composant (`npm run dev`), vide s'il n'y en a pas.
- `test_manuel=<commande>` : avec un seul composant, la commande que donne l'utilisateur, sinon celle de la section « Test manuel par défaut » de la fiche du type, prise entre accents graves pour la pile du composant. Avec au moins deux composants, la valeur est `scripts/dev.sh` et la ligne s'omet.
- `lieu_test=<complément>` : où l'utilisateur essaie, en complément de phrase (« dans un terminal », « dans son navigateur »), tiré de la section « Test manuel par défaut » de la fiche du type. Aucun défaut ne le fournit.

Les autres clés (`projet`, `branche`, `spec`) gardent leur nom de la 0.1.
