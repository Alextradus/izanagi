#!/usr/bin/env bash
# Pose les gabarits d'Izanagi dans un projet, sans rien écraser.
#
#   install.sh <projet> <fichier-valeurs>
#
# Le fichier de valeurs porte une valeur par ligne (`clé=valeur`), dont
# `composant=<nom>|<chemin>|<pile>|<lancement>` (répétable, un par composant)
# et `systemes` (sous-ensemble de `linux,windows,macos`). Sans ligne
# `composant=`, `pile=<p>` (autre que `aucune`) crée le composant `<p>|.|<p>|`.
# Les valeurs se superposent dans cet ordre : templates/core/defaults.env,
# templates/<pile>/defaults.env de chaque pile, puis le fichier passé en
# argument.
#
# Pour chaque gabarit, une ligne :
#   créé       <chemin>   le fichier manquait, il est posé
#   identique  <chemin>   le fichier existe et vaut le gabarit
#   différent  <chemin>   le fichier existe et diffère ; le diff est dans le
#                         dossier de rapport affiché à la fin
# Sort en erreur, sans rien écrire, si un gabarit garde un `{{clé}}` sans valeur.
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage : install.sh <projet> <fichier-valeurs>" >&2
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
      echo "install.sh : ligne illisible dans $1 : $ligne" >&2
      exit 2
    fi
    [[ $cle == composant ]] && continue
    valeurs[$cle]="${ligne#*=}"
  done <"$1"
}

lire_valeurs "$racine/templates/core/defaults.env"
pile_demandee="$(grep -E '^pile=' "$valeurs_utilisateur" | tail -1 | cut -d= -f2- | tr -d '\r' || true)"
pile="${pile_demandee:-aucune}"
if [[ $pile != aucune && ! -d $racine/templates/$pile ]]; then
  echo "install.sh : pas de gabarit pour la pile « $pile »" >&2
  exit 2
fi

# Composants : `nom|chemin|pile|lancement`, dans l'ordre du fichier.
declare -a composants=()
while IFS= read -r ligne; do
  composants+=("${ligne%$'\r'}")
