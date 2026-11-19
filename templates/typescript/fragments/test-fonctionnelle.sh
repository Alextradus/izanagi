    echo "-- {{composant}} : fonctionnelle"
    # Le script `test:fonctionnel` de package.json lance le projet Vitest
    # `fonctionnel` ou Playwright. Sans mesure de couverture : Playwright
    # n'écrit pas de rapport Vitest.
    npm run test:fonctionnel
