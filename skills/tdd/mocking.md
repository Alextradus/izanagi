# Quand simuler

Simule seulement aux **frontières du système** :

- les API externes (paiement, courriel) ;
- le temps et le hasard ;
- la base de données, parfois. Préfère une base de test ;
- le système de fichiers, parfois.

Ne simule pas :

- tes propres classes et modules ;
- un collaborateur interne ;
- ce que le projet contrôle.

## Concevoir une frontière simple à simuler

**Injecte les dépendances.** Passe une dépendance externe en paramètre au lieu de la créer à l'intérieur :

```typescript
// Simple à simuler
function processPayment(order, paymentClient) {
  return paymentClient.charge(order.total);
}

// Difficile à simuler
function processPayment(order) {
  const client = new StripeClient(process.env.STRIPE_KEY);
  return client.charge(order.total);
}
```

**Préfère une fonction par opération à un appel générique.** Écris une fonction pour chaque opération externe, pas une seule fonction qui branche selon ses arguments :

```typescript
// BON : chaque fonction se simule seule
const api = {
  getUser: (id) => fetch(`/users/${id}`),
  getOrders: (userId) => fetch(`/users/${userId}/orders`),
  createOrder: (data) => fetch("/orders", { method: "POST", body: data }),
};

// MAUVAIS : la simulation doit brancher selon l'adresse appelée
const api = {
  fetch: (endpoint, options) => fetch(endpoint, options),
};
```

Avec une fonction par opération, chaque simulation renvoie une seule forme, la mise en place du test n'a pas de branche, et le test montre quelles opérations il exerce.
