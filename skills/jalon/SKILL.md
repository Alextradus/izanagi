---
name: jalon
description: Conduire un jalon du cadrage au tag, en lançant à chaque phase les skills de Matt Pocock et de Superpowers qui lui reviennent.
disable-model-invocation: true
argument-hint: "[cadrage|plan|tranches|revue|test|clôture|convergente]"
---

# Jalon

Tu conduis un jalon du projet courant à travers six phases, dans l'ordre (sections 2 à 7). Les sections 8 et 9 sont des procédures que les phases appellent. Chaque phase lance ses skills et se termine sur un critère vérifiable ; passe à la suivante seulement quand il est rempli. Les skills `mattpocock-skills:*` et `superpowers:*` cités, tu les lances toi-même avec l'outil Skill. Les commandes `/…` sans préfixe, seul l'utilisateur peut les taper : propose-les-lui au moment indiqué.

Un jalon se livre par **tranches** : chacune a sa branche, sa revue, sa PR vers la branche du jalon et son test par l'utilisateur. La branche du jalon ne reçoit que des tranches relues et testées, puis part vers la branche principale en une PR.

**Réglages.** Les valeurs propres au projet sont dans `docs/agents/jalon.md` : spec, lieu des décisions, plans, branche principale, vérification, test manuel, taille d'une tranche, fichier de version, vault. Ce skill les nomme par leur libellé (« la vérification », « le test manuel »). Lis le fichier avant toute phase.

**Vault.** Si la ligne Vault de `docs/agents/jalon.md` donne un chemin, suis `docs/agents/vault.md` pendant tout le jalon. Les étapes qui citent le vault ne s'appliquent que dans ce cas.

## 1. Situer le jalon

Lis l'état avant d'agir :

- `docs/agents/jalon.md`. S'il manque, demande à l'utilisateur de lancer `/izanagi:init` et reprends après ;
- la branche courante et `git log` de la branche principale ;
- le plan du jalon dans les plans et son journal SDD `.superpowers/sdd/<plan>/progress.md`, s'ils existent.

Déduis la phase, la première qui s'applique :

| Constat | Phase |
|---|---|
| l'argument nomme une phase | celle-là |
| l'argument est `convergente` | la revue convergente seule (section 9) sur la branche courante, voir plus bas |
| la spec n'existe pas, ou ses décisions n'ont rien sur ce jalon | cadrage |
| décisions présentes, pas de plan | plan |
| plan avec une tranche non fusionnée dans la branche du jalon | tranches, à l'étape où en est la première tranche non fusionnée |
| toutes les tranches fusionnées, pas de PR vers la branche principale | revue de jalon |
| PR vers la branche principale ouverte, pas de validation de l'utilisateur | test |
| l'utilisateur a validé le jalon | clôture |

Annonce la phase et le constat en une ligne, puis enchaîne.

**Revue convergente seule.** Pour une PR hors jalon : point fixe la branche principale, axe Spec l'issue ou la description de la PR. Sans `docs/agents/jalon.md`, prends la branche par défaut du dépôt et la vérification que nomme `CLAUDE.md` ou `README.md`, sinon demande-la à l'utilisateur. Fin : la revue converge (section 9) et la PR est ouverte ou mise à jour.

## 2. Cadrage

Si la spec n'existe pas encore, lance d'abord `superpowers:brainstorming` : il l'écrit au chemin des réglages. Puis lance `mattpocock-skills:grilling`, suivi de `mattpocock-skills:domain-modeling` : le couple forme `grill-with-docs`. L'écrit se répartit ainsi :

- **Glossaire** : `CONTEXT.md` à la racine. Chaque terme tranché y entre sur le moment, sans détail d'implémentation.
- **Décisions** : au lieu des décisions des réglages, datées, et reportées dans la section de la spec concernée. Elles remplacent les ADR : le dépôt n'a pas de `docs/adr/`. Une décision marquante reçoit aussi sa note dans le vault.
- **Détours** : une question qui demande une réponse exécutable (un état à manipuler, un rendu à voir) passe par `mattpocock-skills:prototype`. Une question de faits (comportement d'un outil, API d'une bibliothèque) passe par `mattpocock-skills:research`. Leur résultat revient dans l'interview.

