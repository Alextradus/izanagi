#!/usr/bin/env bash
# Teste scripts/lib.sh et scripts/state.sh : lecture d'une clé, comparaison de
# versions, cycle de vie de .izanagi/state.env, commit du seul fichier d'état.
set -euo pipefail

racine="$(cd "$(dirname "$0")/.." && pwd)"
state="$racine/scripts/state.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echoue() { echo "ÉCHEC : $*" >&2; exit 1; }

# Lance une commande qui doit sortir avec le code attendu.
code() {
  local attendu=$1 obtenu=0
  shift
  "$@" >/dev/null 2>&1 || obtenu=$?
  [[ $obtenu -eq $attendu ]] || echoue "code $obtenu au lieu de $attendu : $*"
}

[[ -f $racine/scripts/lib.sh && -f $state ]] || echoue "scripts/lib.sh ou scripts/state.sh absent"
# shellcheck source=../scripts/lib.sh
. "$racine/scripts/lib.sh"

# --- kv_get ---
cat >"$tmp/kv" <<'FIN'
# commentaire
decisions=la section « Décisions » de la spec

hors_revue=`a=b`, `c`
branche=main
branche=trunk
FIN
[[ $(kv_get "$tmp/kv" decisions) == 'la section « Décisions » de la spec' ]] || echoue "kv_get : espaces et guillemets"
[[ $(kv_get "$tmp/kv" hors_revue) == '`a=b`, `c`' ]] || echoue "kv_get : valeur avec = et accents graves"
[[ $(kv_get "$tmp/kv" branche) == trunk ]] || echoue "kv_get : la dernière ligne l'emporte"
sortie="$(kv_get "$tmp/kv" absente || echo "code $?")"
[[ $sortie == "code 1" ]] || echoue "kv_get : clé absente : $sortie"
sortie="$(kv_get "$tmp/nulle-part" branche || echo "code $?")"
[[ $sortie == "code 1" ]] || echoue "kv_get : fichier absent : $sortie"
printf 'spec=docs/spec.md\r\n' >"$tmp/crlf"
[[ $(kv_get "$tmp/crlf" spec) == docs/spec.md ]] || echoue "kv_get : retour chariot gardé"

# --- version_lt ---
version_lt 0.3.0 0.4.0 || echoue "version_lt 0.3.0 0.4.0"
version_lt 0.10.0 0.9.0 && echoue "version_lt 0.10.0 0.9.0"
version_lt 0.4.0 0.4.0 && echoue "version_lt 0.4.0 0.4.0"
version_lt 0.4.9 1.0.0 || echoue "version_lt 0.4.9 1.0.0"
version_lt 0.08.0 0.9.0 || echoue "version_lt 0.08.0 0.9.0 : zéro de tête lu en octal"

