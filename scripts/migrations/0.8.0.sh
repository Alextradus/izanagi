#!/usr/bin/env bash
# Migre un projet posé en 0.7 vers la 0.8 (décision 137).
#
#   0.8.0.sh <projet>
#
# - .izanagi/config.env : ajoute `langue_publique=fr` s'il manque, après
#   `mutation_delai=` comme dans le gabarit. Ajoute `version_composant` s'il
#   manque, et lui donne le premier composant de harness.md s'il est vide (vide
#   sans composant). Met `izanagi_version` à 0.8.0.
# - docs/agents/harness.md : ajoute la ligne `- **Déploiement** : à préciser.`
#   sous la ligne « Test manuel » si elle manque, quel que soit le type. Pour un
#   type api ou web-frontend, affiche ensuite une ligne `à préciser`.
#
# Les autres fichiers de la 0.8 (release.yml, deploiement.yml, notes-de-version.sh,
# le template de PR) manquent au projet, et ci.yml, securite.yml et dependabot.yml
# diffèrent du gabarit : la pose d'upgrade les crée ou montre leur écart.
# CHANGELOG.md naît à la première release.
#
# Affiche une ligne par fichier écrit. Relancé sur un projet migré, affiche
# `déjà migré`. Ne commite rien.
set -euo pipefail

# shellcheck source=../lib.sh
. "$(dirname "$0")/../lib.sh"

if [[ $# -ne 1 ]]; then
  echo "usage : 0.8.0.sh <projet>" >&2
  exit 2
fi
cible="$(cd "$1" && pwd)"
config="$cible/.izanagi/config.env"
if [[ ! -f $config ]]; then
  echo "0.8.0.sh : .izanagi/config.env absent : lance d'abord la migration 0.4.0" >&2
  exit 2
fi
harness="$cible/docs/agents/harness.md"

# Premier composant de harness.md : `- composant : <nom> | …`. Vide sans composant.
premier=""
if [[ -f $harness ]]; then
  premier="$(tr -d '\r' <"$harness" | sed -n 's/^- composant : \([^|]*\)|.*/\1/p' | head -1 | tr -d ' ')"
fi

version="$(kv_get "$config" izanagi_version || true)"
monte=0
if [[ -z $version ]] || version_lt "$version" 0.8.0; then monte=1; fi
a_langue=0 a_vc=0
grep -q '^langue_publique=' "$config" && a_langue=1
grep -q '^version_composant=' "$config" && a_vc=1
vc="$(kv_get "$config" version_composant || true)"
remplir_vc=0
[[ -z $vc && -n $premier ]] && remplir_vc=1
config_a_faire=0
[[ $monte -eq 1 || $a_langue -eq 0 || $a_vc -eq 0 || $remplir_vc -eq 1 ]] && config_a_faire=1
harness_a_faire=0
[[ -f $harness ]] && ! grep -q '^- \*\*Déploiement\*\* : ' "$harness" && harness_a_faire=1

if [[ $config_a_faire -eq 0 && $harness_a_faire -eq 0 ]]; then
  echo "déjà migré"
  exit 0
fi

# --- config.env ---
if [[ $config_a_faire -eq 1 ]]; then
  tmp="$(mktemp "$cible/.izanagi/config.XXXXXX")"
  vu_version=0
  # Ordre du gabarit : langue_publique suit mutation_delai, version_composant suit
  # langue_publique.
  while IFS= read -r ligne || [[ -n $ligne ]]; do
    ligne="${ligne%$'\r'}"
    cle="${ligne%%=*}"
    if [[ $monte -eq 1 && $cle == izanagi_version && $ligne == *=* ]]; then
      ligne="izanagi_version=0.8.0"
      vu_version=1
    fi
    if [[ $remplir_vc -eq 1 && $ligne == version_composant=* ]]; then ligne="version_composant=$premier"; fi
    printf '%s\n' "$ligne"
    if [[ $ligne == mutation_delai=* && $a_langue -eq 0 ]]; then
      printf 'langue_publique=fr\n'
      a_langue=1
      ligne="langue_publique=fr"
    fi
    if [[ $ligne == langue_publique=* && $a_vc -eq 0 ]]; then
      printf 'version_composant=%s\n' "$premier"
      a_vc=1
    fi
  done <"$config" >"$tmp"
  # Un config.env sans ces lignes reçoit les clés à la fin.
  [[ $a_langue -eq 1 ]] || printf 'langue_publique=fr\n' >>"$tmp"
  [[ $a_vc -eq 1 ]] || printf 'version_composant=%s\n' "$premier" >>"$tmp"
  if [[ $monte -eq 1 && $vu_version -eq 0 ]]; then printf 'izanagi_version=0.8.0\n' >>"$tmp"; fi
  mv "$tmp" "$config"
  echo "écrit      .izanagi/config.env"
fi

[[ $harness_a_faire -eq 1 ]] || exit 0

# --- harness.md ---
# La ligne va sous « Test manuel », sinon sous « Type », sinon à la fin.
deploiement='- **Déploiement** : à préciser.'
tmp="$(mktemp "$cible/.izanagi/harness.XXXXXX")"
contenu="$(tr -d '\r' <"$harness")"
if grep -q '^- \*\*Test manuel\*\* : ' <<<"$contenu"; then
  repere='- **Test manuel** : '
elif grep -q '^- \*\*Type\*\* : ' <<<"$contenu"; then
  repere='- **Type** : '
else
  repere=""
fi
if [[ -n $repere ]]; then
  awk -v repere="$repere" -v ligne="$deploiement" '
    { print }
    !fait && index($0, repere) == 1 { print ligne; fait = 1 }' <<<"$contenu" >"$tmp"
else
  printf '%s\n%s\n' "$contenu" "$deploiement" >"$tmp"
fi
mv "$tmp" "$harness"
echo "écrit      docs/agents/harness.md"

type="$(sed -n 's/^- \*\*Type\*\* : \(.*\)\.$/\1/p' <<<"$contenu" | head -1)"
if [[ $type == api || $type == web-frontend ]]; then
  echo "à préciser  déploiement : écris la commande dans docs/agents/harness.md, puis relance /izanagi:upgrade"
fi
