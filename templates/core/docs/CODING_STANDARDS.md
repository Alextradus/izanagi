# Règles de relecture

Lues par l'agent de relecture, avec le diff. Elles portent sur les jugements qu'aucun outil ne vérifie. Ce qui se vérifie mécaniquement passe par `{{verification}}` et la CI. La forme d'un constat (preuve, étiquette Important, Nit ou Préexistant) vient de `/izanagi:jalon` : ce fichier ne contient que les règles du projet.

Ce fichier porte les règles communes à tous les langages. Une règle propre à un langage va dans `docs/standards/<langage>.md`.

## Ce qu'est un bug dans {{projet}}

Cherche d'abord ces défaillances. Ce sont elles qui coûtent cher une fois livrées.

- **Écart à la spec.** Un comportement qui contredit la spec ou le plan du jalon, même si le code est propre.

<!-- Ajoute une ligne par classe de défaillance propre au projet : perte de données, état laissé en vrac, écart entre plateformes… -->

## Tests

- **Comportement réel.** Chaque test affirme un résultat observable. Un test qui ne fait que s'exécuter sans affirmer n'en est pas un.

## Code

<!-- Les règles de conception que le projet tient : une seule source pour une règle, frontières entre modules, langue des messages… -->

## Hors revue

Ne relis pas ces chemins, même s'ils sont dans le diff : {{hors_revue}}.
