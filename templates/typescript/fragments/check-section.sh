# --- composant {{composant}} ({{pile}}) ---
verifier_{{id}}() {
  (
    cd "{{chemin}}"
    echo "-- {{composant}} : installation"
    npm ci
    echo "-- {{composant}} : format"
    npm run format:check
    echo "-- {{composant}} : lint"
    npm run lint
    echo "-- {{composant}} : tests"
    npm test
  )
}
