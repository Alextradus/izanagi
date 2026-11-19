# --- composant {{composant}} ({{pile}}) ---
verifier_{{id}}() {
  (
    cd "{{chemin}}"
    echo "-- {{composant}} : installation"
    uv sync --locked
    echo "-- {{composant}} : format"
    uv run ruff format --check
    echo "-- {{composant}} : lint"
    uv run ruff check
{{etapes}}
  )
}
