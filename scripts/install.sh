#!/usr/bin/env bash
# Pose les gabarits d'Izanagi dans un projet, sans rien écraser.
#
#   install.sh <projet> <fichier-valeurs>
#
# Le fichier de valeurs porte une valeur par ligne (`clé=valeur`), dont
# `composant=<nom>|<chemin>|<pile>|<lancement>|<couches>[|<ancienne>]` (répétable,
# un par composant ; `<couches>` pris dans `unitaire,integration,fonctionnelle`, vide
# vaut `unitaire` ; `<ancienne>`, que donne upgrade, est l'ancienne commande de
# tests : l'étape unitaire la garde tant que la couche unitaire du gabarit ne peut
# pas tourner, voir unitaire_prete), `fonctionnel_projet=<dossier>|<commande>` (facultatif),
# `navigateur` (`oui` quand une couche fonctionnelle emploie Playwright,
# `non` par défaut) et `systemes` (sous-ensemble de `linux,windows,macos`). Sans ligne
# `composant=`, `pile=<p>` (autre que `aucune`) crée le composant `<p>|.|<p>|`.
# Les valeurs se superposent dans cet ordre : templates/core/defaults.env,
# templates/<pile>/defaults.env de chaque pile, puis le fichier passé en
# argument. `izanagi_version` vaut la version du plugin, sauf si le fichier de
# valeurs la donne. `hook_push` et `hook_verification` valent `bloque` ou `avertit`,
# `hook_destructif` vaut `demande`, `bloque` ou `avertit`. `mutation` vaut `oui`
# quand toutes les piles des composants ont un gabarit, `non` sinon, sauf si le
# fichier de valeurs la donne. `version_composant` nomme le composant dont
# release.yml lit la version (vide : le premier) ; un nom inconnu sort avec 1.
# config.env porte la valeur effective, `langue_publique` (`fr` par défaut) et lui.
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
# shellcheck source=lib.sh
. "$racine/scripts/lib.sh"
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
# `pile` désigne aussi un dossier de gabarits : les dossiers réservés, posés
# selon d'autres clés, ne sont pas des piles. Sans ce refus, `pile=vault` avec
# une ligne `composant=` poserait `vault.md` sans vault.
if [[ $pile != aucune && ( ! $pile =~ ^[a-z0-9-]+$ || $pile =~ ^(core|code|vault|multi)$ ) ]]; then
  echo "install.sh : pile « $pile » refusée" >&2
  exit 2
fi
if [[ $pile != aucune && ! -d $racine/templates/$pile ]]; then
  echo "install.sh : pas de gabarit pour la pile « $pile »" >&2
  exit 2
fi

# Composants : `nom|chemin|pile|lancement|couches`, dans l'ordre du fichier.
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
  IFS='|' read -r c_nom c_chemin c_pile c_lancement c_couches c_ancienne <<<"$entree"
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
  IFS=',' read -r -a liste_couches <<<"$c_couches"
  for c in "${liste_couches[@]}"; do
    c="${c// /}"
    if [[ -n $c && ! $c =~ ^(unitaire|integration|fonctionnelle)$ ]]; then
      echo "install.sh : couche « $c » du composant $c_nom refusée" >&2
      exit 1
    fi
  done
done

# Couches déclarées d'un composant, dans l'ordre unitaire, integration,
# fonctionnelle, séparées par des espaces. Prend le cinquième champ de
# `composant=` ; vide, il vaut `unitaire`.
couches_de() {
  local champ=",${1// /}," c sortie=""
  for c in unitaire integration fonctionnelle; do
    [[ $champ == *",$c,"* ]] && sortie+="${sortie:+ }$c"
  done
  printf '%s' "${sortie:-unitaire}"
}

