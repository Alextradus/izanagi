#!/usr/bin/env bash
# Passe de mutation sur le diff d'un projet posé par install.sh.
#
#   mutation.sh <projet> <point fixe>
#
# Lit `mutation` et `mutation_delai` (minutes) dans .izanagi/config.env : une clé
# `mutation` absente vaut `non`. Pour chaque composant de docs/agents/harness.md qui
# a un fichier de code dans `git diff <point fixe>...HEAD`, lance l'outil de sa pile
# dans son dossier, sur les tests des couches unitaire et intégration. Le délai est
# partagé : chaque composant reçoit ce qui reste.
#
# Affiche une ligne par survivant, `survivant | <composant> | <fichier>:<ligne> | <mutation>`,
# une ligne par composant non muté, `non muté | <composant> | <raison>`, puis
# `mutation : <n> survivants`. Ne fait jamais échouer la vérification : sort avec 0,
# sauf sur un usage faux (code 2).
#
# IZANAGI_MUTATION_DELAI=<secondes> remplace `mutation_delai`, pour les essais.
#
# Faits lus le 2026-11-19 :
# - cargo-mutants : `--in-diff DIFF_FILE` ne teste que les mutants qui touchent les
#   régions changées du diff. Les noms de fichiers du diff portent le préfixe `b/`
#   de `git diff`, ou aucun. Un diff sans code Rust ne donne aucun mutant.
#   https://mutants.rs/in-diff.html
# - cargo-mutants : `--output <dossier>` crée `mutants.out` dans ce dossier (par
#   défaut le dossier source), et un `mutants.out` existant devient `mutants.out.old`.
#   `missed.txt` y liste les mutants manqués, c'est-à-dire survivants, un par ligne.
#   https://mutants.rs/mutants-out.html et src/options.rs de
#   https://github.com/sourcefrog/cargo-mutants
# - cargo-mutants : une ligne de `missed.txt` s'écrit avec `mutant.name(true)`,
#   par exemple `src/process.rs:213:9: replace ProcessStatus::is_success -> bool with true`
#   (src/output.rs et ses tests, même dépôt).
# - Stryker : `--mutate` prend une liste de fichiers ou de motifs séparés par des
#   virgules, `--reporters` une liste de rapporteurs. Le rapporteur `json` écrit
#   `reports/mutation/mutation.json` sans indentation, que grep et sed ne lisent pas
#   de façon sûre : le script lit le rapport `clear-text` sur la sortie standard.
#   https://stryker-mutator.io/docs/stryker-js/configuration/ et
#   packages/core/src/reporters/json-reporter.ts de https://github.com/stryker-mutator/stryker-js
# - Stryker, rapport `clear-text` : un mutant survivant s'affiche
#   `[Survived] <mutateur>`, puis `<fichier>:<ligne>:<colonne>`, puis les lignes
#   d'origine (`-   `) et mutées (`+   `), en couleurs ANSI que le script retire.
#   packages/core/src/reporters/clear-text-reporter.ts du même dépôt.
# - Stryker et Vitest : la page du lanceur Vitest ne décrit aucune option pour
#   choisir des projets Vitest (`test.projects`). Le fait n'est pas établi : Stryker
#   lance la configuration Vitest entière, couche fonctionnelle comprise si elle
#   est un projet Vitest. `vitest.related` (vrai par défaut) limite les tests à ceux
#   liés aux fichiers mutés. https://stryker-mutator.io/docs/stryker-js/vitest-runner/
# - mutmut : `mutmut run [noms]` filtre les mutants par motif fnmatch. Un nom de
#   mutant vaut `<module>.<fonction mutée>`, où le module est le chemin du fichier
#   sans `.py`, les `/` changés en `.` et un préfixe `src.` retiré ; `.__init__.`
#   devient `.`. Les fonctions mutées commencent par `x` (`x_somme__mutmut_1`).
#   src/mutmut/__main__.py et src/mutmut/utils/format_utils.py de https://github.com/boxed/mutmut
# - mutmut garde ses résultats dans `mutants/`. `mutmut results` affiche
#   `    <nom>: <état>`, l'état `survived` venant du code de sortie 0 des tests.
#   `mutmut show <nom>` affiche `# <nom>: <état>` puis un diff de la seule fonction :
#   ses numéros de ligne partent de la fonction, pas du fichier. Le script cherche
#   donc la ligne d'origine dans le fichier. src/mutmut/__main__.py, stats.py et
#   mutation/diff_apply.py du même dépôt ; https://mutmut.readthedocs.io/en/latest/
# - mutmut choisit ses tests par la configuration `pytest_add_cli_args_test_selection`
#   de pyproject.toml, sans option en ligne de commande (configuration.py). pytest
#   ajoute `PYTEST_ADDOPTS` à sa ligne de commande, et `--ignore=<chemin>` écarte un
#   dossier de la collecte : le script écarte ainsi `tests/fonctionnels`.
#   https://docs.pytest.org/en/stable/example/simple.html et
#   https://docs.pytest.org/en/stable/example/pythoncollection.html
set -uo pipefail

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

