#!/usr/bin/env bash
# Hook PreToolUse sur Bash : refuse un `git push` qui vise la branche principale
# du projet (clé `branche` de .izanagi/config.env).
#
# Avec `hook_push=bloque` (défaut), sort avec 2 et la raison sur la sortie d'erreur.
# Avec `hook_push=avertit`, sort avec 0 et un message pour l'utilisateur.
# Un push de tag, une suppression de branche et tout autre push passent.
#
# Le script lit la commande dans l'entrée JSON et la découpe en mots. C'est un
# garde-fou contre un push fait par habitude, pas une barrière : une commande
# construite pour le tromper (variable, alias, sous-shell) passe.

# shellcheck source=../scripts/lib.sh
. "$(dirname "$0")/../scripts/lib.sh"

entree="$(cat)"
hook_enter "$entree"
racine="$(izanagi_root)" || exit 0
commande="$(json_string "$entree" command)" || exit 0
[[ $commande == *git*push* ]] || exit 0

principale="$(kv_get "$racine/.izanagi/config.env" branche || true)"
[[ -n $principale ]] || exit 0
courante="$(git -C "$racine" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"

# vise_principale <mots après `push`> : rend 0 si ce push vise la branche principale.
vise_principale() {
  local mot dest refs=() positionnels=()
  for mot in "$@"; do
    case "$mot" in
      --tags | --delete | -d | --mirror) return 1 ;;
      -*) ;;
      *) positionnels+=("$mot") ;;
    esac
  done
  # Le premier mot sans tiret est le dépôt distant, les suivants des références.
  refs=("${positionnels[@]:1}")
  if [[ ${#refs[@]} -eq 0 ]]; then
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

# Découpe la commande en commandes simples, puis chacune en mots sans guillemets.
vise=1
simples="${commande//&&/$'\n'}"
simples="${simples//||/$'\n'}"
simples="${simples//;/$'\n'}"
simples="${simples//|/$'\n'}"
while IFS= read -r simple; do
  simple="${simple//\"/}"
  simple="${simple//\'/}"
  read -r -a mots <<<"$simple"
  # Cherche `git … push` : `push` est le premier mot sans tiret après `git`,
  # une fois sautées les options de git et la valeur de `-C` ou `-c`.
  i=0
  while ((i < ${#mots[@]})) && [[ ${mots[i]} != git ]]; do i=$((i + 1)); done
  ((i < ${#mots[@]})) || continue
  i=$((i + 1))
  while ((i < ${#mots[@]})); do
    case "${mots[i]}" in
      -C | -c) i=$((i + 2)) ;;
      -*) i=$((i + 1)) ;;
      *) break ;;
    esac
  done
  [[ ${mots[i]:-} == push ]] || continue
  if vise_principale "${mots[@]:i+1}"; then
    vise=0
    break
  fi
done <<<"$simples"

[[ $vise -eq 0 ]] || exit 0

if [[ $(kv_get "$racine/.izanagi/config.env" hook_push || true) == avertit ]]; then
  printf '{"systemMessage": "Izanagi : push direct sur %s."}\n' "$principale"
  exit 0
fi
echo "Izanagi : push direct sur $principale refusé. Passe par une PR. Pour l'autoriser, mets hook_push=avertit dans .izanagi/config.env." >&2
exit 2
