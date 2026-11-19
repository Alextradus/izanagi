    echo "-- {{composant}} : unitaire"
    # Fait Vitest, lu le 2026-11-19 : `test.projects` déclare plusieurs projets
    # nommés dans une configuration, et `--project <nom>` n'en lance qu'un.
    # https://vitest.dev/guide/projects
    # Le script `test:unitaire` de package.json lance le projet `unitaire`.
    # Avec IZANAGI_COUVERTURE=1, la mesure va dans un rapport blob, que
    # `vitest run --merge-reports --coverage` fusionne à la fin. Faits Vitest,
    # lus le 2026-11-19 : `--coverage` active la mesure
    # (https://vitest.dev/guide/coverage), `--outputFile.blob` choisit le
    # fichier du rapport blob (https://vitest.dev/guide/reporters), et le blob
    # garde la couverture depuis Vitest 2 (https://github.com/vitest-dev/vitest/pull/5736).
    # Le dossier est dans node_modules, que `npm ci` vide à chaque passage.
    if [[ ${IZANAGI_COUVERTURE:-} == 1 ]]; then
      npm run test:unitaire -- --coverage --coverage.reportsDirectory=node_modules/.izanagi-couverture/unitaire --reporter=default --reporter=blob --outputFile.blob=node_modules/.izanagi-couverture/blob/unitaire.json
    else
      npm run test:unitaire
    fi
