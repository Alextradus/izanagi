#!/usr/bin/env bash
# Pose les gabarits d'Izanagi dans un projet, sans rien écraser.
#
#   pose.sh <projet> <fichier-valeurs>
#
# Le fichier de valeurs porte une valeur par ligne (`clé=valeur`), dont
# `pile` (`rust`, ou `aucune` pour le seul cœur). Les valeurs se superposent
# dans cet ordre : templates/core/valeurs.defaut, templates/<pile>/valeurs.defaut,
# puis le fichier passé en argument.
#
# Pour chaque gabarit, une ligne :
#   créé       <chemin>   le fichier manquait, il est posé
#   identique  <chemin>   le fichier existe et vaut le gabarit
#   différent  <chemin>   le fichier existe et diffère ; le diff est dans le
#                         dossier de rapport affiché à la fin
# Sort en erreur, sans rien écrire, si un gabarit garde un `{{clé}}` sans valeur.
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage : pose.sh <projet> <fichier-valeurs>" >&2
  exit 2
fi

racine="$(cd "$(dirname "$0")/.." && pwd)"
cible="$(cd "$1" && pwd)"
rapport="$(mktemp -d)"
# Copie : le fichier est lu deux fois, et il peut être un tube.
valeurs_utilisateur="$rapport/valeurs"
cat "$2" >"$valeurs_utilisateur"

declare -A valeurs=()

lire_valeurs() {
  local ligne cle
  while IFS= read -r ligne || [[ -n $ligne ]]; do
    ligne="${ligne%$'\r'}"
    [[ -z $ligne || $ligne == \#* ]] && continue
    cle="${ligne%%=*}"
    if [[ ! $cle =~ ^[a-z_]+$ || $ligne != *=* ]]; then
      echo "pose.sh : ligne illisible dans $1 : $ligne" >&2
      exit 2
    fi
    valeurs[$cle]="${ligne#*=}"
  done <"$1"
}

lire_valeurs "$racine/templates/core/valeurs.defaut"
pile_demandee="$(grep -E '^pile=' "$valeurs_utilisateur" | tail -1 | cut -d= -f2- | tr -d '\r')"
pile="${pile_demandee:-aucune}"
if [[ $pile != aucune && ! -d $racine/templates/$pile ]]; then
  echo "pose.sh : pas de gabarit pour la pile « $pile »" >&2
  exit 2
fi
[[ -f $racine/templates/$pile/valeurs.defaut ]] && lire_valeurs "$racine/templates/$pile/valeurs.defaut"
lire_valeurs "$valeurs_utilisateur"

# La ligne de CLAUDE.md qui pointe vers le vault se déduit du chemin du vault.
if [[ ${valeurs[vault]:-non} == non ]]; then
  valeurs[ligne_vault]=""
else
  valeurs[ligne_vault]="- Vault Obsidian : \`${valeurs[vault]}\`, tenu à jour au fil de l'eau selon \`docs/agents/vault.md\`."
fi

# Dossiers de gabarits à poser, du plus général au plus particulier.
sources=("$racine/templates/core")
[[ $pile != aucune ]] && sources+=("$racine/templates/$pile")
[[ ${valeurs[vault]:-non} != non ]] && sources+=("$racine/templates/vault")

# Rend un gabarit sur la sortie standard. Une ligne réduite à un `{{clé}}` de
# valeur vide disparaît entièrement.
rendre() {
  local texte cle
  texte="$(cat "$1"; printf x)"
  texte="${texte%x}"
  for cle in "${!valeurs[@]}"; do
    if [[ -z ${valeurs[$cle]} ]]; then
      texte="${texte//"{{$cle}}"$'\n'/}"
    fi
    texte="${texte//"{{$cle}}"/"${valeurs[$cle]}"}"
  done
  printf '%s' "$texte"
}

declare -a fichiers=()
manque=false
for source in "${sources[@]}"; do
  while IFS= read -r -d '' f; do
    rel="${f#"$source"/}"
    [[ $rel == valeurs.defaut ]] && continue
    fichiers+=("$source|$rel")
    if restes="$(rendre "$f" | grep -oE '\{\{[a-z_]+\}\}' | sort -u)" && [[ -n $restes ]]; then
      echo "pose.sh : $rel attend une valeur pour : $(echo $restes)" >&2
      manque=true
    fi
  done < <(find "$source" -type f -print0 | sort -z)
done
$manque && exit 1

for entree in "${fichiers[@]}"; do
  source="${entree%%|*}"
  rel="${entree#*|}"
  dest="$cible/$rel"
  rendu="$rapport/rendu/$rel"
  mkdir -p "$(dirname "$rendu")"
  rendre "$source/$rel" >"$rendu"
  if [[ ! -e $dest ]]; then
    mkdir -p "$(dirname "$dest")"
    cp "$rendu" "$dest"
    case "$rel" in scripts/*.sh | .githooks/*) chmod +x "$dest" ;; esac
    echo "créé       $rel"
  elif diff -q --strip-trailing-cr "$dest" "$rendu" >/dev/null; then
    echo "identique  $rel"
  else
    mkdir -p "$(dirname "$rapport/diff/$rel")"
    diff -u --strip-trailing-cr --label "projet/$rel" --label "gabarit/$rel" \
      "$dest" "$rendu" >"$rapport/diff/$rel.diff" || true
    echo "différent  $rel"
  fi
done

echo "pile : $pile"
echo "rapport : $rapport"
