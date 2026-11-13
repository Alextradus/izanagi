#!/usr/bin/env bash
# Migre un projet posé avant la 0.4 vers la 0.4.
#
#   0.4.0.sh <projet>
#
# - Reprend les valeurs de docs/agents/jalon.md dans .izanagi/config.env, puis
#   supprime jalon.md si chacune de ses lignes de réglage a été reconnue.
# - Pose .izanagi/.gitignore.
# - Supprime .izanagi/journal/.gitignore, que la 0.3 créait : le journal est versionné.
# - Déplace un journal d'avant la 0.3 de .superpowers/sdd/<plan>/progress.md vers
#   .izanagi/journal/<plan>.md.
#
# Affiche une ligne par action. Relancé sur un projet migré, affiche `déjà migré`.
# Ne commite rien.
set -euo pipefail

# shellcheck source=../lib.sh
. "$(dirname "$0")/../lib.sh"

if [[ $# -ne 1 ]]; then
  echo "usage : 0.4.0.sh <projet>" >&2
  exit 2
fi
cible="$(cd "$1" && pwd)"
gabarits="$izanagi_lib_dir/../templates/core/.izanagi"
jalon="$cible/docs/agents/jalon.md"
config="$cible/.izanagi/config.env"

actions=0
dire() {
  echo "$*"
  actions=$((actions + 1))
}

# Supprime un fichier, par git s'il est suivi.
supprimer() {
  if git -C "$cible" ls-files --error-unmatch -- "$1" >/dev/null 2>&1; then
    git -C "$cible" rm -q -f -- "$1"
  else
    rm -f "$cible/$1"
  fi
}

# Formes des lignes de jalon.md, telles que les gabarits 0.1 à 0.3 les écrivent.
re_ligne='^- \*\*([^*]+)\*\* : (.*)$'
re_spec='^`([^`]*)`\. Elle fait foi\.$'
re_decisions='^(.*)\. Chaque [^ ]+ y est dat'
re_plans='^`([^`]*)`, un fichier par jalon\.$'
re_chemin='^`([^`]*)`\.$'
re_verification='^`([^`]*)`\. Sa sortie'
re_test='avec `([^`]*)`, (.*)\.$'
re_taille='^un diff sous (.*) lignes, hors tests'
re_phrase='^(.*)\.$'

if [[ ! -f $config && -f $jalon ]]; then
  declare -A v=()
  non_reconnus=0
  while IFS= read -r ligne || [[ -n $ligne ]]; do
    ligne="${ligne%$'\r'}"
    [[ $ligne =~ $re_ligne ]] || continue
    libelle="${BASH_REMATCH[1]}"
    reste="${BASH_REMATCH[2]}"
    reconnu=1
    case "$libelle" in
      Spec) if [[ $reste =~ $re_spec ]]; then v[spec]="${BASH_REMATCH[1]}"; else reconnu=0; fi ;;
      Décisions) if [[ $reste =~ $re_decisions ]]; then v[decisions]="${BASH_REMATCH[1]}"; else reconnu=0; fi ;;
      Plans) if [[ $reste =~ $re_plans ]]; then v[plans]="${BASH_REMATCH[1]}"; else reconnu=0; fi ;;
      "Branche principale") if [[ $reste =~ $re_chemin ]]; then v[branche]="${BASH_REMATCH[1]}"; else reconnu=0; fi ;;
      Vérification) if [[ $reste =~ $re_verification ]]; then v[verification]="${BASH_REMATCH[1]}"; else reconnu=0; fi ;;
      "Test manuel")
        if [[ $reste =~ $re_test ]]; then
          v[test_manuel]="${BASH_REMATCH[1]}"
          v[lieu_test]="${BASH_REMATCH[2]}"
        else
          reconnu=0
        fi
        ;;
      "Taille d'une tranche") if [[ $reste =~ $re_taille ]]; then v[taille_tranche]="${BASH_REMATCH[1]}"; else reconnu=0; fi ;;
      Version) if [[ $reste =~ $re_phrase ]]; then v[fichier_version]="${BASH_REMATCH[1]}"; else reconnu=0; fi ;;
      Vault)
        if [[ $reste == "non." ]]; then
          v[vault]=non
        elif [[ $reste =~ $re_chemin ]]; then
          v[vault]="${BASH_REMATCH[1]}"
        else
          reconnu=0
        fi
        ;;
      *) reconnu=0 ;;
    esac
    if [[ $reconnu -eq 0 ]]; then
      echo "non reconnu : $ligne"
      non_reconnus=$((non_reconnus + 1))
    fi
  done <"$jalon"

  projet=""
  [[ -f $cible/CLAUDE.md ]] && projet="$(sed -n '1s/^# //p' "$cible/CLAUDE.md" | tr -d '\r')"
  v[projet]="${projet:-$(basename "$cible")}"
  v[izanagi_version]=0.4.0
  v[hook_push]=bloque
  v[hook_verification]=bloque
  # Clé de la 0.5, que le gabarit porte : vide, et pas « à compléter ».
  v[chemins_sensibles]=""

  # Le fichier suit le gabarit ligne à ligne, pour que la pose le trouve identique.
  mkdir -p "$cible/.izanagi"
  a_completer=()
  re_gabarit='^([a-z_]+)=\{\{[a-z_]+\}\}$'
  while IFS= read -r ligne || [[ -n $ligne ]]; do
    ligne="${ligne%$'\r'}"
    if [[ $ligne =~ $re_gabarit ]]; then
      cle="${BASH_REMATCH[1]}"
      [[ -n ${v[$cle]+x} ]] || a_completer+=("$cle")
      printf '%s=%s\n' "$cle" "${v[$cle]:-}"
    else
      printf '%s\n' "$ligne"
    fi
  done <"$gabarits/config.env" >"$config"
  dire "écrit      .izanagi/config.env"
  # Forme qui passe sous `set -u` avec un tableau vide, avant bash 4.4.
  for cle in ${a_completer[@]+"${a_completer[@]}"}; do
    echo "à compléter : $cle"
  done

  if [[ $non_reconnus -eq 0 ]]; then
    supprimer docs/agents/jalon.md
    dire "supprimé   docs/agents/jalon.md"
  fi
fi

if [[ -f $config && ! -f $cible/.izanagi/.gitignore ]]; then
  cp "$gabarits/.gitignore" "$cible/.izanagi/.gitignore"
  dire "écrit      .izanagi/.gitignore"
fi

if [[ -f $cible/.izanagi/journal/.gitignore ]]; then
  supprimer .izanagi/journal/.gitignore
  dire "supprimé   .izanagi/journal/.gitignore"
fi

for ancien in "$cible"/.superpowers/sdd/*/progress.md; do
  [[ -f $ancien ]] || continue
  plan="$(basename "$(dirname "$ancien")")"
  if [[ -e $cible/.izanagi/journal/$plan.md ]]; then
    echo "gardé      .superpowers/sdd/$plan/progress.md : .izanagi/journal/$plan.md existe déjà"
    continue
  fi
  mkdir -p "$cible/.izanagi/journal"
  mv "$ancien" "$cible/.izanagi/journal/$plan.md"
  dire "déplacé    .superpowers/sdd/$plan/progress.md vers .izanagi/journal/$plan.md"
done

[[ $actions -gt 0 ]] || echo "déjà migré"
