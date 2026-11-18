---
name: task-loop
description: Exécuter les tâches d'une tranche d'un plan Izanagi, une par une, avec un implémenteur neuf par tâche, une revue après chaque tâche et un journal qui permet de reprendre. Lancé par la phase tranches d'un jalon.
user-invocable: false
---

# Task loop

Tu exécutes les tâches d'une tranche. Pour chaque tâche, tu lances un sous-agent implémenteur neuf, tu fais relire son diff, tu fais corriger, puis tu notes la tâche au journal. Tu coordonnes : tu n'écris pas le code toi-même et tu ne corriges pas un constat toi-même, pour garder ton contexte pour la coordination et pour que chaque correction passe par une revue.

Un sous-agent ne reçoit jamais l'historique de ta session. Tu lui construis ce dont il a besoin : sa tâche, les interfaces qu'elle touche et les contraintes globales.

`/izanagi:jalon` te donne le plan, le numéro de la tranche et sa branche. Lis `.izanagi/config.env` : la clé `verification` donne la vérification, la clé `spec` le chemin de la spec.

## Sans pause

Exécute toutes les tâches de la tranche sans demander à l'utilisateur s'il faut continuer. Entre deux appels d'outil, écris une ligne au plus. Le journal garde la trace.

Un conflit, une ambiguïté ou un défaut du plan ne t'arrête pas. Tranche-le : la spec fait foi, le plan en découle, et ton jugement règle ce que ni l'un ni l'autre ne dit. Note chaque décision au journal sous la forme `Décision : <ce que tu as décidé>, parce que <raison>. Si c'est faux : <ce que ça coûte>.`

Quatre cas t'arrêtent, et eux seuls. Pose alors la question à l'utilisateur :

- une opération irréversible ou destructrice ;
- une action qui touche à la sécurité ;
- un effet hors de la branche de la tranche (une fusion, un push sur une branche partagée, une publication) ;
- un plan si défaillant que chaque suite possible est une supposition.

## Journal

La mémoire de la conversation ne survit pas à une compaction. Le journal dit où tu en es, et les commits qu'il cite existent dans git même quand tu ne te souviens plus de les avoir créés. Après une compaction, crois le journal et `git log` plutôt que ton souvenir.

- Le journal est `.izanagi/journal/<nom du plan sans extension>.md`. Il est versionné sur la branche du jalon : tu le commites à la clôture de chaque tâche.
- Le **dossier du plan** est `.izanagi/journal/<nom du plan sans extension>/`. Il reçoit les briefs, les rapports et les diffs de ce plan. Git l'ignore (`.izanagi/.gitignore`).
- La première ligne du journal l'identifie : `# Journal, plan : <chemin du plan>`.
- **Reprise.** Si le journal existe et que sa première ligne nomme ton plan, une tâche qui a une ligne `Tâche N : terminée` est finie : ne la relance pas, et reprends à la première tâche sans cette ligne. Une tâche dont la dernière ligne est un tour de correction reprend au tour suivant.
- **Journal d'avant la 0.3.** `/izanagi:upgrade` l'a déplacé de `.superpowers/sdd/` vers `.izanagi/journal/`. Reprends-le même si sa première ligne n'a pas la forme ci-dessus. Ses lignes `Task N: complete` valent `Tâche N : terminée`.

## Avant la première tâche

Lis le plan une fois : son en-tête, ses coutures, ses contraintes globales, ses points de revue et les tâches de la tranche. Lis les sections de la spec que le plan cite.

Cherche ensuite les conflits dans les tâches de la tranche, et écris au journal ce que tu as contrôlé :

- une ligne par paire de tâches qui partagent un fichier ou une interface : ce que l'une produit, ce que l'autre consomme, et ce que tu constates ;
- une ligne par tâche : ses tests concordent-ils avec le code qu'elle demande, et les fichiers qu'elle crée avec ceux qu'elle touche ensuite.

Tranche chaque conflit trouvé, note la décision à côté de sa ligne, puis lance la première tâche.

## La boucle

Lance une seule tâche à la fois, parce que deux implémenteurs en parallèle modifient les mêmes fichiers.

