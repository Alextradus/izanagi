#!/usr/bin/env bash
# Migre un projet posé en 0.6 vers la 0.7.
#
#   0.7.0.sh <projet>
#
# - .izanagi/config.env : écrit `mutation`, `oui` quand toutes les piles des
#   composants ont un gabarit et `non` sinon, même si la clé existe : avant la 0.7,
#   aucun projet ne la choisissait. Ajoute `mutation_delai=15` et `navigateur`
#   s'ils manquent, `navigateur=oui` quand un `playwright.config.*` est à la
#   racine ou dans le dossier d'un composant. Met `izanagi_version` à 0.7.0.
# - docs/agents/harness.md : remplace la ligne « Couches de test » par la section
#   du gabarit (décision 101). Chaque composant reçoit la couche `unitaire`, avec
#   la commande de l'étape `tests` de sa section de scripts/check.sh. Une couche
#   `integration` ou `fonctionnelle` s'ajoute seulement si son dossier contient
#   déjà des tests.
# - Affiche `à ranger   <chemin>` pour chaque fichier de test qu'elle ne range dans
#   aucune couche. Elle ne déplace aucun test (décision 114).
#
# scripts/check.sh et .github/workflows/ci.yml ne sont pas écrits : la pose
# d'upgrade les reprend du gabarit, avec les couches de harness.md.
#
# Affiche une ligne par fichier écrit. Relancé sur un projet migré, affiche
# `déjà migré`. Ne commite rien.
set -euo pipefail

# shellcheck source=../lib.sh
. "$(dirname "$0")/../lib.sh"

