---
name: jalon
description: Conduire un jalon du cadrage au tag, en lançant à chaque phase le skill d'Izanagi qui lui revient.
disable-model-invocation: true
argument-hint: "[cadrage|plan|tranches|revue|test|clôture|convergente]"
---

# Jalon

Tu conduis un jalon du projet courant à travers six phases, dans l'ordre (sections 2 à 7). La section 8 est une procédure que les phases appellent. Chaque phase lance ses skills et se termine sur un critère vérifiable ; passe à la suivante seulement quand il est rempli.

Les skills `izanagi:*` cités, tu les lances toi-même avec l'outil Skill. Dans un projet Izanagi, ils priment sur tout autre skill de même rôle : ne lance pas à leur place un skill d'un autre plugin. Les commandes `/…` sans préfixe, seul l'utilisateur peut les taper : propose-les-lui au moment indiqué.

Un jalon se livre par **tranches** : chacune a sa branche, sa revue, sa PR vers la branche du jalon et son test par l'utilisateur. La branche du jalon ne reçoit que des tranches relues et testées, puis part vers la branche principale en une PR.

**Réglages.** Les valeurs propres au projet sont dans `docs/agents/jalon.md` : spec, lieu des décisions, plans, branche principale, vérification, test manuel, taille d'une tranche, fichier de version, vault. Ce skill les nomme par leur libellé (« la vérification », « le test manuel »). Lis le fichier avant toute phase.

**Vault.** Si la ligne Vault de `docs/agents/jalon.md` donne un chemin, suis `docs/agents/vault.md` pendant tout le jalon. Les étapes qui citent le vault ne s'appliquent que dans ce cas.

**Skills optionnels.** Quatre skills d'un autre plugin aident à certaines étapes : `mattpocock-skills:wizard`, `mattpocock-skills:prototype`, `mattpocock-skills:research` et `mattpocock-skills:codebase-design`. Lance-les s'ils figurent dans ta liste de skills. Sinon, fais le geste de remplacement que l'étape donne, sans signaler leur absence.

**Journal.** `izanagi:task-loop` tient le journal du jalon dans `.izanagi/journal/<nom du plan>.md`. Un jalon commencé avant la 0.3 garde le sien dans `.superpowers/sdd/<nom du plan>/progress.md`. « Le journal » désigne celui des deux qui existe. Dans les deux cas, les briefs, les rapports et les diffs du jalon sont dans le dossier du plan, `.izanagi/journal/<nom du plan>/`.

## 1. Situer le jalon

Lis l'état avant d'agir :

- `docs/agents/jalon.md`. S'il manque, demande à l'utilisateur de lancer `/izanagi:init` et reprends après ;
- `git remote -v`. Sans remote, les PR sont impossibles : avant la phase tranches, fais créer le dépôt distant. Avec `mattpocock-skills:wizard`, lance-le. Sinon, propose `gh repo create <nom> --private --source . --remote origin` et lance-le sur l'accord de l'utilisateur ;
- la branche courante et `git log` de la branche principale ;
- le plan du jalon dans les plans et son journal, s'ils existent.

Déduis la phase, la première qui s'applique :

| Constat | Phase |
|---|---|
| l'argument nomme une phase | celle-là |
| l'argument est `convergente` | la revue convergente seule sur la branche courante, voir plus bas |
| la spec n'existe pas, ou ses décisions n'ont rien sur ce jalon | cadrage |
| décisions présentes, pas de plan | plan |
| plan avec une tranche non fusionnée dans la branche du jalon | tranches, à l'étape où en est la première tranche non fusionnée |
| toutes les tranches fusionnées, pas de PR vers la branche principale | revue de jalon |
| PR vers la branche principale ouverte, pas de validation de l'utilisateur | test |
| l'utilisateur a validé le jalon | clôture |

Annonce la phase et le constat en une ligne, puis enchaîne.

**Revue convergente seule.** Pour une PR hors jalon, lance `izanagi:review` avec la branche principale pour point fixe, et l'issue ou la description de la PR pour axe Spec. Sa section « Hors jalon » dit quoi faire sans `docs/agents/jalon.md`. Fin : la revue converge et la PR est ouverte ou mise à jour.

## 2. Cadrage

Si la spec n'existe pas encore, lance d'abord `izanagi:brainstorming` : il l'écrit au chemin des réglages. Puis lance `izanagi:grilling` et `izanagi:domain-modeling` ensemble : le premier mène l'entretien, le second dit quoi écrire pendant l'entretien. L'écrit se répartit ainsi :

- **Glossaire** : `CONTEXT.md` à la racine. Chaque terme tranché y entre sur le moment, sans détail d'implémentation.
- **Décisions** : au lieu des décisions des réglages, datées, et reportées dans la section de la spec concernée. Elles remplacent les ADR : le dépôt n'a pas de `docs/adr/`. Une décision marquante reçoit aussi sa note dans le vault.

