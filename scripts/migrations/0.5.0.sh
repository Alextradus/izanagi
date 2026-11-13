#!/usr/bin/env bash
# Migre un projet posé en 0.4 vers la 0.5.
#
#   0.5.0.sh <projet>
#
# - Ajoute la clé `chemins_sensibles`, vide, à .izanagi/config.env, après la ligne
#   `taille_tranche=`, comme dans le gabarit.
# - Met `izanagi_version` à 0.5.0.
#
# Affiche une ligne par fichier écrit. Relancé sur un projet migré, affiche
# `déjà migré`. Ne commite rien.
set -euo pipefail

# shellcheck source=../lib.sh
. "$(dirname "$0")/../lib.sh"

if [[ $# -ne 1 ]]; then
  echo "usage : 0.5.0.sh <projet>" >&2
  exit 2
fi
cible="$(cd "$1" && pwd)"
config="$cible/.izanagi/config.env"
if [[ ! -f $config ]]; then
  echo "0.5.0.sh : .izanagi/config.env absent : lance d'abord la migration 0.4.0" >&2
  exit 2
fi

version="$(kv_get "$config" izanagi_version || true)"
a_la_cle=0
grep -q '^chemins_sensibles=' "$config" && a_la_cle=1
monte=0
if [[ -z $version ]] || version_lt "$version" 0.5.0; then monte=1; fi

if [[ $a_la_cle -eq 1 && $monte -eq 0 ]]; then
  echo "déjà migré"
  exit 0
fi

tmp="$(mktemp "$cible/.izanagi/config.XXXXXX")"
pose=$a_la_cle
vu_version=0
while IFS= read -r ligne || [[ -n $ligne ]]; do
  ligne="${ligne%$'\r'}"
  if [[ $monte -eq 1 && $ligne == izanagi_version=* ]]; then
    ligne="izanagi_version=0.5.0"
    vu_version=1
  fi
  printf '%s\n' "$ligne"
  if [[ $pose -eq 0 && $ligne == taille_tranche=* ]]; then
    printf 'chemins_sensibles=\n'
    pose=1
  fi
done <"$config" >"$tmp"
# Un config.env sans ligne `taille_tranche=` ou `izanagi_version=` reçoit la clé à la fin.
if [[ $pose -eq 0 ]]; then printf 'chemins_sensibles=\n' >>"$tmp"; fi
if [[ $monte -eq 1 && $vu_version -eq 0 ]]; then printf 'izanagi_version=0.5.0\n' >>"$tmp"; fi
mv "$tmp" "$config"
echo "écrit      .izanagi/config.env"
