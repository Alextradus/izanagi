# Garde-fous

[Guide](README.md) · [Démarrer](demarrer.md) · [Les flux](flux.md) · [Tests](tests.md) · [Garde-fous](garde-fous.md) · [Release](release.md)

Izanagi applique ses règles de deux façons : quatre hooks de Claude Code, qui regardent ce que l'agent fait pendant la session, et la sécurité posée dans le projet (vérification locale et CI), qui regarde ce qui part dans une PR.

## Hooks

Le plugin installe quatre hooks. Chacun sort sans rien faire hors d'un projet Izanagi.

- **Au démarrage d'une session**, le premier ajoute au contexte l'état du flux de la branche courante. Il avertit aussi quand le cadre du projet est en retard sur le plugin.
- **Avant un `git push`**, le deuxième refuse un push qui vise la branche principale, `git push --all` et `git push --mirror` compris. Un push de tag et une suppression de branche passent.
- **Avant une commande Bash**, le troisième te demande de confirmer un geste destructeur : `git reset --hard`, `git clean -f`, `git push --force` sans `--force-with-lease`, `git branch -D`, `git checkout .` ou `git restore .` sur un arbre modifié, `rm -rf` sur la racine du dépôt ou hors de lui. Il demande aussi avant la lecture d'un fichier de secrets par une commande Bash (`cat`, `source`, `cp`…) : `.env*` sauf `.env.example`, `*.pem`, `*.key`, `id_rsa*`, `id_ed25519*`, `id_ecdsa*`, `credentials*`. Le motif `.env*` couvre aussi `.envrc`.
- **À l'arrêt de l'implémenteur**, le quatrième relance la vérification du projet. Un échec renvoie l'implémenteur au travail, avec la fin de la sortie. Le hook laisse passer un implémenteur qui se déclare bloqué, et cesse de bloquer après deux refus.

Les hooks du push et de la commande Bash sont des garde-fous contre un geste fait par habitude : ils ne voient que la commande tapée, et une commande construite pour les tromper (variable, alias, `eval`) passe. Ils ne surveillent pas le réseau.

Les hooks du push et de la vérification bloquent par défaut, et celui des commandes destructrices demande. Pour qu'un hook avertisse au lieu de bloquer, écris `hook_push=avertit`, `hook_verification=avertit` ou `hook_destructif=avertit` dans `.izanagi/config.env`. `hook_destructif=bloque` refuse au lieu de demander.

Chaque refus, avertissement ou demande d'un hook s'ajoute à `.izanagi/refus.log`, que git ignore et que `/izanagi:retro` lit.

`init` écrit aussi dans `.claude/settings.json` du projet des règles `permissions.deny`, que Claude Code applique lui-même : ses outils ne lisent ni n'écrivent les fichiers de secrets ci-dessus.

## Sécurité du projet

- `scripts/check.sh` cherche des secrets avec `gitleaks` dans les commits de la branche absents de la branche principale, avant de vérifier les composants. Un faux positif s'écarte dans `.gitleaks.toml`, avec sa raison.
- Le job `audit` de la CI audite les dépendances de chaque composant. Une faille haute ou critique fait échouer la PR (`cargo audit`, `npm audit`). Pour Python, `pip-audit` ne filtre pas par gravité : toute faille connue fait échouer la PR.
- `.github/workflows/securite.yml` relance chaque lundi l'audit et `gitleaks` sur tout l'historique. En cas d'échec, il ouvre une issue `securite` ou commente celle qui est ouverte.
- Le job `analyse` de la CI lance Semgrep CE avec les règles du registre (`p/default`). Il affiche tous les constats, et un constat de sévérité ERROR fait échouer la PR. Un faux positif s'écarte par un commentaire `# nosemgrep: <règle>` sur sa ligne, avec la raison juste au-dessus. `securite.yml` relance aussi cette analyse chaque lundi.
- Les actions de la CI sont épinglées par SHA. Chaque lundi, `.github/dependabot.yml` propose leurs mises à jour et celles des dépendances de chaque composant (`cargo`, `npm`, `uv`). Les mineures et les patchs d'un composant se groupent en une PR, et chaque majeure a la sienne. La CI les vérifie comme les autres PR, et tu les fusionnes. Une majeure qui casse la vérification passe par `/izanagi:task`, sur la PR de Dependabot.
- Au niveau de risque élevé, un troisième relecteur, `reviewer-security`, cherche dans le diff les failles que liste la fiche du type d'application.
