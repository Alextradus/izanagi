#!/usr/bin/env bash
# Lance ensemble les composants du projet. Ctrl+C les arrête tous.
set -euo pipefail

cd "$(dirname "$0")/.."

pids=()

arreter() {
  local pid winpid
  for pid in "${pids[@]}"; do
    # Sous Git Bash, `kill` n'atteint pas les processus Windows natifs (npm,
    # node.exe) : taskkill arrête l'arbre entier à partir du PID Windows.
    case "$(uname -s)" in
      MINGW* | MSYS* | CYGWIN*)
        winpid="$(cat "/proc/$pid/winpid" 2>/dev/null || true)"
        [[ -n $winpid ]] && taskkill //T //F //PID "$winpid" >/dev/null 2>&1 || true
        ;;
    esac
    kill "$pid" 2>/dev/null || true
  done
}
trap arreter EXIT

{{lancements}}

if [[ ${#pids[@]} -eq 0 ]]; then
  echo "dev.sh : aucun composant à lancer" >&2
  exit 1
fi

wait
