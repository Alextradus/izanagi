# Izanagi, harnais complet : des skills intégrés, un état et des hooks

Décisions prises le 2026-11-12 lors d'un entretien (grilling). Elles font foi pour les versions 0.3, 0.4 et 0.5.

## But

Izanagi conduit tout le travail d'un projet, pas seulement sa pose et ses jalons. Il n'a plus de prérequis de skill, il garde l'état d'un flux dans le dépôt, et des hooks Claude Code appliquent les règles que les skills ne faisaient que décrire.

En 0.2, le plugin lance quatorze skills externes sans les copier, déduit la phase d'un jalon de `git log` à chaque lancement, et n'a aucun flux pour un correctif ou un petit changement.

## Décisions

### Périmètre

1. Izanagi reste générique sur la pile et le type d'application, et propre à Claude Code. Il utilise les hooks, les sous-agents et les skills de Claude Code sans chercher d'équivalent pour un autre agent.
2. `init` pose un `AGENTS.md` en plus de `CLAUDE.md`. `AGENTS.md` donne à un autre agent la spec, la commande de vérification et les règles de relecture. Il ne décrit pas les flux d'Izanagi.

### Skills intégrés

3. Izanagi contient les skills que chaque jalon traverse. Ils sont réécrits en français, réduits à ce que le flux utilise, avec les règles de `jalon` fondues dedans : tranches, titres « Tâche N », revue convergente, étiquettes de `references/finding.md`. Le plugin ne copie aucun skill tel quel.
4. Dix skills externes sont intégrés :

   | Source | Devient dans Izanagi |
   |---|---|
   | `superpowers:brainstorming` | skill `brainstorming`, sans son compagnon visuel ni ses scripts de serveur |
   | `mattpocock-skills:grilling` | skill `grilling` |
   | `mattpocock-skills:domain-modeling` | skill `domain-modeling`, sans format d'ADR puisque les décisions vont dans la spec |
   | `superpowers:writing-plans` | skill `planning`, avec les coutures et les tranches dans son format |
   | `superpowers:subagent-driven-development` | skill `task-loop` et sous-agent implémenteur |
   | `mattpocock-skills:tdd` | skill `tdd` |
   | `mattpocock-skills:code-review` | skill `review`, qui porte la revue convergente, et deux sous-agents relecteurs |
   | `mattpocock-skills:diagnosing-bugs` | skill `diagnosing` et sous-agent diagnostiqueur |
   | `mattpocock-skills:resolving-merge-conflicts` | skill `merge-conflicts` |
   | `superpowers:finishing-a-development-branch` | fondu dans `jalon` (ouverture de la PR, nettoyage des branches) |

5. Seuls `init`, `jalon` et `grilling` apparaissent comme commandes de l'utilisateur en 0.3. Les autres skills intégrés sont internes : les flux et les sous-agents les chargent.
6. Un fichier `NOTICE` à la racine cite les deux sources, leurs auteurs et leur licence MIT (Matt Pocock, 2026 ; Jesse Vincent, 2025).
7. Cinq skills restent optionnels : `codebase-design`, `prototype`, `research`, `wizard` et `retro`. Un flux propose un skill optionnel s'il est installé et continue sans lui sinon. `init` contrôle leur présence, donne la commande d'installation de ceux qui manquent et attend l'accord de l'utilisateur avant de la lancer.
8. Le `CLAUDE.md` posé dit que, dans ce projet, les skills d'Izanagi priment sur tout autre skill de même rôle. `doctor` signale Superpowers et les skills de Matt Pocock quand ils sont actifs dans un projet Izanagi, sans rien désinstaller.

### Sous-agents

9. Le plugin définit quatre sous-agents dans `agents/` :
   - l'implémenteur suit `tdd` et rend sa tâche avec la vérification verte ;
   - le relecteur Standards relit le diff contre `docs/CODING_STANDARDS.md` et `CLAUDE.md` ;
   - le relecteur Spec relit le diff contre l'axe Spec que la phase fournit ;
   - le diagnostiqueur suit `diagnosing` et rend une cause prouvée par un test rouge.
