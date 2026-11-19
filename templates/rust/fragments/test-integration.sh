    echo "-- {{composant}} : integration"
    # Faits Cargo, lus le 2026-11-19 :
    # - `--test` accepte un motif glob entre guillemets.
    #   https://doc.rust-lang.org/cargo/commands/cargo-test.html
    # - Une cible dont une feature de `required-features` manque est sautée sans
    #   bruit quand rien ne la nomme, mais une cible choisie par `--test`, nom ou
    #   motif, fait échouer la commande (« requires the features »).
    #   https://doc.rust-lang.org/cargo/reference/cargo-targets.html et
    #   unit_generator.rs de https://github.com/rust-lang/cargo, essayé avec cargo 1.99.
    # Le motif `'*'` prendrait les tests `fonctionnel_*` et échouerait sans la
    # feature `fonctionnel`. L'étape nomme donc chaque test de `tests/` hors
    # `fonctionnel_*`, lus dans `cargo metadata` (champs `kind`, `crate_types`
    # puis `name`, dans cet ordre). Sans aucun test, l'étape échoue.
    metadonnees="$(cargo metadata --no-deps --format-version 1 --locked)"
    tests_integration=()
    while IFS= read -r nom; do
      [[ $nom == fonctionnel_* ]] || tests_integration+=(--test "$nom")
    done < <(grep -oE '"kind":\["test"\],"crate_types":\[[^]]*\],"name":"[^"]*"' <<<"$metadonnees" |
      sed -e 's/.*"name":"//' -e 's/"$//' | sort -u)
    if [[ ${#tests_integration[@]} -eq 0 ]]; then
      echo "check.sh : {{composant}} : aucun test d'intégration dans tests/" >&2
      exit 1
    fi
    cargo test --workspace --locked "${tests_integration[@]}"
