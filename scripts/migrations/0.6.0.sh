#!/usr/bin/env bash
# Migre un projet posé en 0.5 vers la 0.6.
#
#   0.6.0.sh <projet>
#
# - Ajoute `hook_destructif=demande` à .izanagi/config.env, après la ligne
#   `hook_verification=`, comme dans le gabarit, et met `izanagi_version` à 0.6.0.
# - Ajoute `refus.log` à .izanagi/.gitignore.
# - Pose .claude/settings.json avec les règles `permissions.deny` du gabarit s'il
#   manque. S'il existe sans toutes ces règles, ne l'écrit pas et affiche
#   `à fusionner .claude/settings.json` : /izanagi:upgrade ajoute les règles sans
#   toucher aux autres réglages.
#
# Les autres fichiers de la 0.6 (.gitleaks.toml, dependabot.yml, securite.yml,
# docs/standards/) manquent au projet : la pose d'upgrade les crée.
#
# Affiche une ligne par fichier. Relancé sur un projet migré, affiche `déjà migré`.
# Ne commite rien.
set -euo pipefail

# shellcheck source=../lib.sh
. "$(dirname "$0")/../lib.sh"

if [[ $# -ne 1 ]]; then
  echo "usage : 0.6.0.sh <projet>" >&2
  exit 2
fi
cible="$(cd "$1" && pwd)"
config="$cible/.izanagi/config.env"
if [[ ! -f $config ]]; then
  echo "0.6.0.sh : .izanagi/config.env absent : lance d'abord la migration 0.4.0" >&2
  exit 2
fi
ignore="$cible/.izanagi/.gitignore"
reglages="$cible/.claude/settings.json"

version="$(kv_get "$config" izanagi_version || true)"
monte=0
if [[ -z $version ]] || version_lt "$version" 0.6.0; then monte=1; fi
a_la_cle=0
grep -q '^hook_destructif=' "$config" && a_la_cle=1
ignore_ok=0
grep -qx 'refus.log' "$ignore" 2>/dev/null && ignore_ok=1
regles_ok=0
[[ -f $reglages && -z $(regles_deny_absentes "$reglages") ]] && regles_ok=1

if [[ $monte -eq 0 && $a_la_cle -eq 1 && $ignore_ok -eq 1 && $regles_ok -eq 1 ]]; then
  echo "déjà migré"
  exit 0
fi

if [[ $monte -eq 1 || $a_la_cle -eq 0 ]]; then
  tmp="$(mktemp "$cible/.izanagi/config.XXXXXX")"
  pose=$a_la_cle
  vu_version=0
  while IFS= read -r ligne || [[ -n $ligne ]]; do
    ligne="${ligne%$'\r'}"
    if [[ $monte -eq 1 && $ligne == izanagi_version=* ]]; then
      ligne="izanagi_version=0.6.0"
      vu_version=1
    fi
    printf '%s\n' "$ligne"
    if [[ $pose -eq 0 && $ligne == hook_verification=* ]]; then
      printf 'hook_destructif=demande\n'
      pose=1
    fi
  done <"$config" >"$tmp"
  # Un config.env sans ligne `hook_verification=` ou `izanagi_version=` reçoit la clé à la fin.
  if [[ $pose -eq 0 ]]; then printf 'hook_destructif=demande\n' >>"$tmp"; fi
  if [[ $monte -eq 1 && $vu_version -eq 0 ]]; then printf 'izanagi_version=0.6.0\n' >>"$tmp"; fi
  mv "$tmp" "$config"
  echo "écrit      .izanagi/config.env"
fi

if [[ $ignore_ok -eq 0 ]]; then
  # Sans saut de ligne final, le motif se collerait à la dernière ligne.
  if [[ -s $ignore && -n $(tail -c 1 "$ignore") ]]; then printf '\n' >>"$ignore"; fi
  printf 'refus.log\n' >>"$ignore"
  echo "écrit      .izanagi/.gitignore"
fi

if [[ ! -f $reglages ]]; then
  mkdir -p "$cible/.claude"
  cp "$izanagi_lib_dir/../templates/core/.claude/settings.json" "$reglages"
  echo "créé       .claude/settings.json"
elif [[ $regles_ok -eq 0 ]]; then
  echo "à fusionner .claude/settings.json"
fi
