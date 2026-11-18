# shellcheck shell=bash
# Fonctions communes aux scripts et aux hooks d'Izanagi. À charger, pas à lancer :
#
#   . "$(dirname "$0")/lib.sh"
#
# Les fichiers lus portent une valeur par ligne (`clé=valeur`). Ils ne se chargent
# jamais avec `source` : une valeur peut contenir des espaces et des accents graves.

izanagi_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Affiche la racine git du dossier courant. Rend 1 hors d'un dépôt.
project_root() {
  git rev-parse --show-toplevel 2>/dev/null
}

# kv_get <fichier> <clé> : affiche la valeur de la dernière ligne `clé=…`, tout ce
# qui suit le premier `=`. Rend 1, sans rien afficher, si la clé ou le fichier manque.
kv_get() {
  local fichier=$1 cle=$2 ligne valeur trouve=1
  [[ -f $fichier ]] || return 1
  while IFS= read -r ligne || [[ -n $ligne ]]; do
    ligne="${ligne%$'\r'}"
    [[ -z $ligne || $ligne == \#* ]] && continue
    if [[ $ligne == "$cle="* ]]; then
      valeur="${ligne#*=}"
      trouve=0
    fi
  done <"$fichier"
  [[ $trouve -eq 0 ]] || return 1
  printf '%s\n' "$valeur"
}

# Affiche la version du plugin, lue dans son plugin.json.
plugin_version() {
  sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
    "$izanagi_lib_dir/../.claude-plugin/plugin.json" | head -1
}

# version_lt <a> <b> : rend 0 si la version a précède la version b.
version_lt() {
  local a1 a2 a3 b1 b2 b3
  IFS=. read -r a1 a2 a3 <<<"$1"
  IFS=. read -r b1 b2 b3 <<<"$2"
  # `10#` : un nombre qui commence par 0 se lit en base dix, pas en octal.
  ((10#${a1:-0} != 10#${b1:-0})) && { ((10#${a1:-0} < 10#${b1:-0})); return; }
  ((10#${a2:-0} != 10#${b2:-0})) && { ((10#${a2:-0} < 10#${b2:-0})); return; }
  ((10#${a3:-0} < 10#${b3:-0}))
}

# json_string <texte> <clé> [saut] : affiche la valeur de la première chaîne
# `"clé": "…"` d'un texte JSON, échappements défaits. Un saut de ligne devient une
# espace, ou le texte `saut` s'il est donné.
# Rend 1 si la clé manque. Suffit pour l'entrée d'un hook, sans décodeur JSON.
json_string() {
  local motif brut resultat="" i=0 c bo saut="${3- }"
  # bo : une barre oblique inverse. Le motif lit une chaîne JSON, où `bo` suivi
  # d'un caractère forme un échappement.
  bo=$(printf '%b' '\0134')
  motif='"'"$2"'"[[:space:]]*:[[:space:]]*"(([^"'"$bo"']|'"$bo$bo"'.)*)"'
  [[ $1 =~ $motif ]] || return 1
  brut="${BASH_REMATCH[1]}"
  while ((i < ${#brut})); do
    c="${brut:i:1}"
    if [[ $c == "$bo" ]]; then
      i=$((i + 1))
      c="${brut:i:1}"
      case "$c" in
        n) resultat+="$saut" ;;
        r | t) resultat+=" " ;;
        u) resultat+="${bo}u" ;;
        *) resultat+="$c" ;;
      esac
    else
      resultat+="$c"
    fi
    i=$((i + 1))
  done
  printf '%s\n' "$resultat"
}

# hook_enter <entrée JSON> : se place dans le dossier `cwd` de l'entrée d'un hook,
# s'il existe. Sinon le hook reste dans le dossier où il a été lancé.
hook_enter() {
  local dossier
  if dossier="$(json_string "$1" cwd)" && [[ -d $dossier ]]; then
    cd "$dossier" || true
  fi
}

# izanagi_root : affiche la racine du projet si c'est un projet Izanagi, c'est-à-dire
# un dépôt git dont la racine contient .izanagi/config.env. Rend 1 sinon.
izanagi_root() {
  local racine
  racine="$(project_root)" || return 1
  [[ -f $racine/.izanagi/config.env ]] || return 1
  printf '%s\n' "$racine"
}

# commandes_simples <commande> <fonction> : découpe une commande Bash en commandes
# simples et appelle `<fonction> <mot>…` pour chacune, avec ses mots. Rend 0 si au
# moins un appel de la fonction a rendu 0, et 1 sinon : « une commande est visée ».
#
# Hors guillemets, une espace finit un mot, et `;`, `&`, `|`, `(`, `)`, l'accent grave
# et le saut de ligne finissent une commande simple. Entre guillemets, tout caractère
# appartient au mot : le `;` d'un message de commit ne coupe rien. Une barre oblique
# inverse en fin de ligne continue la ligne. Le découpage ne développe ni variable,
# ni alias, ni `eval` : une commande construite pour le tromper passe.
# Le temps croît avec le carré de la longueur : limite la commande avant l'appel.
commandes_simples() {
  local commande=$1 fonction=$2 c bo n k=0 mot="" dans_mot=0 guillemet="" vise=1
  local -a mots=()
  bo=$(printf '%b' '\0134')
  n=${#commande}
  while ((k <= n)); do
    if ((k == n)); then
      c=$'\n'
    else
      c="${commande:k:1}"
    fi
    if [[ -n $guillemet ]] && ((k < n)); then
      if [[ $c == "$guillemet" ]]; then
        guillemet=""
      elif [[ $c == "$bo" && $guillemet == '"' ]]; then
        k=$((k + 1))
        mot+="${commande:k:1}"
      else
        mot+="$c"
      fi
    else
      case "$c" in
        '"' | "'")
          guillemet="$c"
          dans_mot=1
          ;;
        "$bo")
          k=$((k + 1))
          if [[ ${commande:k:1} != $'\n' ]]; then
            mot+="${commande:k:1}"
            dans_mot=1
          fi
          ;;
        ' ' | $'\t')
          if ((dans_mot)); then mots+=("$mot"); fi
          mot=""
          dans_mot=0
          ;;
        ';' | '&' | '|' | '(' | ')' | '`' | $'\n')
          if ((dans_mot)); then mots+=("$mot"); fi
          mot=""
          dans_mot=0
          if ((${#mots[@]})) && "$fonction" "${mots[@]}"; then vise=0; fi
          mots=()
          ;;
        *)
          mot+="$c"
          dans_mot=1
          ;;
      esac
    fi
    k=$((k + 1))
  done
  return "$vise"
}

# refus_noter <racine> <hook> <motif> : ajoute à .izanagi/refus.log la ligne
# `<date UTC>|<branche courante>|<hook>|<motif>`, que la rétrospective lit. Les `|` et
# les sauts de ligne du motif deviennent des espaces. N'échoue jamais : une écriture
# ratée ne change pas la décision du hook.
refus_noter() {
  local racine=$1 hook=$2 motif=$3 branche
  branche="$(git -C "$racine" rev-parse --abbrev-ref HEAD 2>/dev/null || echo inconnue)"
  motif="${motif//|/ }"
  motif="${motif//$'\n'/ }"
  printf '%s|%s|%s|%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$branche" "$hook" "$motif" \
    >>"$racine/.izanagi/refus.log" 2>/dev/null || true
}

# json_echappe <texte> : affiche le texte prêt à entrer entre guillemets dans du JSON.
json_echappe() {
  local t=$1 bo
  bo=$(printf '%b' '\0134')
  t="${t//"$bo"/"$bo$bo"}"
  t="${t//\"/"$bo"\"}"
  t="${t//$'\n'/ }"
  printf '%s' "$t"
}
