#!/usr/bin/env bash
# Teste scripts/pose.sh : première pose, relance sans écrasement, écart signalé,
# valeur manquante refusée.
set -euo pipefail

racine="$(cd "$(dirname "$0")/.." && pwd)"
pose="$racine/scripts/pose.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echoue() { echo "ÉCHEC : $*" >&2; exit 1; }

mkdir "$tmp/p"
cat >"$tmp/v" <<'FIN'
pile=rust
projet=essai
spec=docs/spec.md
lieu_test=dans WSL
FIN

sortie="$("$pose" "$tmp/p" "$tmp/v")"
[[ $(grep -c '^créé' <<<"$sortie") -eq 10 ]] || echoue "première pose : $sortie"
[[ -x $tmp/p/scripts/check.sh && -x $tmp/p/.githooks/pre-push ]] || echoue "bit exécutable"
grep -q '{{' "$tmp/p/CLAUDE.md" && echoue "CLAUDE.md garde un {{"
grep -q 'essai-target' "$tmp/p/scripts/check.sh" || echoue "check.sh sans le nom du projet"
grep -q 'github.workflow' "$tmp/p/.github/workflows/ci.yml" || echoue "ci.yml a perdu ses expressions"
[[ -e $tmp/p/docs/agents/vault.md ]] && echoue "vault.md posé sans vault"

echo "règle du projet" >>"$tmp/p/docs/CODING_STANDARDS.md"
avant="$(cat "$tmp/p/docs/CODING_STANDARDS.md")"
sortie="$("$pose" "$tmp/p" "$tmp/v")"
grep -q '^différent  docs/CODING_STANDARDS.md' <<<"$sortie" || echoue "écart non signalé : $sortie"
[[ $(grep -c '^identique' <<<"$sortie") -eq 9 ]] || echoue "relance : $sortie"
[[ $(cat "$tmp/p/docs/CODING_STANDARDS.md") == "$avant" ]] || echoue "fichier écrasé"
rapport="$(sed -n 's/^rapport : //p' <<<"$sortie")"
grep -q '^-règle du projet' "$rapport/diff/docs/CODING_STANDARDS.md.diff" || echoue "diff sans l'ajout du projet"

echo "vault=C:/Vault/essai" >>"$tmp/v"
sortie="$("$pose" "$tmp/p" "$tmp/v")"
grep -q '^créé       docs/agents/vault.md' <<<"$sortie" || echoue "vault.md non posé : $sortie"

mkdir "$tmp/q"
printf 'pile=rust\nprojet=essai\n' >"$tmp/w"
if "$pose" "$tmp/q" "$tmp/w" 2>"$tmp/err"; then echoue "valeur manquante acceptée"; fi
grep -q 'spec' "$tmp/err" || echoue "message sans la clé manquante"
[[ -z $(ls -A "$tmp/q") ]] || echoue "écriture malgré une valeur manquante"

echo "pose.sh : tous les cas passent"
