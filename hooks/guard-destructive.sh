#!/usr/bin/env bash
# Hook PreToolUse sur Bash : demande à l'utilisateur de confirmer une commande
# destructrice ou la lecture d'un fichier de secrets par une commande Bash.
#
# Commandes visées : `git reset --hard`, `git clean -f`, `git push --force` sans
# `--force-with-lease`, `git branch -D`, `git checkout .` et `git restore .` sur un
# arbre modifié, `rm -rf` sur la racine du dépôt ou hors de lui, et `cat`, `less`,
# `source`, `cp`… sur `.env*` (sauf `.env.example`), `*.pem`, `*.key`, `id_rsa*`,
# `id_ed25519*`, `id_ecdsa*`, `credentials*`.
#
# Avec `hook_destructif=demande` (défaut), écrit `permissionDecision: "ask"` et sort
# avec 0 : Claude Code demande confirmation et montre la raison à l'utilisateur.
# Avec `bloque`, sort avec 2 et la raison sur la sortie d'erreur. Avec `avertit`,
# sort avec 0 et un message pour l'utilisateur. Chaque cas visé s'ajoute à
# .izanagi/refus.log.
#
# Faits lus le 2026-11-18 :
# - https://code.claude.com/docs/en/hooks.md : `{"hookSpecificOutput":
#   {"hookEventName": "PreToolUse", "permissionDecision": "ask",
#   "permissionDecisionReason": "…"}}` avec le code 0 fait demander confirmation, et
#   la raison va à l'utilisateur. En mode `-p`, personne ne répond : l'appel est
#   refusé et Claude lit la raison. Le champ `if` ne porte qu'une règle : ce hook
#   n'en a pas, puisqu'il vise plusieurs programmes.
# - https://code.claude.com/docs/en/permissions.md : une règle `Read` refusée bloque
#   déjà `cat`, `head`, `tail` et `sed` dans Bash. Ce hook les couvre aussi, en double.
#
# C'est un garde-fou contre le geste fait par habitude, pas une barrière : il ne voit
# que la commande tapée. Une variable, un alias, un `eval` ou un script lancé par la
# commande lui échappent. L'envoi réseau (`curl`, `wget`) n'est pas visé.

# shellcheck source=../scripts/lib.sh
. "$(dirname "$0")/../scripts/lib.sh"

entree="$(cat)"
hook_enter "$entree"
racine="$(izanagi_root)" || exit 0
commande="$(json_string "$entree" command $'\n')" || exit 0
case "$commande" in
  *git* | *rm* | *env* | *.pem* | *.key* | *id_rsa* | *id_ed25519* | *id_ecdsa* | *credentials*) ;;
  *) exit 0 ;;
esac

