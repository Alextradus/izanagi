---
name: retro
description: Conduire la rétrospective d'un flux Izanagi (jalon, task, fix) et transformer ce qu'il a coûté en règles du projet, ou en brouillons d'issue pour le plugin. À lancer quand l'utilisateur le demande par /izanagi:retro, depuis la clôture de izanagi:jalon, ou depuis la question de clôture de izanagi:task et izanagi:fix.
argument-hint: "[branche du flux]"
---

# Retro

Tu tires les leçons d'un flux : ce qui a coûté des tours de revue, des refus de hook ou des corrections de l'utilisateur. Chaque leçon devient une ligne dans un fichier du projet, ou un brouillon d'issue pour le plugin. L'utilisateur décide de chaque ligne.

Tu ne modifies jamais le plugin, `hooks.json`, ni les clés `hook_*` de `.izanagi/config.env`. Tu proposes, l'utilisateur décide.

## 1. Situer le flux

La branche est l'argument, ou la branche courante. Lis `.izanagi/state.env` avec `bash "${CLAUDE_PLUGIN_ROOT}/scripts/state.sh" get` pour connaître le flux et son nom. Le journal est :

| Flux | Journal | Rapports de revue |
|---|---|---|
| `jalon` | `.izanagi/journal/<nom du plan>.md` | `.izanagi/journal/<nom du plan>/` |
| `task` | `.izanagi/journal/task-<nom>.md` | aucun dossier |
| `fix` hors jalon | `.izanagi/journal/fix-<nom>.md` | aucun dossier |

Sans journal, dis-le et arrête-toi : la rétrospective n'a rien à lire.

Lancé depuis la question de clôture de `task` ou `fix` avec une seule leçon, va droit à la section 3 avec elle.

## 2. Lire la matière

Lis, et rien d'autre :

- le journal du flux : lignes de tâches, tours de revue, `Décision :`, constats écartés, retours de test ;
- les lignes `Correction : ` du journal, chacune une reprise de l'utilisateur ;
- les rapports de revue du dossier du plan, quand il existe ;
- les refus des hooks pour cette branche : `bash "${CLAUDE_PLUGIN_ROOT}/scripts/refus.sh" <branche>`. Chaque ligne a la forme `<date>|<branche>|<hook>|<motif>`.

Ne lis pas les transcripts de Claude Code : ils sont hors du dépôt, et la clôture tourne souvent dans une autre session que les tranches.

## 3. Proposer les leçons

Une leçon est un constat qui revient, ou un coût que l'utilisateur a nommé :

- la même classe de bug relevée dans deux tranches, ou deux tours de revue sur le même point ;
- un refus de hook répété, ou une vérification rouge qui revient sur la même cause ;
- une ligne `Correction : `.

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
- la preuve, tirée du journal, sans nom de projet, sans chemin du projet et sans extrait de son code.

Montre le brouillon à l'utilisateur. Sur son accord explicite, et seulement alors, ouvre-le :

```bash
gh issue create --repo <dépôt> --title "<titre>" --body-file <brouillon>
```

`<dépôt>` vient du champ `repository` de `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`, sous la forme `propriétaire/nom`. Écris le brouillon dans un fichier temporaire hors du projet. Sans accord, n'ouvre rien et ne garde rien.

## 6. Rendre compte

Donne à l'utilisateur, en quelques lignes : les règles écrites et leurs fichiers, les leçons écartées, les issues ouvertes et leurs liens. Si une section `## À proposer au plugin` n'est pas vide, dis-le : ces règles attendent d'être proposées au plugin.
