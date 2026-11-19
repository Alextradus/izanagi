# Contrat de vérification

Lu par `init` quand il pose ou remplit `scripts/check.sh` et la CI. Le script `check-contract.sh <projet>` du plugin contrôle ce contrat sur un projet posé. Un `docs/agents/harness.md` absent est un écart (règle 8). Le script n'a rien à vérifier quand `harness.md` existe et ne déclare aucun composant.

## Ce que fait `scripts/check.sh`

- **Arguments.** Sans argument, il vérifie tous les systèmes cibles atteignables depuis le poste. Avec `--host`, il vérifie le système courant seulement (c'est le mode du hook pre-push). Un système courant hors des cibles est sauté avec le message `<système> : hors des cibles, sauté`. Sous Windows, `--host` vérifie alors la copie WSL si `linux` est une cible. Avec `--complet`, il ajoute aux couches unitaire et intégration les couches fonctionnelles des composants, puis l'entrée fonctionnelle du projet. Les options `--host` et `--complet` se combinent. Avec `--clean`, il vide le cache WSL du projet. Tout autre argument fait sortir le script avec le code 2, sans rien lancer.
- **Aucune saisie.** Le script ne pose aucune question et n'attend aucune entrée.
- **Ordre des étapes.** Pour chaque composant : installation depuis le verrou, format en vérification (sans réécrire), lint, puis une étape par couche de test déclarée : `unitaire`, `integration`, et `fonctionnelle` seulement avec `--complet`. L'entrée fonctionnelle du projet, si elle existe, passe après tous les composants. Le script s'arrête au premier échec.
- **Code de sortie.** 0 si tout passe, un autre code sinon.
- **Verrou.** Les dépendances s'installent depuis le fichier de verrou : `npm ci`, `uv sync --locked`, `cargo ... --locked`.

## Secrets et dépendances

`check.sh` cherche des secrets avant de vérifier les composants, avec la fonction `verifier_secrets` du gabarit. Elle lance `gitleaks git --redact` sur les commits de la branche absents de la branche principale, avec la configuration `.gitleaks.toml` du projet. Elle prend la plage `<branche>..HEAD`, sinon `origin/<branche>..HEAD`, sinon tout l'historique. Elle ne dépend d'aucune pile : une pile sans gabarit la garde telle quelle. Hors d'un dépôt git, comme dans la copie WSL, elle annonce qu'elle saute l'étape. Sans `gitleaks`, elle échoue et renvoie à `/izanagi:doctor`.

L'audit des dépendances tourne dans la CI, pas dans `check.sh` : il a besoin du réseau, et une faille publiée après coup bloquerait sinon le push d'un changement sans rapport. Le job `audit` de `ci.yml` le lance sur chaque PR, et `securite.yml` le relance chaque semaine avec `gitleaks` sur tout l'historique. Une faille de gravité haute ou critique fait échouer le job (`cargo audit` avec `severity_threshold`, `npm audit --audit-level=high`). `pip-audit` ne filtre pas par gravité : pour Python, toute faille connue fait échouer le job. Les actions de la CI sont épinglées par SHA, et `.github/dependabot.yml` propose leurs mises à jour.

## WSL

Sous Windows, quand `linux` est un système cible, `check.sh` copie l'arbre de travail dans WSL, dans `~/.cache/<projet_dossier>-wsl`, puis y lance `check.sh --host`. La copie prend les fichiers suivis et les fichiers non suivis qui ne sont pas ignorés. Elle retire les fichiers disparus depuis la copie précédente. `node_modules`, `.venv` et `target` restent dans le cache d'une vérification à l'autre. Cette règle vaut pour toutes les piles.

## CI

Le fichier `.github/workflows/ci.yml` lance `bash scripts/check.sh --host --complet` dans une matrice `os: [...]` qui a un job par système cible : `ubuntu-latest` pour `linux`, `windows-latest` pour `windows`, `macos-latest` pour `macos`. Il ne recopie aucune commande de vérification. Chaque pile ajoute seulement ses étapes d'installation (toolchain Rust, `setup-node`, `setup-uv`). Pour TypeScript, `setup-node` n'active pas le cache npm, car il échoue quand le fichier de verrou n'est pas à la racine.

Avec `navigateur=oui`, le job `check` installe les navigateurs Playwright sur `ubuntu-latest` seulement, dans le dossier de chaque composant TypeScript qui a une couche fonctionnelle, et à la racine quand la commande de l'entrée fonctionnelle du projet emploie Playwright. Il passe `IZANAGI_NAVIGATEUR=non` aux autres systèmes : les étapes fonctionnelles de ces composants et de l'entrée du projet affichent `-- <nom> : fonctionnelle : navigateur absent de ce système, sauté` et rendent 0.

Le job `couverture` tourne sur `ubuntu-latest` et lance `IZANAGI_COUVERTURE=1 bash scripts/check.sh --host --complet`. Avec cette variable, les étapes de test mesurent la couverture (`cargo llvm-cov`, Vitest avec `--coverage`, `pytest-cov`), et `check.sh` écrit à la fin le résumé de chaque composant, aussi dans `$GITHUB_STEP_SUMMARY`. Le job a `continue-on-error: true` : il n'a pas de seuil et ne fait jamais échouer la PR. Une pile sans gabarit n'a pas de mesure, et son résumé le dit.

## Forme d'une section de composant

Chaque composant a une section dans `check.sh`, tirée du fragment de sa pile, et une fonction `verifier_<id>_fonctionnelle` à part si la couche fonctionnelle est déclarée. Voici celles de Rust, avec les couches unitaire, intégration et fonctionnelle :

```bash
# --- composant <nom> (<pile>) ---
verifier_<id>() {
  (
    cd "<chemin>"
    echo "-- <nom> : format"
    cargo fmt --all --check
    echo "-- <nom> : clippy"
    cargo clippy --workspace --all-targets --locked -q -- -D warnings
    echo "-- <nom> : unitaire"
    <commandes de la couche unitaire>
    echo "-- <nom> : integration"
    <commandes de la couche intégration>
  )
}

verifier_<id>_fonctionnelle() {
  (
    cd "<chemin>"
    echo "-- <nom> : fonctionnelle"
    <commandes de la couche fonctionnelle>
  )
}
```

Les étapes de test viennent des fragments `test-<couche>.sh` de la pile, placés à l'endroit de `{{etapes}}`. Seules les couches `unitaire` et `integration` entrent dans la section. Les fonctions `verifier_<id>_fonctionnelle` et `verifier_projet_fonctionnelle` ne tournent qu'avec `--complet`.

Le contrôle cherche le marqueur `# --- composant <nom> (`. Le sous-shell `( ... )` isole le `cd`. Chaque étape annonce `-- <nom> : <étape>`, avec les noms de couche sans accent : `unitaire`, `integration`, `fonctionnelle`. Les sections TypeScript et Python ajoutent une étape `installation` avant le format.

## Règles du contrôle

`check-contract.sh` applique ces onze règles et affiche `contrat : <fichier> : <règle enfreinte>` par écart.

1. `scripts/check.sh` existe, est exécutable et passe `bash -n`.
2. `check.sh --inconnu` sort avec le code 2 sans rien lancer. Cette règle ne court que si `check.sh` a un cas `--host`. Elle tourne sous `timeout`, avec un délai de 20 s (variable `IZANAGI_CONTRAT_DELAI`).
3. `check.sh` gère `--host` et `--clean`.
4. Aucun `À ÉCRIRE` ne reste dans `check.sh`, `ci.yml`, `securite.yml` ni `dev.sh`.
5. Chaque composant de `harness.md` a sa section `# --- composant <nom> (`.
6. Aucune installation sans verrou : ni `npm install`, ni `pip install`, ni `uv sync` sans `--locked`, ni `cargo build`, `test` ou `clippy` sans `--locked`.
7. Le job `check` de la CI lance `bash scripts/check.sh --host --complet`, sur une ligne à lui (après `run:` ou dans un bloc `run: |`), et sa ligne `os: [...]` correspond aux systèmes de `harness.md`.
8. `docs/agents/harness.md` existe.
9. `check.sh` lance la recherche de secrets (`gitleaks git`).
10. Chaque ligne `- couche : <composant> | <couche> | …` de `harness.md` a son étape `-- <composant> : <couche>` dans `check.sh`, et la ligne `projet` demande `-- projet : fonctionnelle`. Un `harness.md` qui a des composants et aucune ligne `- couche :` est un écart.
11. `check.sh` gère `--complet`.

## Remplir une section `# À ÉCRIRE`

Une pile sans gabarit reçoit une section vide, marquée `# À ÉCRIRE : <composant> (<pile>), format, lint, tests`, une étape de CI marquée `# À ÉCRIRE : installation de <pile>`, et une étape d'audit marquée `# À ÉCRIRE : audit des dépendances de <composant> (<pile>)` dans `ci.yml` et `securite.yml`. Pour chacune :

1. Cherche dans la documentation officielle de la pile les commandes de format (en mode vérification, sans réécriture), de lint et de test. Cherche aussi la commande d'installation depuis le verrou et l'option qui l'impose (`--locked`, `--frozen`, `ci`).
2. Si la pile n'a pas de formateur ou de linter officiel, prends l'outil que sa communauté tient pour standard et dis-le à l'utilisateur.
3. Remplace la ligne `# À ÉCRIRE` de `check.sh` par les étapes, dans l'ordre installation, format, lint, tests, avec un `echo "-- <nom> : <étape>"` avant chacune. Garde le sous-shell et le `cd`.
4. Remplace celle de `ci.yml` par l'action officielle qui installe la toolchain, épinglée par le SHA de son étiquette, avec l'étiquette en commentaire (`uses: <action>@<SHA> # v1.2.3`). Lis le SHA avec `gh api repos/<propriétaire>/<action>/commits/<étiquette> --jq .sha`.
5. Remplace les deux lignes d'audit par l'outil d'audit officiel de la pile, lancé dans le dossier du composant (`working-directory`). Il échoue sur une faille de gravité haute ou critique et signale les autres, si l'outil sait filtrer par gravité. Sinon, il échoue sur toute faille connue, et dis-le à l'utilisateur.
6. Lance `bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-contract.sh" <racine du projet>`, puis `bash scripts/check.sh --host`. Corrige jusqu'à ce que les deux passent.