10. Les deux relecteurs sont en lecture seule. Ils rendent leurs constats dans la forme de `references/finding.md`.

### État et réglages

11. `.izanagi/config.env` porte les réglages du projet en `clé=valeur`, une par ligne, que bash lit sans outil. Il remplace `docs/agents/jalon.md`. `docs/agents/harness.md` reste en prose.
12. `config.env` porte une clé `IZANAGI_VERSION`, la version du plugin qui a posé ou migré le cadre.
13. `.izanagi/state.env` porte l'état du flux de la branche courante : flux, nom, phase, tranche, tour de revue. Il est versionné. Seul un script du plugin l'écrit, jamais le modèle à la main.
14. Chaque branche de flux porte son `state.env`. La branche principale n'en porte aucun : le dernier commit d'un flux le supprime avant la fusion.
15. Si `state.env` et git se contredisent, git l'emporte et `doctor` signale l'écart.
16. Le journal des tâches va dans `.izanagi/journal/<flux>.md`. Pour un nouveau projet, la spec va dans `docs/specs/` et les plans dans `docs/plans/`. Ces chemins sont des clés de `config.env`.

### Hooks

17. Le plugin installe trois hooks, écrits en bash :
    - `SessionStart` injecte dans le contexte l'état lu dans `state.env` et avertit quand `IZANAGI_VERSION` est en retard sur le plugin. Il ne bloque rien.
    - `PreToolUse` refuse un `git push` direct sur la branche principale.
    - `SubagentStop` refuse qu'un implémenteur rende sa tâche quand la vérification échoue.
18. Les hooks `PreToolUse` et `SubagentStop` bloquent par défaut. Une clé de `config.env` par hook le passe en avertissement.
19. Aucun hook ne lance la vérification sur le `Stop` de la session principale.

### Flux

20. Les commandes sont `init`, `jalon`, `task`, `fix`, `upgrade`, `status` et `doctor`. `jalon` garde son nom, déjà écrit dans les projets posés.
21. `task` conduit un petit changement : issue existante ou créée, branche `task/<nom>` depuis la branche principale, cadrage en quelques questions, `tdd` aux coutures convenues, revue selon le niveau de risque, PR vers la branche principale. Il n'écrit ni spec ni plan. Si le diff prévu dépasse la taille d'une tranche ou touche plusieurs coutures, `task` s'arrête et propose `jalon`.
22. `fix` conduit un correctif : diagnostic, test de régression rouge, correctif, revue selon le niveau de risque, PR. La branche `fix/<nom>` part de la branche principale, ou de la branche du jalon quand le bug vient du jalon en cours. Les retours de test d'un jalon passent par `fix`.
23. `upgrade` compare `IZANAGI_VERSION` à la version du plugin et applique les migrations une à une, chacune dans son commit, sur une branche `task/izanagi-upgrade` avec une PR. Il montre chaque écart au gabarit et n'écrase un fichier modifié qu'avec l'accord de l'utilisateur. Il laisse la spec et les plans d'un projet existant à leur place et ne déplace que le journal. Le cas « projet 0.1 » quitte `init`, qui ne garde que la pose initiale.
24. `status` liste les flux ouverts en lisant le `state.env` des branches `jalon/*`, `task/*` et `fix/*`.
25. `doctor` contrôle le poste (outils de la pile, Git Bash, `gh` connecté, WSL si `linux` est une cible, hook `pre-push` de git activé, réglage des clés `hook_push` et `hook_verification`) et le projet (contrat de vérification, écarts au gabarit, cohérence de `state.env` avec git, doublons de skills de la décision 8). Il ne sait pas si Claude Code a chargé les hooks du plugin : le skill renvoie à `/hooks` pour le voir.

### Niveaux de risque

26. Une tranche, une tâche ou un correctif porte un niveau de risque. Le plan fixe celui de chaque tranche. `task` et `fix` le proposent au départ. L'utilisateur peut le changer à tout moment.

    | Niveau | Exemple | Revue | Test manuel |
    |---|---|---|---|
    | faible | documentation, renommage, configuration | un relecteur, un tour | non |
    | normal | comportement nouveau | deux relecteurs, trois tours au plus | oui |
    | élevé | données, sécurité, migration, API publique | deux relecteurs, trois tours au plus, puis relecture du diff par l'utilisateur | oui |

