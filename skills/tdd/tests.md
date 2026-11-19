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

## Un scénario d'acceptation

Il traverse le produit comme l'utilisateur, à la couche fonctionnelle, et ne regarde pas l'intérieur.

```typescript
// BON : passe par le navigateur, comme l'utilisateur
test("l'utilisateur valide son panier et voit la confirmation", async ({ page }) => {
  await page.goto("/");
  await page.getByRole("button", { name: "Ajouter au panier" }).click();
  await page.getByRole("button", { name: "Valider" }).click();
  await expect(page.getByText("Commande confirmée")).toBeVisible();
});
```

## Une propriété

```python
# BON : la règle vaut pour toute liste, la valeur attendue ne recalcule pas le code
@given(st.lists(st.integers()))
def test_le_tri_garde_la_longueur(valeurs):
    assert len(trier(valeurs)) == len(valeurs)
```
