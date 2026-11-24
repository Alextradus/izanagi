# Niveaux de risque

Une tranche, une tâche (`task`) ou un correctif (`fix`) porte un niveau de risque. Le niveau règle la profondeur de la revue et dit si l'utilisateur teste à la main.

| Niveau | Valeur écrite | Exemples | Relecteurs | Tours | Test manuel | Relecture du diff par l'utilisateur |
|---|---|---|---|---|---|---|
| faible | `faible` | documentation, renommage, configuration | Standards seul | un, sauf si ce tour rend un Important : le niveau monte alors à `normal` | non | non |
| normal | `normal` | comportement nouveau | Standards et Spec | trois au plus | oui | non |
| élevé | `eleve` | données, sécurité, migration, API publique | Standards, Spec et Sécurité, avec la passe de mutation sur le diff | trois au plus | oui | oui, après la revue |

La valeur écrite est celle des fichiers et des scripts : `state.sh set risque=eleve`, sans accent.

## Qui fixe le niveau

- **Dans un jalon**, le plan donne le niveau de chaque tranche, sur sa ligne `**Risque :**`. Une tranche sans cette ligne, dans un plan d'avant la 0.5, est de niveau normal.
- **Dans `task` et `fix`**, le flux propose un niveau au départ, d'après les exemples de la table, et l'utilisateur le confirme.
- **L'utilisateur** peut changer le niveau à tout moment. Applique sa réponse et écris-la avec `state.sh set risque=<valeur>`.
- **La revue de jalon** prend le niveau le plus haut de ses tranches et de ses correctifs, avec `normal` au minimum : elle cherche les écarts à la spec sur tout le jalon, et il lui faut le relecteur Spec.
- **Un correctif né d'un jalon** n'écrit pas son niveau dans l'état, qui est celui du jalon. Son niveau se note au journal du jalon.

Dans le doute entre deux niveaux, propose le plus haut.

## Un Important au niveau faible

Le niveau faible parie que le changement ne peut pas casser grand-chose : un seul relecteur, un seul tour, pas de test manuel. Un constat Important au tour unique montre que le pari est perdu. Le niveau retenu monte à `normal`, et la revue continue comme à ce niveau : relecteur Spec, tours suivants, test manuel. Sans cela, la correction de l'Important partirait sans relecture ni essai. `review` fait monter le niveau ; l'utilisateur peut toujours le changer ensuite.

## Chemins sensibles

La clé `chemins_sensibles` de `.izanagi/config.env` liste des motifs de chemins, séparés par des virgules (`db/migrations/*, src/auth/*`). Un diff qui touche un de ces chemins est de niveau élevé, quel que soit le niveau déclaré.

Ne décide pas toi-même qu'un chemin est sensible. Lance le script, qui lit la clé et le diff :

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/risk.sh" <point fixe> <niveau déclaré>
```

Il affiche le niveau retenu sur sa sortie standard, et une ligne `risk.sh : chemin sensible : <chemin>` par fichier sensible sur sa sortie d'erreur. Annonce à l'utilisateur le niveau retenu et, s'il a monté, les chemins qui l'ont fait monter.

Si un fichier te paraît sensible sans figurer dans la clé, dis-le à l'utilisateur et propose d'ajouter le motif à `chemins_sensibles`. Seul l'utilisateur change cette clé.