done < <(grep -E '^composant=' "$valeurs_utilisateur" | cut -d= -f2- || true)
if [[ ${#composants[@]} -eq 0 && $pile != aucune ]]; then
  composants=("$pile|.|$pile|")
fi

# Validation avant toute écriture. Les noms de pile des composants servent de
# nom de dossier de gabarits : ni `/` ni `..`, et pas un dossier réservé.
declare -A noms_vus=()
# Caractères qui casseraient le `cd "chemin"` de check.sh.
chemin_interdit='["$`\]'
for entree in "${composants[@]}"; do
  IFS='|' read -r c_nom c_chemin c_pile c_lancement <<<"$entree"
  if [[ ! $c_nom =~ ^[a-z0-9-]+$ ]]; then
    echo "install.sh : composant « $c_nom » refusé : le nom suit [a-z0-9-]+" >&2
    exit 2
  fi
  if [[ -n ${noms_vus[$c_nom]:-} ]]; then
    echo "install.sh : composant « $c_nom » refusé : nom en double" >&2
    exit 2
  fi
  noms_vus[$c_nom]=1
  if [[ -z $c_chemin || $c_chemin == /* || $c_chemin =~ $chemin_interdit || /$c_chemin/ == */../* ]]; then
    echo "install.sh : chemin « $c_chemin » du composant $c_nom refusé : relatif à la racine, sans \" \$ \` \ ni .." >&2
    exit 2
  fi
  if [[ ! $c_pile =~ ^[a-z0-9-]+$ || $c_pile =~ ^(aucune|core|code|vault|multi)$ ]]; then
    echo "install.sh : pile « $c_pile » du composant $c_nom refusée" >&2
    exit 2
  fi
done

# Systèmes de la CI et de check.sh.
systemes_demandes="$(grep -E '^systemes=' "$valeurs_utilisateur" | tail -1 | cut -d= -f2- | tr -d '\r' || true)"
systemes="${systemes_demandes:-$(sed -n 's/^systemes=//p' "$racine/templates/core/defaults.env" | tr -d '\r')}"
ci_os=""
IFS=',' read -r -a liste_systemes <<<"$systemes"
[[ ${#liste_systemes[@]} -gt 0 ]] || liste_systemes=("")
for s in "${liste_systemes[@]}"; do
  case "$s" in
    linux) os=ubuntu-latest ;;
    windows) os=windows-latest ;;
    macos) os=macos-latest ;;
    *)
      echo "install.sh : systèmes « $systemes » refusés : linux, windows ou macos, séparés par des virgules" >&2
      exit 2
      ;;
  esac
  ci_os+="${ci_os:+, }$os"
done
valeurs[systemes]="$systemes"
valeurs[ci_os]="[$ci_os]"

# Valeurs par défaut de chaque pile utilisée (pile demandée, puis composants).
declare -A piles_lues=()
for p in "${composants[@]}"; do
  IFS='|' read -r _ _ p _ <<<"$p"
  [[ $p == aucune || -n ${piles_lues[$p]:-} ]] && continue
  piles_lues[$p]=1
  [[ -f $racine/templates/$p/defaults.env ]] && lire_valeurs "$racine/templates/$p/defaults.env"
done
# Plusieurs composants : le test manuel par défaut est dev.sh, sauf si le
# fichier de valeurs en donne un.
[[ ${#composants[@]} -ge 2 ]] && valeurs[test_manuel]=scripts/dev.sh
lire_valeurs "$valeurs_utilisateur"
# Posées de nouveau : le fichier de valeurs ne doit pas écraser les valeurs calculées.
valeurs[systemes]="$systemes"
valeurs[ci_os]="[$ci_os]"

# `branche` va entre guillemets dans le YAML de la CI : un `"` ou un `\`
# casserait la chaîne. Git les accepte, le gabarit non.
if [[ ${valeurs[branche]:-} == *[\"\\]* ]]; then
  echo "install.sh : branche « ${valeurs[branche]} » refusée : un \" ou un \\ casserait le YAML de la CI" >&2
  exit 2
fi

# Valeurs dérivées. Le script calcule `vault_cite` et `ligne_vault`, même si
# le fichier de valeurs les donne.
# `projet_dossier` : un nom de dossier sûr dans du shell, fait des seuls
# `[a-z0-9._-]`. Le fichier de valeurs peut le donner ; sinon il se dérive
# de `projet` (`Mon Projet` donne `mon-projet`).
# Le filtre travaille octet par octet en locale C : une lettre accentuée ou
# une apostrophe devient un tiret, quelle que soit la locale de l'appelant.
dossier_sur() {
  local d
  d="$(printf '%s' "$1" | LC_ALL=C tr 'A-Z' 'a-z' | LC_ALL=C tr -cs 'a-z0-9._-' '-')"
  d="${d#-}"
  printf '%s' "${d%-}"
}
source_dossier="${valeurs[projet_dossier]:-${valeurs[projet]:-}}"
if [[ -n $source_dossier ]]; then
  valeurs[projet_dossier]="$(dossier_sur "$source_dossier")"
  [[ -n ${valeurs[projet_dossier]} ]] || valeurs[projet_dossier]=projet
fi
# `vault_cite` : le chemin du vault entre accents graves, ou `non`.
# `ligne_vault` : la ligne de CLAUDE.md qui pointe vers le vault, ou rien.
if [[ ${valeurs[vault]:-non} == non ]]; then
  valeurs[vault_cite]="non"
  valeurs[ligne_vault]=""
else
  valeurs[vault_cite]="\`${valeurs[vault]}\`"
  valeurs[ligne_vault]="- Vault Obsidian : \`${valeurs[vault]}\`, tenu à jour au fil de l'eau selon \`docs/agents/vault.md\`."
fi

# Dossiers de gabarits à poser, du plus général au plus particulier.
sources=("$racine/templates/core")
[[ $pile != aucune ]] && sources+=("$racine/templates/$pile")
[[ ${#composants[@]} -gt 0 ]] && sources+=("$racine/templates/code")
[[ ${#composants[@]} -ge 2 ]] && sources+=("$racine/templates/multi")
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

# Rend un fragment avec les seules clés données (`clé=valeur`).
rendre_fragment() {
  local texte kv f="$1"
  shift
  texte="$(cat "$f"; printf x)"
  texte="${texte%x}"
  for kv in "$@"; do
    texte="${texte//"{{${kv%%=*}}}"/"${kv#*=}"}"
  done
  printf '%s' "$texte"
}

# Fragment d'une pile, ou celui du cœur quand la pile n'a pas de gabarit.
fragment() {
  if [[ -f $racine/templates/$2/fragments/$1 ]]; then
    printf '%s' "$racine/templates/$2/fragments/$1"
  else
    printf '%s' "$racine/templates/core/fragments/$1"
  fi
}

# Valeurs calculées : sections, appels et installation CI des composants.
sections=""
appels=""
lancements=""
ci_setup=""
declare -a a_ecrire=() resume=()
declare -A setup_vus=()
for entree in "${composants[@]}"; do
  IFS='|' read -r c_nom c_chemin c_pile c_lancement <<<"$entree"
  c_id="${c_nom//-/_}"
  sections+="${sections:+$'\n\n'}$(rendre_fragment "$(fragment check-section.sh "$c_pile")" \
    "composant=$c_nom" "id=$c_id" "chemin=$c_chemin" "pile=$c_pile")"
  [[ -n $c_lancement ]] && lancements+="${lancements:+$'\n'}(cd \"$c_chemin\" && $c_lancement) &"
  appels+="${appels:+$'\n'}  verifier_$c_id"
  if [[ -z ${setup_vus[$c_pile]:-} ]]; then
    setup_vus[$c_pile]=1
    ci_setup+="${ci_setup:+$'\n'}$(rendre_fragment "$(fragment ci-setup.yml "$c_pile")" "pile=$c_pile")"
  fi
  [[ -f $racine/templates/$c_pile/fragments/check-section.sh ]] || a_ecrire+=("$c_nom ($c_pile)")
  resume+=("$c_nom($c_pile)")
done
valeurs[sections]="$sections"
valeurs[appels]="$appels"
valeurs[ci_setup]="$ci_setup"
valeurs[lancements]="$lancements"

declare -a fichiers=()
manque=false
for source in "${sources[@]}"; do
  while IFS= read -r -d '' f; do
    rel="${f#"$source"/}"
    [[ $rel == defaults.env || $rel == fragments/* ]] && continue
    fichiers+=("$source|$rel")
    if restes="$(rendre "$f" | grep -oE '\{\{[a-z_]+\}\}' | sort -u)" && [[ -n $restes ]]; then
      echo "install.sh : $rel attend une valeur pour : $(echo $restes)" >&2
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

for e in "${a_ecrire[@]}"; do
  echo "à écrire   $e"
done
if [[ ${#resume[@]} -eq 0 ]]; then
  echo "composants : aucun"
else
  liste="${resume[0]}"
  for e in "${resume[@]:1}"; do liste+=", $e"; done
  echo "composants : $liste"
fi
echo "rapport : $rapport"
