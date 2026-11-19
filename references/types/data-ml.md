# Type : data-ml

Traitement de données, analyse ou apprentissage automatique.

## Couches de test

- Unitaire : les fonctions de transformation, sur de petites données écrites dans le test (`pytest`).
- Intégration : le pipeline sur un petit jeu de données figé et versionné. Le test compare la sortie à une sortie attendue, avec une graine fixe (`pytest`).
- Fonctionnelle : sans objet.

## Test manuel par défaut

Lancer le traitement sur un échantillon réel (`uv run python -m <module>`), puis regarder les sorties (tableaux, graphiques) à la main.

## Sections de CODING_STANDARDS.md

- **Fuite entre entraînement et test.** Des lignes du jeu de test servent à l'entraînement ou à la mise à l'échelle.
- **Résultat non reproductible.** Deux exécutions sur les mêmes données donnent des sorties différentes, faute de graine ou de version figée.
- **Données manquantes ignorées.** Des valeurs nulles ou aberrantes passent sans contrôle et faussent les calculs.
- **Donnée sensible versionnée.** Un jeu de données privé ou un modèle lourd est commité dans le dépôt.

## Sécurité

Classes de failles que le relecteur sécurité cherche dans le diff, au niveau de risque élevé.

- **Désérialisation non sûre.** Un modèle ou un jeu de données est chargé par `pickle`, `joblib` ou `torch.load` sans `weights_only`, depuis une source non maîtrisée.
- **Donnée personnelle exposée.** Un journal, un graphique ou un fichier de sortie contient des données personnelles du jeu d'entrée.
- **Requête construite à partir d'une entrée.** Un paramètre entre dans une requête SQL par concaténation.
- **Donnée sensible versionnée.** Un jeu de données privé ou un modèle lourd est commité dans le dépôt.
- **Secret dans un notebook.** Une clé d'API est écrite dans une cellule de notebook ou dans sa sortie enregistrée.

## Prérequis

Python et uv. Pour l'entraînement sur GPU : le pilote et la version de CUDA qu'exige la bibliothèque.
