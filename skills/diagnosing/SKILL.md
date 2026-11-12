---
name: diagnosing
description: Diagnostic d'un bug difficile ou d'une régression de performance dans un projet Izanagi, d'une boucle de reproduction qui passe au rouge jusqu'au test de régression. Chargé quand un test casse sans cause évidente, qu'un comportement est faux ou qu'une lenteur apparaît.
user-invocable: false
---

# Diagnosing

Une méthode en six phases pour un bug difficile. Tu ne sautes une phase qu'en disant pourquoi.

Avant de lire le code, lis `CONTEXT.md` s'il existe, pour te représenter les modules concernés, et les décisions de la spec qui touchent la zone.

## Masquer les secrets

Ce skill te fait montrer des commandes, des sorties et des captures. Masque d'abord chaque secret : écris `<MASQUÉ>` à sa place. Construis tes boucles avec des variables d'environnement, pour que l'identifiant reste dans l'environnement et pas dans ce que tu montres. Une capture contient des en-têtes d'authentification : ne cite que les lignes qui portent le signal.

Si la sortie masquée ne suffit pas à diagnostiquer, dis-le et demande à l'utilisateur.

## Phase 1 : construire une boucle de retour

Tout le reste en dépend. Si tu as un signal réussite ou échec qui passe au rouge sur ce bug précis, tu trouveras la cause : la bissection, les hypothèses et l'instrumentation ne font que consommer ce signal. Sans lui, lire le code ne te sauvera pas. Mets ici la plus grande part de ton effort.

Les façons d'en construire une, à essayer dans cet ordre :

1. Un test qui échoue, à la couture qui atteint le bug.
2. Un script `curl` contre un serveur de développement lancé.
3. Un appel de la CLI avec une entrée fixe, dont tu compares la sortie à une sortie connue comme bonne.
4. Un script de navigateur sans interface (Playwright) qui pilote l'écran et vérifie le DOM, la console ou le réseau.
5. Le rejeu d'une trace capturée : une vraie requête ou un vrai journal d'événements, enregistré sur disque et rejoué dans le chemin de code isolé.
6. Un montage jetable : un sous-ensemble minimal du système qui exerce le chemin du bug par un seul appel de fonction.
7. Une boucle d'entrées aléatoires, si le bug est « la sortie est parfois fausse » : lance mille entrées et cherche le mode d'échec.
8. Une bissection : si le bug est apparu entre deux états connus (commit, jeu de données, version), automatise le contrôle pour `git bisect run`.
9. Une boucle différentielle : la même entrée dans l'ancienne et la nouvelle version, ou dans deux configurations, puis la comparaison des sorties.
10. En dernier recours, l'utilisateur dans la boucle. Si un geste humain est nécessaire, écris-lui les étapes numérotées, demande-lui de les rejouer et de coller ce qu'il voit, et garde les mêmes étapes d'un essai à l'autre.

### Resserrer la boucle

Une fois la boucle obtenue, resserre-la :

- **Plus rapide** : mets la préparation en cache, saute l'initialisation sans rapport, réduis la portée du test.
- **Plus nette** : vérifie le symptôme précis, pas « ça n'a pas planté ».
- **Plus déterministe** : fige l'heure, fixe la graine du hasard, isole le système de fichiers, coupe le réseau.

Une boucle instable de trente secondes vaut à peine mieux que pas de boucle. Une boucle déterministe de deux secondes suffit.

### Bug non déterministe

Le but n'est pas une reproduction propre, mais un taux de reproduction plus haut. Répète le déclencheur cent fois, lance en parallèle, ajoute de la charge, resserre les fenêtres de temps, injecte des attentes. Un bug qui apparaît une fois sur deux se diagnostique. Un bug qui apparaît une fois sur cent ne se diagnostique pas : monte le taux.

### Quand aucune boucle n'est possible

Arrête-toi et dis-le. Liste ce que tu as essayé. Demande à l'utilisateur l'accès à l'environnement qui reproduit le bug, une capture masquée (fichier HAR, extrait de journal, enregistrement d'écran horodaté), ou la permission d'ajouter une instrumentation temporaire. Ne passe pas aux hypothèses sans boucle.

### Critère de fin

La phase 1 est finie quand tu peux nommer une seule commande, que tu as déjà lancée au moins une fois et dont tu montres l'appel et la sortie, et qui est :

