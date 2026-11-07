# Issue tracker : GitHub

Les issues et les specs de ce dépôt vivent dans GitHub Issues. Toutes les opérations passent par le CLI `gh`.

## Corps de texte

Tout corps multi-ligne (issue, PR, commentaire, message de commit long) s'écrit d'abord dans un fichier du scratchpad avec l'outil Write, puis passe par `--body-file <fichier>` (ou `git commit -F <fichier>`). Un heredoc ou une chaîne en ligne de commande casse sur les accents graves, les guillemets et les sauts de ligne. Après chaque commande `gh`, lis sa sortie (URL ou erreur) avant de la tenir pour faite.

## Conventions

- **Créer une issue** : `gh issue create --title "..." --body-file <fichier>`.
- **Créer une PR** : `gh pr create --base <branche> --title "..." --body-file <fichier>`.
- **Lire une issue** : `gh issue view <numéro> --comments`, en filtrant les commentaires avec `jq` et en récupérant aussi les libellés.
- **Lister les issues** : `gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'`, avec les filtres `--label` et `--state` voulus.
- **Commenter une issue** : `gh issue comment <numéro> --body-file <fichier>`
- **Poser ou retirer des libellés** : `gh issue edit <numéro> --add-label "..."` ou `--remove-label "..."`
- **Fermer** : `gh issue close <numéro> --comment "..."`

`gh` déduit le dépôt de `git remote -v` quand il tourne dans un clone.

## Les PR comme file de tri

**PRs as a request surface: no.** _(Mettre `yes` si ce dépôt traite les PR externes comme des demandes ; `/triage` lit ce drapeau.)_

Avec `yes`, les PR passent par les mêmes libellés et états que les issues, avec les équivalents `gh pr` :

- **Lire une PR** : `gh pr view <numéro> --comments`, et `gh pr diff <numéro>` pour le diff.
- **Lister les PR externes à trier** : `gh pr list --state open --json number,title,body,labels,author,authorAssociation,comments`, puis garder les `authorAssociation` valant `CONTRIBUTOR`, `FIRST_TIME_CONTRIBUTOR` ou `NONE` (écarter `OWNER`, `MEMBER` et `COLLABORATOR`).
- **Commenter, étiqueter, fermer** : `gh pr comment`, `gh pr edit --add-label` ou `--remove-label`, `gh pr close`.

GitHub numérote les issues et les PR dans la même suite : un `#42` nu peut désigner l'une ou l'autre. Essayer `gh pr view 42`, puis `gh issue view 42`.

## Quand un skill dit « publish to the issue tracker »

Créer une issue GitHub.

## Quand un skill dit « fetch the relevant ticket »

Lancer `gh issue view <numéro> --comments`.

## Opérations de wayfinding

Utilisées par `/wayfinder`. La **carte** est une issue unique, ses tickets sont des issues **enfants**.

- **Carte** : une issue libellée `wayfinder:map`, dont le corps porte les parties Notes, Decisions-so-far et Fog. `gh issue create --label wayfinder:map`.
- **Ticket enfant** : une issue reliée à la carte comme sous-issue GitHub (`gh api` sur le point d'accès des sous-issues). Si les sous-issues ne sont pas activées, ajouter l'enfant à une liste de tâches du corps de la carte et mettre `Part of #<carte>` en tête du corps de l'enfant. Libellés : `wayfinder:<type>` (`research`, `prototype`, `grilling` ou `task`). Une fois pris, le ticket est assigné au développeur qui le conduit.
- **Blocage** : les **dépendances d'issues natives** de GitHub, la représentation officielle, visible dans l'interface. Ajouter une arête avec `gh api --method POST repos/<owner>/<repo>/issues/<enfant>/dependencies/blocked_by -F issue_id=<id-base-du-bloqueur>`, où `<id-base-du-bloqueur>` est l'**identifiant de base** numérique du bloqueur (`gh api repos/<owner>/<repo>/issues/<n> --jq .id`, _pas_ le `#numéro` ni le `node_id`). GitHub expose `issue_dependencies_summary.blocked_by`, qui compte les seuls bloqueurs ouverts. Si les dépendances ne sont pas disponibles, mettre une ligne `Blocked by: #<n>, #<n>` en tête du corps de l'enfant. Un ticket est débloqué quand tous ses bloqueurs sont fermés.
- **Requête de frontière** : lister les enfants ouverts de la carte (`gh issue list --state open`, limité aux sous-issues ou à la liste de tâches de la carte), écarter ceux qui ont un bloqueur ouvert (`issue_dependencies_summary.blocked_by > 0`, ou une issue ouverte dans la ligne `Blocked by`) ou un assigné. Le premier dans l'ordre de la carte passe en tête.
- **Prise** : `gh issue edit <n> --add-assignee @me`, première écriture de la session.
- **Résolution** : `gh issue comment <n> --body-file <fichier>`, puis `gh issue close <n>`, puis ajouter un pointeur de contexte (résumé et lien) aux Decisions-so-far de la carte.
