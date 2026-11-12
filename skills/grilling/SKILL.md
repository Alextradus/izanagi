---
name: grilling
description: Interroger l'utilisateur par tours sur un plan, une décision ou une idée, jusqu'à ce que chaque décision soit tranchée. À lancer au cadrage d'un jalon, ou quand l'utilisateur demande un « grill » ou veut mettre son idée à l'épreuve.
argument-hint: "[sujet]"
---

# Grilling

Tu interroges l'utilisateur jusqu'à ce que vous ayez la même compréhension du sujet. Représente le sujet comme un **arbre de décisions** : chaque décision ouvre celles qui en dépendent.

## Tours

Tu avances par tours. La **frontière** est l'ensemble des décisions dont les prérequis sont tranchés, c'est-à-dire les questions que tu peux poser maintenant sans deviner une réponse que tu n'as pas encore reçue. À chaque tour, pose toute la frontière : numérote chaque question et donne la réponse que tu recommandes. Attends ensuite les réponses avant le tour suivant.

Un tour a cette forme :

```
**Q1** - **<titre de la question>** : <corps de la question, sur plusieurs paragraphes au besoin, avec ses choix>

Recommandation : <la réponse que tu recommandes, et pourquoi>

---

**Q2** - **<titre de la question>** : <corps de la question>

Recommandation : <la réponse que tu recommandes, et pourquoi>
```

Les numéros continuent d'un tour à l'autre, pour que l'utilisateur réponde « Q7 : oui ».

Chaque réponse change l'arbre : une décision tranchée pousse la frontière et débloque les questions qui en dépendaient. Recalcule la frontière, puis pose le tour suivant. Une question dont la réponse dépend d'une autre question du même tour appartient à un tour ultérieur.

## Faits et décisions

Les faits sont ton travail, jamais celui de l'utilisateur. Quand une question de la frontière demande un fait (un fichier, le comportement d'un outil, une licence, l'API d'une bibliothèque), cherche-le toi-même et ne le demande pas à l'utilisateur. Une recherche en cours est un prérequis non tranché : seules les questions qui en dépendent attendent son résultat. Pose le reste de la frontière sans attendre.

Deux détours servent à établir un fait :

- Une question qui demande une réponse exécutable (un état à manipuler, un rendu à voir) passe par `mattpocock-skills:prototype` s'il est installé. Sinon, écris l'essai le plus court dans un dossier temporaire, lance-le et rapporte ce que tu as vu.
- Une question de faits sur un outil ou une bibliothèque passe par `mattpocock-skills:research` s'il est installé. Sinon, cherche dans le dépôt et dans la documentation officielle, et cite ta source.

Le résultat d'un détour revient dans l'entretien comme un fait acquis.

Les décisions sont à l'utilisateur. Soumets-lui chacune et attends sa réponse. Une recommandation acceptée est une décision. Une recommandation sans réponse n'en est pas une.

## Fin

L'entretien est fini quand la frontière est vide : chaque branche de l'arbre a été visitée et rien n'est supposé en silence. Rends alors la liste des décisions prises, et demande à l'utilisateur de confirmer que vous êtes d'accord. N'agis sur aucune décision avant cette confirmation.

Appelé par `/izanagi:jalon`, ce skill rend ensuite la main au flux, qui dit où écrire les décisions.