limite=20000
if ((${#commande} > limite)); then
  printf '{"systemMessage": "Izanagi : commande de plus de %s caractères, gestes destructeurs non contrôlés."}\n' "$limite"
  exit 0
fi

# Les chemins se comparent sous la forme que donne `pwd` (/c/… sous Git Bash).
# `ici` suit les `cd` de la commande, dans l'ordre ; vide quand le hook ne peut pas
# résoudre le dossier (`cd "$X"`, `cd -`) : une cible relative compte alors comme
# hors du dépôt.
racine_abs="$(cd "$racine" && pwd)"
ici="$(pwd)"
motif=""
depot_git=""

# normaliser <chemin absolu> : retire `.`, `..` et les barres en trop, sans lire le disque.
normaliser() {
  local -a parties=() garde=()
  local p
  IFS=/ read -r -a parties <<<"$1"
  for p in "${parties[@]}"; do
    case "$p" in
      "" | .) ;;
      ..) if ((${#garde[@]})); then unset 'garde[${#garde[@]}-1]'; fi ;;
      *) garde+=("$p") ;;
    esac
  done
  local IFS=/
  printf '/%s' "${garde[*]}"
}

# absolu <chemin> : affiche le chemin absolu, résolu depuis `ici`, sans lire le disque.
# Rend 1 si le chemin ne se résout pas : variable, substitution, ou relatif à un
# dossier inconnu.
absolu() {
  local cible=$1
  [[ $cible == *'$'* || $cible == *'`'* ]] && return 1
  cible="${cible//\\//}"
  if [[ $cible == '~' || $cible == '~/'* ]]; then cible="$HOME${cible:1}"; fi
  if [[ $cible =~ ^([A-Za-z]):/(.*)$ ]]; then
    cible="/${BASH_REMATCH[1],,}/${BASH_REMATCH[2]}"
  fi
  if [[ $cible != /* ]]; then
    [[ -n $ici ]] || return 1
    cible="$ici/$cible"
  fi
  normaliser "$cible"
}

# suivre_cd <arguments de cd> : met à jour `ici` après un `cd` ou un `pushd` de la
# commande. Les options (`-P`, `-L`, `--`) ne sont pas le dossier. Sans dossier, `cd`
# va dans `$HOME` ; `cd -` et un dossier non résolu rendent `ici` inconnu.
suivre_cd() {
  while (($#)) && [[ $1 == -?* ]]; do
    if [[ $1 == -- ]]; then
      shift
      break
    fi
    shift
  done
  if (($# == 0)); then
    ici="$(normaliser "$HOME")"
  elif [[ $1 == - ]] || ! ici="$(absolu "$1")"; then
    ici=""
  fi
}

# hors_depot <cible> : rend 0 si la cible de `rm` est la racine du dépôt ou hors de lui,
# ou si elle ne se résout pas.
hors_depot() {
  local chemin
  chemin="$(absolu "$1")" || return 0
  # Un dernier segment avec un joker vaut son dossier : `rm -rf *` vise le dossier.
  if [[ ${chemin##*/} == *[*?[]* ]]; then
    chemin="${chemin%/*}"
    chemin="${chemin:-/}"
  fi
  [[ $chemin == "$racine_abs" || $chemin != "$racine_abs"/* ]]
}

# secret <chemin> : rend 0 si le nom du fichier est celui d'un fichier de secrets.
secret() {
  local nom="${1##*/}"
  [[ $nom == .env.example ]] && return 1
  case "$nom" in
    .env* | *.pem | *.key | id_rsa* | id_ed25519* | id_ecdsa* | credentials*) return 0 ;;
  esac
  return 1
}

# examine_git <sous-commande> <arguments> : rend 0 et remplit `motif` si visée.
examine_git() {
  local sous=$1 mot force=0 bail=0 supprime=0
  shift
  case "$sous" in
    reset)
      for mot in "$@"; do
        if [[ $mot == --hard ]]; then motif="git reset --hard"; return 0; fi
      done
      ;;
    clean)
      for mot in "$@"; do
        if [[ $mot == --force || $mot =~ ^-[^-]*f ]]; then motif="git clean -f"; return 0; fi
      done
      ;;
    push)
      for mot in "$@"; do
        case "$mot" in
          --force-with-lease*) bail=1 ;;
          --force) force=1 ;;
          --*) ;;
          -*f*) force=1 ;;
          +*) force=1 ;;
        esac
      done
      if ((force && !bail)); then motif="git push --force"; return 0; fi
      ;;
    branch)
      for mot in "$@"; do
        case "$mot" in
          --delete) supprime=1 ;;
          --force) force=1 ;;
          --*) ;;
          -*D*) motif="git branch -D"; return 0 ;;
          -*)
            if [[ $mot == *d* ]]; then supprime=1; fi
            if [[ $mot == *f* ]]; then force=1; fi
            ;;
        esac
      done
      if ((supprime && force)); then motif="git branch -D"; return 0; fi
      ;;
    checkout | restore)
      for mot in "$@"; do
        [[ $mot == . ]] || continue
        # L'arbre regardé est celui du dépôt visé : `git -C <dossier>`, sinon le
        # dossier courant de la commande. Un dossier inconnu demande.
        if [[ -z $depot_git ]] || [[ -n $(git -C "$depot_git" status --porcelain --untracked-files=no 2>/dev/null) ]]; then
          motif="git $sous . sur un arbre modifié"
          return 0
        fi
      done
      ;;
  esac
  return 1
}