27. `config.env` peut déclarer des chemins sensibles. Un diff qui touche un chemin sensible prend le niveau élevé.

### Livraison

28. Le chantier sort en trois versions, chacune utilisable seule :
    - la 0.3 contient les skills intégrés, les quatre sous-agents et le `NOTICE`, et retire les prérequis de skill. `jalon` garde son comportement.
    - la 0.4 contient `config.env`, `state.env`, les trois hooks, `status`, `doctor`, `upgrade` et `AGENTS.md`.
    - la 0.5 contient les niveaux de risque, `task` et `fix`.
29. La 1.0 sort après un projet mené de bout en bout sur la 0.5.
30. Chaque version a son plan dans `docs/plans/`. Izanagi garde son mode de travail : pas de jalon, une PR par version, relue par la revue convergente, validée à la main dans un bac à sable.

### Décisions ajoutées le 2026-11-12, après la 0.3

Ces décisions précisent ou corrigent des décisions précédentes, qui restent écrites telles qu'elles ont été prises.

31. La décision 7 annonçait cinq skills optionnels contrôlés par `init`. `init` en contrôle quatre : `codebase-design`, `prototype`, `research` et `wizard`, tous du plugin `mattpocock-skills`. `/retro` est un skill personnel de l'utilisateur, sans commande d'installation. `jalon` le propose à la clôture si l'utilisateur l'a.
32. Le journal d'un flux est versionné, comme `state.env` (précise la décision 16). Il vit sur la branche du flux, et le dernier commit du flux le supprime avec `state.env`, après la fin de jalon du vault. Le dossier du plan (`.izanagi/journal/<plan>/`), qui reçoit les briefs, les rapports et les diffs, reste hors de git.
33. À la clôture d'un jalon, `jalon` supprime la branche du jalon en plus des branches de tranche, en local et sur le dépôt distant, une fois la PR fusionnée et le tag poussé (précise la décision 4).
34. Les clés de `config.env` et de `state.env` sont en minuscules, comme celles du fichier de valeurs d'`install.sh` (`branche`, `verification`). La clé de version s'écrit `izanagi_version` (corrige la décision 12). `config.env` reprend les clés que `docs/agents/jalon.md` portait, plus `izanagi_version` et une clé par hook.
35. Le hook `SubagentStop` laisse passer un implémenteur qui rend le statut « bloqué » ou « question », parce qu'il n'a pas de vérification verte à montrer. Il cesse de bloquer après deux refus pour le même sous-agent et avertit l'utilisateur à la place (précise la décision 17).
36. La clôture d'un jalon ne pousse plus de commit sur la branche principale, que le hook `PreToolUse` refuse. La version mineure monte sur la branche du jalon avant la fusion, et le tag est posé sur le commit de fusion.
37. Pour la même raison, le cadrage et le plan d'un jalon s'écrivent sur une branche `jalon/<nom court>-cadrage`, fusionnée dans la branche principale par une PR avant la création de la branche du jalon. Les tranches d'un jalon ne touchent pas à la version : seule la clôture la monte.

## Hors périmètre

- La release et le déploiement d'un projet. La release reste dans la clôture de `jalon`.
- Les évals du harnais, c'est-à-dire des scénarios rejoués sur un projet témoin. Les deux sujets sont prévus pour une V2.
- Le template de PR, qui reste sur la feuille de route.

## Coûts

- Izanagi ne reçoit plus les améliorations des skills sources. Une correction d'amont se reporte à la main.
- Le plugin passe de deux skills à onze, tous à maintenir et à relire.
- `state.env` versionné ajoute un commit à chaque changement de phase.
- Un projet posé en 0.2 doit passer par `upgrade` en 0.4 : sans lui, il garde `docs/agents/jalon.md`, que les flux ne lisent plus.
