# Harnais de test

Le contrat de vérification de ce projet. Le script `check-contract.sh` du plugin Izanagi, que lance `/izanagi:init`, compare ce fichier à `scripts/check.sh`, à la CI et à `scripts/dev.sh`.

- **Type** : {{type}}.
- **Systèmes cibles** : {{systemes}}.
- **Test manuel** : `{{test_manuel}}`.
- **Déploiement** : {{deploiement_ligne}}

## Composants

{{tableau_composants}}

{{lignes_composants}}

## Couches de test

`scripts/check.sh` lance les couches unitaire et intégration de chaque composant. `scripts/check.sh --complet` lance en plus les couches fonctionnelles, puis l'entrée fonctionnelle du projet.

{{tableau_couches}}

{{lignes_couches}}