- **capable de passer au rouge** : elle exerce le vrai chemin du bug et vérifie le symptôme exact de l'utilisateur, donc elle est rouge sur ce bug et verte une fois le bug corrigé ;
- **déterministe** : le même verdict à chaque lancement, ou un taux de reproduction haut et fixé pour un bug instable ;
- **rapide** : des secondes, pas des minutes ;
- **lançable sans personne**, sauf dans le cas 10.

Si tu te surprends à lire le code pour bâtir une théorie avant que cette commande existe, arrête-toi. Sauter à une hypothèse est l'erreur que ce skill empêche.

## Phase 2 : reproduire et réduire

Lance la boucle et regarde-la passer au rouge. Contrôle trois points :

- La boucle produit l'échec que l'utilisateur a décrit, pas un autre échec voisin. Un mauvais bug donne un mauvais correctif.
- L'échec se reproduit sur plusieurs lancements.
- Tu as noté le symptôme exact (message d'erreur, sortie fausse, durée), pour vérifier plus tard que le correctif le traite.

Réduis ensuite la reproduction au plus petit scénario qui reste rouge. Retire les entrées, les appelants, la configuration, les données et les étapes un par un, en relançant la boucle après chaque retrait. La réduction est finie quand retirer n'importe quel élément restant fait passer la boucle au vert.

Une reproduction réduite laisse moins de suspects à la phase 3 et devient le test de régression de la phase 5. Ne continue pas avant d'avoir reproduit et réduit.

## Phase 3 : hypothèses

Écris trois à cinq hypothèses classées avant d'en tester une. Une hypothèse unique t'ancre sur la première idée plausible.

Chaque hypothèse dit ce qu'elle prédit : « Si <X> est la cause, alors <changer Y> fait disparaître le bug, ou <changer Z> l'aggrave. » Une hypothèse sans prédiction se précise ou s'écarte.

Montre la liste classée à l'utilisateur avant de tester. Il sait souvent quelque chose qui la reclasse (« on vient de déployer un changement sur la troisième ») ou ce qu'il a déjà écarté. N'attends pas sa réponse pour avancer : suis ton classement s'il est absent.

## Phase 4 : instrumenter

Chaque sonde correspond à une prédiction de la phase 3. Change une seule variable à la fois.

Préfère, dans cet ordre :

1. un débogueur ou une console interactive, si l'environnement le permet. Un point d'arrêt vaut dix journaux ;
2. des journaux ciblés aux frontières qui départagent les hypothèses.

Ne journalise jamais tout pour chercher ensuite.

Marque chaque journal de diagnostic d'un préfixe unique, par exemple `[DEBUG-a4f2]`. Le nettoyage final se fait alors par une seule recherche.

**Performance.** Pour une régression de performance, les journaux aident rarement. Établis d'abord une mesure de référence (banc de mesure, profileur, plan de requête), puis fais une bissection. Mesure avant de corriger.

## Phase 5 : test de régression et correctif

Écris le test de régression avant le correctif, à condition qu'une couture correcte existe.

Une couture correcte est une couture où le test exerce le vrai motif du bug, tel qu'il se produit au point d'appel. Si la seule couture disponible est trop étroite, par exemple un test à un seul appelant quand le bug demande plusieurs appelants, un test de régression à cet endroit donne une fausse assurance.

Si aucune couture correcte n'existe, c'est un résultat du diagnostic. Note-le : l'architecture empêche de fixer ce bug par un test, et l'utilisateur doit le savoir.

Si une couture correcte existe :

1. Transforme la reproduction réduite en test qui échoue à cette couture (`izanagi:tdd`).
2. Constate son échec.
3. Applique le correctif.
4. Constate son succès.
5. Relance la boucle de la phase 1 sur le scénario d'origine, non réduit.

## Phase 6 : nettoyage

Avant de dire que c'est fini, contrôle que :

- la reproduction d'origine ne se reproduit plus, boucle de la phase 1 relancée ;
- le test de régression passe, ou l'absence de couture est notée ;
- toute l'instrumentation `[DEBUG-...]` est retirée, recherche du préfixe à l'appui ;
- les montages jetables sont supprimés ;
- le message de commit ou la PR dit quelle hypothèse était la bonne.
