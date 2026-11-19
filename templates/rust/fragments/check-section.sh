# --- composant {{composant}} ({{pile}}) ---
verifier_{{id}}() {
  (
    cd "{{chemin}}"
    echo "-- {{composant}} : format"
    cargo fmt --all --check
    echo "-- {{composant}} : clippy"
    cargo clippy --workspace --all-targets --locked -q -- -D warnings
{{etapes}}
  )
}
