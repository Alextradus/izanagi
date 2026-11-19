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

# Sans recherche de secrets : refusé.
cp -r "$tmp/ok" "$tmp/sanssecret"
sed -i '/gitleaks git/d' "$tmp/sanssecret/scripts/check.sh"
if sortie="$("$contrat" "$tmp/sanssecret")"; then echoue "check.sh sans gitleaks accepté"; fi
grep -qF 'contrat : scripts/check.sh : ne lance pas la recherche de secrets (gitleaks git)' <<<"$sortie" || echoue "sans gitleaks : $sortie"

# zig sans rien remplir : À ÉCRIRE dans check.sh et ci.yml.
poser zig composant='api|.|zig|' systemes=linux,windows
if sortie="$("$contrat" "$tmp/zig")"; then echoue "zig vide accepté"; fi
grep -q '^contrat : scripts/check.sh : .*À ÉCRIRE' <<<"$sortie" || echoue "zig : check.sh : $sortie"
grep -q '^contrat : .github/workflows/ci.yml : .*À ÉCRIRE' <<<"$sortie" || echoue "zig : ci.yml : $sortie"
grep -q '^contrat : .github/workflows/securite.yml : .*À ÉCRIRE' <<<"$sortie" || echoue "zig : securite.yml : $sortie"

# zig rempli.
sed -i 's/^\( *\)# À ÉCRIRE : api (zig).*/\1true/' "$tmp/zig/scripts/check.sh"
sed -i 's/^\( *\)# À ÉCRIRE : installation de zig.*/\1- run: echo zig/' "$tmp/zig/.github/workflows/ci.yml"
sed -i 's/^\( *\)# À ÉCRIRE : audit des dépendances de api (zig).*/\1- run: echo audit/' \
  "$tmp/zig/.github/workflows/ci.yml" "$tmp/zig/.github/workflows/securite.yml"
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

# Règle 7 : une CI qui lance encore `--host` seul est refusée, même si le job
# couverture lance `--host --complet`.
cp -r "$tmp/ok" "$tmp/r7"
sed -i 's/^\( *\)run: bash scripts\/check.sh --host --complet$/\1run: bash scripts\/check.sh --host/' "$tmp/r7/.github/workflows/ci.yml"
grep -qxF '        run: bash scripts/check.sh --host' "$tmp/r7/.github/workflows/ci.yml" || echoue "règle 7 : sed sans effet"
if sortie="$("$contrat" "$tmp/r7")"; then echoue "CI sans --complet acceptée"; fi
grep -qxF 'contrat : .github/workflows/ci.yml : ne lance pas bash scripts/check.sh --host --complet' <<<"$sortie" || echoue "règle 7 : $sortie"
# Dans un bloc `run: |`, la ligne seule passe aussi.
cp -r "$tmp/ok" "$tmp/r7b"
sed -i 's/^\( *\)run: bash scripts\/check.sh --host --complet$/\1run: |\n\1  bash scripts\/check.sh --host --complet/' "$tmp/r7b/.github/workflows/ci.yml"
sortie="$("$contrat" "$tmp/r7b")" || echoue "règle 7 : bloc run: | refusé : $sortie"
rm -rf "$tmp/r7" "$tmp/r7b"

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

# check.sh qui ne lit pas ses arguments : la règle 2 est sautée, rien ne dort.
cp -r "$tmp/ok" "$tmp/sd"
printf '#!/usr/bin/env bash\n# --- composant cli (rust) ---\ncase "${1:-}" in --clean) ;; esac\nsleep 60\n' >"$tmp/sd/scripts/check.sh"
sortie="$(IZANAGI_CONTRAT_DELAI=1 "$contrat" "$tmp/sd" || true)"
grep -q 'ne gère pas --host' <<<"$sortie" || echoue "sans --host : $sortie"
grep -q 'option inconnue' <<<"$sortie" && echoue "règle 2 lancée sans --host : $sortie"
rm -rf "$tmp/sd"

# check.sh dont la branche d'option inconnue dort : délai dépassé, écart.
cp -r "$tmp/ok" "$tmp/sl"
printf '#!/usr/bin/env bash\n# --- composant cli (rust) ---\ncase "${1:-}" in\n  --host|-h) ;;\n  --clean) exit 0 ;;\n  *) sleep 60 ;;\nesac\n' >"$tmp/sl/scripts/check.sh"
if sortie="$(IZANAGI_CONTRAT_DELAI=1 "$contrat" "$tmp/sl")"; then echoue "délai dépassé accepté"; fi
grep -q 'option inconnue doit sortir avec le code 2' <<<"$sortie" || echoue "délai : $sortie"
grep -qE 'ne gère pas --(host|clean)' <<<"$sortie" && echoue "--host|-h) non reconnu : $sortie"
rm -rf "$tmp/sl"

