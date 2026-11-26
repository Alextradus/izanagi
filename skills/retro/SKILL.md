---
name: retro
description: Conduire la rétrospective d'un flux Izanagi (jalon, task, fix) et transformer ce qu'il a coûté en règles du projet, ou en brouillons d'issue pour le plugin. À lancer quand l'utilisateur le demande par /izanagi:retro, depuis la clôture de izanagi:jalon, ou depuis la question de clôture de izanagi:task et izanagi:fix.
argument-hint: "[branche du flux]"
---

# Retro

Tu tires les leçons d'un flux : ce qui a coûté des tours de revue, des refus de hook, des corrections de l'utilisateur ou du bruit dans l'historique git. Chaque leçon devient une ligne dans un fichier du projet, ou un brouillon d'issue pour le plugin. L'utilisateur décide de chaque ligne.

Tu ne modifies jamais le plugin, `hooks.json`, ni les clés `hook_*` de `.izanagi/config.env`. Tu proposes, l'utilisateur décide.

## 1. Situer le flux

La branche est l'argument, ou la branche courante. Lis `.izanagi/state.env` avec `bash "${CLAUDE_PLUGIN_ROOT}/scripts/state.sh" get` pour connaître le flux et son nom. Le journal est :

| Flux | Journal | Rapports de revue |
|---|---|---|
| `jalon` | `.izanagi/journal/<nom du plan>.md` | `.izanagi/journal/<nom du plan>/` |
| `task` | `.izanagi/journal/task-<nom>.md` | aucun dossier |
| `fix` hors jalon | `.izanagi/journal/fix-<nom>.md` | aucun dossier |

Sans journal, par exemple après la clôture d'un `task` ou d'un `fix`, qui le supprime, travaille sur les refus et l'historique de la branche (section 2). Sans journal, ni refus, ni commit propre à la branche, dis-le et arrête-toi : la rétrospective n'a rien à lire.

Lancé depuis la question de clôture de `task` ou `fix` avec une seule leçon, va droit à la section 3 avec elle.

## 2. Lire la matière

Lis, et rien d'autre :

- le journal du flux : lignes de tâches, tours de revue, `Décision :`, constats écartés, retours de test ;
- les lignes `Correction : ` du journal, chacune une reprise de l'utilisateur ;
- les rapports de revue du dossier du plan, quand il existe ;
- les refus des hooks pour cette branche : `bash "${CLAUDE_PLUGIN_ROOT}/scripts/refus.sh" <branche>`. Chaque ligne a la forme `<date>|<branche>|<hook>|<motif>` ;
- l'historique git de la branche : `bash "${CLAUDE_PLUGIN_ROOT}/scripts/historique.sh" <branche>`, qui compte ses commits par type, avec à part les commits de suivi `chore(izanagi)` (journal et état). Pour un correctif né d'un jalon, passe la branche du jalon en second argument. Lis ensuite les titres eux-mêmes (`git log --no-merges --format=%s <branche principale>..<branche>`) : une suite de `fix` sur le même fichier après une revue, un `revert`, un commit qui défait le précédent.

Le journal ne dit que ce que le flux y a écrit. L'historique montre ce qu'il n'y écrit pas : le bruit des commits de suivi, les reprises, les allers-retours.

Ne lis pas les transcripts de Claude Code : ils sont hors du dépôt, et la clôture tourne souvent dans une autre session que les tranches.

## 3. Proposer les leçons

Une leçon est un constat qui revient, ou un coût que l'utilisateur a nommé :

- la même classe de bug relevée dans deux tranches, ou deux tours de revue sur le même point ;
- un refus de hook répété, ou une vérification rouge qui revient sur la même cause ;
- une ligne `Correction : ` ;
- un historique dont plus d'un quart des commits sont des `chore(izanagi)`, ou qui porte des reprises en série (section 2). Les commits de suivi tiennent au harnais : la leçon est une leçon **harnais**, avec la part et le décompte en preuve.

Un incident isolé, déjà corrigé, sans règle à en tirer, n'est pas une leçon : ne le propose pas.

Pour chaque leçon, donne à l'utilisateur, en une ligne chacun :

1. le constat et sa preuve, tirée du journal ou de `refus.log` ;
2. son classement : **projet**, si la leçon tient à ce dépôt, ou **harnais**, si elle tient à un skill, un sous-agent ou un hook d'Izanagi ;
3. pour une leçon projet, le fichier cible et la ligne exacte à ajouter.

| Nature de la leçon projet | Fichier cible |
|---|---|
| règle de code commune à tous les langages | `docs/CODING_STANDARDS.md` |
| règle de code propre à un langage, et propre à ce projet | `docs/standards/<langage>.md`, sous `## Règles du projet` |
| règle de code d'un langage, valable hors de ce projet | `docs/standards/<langage>.md`, sous `## À proposer au plugin` |
| consigne de conduite de l'agent | `CLAUDE.md` |
| connaissance du domaine | `CONTEXT.md`, ou `docs/agents/domain.md` |
| chemin qui devrait relever le niveau de risque | clé `chemins_sensibles` de `.izanagi/config.env` |

Le projet n'a pas de fichier « leçons » à part. Une règle de code ne porte que sur un jugement qu'aucun outil ne vérifie : une leçon qu'une lint attraperait devient une proposition de lint, pas une règle.

## 4. Appliquer les leçons projet

L'utilisateur accepte, modifie ou écarte chaque ligne. Écris les lignes acceptées, telles qu'il les a validées. Un motif de `chemins_sensibles` ne s'écrit qu'avec son accord explicite, puisqu'il change le niveau de risque des flux suivants.

Commite les ajouts sur la branche du flux, avant la fusion : `docs(izanagi): leçons de <flux> <nom>`. Puis vide les refus traités : `bash "${CLAUDE_PLUGIN_ROOT}/scripts/refus.sh" <branche> --vider`.

Fin : chaque leçon projet est écrite, modifiée ou écartée, et le commit est sur la branche du flux.

## 5. Rédiger les leçons harnais

Chaque leçon harnais devient un brouillon d'issue pour le dépôt d'Izanagi :

- un titre qui nomme le skill, le sous-agent ou le hook ;
- le constat, en deux ou trois phrases ;
- la preuve, tirée du journal, sans nom de projet, sans chemin du projet ni du poste et sans extrait de son code. Les motifs de `refus.log` contiennent souvent des chemins absolus (`rm -rf /c/Users/…`) : remplace-les par un chemin neutre.

Montre le brouillon à l'utilisateur. Sur son accord explicite, et seulement alors, ouvre-le :

```bash
gh issue create --repo <dépôt> --title "$(cat <fichier du titre>)" --body-file <fichier du brouillon>
```

`<dépôt>` vient du champ `repository` de `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`, sous la forme `propriétaire/nom`. Écris le titre et le brouillon dans deux fichiers temporaires hors du projet, avec l'outil Write. Le titre passe ainsi par un fichier : un nom de skill entre accents graves n'est jamais exécuté par le shell. Sans accord, n'ouvre rien et ne garde rien.

## 6. Rendre compte

Donne à l'utilisateur, en quelques lignes : la part des commits `chore(izanagi)` de la branche, même sous le quart, les règles écrites et leurs fichiers, les leçons écartées, les issues ouvertes et leurs liens. Si une section `## À proposer au plugin` n'est pas vide, dis-le : ces règles attendent d'être proposées au plugin par `/izanagi:contribuer <langage>`, que seul l'utilisateur lance.
