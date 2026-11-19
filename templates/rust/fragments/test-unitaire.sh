    echo "-- {{composant}} : unitaire"
    # Faits Cargo, lus le 2026-11-19 :
    # - `--doc` ne se combine avec aucune autre option de cible.
    #   https://doc.rust-lang.org/cargo/commands/cargo-test.html
    # - `--lib` et `--doc` sortent en erreur (« no library targets found ») quand
    #   aucun paquet choisi n'a de bibliothèque. Source : unit_generator.rs de
    #   https://github.com/rust-lang/cargo (src/ops/cargo_compile/), essayé avec cargo 1.99.
    # La bibliothèque se cherche donc dans `cargo metadata`, qui couvre tout
    # l'espace de travail, même quand la racine est un manifeste virtuel.
    metadonnees="$(cargo metadata --no-deps --format-version 1 --locked)"
    bibliotheque='"kind":\[[^]]*"(lib|rlib|proc-macro)"'
    if [[ $metadonnees =~ $bibliotheque ]]; then
      cargo test --workspace --locked --lib --bins
      cargo test --workspace --locked --doc
    else
      cargo test --workspace --locked --bins
    fi
