#!/usr/bin/env bash
# Contrôle le poste et le cadre Izanagi d'un projet.
#
#   doctor.sh <projet>
#
# Une ligne par contrôle : `ok      <contrôle>` ou `écart   <contrôle> : <détail>`.
# Sort avec 1 s'il y a au moins un écart, avec 2 hors d'un projet Izanagi.
# Ne lance ni install.sh ni scripts/check.sh, qui sont longs.
set -uo pipefail

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

if [[ $# -ne 1 ]]; then
  echo "usage : doctor.sh <projet>" >&2
  exit 2
fi
cible="$(cd "$1" 2>/dev/null && pwd)" || {
  echo "doctor.sh : dossier introuvable : $1" >&2
  exit 2
}
config="$cible/.izanagi/config.env"
harness="$cible/docs/agents/harness.md"
if [[ ! -f $config && ! -f $cible/docs/agents/jalon.md ]]; then
  echo "doctor.sh : pas un projet Izanagi" >&2
  exit 2
fi

ecarts=0
ok() { echo "ok      $1"; }
ecart() {
  echo "écart   $1 : $2"
  ecarts=$((ecarts + 1))
}
outil() { # outil <commande>
  if command -v "$1" >/dev/null 2>&1; then ok "outil $1"; else ecart "outil $1" "absent du PATH"; fi
}

# --- Poste ---
outil git
outil bash
outil gh
if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then ok "gh connecté"; else ecart "gh connecté" "lance gh auth login"; fi
fi

systemes=""
piles=""
if [[ -f $harness ]]; then
  systemes="$(sed -n 's/^- \*\*Systèmes cibles\*\* : \(.*\)\.$/\1/p' "$harness" | tr -d '\r')"
  piles="$(sed -n 's/^- composant : [^|]*|[^|]*| *\([a-z0-9-]*\) *|.*$/\1/p' "$harness" | sort -u)"
fi
case "$(uname -s)" in
  MINGW* | MSYS* | CYGWIN*)
    if [[ ,$systemes, == *,linux,* ]]; then
      if wsl.exe --exec true >/dev/null 2>&1; then ok "wsl"; else ecart "wsl" "linux est une cible et WSL ne répond pas"; fi
    fi
    ;;
esac
# La recherche de secrets de check.sh demande gitleaks dès qu'il y a un composant.
[[ -n $piles ]] && outil gitleaks
for pile in $piles; do
  case "$pile" in
    rust) outil cargo ;;
    typescript)
      outil node
      outil npm
      ;;
    python) outil uv ;;
  esac
done

# --- Projet ---
if [[ -f $cible/scripts/check.sh ]]; then
  chemin_hooks="$(git -C "$cible" config core.hooksPath 2>/dev/null || true)"
  if [[ $chemin_hooks == .githooks ]]; then
    ok "hook pre-push"
  else
    ecart "hook pre-push" "core.hooksPath ne vaut pas .githooks : lance git config core.hooksPath .githooks"
  fi
fi

if [[ -f $config ]]; then
  manquantes=""
  re_gabarit='^([a-z_]+)=\{\{[a-z_]+\}\}$'
  while IFS= read -r ligne || [[ -n $ligne ]]; do
    ligne="${ligne%$'\r'}"
    [[ $ligne =~ $re_gabarit ]] || continue
    cle="${BASH_REMATCH[1]}"
    # `chemins_sensibles` peut rester vide : la ligne doit seulement exister.
    if [[ $cle == chemins_sensibles ]]; then
      kv_get "$config" "$cle" >/dev/null || manquantes+="${manquantes:+, }$cle"
      continue
    fi
    valeur="$(kv_get "$config" "$cle" || true)"
    [[ -n $valeur ]] || manquantes+="${manquantes:+, }$cle"
  done <"$izanagi_lib_dir/../templates/core/.izanagi/config.env"
  if [[ -z $manquantes ]]; then ok "config.env"; else ecart "config.env" "clés absentes ou vides : $manquantes"; fi

  cadre="$(kv_get "$config" izanagi_version || true)"
  plugin="$(plugin_version)"
  if [[ $cadre == "$plugin" ]]; then
    ok "version du cadre"
  else
    ecart "version du cadre" "cadre en ${cadre:-inconnue}, plugin en $plugin : lance /izanagi:upgrade"
  fi

  for cle in hook_push hook_verification; do
    valeur="$(kv_get "$config" "$cle" || true)"
    if [[ $valeur == bloque ]]; then ok "$cle"; else ecart "$cle" "en avertissement (${valeur:-absent})"; fi
  done
  valeur="$(kv_get "$config" hook_destructif || true)"
  if [[ $valeur == demande || $valeur == bloque ]]; then
    ok hook_destructif
  else
    ecart hook_destructif "en avertissement (${valeur:-absent})"
  fi
