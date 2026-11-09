# Contrat de vérification

Lu par `init` quand il pose ou remplit `scripts/check.sh` et la CI. `scripts/check-contract.sh <projet>` contrôle ce contrat sur un projet posé. Il ne vérifie rien tant que `docs/agents/harness.md` ne déclare aucun composant.

## Ce que fait `scripts/check.sh`

- **Arguments.** Sans argument, il vérifie tous les systèmes cibles atteignables depuis le poste. Avec `--host`, il vérifie le système courant seulement (c'est le mode du hook pre-push). Avec `--clean`, il vide le cache WSL du projet. Tout autre argument fait sortir le script avec le code 2, sans rien lancer.
- **Aucune saisie.** Le script ne pose aucune question et n'attend aucune entrée.
- **Ordre des étapes.** Pour chaque composant : installation depuis le verrou, format en vérification (sans réécrire), lint, puis tests. Le script s'arrête au premier échec.
- **Code de sortie.** 0 si tout passe, un autre code sinon.
- **Verrou.** Les dépendances s'installent depuis le fichier de verrou : `npm ci`, `uv sync --locked`, `cargo ... --locked`.

## WSL

Sous Windows, quand `linux` est un système cible, `check.sh` copie l'arbre de travail dans WSL, dans `~/.cache/<projet_dossier>-wsl`, puis y lance `check.sh --host`. La copie prend les fichiers suivis et les fichiers non suivis qui ne sont pas ignorés. Elle retire les fichiers disparus depuis la copie précédente. `node_modules`, `.venv` et `target` restent dans le cache d'une vérification à l'autre. Cette règle vaut pour toutes les piles.

## CI

Le fichier `.github/workflows/ci.yml` lance `bash scripts/check.sh --host` dans une matrice `os: [...]` qui a un job par système cible : `ubuntu-latest` pour `linux`, `windows-latest` pour `windows`, `macos-latest` pour `macos`. Il ne recopie aucune commande de vérification. Chaque pile ajoute seulement ses étapes d'installation (toolchain Rust, `setup-node`, `setup-uv`). Pour TypeScript, `setup-node` n'active pas le cache npm, car il échoue quand le fichier de verrou n'est pas à la racine.

## Forme d'une section de composant

Chaque composant a une section dans `check.sh`, tirée du fragment de sa pile. Voici celle de Rust :

```bash
# --- composant <nom> (<pile>) ---
verifier_<id>() {
  (
    cd "<chemin>"
    echo "-- <nom> : format"
    cargo fmt --all --check
    echo "-- <nom> : clippy"
    cargo clippy --workspace --all-targets --locked -q -- -D warnings
    echo "-- <nom> : tests"
    cargo test --workspace --locked
  )
}
```

Le contrôle cherche le marqueur `# --- composant <nom> (`. Le sous-shell `( ... )` isole le `cd`. Chaque étape annonce `-- <nom> : <étape>`. Les sections TypeScript et Python ajoutent une étape `installation` avant le format.

## Règles du contrôle

`check-contract.sh` applique ces huit règles et affiche `contrat : <fichier> : <règle enfreinte>` par écart.

1. `scripts/check.sh` existe, est exécutable et passe `bash -n`.
2. `check.sh --inconnu` sort avec le code 2 sans rien lancer. Cette règle ne court que si `check.sh` a un cas `--host`. Elle tourne sous `timeout`, avec un délai de 20 s (variable `IZANAGI_CONTRAT_DELAI`).
3. `check.sh` gère `--host` et `--clean`.
4. Aucun `À ÉCRIRE` ne reste dans `check.sh`, `ci.yml` ni `dev.sh`.
5. Chaque composant de `harness.md` a sa section `# --- composant <nom> (`.
6. Aucune installation sans verrou : ni `npm install`, ni `pip install`, ni `uv sync` sans `--locked`, ni `cargo build`, `test` ou `clippy` sans `--locked`.
7. La CI lance `bash scripts/check.sh --host`, et sa ligne `os: [...]` correspond aux systèmes de `harness.md`.
8. `docs/agents/harness.md` existe.

## Remplir une section `# À ÉCRIRE`

Une pile sans gabarit reçoit une section vide, marquée `# À ÉCRIRE : <composant> (<pile>), format, lint, tests`, et une étape de CI marquée `# À ÉCRIRE : installation de <pile>`. Pour chacune :

1. Cherche dans la documentation officielle de la pile les commandes de format (en mode vérification, sans réécriture), de lint et de test. Cherche aussi la commande d'installation depuis le verrou et l'option qui l'impose (`--locked`, `--frozen`, `ci`).
2. Si la pile n'a pas de formateur ou de linter officiel, prends l'outil que sa communauté tient pour standard et dis-le à l'utilisateur.
3. Remplace la ligne `# À ÉCRIRE` de `check.sh` par les étapes, dans l'ordre installation, format, lint, tests, avec un `echo "-- <nom> : <étape>"` avant chacune. Garde le sous-shell et le `cd`.
4. Remplace celle de `ci.yml` par l'action officielle qui installe la toolchain, épinglée à une version majeure.
5. Lance `bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-contract.sh" <racine du projet>`, puis `bash scripts/check.sh --host`. Corrige jusqu'à ce que les deux passent.
