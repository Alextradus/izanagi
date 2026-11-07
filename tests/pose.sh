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
projet=Essai Rapide
spec=docs/spec.md
lieu_test=dans WSL
decisions=le §14 de la spec
FIN

sortie="$("$pose" "$tmp/p" "$tmp/v")"
[[ $(grep -c '^créé' <<<"$sortie") -eq 10 ]] || echoue "première pose : $sortie"
[[ -x $tmp/p/scripts/check.sh && -x $tmp/p/.githooks/pre-push ]] || echoue "bit exécutable"
grep -q '{{' "$tmp/p/CLAUDE.md" && echoue "CLAUDE.md garde un {{"
grep -q 'cache/essai-rapide-target' "$tmp/p/scripts/check.sh" || echoue "cache WSL sans le nom du projet en minuscules"
grep -qF 'Les décisions sont dans le §14 de la spec.' "$tmp/p/docs/agents/domain.md" || echoue "domain.md : décisions mal accordées"
grep -qF 'de le §14' "$tmp/p/docs/agents/domain.md" && echoue "domain.md contient « de le »"
grep -qxF -- '- **Vault** : non.' "$tmp/p/docs/agents/jalon.md" || echoue "jalon.md : vault absent mal affiché"
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
rapport="$(sed -n 's/^rapport : //p' <<<"$sortie")"
grep -qxF -- '- **Vault** : `C:/Vault/essai`.' "$rapport/rendu/docs/agents/jalon.md" || echoue "jalon.md : chemin du vault sans accents graves"

# Nom de projet hostile au shell : apostrophe, &, /, majuscule accentuée.
mkdir "$tmp/r"
printf "pile=rust\nprojet=Élan d'été & Co/x\nspec=s.md\nlieu_test=ici\n" >"$tmp/u"
LC_ALL=C "$pose" "$tmp/r" "$tmp/u" >/dev/null
grep -qF 'cache/lan-d-t-co-x-target"' "$tmp/r/scripts/check.sh" || echoue "cache WSL : nom de dossier non filtré"
bash -n "$tmp/r/scripts/check.sh" || echoue "check.sh n'est plus du shell valide"
grep -qF "# Élan d'été & Co/x" "$tmp/r/CLAUDE.md" || echoue "CLAUDE.md : le nom du projet doit rester tel quel"

# projet_dossier donné par le fichier de valeurs (le name de Cargo.toml).
mkdir "$tmp/s"
printf 'pile=rust\nprojet=Raimei\nprojet_dossier=raimei-editeur\nspec=s.md\nlieu_test=ici\n' >"$tmp/x"
"$pose" "$tmp/s" "$tmp/x" >/dev/null
grep -qF 'cache/raimei-editeur-target"' "$tmp/s/scripts/check.sh" || echoue "projet_dossier fourni ignoré"

mkdir "$tmp/q"
printf 'pile=rust\nprojet=essai\n' >"$tmp/w"
if "$pose" "$tmp/q" "$tmp/w" 2>"$tmp/err"; then echoue "valeur manquante acceptée"; fi
grep -q 'spec' "$tmp/err" || echoue "message sans la clé manquante"
[[ -z $(ls -A "$tmp/q") ]] || echoue "écriture malgré une valeur manquante"

echo "pose.sh : tous les cas passent"