# --- plugin_version ---
[[ $(plugin_version) =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || echoue "plugin_version : $(plugin_version)"

# --- state.sh ---
projet="$tmp/p"
mkdir -p "$projet/.izanagi"
git -C "$projet" init -q -b main
git -C "$projet" config user.email essai@example.invalid
git -C "$projet" config user.name Essai
cd "$projet"

# Hors projet Izanagi : pas de config.env.
code 2 bash "$state" get
message="$(bash "$state" get 2>&1 || true)"
[[ $message == 'state.sh : pas un projet Izanagi' ]] || echoue "message hors projet : $message"

echo 'branche=main' >.izanagi/config.env
git add -A && git commit -q -m "cadre"

# Sans état.
code 1 bash "$state" get
[[ -z $(bash "$state" get 2>/dev/null || true) ]] || echoue "get sans état affiche quelque chose"
code 0 bash "$state" clear

# Refus de start.
code 2 bash "$state" start jalon "Mon Jalon"
code 2 bash "$state" start autre x
code 2 bash "$state" start jalon
[[ ! -e .izanagi/state.env ]] || echoue "start refusé a créé le fichier"

# start.
bash "$state" start jalon essai
[[ $(bash "$state" get flux) == jalon ]] || echoue "start : flux"
[[ $(bash "$state" get nom) == essai ]] || echoue "start : nom"
[[ $(bash "$state" get phase) == cadrage ]] || echoue "start : phase d'un jalon"
[[ $(bash "$state" get maj) =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$ ]] || echoue "start : maj : $(bash "$state" get maj)"
[[ $(grep -c '=' .izanagi/state.env) -eq 4 ]] || echoue "start : quatre clés attendues : $(cat .izanagi/state.env)"
code 2 bash "$state" start jalon autre
code 1 bash "$state" get tranche

# set.
bash "$state" set phase=tranches tranche=2
[[ $(bash "$state" get tranche) == 2 && $(bash "$state" get phase) == tranches ]] || echoue "set : phase et tranche"
[[ $(bash "$state" get nom) == essai ]] || echoue "set a perdu le nom"
avant="$(cat .izanagi/state.env)"
code 2 bash "$state" set phase=inconnue
code 2 bash "$state" set flux=task
code 2 bash "$state" set tranche=deux
code 2 bash "$state" set tour=1 phase=inconnue
code 2 bash "$state" set
[[ $(cat .izanagi/state.env) == "$avant" ]] || echoue "set refusé a modifié le fichier"
bash "$state" set plan=docs/plans/2026-01-01-essai.md
[[ $(bash "$state" get plan) == docs/plans/2026-01-01-essai.md ]] || echoue "set : plan"
bash "$state" get | grep -qx 'flux=jalon' || echoue "get sans clé n'affiche pas le fichier"

# --commit : le seul fichier d'état, même avec un autre fichier modifié.
echo "autre" >autre.txt
git add autre.txt
bash "$state" set --commit phase=revue
[[ $(git show --name-only --format= HEAD) == .izanagi/state.env ]] || echoue "--commit a pris d'autres fichiers : $(git show --name-only --format= HEAD)"
[[ $(git log -1 --format=%s) == 'chore(izanagi): état jalon essai, revue' ]] || echoue "--commit : message : $(git log -1 --format=%s)"
git status --porcelain | grep -q 'autre.txt' || echoue "--commit a touché autre.txt"
# Sans changement, ni commit ni nouvelle date.
bash "$state" set --commit tour=1
tete="$(git rev-parse HEAD)"
maj="$(bash "$state" get maj)"
sleep 1
bash "$state" set --commit tour=1
[[ $(git rev-parse HEAD) == "$tete" ]] || echoue "set --commit sans changement a commité"
[[ $(bash "$state" get maj) == "$maj" ]] || echoue "set sans changement a changé la date"
# Un changement fait sans --commit part avec le --commit suivant, même sans nouvelle valeur.
bash "$state" set tour=2
bash "$state" set --commit tour=2
[[ $(git rev-parse HEAD) != "$tete" ]] || echoue "set --commit n'a pas commité un changement en attente"
[[ -z $(git status --porcelain -- .izanagi/state.env) ]] || echoue "state.env reste modifié après set --commit"
tete="$(git rev-parse HEAD)"

# clear.
bash "$state" clear --commit
[[ ! -e .izanagi/state.env ]] || echoue "clear n'a pas supprimé le fichier"
[[ $(git rev-parse HEAD) != "$tete" ]] || echoue "clear --commit n'a pas commité"
[[ $(git log -1 --format=%s) == 'chore(izanagi): état jalon essai, fin' ]] || echoue "clear --commit : message : $(git log -1 --format=%s)"
git ls-files --error-unmatch .izanagi/state.env >/dev/null 2>&1 && echoue "state.env encore suivi après clear --commit"
tete="$(git rev-parse HEAD)"
code 0 bash "$state" clear --commit
[[ $(git rev-parse HEAD) == "$tete" ]] || echoue "second clear --commit a commité"

# Un flux hors jalon commence en phase debut.
bash "$state" start task petit-changement --commit
[[ $(bash "$state" get phase) == debut ]] || echoue "start task : phase"
[[ $(git log -1 --format=%s) == 'chore(izanagi): état task petit-changement, debut' ]] || echoue "start --commit : message"

# Un état écrit à la main, sans flux ni nom, n'arrête pas set.
git switch -q -c task/main-seule
printf 'phase=debut\n' >.izanagi/state.env
code 0 bash "$state" set --commit tour=1
[[ -z $(git status --porcelain -- .izanagi/state.env) ]] || echoue "set --commit sur un état incomplet n'a pas commité"
git switch -q -
git branch -q -D task/main-seule

# Depuis un sous-dossier du projet.
mkdir -p sous/dossier && cd sous/dossier
[[ $(bash "$state" get flux) == task ]] || echoue "get depuis un sous-dossier"

echo "state.sh : tous les cas passent"