if [[ $# -ne 1 ]]; then
  echo "usage : 0.7.0.sh <projet>" >&2
  exit 2
fi
cible="$(cd "$1" && pwd)"
config="$cible/.izanagi/config.env"
if [[ ! -f $config ]]; then
  echo "0.7.0.sh : .izanagi/config.env absent : lance d'abord la migration 0.4.0" >&2
  exit 2
fi
harness="$cible/docs/agents/harness.md"
check="$cible/scripts/check.sh"
gabarits="$izanagi_lib_dir/../templates"

version="$(kv_get "$config" izanagi_version || true)"
monte=0
if [[ -z $version ]] || version_lt "$version" 0.7.0; then monte=1; fi
declare -A presente=()
for cle in navigateur mutation mutation_delai; do
  grep -q "^$cle=" "$config" && presente[$cle]=1
done
harness_a_faire=0
[[ -f $harness ]] && ! grep -qx '## Couches de test' <(tr -d '\r' <"$harness") && harness_a_faire=1
config_a_faire=$monte
[[ ${#presente[@]} -eq 3 ]] || config_a_faire=1

if [[ $config_a_faire -eq 0 && $harness_a_faire -eq 0 ]]; then
  echo "déjà migré"
  exit 0
fi

# Composants de harness.md : `- composant : <nom> | <chemin> | <pile> | <lancement>`.
noms=() chemins=() piles=()
if [[ -f $harness ]]; then
  while IFS='|' read -r c_nom c_chemin c_pile _; do
    noms+=("$(printf '%s' "$c_nom" | tr -d ' ')")
    chemins+=("$(printf '%s' "$c_chemin" | tr -d ' ')")
    piles+=("$(printf '%s' "$c_pile" | tr -d ' ')")
  done < <(sed -n 's/^- composant : //p' "$harness" | tr -d '\r')
fi

# dossier_de <chemin> : le dossier absolu d'un composant.
dossier_de() {
  if [[ $1 == . ]]; then printf '%s' "$cible"; else printf '%s' "$cible/$1"; fi
}

# --- config.env ---
if [[ $config_a_faire -eq 1 ]]; then
  declare -A nouvelle=()
  # Mutation (décision 111) : comme install.sh, `oui` quand chaque pile a un gabarit.
  mutation=non
  if [[ ${#piles[@]} -gt 0 ]]; then
    mutation=oui
    for p in "${piles[@]}"; do
      [[ -f $gabarits/$p/fragments/check-section.sh ]] || mutation=non
    done
  fi
  navigateur=non
  for d in "$cible" ${chemins[@]+"${chemins[@]}"}; do
    [[ $d == "$cible" ]] || d="$(dossier_de "$d")"
    compgen -G "$d/playwright.config.*" >/dev/null && navigateur=oui
  done
  nouvelle[navigateur]="navigateur=$navigateur"
  nouvelle[mutation]="mutation=$mutation"
  nouvelle[mutation_delai]="mutation_delai=15"
  # Ordre du gabarit : chaque clé manquante suit la précédente de la suite.
  suite=(hook_destructif navigateur mutation mutation_delai)
  ecrire_suivantes() {
    local i trouve=0
    for i in "${suite[@]}"; do
      if [[ $trouve -eq 1 ]]; then
        [[ -n ${presente[$i]:-} ]] && return 0
        printf '%s\n' "${nouvelle[$i]}"
        presente[$i]=1
      fi
      [[ $i == "$1" ]] && trouve=1
    done
    return 0
  }
  tmp="$(mktemp "$cible/.izanagi/config.XXXXXX")"
  vu_version=0
  while IFS= read -r ligne || [[ -n $ligne ]]; do
    ligne="${ligne%$'\r'}"
    cle="${ligne%%=*}"
    if [[ $monte -eq 1 && $cle == izanagi_version ]]; then
      ligne="izanagi_version=0.7.0"
      vu_version=1
    fi
    if [[ $monte -eq 1 && $cle == mutation && $ligne == *=* ]]; then ligne="${nouvelle[mutation]}"; fi
    printf '%s\n' "$ligne"
    if [[ $ligne == *=* && $cle =~ ^(hook_destructif|navigateur|mutation)$ ]]; then ecrire_suivantes "$cle"; fi
  done <"$config" >"$tmp"
  # Un config.env sans ces lignes reçoit les clés à la fin.
  for cle in navigateur mutation mutation_delai; do
    [[ -n ${presente[$cle]:-} ]] || printf '%s\n' "${nouvelle[$cle]}" >>"$tmp"
  done
  if [[ $monte -eq 1 && $vu_version -eq 0 ]]; then printf 'izanagi_version=0.7.0\n' >>"$tmp"; fi
  mv "$tmp" "$config"
  echo "écrit      .izanagi/config.env"
fi

[[ $harness_a_faire -eq 1 ]] || exit 0

# --- harness.md ---

# commande_tests <nom> : la commande de l'étape `tests` du composant dans
# scripts/check.sh, la ligne qui suit `echo "-- <nom> : tests"` dans sa section.
# Rien si elle manque.
commande_tests() {
  [[ -f $check ]] || return 0
  tr -d '\r' <"$check" | awk -v debut="verifier_${1//-/_}() {" -v etape="echo \"-- $1 : tests\"" '
    $0 == debut { dans = 1; next }
    dans && /^}/ { exit }
    dans {
      t = $0
      gsub(/^[ \t]+|[ \t]+$/, "", t)
      if (suivant && t != "" && t !~ /^#/) {
        if (t != ")" && t != "}") print t
        exit
      }
      if (t == etape) suivant = 1
    }'
}

# Motif find des fichiers de test d'une pile. Une pile sans gabarit : tout fichier.
motif_tests() {
  case "$1" in
    python) printf '%s\n' -name 'test_*.py' -o -name '*_test.py' ;;
    typescript)
      local ext
      printf '%s\n' -false
      for ext in ts tsx mts cts js jsx mjs cjs; do
        printf '%s\n' -o -name "*.test.$ext" -o -name "*.spec.$ext"
      done
      ;;
    rust) printf '%s\n' -name '*.rs' ;;
    *) printf '%s\n' -type f ;;
  esac
}

# tests_dans <dossier> <pile> [profondeur] : affiche les fichiers de test du dossier,
# hors des dossiers d'outils et des autres composants.
tests_dans() {
  local dossier="$1" pile="$2" autre
  [[ -d $dossier ]] || return 0
  local -a motif elagage=(-name node_modules -o -name .venv -o -name venv -o -name .git -o -name target -o -name dist -o -name build)
  mapfile -t motif < <(motif_tests "$pile")
  for autre in ${chemins[@]+"${chemins[@]}"}; do
    autre="$(dossier_de "$autre")"
    [[ $autre != "$dossier" && $autre == "$dossier"/* ]] && elagage+=(-o -path "$autre")
  done
  find "$dossier" ${3:+-maxdepth "$3"} \( "${elagage[@]}" \) -prune -o -type f \( "${motif[@]}" \) -print
}

# Couches détectées d'un composant : `integration` et `fonctionnelle` quand leur
# dossier contient déjà des tests. Remplit `detectees` et `rangees` (fichiers rangés).
detecter() {
  local dir="$1" pile="$2" f
  detectees=" unitaire "
  rangees=""
  case "$pile" in
    rust)
      while IFS= read -r f; do
        rangees+="$f"$'\n'
        if [[ $(basename "$f") == fonctionnel_* ]]; then
          detectees+="fonctionnelle "
        else
          detectees+="integration "
        fi
      done < <(tests_dans "$dir/tests" rust 1)
      ;;
    *)
      local couche sous
      for couche in integration fonctionnelle; do
        sous=integration
        [[ $couche == fonctionnelle ]] && sous=fonctionnels
        f="$(tests_dans "$dir/tests/$sous" "$pile")"
        if [[ -n $f ]]; then
          detectees+="$couche "
          rangees+="$f"$'\n'
        fi
      done
      ;;
  esac
}

rangs=""
lignes=""
a_ranger=""
for i in "${!noms[@]}"; do
  nom="${noms[$i]}" chemin="${chemins[$i]}" pile="${piles[$i]}"
  dir="$(dossier_de "$chemin")"
  detecter "$dir" "$pile"
  for couche in unitaire integration fonctionnelle; do
    declaree=0
    [[ $detectees == *" $couche "* ]] && declaree=1
    commande="" dossier=""
    if [[ $couche == unitaire ]]; then
      commande="$(commande_tests "$nom")"
      commande="${commande:-à préciser}"
    elif [[ $declaree -eq 1 && ! -f $gabarits/$pile/fragments/check-section.sh ]]; then
      # Pile sans gabarit : le dossier est celui où les tests ont été trouvés.
      dossier="tests/integration"
      [[ $couche == fonctionnelle ]] && dossier="tests/fonctionnels"
    fi
    rendre_couche "$nom" "$chemin" "$pile" "$couche" "$declaree" "$commande" "$dossier"
    rangs+="${rangs:+$'\n'}$couche_rang"
    [[ $declaree -eq 1 ]] && lignes+="${lignes:+$'\n'}$couche_ligne"
  done
  # Fichiers de test hors de toute couche : ni dans le dossier unitaire, ni rangés.
  case "$pile" in
    python | typescript)
      info="$(info_couche "$pile" unitaire)"
      unitaire="$dir/${info%%|*}"
      while IFS= read -r f; do
        [[ $f == "$unitaire"/* ]] && continue
        [[ $'\n'"$rangees" == *$'\n'"$f"$'\n'* ]] && continue
        a_ranger+="${f#"$cible"/}"$'\n'
      done < <(tests_dans "$dir" "$pile")
      ;;
  esac
done

# Section du gabarit, de son titre à la fin, rendue avec le tableau et les lignes.
section="$(sed -n '/^## Couches de test$/,$p' "$gabarits/core/docs/agents/harness.md" | tr -d '\r')"
section="${section//"{{tableau_couches}}"/"$(tableau_des_couches "$rangs")"}"
if [[ -n $lignes ]]; then
  section="${section//"{{lignes_couches}}"/"$lignes"}"
else
  section="${section//$'\n\n'"{{lignes_couches}}"/}"
fi

tmp="$(mktemp "$cible/.izanagi/harness.XXXXXX")"
tr -d '\r' <"$harness" | grep -v '^- \*\*Couches de test\*\* : ' >"$tmp" || true
printf '\n%s\n' "$section" >>"$tmp"
mv "$tmp" "$harness"
echo "écrit      docs/agents/harness.md"

if [[ -n $a_ranger ]]; then
  printf '%s' "$a_ranger" | LC_ALL=C sort -u | while IFS= read -r f; do
    echo "à ranger   $f"
  done
fi
