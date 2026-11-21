---
name: fix
description: Conduire un correctif dans un projet Izanagi, du diagnostic à la PR, avec un test de régression rouge avant le correctif. À lancer seulement quand l'utilisateur le demande par /izanagi:fix, ou depuis izanagi:jalon pour un retour de test. Ne pas lancer de soi-même parce qu'un bug est mentionné.
argument-hint: "[numéro d'issue ou description du bug]"
---

# Fix

Tu conduis un correctif du projet courant : un diagnostic qui prouve la cause par un test rouge, le correctif, une revue, une PR. La branche s'appelle `fix/<nom court>`.

Les skills `izanagi:*` cités, tu les lances toi-même avec l'outil Skill. Dans un projet Izanagi, ils priment sur tout autre skill de même rôle.

**Réglages.** Lis `.izanagi/config.env` avant toute étape. Ce skill nomme les réglages par leur libellé : la branche principale (`branche`), la vérification (`verification`), le test manuel (`test_manuel`), le fichier de version (`fichier_version`).

**État.** Tu n'écris jamais `.izanagi/state.env` toi-même : tu passes par `bash "${CLAUDE_PLUGIN_ROOT}/scripts/state.sh"`, que ce skill abrège en `state.sh`.

**Niveau de risque.** `${CLAUDE_PLUGIN_ROOT}/references/risk.md` décrit les trois niveaux. Tu proposes un niveau à la section 4, normal par défaut, et l'utilisateur le confirme. La revue le monte à élevé si le diff touche un chemin sensible.

## Deux cas

Un correctif naît hors jalon ou dans un jalon. Tout le skill dépend de ce cas, que la section 1 établit.

| | Hors jalon | Dans un jalon |
|---|---|---|
| Base | la branche principale | la branche courante, celle du jalon ou d'une tranche |
| État | le sien : `flux=fix` | celui du jalon, plus la clé `correctif` |
| Journal | `.izanagi/journal/fix-<nom court>.md` | le journal du jalon |
| Niveau de risque | écrit dans l'état | noté au journal du jalon |
| Version | le patch monte | la version ne bouge pas |
| PR | vers la branche principale | vers la base |

