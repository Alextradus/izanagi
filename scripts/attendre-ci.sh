#!/usr/bin/env bash
# Attend la fin des checks d'une PR avant que le flux propose sa fusion.
#
#   attendre-ci.sh <pr> [--delai <minutes>]
#
# Juste après un push, GitHub n'a pas encore enregistré les checks du nouveau commit,
# et `gh pr checks` répond « no checks reported ». Le script attend donc qu'ils
# apparaissent, puis qu'aucun ne soit en cours, et relit la liste une dernière fois :
# un workflow enregistré plus tard ne passe pas inaperçu.
#
# Affiche une ligne `<résultat>  <check>` par check, puis le verdict. Codes :
#   0  tous les checks passent (ou sont sautés)
#   1  au moins un check échoue ou est annulé
#   2  appel refusé, ou `gh` en erreur
#   3  aucun check n'apparaît : le dépôt n'a pas de CI, ou elle ne s'est pas lancée
#   4  délai dépassé, des checks tournent encore
#
# `--delai` borne l'attente totale, 30 minutes par défaut. IZANAGI_CI_PAUSE (secondes
# entre deux lectures, 15 par défaut) et IZANAGI_CI_APPARITION (secondes laissées aux
# checks pour apparaître, 180 par défaut) servent aux tests.
set -euo pipefail

refuse() {
  echo "$*" >&2
  exit 2
}

[[ $# -eq 1 || ($# -eq 3 && $2 == --delai) ]] || refuse "usage : attendre-ci.sh <pr> [--delai <minutes>]"
pr=$1
delai_min=${3:-30}
[[ $delai_min =~ ^[0-9]+$ ]] || refuse "attendre-ci.sh : délai invalide : $delai_min"
pause=${IZANAGI_CI_PAUSE:-15}
apparition=${IZANAGI_CI_APPARITION:-180}
delai=$((delai_min * 60))

# lire : remplit $checks (lignes `<bucket>\t<nom>`). Rend 0 avec des checks, 1 sans
# aucun check ; sort en 2 sur une autre erreur de gh.
checks=""
lire() {
  local sortie code=0
  sortie="$(gh pr checks "$pr" --json bucket,name --jq '.[] | "\(.bucket)\t\(.name)"' 2>&1)" || code=$?
  # gh rend 1 quand un check échoue et 8 quand un check tourne : la liste reste valable.
  checks="$(grep -E $'^(pass|fail|pending|skipping|cancel)\t' <<<"$sortie" || true)"
  [[ -n $checks ]] && return 0
  if [[ $code -eq 0 || $sortie == *"no checks reported"* ]]; then
    return 1
  fi
  echo "attendre-ci.sh : gh pr checks a échoué ($code) : $sortie" >&2
  exit 2
}

afficher() {
  local bucket nom
  while IFS=$'\t' read -r bucket nom; do
    printf '%-8s  %s\n' "$bucket" "$nom"
  done <<<"$checks"
}

en_cours() { grep -q $'^pending\t' <<<"$checks"; }
en_echec() { grep -qE $'^(fail|cancel)\t' <<<"$checks"; }

debut=$SECONDS
# 1. Les checks du commit poussé apparaissent.
until lire; do
  if ((SECONDS - debut >= apparition)); then
    echo "ci : aucun check après $apparition s sur la PR $pr"
    exit 3
  fi
  sleep "$pause"
done

# 2. Plus aucun check en cours, puis une relecture qui confirme la liste.
confirme=0
while :; do
  if en_echec; then
    afficher
    echo "ci : rouge"
    exit 1
  fi
  if [[ -z $checks ]] || en_cours; then
    confirme=0
  elif ((confirme)); then
    afficher
    echo "ci : verte"
    exit 0
  else
    confirme=1
  fi
  if ((SECONDS - debut >= delai)); then
    afficher
    echo "ci : délai de $delai_min min dépassé, des checks tournent encore"
    exit 4
  fi
  sleep "$pause"
  lire || true
done