Fin de phase : la frontière est vide, l'utilisateur confirme l'accord, chaque décision est dans la spec, et la spec et `CONTEXT.md` sont commités (`docs:`).

Enchaîne sur le plan dans la même fenêtre de contexte : le plan a besoin du raisonnement du cadrage tel quel, pas d'un résumé.

## 3. Plan

Lance `superpowers:writing-plans`, avec pour dossier les plans des réglages. Ajoute à son format :

- **Coutures** : avant d'écrire les tâches, liste les coutures (les interfaces publiques où les tests observent le comportement) et fais-les valider par l'utilisateur. `tdd` n'écrit de test qu'à une couture convenue. Si la forme d'une couture est en question (profondeur du module, place de l'interface), consulte `mattpocock-skills:codebase-design`.
- **Tranches** : regroupe les tâches en tranches. Une tranche livre un comportement que l'utilisateur peut essayer avec le test manuel, et son diff reste sous la taille d'une tranche des réglages. Chaque tranche dit ce que l'utilisateur pourra essayer à la fin. Fais valider le découpage en même temps que les coutures.
- **Titres** : `## Tranche N : …` pour une tranche, `### Tâche N : …` pour une tâche, numérotée en continu sur tout le plan. Chaque tâche nomme ses coutures.
- **Versions** : le plan n'écrit aucun numéro de version (`${CLAUDE_PLUGIN_ROOT}/references/versions.md`).

Un plan écrit avant cette règle forme une seule tranche.

Fin de phase : coutures et tranches validées, plan commité, branche du jalon `jalon/<nom court>` créée depuis la branche principale à jour et poussée.

## 4. Tranches

Traite les tranches dans l'ordre du plan. Pour chacune :

1. **Branche** : `<branche du jalon>-tN`, créée depuis la branche du jalon à jour.
2. **Tâches** : lance `superpowers:subagent-driven-development` sur les tâches de la tranche, avec son journal. Ajoute :
   - **TDD** : le brief de chaque implémenteur commence par « Lance le skill `mattpocock-skills:tdd`. Les coutures de cette tâche sont convenues avec l'utilisateur : teste à ces coutures, un cycle rouge puis vert à la fois. » Pour un plan écrit avant ce skill, les tests nommés par la tâche tiennent lieu de coutures.
   - **Brief** : le script `task-brief` cherche « Task N » et les plans disent « Tâche N ». Extrais le brief à la main (awk entre `### Tâche N` et le titre suivant).
   - **Bug** : un test qui casse sans cause évidente, une régression ou une lenteur passe par `mattpocock-skills:diagnosing-bugs`, que ce soit toi ou un sous-agent dédié qui s'en charge.
   - **Conflit** : un rebase en conflit passe par `mattpocock-skills:resolving-merge-conflicts`.
3. **Revue** : la revue convergente (section 9), avec la branche du jalon pour point fixe et la tranche du plan pour axe Spec.
4. **PR de tranche** : `gh pr create --base <branche du jalon>`, corps passé par `--body-file` (`docs/agents/issue-tracker.md`). Le corps dit ce que la tranche fait, comment l'essayer (commandes et gestes) et colle la sortie de la vérification.
5. **Test ciblé** : l'utilisateur essaie la tranche avec le test manuel, depuis la branche de la tranche. Traite ses retours selon la section 8.
6. **Fusion** : avec l'accord de l'utilisateur, fusionne la PR dans la branche du jalon. Coche la tranche au journal avec son nombre de tours de revue, et ajoute-la à la note du jalon dans le vault.

Fin de phase : toutes les tranches fusionnées dans la branche du jalon, la vérification verte sur cette branche.

## 5. Revue de jalon

Les tranches ont déjà passé leur revue. Celle-ci cherche ce qu'elles ne voyaient pas une à une : les écarts à la spec sur l'ensemble du jalon et les défauts entre tranches.

1. La revue convergente (section 9), avec la branche principale pour point fixe et les sections de la spec propres au jalon pour axe Spec.
2. Monte le patch (`${CLAUDE_PLUGIN_ROOT}/references/versions.md`), puis lance `superpowers:finishing-a-development-branch` pour ouvrir la PR vers la branche principale.