**Corrections.** Quand l'utilisateur corrige une consigne, reprend un travail ou rappelle une règle, ajoute au journal du tableau une ligne `Correction : <ce qu'il a repris, en une phrase>`, et commite-la avec la prochaine ligne du journal. La rétrospective et la question de la clôture s'en servent.

## 1. Situer

Lis `.izanagi/config.env`. S'il manque, renvoie à `/izanagi:init`, ou à `/izanagi:upgrade` si le projet a un cadre d'avant la 0.4, et arrête-toi.

Lance `state.sh get`, la première ligne qui s'applique :

| Constat | Suite |
|---|---|
| l'état dit `flux=fix` | reprends ce correctif hors jalon, à sa phase : `diagnostic` à la section 3, `travail` à la section 4, `revue` à la section 5, `test` à la section 6, `cloture` à la section 7 |
| l'état porte une clé `correctif` | reprends ce correctif de jalon. Lis le journal du jalon et `git log <base>..HEAD` pour savoir où il en est |
| l'état dit `flux=jalon` | un correctif **dans un jalon** commence. La base est la branche courante |
| l'état dit `flux=task` | dis-le et arrête-toi : un retour de test sur un petit changement se traite dans `/izanagi:task` |
| pas d'état | un correctif **hors jalon** commence. Contrôle que l'arbre de travail est propre et que le dépôt a un dépôt distant, puis reviens sur la branche principale à jour, qui est la base |

Fin : tu annonces en une ligne le cas, la base et si tu reprends ou commences.

## 2. Branche et état

1. **Bug.** Si l'argument donne un numéro d'issue, lis-la (`gh issue view <n>`). Sinon, fais dire à l'utilisateur le geste qui montre le bug, ce qu'il attendait et ce qu'il a vu. Hors jalon, propose de créer l'issue, et crée-la sur son accord (`docs/agents/issue-tracker.md`).
2. **Nom court.** Deux à quatre mots en minuscules, séparés par des tirets (`export-date-vide`).
3. **Branche.** Crée `fix/<nom court>` depuis la base.
4. **État.**
   - Hors jalon : `state.sh start fix <nom court>`, puis `state.sh set issue=<n> --commit` si une issue existe, sinon `state.sh set phase=diagnostic --commit`. L'état commence à la phase `diagnostic`.
   - Dans un jalon : `state.sh set correctif=<nom court> --commit`. L'état reste celui du jalon : ne touche ni à sa phase ni à sa tranche.

Fin : la branche existe, avec son état commité.

## 3. Diagnostic

Lance le sous-agent `izanagi:diagnostician`, avec le geste, l'attendu, le constaté et l'issue. Il rend la cause et un test de régression rouge, commité sur la branche.

Lis son rapport :

- **Cause prouvée.** Écris au journal le geste qui montrait le bug et la cause en une phrase, puis commite-le (`chore(izanagi): journal, diagnostic`). Hors jalon, ce commit crée le journal du correctif.
- **Pas de cause.** Présente à l'utilisateur ce que le diagnostic a écarté, et demande-lui ce qui manque pour reproduire le bug.
- **Le comportement n'a jamais été cadré.** Ce n'est pas un bug. Arrête le correctif :
  1. retire l'état : `state.sh clear --commit` hors jalon, `state.sh set correctif= --commit` dans un jalon ;
  2. reviens sur la base et supprime la branche `fix/<nom court>` avec `git branch -D`, puisqu'elle n'est pas fusionnée ;
  3. hors jalon, propose `/izanagi:task`. Dans un jalon, rends la main à `izanagi:jalon`, qui mène une courte ronde de `izanagi:grilling` et écrit la décision.

Fin : la cause est prouvée par un test rouge commité.

## 4. Correctif

1. Propose le niveau de risque d'après `references/risk.md`, normal par défaut, et fais-le confirmer par l'utilisateur. Si tu reviens ici après un test qui montre encore le bug, garde le niveau déjà confirmé, sans le redemander. Hors jalon, lance `state.sh set phase=travail risque=<niveau> --commit`, à la reprise aussi, pour que l'état dise la phase en cours. Dans un jalon, n'écris rien dans l'état, qui est celui du jalon : ajoute au journal du jalon la ligne `Correctif <nom court> : niveau <niveau>` et commite-la, une seule fois par correctif.
2. Lance un sous-agent `izanagi:implementer`. Son brief : le rapport du diagnostic, le test de régression à faire passer, la consigne de ne corriger que cette cause, et le chemin absolu de `${CLAUDE_PLUGIN_ROOT}/references/langages/index.md`. Un hook du plugin relance la vérification à son arrêt.
3. Lis son rapport. Au statut « question » ou « bloqué », réponds ou demande à l'utilisateur, puis relance un implémenteur avec la réponse.

Lance ensuite la vérification complète, `<verification> --complet`, avant la revue. Garde sa sortie pour le corps de la PR.

Fin : le test de régression passe, la vérification complète est verte, le correctif est commité.

## 5. Revue

Hors jalon, lance `state.sh set phase=revue tour=0 --commit`. Dans un jalon, ne change pas la phase.

Calcule d'abord le niveau retenu avec `bash "${CLAUDE_PLUGIN_ROOT}/scripts/risk.sh" <base> <niveau déclaré>`. Un chemin sensible peut faire monter le diff à `eleve`. `review` recalcule ce niveau à son tour, ce qui ne coûte rien.

Au seul niveau `eleve`, lance ensuite `bash "${CLAUDE_PLUGIN_ROOT}/scripts/mutation.sh" <projet> <base>` et garde sa sortie, qui est le rapport de mutation. La base est la branche principale, ou la branche du jalon pour un correctif né d'un jalon. Le script ne fait jamais échouer la revue.

Lance `izanagi:review`, avec le rapport de mutation s'il existe, la base pour point fixe, le rapport du diagnostic et l'issue pour axe Spec, le journal, et le niveau de risque. Applique pour la suite le niveau que `review` annonce.

Dans un jalon, `review` n'écrit ni le tour ni le niveau dans l'état : il voit la clé `correctif` et laisse l'état du jalon tel quel. Il note le nombre de tours et le niveau retenu au journal du jalon.

Fin : la revue est finie, et au niveau élevé l'utilisateur a relu le diff.

## 6. PR et test

1. **Version.** Hors jalon, monte le patch dans le fichier de version (`${CLAUDE_PLUGIN_ROOT}/references/versions.md`) et commite. Si la version de la branche dépasse déjà celle de la branche principale, tu l'as montée lors d'un passage précédent : ne la remonte pas. Dans un jalon, ne touche pas à la version.
2. **PR.** Pousse la branche. Si la PR existe déjà (`gh pr view` réussit), mets son corps à jour avec `gh pr edit --body-file`. Sinon, ouvre-la : `gh pr create --base <base>`, corps passé par `--body-file`. Le corps suit les quatre titres de `.github/pull_request_template.md` : `## Quoi` dit le geste qui montrait le bug et le correctif, `## Pourquoi` dit la cause, `## Vérification` colle la sortie de la vérification complète, `## Risque` donne le niveau retenu. Il finit par `Closes #<n>` si une issue existe.
3. Hors jalon, lance `state.sh set phase=test --commit` et pousse.
4. **Test.** L'utilisateur refait le geste qui montrait le bug, depuis la branche. Si la revue a retenu le niveau faible, il n'y a pas de test : passe à la clôture.

