# Règles générales : TypeScript

Règles valables pour tout projet TypeScript ou JavaScript, lues avec `docs/standards/typescript.md` du projet. Un projet écarte une règle par une ligne `Écarte : R<n>, parce que <raison>` dans son fichier.

## R1. Une donnée externe se valide avant d'être typée

Une donnée qui vient de l'extérieur (JSON, réponse réseau, stockage local, variable d'environnement) arrive en `unknown` et se valide avant d'être utilisée. Le type annoncé ne prouve rien à l'exécution.

Exemple : `const brut: unknown = await reponse.json();` puis un schéma ou une garde de type, plutôt que `const user = (await reponse.json()) as User;`.

Source : TypeScript Handbook, « Narrowing » (https://www.typescriptlang.org/docs/handbook/2/narrowing.html).

## R2. `as` ne sert pas à faire taire le compilateur

Une assertion de type `as` ne sert qu'après une vérification que le compilateur ne voit pas, jamais pour faire disparaître une erreur de type.

Exemple : `if (el instanceof HTMLInputElement) { el.value = "" }` plutôt que `(el as HTMLInputElement).value = ""`.

Source : TypeScript Handbook, « Everyday Types », Type Assertions (https://www.typescriptlang.org/docs/handbook/2/everyday-types.html#type-assertions).

## R3. Un état se modélise par une union discriminée

Un objet qui passe par plusieurs états a un champ discriminant et une forme par état, plutôt que des champs optionnels qui se combinent mal.

Exemple : `type Chargement = { etat: "attente" } | { etat: "ok"; donnees: T } | { etat: "erreur"; message: string }`.

Source : TypeScript Handbook, « Narrowing », Discriminated unions (https://www.typescriptlang.org/docs/handbook/2/narrowing.html#discriminated-unions).

## R4. Un `switch` sur une union est exhaustif

Un `switch` sur une union discriminée finit par un cas `default` qui affecte la valeur à `never`, pour qu'une variante ajoutée casse la compilation.

Exemple : `default: { const jamais: never = etat; throw new Error(jamais); }`.

Source : TypeScript Handbook, « Narrowing », Exhaustiveness checking (https://www.typescriptlang.org/docs/handbook/2/narrowing.html#exhaustiveness-checking).

## R5. Ce qu'une fonction ne modifie pas est `readonly`

Un paramètre tableau ou objet qu'une fonction ne modifie pas est déclaré `readonly`, pour que le compilateur le garantisse à l'appelant.

Exemple : `function total(lignes: readonly Ligne[]): number`.

Source : TypeScript Handbook, « Object Types », readonly Properties (https://www.typescriptlang.org/docs/handbook/2/objects.html#readonly-properties).

## R6. Chaque promesse est attendue ou son rejet traité

Une promesse est attendue avec `await`, rendue à l'appelant, ou suivie d'un `.catch`. Une promesse lancée sans suite perd son erreur.

Exemple : `void envoyer(evt).catch(journaliser);` plutôt que `envoyer(evt);` dans un gestionnaire d'événement.

Source : MDN, « Using promises », Error handling (https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Using_promises#error_handling).

## R7. Pas de `Object`, `Function` ni `{}` comme type

Une signature n'emploie ni `Object`, ni `Function`, ni `{}` : ils acceptent presque tout. Elle donne le type réel, ou `unknown`.

Exemple : `rappel: (erreur: Error | null) => void` plutôt que `rappel: Function`.

Source : TypeScript, « Do's and Don'ts », General Types (https://www.typescriptlang.org/docs/handbook/declaration-files/do-s-and-don-ts.html#general-types).

## R8. Un paramètre optionnel plutôt que des surcharges

Deux surcharges qui ne diffèrent que par un paramètre final deviennent une seule signature avec ce paramètre optionnel.

Exemple : `diff(un: string, deux: string, ignorerEspaces?: boolean)` plutôt que deux déclarations.

Source : TypeScript, « Do's and Don'ts », Use Optional Parameters (https://www.typescriptlang.org/docs/handbook/declaration-files/do-s-and-don-ts.html#use-optional-parameters).

## R9. Un rappel dont le résultat est ignoré rend `void`

Le type d'un rappel dont l'appelant ignore le résultat rend `void`, pas `any`, pour qu'on ne s'en serve pas par erreur.

Exemple : `function chaque(liste: Item[], f: (item: Item) => void): void`.

Source : TypeScript, « Do's and Don'ts », Return Types of Callbacks (https://www.typescriptlang.org/docs/handbook/declaration-files/do-s-and-don-ts.html#return-types-of-callbacks).

## R10. Un type générique se sert de son paramètre

Un paramètre de type apparaît dans au moins deux positions de la signature, ou dans le type rendu. Sinon il ne relie rien et se remplace par le type concret.

Exemple : `function premier<T>(liste: T[]): T | undefined`, et pas `function lire<T>(cle: string): T`.

Source : TypeScript, « Do's and Don'ts », Generics (https://www.typescriptlang.org/docs/handbook/declaration-files/do-s-and-don-ts.html#generics).