# examine_rm <arguments> : rend 0 et remplit `motif` pour un `rm` récursif et forcé
# dont une cible est la racine du dépôt ou hors de lui.
examine_rm() {
  local mot recursif=0 force=0 fin_options=0
  local -a cibles=()
  for mot in "$@"; do
    if ((fin_options)) || [[ $mot != -* ]]; then
      cibles+=("$mot")
      continue
    fi
    case "$mot" in
      --) fin_options=1 ;;
      --recursive) recursif=1 ;;
      --force) force=1 ;;
      --*) ;;
      *)
        if [[ $mot == *[rR]* ]]; then recursif=1; fi
        if [[ $mot == *f* ]]; then force=1; fi
        ;;
    esac
  done
  ((recursif && force)) || return 1
  # Sans cible visible, la cible vient d'une substitution (`rm -rf `pwd`/x`), que le
  # découpage coupe à l'accent grave : elle est inconnue, donc hors du dépôt.
  if ((${#cibles[@]} == 0)); then
    motif="rm -rf <cible calculée>"
    return 0
  fi
  for mot in "${cibles[@]}"; do
    if hors_depot "$mot"; then motif="rm -rf $mot"; return 0; fi
  done
  return 1
}

# examine <mots> : rend 0 et remplit `motif` si la commande simple est visée.
examine() {
  local -a mots=("$@")
  local i=0 n=${#mots[@]} mot
  # Les affectations en tête (`FOO=1 cmd`) et les préfixes courants (`sudo`, `env`,
  # `command`, `time`, `nohup`, `exec`, avec leurs options) ne changent pas la commande.
  # Une option de préfixe qui prend une valeur (`sudo -u root`, `env -u NOM`) saute
  # aussi sa valeur.
  local prefixe=""
  while ((i < n)); do
    case "${mots[i]}" in
      sudo | env | command | time | nohup | exec) prefixe="${mots[i]}" ;;
      -*)
        [[ -n $prefixe ]] || break
        case "$prefixe:${mots[i]}" in
          sudo:-u | sudo:-g | sudo:-h | sudo:-p | sudo:-C | sudo:-U | sudo:-r | sudo:-t | sudo:-D | \
            env:-u | env:-C | env:-S | time:-f | time:-o) i=$((i + 1)) ;;
        esac
        ;;
      *)
        [[ ${mots[i]} =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || break
        ;;
    esac
    i=$((i + 1))
  done
  ((i < n)) || return 1
  case "${mots[i]}" in
    cd | pushd)
      suivre_cd "${mots[@]:i+1}"
      return 1
      ;;
    popd)
      ici=""
      return 1
      ;;
    git)
      depot_git="$ici"
      i=$((i + 1))
      while ((i < n)); do
        case "${mots[i]}" in
          -C)
            depot_git="$(absolu "${mots[i + 1]:-}")" || depot_git=""
            i=$((i + 2))
            ;;
          -c | --git-dir | --work-tree | --namespace) i=$((i + 2)) ;;
          -*) i=$((i + 1)) ;;
          *) break ;;
        esac
      done
      ((i < n)) && examine_git "${mots[@]:i}"
      ;;
    rm) examine_rm "${mots[@]:i+1}" ;;
    cat | less | more | head | tail | grep | source | . | cp | mv | base64 | xxd | strings)
      for mot in "${mots[@]:i+1}"; do
        [[ $mot == -* ]] && continue
        if secret "$mot"; then motif="lecture de $mot"; return 0; fi
      done
      return 1
      ;;
    *) return 1 ;;
  esac
}

commandes_simples "$commande" examine || exit 0
refus_noter "$racine" destructif "$motif"

case "$(kv_get "$racine/.izanagi/config.env" hook_destructif || true)" in
  bloque)
    echo "Izanagi : $motif refusé. Pour être consulté à la place, mets hook_destructif=demande dans .izanagi/config.env." >&2
    exit 2
    ;;
  avertit)
    printf '{"systemMessage": "Izanagi : %s."}\n' "$(json_echappe "$motif")"
    ;;
  *)
    printf '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "ask", "permissionDecisionReason": "Izanagi : %s. Confirme que cette commande est voulue."}}\n' "$(json_echappe "$motif")"
    ;;
esac
exit 0