else
  ecart "config.env" "absent : lance /izanagi:upgrade"
fi

# Règles `permissions.deny` de .claude/settings.json : cherchées comme texte entre
# guillemets, sans décodeur JSON. La liste est celle du gabarit.
manquantes=""
reglages="$cible/.claude/settings.json"
while IFS= read -r regle; do
  grep -qF "\"$regle\"" "$reglages" 2>/dev/null || manquantes+="${manquantes:+, }$regle"
done < <(sed -n 's/^ *"\(\(Read\|Edit\)([^"]*)\)",\{0,1\}$/\1/p' "$izanagi_lib_dir/../templates/core/.claude/settings.json")
if [[ -z $manquantes ]]; then
  ok permissions
else
  ecart permissions "règles absentes de .claude/settings.json : $manquantes"
fi

# Actions de la CI épinglées par le SHA d'un commit. Une action locale (`./…`) ou une
# image (`docker://…`) n'a rien à épingler.
non_epinglees=""
for wf in "$cible"/.github/workflows/*.yml "$cible"/.github/workflows/*.yaml; do
  [[ -f $wf ]] || continue
  while IFS=: read -r num ligne; do
    action="$(sed -E 's/^[[:space:]]*-?[[:space:]]*uses:[[:space:]]*([^[:space:]#]+).*/\1/' <<<"$ligne")"
    [[ $action =~ @[0-9a-f]{40}$ || $action == ./* || $action == docker://* ]] && continue
    non_epinglees+="${non_epinglees:+, }${wf##*/}:$num $action"
  done < <(grep -nE '^[[:space:]]*-?[[:space:]]*uses:' "$wf" | tr -d '\r')
done
if [[ -z $non_epinglees ]]; then
  ok "actions épinglées"
else
  ecart "actions épinglées" "$non_epinglees"
fi

if [[ -f $harness ]]; then
  contrat="$(bash "$izanagi_lib_dir/check-contract.sh" "$cible" 2>&1 || true)"
  if grep -qE '^contrat : (respecté|aucun composant)' <<<"$contrat"; then
    ok "contrat"
  else
    ecart "contrat" "$(grep -c '^contrat : ' <<<"$contrat") règle(s) enfreinte(s) : lance check-contract.sh pour le détail"
  fi
else
  ecart "contrat" "docs/agents/harness.md absent : lance /izanagi:upgrade"
fi

# Cohérence de l'état avec git : git l'emporte, ce contrôle signale l'écart.
etat="$cible/.izanagi/state.env"
branche="$(git -C "$cible" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
principale="$(kv_get "$config" branche || true)"
if [[ -f $etat ]]; then
  flux="$(kv_get "$etat" flux || true)"
  nom="$(kv_get "$etat" nom || true)"
  plan="$(kv_get "$etat" plan || true)"
  correctif="$(kv_get "$etat" correctif || true)"
  re_tranche="^$flux/$nom(-t[0-9]+)?\$"
  if [[ $branche == "$principale" ]]; then
    ecart "état" "state.env sur la branche principale, qui n'en porte jamais"
  elif [[ -n $correctif && $branche != "fix/$correctif" ]]; then
    ecart "état" "correctif « $correctif » resté dans l'état, la branche courante est $branche"
  elif [[ -n $correctif ]]; then
    # Un correctif né d'un jalon garde l'état du jalon sur sa branche fix/<nom>.
    ok "état"
  elif [[ ! $branche =~ $re_tranche ]]; then
    ecart "état" "state.env décrit le flux $flux « $nom », la branche courante est $branche"
  elif [[ -n $plan && ! -f $cible/$plan ]]; then
    ecart "état" "le plan $plan n'existe pas"
  else
    ok "état"
  fi
else
  ok "état"
fi

if [[ -f $cible/docs/agents/jalon.md ]]; then
  ecart "jalon.md" "docs/agents/jalon.md date d'avant la 0.4 : lance /izanagi:upgrade"
else
  ok "jalon.md"
fi

[[ $ecarts -eq 0 ]]