# Cas entre guillemets : `"--host")` et `'--clean')` sont reconnus.
cp -r "$tmp/ok" "$tmp/gu"
sed -i -e 's/^\( *\)--host)/\1"--host")/' -e "s/^\\( *\\)--clean)/\\1'--clean')/" "$tmp/gu/scripts/check.sh"
grep -qF '"--host")' "$tmp/gu/scripts/check.sh" && grep -qF "'--clean')" "$tmp/gu/scripts/check.sh" || echoue "guillemets : sed sans effet"
sortie="$("$contrat" "$tmp/gu")" || echoue "cas entre guillemets refusés : $sortie"
rm -rf "$tmp/gu"

# Systèmes de harness.md avec espaces : « linux, windows » vaut linux,windows.
cp -r "$tmp/ok" "$tmp/sp"
sed -i 's/^- \*\*Systèmes cibles\*\* : linux,windows\./- **Systèmes cibles** : linux, windows./' "$tmp/sp/docs/agents/harness.md"
grep -qF 'linux, windows.' "$tmp/sp/docs/agents/harness.md" || echoue "espaces : sed sans effet"
sortie="$("$contrat" "$tmp/sp")" || echoue "systèmes avec espaces refusés : $sortie"
rm -rf "$tmp/sp"

# Section CRLF avec `npm install` : signalée.
cp -r "$tmp/ok" "$tmp/cr"
sed -i 's/^    echo "-- cli : format"/    npm install/' "$tmp/cr/scripts/check.sh"
sed -i 's/$/\r/' "$tmp/cr/scripts/check.sh"
if sortie="$("$contrat" "$tmp/cr")"; then echoue "npm install en CRLF accepté"; fi
grep -q 'verrou' <<<"$sortie" || echoue "CRLF : $sortie"
rm -rf "$tmp/cr"

# Règle 10 : une étape par couche déclarée dans harness.md.
poser couches composant='cli|.|rust|cargo run|unitaire,integration,fonctionnelle' systemes=linux,windows \
  fonctionnel_projet='e2e|bash e2e/run.sh'
sortie="$("$contrat" "$tmp/couches")" || echoue "projet à trois couches refusé : $sortie"
[[ $sortie == 'contrat : respecté' ]] || echoue "trois couches : $sortie"
for couche in unitaire integration fonctionnelle; do
  cp -r "$tmp/couches" "$tmp/manque"
  sed -i "/echo \"-- cli : $couche\"/d" "$tmp/manque/scripts/check.sh"
  if sortie="$("$contrat" "$tmp/manque")"; then echoue "étape $couche manquante acceptée"; fi
  grep -qF "contrat : scripts/check.sh : pas d'étape $couche pour le composant cli" <<<"$sortie" || echoue "étape $couche : $sortie"
  rm -rf "$tmp/manque"
done
cp -r "$tmp/couches" "$tmp/manque"
sed -i '/echo "-- projet : fonctionnelle"/d' "$tmp/manque/scripts/check.sh"
if sortie="$("$contrat" "$tmp/manque")"; then echoue "étape projet manquante acceptée"; fi
grep -qF "contrat : scripts/check.sh : pas d'étape fonctionnelle pour le composant projet" <<<"$sortie" || echoue "étape projet : $sortie"
rm -rf "$tmp/manque"

# Règle 11 : check.sh gère --complet.
cp -r "$tmp/ok" "$tmp/comp"
sed -i 's/--complet)/--entier)/' "$tmp/comp/scripts/check.sh"
if sortie="$("$contrat" "$tmp/comp")"; then echoue "--complet absent accepté"; fi
grep -qF 'contrat : scripts/check.sh : ne gère pas --complet' <<<"$sortie" || echoue "--complet : $sortie"
rm -rf "$tmp/comp"

# Des composants et aucune couche déclarée : écart.
cp -r "$tmp/ok" "$tmp/nc"
sed -i '/^- couche : /d' "$tmp/nc/docs/agents/harness.md"
if sortie="$("$contrat" "$tmp/nc")"; then echoue "aucune couche déclarée acceptée"; fi
grep -qF 'contrat : docs/agents/harness.md : aucune couche de test déclarée' <<<"$sortie" || echoue "aucune couche : $sortie"
rm -rf "$tmp/nc"

# harness.md supprimé.
rm "$tmp/ok/docs/agents/harness.md"
if sortie="$("$contrat" "$tmp/ok")"; then echoue "harness.md absent accepté"; fi
grep -q 'harness.md' <<<"$sortie" || echoue "harness : $sortie"

# Aucun composant : rien à vérifier.
poser vide
sortie="$("$contrat" "$tmp/vide")" || echoue "projet vide refusé : $sortie"
[[ $sortie == 'contrat : aucun composant, rien à vérifier' ]] || echoue "vide : $sortie"

echo "check-contract.sh : tous les cas passent"
