---
name: task
description: Conduire un petit changement dans un projet Izanagi, de l'issue à la PR, sans spec ni plan. Cadrage en quelques questions, implémentation testée, revue selon le niveau de risque.
disable-model-invocation: true
argument-hint: "[numéro d'issue ou description du changement]"
---

# Task

Tu conduis un petit changement du projet courant : une issue, une branche `task/<nom court>`, une PR vers la branche principale. Un petit changement tient dans une tranche et se teste à une seule couture. Tu n'écris ni spec ni plan. Ce qui dépasse cette taille est un jalon.

Les skills `izanagi:*` cités, tu les lances toi-même avec l'outil Skill. Dans un projet Izanagi, ils priment sur tout autre skill de même rôle.

**Réglages.** Lis `.izanagi/config.env` avant toute étape. Ce skill nomme les réglages par leur libellé : la branche principale (`branche`), la vérification (`verification`), le test manuel et son lieu (`test_manuel`, `lieu_test`), la taille d'une tranche (`taille_tranche`), le fichier de version (`fichier_version`).

**État.** L'état du changement est dans `.izanagi/state.env`, versionné sur la branche `task/<nom court>`. Tu ne l'écris jamais toi-même : tu passes par `bash "${CLAUDE_PLUGIN_ROOT}/scripts/state.sh"`, que ce skill abrège en `state.sh`. Avec `--commit`, le script commite ce seul fichier.

**Journal.** Le cadrage, les constats écartés et les retours de test vont dans `.izanagi/journal/task-<nom court>.md`, versionné sur la branche. La clôture le supprime avec l'état.

**Niveau de risque.** `${CLAUDE_PLUGIN_ROOT}/references/risk.md` décrit les trois niveaux. Le niveau règle la revue et le test manuel.

## 1. Situer

Lis `.izanagi/config.env`. S'il manque, renvoie à `/izanagi:init`, ou à `/izanagi:upgrade` si le projet a un cadre d'avant la 0.4, et arrête-toi.

Lance `state.sh get` :

- **La branche courante porte un flux `task`.** Reprends à la phase que l'état donne : `debut` à la section 3, `travail` à la section 4, `revue` à la section 5, `test` à la section 6, `cloture` à la section 7.
- **Elle porte un autre flux.** Dis lequel et arrête-toi : un changement ne se commence pas sur la branche d'un jalon ou d'un correctif.
- **Pas d'état.** Contrôle que l'arbre de travail est propre (`git status --porcelain`) et que le dépôt a un dépôt distant, puis reviens sur la branche principale à jour.

Fin : tu sais si tu reprends un changement ou si tu en commences un, et tu l'annonces en une ligne.

## 2. Issue et branche

1. **Issue.** Si l'argument donne un numéro, lis l'issue (`gh issue view <n>`). Sinon, propose le titre et le corps d'une issue d'après la description, et crée-la sur l'accord de l'utilisateur (`docs/agents/issue-tracker.md`).
2. **Nom court.** Deux à quatre mots en minuscules, séparés par des tirets, tirés du titre de l'issue (`export-csv-dates`).
3. **Branche.** Crée `task/<nom court>` depuis la branche principale à jour.
4. **État.** Lance `state.sh start task <nom court>`, puis `state.sh set issue=<n> --commit`.

Fin : la branche existe, avec son état commité.

## 3. Cadrage

Lance `izanagi:grilling` sur le changement, pour cinq questions au plus. Tu cherches quatre réponses :

- **ce que le changement fait**, en une ou deux phrases que l'utilisateur confirme ;
- **la couture** : l'interface par laquelle un test le prouve ;
- **le critère de fin** : ce que l'utilisateur pourra faire ou voir une fois le changement fusionné ;
- **le niveau de risque**, que tu proposes d'après `references/risk.md` et que l'utilisateur confirme.

**Garde-fou.** Arrête le cadrage si le changement prévu dépasse la taille d'une tranche ou s'il touche plusieurs coutures. Dis pourquoi, puis :

1. lance `state.sh clear --commit` ;
2. reviens sur la branche principale et supprime la branche `task/<nom court>` avec `git branch -D`, puisqu'elle n'est pas fusionnée ;
3. propose `/izanagi:jalon`, et laisse l'issue ouverte.

Sinon, écris les quatre réponses dans `.izanagi/journal/task-<nom court>.md`, sous le titre de l'issue, et commite (`chore(izanagi): journal, cadrage`).

Fin : l'utilisateur a confirmé les quatre réponses, et le journal les porte.

## 4. Travail