if [[ $# -ne 2 ]]; then
  echo "usage : mutation.sh <projet> <point fixe>" >&2
  exit 2
fi
cible="$(cd "$1" 2>/dev/null && pwd)" || {
  echo "mutation.sh : dossier introuvable : $1" >&2
  exit 2
}
point=$2
if ! git -C "$cible" rev-parse --verify -q "$point^{commit}" >/dev/null 2>&1; then
  echo "mutation.sh : point fixe introuvable : $point" >&2
  exit 2
fi
config="$cible/.izanagi/config.env"
harness="$cible/docs/agents/harness.md"

if [[ $(kv_get "$config" mutation 2>/dev/null || true) != oui ]]; then
  echo "mutation : désactivée"
  exit 0
fi
delai="$(kv_get "$config" mutation_delai 2>/dev/null || true)"
[[ $delai =~ ^[0-9]+$ ]] || delai=15
budget=$((10#$delai * 60))
[[ ${IZANAGI_MUTATION_DELAI:-} =~ ^[0-9]+$ ]] && budget=$IZANAGI_MUTATION_DELAI

trim() { # trim <texte> : sans espaces de bord
  local t=$1
  t="${t#"${t%%[![:space:]]*}"}"
  printf '%s' "${t%"${t##*[![:space:]]}"}"
}

# code_a_muter <pile> <fichier> : rend 0 si le fichier, relatif au composant, est du
# code que l'outil de la pile mute. Les tests, la documentation et la
# configuration ne le sont pas.
code_a_muter() {
  local f=$2
  case "$1" in
    rust)
      [[ $f == *.rs && $f != tests/* && $f != */tests/* && $f != benches/* && $f != */benches/* ]]
      ;;
    typescript)
      case "$f" in
        *.d.ts | *.test.* | *.spec.* | *.config.* | tests/* | */tests/* | e2e/* | */e2e/*) return 1 ;;
        *.ts | *.tsx | *.mts | *.cts | *.js | *.jsx | *.mjs | *.cjs) return 0 ;;
        *) return 1 ;;
      esac
      ;;
    python)
      case "$f" in
        tests/* | */tests/* | test_*.py | */test_*.py | *_test.py | conftest.py | */conftest.py) return 1 ;;
        *.py) return 0 ;;
        *) return 1 ;;
      esac
      ;;
    *)
      [[ $f != *.md && $f != docs/* ]]
      ;;
  esac
}

# Composants qui ont du code dans le diff. Les chemins se lisent dans le dossier du
# composant (`--relative`) : cargo-mutants et les autres outils y tournent.
noms=() chemins=() piles=() fichiers=()
if [[ -f $harness ]]; then
  while IFS='|' read -r nom chemin pile _; do
    nom="$(trim "${nom#- composant :}")"
    chemin="$(trim "$chemin")"
    pile="$(trim "$pile")"
    [[ -z $chemin ]] && chemin=.
    [[ -d $cible/$chemin ]] || continue
    liste=""
    while IFS= read -r f; do
      [[ -n $f ]] && code_a_muter "$pile" "$f" && liste+="$f"$'\n'
    done < <(git -C "$cible/$chemin" diff --relative --name-only --diff-filter=d "$point...HEAD" 2>/dev/null)
    [[ -n $liste ]] || continue
    noms+=("$nom")
    chemins+=("$chemin")
    piles+=("$pile")
    fichiers+=("$liste")
  done < <(grep -E '^- composant : ' "$harness" | tr -d '\r')
fi
if [[ ${#noms[@]} -eq 0 ]]; then
  echo "mutation : rien à muter"
  exit 0
fi

travail="$(mktemp -d)"
trap 'rm -rf "$travail"' EXIT
fin=$(($(date +%s) + budget))
echappement=$'\033'

# natif <chemin> : le chemin lisible par un programme Windows (`C:/…`) quand cygpath
# existe, tel quel sinon. cargo reçoit ainsi des chemins du dossier temporaire.
natif() {
  if command -v cygpath >/dev/null; then cygpath -m "$1"; else printf '%s' "$1"; fi
}

# lancer <journal> <commande>… : lance la commande avec le délai restant, sortie dans
# le journal. Rend 124 si le délai est usé avant ou pendant la commande. Sans
# `timeout`, la commande tourne sans borne, comme dans check-contract.sh.
lancer() {
  local journal=$1 restant
  shift
  restant=$((fin - $(date +%s)))
  ((restant > 0)) || return 124
  if command -v timeout >/dev/null; then
    timeout "${restant}s" "$@" >"$journal" 2>&1
  else
    "$@" >"$journal" 2>&1
  fi
}

# Résultats d'un composant : une ligne `<fichier>\t<ligne>\t<mutation>` par
# survivant, fichier relatif au composant.
resultats_rust() { # resultats_rust <missed.txt>
  sed -n 's/^\([^:]*\):\([0-9]*\):[0-9]*: \(.*\)$/\1\t\2\t\3/p' "$1" | tr -d '\r'
}
resultats_typescript() { # resultats_typescript <journal> <dossier>
  sed "s/$echappement\[[0-9;]*m//g" "$1" | tr -d '\r' | awk -v dossier="$2/" '
    function sortir(remplacement) {
      fichier = lieu
      sub(/:[0-9]+$/, "", fichier)
      ligne = fichier
      sub(/^.*:/, "", ligne)
      sub(/:[0-9]+$/, "", fichier)
      if (index(fichier, dossier) == 1) fichier = substr(fichier, length(dossier) + 1)
      printf "%s\t%s\t%s%s\n", fichier, ligne, mutateur, remplacement
      etat = 0
    }
    etat == 2 && /^\+   / {
      r = substr($0, 5)
      sub(/^[ \t]+/, "", r)
      sub(/[ \t]+$/, "", r)
      sortir(" : " r)
      next
    }
    etat == 2 && !/^-   / { sortir("") }
    /^\[[^]]*Survived\] / {
      mutateur = $0
      sub(/^\[[^]]*\] /, "", mutateur)
      etat = 1
      next
    }
    etat == 1 { lieu = $0; etat = 2; next }
    END { if (etat == 2) sortir("") }
  '
}
# ligne_dans <fichier> <texte> : numéro de la première ligne du fichier égale au
# texte, espaces de bord ignorées ; `?` sans correspondance.
ligne_dans() {
  awk -v t="$2" '
    BEGIN { sub(/^[ \t]+/, "", t); sub(/[ \t]+$/, "", t) }
    { l = $0; sub(/\r$/, "", l); sub(/^[ \t]+/, "", l); sub(/[ \t]+$/, "", l) }
    l == t { print NR; trouve = 1; exit }
    END { if (!trouve) print "?" }
  ' "$1"
}

survivants=0
for i in "${!noms[@]}"; do
  nom=${noms[i]}
  chemin=${chemins[i]}
  pile=${piles[i]}
  dossier="$cible/$chemin"
  prefixe=""
  [[ $chemin != . ]] && prefixe="${chemin%/}/"
  mapfile -t liste < <(printf '%s' "${fichiers[i]}")
  case "$pile" in
    rust) sonde=(cargo mutants --version) ;;
    typescript) sonde=(npx --no-install stryker --version) ;;
    python) sonde=(uv run mutmut --version) ;;
    *)
      echo "non muté | $nom | pile sans outil"
      continue
      ;;
  esac
  if ((fin - $(date +%s) <= 0)); then
    echo "non muté | $nom | délai dépassé"
    continue
  fi
  if ! (cd "$dossier" && "${sonde[@]}" >/dev/null 2>&1); then
    echo "non muté | $nom | outil absent"
    continue
  fi

  journal="$travail/$i.log"
  trouves="$travail/$i.survivants"
  : >"$trouves"
  code=0
  case "$pile" in
    rust)
      # Les tests fonctionnels demandent la feature `fonctionnel` (required-features) :
      # sans `--features`, cargo les saute, et cargo-mutants ne lance que les couches
      # unitaire et intégration.
      git -C "$dossier" diff --relative "$point...HEAD" >"$travail/$i.diff" 2>/dev/null
      (cd "$dossier" && lancer "$journal" cargo mutants --in-diff "$(natif "$travail/$i.diff")" --output "$(natif "$travail/$i.out")") || code=$?
      if [[ -f $travail/$i.out/mutants.out/missed.txt ]]; then
        resultats_rust "$travail/$i.out/mutants.out/missed.txt" >"$trouves"
      elif [[ $code -ne 124 ]]; then
        echo "non muté | $nom | échec de l'outil (code $code)"
        continue
      fi
      ;;
    typescript)
      mutate="$(IFS=,; printf '%s' "${liste[*]}")"
      (cd "$dossier" && lancer "$journal" npx --no-install stryker run --mutate "$mutate" --reporters clear-text) || code=$?
      if [[ $code -ne 0 && $code -ne 124 ]]; then
        echo "non muté | $nom | échec de l'outil (code $code)"
        continue
      fi
      resultats_typescript "$journal" "$dossier" >"$trouves"
      ;;
    python)
      declare -A module_de=()
      motifs=()
      for f in "${liste[@]}"; do
        m="${f%.py}"
        m="${m//\//.}"
        m="${m#src.}"
        m="${m%.__init__}"
        module_de[$m]=$f
        motifs+=("$m.x*")
      done
      (cd "$dossier" && PYTEST_ADDOPTS="${PYTEST_ADDOPTS:+$PYTEST_ADDOPTS }--ignore=tests/fonctionnels" \
        lancer "$journal" uv run mutmut run "${motifs[@]}") || code=$?
      # Après le délai, `mutmut results` prendrait encore du temps : rien n'est lu.
      if [[ $code -ne 124 ]]; then
        if ! (cd "$dossier" && uv run mutmut results >"$travail/$i.res" 2>/dev/null); then
          echo "non muté | $nom | échec de l'outil (code $code)"
          unset module_de
          continue
        fi
        while IFS= read -r mutant; do
          m="${mutant%.*}"
          [[ -n ${module_de[$m]+x} ]] || continue
          f=${module_de[$m]}
          origine="$(cd "$dossier" && uv run mutmut show "$mutant" 2>/dev/null | tr -d '\r' |
            sed -n '/^@@/,$p' | sed -n 's/^-\(.*\)$/\1/p' | head -1)"
          ligne="?"
          [[ -n $origine && -f $dossier/$f ]] && ligne="$(ligne_dans "$dossier/$f" "$origine")"
          printf '%s\t%s\t%s\n' "$f" "$ligne" "$mutant" >>"$trouves"
        done < <(tr -d '\r' <"$travail/$i.res" | sed -n 's/^ *\([^ :]*\): survived$/\1/p')
      fi
      unset module_de
      ;;
  esac
  while IFS=$'\t' read -r f ligne texte; do
    [[ -n $f ]] || continue
    echo "survivant | $nom | $prefixe$f:$ligne | $texte"
    survivants=$((survivants + 1))
  done <"$trouves"
  [[ $code -eq 124 ]] && echo "non muté | $nom | délai dépassé"
done
echo "mutation : $survivants survivants"
exit 0
