    echo "-- {{composant}} : integration"
    # Le script `test:integration` de package.json lance le projet Vitest
    # `integration` (`--project`, voir https://vitest.dev/guide/projects, lu le 2026-11-19).
    # Avec IZANAGI_COUVERTURE=1, la mesure va dans un rapport blob, comme pour
    # la couche unitaire.
    if [[ ${IZANAGI_COUVERTURE:-} == 1 ]]; then
      npm run test:integration -- --coverage --coverage.reportsDirectory=node_modules/.izanagi-couverture/integration --reporter=default --reporter=blob --outputFile.blob=node_modules/.izanagi-couverture/blob/integration.json
    else
      npm run test:integration
    fi
