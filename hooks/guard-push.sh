#!/usr/bin/env bash
# Hook PreToolUse sur Bash : refuse un `git push` qui vise la branche principale
# du projet (clé `branche` de .izanagi/config.env).
#
# Avec `hook_push=bloque` (défaut), sort avec 2 et la raison sur la sortie d'erreur.
# Avec `hook_push=avertit`, sort avec 0 et un message pour l'utilisateur.
# Un push de tags seuls, une suppression de branche et tout autre push passent.
#
# Le script lit la commande dans l'entrée JSON et la découpe en mots, guillemets
# compris. C'est un garde-fou contre un push fait par habitude, pas une barrière :
# une commande construite pour le tromper (variable, alias, eval) passe.

# shellcheck source=../scripts/lib.sh
. "$(dirname "$0")/../scripts/lib.sh"

entree="$(cat)"
hook_enter "$entree"
racine="$(izanagi_root)" || exit 0
commande="$(json_string "$entree" command $'\n')" || exit 0
[[ $commande == *git*push* ]] || exit 0

principale="$(kv_get "$racine/.izanagi/config.env" branche || true)"
[[ -n $principale ]] || exit 0
courante="$(git -C "$racine" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"

# vise_principale <mots après `push`> : rend 0 si ce push vise la branche principale.
vise_principale() {
  local mot dest tags=0 saute=0 refs=() positionnels=()
  for mot in "$@"; do
    if ((saute)); then
      saute=0
      continue
    fi
    case "$mot" in
      --delete | -d) return 1 ;;
      # Toutes les branches partent, la principale avec.
      --all | --mirror | --branches) return 0 ;;
      --tags) tags=1 ;;
      # Le dépôt distant est donné par l'option : tout mot sans tiret est une référence.
      --repo=*) positionnels=(depot "${positionnels[@]}") ;;
      -o | --push-option | --receive-pack | --exec) saute=1 ;;
      -*) ;;
      *) positionnels+=("$mot") ;;
    esac
  done
  # Le premier mot sans tiret est le dépôt distant, les suivants des références.
  refs=("${positionnels[@]:1}")
  if [[ ${#refs[@]} -eq 0 ]]; then
    # `--tags` sans référence ne pousse que des tags.
    ((tags)) && return 1
    [[ $courante == "$principale" ]]
    return
  fi
  for mot in "${refs[@]}"; do
    mot="${mot#+}"
    dest="${mot##*:}"
    [[ $dest == refs/tags/* ]] && continue
    dest="${dest#refs/heads/}"
    if [[ $dest == HEAD ]]; then dest="$courante"; fi
    [[ $dest == "$principale" ]] && return 0
  done
  return 1
}

vise=1
mots=()
mot=""
dans_mot=0
guillemet=""

fin_mot() {
  if ((dans_mot)); then mots+=("$mot"); fi
  mot=""
  dans_mot=0
}

# Examine la commande simple lue dans `mots`, puis la vide. Cherche `git … push` :
# `push` est le premier mot sans tiret après `git`, une fois sautées les options
# de git et la valeur de celles qui en prennent une.
fin_commande() {
  local i=0 n
  fin_mot
  n=${#mots[@]}
  while ((i < n)) && [[ ${mots[i]} != git ]]; do i=$((i + 1)); done
  i=$((i + 1))
  while ((i < n)); do
    case "${mots[i]}" in
      -C | -c | --git-dir | --work-tree | --namespace) i=$((i + 2)) ;;
      -*) i=$((i + 1)) ;;
      *) break ;;
    esac
  done
  if ((i < n)) && [[ ${mots[i]} == push ]] && vise_principale "${mots[@]:i+1}"; then
    vise=0
  fi
  mots=()
}

# Lit la commande caractère par caractère. Hors guillemets, une espace finit un mot
# et un séparateur du shell finit une commande simple. Entre guillemets, tout
# caractère appartient au mot : le `;` d'un message de commit ne coupe rien.
bo=$(printf '%b' '\0134')
# Le temps de cette boucle croît avec le carré de la longueur de la commande :
# environ deux secondes pour 20 Ko sous Git Bash, mesurées le 2026-11-13.
n=${#commande}
k=0
while ((k < n)); do
  c="${commande:k:1}"
  if [[ -n $guillemet ]]; then
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
        # Une barre oblique inverse en fin de ligne continue la ligne.
        k=$((k + 1))
        if [[ ${commande:k:1} != $'\n' ]]; then
          mot+="${commande:k:1}"
          dans_mot=1
        fi
        ;;
      ' ' | $'\t') fin_mot ;;
      ';' | '&' | '|' | '(' | ')' | '`' | $'\n') fin_commande ;;
      *)
        mot+="$c"
        dans_mot=1
        ;;
    esac
  fi
  k=$((k + 1))
done
fin_commande

[[ $vise -eq 0 ]] || exit 0

if [[ $(kv_get "$racine/.izanagi/config.env" hook_push || true) == avertit ]]; then
  printf '{"systemMessage": "Izanagi : push direct sur %s."}\n' "$principale"
  exit 0
fi
echo "Izanagi : push direct sur $principale refusé. Passe par une PR. Pour l'autoriser, mets hook_push=avertit dans .izanagi/config.env." >&2
exit 2
