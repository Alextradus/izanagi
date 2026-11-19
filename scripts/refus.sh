#!/usr/bin/env bash
# Liste ou vide les lignes de .izanagi/refus.log d'une branche. Les hooks y écrivent
# une ligne `<date>|<branche>|<hook>|<motif>` par refus, avertissement ou demande ;
# la rétrospective et la clôture de `task` et `fix` les lisent.
#
#   refus.sh <branche>            affiche les lignes de cette branche
#   refus.sh <branche> --vider    les retire du fichier
#
# Sans refus.log, n'affiche rien. Codes : 0 réussi, 2 appel refusé ou hors d'un
# projet Izanagi.
set -euo pipefail

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

refuse() {
  echo "$*" >&2
  exit 2
}

[[ $# -eq 1 || ($# -eq 2 && $2 == --vider) ]] || refuse "usage : refus.sh <branche> [--vider]"
# Le hook note un `|` du nom de branche comme une espace : même conversion ici.
branche="${1//|/ }"
racine="$(izanagi_root)" || refuse "refus.sh : pas un projet Izanagi"
journal="$racine/.izanagi/refus.log"
[[ -f $journal ]] || exit 0

if [[ ${2:-} == --vider ]]; then
  tmp="$(mktemp "$racine/.izanagi/refus.XXXXXX")"
  awk -F'|' -v b="$branche" '$2 != b' "$journal" >"$tmp"
  mv "$tmp" "$journal"
else
  awk -F'|' -v b="$branche" '$2 == b' "$journal"
fi
