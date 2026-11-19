    echo "-- {{composant}} : integration"
    # Le script `test:integration` de package.json lance le projet Vitest
    # `integration` (`--project`, voir https://vitest.dev/guide/projects, lu le 2026-11-19).
    npm run test:integration
