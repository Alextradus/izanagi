#!/usr/bin/env bash
# Notes d'une version : écrit sur la sortie standard la section `## [X.Y.Z]` de
# CHANGELOG.md, sans sa ligne de titre, jusqu'au titre `## ` suivant ou à la fin
# du fichier. La CI de release s'en sert pour le corps de la release.
#
#   scripts/notes-de-version.sh <X.Y.Z>
#
# Sort avec 1 si CHANGELOG.md manque ou n'a pas de section (ou une section vide)
# pour cette version, avec 2 si l'argument n'est pas de la forme X.Y.Z.
set -euo pipefail

cd "$(dirname "$0")/.."

usage() {
  echo "usage : scripts/notes-de-version.sh <X.Y.Z>" >&2
  exit 2
}

[[ $# -eq 1 && $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || usage
version="$1"

if [[ ! -f CHANGELOG.md ]]; then
  echo "notes-de-version.sh : CHANGELOG.md absent" >&2
  exit 1
fi

# Retire le retour chariot d'un fichier CRLF, repère le titre de la version
# (comparaison de texte, les points ne sont pas des jointures), garde les lignes
# jusqu'au titre suivant, puis retire les lignes vides du début et de la fin.
notes="$(awk -v titre="## [$version]" '
  { sub(/\r$/, "") }
  /^## / {
    if (dedans) exit
    if (index($0, titre) == 1) { dedans = 1; next }
  }
  dedans {
    if ($0 ~ /^[[:space:]]*$/) { vides++; next }
    if (vu) { for (; vides > 0; vides--) print "" }
    vides = 0
    vu = 1
    print
  }
' CHANGELOG.md)"

if [[ -z $notes ]]; then
  echo "notes-de-version.sh : CHANGELOG.md n'a pas de section [$version]" >&2
  exit 1
fi
printf '%s\n' "$notes"
