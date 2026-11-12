# shellcheck shell=bash
# Fonctions communes aux scripts et aux hooks d'Izanagi. À charger, pas à lancer :
#
#   . "$(dirname "$0")/lib.sh"
#
# Les fichiers lus portent une valeur par ligne (`clé=valeur`). Ils ne se chargent
# jamais avec `source` : une valeur peut contenir des espaces et des accents graves.

izanagi_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Affiche la racine git du dossier courant. Rend 1 hors d'un dépôt.
project_root() {
  git rev-parse --show-toplevel 2>/dev/null
}

# kv_get <fichier> <clé> : affiche la valeur de la dernière ligne `clé=…`, tout ce
# qui suit le premier `=`. Rend 1, sans rien afficher, si la clé ou le fichier manque.
kv_get() {
  local fichier=$1 cle=$2 ligne valeur trouve=1
  [[ -f $fichier ]] || return 1
  while IFS= read -r ligne || [[ -n $ligne ]]; do
    ligne="${ligne%$'\r'}"
    [[ -z $ligne || $ligne == \#* ]] && continue
    if [[ $ligne == "$cle="* ]]; then
      valeur="${ligne#*=}"
      trouve=0
    fi
  done <"$fichier"
  [[ $trouve -eq 0 ]] || return 1
  printf '%s\n' "$valeur"
}

# config_get <clé> et state_get <clé> : kv_get sur les fichiers du projet courant.
config_get() {
  local racine
  racine="$(project_root)" || return 1
  kv_get "$racine/.izanagi/config.env" "$1"
}

state_get() {
  local racine
  racine="$(project_root)" || return 1
  kv_get "$racine/.izanagi/state.env" "$1"
}

# Affiche la version du plugin, lue dans son plugin.json.
plugin_version() {
  sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
    "$izanagi_lib_dir/../.claude-plugin/plugin.json" | head -1
}

# version_lt <a> <b> : rend 0 si la version a précède la version b.
version_lt() {
  local a1 a2 a3 b1 b2 b3
  IFS=. read -r a1 a2 a3 <<<"$1"
  IFS=. read -r b1 b2 b3 <<<"$2"
  ((${a1:-0} != ${b1:-0})) && { ((${a1:-0} < ${b1:-0})); return; }
  ((${a2:-0} != ${b2:-0})) && { ((${a2:-0} < ${b2:-0})); return; }
  ((${a3:-0} < ${b3:-0}))
}
