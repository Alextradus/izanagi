---
name: review
description: Revue convergente d'un diff dans un projet Izanagi. Deux relecteurs en parallèle, l'un sur les règles du projet, l'autre sur la spec, puis des tours de correction jusqu'à un tour sans constat Important, trois tours au plus. Le niveau de risque du diff règle le nombre de relecteurs et de tours. Lancée pour une tranche, un jalon, une tâche, un correctif ou une PR hors jalon.
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
- le **journal** du jalon, s'il existe ;
- le **rapport de mutation**, facultatif : la sortie de `mutation.sh` que la phase a lancé avant la revue ;
- le **niveau de risque** déclaré : `faible`, `normal` ou `eleve`. Sans niveau donné, prends `normal`. Un plan écrit « élevé » : passe `eleve` aux scripts, qui refusent l'accent.

Lis `.izanagi/config.env` : la clé `verification` donne la vérification, la clé `branche` la branche principale.

**Hors jalon.** Pour une PR hors jalon, le point fixe est la branche principale et l'axe Spec est l'issue ou la description de la PR. Dans un dépôt sans `.izanagi/config.env`, prends la branche par défaut du dépôt et la vérification que nomme `CLAUDE.md` ou `README.md`, sinon demande-la à l'utilisateur.

## 1. Préparer le diff

Contrôle que le point fixe existe (`git rev-parse <point fixe>`) et que le diff n'est pas vide. Une référence fausse doit échouer ici, pas dans deux sous-agents.

Les relecteurs n'ont pas d'outil pour lancer git. Écris-leur le diff dans un fichier :

```bash
{ git log --oneline <point fixe>..HEAD; git diff --stat <point fixe>...HEAD; git diff <point fixe>...HEAD; } > <fichier>
```

Les trois points comparent à l'ancêtre commun. Pour un jalon, le fichier va dans le dossier du plan, `.izanagi/journal/<nom du plan sans extension>/`. Hors jalon, il va dans `.izanagi/journal/hors-jalon/`. Git ignore ces deux dossiers (`.izanagi/.gitignore`). Dans un dépôt sans `.izanagi/`, écris le fichier dans `.git/izanagi-review/`, que git ne suit jamais. Les relecteurs lisent ainsi le diff dans le dépôt.

**Rapport de mutation.** Si la phase en fournit un, écris-le à côté du diff, dans le même dossier, sous le nom `mutation.txt`. Le rapport liste les lignes `survivant`, les lignes `non muté` et un compte final. Sur TypeScript, Stryker lance toute la configuration Vitest. La couche fonctionnelle peut aussi tuer des mutants, et le nombre de survivants peut donc être plus bas que les couches unitaire et d'intégration seules ne le donneraient.

## 2. Niveau de risque

