#!/usr/bin/env bash
# Contrôle le contrat de vérification d'un projet posé par install.sh.
#
#   check-contract.sh <projet>
#
# Sort 0 et affiche `contrat : respecté` quand tout est conforme. Sinon
# affiche une ligne `contrat : <fichier> : <règle enfreinte>` par écart et
# sort 1. N'écrit rien dans le projet.
set -euo pipefail

if [[ $# -ne 1 || ! -d $1 ]]; then
  echo "usage : check-contract.sh <projet>" >&2
  exit 2
fi
projet="$(cd "$1" && pwd)"

ecarts=0
ecart() {
  echo "contrat : $1 : $2"
  ecarts=$((ecarts + 1))
}

harness=docs/agents/harness.md
check=scripts/check.sh
ci=.github/workflows/ci.yml
dev=scripts/dev.sh
secu=.github/workflows/securite.yml

# Règle 8 : harness.md existe.
if [[ ! -f $projet/$harness ]]; then
  ecart "$harness" "fichier absent"
  exit 1
fi

# Composants et systèmes déclarés dans harness.md.
noms=()
while IFS= read -r ligne; do
  ligne="${ligne%$'\r'}"
  nom="${ligne#- composant : }"
  nom="${nom%% |*}"
  noms+=("$nom")
done < <(grep -E '^- composant : ' "$projet/$harness" || true)
systemes="$(sed -n 's/^- \*\*Systèmes cibles\*\* : \(.*\)\.\r\{0,1\}$/\1/p' "$projet/$harness" | head -1)"

if [[ ${#noms[@]} -eq 0 ]]; then
  echo "contrat : aucun composant, rien à vérifier"
  exit 0
fi

# Lignes d'un fichier hors commentaires (les lignes qui commencent par `#`).
sans_commentaires() { tr -d '\r' <"$1" | grep -vE '^[[:space:]]*#' || true; }

# Règle 1 : check.sh existe, est exécutable, est du shell valide.
syntaxe_ok=false
if [[ ! -f $projet/$check ]]; then
  ecart "$check" "fichier absent"
elif [[ ! -x $projet/$check ]]; then
  ecart "$check" "pas exécutable"
elif ! bash -n "$projet/$check" 2>/dev/null; then
  ecart "$check" "erreur de syntaxe (bash -n)"
else
  syntaxe_ok=true
fi

if [[ -f $projet/$check ]]; then
  # Règle 3 : --host et --clean, seuls ou en alternative (`--host|-h)`), avec
  # ou sans guillemets (`"--host")`, `'--host')`).
  gere_host=false
  for option in --host --clean; do
    if grep -qE -- "(^|[|[:space:]])[\"']?$option[\"']?[|)]" "$projet/$check"; then
      [[ $option == --host ]] && gere_host=true
    else
      ecart "$check" "ne gère pas $option"
    fi
  done
  # Règle 2 : une option inconnue sort avec 2, sans rien vérifier. Elle ne
  # s'exécute que si check.sh lit ses arguments (un cas `--host)`) : sinon le
  # script lancerait toute la vérification. Délai d'attente : 20 s.
  if $syntaxe_ok && $gere_host; then
    code=0
    delai="${IZANAGI_CONTRAT_DELAI:-20}"
    if command -v timeout >/dev/null; then
      (cd "$projet" && timeout "$delai" bash "$check" --inconnu >/dev/null 2>&1) || code=$?
    else
      (cd "$projet" && bash "$check" --inconnu >/dev/null 2>&1) || code=$?
    fi
    [[ $code -eq 2 ]] || ecart "$check" "une option inconnue doit sortir avec le code 2 sans rien lancer"
  fi
  # Règle 9 : la recherche de secrets.
  grep -qF 'gitleaks git' "$projet/$check" || ecart "$check" "ne lance pas la recherche de secrets (gitleaks git)"
  # Règle 5 : une section par composant.
  for nom in "${noms[@]}"; do
    grep -qF -- "# --- composant $nom (" "$projet/$check" || ecart "$check" "pas de section pour le composant $nom"
  done
fi

# Règle 4 : aucun À ÉCRIRE.
for f in "$check" "$ci" "$secu" "$dev"; do
  if [[ -f $projet/$f ]] && grep -qF 'À ÉCRIRE' "$projet/$f"; then
    ecart "$f" "contient À ÉCRIRE, à remplir"
  fi
done

# Règle 6 : installations sans verrou.
for f in "$check" "$ci" "$dev"; do
  [[ -f $projet/$f ]] || continue
  texte="$(sans_commentaires "$projet/$f")"
  motifs=(
    '(^|[^[:alnum:]_-])npm (install|i)( |$)'
    '(^|[^[:alnum:]_-])pip3? install'
  )
  for motif in "${motifs[@]}"; do
    if grep -qE "$motif" <<<"$texte"; then
      ecart "$f" "installation sans verrou : $(grep -oE "$motif" <<<"$texte" | head -1 | sed 's/^[^[:alnum:]]//') (utilise npm ci, uv sync --locked ou un fichier de verrou)"
    fi
  done
  if grep -E '(^|[^[:alnum:]_-])uv sync' <<<"$texte" | grep -v -- '--locked' >/dev/null; then
    ecart "$f" "uv sync sans verrou : ajoute --locked"
  fi
  if grep -E '(^|[^[:alnum:]_-])cargo (build|test|clippy)' <<<"$texte" | grep -v -- '--locked' >/dev/null; then
    ecart "$f" "cargo sans verrou : ajoute --locked"
  fi
done

# Règle 7 : la CI lance check.sh --host, sur les systèmes de harness.md.
if [[ -f $projet/$ci ]]; then
  grep -qF 'bash scripts/check.sh --host' "$projet/$ci" || ecart "$ci" "ne lance pas bash scripts/check.sh --host"
  attendu=""
  IFS=',' read -r -a liste <<<"$systemes"
  for s in "${liste[@]}"; do
    # « linux, windows » : les espaces autour des virgules ne comptent pas.
    s="${s//[[:space:]]/}"
    case "$s" in
      linux) attendu+="ubuntu-latest"$'\n' ;;
      windows) attendu+="windows-latest"$'\n' ;;
      macos) attendu+="macos-latest"$'\n' ;;
    esac
  done
  ligne_os="$(grep -E '^[[:space:]]*os:[[:space:]]*\[' "$projet/$ci" | head -1 || true)"
  if [[ -z $ligne_os ]]; then
    ecart "$ci" "pas de ligne os: [..]"
  else
    trouve="$(sed 's/^[^[]*\[\(.*\)\].*$/\1/' <<<"$ligne_os" | tr -d ' \r' | tr ',' '\n' | sort -u)"
    voulu="$(printf '%s' "$attendu" | sort -u)"
    [[ $trouve == "$voulu" ]] || ecart "$ci" "os: ne correspond pas aux systèmes de $harness ($systemes)"
  fi
fi

if [[ $ecarts -eq 0 ]]; then
  echo "contrat : respecté"
else
  exit 1
fi
