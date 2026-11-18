---
name: contribuer
description: Proposer au plugin Izanagi, par une PR, les règles de langage qu'un projet a mises de côté sous « À proposer au plugin ». À lancer seulement quand l'utilisateur le demande par /izanagi:contribuer.
argument-hint: "[langage]"
disable-model-invocation: true
---

# Contribuer

Tu proposes au plugin Izanagi les règles générales d'un langage que ce projet a apprises. Elles attendent dans la section `## À proposer au plugin` de `docs/standards/<langage>.md`, où `/izanagi:retro` les range. Tu les réécris sans rien qui vienne du projet, tu prépares une PR vers le dépôt d'Izanagi, et tu ne l'envoies qu'avec l'accord de l'utilisateur.

Une PR vers un dépôt public publie son contenu. Rien ne part sans un oui explicite de l'utilisateur, donné après qu'il a vu le diff complet.

## 1. Lire les règles

Le langage est l'argument. Sans argument, liste les fichiers `docs/standards/*.md` dont la section `## À proposer au plugin` a au moins une règle, et demande lequel traiter.

Lis la section. Si elle est vide, dis-le et arrête-toi.

## 2. Réécrire sans le projet

Chaque règle doit valoir pour tout projet du langage. Réécris-la sans :

- le nom du projet, de ses composants ou de son organisation ;
- un chemin du dépôt ;
- un nom de type, de fonction ou de module du projet ;
- un extrait de son code : remplace l'exemple par un exemple neutre, écrit pour l'occasion.

Donne à chaque règle la forme de `${CLAUDE_PLUGIN_ROOT}/references/langages/<langage>.md` : un titre `## R<n>. <règle en peu de mots>` qui reprend la numérotation après la dernière règle du fichier, une phrase, une ligne `Exemple :`, une ligne `Source :`. Une règle sans source publique reçoit `Source : expérience d'un projet`. Une règle qu'une lint courante vérifie déjà n'entre pas.

Une règle qui perd son sens une fois généralisée reste dans le projet. Dis-le à l'utilisateur, et ne la propose pas.

Fin : chaque règle de la section est réécrite ou laissée au projet, et l'utilisateur sait laquelle.

## 3. Préparer la PR

1. Lis le dépôt cible dans le champ `repository` de `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`, et ramène-le à la forme `propriétaire/nom`.
2. Clone-le dans un dossier temporaire hors du projet : `gh repo clone <dépôt> "$(mktemp -d)/izanagi"`. Tout ce qui suit se fait dans ce clone, jamais dans le projet.
3. Crée la branche `langage/<langage>-<AAAA-MM-JJ>`, à la date du jour. Son nom ne contient pas celui du projet.
4. Ajoute les règles réécrites à la fin de `references/langages/<langage>.md`. Pour un langage sans fichier, crée le fichier avec l'en-tête des autres fichiers de langage, et remplace sa ligne `aucun` dans la table de `references/langages/index.md` par le nom du fichier, ou ajoute la ligne du langage avec ses extensions.
5. Regarde si l'utilisateur peut écrire dans le dépôt : `gh api repos/<dépôt> --jq .permissions.push`. Si la réponse n'est pas `true`, il passera par un fork : `gh repo fork <dépôt> --clone=false --remote`, lancé dans le clone, ajoute le fork comme dépôt distant.

## 4. Accord

**Accord.** Montre à l'utilisateur le diff complet du clone (`git -C <clone> diff`), le dépôt cible et, s'il y a lieu, le fork. Demande-lui s'il veut ouvrir la PR.

Sans un oui explicite, supprime le clone et arrête-toi : rien n'est commité, rien n'est poussé, et les règles restent dans le projet.

## 5. Envoyer

Sur le oui de l'utilisateur, et seulement alors :

1. Commite dans le clone : `docs: règles <langage> proposées par un projet`.
2. Pousse la branche, vers le dépôt ou vers le fork : `git push -u <dépôt distant> langage/<langage>-<AAAA-MM-JJ>`.
3. Ouvre la PR vers la branche principale du dépôt cible avec `gh pr create --repo <dépôt>`. Le corps dit que les règles viennent des leçons d'un projet, sans le nommer, et liste les titres des règles.
4. Donne le lien de la PR à l'utilisateur, puis supprime le clone.

Les règles restent dans la section `## À proposer au plugin` du projet jusqu'à la fusion : le relecteur continue de les appliquer. Après la fusion, `/izanagi:upgrade` propose de les retirer, puisque le plugin les porte.

## 6. PR fermée sans fusion

Si l'utilisateur relance `contribuer` pour un langage dont la PR a été fermée sans fusion (`gh pr list --repo <dépôt> --state closed --search "head:langage/<langage>-"`), propose de déplacer ses règles de `## À proposer au plugin` vers `## Règles du projet`, où elles restent des règles de ce projet. Déplace-les sur son accord, et commite sur une branche `task/regles-<langage>` avec une PR, puisque la branche principale ne reçoit pas de push direct.
