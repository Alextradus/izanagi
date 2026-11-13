#!/usr/bin/env bash
# Teste scripts/risk.sh : niveau retenu pour un diff, chemins sensibles, refus.
set -euo pipefail

racine="$(cd "$(dirname "$0")/.." && pwd)"
risk="$racine/scripts/risk.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echoue() { echo "ÉCHEC : $*" >&2; exit 1; }

[[ -f $risk ]] || echoue "scripts/risk.sh absent"

# lancer <arguments…> : remplit $sortie, $erreur et $code.
lancer() {
  code=0
  sortie="$(bash "$risk" "$@" 2>"$tmp/err")" || code=$?
  erreur="$(cat "$tmp/err")"
}

# attend <niveau> <arguments…> : risk.sh sort avec 0 et affiche ce niveau.
attend() {
  local niveau=$1
  shift
  lancer "$@"
  [[ $code -eq 0 && $sortie == "$niveau" ]] || echoue "risk.sh $* : code $code, sortie « $sortie », attendu « $niveau » ($erreur)"
}

regler() { # regler <valeur de chemins_sensibles>, ou rien pour retirer la clé
  sed -i '/^chemins_sensibles=/d' .izanagi/config.env
  if [[ $# -eq 1 ]]; then printf 'chemins_sensibles=%s\n' "$1" >>.izanagi/config.env; fi
}

projet="$tmp/p"
mkdir -p "$projet/.izanagi" "$projet/db/migrations" "$projet/src/auth/jetons" "$projet/mes docs"
cd "$projet"
git init -q -b main
git config user.email essai@example.invalid
git config user.name Essai
echo 'branche=main' >.izanagi/config.env
echo a >README.md
git add -A && git commit -q -m cadre
git switch -q -c task/x
echo b >>README.md
echo c >db/migrations/001.sql
echo d >src/auth/jetons/lire.txt
echo e >"mes docs/guide.md"
git add -A && git commit -q -m changement

# Sans clé chemins_sensibles : le niveau déclaré, normal par défaut.
attend normal main
attend faible main faible
attend eleve main eleve
[[ -z $erreur ]] || echoue "sans chemin sensible, la sortie d'erreur n'est pas vide : $erreur"

# Clé vide.
regler ''
attend faible main faible

# Un chemin sensible monte le niveau et se nomme.
regler 'db/migrations/*'
attend eleve main faible
[[ $erreur == 'risk.sh : chemin sensible : db/migrations/001.sql' ]] || echoue "chemin sensible mal nommé : $erreur"
attend eleve main

# L'étoile couvre aussi les sous-dossiers.
regler 'src/auth/*'
attend eleve main faible
grep -qxF 'risk.sh : chemin sensible : src/auth/jetons/lire.txt' <<<"$erreur" || echoue "étoile et sous-dossier : $erreur"

# Deux motifs, des espaces autour de la virgule, un motif avec une espace.
regler 'secrets/* , mes docs/*,db/migrations/*'
attend eleve main normal
[[ $(grep -c '^risk.sh : chemin sensible : ' <<<"$erreur") -eq 2 ]] || echoue "deux chemins sensibles attendus : $erreur"
grep -qxF 'risk.sh : chemin sensible : mes docs/guide.md' <<<"$erreur" || echoue "motif avec une espace : $erreur"

# Un motif qui ne touche aucun fichier du diff.
regler 'secrets/*'
attend faible main faible

# Un fichier sensible hors du diff ne compte pas.
regler 'README.md'
attend eleve main faible
git switch -q main
attend faible main faible
git switch -q task/x

# Un fichier déplacé hors d'un dossier sensible compte par son ancien chemin.
git switch -q -c task/deplace main
mkdir -p db/migrations docs
echo "create table t (id integer primary key, nom text not null, cree timestamp);" >db/migrations/000.sql
git add db && git commit -q -m "migration"
git tag avant-deplacement
git mv db/migrations/000.sql docs/000.sql
git commit -q -m "déplacement"
regler 'db/migrations/*'
attend eleve avant-deplacement faible
grep -qxF 'risk.sh : chemin sensible : db/migrations/000.sql' <<<"$erreur" || echoue "fichier déplacé hors d'un dossier sensible : $erreur"

# Sans ancêtre commun, le script refuse au lieu de rendre le niveau déclaré.
orphelin="$(git commit-tree "$(git hash-object -t tree /dev/null)" -m racine)"
lancer "$orphelin" faible
[[ $code -eq 2 && -z $sortie && $erreur == "risk.sh : pas d'ancêtre commun entre $orphelin et HEAD" ]] || echoue "sans ancêtre commun : code $code, sortie « $sortie », $erreur"
git switch -q task/x

# Refus.
lancer main moyen
[[ $code -eq 2 && $erreur == 'risk.sh : niveau refusé : moyen' ]] || echoue "niveau inconnu : code $code, $erreur"
lancer nulle-part
[[ $code -eq 2 && $erreur == 'risk.sh : point fixe introuvable : nulle-part' ]] || echoue "point fixe faux : code $code, $erreur"
lancer
[[ $code -eq 2 && $erreur == 'usage : risk.sh <point fixe> [faible|normal|eleve]' ]] || echoue "sans argument : code $code, $erreur"
cd "$tmp" && lancer main
[[ $code -eq 2 && $erreur == 'risk.sh : pas un projet Izanagi' ]] || echoue "hors projet : code $code, $erreur"

echo "risk.sh : tous les cas passent"
