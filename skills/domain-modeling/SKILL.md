---
name: domain-modeling
description: Construire et préciser le vocabulaire du domaine d'un projet pendant un cadrage. Tient `CONTEXT.md` à jour terme par terme et reporte les décisions dans la spec.
user-invocable: false
---

# Domain modeling

Tu construis le modèle du domaine pendant que l'utilisateur et toi cadrez un travail. Ce skill sert quand le modèle change : tu contestes un terme, tu inventes un cas limite, et tu écris le glossaire et les décisions au moment où ils se fixent. Lire `CONTEXT.md` pour employer le bon vocabulaire ne demande pas ce skill.

## Fichiers

Le projet a un seul contexte et deux fichiers :

- `CONTEXT.md` à la racine est le glossaire.
- La spec, au chemin de la ligne Spec de `docs/agents/jalon.md`, reçoit les décisions.

Le projet n'a pas de `docs/adr/`. `docs/agents/domain.md` décrit cette disposition pour les autres skills.

Crée `CONTEXT.md` quand le premier terme est tranché, pas avant.

## Pendant l'entretien

**Confronte au glossaire.** Quand l'utilisateur emploie un terme dans un sens que `CONTEXT.md` contredit, dis-le tout de suite : « Le glossaire définit "annulation" comme X, et tu sembles vouloir dire Y. Lequel des deux ? »

**Précise un terme flou.** Quand un terme est vague ou porte deux sens, propose un terme canonique : « Par "compte", tu entends le Client ou l'Utilisateur ? Ce sont deux notions. »

**Éprouve par des scénarios.** Quand vous discutez des relations entre deux notions, invente des scénarios précis qui visent les cas limites et obligent à dire où passe la frontière entre elles.

**Recoupe avec le code.** Quand l'utilisateur affirme un comportement, vérifie que le code dit la même chose. En cas de contradiction, montre-la : « Le code annule une Commande entière, et tu viens de dire qu'une annulation partielle existe. Lequel a raison ? »

## Écrire le glossaire

Dès qu'un terme est tranché, écris-le dans `CONTEXT.md`. Ne garde pas les termes pour la fin.

`CONTEXT.md` a cette forme :

```md
# {Nom du contexte}

{Une ou deux phrases : ce qu'est ce contexte et pourquoi il existe.}

## Langage

**Commande** :
{Une ou deux phrases qui définissent le terme.}
_À éviter_ : achat, transaction

**Facture** :
Demande de paiement envoyée à un client après la livraison.
_À éviter_ : note, demande de paiement
```

Ses règles :

- **Choisis.** Quand plusieurs mots désignent la même notion, garde le meilleur et liste les autres sous `_À éviter_`.
- **Définis court.** Deux phrases au plus. La définition dit ce que la notion est pour l'utilisateur, pas ce qu'elle fait dans le code.
- **Seulement les termes du projet.** Une notion générale de programmation (délai d'attente, type d'erreur, utilitaire) n'entre pas, même si le projet s'en sert partout.
- **Aucun détail d'implémentation.** `CONTEXT.md` est un glossaire. Il ne sert ni de spec, ni de brouillon, ni de journal des décisions.
- **Groupe les termes** sous des sous-titres quand des familles apparaissent. Une liste plate convient tant que les termes forment un seul ensemble.

## Écrire une décision

Une décision tranchée va au lieu des décisions de `docs/agents/jalon.md`, avec sa date, puis dans la section de la spec qu'elle touche. Écris la décision elle-même et sa raison en une phrase quand elle n'est pas évidente.

Quand une décision est à la fois difficile à défaire, surprenante pour un lecteur futur et issue d'un vrai arbitrage entre plusieurs options, écris aussi les options écartées et pourquoi. Si le projet a un vault, cette décision y reçoit sa note (`docs/agents/vault.md`).
