    echo "-- {{composant}} : unitaire"
    # Fait Vitest, lu le 2026-11-19 : `test.projects` déclare plusieurs projets
    # nommés dans une configuration, et `--project <nom>` n'en lance qu'un.
    # https://vitest.dev/guide/projects
    # Le script `test:unitaire` de package.json lance le projet `unitaire`.
    npm run test:unitaire
