#!/usr/bin/env bash
# Lit, écrit et supprime l'état du flux de la branche courante, .izanagi/state.env.
# Ce script est le seul à écrire ce fichier.
#
#   state.sh start <flux> <nom> [--commit]    flux : jalon, task ou fix
#   state.sh set <clé>=<valeur>… [--commit]   clés : phase, tranche, tour, plan,
#                                             risque, issue, correctif
#   state.sh get [clé]
#   state.sh clear [--commit]
#
# `--commit` commite le seul fichier d'état après l'écriture.
# Codes : 0 réussi, 1 pas d'état ou clé absente (get), 2 appel ou valeur refusé.
set -euo pipefail

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

refuse() {
  echo "state.sh : $*" >&2
  exit 2
}

commit=0
args=()
for a in "$@"; do
  if [[ $a == --commit ]]; then commit=1; else args+=("$a"); fi
done
commande="${args[0]:-}"

racine="$(project_root)" || refuse "pas un projet Izanagi"
[[ -f $racine/.izanagi/config.env ]] || refuse "pas un projet Izanagi"
fichier="$racine/.izanagi/state.env"

cles=(flux nom phase tranche tour plan risque issue correctif maj)
declare -A etat=()

charger() {
  local c v
  for c in "${cles[@]}"; do
    if v="$(kv_get "$fichier" "$c")"; then etat[$c]="$v"; fi
  done
}

# Écrit l'état par un fichier temporaire du même dossier, puis le renomme.
# Si rien ne change hors de la date `maj`, le fichier reste tel quel : une écriture
# sans changement ne donne pas de commit.
ecrire() {
  local c tmp contenu=""
  for c in "${cles[@]}"; do
    [[ $c == maj ]] && continue
    [[ -n ${etat[$c]:-} ]] && contenu+="$c=${etat[$c]}"$'\n'
  done
  if [[ -f $fichier && $(grep -v '^maj=' "$fichier") == "${contenu%$'\n'}" ]]; then
    return 0
  fi
  tmp="$(mktemp "$racine/.izanagi/state.XXXXXX")"
  printf '%smaj=%s\n' "$contenu" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$tmp"
  mv "$tmp" "$fichier"
}

# commiter <fin du message> : commite le seul fichier d'état, s'il a changé.
commiter() {
  [[ $commit -eq 1 ]] || return 0
  git -C "$racine" add -A -- .izanagi/state.env 2>/dev/null || true
  git -C "$racine" diff --cached --quiet -- .izanagi/state.env && return 0
  git -C "$racine" commit -q -m "chore(izanagi): état $1" -- .izanagi/state.env
}

case "$commande" in
  start)
    [[ ${#args[@]} -eq 3 ]] || refuse "usage : state.sh start <flux> <nom>"
    flux="${args[1]}"
    nom="${args[2]}"
    [[ $flux == jalon || $flux == task || $flux == fix ]] || refuse "flux refusé : $flux"
    [[ $nom =~ ^[a-z0-9][a-z0-9-]*$ ]] || refuse "nom refusé : $nom"
    [[ ! -e $fichier ]] || refuse "un flux est déjà en cours sur cette branche"
    etat[flux]="$flux"
    etat[nom]="$nom"
    case "$flux" in
      jalon) etat[phase]=cadrage ;;
      fix) etat[phase]=diagnostic ;;
      *) etat[phase]=debut ;;
    esac
    ecrire
    commiter "$flux $nom, ${etat[phase]}"
    ;;
  set)
    [[ -f $fichier ]] || refuse "aucun flux en cours sur cette branche"
    [[ ${#args[@]} -ge 2 ]] || refuse "usage : state.sh set <clé>=<valeur>…"
    charger
    for paire in "${args[@]:1}"; do
      [[ $paire == *=* ]] || refuse "paire refusée : $paire"
      cle="${paire%%=*}"
      valeur="${paire#*=}"
      case "$cle" in
        phase)
          [[ $valeur =~ ^(cadrage|plan|tranches|revue|test|cloture|debut|diagnostic|travail)$ ]] || refuse "phase refusée : $valeur"
          ;;
        tranche | tour | issue)
          [[ $valeur =~ ^[0-9]+$ ]] || refuse "$cle refusé : $valeur"
          ;;
        risque)
          [[ $valeur =~ ^(faible|normal|eleve)$ ]] || refuse "risque refusé : $valeur"
          ;;
        correctif)
          # Une valeur vide retire la clé : le correctif d'un jalon est fini.
          [[ -z $valeur || $valeur =~ ^[a-z0-9][a-z0-9-]*$ ]] || refuse "correctif refusé : $valeur"
          ;;
        plan)
          [[ -n $valeur && $valeur != *$'\n'* ]] || refuse "plan refusé"
          ;;
        *) refuse "clé refusée : $cle" ;;
      esac
      etat[$cle]="$valeur"
    done
    ecrire
    commiter "${etat[flux]:-} ${etat[nom]:-}, ${etat[phase]:-}"
    ;;
  get)
    [[ -f $fichier ]] || exit 1
    if [[ ${#args[@]} -ge 2 ]]; then
      kv_get "$fichier" "${args[1]}"
    else
      cat "$fichier"
    fi
    ;;
  clear)
    [[ -f $fichier ]] || exit 0
    charger
    rm -f "$fichier"
    commiter "${etat[flux]:-} ${etat[nom]:-}, fin"
    ;;
  *)
    refuse "usage : state.sh start|set|get|clear"
    ;;
esac
