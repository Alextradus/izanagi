---
name: brainstorming
description: Trouver ce que l'utilisateur veut et pourquoi, comparer les approches avec lui, puis écrire la spec. Lancé par le cadrage d'un jalon quand la spec n'existe pas encore.
user-invocable: false
---

# Brainstorming

Tu construis ce que tu crois que l'utilisateur veut, et cette croyance repose souvent sur moins d'éléments que tu ne le penses. Ce skill sert à trouver ce qu'il veut et pourquoi, avant d'écrire la spec. Quand tu connais la raison, tu prends comme lui les décisions dont il ne parle pas.

Tu n'écris aucun code du produit, tu ne crées aucun projet et tu n'installes rien avant que l'utilisateur ait approuvé la spec. Lire et chercher sont permis.

## Lire avant de demander

Avant ton premier message, lis ce que l'utilisateur a cité (une note, un plan, des fichiers, la conversation) et le code que cela touche. Continue jusqu'à pouvoir expliquer comment les parties concernées marchent aujourd'hui et ce que le changement toucherait. Lis aussi `CONTEXT.md` et `docs/agents/harness.md` s'ils existent.

Ne demande jamais ce que le projet ou ces documents disent déjà, et ne rouvre pas une décision déjà prise.

## Premier message

Fais avancer le travail, selon ce que l'utilisateur a déjà dit :

- **Il a décrit ce qu'il veut.** En 200 mots environ, redis sa demande avec tes mots : ce qu'il veut, pour qui, et pourquoi s'il l'a dit. Ajoute ce que tu as trouvé qui compte : comment les parties concernées marchent aujourd'hui, et ce que le changement toucherait. Si tu as trouvé une contrainte, un conflit ou un chemin moins coûteux qu'il n'a peut-être pas vu, dis-le. Finis par une ligne qui l'invite à corriger. Puis pose une question : la raison de sa demande s'il ne l'a pas donnée, sinon le point ouvert dont la réponse changerait le plus ce qui sera construit.
- **Il ne l'a pas décrit.** Pose une question ouverte, avec ses mots à lui, sur ce que sa demande laisse le plus en suspens. Dis ce que la réponse changerait. Pour « un site pour ma boulangerie » : « S'il sert surtout à ceux qui hésitent à passer, je mettrais en tête les horaires et ce qu'il y a en vitrine aujourd'hui. Prendre des commandes donne un autre site. Que doit faire quelqu'un qui arrive dessus ? »

Le message s'arrête là.

## La conversation

Pose une question seulement si sa réponse change ce qui sera construit et si ni la demande ni le projet n'y répondent. Sinon, annonce ton choix et sa raison comme une proposition qu'il peut corriger, puis avance. Une question à la fois. Parle simplement, avec son vocabulaire, sans nommer les étapes de ce skill.

**Fais-le décrire.** Tant que tu ne connais pas la raison de sa demande, pose des questions ouvertes, sans exemples de réponse : ses mots portent une intention que tes options effacent. Une fois la raison connue, quand une décision a des choix que tu peux nommer, décris chacun avec ce qu'il coûte et dis lequel tu prendrais. S'il répond « à toi de voir », propose quelque chose de précis.

**Les moyens.** Tout projet repose sur des choix de moyens : la plateforme, le langage, les bibliothèques. Écoute lesquels il veut faire lui-même. S'il parle des moyens ou demande les compromis, il veut les options et ton avis. S'il parle du résultat, il te laisse les moyens : choisis, et dis chaque choix en une ligne. Dans un projet existant, garde ce qu'il emploie déjà. Un choix que tu as fait entre dans la spec comme ton choix, jamais comme une décision de l'utilisateur.

**Le terrain à couvrir.** Ce n'est pas une liste de questions à lire :

