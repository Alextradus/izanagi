---
name: planning
description: Écrire le plan d'un jalon à partir de sa spec, en tranches et en tâches, avec les coutures de test validées par l'utilisateur. Lancé par la phase plan d'un jalon.
user-invocable: false
---

# Planning

Tu écris un plan pour un implémenteur qui n'a vu ni ce dépôt ni la spec. Il écrit du code idiomatique dès qu'il connaît l'interface exacte et le test exact, et il fait un choix raisonnable partout où le plan en laisse un. Il ne peut pas deviner ce que tu as décidé : quels fichiers, quels noms et signatures, quelles valeurs de la spec, quels tests prouvent chaque tâche. Le plan écrit ces décisions.

Le plan va dans le dossier de la ligne Plans de `docs/agents/jalon.md`, sous le nom `AAAA-MM-JJ-<jalon>.md`.

## Périmètre

Si la spec couvre plusieurs sous-systèmes indépendants, propose un plan par sous-système. Chaque plan livre seul un logiciel qui marche et qui se teste.

## Fichiers

Avant les tâches, liste les fichiers à créer ou à modifier et le rôle de chacun. Le découpage se décide ici.

- Un fichier a une responsabilité et une interface nette.
- Préfère plusieurs fichiers courts à un fichier qui fait trop : tes modifications sont plus sûres sur un fichier que tu tiens en entier dans ton contexte.
- Ce qui change ensemble vit ensemble. Découpe par responsabilité, pas par couche technique.
- Dans un code existant, suis ses habitudes. Si un fichier que tu modifies est devenu trop gros, le plan peut prévoir de le couper.

## Coutures

Une couture est une interface publique où un test observe le comportement sans regarder à l'intérieur. Avant d'écrire les tâches, liste les coutures du jalon et fais-les valider par l'utilisateur. L'implémenteur n'écrit de test qu'à une couture convenue.

Si la forme d'une couture est en question (profondeur du module, place de l'interface, ce qu'elle expose), consulte `mattpocock-skills:codebase-design` s'il est installé. Sinon, présente les deux formes possibles à l'utilisateur avec ce que chacune coûte.

## Tranches

Regroupe les tâches en tranches. Une tranche livre un comportement que l'utilisateur peut essayer avec le test manuel des réglages, et son diff reste sous la taille d'une tranche des réglages. Chaque tranche dit en une phrase ce que l'utilisateur pourra essayer à la fin.

Fais valider le découpage en tranches en même temps que les coutures.

## Taille d'une tâche

Une tâche est la plus petite unité qui a son propre cycle de test et qui mérite une relecture à part. La mise en place, la configuration et la documentation entrent dans la tâche dont le livrable en a besoin. Coupe seulement là où un relecteur pourrait refuser une tâche et accepter sa voisine. Chaque tâche finit sur un livrable qui se teste seul.

## Grain d'une étape

Une étape est une action dont le résultat se contrôle :

- écrire le test qui échoue ;
- le lancer et constater l'échec ;
- écrire le code minimal qui le fait passer ;
- lancer les tests et constater qu'ils passent ;
- commiter.

## En-tête du plan

Tout plan commence ainsi :

```markdown
# <Jalon> : plan d'implémentation

> **Exécution :** `izanagi:task-loop` exécute ce plan tranche par tranche. Les étapes sont des cases à cocher (`- [ ]`).

**But :** <une phrase sur ce que le jalon construit>

**Architecture :** <deux ou trois phrases sur l'approche>

**Pile :** <technologies et bibliothèques principales>

**Spec :** <chemin de la spec, et les sections que ce jalon applique>

## Coutures

<une ligne par couture validée : l'interface, et ce que les tests y observent>

## Contraintes globales

<les exigences de la spec qui valent pour tout le jalon (versions minimales, dépendances permises, règles de nommage, systèmes cibles), une par ligne, avec les valeurs exactes recopiées de la spec. Elles s'ajoutent aux exigences de chaque tâche.>

## Points de revue

<les cinq classes d'entrées ou modes d'échec que la spec implique, qu'aucun test du plan n'exerce encore et qui ont le plus de chances de gêner un utilisateur. Une ligne chacun : l'entrée ou la condition, puis le comportement qu'on attend. Le plus probable d'abord.>

---
```