Quand le plan aligne plusieurs tâches qui sont chacune une petite modification du même genre (la même correction d'une ligne répétée dans plusieurs fichiers), confie-les à un seul implémenteur dans un seul brief, et fais relire leur diff en une fois.

### 1. Lancer l'implémenteur

Note `BASE` (`git rev-parse HEAD`) avant de lancer : le diff de la revue en part.

Écris le brief dans `<dossier du plan>/tache-N.md`. Il contient, dans cet ordre :

1. une ligne qui situe la tâche dans la tranche ;
2. l'en-tête du plan : but, architecture, coutures, contraintes globales ;
3. le texte de la tâche, recopié tel quel, du titre `### Tâche N` au titre suivant ;
4. les sections de la spec que la tâche cite, recopiées ;
5. les interfaces et les décisions des tâches précédentes que le texte de la tâche ne peut pas connaître, et ta réponse à toute ambiguïté que tu as vue ;
6. si une tâche précédente a laissé au journal un constat dans la zone que celle-ci touche, ce constat ;
7. le chemin absolu de `${CLAUDE_PLUGIN_ROOT}/references/langages/index.md`, d'où l'implémenteur tire les règles des langages qu'il touche.

Les valeurs exactes (nombres, chaînes, signatures, cas de test) viennent du plan et de la spec, recopiées sans reformulation. Le brief ne contient pas le récit des tâches précédentes.

Lance le sous-agent `izanagi:implementer` avec deux chemins : celui du brief (« Lis ce fichier d'abord, il contient tes exigences. ») et celui où il écrit son rapport, `<dossier du plan>/tache-N.rapport.md`. Garde son identifiant, les tours de correction le relancent.

### 2. Traiter le rapport

Le statut est la première ligne du rapport, écrite `Statut : …`. Un hook du plugin a déjà relancé la vérification à l'arrêt de l'implémenteur, sauf pour un statut « bloqué » ou « question ».

- **Fait** : passe à la revue.
- **Fait avec réserves** : lis les réserves. Si elles portent sur la justesse ou le périmètre, traite-les avant la revue. Si ce sont des remarques (« ce fichier grossit »), note-les au journal et passe à la revue.
- **Question** : réponds complètement, ajoute le contexte qui manquait et relance.
- **Bloqué** : trouve ce qui doit changer avant de relancer. S'il manque du contexte, donne-le. Si la tâche est trop grosse, coupe-la. Si le plan est faux, tranche la correction, note-la au journal et porte-la dans le brief. Si un test casse sans cause évidente, lance le sous-agent `izanagi:diagnostician`, puis relance l'implémenteur avec la cause trouvée.

Ne relance jamais un implémenteur bloqué sans rien changer.

Une régression ou une lenteur que tu constates pendant la tranche, même sans rapport « bloqué », passe aussi par `izanagi:diagnostician`.

Un rebase ou une fusion en conflit pendant la tranche passe par `izanagi:merge-conflicts`.

### 3. Relire la tâche

Chaque tâche est relue, sans exception. La relecture que l'implémenteur fait de son propre diff ne la remplace pas.

Écris le diff dans un fichier : `git diff BASE..HEAD > <dossier du plan>/tache-N.diff`. Prends toujours `BASE`, jamais `HEAD~1`, qui perd tous les commits d'une tâche sauf le dernier.

Lance le sous-agent `izanagi:reviewer-spec` avec :

- le chemin du diff ;
- le chemin du brief, qui est son axe Spec ;
- le chemin du rapport de l'implémenteur, qui porte la preuve des tests ;
- le chemin absolu de `${CLAUDE_PLUGIN_ROOT}/references/finding.md`.

Le relecteur Standards ne passe pas ici. Il relit la tranche entière, dans `izanagi:review`.

Ne juge pas d'avance à la place du relecteur. N'écris jamais dans son brief qu'il doit ignorer un point ou le tenir pour mineur. Si tu penses qu'un constat sera faux, laisse-le le lever et traite-le ensuite. Ne lui demande pas de relancer les tests, puisqu'il lit leur sortie dans le rapport de l'implémenteur.

Si le relecteur dit qu'il ne peut pas vérifier une exigence depuis le diff, parce qu'elle vit dans du code inchangé ou dans une autre tâche, vérifie-la toi-même avant de clore la tâche. Si elle manque, c'est un constat Important.

### 4. Traiter les constats

Traite chaque constat selon son étiquette :

- **Important** : il entre dans les tours de correction.
- **Nit**, **Préexistant**, **Jugement** : note-le au journal, `Tâche N : mineur : <une ligne>`. La revue de la tranche le reprend.

Un constat qui contredit ce que le texte du plan exige est à toi : pèse-le contre le plan avec la spec pour arbitre, et note ta décision au journal avant d'agir.

Un tour de correction est une correction suivie d'une relecture du seul diff de la correction. Trois tours au plus par tâche :

1. Relance l'implémenteur de la tâche avec les constats ouverts, mot pour mot. Si tu ne peux plus lui écrire, lance un implémenteur neuf avec le brief et les constats.
2. Contrôle que son rapport cite les tests qui couvrent le code corrigé, la commande et sa sortie.
3. Écris le diff depuis le dernier commit relu, et relance `izanagi:reviewer-spec` sur ce diff avec la liste des constats et le rapport mis à jour. Il dit de chacun s'il est traité, et signale ce que la correction a cassé. Un Important nouveau dans ce diff rejoint les constats ouverts. Une remarque sur du code que la correction n'a pas touché va au journal comme mineur.
4. Ajoute au journal : `Tâche N : tour de correction R/3 (<x> traités, <y> ouverts : <une ligne par constat>, commits <a>..<b>)`.

**Au plafond.** Si le troisième tour laisse un Important ouvert, arrête les tours et tranche chaque constat restant :

- le relecteur a tort, ou le point se discute : laisse le code et note `Tâche N : écarté : <constat>. Décision : <pourquoi le code reste>.` ;
- le constat est juste et rien ne se construit dessus dans la tranche : note-le de la même façon, comme juste et reporté à la revue de la tranche ;
- le constat est juste et une tâche suivante en dépend, ou il révèle un défaut du plan : décide du plus petit changement qui débloque la suite, note-le et porte-le dans le brief de la tâche suivante. Si chaque suite possible est une supposition, arrête-toi et demande à l'utilisateur.

Ne tranche qu'au plafond. Chaque constat écarté a sa ligne au journal : aucun ne disparaît en silence.

### 5. Clore la tâche

Quand la relecture ne rend plus d'Important, ou que chaque Important restant est noté au plafond, ajoute au journal :

- `Tâche N : terminée (commits <base>..<tête>, revue nette)`, ou
- `Tâche N : terminée (commits <base>..<tête>, <k> constats notés)`.

Coche les étapes de la tâche dans le plan. Commite ensemble le journal et le plan (`chore(izanagi): journal, tâche N`), puis passe à la tâche suivante.

## Fin de la tranche

Après la dernière tâche de la tranche, lance la vérification sur la branche de la tranche. Si elle échoue, traite l'échec comme un rapport « bloqué » de la dernière tâche.

Rends ensuite la main à `/izanagi:jalon`, qui lance la revue de la tranche. Tu ne lances ni revue d'ensemble ni PR.

## Erreurs courantes

| Tentation | Ce qu'il faut faire |
|---|---|
| « C'est presque conforme à la tâche » | Un Important ouvert se corrige ou se tranche au plafond. Il n'y a pas d'autre sortie. |
| « Je corrige moi-même, c'est plus rapide » | Une correction faite par toi échappe à la revue. Relance l'implémenteur. |
| « Un tour de plus et ça converge » | Après trois tours, le défaut vient du plan ou de l'approche. Tranche. |
| « La correction est petite, je saute la relecture » | Chaque tour finit par une relecture du diff de la correction. |
| « Ce constat est faux, je l'écarte » | Tu n'écartes qu'au plafond, avec une ligne au journal. |
| « Tenir le journal me ralentit » | Sans journal, une compaction te fait relancer des tâches déjà finies. |
