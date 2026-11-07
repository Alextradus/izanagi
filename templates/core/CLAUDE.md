# {{projet}}

- Spec, qui fait foi : `{{spec}}`. Plans par jalon : `{{plans}}`.
- Vérifier avant de pousser ou de rendre une tâche : `{{verification}}`. Le hook `.githooks/pre-push` lance `scripts/check.sh --host` (activation, une fois par clone : `git config core.hooksPath .githooks`).
- Relecture : `docs/CODING_STANDARDS.md`.
- Jalons : `/izanagi:jalon`, réglé par `docs/agents/jalon.md`.
{{ligne_vault}}

## Agent skills

### Issue tracker

Les issues vivent dans GitHub Issues (`gh`). Voir `docs/agents/issue-tracker.md`.

### Triage labels

Les cinq libellés par défaut. Voir `docs/agents/triage-labels.md`.

### Domain docs

Contexte unique : `CONTEXT.md` à la racine, décisions dans la spec. Voir `docs/agents/domain.md`.