Écris les points de revue une fois, avec la spec sous les yeux. Le silence de la spec sur une entrée ne permet pas que cette entrée casse le programme. Pour chaque ligne, ajoute ensuite le test qui la couvre à la tâche qui possède le code.

## Tranches et tâches

Les titres ont cette forme, et les tâches se numérotent en continu sur tout le plan :

````markdown
## Tranche 1 : <comportement livré>

**À essayer :** <ce que l'utilisateur pourra faire à la fin de la tranche>

### Tâche 1 : <composant>

**Coutures :** <celles de l'en-tête que cette tâche teste>

**Fichiers :**
- Créer : `chemin/exact/fichier.py`
- Modifier : `chemin/exact/existant.py:123-145`
- Test : `tests/chemin/exact/test.py`

**Interfaces :**
- Consomme : <ce que la tâche prend aux tâches précédentes, signatures exactes>
- Produit : <ce dont les tâches suivantes dépendent : noms de fonctions, types des paramètres et du retour>

- [ ] **Étape 1 : écrire le test qui échoue**

```python
def test_comportement_precis():
    resultat = fonction(entree)
    assert resultat == attendu
```

- [ ] **Étape 2 : lancer le test et constater l'échec**

Commande : `pytest tests/chemin/test.py::test_comportement_precis -v`
Attendu : échec, « fonction non définie »

- [ ] **Étape 3 : écrire `fonction(entree: TypeEntree) -> TypeResultat` dans `chemin/exact/fichier.py`**

- [ ] **Étape 4 : lancer le test et constater qu'il passe**

- [ ] **Étape 5 : commiter**
````

L'implémenteur d'une tâche ne voit que sa tâche. Le bloc Interfaces est le seul endroit où il apprend les noms et les types que les tâches voisines emploient.

## Ce que contient une étape

Une étape est finie quand l'implémenteur ne peut en tirer qu'une seule chose raisonnable. Elle doit être sans ambiguïté, pas complète :

- **Une étape de test** donne le nom du test et ses assertions, en code, avec les valeurs exactes de la spec.
- **Une étape de code** donne la signature exacte, le fichier, et les valeurs que la spec fixe. L'implémenteur écrit le corps. Un corps n'apparaît que pour un algorithme que la signature et les tests ne déterminent pas, ou pour un texte que la spec fixe mot pour mot.
- **Une étape de vérification** donne la commande et la sortie qui prouve le succès.
- **Un renvoi à une autre tâche** s'appuie sur le bloc Interfaces de cette tâche. Le plan ne recopie pas son code.

Un plan plus long que le code qu'il décrit a écrit le code à la place de l'implémenteur. À l'inverse, une ligne qui ne décide rien (« à préciser », « gérer les cas limites », « ajouter la validation adéquate », un type qu'aucune tâche ne définit) est un trou.

## Versions

Le plan n'écrit aucun numéro de version. Il dit « le patch suivant celui de la branche principale au moment de la PR » (`${CLAUDE_PLUGIN_ROOT}/references/versions.md`).

## Relecture du plan

Une fois le plan écrit, relis la spec et contrôle le plan contre elle. Tu fais cette relecture toi-même, sans sous-agent.

1. **Couverture.** Pour chaque exigence de la spec, montre la tâche qui l'applique. Ajoute la tâche qui manque.
2. **Étapes.** Chaque étape permet d'écrire une seule chose raisonnable, et rien de plus. Corrige les trous et les corps de fonction superflus.
3. **Cohérence des noms.** Les types, signatures et noms employés dans les tâches tardives sont ceux que les tâches précédentes ont définis. Une fonction `vider_couches()` à la tâche 3 et `vider_toutes_couches()` à la tâche 7 est un bug.
4. **Points de revue.** Chaque ligne de la section a son test dans la tâche qui possède le code. Une section vide veut dire que tu as cherché et rien trouvé.
5. **Coutures et tranches.** Chaque tâche nomme ses coutures, toutes validées. Chaque tranche se teste à la main et tient sous la taille d'une tranche.
6. **Proportion.** Si le plan fait plusieurs fois la longueur de la spec, ou si les blocs de code en forment la plus grande part, remplace les corps par des signatures, des noms de tests et des assertions.

Corrige sur place, sans seconde relecture.

## Fin

Donne à l'utilisateur le chemin du plan et demande-lui de le lire. Le skill est fini quand il a validé les coutures, les tranches et le plan. Rends la main à `/izanagi:jalon`, qui commite le plan et crée la branche du jalon.
