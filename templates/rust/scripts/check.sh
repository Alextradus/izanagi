#!/usr/bin/env bash
# Vérifications du dépôt, celles de la CI : format, clippy, tests.
#
#   scripts/check.sh            machine courante, puis WSL si on est sous Windows
#   scripts/check.sh --host     machine courante seulement (hook pre-push)
#
# Affiche un résumé par plateforme (`windows : 695 réussis, 0 échec`) et sort
# en erreur au premier échec.
set -euo pipefail

cd "$(dirname "$0")/.."

host_only=false
case "${1:-}" in
  --host) host_only=true ;;
  "") ;;
  *) echo "usage : scripts/check.sh [--host]" >&2; exit 2 ;;
esac

# Résumé d'une sortie de `cargo test` : total des tests réussis et échoués.
summarize() {
  awk '/^test result:/ { ok += $4; ko += $6 } END { printf "%d réussis, %d échec(s)\n", ok, ko }'
}

run_checks() {
  local label=$1
  shift
  echo "== $label : format, clippy, tests"
  "$@" cargo fmt --all --check
  "$@" cargo clippy --workspace --all-targets --locked -q -- -D warnings
  local log
  log=$(mktemp)
  if ! "$@" cargo test --workspace --locked >"$log" 2>&1; then
    grep -E "^test .* FAILED|panicked|^error" "$log" | head -40 || true
    echo "$label : $(summarize <"$log")"
    rm -f "$log"
    return 1
  fi
  echo "$label : $(summarize <"$log")"
  rm -f "$log"
}

case "$(uname -s)" in
  MINGW* | MSYS* | CYGWIN*) platform=windows ;;
  *) platform=linux ;;
esac

run_checks "$platform"

if [[ $platform == windows && $host_only == false ]]; then
  if ! command -v wsl.exe >/dev/null; then
    echo "wsl : absent, étape sautée"
    exit 0
  fi
  # Le dossier cible reste dans WSL : les I/O sur /mnt/c sont lentes.
  # `--cd` accepte le chemin Windows. `--exec` passe les arguments tels quels,
  # sans le shell par défaut ; `bash -l` charge le PATH de rustup, et la
  # commande arrive dans "$0" "$@".
  run_checks wsl wsl.exe --cd "$(pwd -W)" --exec bash -lc \
    'CARGO_TARGET_DIR="$HOME/.cache/{{projet}}-target" exec "$0" "$@"'
fi
