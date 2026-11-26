#!/usr/bin/env bash
# Résume l'historique git d'un flux pour la rétrospective : ce que le journal ne dit pas.
#
#   historique.sh <branche> [<base>]
#
# Compte les commits de <branche> absents de <base>, commits de fusion exclus, par
# type de leur titre (`feat`, `fix`, `docs`…). Les commits de suivi d'Izanagi
# (`chore(izanagi): …`, journal et état) ont leur ligne à part. <base> vaut par défaut
# la clé `branche` de .izanagi/config.env, prise en local ou, à défaut, sur `origin`.
#
# Sortie :
#   commits : <n>
#   <type> : <k> (<p> %)      une ligne par type, du plus fréquent au moins fréquent
#
# Un titre qui ne suit pas `type(portée): …` compte sous `autre`. Codes : 0 réussi,
# 2 appel refusé, hors d'un projet Izanagi, ou branche introuvable.
set -euo pipefail

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

refuse() {
  echo "$*" >&2
  exit 2
}

[[ $# -eq 1 || $# -eq 2 ]] || refuse "usage : historique.sh <branche> [<base>]"
racine="$(izanagi_root)" || refuse "historique.sh : pas un projet Izanagi"
branche=$1
base=${2:-$(kv_get "$racine/.izanagi/config.env" branche || echo main)}

# ref <nom> : la branche locale, sinon sa copie sur origin.
ref() {
  if git -C "$racine" rev-parse -q --verify "$1^{commit}" >/dev/null; then
    echo "$1"
  elif git -C "$racine" rev-parse -q --verify "origin/$1^{commit}" >/dev/null; then
    echo "origin/$1"
  else
    refuse "historique.sh : branche introuvable : $1"
  fi
}
b="$(ref "$branche")"
p="$(ref "$base")"

git -C "$racine" log --no-merges --format=%s "$p..$b" | awk '
  {
    t = "autre"
    if (match($0, /^[a-z]+(\([^)]*\))?!?:/)) {
      t = substr($0, 1, RLENGTH)
      sub(/!?:$/, "", t)
      # La portée ne compte que pour les commits de suivi d Izanagi.
      if (t != "chore(izanagi)") sub(/\(.*$/, "", t)
    }
    n[t]++
    total++
  }
  END {
    print "commits : " total + 0
    for (t in n) printf "%d\t%s : %d (%d %%)\n", n[t], t, n[t], int(n[t] * 100 / total + 0.5)
  }
' | {
  IFS= read -r premiere
  echo "$premiere"
  sort -t$'\t' -k1,1nr -k2,2 | cut -f2-
}