Fin de phase : PR vers la branche principale ouverte, revue convergée, vault à jour.

## 6. Test du jalon

L'utilisateur teste le jalon entier avec le test manuel, en priorité les interactions entre tranches. Traite ses retours selon la section 8.

Fin de phase : l'utilisateur valide le jalon explicitement.

## 7. Clôture

Une fois la validation reçue :

1. Fusion de la PR dans la branche principale, avec l'accord de l'utilisateur.
2. Version mineure et tag (`${CLAUDE_PLUGIN_ROOT}/references/versions.md`).
3. Fin de jalon du vault (`docs/agents/vault.md`), avant de supprimer le journal SDD.
4. Relecture de `CONTEXT.md` : chaque terme introduit par le jalon y figure, défini par son sens pour l'utilisateur.
5. Suppression des branches de tranche.
6. Propose à l'utilisateur de lancer `/retro` sur la session du jalon.

Fin de phase : tag poussé, vault clos, journal SDD supprimé, `/retro` proposé.

## 8. Retours de test

Valable pour le test ciblé d'une tranche comme pour le test du jalon. Traite chaque retour selon sa nature :

- **Comportement cassé** : `mattpocock-skills:diagnosing-bugs`, puis un correctif avec test de régression sur la branche testée.
- **Attente non cadrée** : une courte ronde de `mattpocock-skills:grilling`, la décision au lieu des décisions, puis le correctif.
- **Tout retour** : la section Test manuel de la note du jalon dans le vault.

## 9. Revue convergente

Une revue qui converge en peu de tours. La phase appelante fournit le point fixe et l'axe Spec.

1. **Premier tour** : lance `mattpocock-skills:code-review` depuis le point fixe. Axe Standards : `docs/CODING_STANDARDS.md` et `CLAUDE.md`. Passe aux deux relecteurs le chemin absolu de `${CLAUDE_PLUGIN_ROOT}/references/constat.md`, qui fixe la forme et les étiquettes de leurs constats, et la liste des constats écartés notés au journal pour ce jalon, pour qu'ils ne les reprennent pas.
2. **Traite chaque constat** selon son étiquette :
   - **Important** : corrige-le. Une classe de bug se corrige sur toutes ses occurrences, cherchées dans tout le dépôt, pas seulement celles citées. Si tu penses que le constat est faux ou voulu, présente-le à l'utilisateur avec ta raison et applique sa réponse.
   - **Nit** : corrige-le s'il tient en une ligne, sinon laisse-le.
   - **Préexistant** : ouvre une issue (`docs/agents/issue-tracker.md`) et laisse le code tel quel dans cette branche.
   - **Jugement** (odeur de code, écart de périmètre) : présente-le à l'utilisateur et applique sa réponse.

   Note au journal chaque constat écarté, avec sa raison. Hors jalon, sans journal, note-les dans la description de la PR.
3. **Vérifie** : la vérification, puis commit des corrections.
4. **Tours suivants** : relance `code-review` avec pour point fixe le dernier commit relu au tour précédent, pour ne relire que les corrections. La revue a convergé quand un tour ne rend aucun Important.
5. **Plafond** : si le troisième tour rend encore un Important, arrête les tours. Présente à l'utilisateur ce qui revient et pourquoi, et propose de revoir l'approche ou le découpage plutôt qu'un quatrième tour.
6. **Source** : si une règle ou une classe de bug a déjà été signalée dans une tranche précédente (journal), propose à l'utilisateur de la traiter à la source : une règle dans `docs/CODING_STANDARDS.md`, une lint ou un test.

Fin de la revue : un tour sans Important, ou la décision de l'utilisateur au plafond ; nombre de tours noté au journal.

## Hors phases

- **Étape humaine** (jeton de registre, secret de CI, réglage d'un compte) : `mattpocock-skills:wizard`.
- **Commandes de l'utilisateur**, à lui rappeler au bon moment : `/wait-what` quand une de tes explications ne passe pas, `/handoff` pour emporter un travail dans un autre dossier ou outil, `/triage` pour les issues qu'il a ouvertes lui-même.