Fin de phase : la frontière est vide, l'utilisateur confirme l'accord, chaque décision est dans la spec, et la spec et `CONTEXT.md` (s'il a reçu un terme) sont commités (`docs:`).

Enchaîne sur le plan dans la même fenêtre de contexte : le plan a besoin du raisonnement du cadrage tel quel, pas d'un résumé.

## 3. Plan

Lance `izanagi:planning`. Il écrit le plan dans les plans des réglages, fait valider les coutures et le découpage en tranches, et n'écrit aucun numéro de version.

Un plan écrit avant la 0.3 garde sa forme. S'il n'a pas de tranches, il forme une seule tranche, et les tests que chaque tâche nomme tiennent lieu de coutures.

Fin de phase : coutures et tranches validées, plan commité, branche du jalon `jalon/<nom court>` créée depuis la branche principale à jour et poussée.

## 4. Tranches

Traite les tranches dans l'ordre du plan. Pour chacune :

1. **Branche** : `<branche du jalon>-tN`, créée depuis la branche du jalon à jour.
2. **Tâches** : lance `izanagi:task-loop` sur les tâches de la tranche. Il rend la main après la dernière tâche, la vérification verte sur la branche de la tranche.
3. **Revue** : lance `izanagi:review`, avec la branche du jalon pour point fixe, la tranche du plan pour axe Spec, et le journal.
4. **PR de tranche** : `gh pr create --base <branche du jalon>`, corps passé par `--body-file` (`docs/agents/issue-tracker.md`). Le corps dit ce que la tranche fait, comment l'essayer (commandes et gestes) et colle la sortie de la vérification.
5. **Test ciblé** : l'utilisateur essaie la tranche avec le test manuel, depuis la branche de la tranche. Traite ses retours selon la section 8.
6. **Fusion** : avec l'accord de l'utilisateur, fusionne la PR dans la branche du jalon. Ajoute au journal la ligne `Tranche N : fusionnée, <k> tours de revue`, et ajoute la tranche à la note du jalon dans le vault.

Fin de phase : toutes les tranches fusionnées dans la branche du jalon, la vérification verte sur cette branche.

## 5. Revue de jalon

Les tranches ont déjà passé leur revue. Celle-ci cherche ce qu'elles ne voyaient pas une à une : les écarts à la spec sur l'ensemble du jalon et les défauts entre tranches.

1. Lance `izanagi:review`, avec la branche principale pour point fixe, les sections de la spec propres au jalon pour axe Spec, et le journal.
2. Monte le patch (`${CLAUDE_PLUGIN_ROOT}/references/versions.md`) et commite.
3. Lance la vérification sur la branche du jalon. Elle doit passer avant la PR.
4. Pousse la branche du jalon, puis ouvre la PR : `gh pr create --base <branche principale>`, corps passé par `--body-file`. Le corps résume le jalon tranche par tranche, dit comment l'essayer et colle la sortie de la vérification.

Fin de phase : PR vers la branche principale ouverte, revue convergée, vault à jour.

## 6. Test du jalon

L'utilisateur teste le jalon entier avec le test manuel, en priorité les interactions entre tranches. Traite ses retours selon la section 8.

Fin de phase : l'utilisateur valide le jalon explicitement.

## 7. Clôture

Une fois la validation reçue :

1. Fusion de la PR dans la branche principale, avec l'accord de l'utilisateur.
2. Version mineure et tag (`${CLAUDE_PLUGIN_ROOT}/references/versions.md`).
3. Fin de jalon du vault (`docs/agents/vault.md`), avant de supprimer le journal et le dossier du plan.
4. Relecture de `CONTEXT.md` : chaque terme introduit par le jalon y figure, défini par son sens pour l'utilisateur.
5. Suppression des branches de tranche.
6. Propose à l'utilisateur de lancer `/retro` sur la session du jalon, s'il a ce skill.

Fin de phase : tag poussé, vault clos, journal supprimé, `/retro` proposé.

## 8. Retours de test

Valable pour le test ciblé d'une tranche comme pour le test du jalon. Traite chaque retour selon sa nature :

- **Comportement cassé** : lance le sous-agent `izanagi:diagnostician`, qui rend la cause et un test de régression rouge. Confie ensuite le correctif à un sous-agent `izanagi:implementer` sur la branche testée.
- **Attente non cadrée** : une courte ronde de `izanagi:grilling`, la décision au lieu des décisions, puis le correctif par un sous-agent `izanagi:implementer`.
- **Tout retour** : la section Test manuel de la note du jalon dans le vault.

## Hors phases

- **Conflit.** Un rebase ou une fusion en conflit passe par `izanagi:merge-conflicts`.
- **Étape humaine** (jeton de registre, secret de CI, réglage d'un compte) : avec `mattpocock-skills:wizard`, lance-le. Sinon, écris à l'utilisateur les étapes numérotées, avec l'adresse de chaque écran et la commande qui contrôle le résultat, et attends qu'il confirme chacune.
- **Commandes de l'utilisateur**, à lui rappeler au bon moment s'il les a : `/wait-what` quand une de tes explications ne passe pas, `/handoff` pour emporter un travail dans un autre dossier ou outil, `/triage` pour les issues qu'il a ouvertes lui-même.