# Entrée fonctionnelle du projet : `dossier|commande`, la commande à la racine.
fonctionnel_projet="$(grep -E '^fonctionnel_projet=' "$valeurs_utilisateur" | tail -1 | cut -d= -f2- | tr -d '\r' || true)"
if [[ -n $fonctionnel_projet && ( $fonctionnel_projet != *'|'* || -z ${fonctionnel_projet%%|*} || -z ${fonctionnel_projet#*|} ) ]]; then
  echo "install.sh : fonctionnel_projet « $fonctionnel_projet » refusé : <dossier>|<commande>" >&2
  exit 2
fi
# `verifier_projet_fonctionnelle` et la ligne `- couche : projet` sont à l'entrée du projet.
if [[ -n $fonctionnel_projet && -n ${noms_vus[projet]:-} ]]; then
  echo "install.sh : composant « projet » refusé : le nom désigne l'entrée fonctionnel_projet" >&2
  exit 2
fi

# unitaire_prete <pile> <dossier du composant> : rend 0 si la couche unitaire du
# gabarit peut tourner dans le dossier. Python : un test dans tests/unitaires/.
# TypeScript : un script `test:unitaire` dans package.json. Les autres piles
# ne dépendent pas d'un dossier ou n'ont pas de gabarit : 0.
unitaire_prete() {
  case "$1" in
    python) [[ -n $(find "$2/tests/unitaires" -type f \( -name 'test_*.py' -o -name '*_test.py' \) 2>/dev/null | head -1) ]] ;;
    typescript) grep -qF '"test:unitaire"' "$2/package.json" 2>/dev/null ;;
    *) return 0 ;;
  esac
}

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
union=""
for p in "${composants[@]}"; do
  IFS='|' read -r _ _ p _ <<<"$p"
  [[ $p == aucune || -n ${piles_lues[$p]:-} ]] && continue
  piles_lues[$p]=1
  if [[ -f $racine/templates/$p/defaults.env ]]; then
    lire_valeurs "$racine/templates/$p/defaults.env"
    # `hors_revue` : union des piles, dans l'ordre des composants.
    IFS=',' read -r -a elements <<<"${valeurs[hors_revue]}"
    for e in "${elements[@]}"; do
      e="${e# }"
      [[ -n $e && ", $union, " != *", $e, "* ]] && union+="${union:+, }$e"
    done
  fi
done
[[ -n $union ]] && valeurs[hors_revue]="$union"
# Plusieurs composants : le test manuel par défaut est dev.sh, sauf si le
# fichier de valeurs en donne un.
[[ ${#composants[@]} -ge 2 ]] && valeurs[test_manuel]=scripts/dev.sh
lire_valeurs "$valeurs_utilisateur"
# Posées de nouveau : le fichier de valeurs ne doit pas écraser les valeurs calculées.
valeurs[systemes]="$systemes"
valeurs[ci_os]="[$ci_os]"

# `version_composant` : le composant qui porte la version du projet, lue par
# release.yml. Vide, elle vaut le premier composant.
if [[ -n ${valeurs[version_composant]:-} && -z ${noms_vus[${valeurs[version_composant]}]:-} ]]; then
  echo "install.sh : version_composant « ${valeurs[version_composant]} » n'est pas un composant" >&2
  exit 1
fi
# La valeur effective va dans config.env, pour qu'upgrade la retrouve : le nom
# donné, sinon le premier composant, sinon rien.
if [[ -z ${valeurs[version_composant]:-} && ${#composants[@]} -gt 0 ]]; then
  valeurs[version_composant]="${composants[0]%%|*}"
fi

# `branche` va entre guillemets dans le YAML de la CI : un `"` ou un `\`
# casserait la chaîne. Git les accepte, le gabarit non.
if [[ ${valeurs[branche]:-} == *[\"\\]* ]]; then
  echo "install.sh : branche « ${valeurs[branche]} » refusée : un \" ou un \\ casserait le YAML de la CI" >&2
  exit 2
fi

# Clés des hooks : deux valeurs permises, contrôlées avant toute écriture.
for cle_hook in hook_push hook_verification; do
  if [[ ! ${valeurs[$cle_hook]:-} =~ ^(bloque|avertit)$ ]]; then
    echo "install.sh : $cle_hook « ${valeurs[$cle_hook]:-} » refusé : bloque ou avertit" >&2
    exit 2
  fi
done
if [[ ! ${valeurs[hook_destructif]:-} =~ ^(demande|bloque|avertit)$ ]]; then
  echo "install.sh : hook_destructif « ${valeurs[hook_destructif]:-} » refusé : demande, bloque ou avertit" >&2
  exit 2
fi
# `navigateur=oui` : une couche fonctionnelle emploie Playwright.
if [[ ! ${valeurs[navigateur]:-} =~ ^(oui|non)$ ]]; then
  echo "install.sh : navigateur « ${valeurs[navigateur]:-} » refusé : oui ou non" >&2
  exit 2
fi
# Version du cadre posé : celle du plugin, sauf si le fichier de valeurs la donne.
valeurs[izanagi_version]="${valeurs[izanagi_version]:-$(plugin_version)}"
# Chemins sensibles : vide si le fichier de valeurs ne les donne pas.
valeurs[chemins_sensibles]="${valeurs[chemins_sensibles]:-}"

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
      # La ligne entière seulement : `clé={{clé}}` garde son saut de ligne.
      texte="${texte//$'\n'"{{$cle}}"$'\n'/$'\n'}"
      if [[ $texte == "{{$cle}}"$'\n'* ]]; then texte="${texte#"{{$cle}}"$'\n'}"; fi
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

# Garde des étapes fonctionnelles qui emploient Playwright, quand
# `navigateur=oui` : la CI passe IZANAGI_NAVIGATEUR=non aux systèmes sans
# navigateur. L'étape tourne dans un sous-shell : `exit 0` ne quitte que lui.
garde_navigateur() {
  printf '%s\n' \
    '    if [[ ${IZANAGI_NAVIGATEUR:-} == non ]]; then' \
    "      echo \"-- $1 : fonctionnelle : navigateur absent de ce système, sauté\"" \
    '      exit 0' \
    '    fi'
}

# Couverture d'un composant selon sa pile : effacement des mesures d'avant
# (`couv_prep`) et résumé (`couv_resume`), pour preparer_couverture et resumer_couverture
# de check.sh. Les commandes de mesure sont dans les fragments `test-*.sh`.
couverture_de() {
  local nom="$1" chemin="$2" pile="$3" couches=" $4 "
  couv_prep=""
  couv_resume=""
  case "$pile" in
    rust)
      couv_prep="  (cd \"$chemin\" && cargo llvm-cov clean --workspace)"
      couv_resume="  couverture_composant $nom rust \"$chemin\" cargo llvm-cov report"
      ;;
    typescript)
      couv_prep="  rm -rf \"$chemin/node_modules/.izanagi-couverture\""
      # La couche fonctionnelle ne mesure pas : sans unitaire ni integration,
      # il n'y a aucun rapport à fusionner.
      if [[ $couches == *" unitaire "* || $couches == *" integration "* ]]; then
        couv_resume="  couverture_composant $nom typescript \"$chemin\" npx vitest run --merge-reports=node_modules/.izanagi-couverture/blob --coverage --coverage.reporter=text-summary --coverage.reportsDirectory=node_modules/.izanagi-couverture/rapport"
      else
        couv_resume="  couverture_composant $nom typescript \"$chemin\" echo \"pas de mesure : la couche fonctionnelle seule ne mesure pas\""
      fi
      ;;
    python)
      couv_prep="  rm -f \"$chemin/.coverage\""
      couv_resume="  couverture_composant $nom python \"$chemin\" uv run --with pytest-cov==7.1.0 coverage report"
      ;;
    *)
      couv_resume="  couverture_composant $nom $pile \"$chemin\" echo \"pas de mesure de couverture pour $pile\""
      ;;
  esac
}

# Valeurs calculées : sections, appels et installation CI des composants.
preparations_couverture=""
resumes_couverture=""
ci_couverture=""
ci_playwright=""
declare -A couverture_vus=() playwright_vus=()
# Ajoute l'installation des navigateurs Playwright pour un dossier, une fois.
# Les commentaires du fragment ne passent qu'avec la première étape.
ajouter_playwright() {
  local etape
  [[ -n ${playwright_vus[$1]:-} ]] && return 0
  playwright_vus[$1]=1
  etape="$(rendre_fragment "$racine/templates/core/fragments/ci-playwright.yml" "chemin=$1")"
  [[ -n $ci_playwright ]] && etape="$(grep -v '^ *#' <<<"$etape")"
  ci_playwright+="${ci_playwright:+$'\n'}$etape"
}
sections=""
appels=""
appels_complets=""
lancements=""
tableau=""
lignes_composants=""
tableau_couches=""
lignes_couches=""
ci_setup=""
ci_audit=""
declare -a a_ecrire=() resume=()
declare -A setup_vus=()
for entree in "${composants[@]}"; do
  IFS='|' read -r c_nom c_chemin c_pile c_lancement c_couches c_ancienne <<<"$entree"
  c_id="${c_nom//-/_}"
  cles=("composant=$c_nom" "id=$c_id" "chemin=$c_chemin" "pile=$c_pile")
  # Une étape par couche déclarée : unitaire et integration dans la section,
  # fonctionnelle dans une fonction à part, que seul `--complet` appelle.
  etapes=""
  fonctionnelle=""
  declarees=" $(couches_de "$c_couches") "
  # Ancienne commande de tests (sixième champ) : l'étape unitaire la garde tant
  # que la couche unitaire du gabarit ne peut pas tourner dans le projet.
  ancienne=""
  # `à préciser` : la migration 0.7.0 n'a pas trouvé d'étape `tests` dans check.sh.
  [[ -n ${c_ancienne:-} && $c_ancienne != 'à préciser' ]] && ! unitaire_prete "$c_pile" "$cible/$c_chemin" && ancienne="$c_ancienne"
  for couche in unitaire integration fonctionnelle; do
    declaree=0
    [[ $declarees == *" $couche "* ]] && declaree=1
    commande_couche=""
    [[ $couche == unitaire ]] && commande_couche="$ancienne"
    rendre_couche "$c_nom" "$c_chemin" "$c_pile" "$couche" "$declaree" "$commande_couche"
    tableau_couches+="${tableau_couches:+$'\n'}$couche_rang"
    [[ $declaree -eq 1 ]] || continue
    lignes_couches+="${lignes_couches:+$'\n'}$couche_ligne"
    if [[ -n $commande_couche ]]; then
      etape="    # Ancienne commande du projet : la couche unitaire du gabarit n'a pas encore ses tests."$'\n'"    echo \"-- $c_nom : unitaire\""$'\n'"    $commande_couche"
    else
      etape="$(rendre_fragment "$(fragment "test-$couche.sh" "$c_pile")" "${cles[@]}")"
    fi
    if [[ $couche == fonctionnelle ]]; then
      # TypeScript : la couche fonctionnelle peut employer Playwright.
      if [[ ${valeurs[navigateur]} == oui && $c_pile == typescript ]]; then
        etape="$(garde_navigateur "$c_nom")"$'\n'"$etape"
        ajouter_playwright "$c_chemin"
      fi
      fonctionnelle="verifier_${c_id}_fonctionnelle() {"$'\n'"  ("$'\n'"    cd \"$c_chemin\""$'\n'"$etape"$'\n'"  )"$'\n'"}"
      appels_complets+="${appels_complets:+$'\n'}  verifier_${c_id}_fonctionnelle"
    else
      etapes+="${etapes:+$'\n'}$etape"
    fi
  done
  sections+="${sections:+$'\n\n'}$(rendre_fragment "$(fragment check-section.sh "$c_pile")" "etapes=$etapes" "${cles[@]}")"
  [[ -n $fonctionnelle ]] && sections+=$'\n\n'"$fonctionnelle"
  tableau+="${tableau:+$'\n'}| $c_nom | \`$c_chemin\` | $c_pile | ${c_lancement:+\`$c_lancement\`} |"
  lignes_composants+="${lignes_composants:+$'\n'}- composant : $c_nom | $c_chemin | $c_pile |${c_lancement:+ $c_lancement}"
  [[ -n $c_lancement ]] && lancements+="${lancements:+$'\n'}(cd \"$c_chemin\" && $c_lancement) &"$'\n''pids+=("$!")'
  appels+="${appels:+$'\n'}  verifier_$c_id"
  if [[ -z ${setup_vus[$c_pile]:-} ]]; then
    setup_vus[$c_pile]=1
    ci_setup+="${ci_setup:+$'\n'}$(rendre_fragment "$(fragment ci-setup.yml "$c_pile")" "pile=$c_pile")"
  fi
  # Couverture : outils de la pile en CI (une fois par pile), effacement et résumé par composant.
  if [[ -z ${couverture_vus[$c_pile]:-} ]]; then
    couverture_vus[$c_pile]=1
    if [[ -f $racine/templates/$c_pile/fragments/ci-couverture.yml ]]; then
      ci_couverture+="${ci_couverture:+$'\n'}$(cat "$racine/templates/$c_pile/fragments/ci-couverture.yml")"
    fi
  fi
  couverture_de "$c_nom" "$c_chemin" "$c_pile" "$declarees"
  [[ -n $couv_prep ]] && preparations_couverture+="${preparations_couverture:+$'\n'}$couv_prep"
  resumes_couverture+="${resumes_couverture:+$'\n'}$couv_resume"
  # Audit des dépendances : un bloc par composant, dans son dossier.
  ci_audit+="${ci_audit:+$'\n'}$(rendre_fragment "$(fragment ci-audit.yml "$c_pile")" \
    "composant=$c_nom" "id=$c_id" "chemin=$c_chemin" "pile=$c_pile")"
  [[ -f $racine/templates/$c_pile/fragments/check-section.sh ]] || a_ecrire+=("$c_nom ($c_pile)")
  resume+=("$c_nom($c_pile)")
done
if [[ -n $tableau ]]; then
  tableau=$'| Nom | Chemin | Pile | Lancement |\n| --- | --- | --- | --- |\n'"$tableau"
else
  tableau="Aucun composant pour l'instant : \`/izanagi:init\` en ajoute."
fi
# Entrée fonctionnelle du projet (décision 97) : lancée à la racine, après les
# composants, par `--complet`.
if [[ -n $fonctionnel_projet && ${#composants[@]} -gt 0 ]]; then
  p_dossier="${fonctionnel_projet%%|*}"
  p_commande="${fonctionnel_projet#*|}"
  p_garde=""
  if [[ ${valeurs[navigateur]} == oui ]]; then
    p_garde="$(garde_navigateur projet)"$'\n'
    # Une commande Playwright à la racine : les navigateurs s'installent depuis le verrou de la racine.
    [[ $p_commande == *playwright* ]] && ajouter_playwright .
  fi
  # Le package.json de la racine (Playwright, scénarios) s'installe depuis son verrou,
  # comme chaque composant TypeScript, après la garde du navigateur.
  p_installation="$(printf '%s\n' \
    '    if [[ -f package-lock.json ]]; then' \
    '      echo "-- projet : installation"' \
    '      npm ci' \
    '    fi')"$'\n'
  sections+=$'\n\n'"# --- entrée fonctionnelle du projet ---"$'\n'"verifier_projet_fonctionnelle() {"$'\n'"  ("$'\n'"$p_garde$p_installation    echo \"-- projet : fonctionnelle\""$'\n'"    $p_commande"$'\n'"  )"$'\n'"}"
  appels_complets+="${appels_complets:+$'\n'}  verifier_projet_fonctionnelle"
  tableau_couches+=$'\n'"| projet | fonctionnelle | \`$p_dossier\` | \`${p_commande//|/\\|}\` |"
  lignes_couches+=$'\n'"- couche : projet | fonctionnelle | $p_dossier | $p_commande"
fi
# release.yml : la version se lit dans le composant `version_composant` (le
# premier par défaut), puis un job de livrable par composant selon `type` et sa
# pile (décision 126) : `binaires` pour un cli en Rust, `publier` pour un cli en
# TypeScript ou en Python et pour une library (à écrire, depuis le fragment du cœur,
# pour une pile sans gabarit de publication). desktop, game, mobile et data-ml
# ont un job `livrable` à écrire ; les autres types n'ont que verifier et release.
release_matrice=""
for s in "${liste_systemes[@]}"; do
  case "$s" in
    linux) os=ubuntu-latest ;;
    windows) os=windows-latest ;;
    macos) os=macos-latest ;;
  esac
  release_matrice+="${release_matrice:+$'\n'}          - { systeme: $s, os: $os }"
done
release_version=""
release_jobs=""
release_needs="verifier"
# ajouter_job_release <job> <fragment> [clé=valeur]… : rend le fragment, qui commence
# par une ligne vide, et l'ajoute aux jobs ; une ligne vide sépare deux jobs.
ajouter_job_release() {
  local job="$1" f="$2" texte
  shift 2
  texte="$(rendre_fragment "$f" "$@")"
  # Une publication sur un registre est irréversible : elle attend les binaires.
  [[ $job == publier-* ]] && texte="${texte//$'\n'"    needs: verifier"$'\n'/$'\n'"    needs: $needs_publier"$'\n'}"
  release_jobs+="${release_jobs:+$'\n'}$texte"
  release_needs+=", $job"
}
# needs des jobs publier-* : verifier, plus les binaires d'un cli mixte.
needs_publier=verifier
if [[ ${valeurs[type]:-} == cli ]]; then
  for entree in "${composants[@]}"; do
    IFS='|' read -r c_nom _ c_pile _ <<<"$entree"
    [[ $c_pile == rust ]] && needs_publier+=", binaires-$c_nom"
  done
  [[ $needs_publier == verifier ]] || needs_publier="[$needs_publier]"
fi
for entree in "${composants[@]}"; do
  IFS='|' read -r c_nom c_chemin c_pile _ <<<"$entree"
  cles=("composant=$c_nom" "chemin=$c_chemin" "pile=$c_pile")
  if [[ -z $release_version && ( -z ${valeurs[version_composant]:-} || ${valeurs[version_composant]} == "$c_nom" ) ]]; then
    release_version="$(rendre_fragment "$(fragment release-version.yml "$c_pile")" "${cles[@]}")"
  fi
  case "${valeurs[type]:-}|$c_pile" in
    cli\|rust)
      ajouter_job_release "binaires-$c_nom" "$racine/templates/rust/fragments/release-binaires.yml" "${cles[@]}" "matrice=$release_matrice"
      ;;
    cli\|typescript | cli\|python | library\|*)
      # Une pile sans gabarit de publication reçoit le job du cœur, à écrire.
      ajouter_job_release "publier-$c_nom" "$(fragment release-registre.yml "$c_pile")" "${cles[@]}"
      ;;
  esac
done
case "${valeurs[type]:-}" in
  desktop | game | mobile | data-ml)
    ajouter_job_release livrable "$racine/templates/core/fragments/release-livrable.yml" "type=${valeurs[type]}"
    ;;
esac
# dependabot.yml : une entrée par composant dont la pile a un gabarit ; les autres
# piles laissent un commentaire. Le chemin `.` s'écrit `/`, un autre `/<chemin>`.
dependabot_ecosystemes=""
for entree in "${composants[@]}"; do
  IFS='|' read -r c_nom c_chemin c_pile _ <<<"$entree"
  if [[ -f $racine/templates/$c_pile/fragments/dependabot.yml ]]; then
    c_chemin_db="${c_chemin#./}"
    c_chemin_db="${c_chemin_db%/}"
    if [[ -z $c_chemin_db || $c_chemin_db == . ]]; then c_repertoire=/; else c_repertoire="/$c_chemin_db"; fi
    dependabot_ecosystemes+="${dependabot_ecosystemes:+$'\n'}$(rendre_fragment "$racine/templates/$c_pile/fragments/dependabot.yml" \
      "composant=$c_nom" "repertoire=$c_repertoire")"
  else
    dependabot_ecosystemes+="${dependabot_ecosystemes:+$'\n'}  # $c_nom ($c_pile) : pas de gabarit Dependabot, à ajouter à la main."
  fi
done
valeurs[dependabot_ecosystemes]="$dependabot_ecosystemes"
valeurs[release_version]="$release_version"
valeurs[release_jobs]="$release_jobs"
valeurs[release_needs]="$release_needs"
valeurs[tableau_couches]="$(tableau_des_couches "$tableau_couches")"
valeurs[lignes_couches]="$lignes_couches"
valeurs[tableau_composants]="$tableau"
valeurs[lignes_composants]="$lignes_composants"
valeurs[sections]="$sections"
valeurs[appels]="$appels"
valeurs[appels_complets]="${appels_complets:-  :}"
valeurs[ci_setup]="$ci_setup"
valeurs[ci_audit]="$ci_audit"
valeurs[ci_analyse]="$(cat "$racine/templates/core/fragments/ci-analyse.yml")"
valeurs[ci_gitleaks]="$(cat "$racine/templates/core/fragments/ci-gitleaks.yml")"
valeurs[preparations_couverture]="${preparations_couverture:-  :}"
valeurs[resumes_couverture]="${resumes_couverture:-  :}"
valeurs[ci_couverture]="$ci_couverture"
# Playwright : dans le job check, Ubuntu seul ; dans le job couverture, qui
# n'a pas de matrice, sans condition.
valeurs[ci_playwright]="$ci_playwright"
valeurs[ci_playwright_couverture]="${ci_playwright//$'\n'"        if: matrix.os == 'ubuntu-latest'"/}"
if [[ ${valeurs[navigateur]} == oui && ${#composants[@]} -gt 0 ]]; then
  valeurs[ci_navigateur]="        env:"$'\n'"          IZANAGI_NAVIGATEUR: \${{ matrix.os == 'ubuntu-latest' && 'oui' || 'non' }}"
else
  valeurs[ci_navigateur]=""
fi
valeurs[lancements]="$lancements"
# Mutation (décision 111) : `oui` quand toutes les piles des composants ont un
# gabarit (cargo-mutants, Stryker, mutmut), `non` sinon ou sans composant. Le
# fichier de valeurs l'emporte : une relance d'upgrade garde le choix du projet.
if [[ -z ${valeurs[mutation]:-} ]]; then
  if [[ ${#composants[@]} -gt 0 && ${#a_ecrire[@]} -eq 0 ]]; then
    valeurs[mutation]=oui
  else
    valeurs[mutation]=non
  fi
fi
if [[ ! ${valeurs[mutation]} =~ ^(oui|non)$ ]]; then
  echo "install.sh : mutation « ${valeurs[mutation]} » refusée : oui ou non" >&2
  exit 2
fi

valeurs[deploiement_ligne]="@@deploiement-ligne@@"
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

# Déploiement : `deploiement` porte la commande, écrite par le projet. La ligne de
# harness.md garde un repère, remplacé après le rendu : la commande peut contenir
# `{{x}}`, qui ne doit pas passer pour une clé manquante. Le fichier
# deploiement.yml n'est posé que si une commande existe ; il est rendu ici, avec
# chaque ligne de la commande indentée sous `run: |`, puis posé sans autre rendu.
repere_deploiement="@@deploiement-ligne@@"
# Une valeur vide, ou faite d'espaces, vaut « à préciser ».
[[ ${valeurs[deploiement]:-} =~ [^[:space:]] ]] || valeurs[deploiement]="à préciser"
if [[ ${valeurs[deploiement]} == "à préciser" ]]; then
  ligne_deploiement="à préciser."
else
  ligne_deploiement="\`${valeurs[deploiement]}\`."
  commande_indentee=""
  while IFS= read -r ligne || [[ -n $ligne ]]; do
    ligne="${ligne%$'\r'}"
    commande_indentee+="${commande_indentee:+$'\n'}          $ligne"
  done <<<"${valeurs[deploiement]}"
  mkdir -p "$rapport/deploiement/.github/workflows"
  rendre_fragment "$racine/templates/code/fragments/deploiement.yml" "commande=$commande_indentee" \
    >"$rapport/deploiement/.github/workflows/deploiement.yml"
  [[ ${#composants[@]} -gt 0 ]] && fichiers+=("$rapport/deploiement|.github/workflows/deploiement.yml")
fi

# Règles par langage : un fichier docs/standards/<pile>.md par pile des composants,
# rendu depuis le fragment, puis comparé comme les autres gabarits.
declare -A langages_vus=()
for entree in "${composants[@]}"; do
  IFS='|' read -r c_nom c_chemin c_pile c_lancement c_couches c_ancienne <<<"$entree"
  [[ -n ${langages_vus[$c_pile]:-} ]] && continue
  langages_vus[$c_pile]=1
  if [[ -f $racine/references/langages/$c_pile.md ]]; then
    ligne_plugin="Le relecteur et l'implémenteur lisent aussi les règles générales du plugin pour ce langage, \`references/langages/$c_pile.md\` d'Izanagi. Ce fichier porte les ajouts et les exceptions de ce projet."
  else
    ligne_plugin="Le plugin n'a pas de règles générales pour $c_pile : ce fichier porte toutes les règles de ce projet pour ce langage."
  fi
  mkdir -p "$rapport/langages/docs/standards"
  rendre_fragment "$racine/templates/core/fragments/standards.md" "langage=$c_pile" "ligne_plugin=$ligne_plugin" \
    >"$rapport/langages/docs/standards/$c_pile.md"
  fichiers+=("$rapport/langages|docs/standards/$c_pile.md")
done

for entree in "${fichiers[@]}"; do
  source="${entree%%|*}"
  rel="${entree#*|}"
  dest="$cible/$rel"
  rendu="$rapport/rendu/$rel"
  mkdir -p "$(dirname "$rendu")"
  if [[ $source == "$rapport/deploiement" ]]; then
    cp "$source/$rel" "$rendu"
  else
    rendre "$source/$rel" >"$rendu"
  fi
  if [[ $rel == docs/agents/harness.md ]]; then
    texte="$(cat "$rendu"; printf x)"
    texte="${texte%x}"
    printf '%s' "${texte//"$repere_deploiement"/"$ligne_deploiement"}" >"$rendu"
  fi
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
