#!/usr/bin/env bash
# Liste les flux ouverts du projet courant, d'après ses branches.
#
#   status.sh
#
# Une ligne par branche locale ou distante nommée jalon/*, task/* ou fix/*, avec
# l'état lu dans le .izanagi/state.env de cette branche. Une branche de tranche
# (jalon/x-t1) est en retrait sous son jalon. `*` marque la branche courante.
# Sans branche de flux, affiche `aucun flux ouvert`.
set -euo pipefail

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

racine="$(izanagi_root)" || {
  echo "status.sh : pas un projet Izanagi" >&2
  exit 2
}
courante="$(git -C "$racine" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

# Branche vers la référence à lire. Une branche locale l'emporte sur sa copie distante.
declare -A refs=()
while IFS= read -r ref; do
  case "$ref" in
    refs/heads/*) nom="${ref#refs/heads/}" ;;
    refs/remotes/*/*)
      nom="${ref#refs/remotes/}"
      nom="${nom#*/}"
      ;;
    *) continue ;;
  esac
  [[ $nom == jalon/* || $nom == task/* || $nom == fix/* ]] || continue
  if [[ $ref == refs/heads/* || -z ${refs[$nom]:-} ]]; then refs[$nom]="$ref"; fi
done < <(git -C "$racine" for-each-ref --format='%(refname)' refs/heads refs/remotes)

if [[ ${#refs[@]} -eq 0 ]]; then
  echo "aucun flux ouvert"
  exit 0
fi

re_tranche='^(jalon/.+)-t[0-9]+$'
while IFS= read -r nom; do
  marque="  "
  [[ $nom == "$courante" ]] && marque="* "
  retrait=""
  if [[ $nom =~ $re_tranche && -n ${refs[${BASH_REMATCH[1]}]:-} ]]; then retrait="  "; fi
  if git -C "$racine" show "${refs[$nom]}:.izanagi/state.env" >"$tmp" 2>/dev/null && flux="$(kv_get "$tmp" flux)"; then
    ligne="$flux « $(kv_get "$tmp" nom || true) », phase $(kv_get "$tmp" phase || true)"
    if tranche="$(kv_get "$tmp" tranche)"; then ligne+=", tranche $tranche"; fi
    if tour="$(kv_get "$tmp" tour)"; then ligne+=", tour $tour"; fi
    if maj="$(kv_get "$tmp" maj)"; then ligne+="  (${maj%%T*})"; fi
  else
    ligne="sans état"
  fi
  echo "$marque$retrait$nom  $ligne"
done < <(printf '%s\n' "${!refs[@]}" | sort)
