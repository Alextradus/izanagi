#!/usr/bin/env bash
# Vérifications du dépôt, celles de la CI : une section par composant.
#
#   scripts/check.sh            systèmes cibles atteignables (WSL sous Windows)
#   scripts/check.sh --host     système courant s'il est une cible, sinon la
#                               copie WSL sous Windows (hook pre-push, CI)
#   scripts/check.sh --complet  ajoute les étapes fonctionnelles (options combinables
#                               avec --host, dans tout ordre)
#   scripts/check.sh --clean    vide les caches de vérification (seul)
#
# Sort en erreur au premier échec.
set -euo pipefail

cd "$(dirname "$0")/.."

# Systèmes à vérifier. Sous Windows, `linux` veut dire : dans WSL.
cibles="{{systemes}}"
cache_wsl='.cache/{{projet_dossier}}-wsl'
principale='{{branche}}'

case "$(uname -s)" in
  MINGW* | MSYS* | CYGWIN*) systeme=windows ;;
  Darwin*) systeme=macos ;;
  *) systeme=linux ;;
esac

host_only=false
complet=false
nettoyer=false
for argument in "$@"; do
  case "$argument" in
    --host) host_only=true ;;
    --complet) complet=true ;;
    --clean) nettoyer=true ;;
    *) usage_faux=true ;;
  esac
done
# `--clean` ne se combine avec rien : ni avec une autre option, ni avec lui-même.
if [[ ${usage_faux:-false} == true ]] || { $nettoyer && [[ $# -ne 1 ]]; }; then
  echo "usage : scripts/check.sh [--host] [--complet] | --clean" >&2
  exit 2
fi
if $nettoyer; then
  if [[ $systeme != windows ]]; then
    echo "rien à vider"
  elif ! command -v wsl.exe >/dev/null; then
    echo "wsl : absent, rien à vider"
  else
    # `--exec` ne développe pas $HOME : le shell de WSL s'en charge.
    wsl.exe --exec bash -c 'rm -rf "$HOME/$0"' "$cache_wsl"
    echo "cache WSL vidé"
  fi
  exit 0
fi

# Cherche des secrets dans les commits de la branche absents de la branche principale,
# avec gitleaks et .gitleaks.toml. Ne dépend pas du système : tourne une fois, sur le
# poste. Hors d'un dépôt git, comme dans la copie WSL, l'étape est sautée.
verifier_secrets() {
  local plage=""
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "-- secrets : pas de dépôt git, sauté"
    return 0
  fi
  if ! command -v gitleaks >/dev/null; then
    echo "-- secrets : gitleaks absent, voir /izanagi:doctor" >&2
    return 1
  fi
  if git rev-parse -q --verify "refs/heads/$principale" >/dev/null; then
    plage="$principale..HEAD"
  elif git rev-parse -q --verify "refs/remotes/origin/$principale" >/dev/null; then
    plage="origin/$principale..HEAD"
  fi
  if [[ -n $plage ]]; then
    echo "-- secrets : $plage"
    gitleaks git --redact --no-banner --log-opts="$plage" .
  else
    echo "-- secrets : branche principale introuvable, analyse de tout l'historique"
    gitleaks git --redact --no-banner .
  fi
}

{{sections}}

verifier_tout() {
{{appels}}
}

# Étapes de l'option `--complet`, après celles de `verifier_tout`. Les appels
# viennent des fonctions `verifier_<id>_fonctionnelle` des composants et de
# `verifier_projet_fonctionnelle`, quand le projet en a.
verifier_tout_complet() {
{{appels_complets}}
}

# Copie le dépôt dans WSL, hors de /mnt/c où les I/O sont lentes, et y lance
# `check.sh --host`. La copie contient les fichiers suivis et les fichiers non
# suivis non ignorés. Les dépendances installées (node_modules, .venv, target)
# restent dans le cache d'une exécution à l'autre : seuls les fichiers de la
# liste précédente (`.izanagi-files`) qui ont disparu du dépôt sont supprimés.
# Liste NUL des fichiers à copier : suivis et non suivis non ignorés, sans les
# fichiers suivis supprimés du disque mais pas encore retirés de l'index.
lister_fichiers() {
  local f
  git ls-files -z --cached --others --exclude-standard |
    while IFS= read -r -d '' f; do
      if [[ -e $f || -L $f ]]; then printf '%s\0' "$f"; fi
    done
}

verifier_wsl() {
  # Options transmises à la copie : `--host`, plus `--complet` si demandé.
  local options_wsl=()
  if $complet; then options_wsl+=(--complet); fi
  if ! command -v wsl.exe >/dev/null; then
    echo "wsl : absent, étape sautée"
    return 0
  fi
  echo "== wsl : copie vers ~/$cache_wsl"
  staging=$(mktemp -d)
  trap 'rm -rf "$staging"' EXIT
  lister_fichiers >"$staging/.izanagi-files.new"
  # `--exec` passe les arguments tels quels, sans le shell par défaut ;
  # `bash -l` charge le PATH de rustup, node et uv.
  tar --null --ignore-failed-read -T "$staging/.izanagi-files.new" -cf - -C "$staging" .izanagi-files.new |
    wsl.exe --exec bash -lc '
      set -euo pipefail
      dest="$HOME/${0:?}"
      mkdir -p "$dest"
      cd "$dest"
      tar -xf -
      if [[ -f .izanagi-files ]]; then
        comm -z -23 <(sort -z .izanagi-files) <(sort -z .izanagi-files.new) |
          while IFS= read -r -d "" f; do rm -f -- "$f"; done
      fi
      mv .izanagi-files.new .izanagi-files
      # WSL ajoute au PATH les dossiers de Windows (/mnt/c/...). Un outil absent
      # de Linux y serait pris dans Windows : npm installerait des binaires
      # Windows dans la copie. Sans ces dossiers, il manque franchement.
      linux_seul=""
      IFS=: read -ra dossiers <<<"$PATH"
      for d in "${dossiers[@]}"; do
        [[ $d == /mnt/* ]] || linux_seul+="${linux_seul:+:}$d"
      done
      export PATH="$linux_seul"
      # nvm se charge dans .bashrc, après la garde des shells non interactifs :
      # `bash -l` ne le voit pas. nvm.sh supporte mal `set -eu`.
      if [[ -s $HOME/.nvm/nvm.sh ]]; then
        set +eu
        . "$HOME/.nvm/nvm.sh"
        set -eu
      fi
      exec bash scripts/check.sh --host "$@"
    ' "$cache_wsl" ${options_wsl[@]+"${options_wsl[@]}"}
}

# Le script ne vérifie le système courant que s'il est une cible. Sous Windows,
# `linux` dans les cibles fait vérifier la copie WSL : toujours sans argument,
# et avec `--host` quand Windows n'est pas une cible.
hote_cible=false
[[ ",$cibles," == *",$systeme,"* ]] && hote_cible=true
wsl_cible=false
[[ $systeme == windows && ",$cibles," == *,linux,* ]] && wsl_cible=true

verifier_secrets

if $hote_cible; then
  echo "== $systeme"
  verifier_tout
  if $complet; then
    verifier_tout_complet
    echo "$systeme : tout passe (complet)"
  else
    echo "$systeme : tout passe"
  fi
elif ! $host_only || ! $wsl_cible; then
  echo "$systeme : hors des cibles, sauté"
fi

if $wsl_cible && { ! $host_only || ! $hote_cible; }; then
  verifier_wsl
fi
