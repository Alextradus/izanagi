---
name: doctor
description: Contrôler le poste et le cadre Izanagi d'un projet (outils, navigateurs Playwright, outils de mutation, hooks, réglages, version du cadre, contrat de vérification, cohérence de l'état avec git) et proposer la correction de chaque écart. À lancer quand un flux se comporte de façon inattendue ou après un changement de poste.
---

# Doctor

Tu contrôles le poste et le cadre du projet courant, puis tu proposes la correction de chaque écart. Tu ne corriges rien sans l'accord de l'utilisateur, et tu ne désinstalles jamais rien.

## 1. Lancer le contrôle

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/doctor.sh" <racine du projet>
```

Le script rend une ligne par contrôle, `ok      <contrôle>` ou `écart   <contrôle> : <détail>`, et sort avec 1 s'il y a un écart. S'il sort avec 2 et `pas un projet Izanagi`, renvoie à `/izanagi:init` et arrête-toi.

## 2. Ajouter ce que le script ne voit pas

**Hooks du plugin.** Le script contrôle le réglage des clés `hook_push`, `hook_verification` et `hook_destructif`, pas le chargement des hooks par Claude Code. Dis à l'utilisateur que `/hooks` liste les hooks chargés, et qu'il doit y voir `session-start.sh`, `guard-push.sh`, `guard-destructive.sh` et `verify-implementer.sh`.

**Skills en double.** Regarde ta liste de skills. Un skill d'un autre plugin qui a le rôle d'un skill d'Izanagi est un doublon : `superpowers:brainstorming`, `superpowers:writing-plans`, `superpowers:subagent-driven-development`, `superpowers:test-driven-development`, `superpowers:systematic-debugging`, `mattpocock-skills:grilling`, `mattpocock-skills:tdd`, `mattpocock-skills:code-review`, `mattpocock-skills:diagnosing-bugs`, `mattpocock-skills:domain-modeling`. Signale ceux que tu vois, en une ligne chacun. Le `CLAUDE.md` du projet dit déjà que les skills `izanagi:*` priment, donc un doublon n'est pas une panne. Si Superpowers est actif, dis que son hook de démarrage pousse ses propres skills à chaque session, et que l'utilisateur peut le désactiver pour ce projet.

**Ligne de priorité.** Vérifie que `CLAUDE.md` contient la ligne qui dit que les skills `izanagi:*` priment. Si elle manque, c'est un écart.

## 3. Rendre compte

Rends la sortie du script dans un bloc de code, puis la liste des écarts. Pour chacun, donne la commande ou le geste qui le corrige :

| Écart | Correction |
|---|---|
| `outil <nom>` | la commande d'installation officielle de l'outil |
| `gh connecté` | `gh auth login`, que l'utilisateur lance lui-même |
| `wsl` | `wsl --install`, ou retirer `linux` des systèmes cibles de `docs/agents/harness.md` |
| `hook pre-push` | `git config core.hooksPath .githooks` |
| `config.env` | remplir les clés citées dans `.izanagi/config.env` |
| `version du cadre`, `jalon.md` | `/izanagi:upgrade` |
| `hook_push`, `hook_verification` | remettre `bloque` dans `.izanagi/config.env`. C'est un choix de l'utilisateur : rappelle-le sans insister |
| `hook_destructif` | remettre `demande` dans `.izanagi/config.env`. Même remarque |
| `permissions` | ajouter les règles citées à la liste `permissions.deny` de `.claude/settings.json`, avec l'outil Edit, sans toucher aux autres clés |
| `actions épinglées` | remplacer l'étiquette de chaque action citée par le SHA de son commit, l'étiquette en commentaire (`uses: <action>@<SHA> # v1.2.3`). Le SHA se lit avec `gh api repos/<propriétaire>/<action>/commits/<étiquette> --jq .sha` |
| `outil gitleaks` | `winget install Gitleaks.Gitleaks` sous Windows, `brew install gitleaks` sous macOS, le binaire de https://github.com/gitleaks/gitleaks/releases sous Linux |
| `navigateurs Playwright`, `navigateurs Playwright (WSL)` | `npx playwright install chromium`, lancé dans le dossier du composant TypeScript, ou dans WSL pour la seconde ligne. Le script lit `navigateur` dans `.izanagi/config.env` et ne contrôle rien tant que la clé manque ou vaut `non` |
| `cargo-mutants`, `stryker`, `mutmut` | la commande que la ligne donne : `cargo install cargo-mutants`, `npm install --save-dev @stryker-mutator/core @stryker-mutator/vitest-runner` dans le dossier du composant, `uv add --dev mutmut` dans le dossier du composant. Le script lit `mutation` dans `.izanagi/config.env` et ne contrôle rien tant que la clé manque ou vaut `non` |
| `contrat` | `bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-contract.sh" <racine>` pour le détail, puis la correction de chaque règle |
| `état` | git l'emporte. Sur une branche de flux, `/izanagi:jalon` corrige l'état. Sur la branche principale, supprimer `.izanagi/state.env` par une PR |

Attends l'accord de l'utilisateur avant de lancer une correction.

Propose enfin deux contrôles plus longs, que le script ne lance pas : `bash scripts/check.sh --host`, qui dit si la vérification passe sur ce poste, et `/izanagi:upgrade`, qui montre les écarts du projet au gabarit.