1. Lance `state.sh set phase=travail risque=<niveau> --commit`. Si tu reviens ici après un retour de test, garde le niveau que l'état porte déjà (`state.sh get risque`) : la revue a pu le monter.
2. Écris le brief de l'implémenteur : le titre et le numéro de l'issue, les quatre réponses du cadrage, la couture, et la consigne de ne rien faire d'autre.
3. Lance un sous-agent `izanagi:implementer` avec ce brief. Un hook du plugin relance la vérification à son arrêt et le renvoie au travail si elle échoue.
4. Lis son rapport. Au statut « question » ou « bloqué », réponds ou demande à l'utilisateur, puis relance un implémenteur avec la réponse. Au statut « fait avec réserves », note les réserves au journal et commite-le.

**Sans code.** Un changement de niveau faible qui ne touche que de la documentation ou de la configuration se fait sans sous-agent : fais-le toi-même, lance la vérification, commite.

Fin : le changement est commité sur la branche, la vérification verte.

## 5. Revue

1. Lance `state.sh set phase=revue tour=0 --commit`.
2. Lance `izanagi:review`, avec la branche principale pour point fixe, l'issue et le cadrage du journal pour axe Spec, le journal, et le niveau de risque.

`review` calcule le niveau retenu : il monte à élevé si le diff touche un chemin sensible du projet. Applique le niveau qu'il annonce pour la suite.

Fin : la revue est finie, et au niveau élevé l'utilisateur a relu le diff.

## 6. PR et test

1. **Version.** Monte le patch dans le fichier de version (`${CLAUDE_PLUGIN_ROOT}/references/versions.md`) : lis la version sur la branche principale à jour juste avant, et commite (`chore: <version>`). Si la version de la branche dépasse déjà celle de la branche principale, tu l'as montée lors d'un passage précédent : ne la remonte pas.
2. **PR.** Pousse la branche. Si la PR n'existe pas (`gh pr view` échoue), ouvre-la : `gh pr create --base <branche principale>`, corps passé par `--body-file`. Le corps dit ce que le changement fait, comment l'essayer, colle la sortie de la vérification, et finit par `Closes #<n>`. Si elle existe, mets son corps à jour avec `gh pr edit --body-file`.
3. Lance `state.sh set phase=test --commit` et pousse.
4. **Test manuel.** L'utilisateur essaie le changement avec le test manuel, depuis la branche. Si la revue a retenu le niveau faible (`state.sh get risque`), il n'y a pas de test manuel : passe à la clôture.

Traite un retour de test selon sa nature :

- **Comportement cassé** : un sous-agent `izanagi:implementer` écrit un test de régression rouge, puis le correctif, sur la même branche. Si la cause n'est pas évidente, lance d'abord le sous-agent `izanagi:diagnostician`. Refais ensuite la revue de la section 5 sur le seul diff ajouté, puis pousse.
- **Attente nouvelle** : si elle tient dans le changement, reprends à la section 4, puis refais la revue de la section 5 sur le seul diff ajouté. Sinon, propose une autre issue.

Note chaque retour au journal et commite-le.

Fin : la PR est ouverte et l'utilisateur valide le changement.

## 7. Clôture

1. Lance `state.sh set phase=cloture --commit`.
2. Lance `state.sh clear`, sans `--commit`, et supprime le journal avec `git rm -f`, qui passe même si une ligne du journal n'est pas commitée. Lance ensuite `git add -u -- .izanagi`, qui met en index la suppression de l'état. Contrôle que `git ls-files .izanagi` ne liste plus ni `state.env` ni le journal, puis fais un seul commit `chore(izanagi): fin de task <nom court>` et pousse.
3. Relis la version de la branche principale à jour (`references/versions.md`) : si une autre PR a pris le même patch, remonte-le avant de fusionner.
4. Fusionne la PR dans la branche principale, avec l'accord de l'utilisateur.
5. Reviens sur la branche principale à jour, puis supprime la branche `task/<nom court>`, en local et sur le dépôt distant.

Fin : la PR est fusionnée, l'issue fermée, la branche principale sans état ni journal, la branche du changement supprimée.

## Hors étapes

- **Conflit.** Un rebase ou une fusion en conflit passe par `izanagi:merge-conflicts`.
- **Push refusé.** Un hook du plugin refuse un `git push` qui vise la branche principale. Ne le contourne pas.
- **Abandon.** Si l'utilisateur renonce au changement, ne laisse ni état ni branche : lance `state.sh clear --commit`, ferme la PR si elle existe (`gh pr close`), reviens sur la branche principale et supprime la branche `task/<nom court>`, en local avec `git branch -D`, puisqu'elle n'est pas fusionnée, et sur le dépôt distant. Laisse l'issue ouverte, sauf s'il demande de la fermer.
- **Bug trouvé en route**, sans lien avec le changement : ne le corrige pas ici. Propose `/izanagi:fix` après la clôture, ou ouvre une issue avec l'accord de l'utilisateur.