`${CLAUDE_PLUGIN_ROOT}/references/risk.md` décrit les niveaux. Dans un projet Izanagi, calcule le niveau retenu :

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/risk.sh" <point fixe> <niveau déclaré>
```

Le script rend le niveau déclaré, ou `eleve` si le diff touche un chemin sensible du projet, qu'il nomme alors sur sa sortie d'erreur. Annonce en une ligne le niveau retenu et les chemins qui l'ont fait monter. Dans un dépôt sans `.izanagi/config.env`, garde le niveau déclaré.

Le niveau retenu règle la suite :

| Niveau | Relecteurs | Tours | Après la revue |
|---|---|---|---|
| `faible` | `izanagi:reviewer-standards` seul | un, sauf Important (section 6) | rien |
| `normal` | Standards et Spec | trois au plus | rien |
| `eleve` | Standards, Spec et Sécurité | trois au plus | l'utilisateur relit le diff |

Si l'utilisateur change le niveau pendant la revue, applique le nouveau niveau à partir du tour en cours.

## 3. Premier tour

Lance les sous-agents `izanagi:reviewer-standards` et `izanagi:reviewer-spec` en parallèle. Au niveau `eleve`, lance aussi `izanagi:reviewer-security`, en parallèle des deux autres. Au niveau `faible`, lance le seul `izanagi:reviewer-standards`, et saute ce que ce skill dit du relecteur Spec. Passe à chacun :

- le chemin du fichier de diff ;
- au seul `izanagi:reviewer-standards`, et au premier tour seulement, le chemin de `mutation.txt` s'il existe ;
- le chemin absolu de `${CLAUDE_PLUGIN_ROOT}/references/finding.md`, qui fixe la forme et les étiquettes de ses constats ;
- les constats écartés notés au journal pour ce jalon, pour qu'il ne les reprenne pas ;
- les mineurs que les revues de tâche ont laissés au journal, à confirmer avec une étiquette ou à écarter.

Le relecteur Spec reçoit en plus l'axe Spec. Le relecteur Standards lit lui-même `docs/CODING_STANDARDS.md`, `CLAUDE.md` et `docs/standards/`, et reçoit en plus le chemin absolu de `${CLAUDE_PLUGIN_ROOT}/references/langages/index.md`, qui le mène aux règles générales de chaque langage. Le relecteur Sécurité reçoit en plus le chemin absolu de `${CLAUDE_PLUGIN_ROOT}/references/types/<type>.md`, où `<type>` est le type d'application que donne `docs/agents/harness.md`. Pour un projet à plusieurs types, passe-lui chaque fiche.

Ne fusionne pas les rapports et ne les reclasse pas l'un contre l'autre.

## 4. Traiter chaque constat

Si le relecteur Spec liste des exigences « non vérifiables depuis le diff », contrôle chacune toi-même avant de continuer, dans le code inchangé ou dans les autres tranches. Une exigence qui manque devient un constat Important.

Traite chaque constat selon son étiquette :

- **Important** : fais-le corriger par un sous-agent `izanagi:implementer`, comme une tâche. Une classe de bug se corrige sur toutes ses occurrences, cherchées dans tout le dépôt, pas seulement celles que le relecteur cite. Si tu penses que le constat est faux ou voulu, présente-le à l'utilisateur avec ta raison et applique sa réponse.
- **Nit** : corrige-le s'il tient en une ligne, sinon laisse-le.
- **Préexistant** : ouvre une issue (`docs/agents/issue-tracker.md`) et laisse le code tel quel dans cette branche.
- **Jugement** : présente-le à l'utilisateur et applique sa réponse.

Note au journal chaque constat écarté, avec sa raison. Hors jalon, sans journal, note-les dans la description de la PR.

## 5. Vérifier

Lance la vérification. Les sous-agents `izanagi:implementer` ont déjà commité leurs corrections. Dans un flux, c'est-à-dire sur une branche qui porte un état (jalon, `task` ou `fix`), c'est toi qui commites ensuite le tour : lance `bash "${CLAUDE_PLUGIN_ROOT}/scripts/state.sh" set tour=<numéro du tour> risque=<niveau retenu> --commit`, puis commite les lignes ajoutées au journal (`chore(izanagi): journal, tour <numéro du tour>`). `/izanagi:status` lit l'état commité : un tour non commité n'y apparaît pas. La clôture d'un flux supprime son journal avec `git rm`, qui refuse un fichier modifié : ne laisse aucune ligne de journal hors d'un commit.

**Correctif de jalon.** Si l'état porte une clé `correctif`, il est celui du jalon, pas celui du correctif en revue. N'y écris ni le tour ni le niveau : commite seulement les lignes du journal, où tu notes aussi le niveau retenu.

## 6. Tours suivants

**Niveau `faible`.** Si le tour unique ne rend aucun Important, la revue s'arrête là. S'il en rend un, le niveau retenu monte à `normal` (`${CLAUDE_PLUGIN_ROOT}/references/risk.md`) : annonce-le en une ligne, avec le constat qui l'a fait monter. Le tour 1 compte, le plafond reste trois tours, et l'état reçoit `risque=normal` au commit du tour (section 5). Au tour 2, lance Standards et Spec. Standards relit les corrections, comme ci-dessous. Spec n'a encore rien relu : il reçoit le diff entier depuis le point fixe d'origine, écrit dans un nouveau fichier. La phase qui t'a appelé applique ensuite le niveau `normal`, test manuel compris.

Aux niveaux `normal` et `eleve`, relance les relecteurs du premier tour avec les mêmes pièces, plus la liste des constats Important du tour précédent, mot pour mot. La même liste va à chaque relecteur, et chacun répond sur les constats de son axe. Contrôle de nouveau toi-même ce que le relecteur Spec dit non vérifiable depuis le diff. Le point fixe devient le dernier commit relu au tour précédent, pour qu'ils ne relisent que les corrections. Écris ce nouveau diff dans un nouveau fichier. Ne relance pas la mutation et ne passe plus `mutation.txt`.

La revue a convergé quand un tour ne rend aucun Important.

## 7. Plafond

Si le troisième tour rend encore un Important, arrête les tours. Présente à l'utilisateur ce qui revient et pourquoi, et propose de revoir l'approche ou le découpage plutôt qu'un quatrième tour.

## 8. Traiter à la source

Si une règle ou une classe de bug a déjà été signalée dans une tranche précédente, d'après le journal, propose à l'utilisateur de la traiter à la source : une règle dans `docs/CODING_STANDARDS.md`, une lint ou un test.

## Fin

La revue est finie sur un tour sans Important, ou sur la décision de l'utilisateur au plafond.

**Niveau `eleve` : relecture par l'utilisateur.** Une fois la revue finie, donne à l'utilisateur de quoi lire le diff entier : le lien de la PR si elle existe, sinon la commande `git diff <point fixe>...HEAD`. Dis-lui quels chemins sensibles le diff touche. Attends qu'il dise avoir relu, et traite ses remarques comme des constats Jugement. La phase qui t'a appelé ne fusionne rien avant.

À tout niveau, note le nombre de tours et le niveau retenu au journal, et commite la ligne. Sans journal, note-les dans la description de la PR. Hors flux, supprime ensuite `.izanagi/journal/hors-jalon/` ou `.git/izanagi-review/`.

Rends à la phase qui t'a appelé un compte rendu court : le niveau de risque retenu, le compte des constats par axe et par étiquette, le nombre de tours, les constats écartés et les issues ouvertes.
