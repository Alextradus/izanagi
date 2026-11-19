    echo "-- {{composant}} : integration"
    # Avec IZANAGI_COUVERTURE=1 : mesure ajoutée à .coverage, comme pour la couche unitaire.
    if [[ ${IZANAGI_COUVERTURE:-} == 1 ]]; then
      uv run --with pytest-cov==7.1.0 pytest tests/integration --cov --cov-append --cov-report=
    else
      uv run pytest tests/integration
    fi
