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

## Anti-motifs

- **Test couplé à l'implémentation.** Il simule un collaborateur interne, teste une méthode privée ou vérifie par un canal détourné, par exemple en interrogeant la base au lieu de passer par l'interface. Le signe : le test casse pendant une refonte alors que le comportement n'a pas changé.
- **Test tautologique.** L'assertion recalcule la valeur attendue comme le code la calcule (`expect(add(a, b)).toBe(a + b)`, un instantané dérivé à la main de la même façon). Le test passe par construction et ne peut jamais contredire le code. Une valeur attendue vient d'une source indépendante : un littéral connu, un exemple calculé à la main, la spec.
- **Découpage horizontal.** Écrire tous les tests, puis tout le code. Des tests écrits en bloc vérifient un comportement imaginé, et ils figent la structure des tests avant que tu comprennes l'implémentation. Travaille par cycles : un test, son implémentation, puis le test suivant, que le cycle précédent t'aide à choisir.

## Règles de la boucle

- **Rouge avant vert.** Écris d'abord le test qui échoue, lance-le et lis l'échec : il doit échouer pour la raison attendue. Écris ensuite le code minimal qui le fait passer. N'anticipe pas les tests suivants.
- **Un cycle à la fois.** Une couture, un test, une implémentation minimale par cycle.
- **Pas de refonte dans la boucle.** La refonte appartient à la revue (`izanagi:review`), pas au cycle rouge puis vert.
- **Un test rouge ne se contourne pas.** Tu ne supprimes pas un test, tu ne le marques pas comme ignoré et tu n'affaiblis pas son assertion pour qu'il passe. Si un test casse sans cause évidente, arrête la boucle et signale-le : le diagnostic passe par `izanagi:diagnosing`.
