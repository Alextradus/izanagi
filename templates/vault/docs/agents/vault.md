# Vault Obsidian

Le vault `{{vault}}` est le second cerveau du projet. Il vit hors du dépôt et reste privé même si le dépôt devient public. Il garde les décisions et l'historique des jalons, et renvoie vers la spec et les issues sans les recopier : la spec et le tracker font foi.

## Structure

- `Accueil.md` : version courante, jalon en cours, liens vers le reste.
- `Jalons/` : une note par jalon, et l'index `Jalons.md`. Une note de jalon a les sections Livré, Mesures, Test manuel et Reporté.
- `Décisions/` : une note par décision marquante (contexte, décision, conséquences) et l'index `Décisions.md`. `Décisions/Journaux/` reçoit les décisions du journal de chaque jalon, un titre par décision.
- `Issues ouvertes.md` : instantané du tracker.
- `Notes/À trier.md` : notes de l'utilisateur, à relire et rattacher.

Crée une note ou un dossier absent au moment où une règle ci-dessous en a besoin.

## Au fil de l'eau

Dans toute session sur le projet, sans attendre qu'on le demande :

- en début de session, resynchronise `Issues ouvertes.md` avec le tracker : l'utilisateur crée aussi des issues sans toi ;
- issue créée ou fermée : `Issues ouvertes.md`, et la note du jalon concerné ;
- PR fusionnée : la note du jalon (contenu, mesures) ;
- décision marquante, de l'utilisateur ou notée au journal pendant une tranche : sa note dans `Décisions/` et sa ligne dans `Décisions.md` ;
- nouvelle version ou tag : `Accueil.md`, `Jalons.md` et la note du jalon ;
- retour de test manuel : la section Test manuel de la note du jalon.

## Fin de jalon

Avant de supprimer le journal du jalon :

1. Copie dans `Décisions/Journaux/Décisions <jalon>.md` ses lignes `Décision :` et ses constats écartés, chacun avec sa raison. Dans un journal d'avant la 0.3, ce sont les lignes `Ruling:`.
2. Termine la note du jalon : livré, mesures, retours du test manuel, reporté.
3. Ajoute une note par décision marquante, et sa ligne dans `Décisions.md`.
4. Régénère `Issues ouvertes.md`.
5. Relis `Notes/À trier.md` et rattache chaque note.

## Forme

- Les noms de note n'ont pas de `#` : il casse les liens Obsidian.
- Le dossier `.obsidian` appartient à l'utilisateur : laisse ses réglages tels quels.
