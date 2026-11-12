---
name: review
description: Revue convergente d'un diff dans un projet Izanagi. Deux relecteurs en parallèle, l'un sur les règles du projet, l'autre sur la spec, puis des tours de correction jusqu'à un tour sans constat Important, trois tours au plus. Lancée pour une tranche, un jalon ou une PR hors jalon.
user-invocable: false
---

# Review

Tu conduis la revue d'un diff sur deux axes :

- **Standards** : le code suit-il les règles écrites du projet ?
- **Spec** : le code fait-il ce que la spec demandait, ni moins ni plus ?

Un changement peut réussir un axe et échouer l'autre. Un code peut suivre chaque règle et construire la mauvaise chose, ou faire ce qui était demandé et enfreindre les conventions du projet. Les deux axes ont chacun leur relecteur, pour que l'un ne masque pas l'autre.

La revue converge en peu de tours : le premier tour relit tout le diff, les suivants ne relisent que les corrections.

## Entrées

La phase qui t'appelle fournit :

- le **point fixe** : la branche ou le commit d'où part le diff ;
- l'**axe Spec** : un texte ou un chemin (une tranche du plan, des sections de la spec, une issue, la description d'une PR) ;
- le **journal** du jalon, s'il existe.

Lis `docs/agents/jalon.md` pour la vérification.

**Hors jalon.** Pour une PR hors jalon, le point fixe est la branche principale et l'axe Spec est l'issue ou la description de la PR. Sans `docs/agents/jalon.md`, prends la branche par défaut du dépôt et la vérification que nomme `CLAUDE.md` ou `README.md`, sinon demande-la à l'utilisateur.

## 1. Préparer le diff

Contrôle que le point fixe existe (`git rev-parse <point fixe>`) et que le diff n'est pas vide. Une référence fausse doit échouer ici, pas dans deux sous-agents.

Les relecteurs n'ont pas d'outil pour lancer git. Écris-leur le diff dans un fichier :

```bash
{ git log --oneline <point fixe>..HEAD; git diff --stat <point fixe>...HEAD; git diff <point fixe>...HEAD; } > <fichier>
```

Les trois points comparent à l'ancêtre commun. Pour un jalon, le fichier va dans le dossier du plan, `.izanagi/journal/<nom du plan sans extension>/`, que le journal soit là ou sous `.superpowers/`. Hors jalon, il va dans `.izanagi/journal/hors-jalon/`. Si `.izanagi/journal/` n'existe pas, crée-le avec un fichier `.gitignore` qui contient la seule ligne `*`. Les relecteurs lisent ainsi le diff dans le dépôt.

## 2. Premier tour

Lance les sous-agents `izanagi:reviewer-standards` et `izanagi:reviewer-spec` en parallèle. Passe à chacun :

- le chemin du fichier de diff ;
- le chemin absolu de `${CLAUDE_PLUGIN_ROOT}/references/finding.md`, qui fixe la forme et les étiquettes de ses constats ;
- les constats écartés notés au journal pour ce jalon, pour qu'il ne les reprenne pas ;
- les mineurs que les revues de tâche ont laissés au journal, à confirmer avec une étiquette ou à écarter.

Le relecteur Spec reçoit en plus l'axe Spec. Le relecteur Standards lit lui-même `docs/CODING_STANDARDS.md` et `CLAUDE.md`.

Ne fusionne pas les deux rapports et ne les reclasse pas l'un contre l'autre.

## 3. Traiter chaque constat

Si le relecteur Spec liste des exigences « non vérifiables depuis le diff », contrôle chacune toi-même avant de continuer, dans le code inchangé ou dans les autres tranches. Une exigence qui manque devient un constat Important.

Traite chaque constat selon son étiquette :

- **Important** : fais-le corriger par un sous-agent `izanagi:implementer`, comme une tâche. Une classe de bug se corrige sur toutes ses occurrences, cherchées dans tout le dépôt, pas seulement celles que le relecteur cite. Si tu penses que le constat est faux ou voulu, présente-le à l'utilisateur avec ta raison et applique sa réponse.
- **Nit** : corrige-le s'il tient en une ligne, sinon laisse-le.
- **Préexistant** : ouvre une issue (`docs/agents/issue-tracker.md`) et laisse le code tel quel dans cette branche.
- **Jugement** : présente-le à l'utilisateur et applique sa réponse.

Note au journal chaque constat écarté, avec sa raison. Hors jalon, sans journal, note-les dans la description de la PR.

## 4. Vérifier

Lance la vérification, puis commite les corrections.

## 5. Tours suivants

Relance les deux relecteurs avec les mêmes pièces qu'au premier tour, plus la liste des constats Important du tour précédent, mot pour mot. Chaque relecteur dit de chacun des siens s'il est traité. Le point fixe devient le dernier commit relu au tour précédent, pour qu'ils ne relisent que les corrections. Écris ce nouveau diff dans un nouveau fichier.

La revue a convergé quand un tour ne rend aucun Important.

## 6. Plafond

Si le troisième tour rend encore un Important, arrête les tours. Présente à l'utilisateur ce qui revient et pourquoi, et propose de revoir l'approche ou le découpage plutôt qu'un quatrième tour.

## 7. Traiter à la source

Si une règle ou une classe de bug a déjà été signalée dans une tranche précédente, d'après le journal, propose à l'utilisateur de la traiter à la source : une règle dans `docs/CODING_STANDARDS.md`, une lint ou un test.

## Fin

La revue est finie sur un tour sans Important, ou sur la décision de l'utilisateur au plafond. Note le nombre de tours au journal, ou dans la description de la PR hors jalon.

Rends à la phase qui t'a appelé un compte rendu court : le compte des constats par axe et par étiquette, le nombre de tours, les constats écartés et les issues ouvertes.
