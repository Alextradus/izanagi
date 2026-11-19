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
    # feature `fonctionnel`. L'étape nomme donc chaque test de `tests/` lu dans
    # `cargo metadata`, sauf `fonctionnel_*` et les tests qui déclarent des
    # `required-features` : ceux-là restent sautés, comme sans `--test`. Une
    # cible par ligne en coupant avant chaque `{"kind":`. Sans aucun test,
    # l'étape échoue.
    metadonnees="$(cargo metadata --no-deps --format-version 1 --locked)"
    debut='{"kind":'
    saut=$'\n'
    nom_cible='^\{"kind":\["test"\],[^}]*"name":"([^"]*)"'
    avec_features='"required-features":\["'
    tests_integration=()
    while IFS= read -r cible; do
      [[ $cible =~ $avec_features ]] && continue
      [[ $cible =~ $nom_cible ]] || continue
      nom="${BASH_REMATCH[1]}"
      [[ $nom == fonctionnel_* || " ${tests_integration[*]-} " == *" $nom "* ]] || tests_integration+=(--test "$nom")
    done <<<"${metadonnees//"$debut"/"$saut$debut"}"
    if [[ ${#tests_integration[@]} -eq 0 ]]; then
      echo "check.sh : {{composant}} : aucun test d'intégration dans tests/" >&2
      exit 1
    fi
    # Avec IZANAGI_COUVERTURE=1 : mesure gardée pour `cargo llvm-cov report`.
    if [[ ${IZANAGI_COUVERTURE:-} == 1 ]]; then
      cargo llvm-cov --no-report --workspace --locked "${tests_integration[@]}"
    else
      cargo test --workspace --locked "${tests_integration[@]}"
    fi
