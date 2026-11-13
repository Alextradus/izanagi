# Niveaux de risque

Une tranche, une tâche (`task`) ou un correctif (`fix`) porte un niveau de risque. Le niveau règle la profondeur de la revue et dit si l'utilisateur teste à la main.

| Niveau | Valeur écrite | Exemples | Relecteurs | Tours | Test manuel | Relecture du diff par l'utilisateur |
|---|---|---|---|---|---|---|
| faible | `faible` | documentation, renommage, configuration | Standards seul | un | non | non |
| normal | `normal` | comportement nouveau | Standards et Spec | trois au plus | oui | non |
| élevé | `eleve` | données, sécurité, migration, API publique | Standards et Spec | trois au plus | oui | oui, après la revue |

La valeur écrite est celle des fichiers et des scripts : `state.sh set risque=eleve`, sans accent.

## Qui fixe le niveau

- **Dans un jalon**, le plan donne le niveau de chaque tranche, sur sa ligne `**Risque :**`. Une tranche sans cette ligne, dans un plan d'avant la 0.5, est de niveau normal.
- **Dans `task` et `fix`**, le flux propose un niveau au départ, d'après les exemples de la table, et l'utilisateur le confirme.
- **L'utilisateur** peut changer le niveau à tout moment. Applique sa réponse et écris-la avec `state.sh set risque=<valeur>`.

Dans le doute entre deux niveaux, propose le plus haut.

## Chemins sensibles

La clé `chemins_sensibles` de `.izanagi/config.env` liste des motifs de chemins, séparés par des virgules (`db/migrations/*, src/auth/*`). Un diff qui touche un de ces chemins est de niveau élevé, quel que soit le niveau déclaré.

Ne décide pas toi-même qu'un chemin est sensible. Lance le script, qui lit la clé et le diff :

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/risk.sh" <point fixe> <niveau déclaré>
```

Il affiche le niveau retenu sur sa sortie standard, et une ligne `risk.sh : chemin sensible : <chemin>` par fichier sensible sur sa sortie d'erreur. Annonce à l'utilisateur le niveau retenu et, s'il a monté, les chemins qui l'ont fait monter.

Si un fichier te paraît sensible sans figurer dans la clé, dis-le à l'utilisateur et propose d'ajouter le motif à `chemins_sensibles`. Seul l'utilisateur change cette clé.