Si le bug est toujours là, reprends à la section 3 avec ce que l'utilisateur a vu.

Fin : la PR est ouverte et l'utilisateur confirme que le bug a disparu.

## 7. Clôture

**Hors jalon.**

1. Lance `state.sh set phase=cloture --commit`.
2. **Leçon.** Si le tour de revue de l'état vaut 2 ou plus, ou si `bash "${CLAUDE_PLUGIN_ROOT}/scripts/refus.sh" fix/<nom court>` affiche une ligne, demande à l'utilisateur : « une leçon à garder ? », en citant ce qui a coûté. Sur un oui, lance `izanagi:retro` avec l'outil Skill pour cette seule leçon : il l'écrit et la commite sur la branche. Sinon, ne demande rien.
3. **Publication.** Demande à l'utilisateur : « publier ce correctif ? ». Sur un non, ne change rien. Le correctif n'a pas de tag, et l'étape 8 se saute, comme l'écriture du changelog qui suit. Sur un oui, écris la section du patch dans `CHANGELOG.md` : `## [X.Y.Z] - <date du jour>`, avec la version que la section 6 a montée, une ligne sous la rubrique Corrigé (`### Corrigé` en français, `### Fixed` en anglais, selon `langue_publique` dans `.izanagi/config.env`, `fr` par défaut), qui dit ce que l'utilisateur du projet ne voit plus. Si `CHANGELOG.md` n'existe pas, crée-le avec son en-tête comme le fait `izanagi:jalon`. Commite la section (`docs: changelog <version>`). `release.yml` échoue sans elle, et elle doit être sur le commit de fusion avant le tag.
4. Lance `state.sh clear`, sans `--commit`, et supprime le journal avec `git rm -f --ignore-unmatch`, qui passe même si une ligne du journal n'est pas commitée ou si le journal n'existe pas. Lance ensuite `git add -u -- .izanagi`, qui met en index la suppression de l'état. Contrôle que `git ls-files .izanagi` ne liste plus ni `state.env` ni le journal, puis fais un seul commit `chore(izanagi): fin de fix <nom court>` et pousse.
5. Relis la version de la branche principale à jour (`references/versions.md`) : si une autre PR a pris le même patch, remonte-le avant de fusionner, et reporte le numéro dans le titre de la section du changelog si tu l'as écrite.
6. Fusionne la PR dans la branche principale, avec l'accord de l'utilisateur.
7. Reviens sur la branche principale à jour, puis supprime la branche `fix/<nom court>`, en local et sur le dépôt distant.
8. Si l'utilisateur a voulu publier, pose le tag `vX.Y.Z` sur le commit de fusion, puis demande son accord avant de le pousser. Après le push, dis que `release.yml` publie la release. Si la ligne `Déploiement` de `docs/agents/harness.md` porte une commande (et non « à préciser »), propose `gh workflow run deploiement.yml -f tag=vX.Y.Z` et ne le lance que sur l'accord de l'utilisateur.

**Dans un jalon.**

1. Ajoute au journal du jalon la ligne `Correctif <nom court> : <cause en une phrase>`, et commite-la. Ne pose pas la question de la leçon : la rétrospective du jalon lira ce journal.
2. Lance `state.sh set correctif= --commit`, qui retire la clé. Contrôle avec `git diff <base> -- .izanagi/state.env` que l'état ne diffère plus de celui de la base que par sa date, puis pousse.
3. Fusionne la PR dans la base, avec l'accord de l'utilisateur.
4. Reviens sur la base à jour, puis supprime la branche `fix/<nom court>`, en local et sur le dépôt distant.
5. Rends la main à la phase de `izanagi:jalon` qui a lancé le correctif.

Fin : la PR est fusionnée, la branche du correctif supprimée, et la base ne porte ni état de correctif ni clé `correctif`.

## Hors étapes

- **Conflit.** Un rebase ou une fusion en conflit passe par `izanagi:merge-conflicts`.
- **Push refusé.** Un hook du plugin refuse un `git push` qui vise la branche principale. Ne le contourne pas.
- **Abandon.** Si l'utilisateur renonce au correctif, ne laisse ni état ni branche. Hors jalon : `state.sh clear --commit`. Dans un jalon : `state.sh set correctif= --commit`. Ferme ensuite la PR si elle existe (`gh pr close`), reviens sur la base et supprime la branche `fix/<nom court>`, en local avec `git branch -D`, puisqu'elle n'est pas fusionnée, et sur le dépôt distant. Dans un jalon, note l'abandon au journal du jalon.
- **Second bug trouvé en route.** Ne le corrige pas dans cette branche. Ouvre une issue avec l'accord de l'utilisateur, ou note-le au journal du jalon.
