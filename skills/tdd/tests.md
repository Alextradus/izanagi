# Bons et mauvais tests

## Bons tests

Un bon test passe par les vraies interfaces, sans simuler de partie interne.

```typescript
// BON : teste un comportement observable
test("l'utilisateur peut valider un panier valide", async () => {
  const cart = createCart();
  cart.add(product);
  const result = await checkout(cart, paymentMethod);
  expect(result.status).toBe("confirmed");
});
```

Il a ces traits :

- il teste un comportement qui compte pour l'utilisateur ou l'appelant ;
- il n'emploie que l'API publique ;
- il survit à une refonte interne ;
- son nom dit ce que le code fait, pas comment ;
- il porte une seule assertion logique.

## Mauvais tests

### Test d'un détail d'implémentation

```typescript
// MAUVAIS : teste un détail d'implémentation
test("checkout appelle paymentService.process", async () => {
  const mockPayment = jest.mock(paymentService);
  await checkout(cart, payment);
  expect(mockPayment.process).toHaveBeenCalledWith(cart.total);
});
```

Les signes :

- il simule un collaborateur interne ;
- il teste une méthode privée ;
- il vérifie un nombre ou un ordre d'appels ;
- il casse pendant une refonte sans changement de comportement ;
- son nom dit comment le code fait, pas ce qu'il fait ;
- il vérifie par un moyen extérieur à l'interface.

```typescript
// MAUVAIS : contourne l'interface pour vérifier
test("createUser écrit en base", async () => {
  await createUser({ name: "Alice" });
  const row = await db.query("SELECT * FROM users WHERE name = ?", ["Alice"]);
  expect(row).toBeDefined();
});

// BON : vérifie par l'interface
test("createUser rend l'utilisateur consultable", async () => {
  const user = await createUser({ name: "Alice" });
  const retrieved = await getUser(user.id);
  expect(retrieved.name).toBe("Alice");
});
```

### Test tautologique

La valeur attendue répète l'implémentation, donc le test passe par construction.

```typescript
// MAUVAIS : la valeur attendue est recalculée comme le code la calcule
test("calculateTotal additionne les lignes", () => {
  const items = [{ price: 10 }, { price: 5 }];
  const expected = items.reduce((sum, i) => sum + i.price, 0);
  expect(calculateTotal(items)).toBe(expected);
});

// BON : la valeur attendue est un littéral connu, indépendant du code
test("calculateTotal additionne les lignes", () => {
  expect(calculateTotal([{ price: 10 }, { price: 5 }])).toBe(15);
});
```
