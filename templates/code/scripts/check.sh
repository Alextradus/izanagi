#!/usr/bin/env bash
# Vérifications du dépôt, celles de la CI : une section par composant.
#
#   scripts/check.sh            machine courante
#   scripts/check.sh --host     machine courante seulement (hook pre-push)
#   scripts/check.sh --clean    vide les caches de vérification
#
# Sort en erreur au premier échec.
set -euo pipefail

cd "$(dirname "$0")/.."

case "${1:-}" in
  --host | "") ;;
  --clean) echo "rien à vider"; exit 0 ;;
  *) echo "usage : scripts/check.sh [--host|--clean]" >&2; exit 2 ;;
esac

case "$(uname -s)" in
  MINGW* | MSYS* | CYGWIN*) systeme=windows ;;
  Darwin*) systeme=macos ;;
  *) systeme=linux ;;
esac

{{sections}}

verifier_tout() {
{{appels}}
}

echo "== $systeme"
verifier_tout
echo "$systeme : tout passe"
