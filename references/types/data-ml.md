# Type : data-ml

Traitement de données, analyse ou apprentissage automatique.

## Couches de test

- Tests unitaires des fonctions de transformation, sur de petites données écrites dans le test (`pytest`).
- Tests de bout en bout du traitement sur un jeu d'exemple versionné : lancer le pipeline et comparer la sortie à une sortie attendue, avec une graine fixe.

## Test manuel par défaut

Lancer le traitement sur un échantillon réel (`uv run python -m <module>`), puis regarder les sorties (tableaux, graphiques) à la main.

## Sections de CODING_STANDARDS.md

- **Fuite entre entraînement et test.** Des lignes du jeu de test servent à l'entraînement ou à la mise à l'échelle.
- **Résultat non reproductible.** Deux exécutions sur les mêmes données donnent des sorties différentes, faute de graine ou de version figée.
- **Données manquantes ignorées.** Des valeurs nulles ou aberrantes passent sans contrôle et faussent les calculs.
- **Donnée sensible versionnée.** Un jeu de données privé ou un modèle lourd est commité dans le dépôt.

## Prérequis

Python et uv. Pour l'entraînement sur GPU : le pilote et la version de CUDA qu'exige la bibliothèque.
