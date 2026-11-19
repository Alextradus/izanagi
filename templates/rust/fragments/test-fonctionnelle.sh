    echo "-- {{composant}} : fonctionnelle"
    # Faits Cargo, lus le 2026-11-19 :
    # - `--test` accepte un motif glob entre guillemets. Un motif sans cible
    #   fait échouer la commande : une couche vide ne passe pas.
    #   https://doc.rust-lang.org/cargo/commands/cargo-test.html
    # - Avec le résolveur 2 ou plus (éditions 2021 et 2024), `--features` vaut
    #   pour tous les paquets choisis par `--workspace`.
    #   https://doc.rust-lang.org/cargo/reference/features.html
    #   Essayé avec cargo 1.99 : un espace de travail où un seul paquet déclare
    #   la feature `fonctionnel` passe.
    cargo test --workspace --locked --features fonctionnel --test 'fonctionnel_*'
