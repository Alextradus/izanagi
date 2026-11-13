---
name: merge-conflicts
description: Résoudre un conflit de fusion ou de rebase en cours dans un projet Izanagi, en gardant l'intention des deux côtés, puis vérifier et terminer l'opération.
user-invocable: false
---

# Merge conflicts

Tu résous un conflit de fusion ou de rebase en cours.

1. **Lis l'état.** Regarde où en est la fusion ou le rebase (`git status`), l'historique des deux côtés et les fichiers en conflit.

2. **Trouve la raison de chaque changement.** Pour chaque conflit, lis les messages de commit, la PR et l'issue d'origine, ainsi que la tâche du plan si le changement vient d'un jalon. Tu dois pouvoir dire pourquoi chaque côté a fait son changement.

3. **Résous chaque bloc.** Garde les deux intentions quand c'est possible. Quand elles s'excluent, garde celle qui sert le but de la fusion et note ce que tu abandonnes. N'invente aucun comportement nouveau. Résous toujours : n'abandonne pas l'opération avec `--abort`.

4. **Vérifie.** Lance la commande de la clé `verification` de `.izanagi/config.env`. Corrige ce que la fusion a cassé.

5. **Termine.** Indexe tout et commite. Pendant un rebase, continue jusqu'à ce que tous les commits soient rejoués.

Rends ensuite la liste des fichiers en conflit et, pour chaque intention abandonnée, ce que tu as gardé et pourquoi.
