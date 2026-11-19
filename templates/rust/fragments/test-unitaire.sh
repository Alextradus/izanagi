    echo "-- {{composant}} : unitaire"
    # Faits Cargo, lus le 2026-11-19 :
    # - `--doc` ne se combine avec aucune autre option de cible.
    #   https://doc.rust-lang.org/cargo/commands/cargo-test.html
    # - `--lib` et `--doc` sortent en erreur (« no library targets found ») quand
    #   aucun paquet choisi n'a de bibliothèque. Source : unit_generator.rs de
    #   https://github.com/rust-lang/cargo (src/ops/cargo_compile/), essayé avec cargo 1.99.
    # - Dans `cargo metadata`, `"doctest":true` marque une bibliothèque dont les
    #   doctests tournent : type lib, rlib ou proc-macro, sans `doctest = false`.
    #   Source : src/workspace/manifest.rs du même dépôt.
    # La bibliothèque se cherche donc dans `cargo metadata`, qui couvre tout
    # l'espace de travail, même quand la racine est un manifeste virtuel. Une
    # bibliothèque de tout type (cdylib et staticlib compris) a des tests `--lib`.
    metadonnees="$(cargo metadata --no-deps --format-version 1 --locked)"
    bibliotheque='"kind":\[[^]]*"(lib|rlib|dylib|cdylib|staticlib|proc-macro)"'
    if [[ $metadonnees =~ $bibliotheque ]]; then
      cargo test --workspace --locked --lib --bins
    else
      cargo test --workspace --locked --bins
    fi
    if [[ $metadonnees == *'"doctest":true'* ]]; then
      cargo test --workspace --locked --doc
    fi
