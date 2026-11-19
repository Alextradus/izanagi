---
name: tdd
description: Règles du développement piloté par les tests dans un projet Izanagi, un cycle rouge puis vert à la fois, aux coutures convenues dans le plan. Chargé par l'implémenteur d'une tâche et par un correctif.
user-invocable: false
---

# TDD

Le TDD est la boucle rouge puis vert. Ce skill dit ce qu'est un bon test, où vont les tests, les anti-motifs et les règles de la boucle. Chaque section vaut à chaque cycle : consulte-les avant et pendant la boucle, pas après.

Avant d'écrire un test, lis `CONTEXT.md` s'il existe, pour que les noms des tests et le vocabulaire des interfaces soient ceux du domaine. Respecte les décisions de la spec qui touchent la zone de travail.

## Un bon test

Un test vérifie un comportement à travers une interface publique, jamais un détail d'implémentation. Le code peut changer en entier sans que le test change. Un bon test se lit comme une exigence : « l'utilisateur peut valider un panier valide » dit quelle capacité existe, et survit à une refonte parce qu'il ignore la structure interne.

Les exemples sont dans [tests.md](tests.md), les règles de simulation dans [mocking.md](mocking.md).

## Coutures : où vont les tests

Une **couture** est la frontière publique où tu testes : l'interface où tu observes le comportement sans regarder à l'intérieur. Un test vit à une couture, jamais contre l'intérieur d'un module.

**Teste seulement aux coutures convenues.** Le plan liste les coutures que l'utilisateur a validées, et ta tâche nomme les siennes. N'écris aucun test ailleurs. Personne ne peut tout tester : les coutures convenues dirigent l'effort vers les chemins critiques et la logique difficile.

Si ta tâche ne nomme aucune couture, les tests qu'elle cite en tiennent lieu. Si elle ne cite ni couture ni test, arrête-toi et demande.

Si le travail montre qu'une couture convenue ne permet pas d'observer le comportement demandé, ne la déplace pas de toi-même. Signale-le : le choix d'une couture revient à l'utilisateur.

## Couches

Un projet a trois couches de test. Chacune se définit par ce que le test traverse, pas par l'outil.

- **Unitaire.** Le test reste dans le processus, sans réseau, disque ni base. Il vise un module ou une fonction publique.
- **Intégration.** Le test vise le composant avec ses vraies dépendances (base de test, système de fichiers, HTTP local), appelé par son interface de code ou ses routes.
- **Fonctionnelle.** Le test vise le produit tel que l'utilisateur le touche (binaire lancé, service HTTP lancé, navigateur), sans accès à l'intérieur. C'est ce que d'autres appellent e2e.

Un test va à la couche de sa couture, dans le dossier de cette couche. Le plan donne la couche de chaque couture, et `harness.md` donne le dossier et la commande dans les lignes `- couche : <composant> | <couche> | <dossier> | <commande>`. Par défaut :

- Rust : `#[cfg(test)]` pour l'unitaire, `tests/` pour l'intégration, `tests/fonctionnel_*.rs` avec la feature `fonctionnel` pour la fonctionnelle.
- TypeScript : un projet Vitest par couche, et `tests/fonctionnels` pour la fonctionnelle (Playwright pour un front).
- Python : `tests/unitaires`, `tests/integration` et `tests/fonctionnels`.

Ne mets pas un test d'intégration dans le dossier des tests unitaires pour qu'il passe plus vite. Si la couche du plan ne convient pas à la couture, signale-le comme pour une couture : la couche revient à l'utilisateur.

## Double boucle

Quand la tâche porte le scénario d'acceptation de sa tranche (ligne `**Acceptation :**` du plan), la boucle a deux niveaux.

1. Écris le scénario en premier, à la couche fonctionnelle.
2. Lance-le avec la vérification complète, `bash scripts/check.sh --complet`, parce que la vérification ordinaire n'exécute pas la couche fonctionnelle. Il doit échouer pour la raison attendue : le comportement manque, pas une erreur de décor ou de commande.
3. Fais les cycles rouge puis vert des couches plus basses, couture par couture, comme d'habitude.
4. Relance le scénario à la fin de la tranche. Il doit passer. S'il échoue encore, une couture manque : retourne aux cycles bas, ne change pas le scénario.

Une tâche qui ne porte pas le scénario suit la boucle simple, avec `bash scripts/check.sh`.

## Propriétés

Un test de propriété énonce une règle qui vaut pour toute entrée d'un domaine, et la bibliothèque génère les entrées. Préfère-le à des exemples dans ces cas :

- un invariant (le tri garde la longueur, un total ne devient jamais négatif) ;
- un aller-retour (`decode(encode(x)) == x`) ;
- un parseur, qui reçoit des entrées que tu n'imagines pas ;
- un calcul sur un domaine large, où quelques exemples laissent des trous.

Garde les exemples pour un comportement précis dont la valeur attendue vient de la spec. Une propriété ne recalcule pas le résultat comme le code le fait : c'est le test tautologique.

La bibliothèque dépend de la pile : `proptest` en Rust, `fast-check` en TypeScript, `hypothesis` en Python. `init` ne l'installe pas. Ajoute-la au premier besoin, comme dépendance de développement, dans le commit du premier test de propriété.

## Anti-motifs

- **Test couplé à l'implémentation.** Il simule un collaborateur interne, teste une méthode privée ou vérifie par un canal détourné, par exemple en interrogeant la base au lieu de passer par l'interface. Le signe : le test casse pendant une refonte alors que le comportement n'a pas changé.
- **Test tautologique.** L'assertion recalcule la valeur attendue comme le code la calcule (`expect(add(a, b)).toBe(a + b)`, un instantané dérivé à la main de la même façon). Le test passe par construction et ne peut jamais contredire le code. Une valeur attendue vient d'une source indépendante : un littéral connu, un exemple calculé à la main, la spec.
- **Découpage horizontal.** Écrire tous les tests, puis tout le code. Des tests écrits en bloc vérifient un comportement imaginé, et ils figent la structure des tests avant que tu comprennes l'implémentation. Travaille par cycles : un test, son implémentation, puis le test suivant, que le cycle précédent t'aide à choisir.

## Règles de la boucle

- **Rouge avant vert.** Écris d'abord le test qui échoue, lance-le et lis l'échec : il doit échouer pour la raison attendue. Écris ensuite le code minimal qui le fait passer. N'anticipe pas les tests suivants.
- **Un cycle à la fois.** Une couture, un test, une implémentation minimale par cycle.
- **Pas de refonte dans la boucle.** La refonte appartient à la revue (`izanagi:review`), pas au cycle rouge puis vert.
- **Un test rouge ne se contourne pas.** Tu ne supprimes pas un test, tu ne le marques pas comme ignoré et tu n'affaiblis pas son assertion pour qu'il passe. Si un test casse sans cause évidente, arrête la boucle et signale-le : le diagnostic passe par `izanagi:diagnosing`.
