#!/usr/bin/env bash
# Teste scripts/check-contract.sh sur des projets posés par install.sh.
set -euo pipefail

racine="$(cd "$(dirname "$0")/.." && pwd)"
install="$racine/scripts/install.sh"
contrat="$racine/scripts/check-contract.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echoue() { echo "ÉCHEC : $*" >&2; exit 1; }

base=(projet=essai spec=s.md lieu_test=ici test_manuel=x fichier_version=y)

# poser <nom> <ligne de valeurs>... : crée $tmp/<nom> avec install.sh.
poser() {
  local nom="$1"
  shift
  mkdir "$tmp/$nom"
  printf '%s\n' "${base[@]}" "$@" >"$tmp/$nom.v"
  "$install" "$tmp/$nom" "$tmp/$nom.v" >/dev/null
}

# Rust : contrat respecté.
poser ok composant='cli|.|rust|cargo run' systemes=linux,windows
sortie="$("$contrat" "$tmp/ok")" || echoue "Rust refusé : $sortie"
[[ $sortie == 'contrat : respecté' ]] || echoue "Rust : sortie $sortie"

# Le contrôle n'écrit rien.
avant="$(cd "$tmp/ok" && find . -type f | sort | xargs cat | cksum)"
"$contrat" "$tmp/ok" >/dev/null
apres="$(cd "$tmp/ok" && find . -type f | sort | xargs cat | cksum)"
[[ $avant == "$apres" ]] || echoue "check-contract.sh a écrit dans le projet"

# zig sans rien remplir : À ÉCRIRE dans check.sh et ci.yml.
poser zig composant='api|.|zig|' systemes=linux,windows
if sortie="$("$contrat" "$tmp/zig")"; then echoue "zig vide accepté"; fi
grep -q '^contrat : scripts/check.sh : .*À ÉCRIRE' <<<"$sortie" || echoue "zig : check.sh : $sortie"
grep -q '^contrat : .github/workflows/ci.yml : .*À ÉCRIRE' <<<"$sortie" || echoue "zig : ci.yml : $sortie"

# zig rempli.
sed -i 's/^\( *\)# À ÉCRIRE : api (zig).*/\1true/' "$tmp/zig/scripts/check.sh"
sed -i 's/^\( *\)# À ÉCRIRE : installation de zig.*/\1- run: echo zig/' "$tmp/zig/.github/workflows/ci.yml"
sortie="$("$contrat" "$tmp/zig")" || echoue "zig rempli refusé : $sortie"

# Installation sans verrou.
for ajout in 'npm install' 'pip install x' 'uv sync' 'cargo build'; do
  cp -r "$tmp/ok" "$tmp/nl"
  sed -i "s/^    echo \"-- cli : format\"/    $ajout\n&/" "$tmp/nl/scripts/check.sh"
  if sortie="$("$contrat" "$tmp/nl")"; then echoue "« $ajout » accepté"; fi
  grep -q 'verrou' <<<"$sortie" || echoue "« $ajout » : sortie sans verrou : $sortie"
  rm -rf "$tmp/nl"
done
# Les formes verrouillées et les commentaires passent.
cp -r "$tmp/ok" "$tmp/nl"
sed -i 's/^    echo "-- cli : format"/    # npm install\n    uv sync --locked\n    npm ci\n&/' "$tmp/nl/scripts/check.sh"
"$contrat" "$tmp/nl" >/dev/null || echoue "formes verrouillées refusées"
rm -rf "$tmp/nl"

# Ligne os: modifiée à la main.
cp -r "$tmp/ok" "$tmp/os"
sed -i 's/os: \[ubuntu-latest, windows-latest\]/os: [ubuntu-latest]/' "$tmp/os/.github/workflows/ci.yml"
if sortie="$("$contrat" "$tmp/os")"; then echoue "os modifié accepté"; fi
grep -q 'ci.yml' <<<"$sortie" || echoue "os : $sortie"
rm -rf "$tmp/os"

# Composant sans section dans check.sh.
cp -r "$tmp/ok" "$tmp/sec"
sed -i 's/^# --- composant cli (/# --- composant autre (/' "$tmp/sec/scripts/check.sh"
if sortie="$("$contrat" "$tmp/sec")"; then echoue "section absente acceptée"; fi
grep -q 'cli' <<<"$sortie" || echoue "section : $sortie"
rm -rf "$tmp/sec"

# check.sh sans --host.
cp -r "$tmp/ok" "$tmp/h"
sed -i 's/--host)/--hote)/' "$tmp/h/scripts/check.sh"
if sortie="$("$contrat" "$tmp/h")"; then echoue "--host absent accepté"; fi
rm -rf "$tmp/h"

# harness.md supprimé.
rm "$tmp/ok/docs/agents/harness.md"
if sortie="$("$contrat" "$tmp/ok")"; then echoue "harness.md absent accepté"; fi
grep -q 'harness.md' <<<"$sortie" || echoue "harness : $sortie"

# Aucun composant : rien à vérifier.
poser vide
sortie="$("$contrat" "$tmp/vide")" || echoue "projet vide refusé : $sortie"
[[ $sortie == 'contrat : aucun composant, rien à vérifier' ]] || echoue "vide : $sortie"

echo "check-contract.sh : tous les cas passent"
