    echo "-- {{composant}} : unitaire"
    # Avec IZANAGI_COUVERTURE=1, pytest-cov ajoute la mesure de chaque couche au
    # fichier .coverage (`--cov-append`), sans rapport (`--cov-report=`) :
    # `coverage report` le résume à la fin. Faits pytest-cov, lus le 2026-11-19 :
    # https://pytest-cov.readthedocs.io/en/latest/config.html
    if [[ ${IZANAGI_COUVERTURE:-} == 1 ]]; then
      uv run --with pytest-cov==7.1.0 pytest tests/unitaires --cov --cov-append --cov-report=
    else
      uv run pytest tests/unitaires
    fi
