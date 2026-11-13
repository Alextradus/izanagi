#!/usr/bin/env bash
# Affiche le niveau de risque retenu pour le diff entre un point fixe et HEAD.
#
#   risk.sh <point fixe> [faible|normal|eleve]     niveau déclaré, normal par défaut
#
# Le niveau retenu est le niveau déclaré, sauf si le diff touche un chemin sensible :
# il vaut alors `eleve`. Les chemins sensibles sont la clé `chemins_sensibles` de
# .izanagi/config.env, une liste de motifs séparés par des virgules. Un motif se
# compare au chemin entier, et `*` couvre aussi `/`.
#
# Sortie standard : le niveau retenu. Sortie d'erreur : une ligne par fichier sensible.
# Codes : 0 réussi, 2 appel refusé.
set -euo pipefail

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

refuse() {
  echo "$*" >&2
  exit 2
}

[[ $# -ge 1 && $# -le 2 ]] || refuse "usage : risk.sh <point fixe> [faible|normal|eleve]"
point=$1
niveau="${2:-normal}"
[[ $niveau == faible || $niveau == normal || $niveau == eleve ]] || refuse "risk.sh : niveau refusé : $niveau"

racine="$(izanagi_root)" || refuse "risk.sh : pas un projet Izanagi"
git -C "$racine" rev-parse --verify --quiet "$point^{commit}" >/dev/null ||
  refuse "risk.sh : point fixe introuvable : $point"

# Découpe la clé aux virgules et retire les espaces autour de chaque motif.
motifs=()
valeur="$(kv_get "$racine/.izanagi/config.env" chemins_sensibles || true)"
while [[ -n $valeur ]]; do
  motif="${valeur%%,*}"
  if [[ $valeur == *,* ]]; then valeur="${valeur#*,}"; else valeur=""; fi
  motif="${motif#"${motif%%[![:space:]]*}"}"
  motif="${motif%"${motif##*[![:space:]]}"}"
  if [[ -n $motif ]]; then motifs+=("$motif"); fi
done

if [[ ${#motifs[@]} -gt 0 ]]; then
  while IFS= read -r -d '' chemin; do
    for motif in "${motifs[@]}"; do
      # Sans guillemets autour de $motif : il se lit comme un motif, pas comme un texte.
      # shellcheck disable=SC2053
      if [[ $chemin == $motif ]]; then
        echo "risk.sh : chemin sensible : $chemin" >&2
        niveau=eleve
        break
      fi
    done
  done < <(git -C "$racine" diff --name-only -z "$point...HEAD")
fi

echo "$niveau"