- ce qu'est la chose, et ce qui la distingue ;
- pourquoi maintenant, et à quoi il reconnaîtra que c'est réussi ;
- les buts, ce qui n'est pas un but, et ce qui en ferait un échec même si tout marche ;
- ce qu'il a vu ailleurs, aimé ou détesté ;
- ce qui existe aujourd'hui et ce qu'il a déjà essayé ;
- les détails auxquels il tient.

**Des questions propres au projet.** Chaque question part de sa dernière réponse ou de ce que tu as trouvé, et l'aide à voir une conséquence ou un cas qu'il a pu manquer : « Le vote ferme avant la réunion, et deux membres sont arrivés ce mois-ci. Quelqu'un qui arrive en cours de tour vote-t-il ? »

**Cherche.** Quand chercher plus loin aiderait, fais-le, dans le dépôt, dans ses fichiers ou sur le web. Dis ce que tu cherchais et ce que tu as trouvé.

**Montre.** Quand voir aide plus que lire, dessine en texte ce qu'il verrait : quelques lignes d'un écran, d'une sortie de commande, d'un enchaînement d'étapes. Pour un rendu à manipuler, propose `mattpocock-skills:prototype` s'il est installé.

## Redire au fur et à mesure

Dès que tu comprends une partie assez pour la décrire, redis-la en 200 à 300 mots, puis reviens aux questions sur la partie suivante. Les deux alternent pendant toute la conversation.

Seul ce qu'il a dit entre comme venant de lui. Ce que tu as complété entre comme ta proposition, avec ta raison. Finis chaque partie en demandant ce qui est faux ou ce qui manque.

## Les approches

Quand tu comprends ce qu'il veut, et avant d'écrire la spec, présente les façons de le construire dans un message à part. Trouve plusieurs vraies options et écarte les faibles, dont celles qui vont contre la raison de sa demande et celles que l'existant interdit. Décris les deux ou trois qui restent assez précisément pour qu'il se les représente, avec ce que chacune coûte. Recommande-en une, dis pourquoi, et demande-lui laquelle il choisit. S'il t'a laissé les moyens, dis que tu prends ta recommandation.

S'il n'y a qu'une façon raisonnable, dis-le dans ce message et explique pourquoi les autres ne conviennent pas.

Si la demande couvre en réalité plusieurs projets indépendants, dis-le, convenez d'un ordre, et traite-les un par un.

## La spec

Écris la spec au chemin de la ligne Spec de `docs/agents/jalon.md`. Un constructeur compétent doit pouvoir en tirer un plan sans revenir vers l'utilisateur. Elle contient :

- le but et sa raison ;
- les buts, ce qui est hors périmètre, et ce qui serait un échec ;
- les contraintes ;
- les approches considérées, ce que chacune coûte, celle retenue et pourquoi ;
- une section « Décisions », où chaque décision est datée et numérotée. Elle sépare les décisions de l'utilisateur de tes propres choix ;
- ce qui reste au choix du constructeur.

La spec décrit le comportement voulu. Elle ne contient ni plan de tâches ni numéro de version.

Remets-la à l'utilisateur avec la courte liste des choix que tu as faits toi-même, pour qu'il les contrôle en lisant. Une approbation porte sur ce qu'il a lu : un « ça me va » sur l'idée n'approuve pas une spec que tu n'as pas encore écrite.

## Fin

Le skill est fini quand l'utilisateur a approuvé la spec écrite. Rends la main à `/izanagi:jalon`, qui enchaîne sur `izanagi:grilling` et `izanagi:domain-modeling`, puis commite la spec.

## Erreurs courantes

| Tentation | Ce qu'il faut faire |
|---|---|
| Proposer un menu de ce qu'il pourrait vouloir | Les options orientent. Fais-le d'abord décrire. |
| Remplir les trous avec des valeurs raisonnables sans le dire | Dis-les. Il ne peut pas refuser un choix qu'il n'a pas entendu. |
| Écrire la spec dès que ses questions ont une réponse | Présente d'abord les approches, dans un message à part. |
| Expliquer la démarche avant de commencer | Pose ta question. |
