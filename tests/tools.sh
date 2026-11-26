#!/usr/bin/env bash
# Teste les scripts des commandes upgrade, status et doctor, et la passe de mutation :
# scripts/migrations/*.sh, scripts/status.sh, scripts/doctor.sh et scripts/mutation.sh.
set -euo pipefail

racine="$(cd "$(dirname "$0")/.." && pwd)"
install="$racine/scripts/install.sh"
migration="$racine/scripts/migrations/0.4.0.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echoue() { echo "ÉCHEC : $*" >&2; exit 1; }

# shellcheck source=../scripts/lib.sh
. "$racine/scripts/lib.sh"

depot() { # depot <dossier> : en fait un dépôt git avec un premier commit.
  git -C "$1" init -q -b main
  git -C "$1" config user.email essai@example.invalid
  git -C "$1" config user.name Essai
  git -C "$1" add -A
  git -C "$1" commit -q -m cadre
}

# valeurs_de <projet> : le fichier de valeurs qu'upgrade passe à install.sh, fait
# des clés de config.env.
valeurs_de() {
  grep -vE '^(#|$)' "$1/.izanagi/config.env"
}

# controle_config_08 <cas> <écarts> : config.env d'un projet migré avant la 0.8
# diffère du gabarit par les seules lignes <écarts> (celles du diff, `-` et `+`
# comprises, séparées par des retours à la ligne) : `langue_publique` et
# `version_composant` (la migration 0.4.0 l'écrit vide, la pose y met le premier
# composant ; une pose d'avant la 0.8 ne les a pas). Lit $sortie, la sortie
# d'install.sh.
controle_config_08() {
  local rap diff_c
  grep -qxF 'différent  .izanagi/config.env' <<<"$sortie" || echoue "$1 : config.env : $sortie"
  rap="$(sed -n 's/^rapport : //p' <<<"$sortie")"
  diff_c="$(grep -E '^[+-]' "$rap/diff/.izanagi/config.env.diff" | grep -vE '^(\+\+\+|---) ' | tr -d '\r')"
  [[ $diff_c == "$2" ]] || echoue "$1 : config.env diffère autrement que prévu : $diff_c"
}

# Système courant, pour `systemes` : `check.sh --host` ne lance alors que lui.
case "$(uname -s)" in
  MINGW* | MSYS* | CYGWIN*) ici=windows ;;
  Darwin*) ici=macos ;;
  *) ici=linux ;;
esac

# ============ Migration 0.4.0 ============
[[ -f $migration ]] || echoue "scripts/migrations/0.4.0.sh absent"

# --- Projet posé par la 0.3.0 ---
git -C "$racine" cat-file -e 'v0.3.0^{commit}' 2>/dev/null || echoue "tag v0.3.0 absent du dépôt : lance git fetch --tags"
mkdir -p "$tmp/v03" "$tmp/p03"
git -C "$racine" archive v0.3.0 scripts templates | tar -x -C "$tmp/v03"
cat >"$tmp/p03v" <<'FIN'
pile=rust
projet=Essai Rapide
spec=docs/spec.md
lieu_test=dans un terminal
decisions=le §14 de la spec
vault=C:/Vault/essai
FIN
bash "$tmp/v03/scripts/install.sh" "$tmp/p03" "$tmp/p03v" >/dev/null
[[ -f $tmp/p03/docs/agents/jalon.md ]] || echoue "la pose 0.3.0 n'a pas de jalon.md"
depot "$tmp/p03"

sortie="$(bash "$migration" "$tmp/p03")"
grep -qxF 'écrit      .izanagi/config.env' <<<"$sortie" || echoue "migration : config.env non annoncé : $sortie"
grep -qxF 'supprimé   docs/agents/jalon.md' <<<"$sortie" || echoue "migration : jalon.md non annoncé : $sortie"
grep -q '^non reconnu' <<<"$sortie" && echoue "migration : ligne non reconnue sur un gabarit intact : $sortie"
config="$tmp/p03/.izanagi/config.env"
[[ ! -e $tmp/p03/docs/agents/jalon.md ]] || echoue "migration : jalon.md gardé"
[[ $(kv_get "$config" izanagi_version) == 0.4.0 ]] || echoue "migration : izanagi_version"
[[ $(kv_get "$config" projet) == 'Essai Rapide' ]] || echoue "migration : projet : $(kv_get "$config" projet)"
[[ $(kv_get "$config" spec) == docs/spec.md ]] || echoue "migration : spec"
[[ $(kv_get "$config" decisions) == 'le §14 de la spec' ]] || echoue "migration : decisions"
[[ $(kv_get "$config" plans) == docs/plans/ ]] || echoue "migration : plans"
[[ $(kv_get "$config" branche) == main ]] || echoue "migration : branche"
[[ $(kv_get "$config" verification) == scripts/check.sh ]] || echoue "migration : verification"
[[ $(kv_get "$config" test_manuel) == 'cargo install --path . --locked' ]] || echoue "migration : test_manuel : $(kv_get "$config" test_manuel)"
[[ $(kv_get "$config" lieu_test) == 'dans un terminal' ]] || echoue "migration : lieu_test"
[[ $(kv_get "$config" taille_tranche) == '1 500' ]] || echoue "migration : taille_tranche"
[[ $(kv_get "$config" fichier_version) == *Cargo.toml* ]] || echoue "migration : fichier_version"
[[ $(kv_get "$config" vault) == C:/Vault/essai ]] || echoue "migration : vault"
[[ $(kv_get "$config" hook_push) == bloque && $(kv_get "$config" hook_verification) == bloque ]] || echoue "migration : hooks"
[[ $(cat "$tmp/p03/.izanagi/.gitignore") == "$(cat "$racine/templates/core/.izanagi/.gitignore")" ]] || echoue "migration : .izanagi/.gitignore"
[[ $(kv_get "$config" hook_destructif) == demande ]] || echoue "migration : hook_destructif"

# La pose relancée avec ces valeurs trouve le config.env identique au gabarit.
{ echo pile=rust; valeurs_de "$tmp/p03"; } >"$tmp/p03v2"
sortie="$("$install" "$tmp/p03" "$tmp/p03v2")"
controle_config_08 "migration 0.4.0" $'-version_composant=\n+version_composant=rust'
grep -qxF 'identique  .izanagi/.gitignore' <<<"$sortie" || echoue ".gitignore migré différent du gabarit : $sortie"

# Seconde migration : rien à faire, rien de changé.
git -C "$tmp/p03" add -A && git -C "$tmp/p03" commit -q -m migration
sortie="$(bash "$migration" "$tmp/p03")"
[[ $sortie == 'déjà migré' ]] || echoue "seconde migration : $sortie"
[[ -z $(git -C "$tmp/p03" status --porcelain) ]] || echoue "seconde migration : fichiers changés"

# ============ Migration 0.5.0 ============
migration05="$racine/scripts/migrations/0.5.0.sh"
[[ -f $migration05 ]] || echoue "scripts/migrations/0.5.0.sh absent"

# Enchaînée après la 0.4.0 sur le projet posé en 0.3.0 : la clé est déjà là, la version monte.
grep -qxF 'chemins_sensibles=' "$config" || echoue "migration 0.4.0 : chemins_sensibles absent ou non vide"
sortie="$(bash "$migration05" "$tmp/p03")"
[[ $sortie == 'écrit      .izanagi/config.env' ]] || echoue "migration 0.5.0 après 0.4.0 : $sortie"
[[ $(kv_get "$config" izanagi_version) == 0.5.0 ]] || echoue "migration 0.5.0 : izanagi_version"
[[ $(kv_get "$config" projet) == 'Essai Rapide' ]] || echoue "migration 0.5.0 a perdu une valeur"
[[ $(bash "$migration05" "$tmp/p03") == 'déjà migré' ]] || echoue "migration 0.5.0 relancée"
git -C "$tmp/p03" checkout -q -- .izanagi/config.env

# --- Projet posé par la 0.4.1 ---
git -C "$racine" cat-file -e 'v0.4.1^{commit}' 2>/dev/null || echoue "tag v0.4.1 absent du dépôt : lance git fetch --tags"
mkdir -p "$tmp/v04" "$tmp/p04"
git -C "$racine" archive v0.4.1 scripts templates .claude-plugin | tar -x -C "$tmp/v04"
bash "$tmp/v04/scripts/install.sh" "$tmp/p04" "$tmp/p03v" >/dev/null
grep -q '^chemins_sensibles=' "$tmp/p04/.izanagi/config.env" && echoue "la pose 0.4.1 a déjà chemins_sensibles"
depot "$tmp/p04"
sortie="$(bash "$migration05" "$tmp/p04")"
[[ $sortie == 'écrit      .izanagi/config.env' ]] || echoue "migration 0.5.0 : $sortie"
[[ $(kv_get "$tmp/p04/.izanagi/config.env" izanagi_version) == 0.5.0 ]] || echoue "migration 0.5.0 sur 0.4.1 : izanagi_version"
[[ $(grep -A1 '^taille_tranche=' "$tmp/p04/.izanagi/config.env" | tail -1) == 'chemins_sensibles=' ]] || echoue "migration 0.5.0 : chemins_sensibles mal placé"
# La pose de la 0.5.0, relancée avec ces valeurs, trouve le config.env identique à
# son gabarit. Le gabarit courant porte les clés des versions suivantes.
{ echo pile=rust; valeurs_de "$tmp/p04"; } >"$tmp/p04v"
mkdir -p "$tmp/v05"
git -C "$racine" archive v0.5.0 scripts templates .claude-plugin | tar -x -C "$tmp/v05"
sortie="$(bash "$tmp/v05/scripts/install.sh" "$tmp/p04" "$tmp/p04v")"
grep -qxF 'identique  .izanagi/config.env' <<<"$sortie" || echoue "config.env migré en 0.5 différent du gabarit : $sortie"
[[ $(bash "$migration05" "$tmp/p04") == 'déjà migré' ]] || echoue "migration 0.5.0 relancée sur 0.4.1"
# Sans config.env, la migration refuse.
mkdir "$tmp/nu"
code=0; bash "$migration05" "$tmp/nu" >/dev/null 2>&1 || code=$?
[[ $code -eq 2 ]] || echoue "migration 0.5.0 sans config.env : code $code"

# ============ Migration 0.6.0 ============
migration06="$racine/scripts/migrations/0.6.0.sh"
[[ -f $migration06 ]] || echoue "scripts/migrations/0.6.0.sh absent"
# Sur le projet migré en 0.5 : clé, .gitignore et règles permissions.deny.
git -C "$tmp/p04" add -A && git -C "$tmp/p04" commit -q -m "cadre 0.5"
sortie="$(bash "$migration06" "$tmp/p04")"
[[ $sortie == $'écrit      .izanagi/config.env\nécrit      .izanagi/.gitignore\ncréé       .claude/settings.json' ]] || echoue "migration 0.6.0 : $sortie"
config04="$tmp/p04/.izanagi/config.env"
[[ $(kv_get "$config04" izanagi_version) == 0.6.0 ]] || echoue "migration 0.6.0 : izanagi_version"
[[ $(grep -A1 '^hook_verification=' "$config04" | tail -1) == 'hook_destructif=demande' ]] || echoue "migration 0.6.0 : hook_destructif mal placé"
[[ $(kv_get "$config04" projet) == 'Essai Rapide' ]] || echoue "migration 0.6.0 a perdu une valeur"
# La pose courante, relancée avec ces valeurs, trouve ces fichiers identiques au gabarit.
# config.env ne diffère que par les clés de la 0.7, que la migration 0.7.0 ajoutera.
{ echo pile=rust; valeurs_de "$tmp/p04"; } >"$tmp/p04v6"
sortie="$("$install" "$tmp/p04" "$tmp/p04v6")"
for f in .izanagi/.gitignore .claude/settings.json; do
  grep -qxF "identique  $f" <<<"$sortie" || echoue "migration 0.6.0 : $f différent du gabarit : $sortie"
done
rapport06="$(sed -n 's/^rapport : //p' <<<"$sortie")"
ecarts06="$(grep -E '^[-+][^-+]' "$rapport06/diff/.izanagi/config.env.diff" 2>/dev/null || true)"
[[ $ecarts06 == $'+navigateur=non\n+mutation=oui\n+mutation_delai=15\n+langue_publique=fr\n+version_composant=rust' ]] ||
  echoue "migration 0.6.0 : config.env diffère du gabarit hors des clés de la 0.7 : $ecarts06"
[[ $(bash "$migration06" "$tmp/p04") == 'déjà migré' ]] || echoue "migration 0.6.0 relancée"

# Un .claude/settings.json du projet, avec d'autres réglages, n'est jamais réécrit.
mkdir -p "$tmp/p06r/.izanagi" "$tmp/p06r/.claude"
printf 'izanagi_version=0.5.0\nhook_push=bloque\nhook_verification=bloque\n' >"$tmp/p06r/.izanagi/config.env"
printf '{\n  "model": "sonnet"\n}\n' >"$tmp/p06r/.claude/settings.json"
# Un .gitignore sans saut de ligne final : le motif ne se colle pas à la dernière ligne.
printf 'journal/*/' >"$tmp/p06r/.izanagi/.gitignore"
avant="$(cat "$tmp/p06r/.claude/settings.json")"
sortie="$(bash "$migration06" "$tmp/p06r")"
grep -qxF 'à fusionner .claude/settings.json' <<<"$sortie" || echoue "migration 0.6.0 : settings.json existant : $sortie"
[[ $(cat "$tmp/p06r/.claude/settings.json") == "$avant" ]] || echoue "migration 0.6.0 a réécrit settings.json"
[[ $(cat "$tmp/p06r/.izanagi/.gitignore") == $'journal/*/\nrefus.log' ]] || echoue "migration 0.6.0 : .gitignore sans saut de ligne final : $(cat "$tmp/p06r/.izanagi/.gitignore")"
# Les règles déjà fusionnées : plus rien à signaler.
cp "$racine/templates/core/.claude/settings.json" "$tmp/p06r/.claude/settings.json"
[[ $(bash "$migration06" "$tmp/p06r") == 'déjà migré' ]] || echoue "migration 0.6.0 après fusion"

# Enchaînée après la 0.4.0 et la 0.5.0 sur le projet posé en 0.3.0 : la clé est déjà là.
sortie="$(bash "$migration05" "$tmp/p03" >/dev/null; bash "$migration06" "$tmp/p03")"
[[ $(kv_get "$config" izanagi_version) == 0.6.0 ]] || echoue "migration 0.6.0 après 0.5.0 : izanagi_version : $sortie"
[[ $(grep -c '^hook_destructif=' "$config") -eq 1 ]] || echoue "migration 0.6.0 après 0.4.0 : hook_destructif en double"
git -C "$tmp/p03" checkout -q -- .izanagi
rm -rf "$tmp/p03/.claude"
code=0; bash "$migration06" "$tmp/nu" >/dev/null 2>&1 || code=$?
[[ $code -eq 2 ]] || echoue "migration 0.6.0 sans config.env : code $code"

# --- Vault absent ---
mkdir "$tmp/sv"
printf 'pile=rust\nprojet=Essai\nspec=s.md\nlieu_test=ici\n' >"$tmp/svv"
bash "$tmp/v03/scripts/install.sh" "$tmp/sv" "$tmp/svv" >/dev/null
depot "$tmp/sv"
bash "$migration" "$tmp/sv" >/dev/null
[[ $(kv_get "$tmp/sv/.izanagi/config.env" vault) == non ]] || echoue "migration : vault absent"

# --- jalon.md modifié à la main ---
mkdir "$tmp/mod"
bash "$tmp/v03/scripts/install.sh" "$tmp/mod" "$tmp/svv" >/dev/null
echo '- **Budget** : 3 jours.' >>"$tmp/mod/docs/agents/jalon.md"
sed -i 's/^- \*\*Branche principale\*\* : .*/- **Branche principale** : la branche trunk./' "$tmp/mod/docs/agents/jalon.md"
depot "$tmp/mod"
sortie="$(bash "$migration" "$tmp/mod")"
grep -qxF 'non reconnu : - **Budget** : 3 jours.' <<<"$sortie" || echoue "ligne ajoutée non signalée : $sortie"
grep -qxF 'non reconnu : - **Branche principale** : la branche trunk.' <<<"$sortie" || echoue "valeur illisible non signalée : $sortie"
grep -qxF 'à compléter : branche' <<<"$sortie" || echoue "clé à compléter non signalée : $sortie"
[[ -f $tmp/mod/docs/agents/jalon.md ]] || echoue "jalon.md supprimé malgré une ligne non reconnue"
[[ $(kv_get "$tmp/mod/.izanagi/config.env" spec) == s.md ]] || echoue "config.env non écrit malgré les lignes reconnues"

# --- Journaux ---
mkdir "$tmp/jr"
bash "$tmp/v03/scripts/install.sh" "$tmp/jr" "$tmp/svv" >/dev/null
mkdir -p "$tmp/jr/.izanagi/journal" "$tmp/jr/.superpowers/sdd/ancien" "$tmp/jr/.superpowers/sdd/double"
echo '*' >"$tmp/jr/.izanagi/journal/.gitignore"
echo 'journal 0.3' >"$tmp/jr/.izanagi/journal/plan.md"
echo 'Task 1: complete' >"$tmp/jr/.superpowers/sdd/ancien/progress.md"
echo 'ancien' >"$tmp/jr/.superpowers/sdd/double/progress.md"
echo 'nouveau' >"$tmp/jr/.izanagi/journal/double.md"
depot "$tmp/jr"
sortie="$(bash "$migration" "$tmp/jr")"
[[ ! -e $tmp/jr/.izanagi/journal/.gitignore ]] || echoue "journal/.gitignore gardé"
[[ $(cat "$tmp/jr/.izanagi/journal/plan.md") == 'journal 0.3' ]] || echoue "journal 0.3 touché"
[[ $(cat "$tmp/jr/.izanagi/journal/ancien.md") == 'Task 1: complete' ]] || echoue "journal d'avant la 0.3 non déplacé"
[[ ! -e $tmp/jr/.superpowers/sdd/ancien/progress.md ]] || echoue "journal d'avant la 0.3 gardé à son ancien chemin"
grep -qxF 'déplacé    .superpowers/sdd/ancien/progress.md vers .izanagi/journal/ancien.md' <<<"$sortie" || echoue "déplacement non annoncé : $sortie"
[[ $(cat "$tmp/jr/.izanagi/journal/double.md") == nouveau && $(cat "$tmp/jr/.superpowers/sdd/double/progress.md") == ancien ]] || echoue "journal en double écrasé"
grep -qxF 'gardé      .superpowers/sdd/double/progress.md : .izanagi/journal/double.md existe déjà' <<<"$sortie" || echoue "journal en double non signalé : $sortie"

# --- Projet posé par la 0.1.1, migré puis comparé au gabarit ---
if git -C "$racine" cat-file -e '5bb1144^{commit}' 2>/dev/null; then
  mkdir -p "$tmp/v01" "$tmp/p01"
  git -C "$racine" archive 5bb1144 scripts templates | tar -x -C "$tmp/v01"
  printf 'pile=rust\nprojet=Essai\nspec=docs/spec.md\nlieu_test=dans un terminal\n' >"$tmp/p01v0"
  bash "$tmp/v01/scripts/pose.sh" "$tmp/p01" "$tmp/p01v0" >/dev/null
  depot "$tmp/p01"
  attendu="$(cd "$tmp/p01" && git ls-files | sort)"
  sortie="$(bash "$migration" "$tmp/p01")"
  grep -q '^non reconnu' <<<"$sortie" && echoue "0.1.1 : ligne non reconnue : $sortie"
  [[ ! -e $tmp/p01/docs/agents/jalon.md ]] || echoue "0.1.1 : jalon.md gardé"
  # projet_dossier : le nom avant `-target` dans le check.sh de la 0.1.
  dossier="$(sed -n 's|.*\.cache/\([a-z0-9._-]*\)-target.*|\1|p' "$tmp/p01/scripts/check.sh" | head -1)"
  [[ $dossier == essai ]] || echoue "0.1.1 : projet_dossier lu dans check.sh : $dossier"
  {
    printf 'composant=rust|.|rust|cargo run\nsystemes=linux,windows\ntype=cli\nprojet_dossier=%s\n' "$dossier"
    valeurs_de "$tmp/p01"
  } >"$tmp/p01v"
  sortie="$("$install" "$tmp/p01" "$tmp/p01v")"
  for f in $attendu; do
    case "$f" in
      docs/agents/jalon.md) continue ;;
      scripts/check.sh | .github/workflows/ci.yml) etat=différent ;;
      # Changés par la 0.3 : ligne des skills izanagi, renvois, chemins hors revue.
      CLAUDE.md | docs/agents/domain.md | docs/CODING_STANDARDS.md) etat=différent ;;
      *) etat=identique ;;
    esac
    grep -qxF "$etat  $f" <<<"$sortie" || echoue "0.1.1 : $f n'est pas $etat : $sortie"
  done
  for f in docs/agents/harness.md AGENTS.md .claude/settings.json .gitleaks.toml .github/dependabot.yml .github/workflows/securite.yml docs/standards/rust.md scripts/notes-de-version.sh .github/workflows/release.yml .github/pull_request_template.md; do
    grep -qxF "créé       $f" <<<"$sortie" || echoue "0.1.1 : $f non créé : $sortie"
  done
  [[ $(grep -c '^créé' <<<"$sortie") -eq 10 ]] || echoue "0.1.1 : créations en trop : $sortie"
  controle_config_08 "0.1.1" $'-version_composant=\n+version_composant=rust'
else
  echo "0.1.1 : commit 5bb1144 absent du dépôt, cas sauté"
fi

# ============ Migration 0.7.0 ============
migration07="$racine/scripts/migrations/0.7.0.sh"
[[ -f $migration07 ]] || echoue "scripts/migrations/0.7.0.sh absent"

# controle_harness_08 <cas> : après la 0.8, harness.md d'un projet posé avant elle
# diffère du gabarit par la seule ligne « Déploiement » ; install.sh n'y touche pas.
# Lit $sortie, la sortie d'install.sh.
controle_harness_08() {
  local rap diff_h
  grep -qxF 'différent  docs/agents/harness.md' <<<"$sortie" || echoue "$1 : harness.md : $sortie"
  rap="$(sed -n 's/^rapport : //p' <<<"$sortie")"
  diff_h="$(grep -E '^[+-]' "$rap/diff/docs/agents/harness.md.diff" | grep -vE '^(\+\+\+|---) ' | tr -d '\r')"
  [[ $diff_h == '+- **Déploiement** : à préciser.' ]] || echoue "$1 : harness.md diffère autrement que par la ligne Déploiement : $diff_h"
}

# valeurs_upgrade <projet> : le fichier de valeurs que la section 3 d'upgrade écrit,
# fait des clés de config.env et des lignes de harness.md. Le cinquième champ de
# `composant=` vient des lignes `- couche :`, le sixième de la commande unitaire.
# `version_composant` n'est gardé que s'il nomme un composant de harness.md : sinon
# install.sh prend le premier. `deploiement` vient de la ligne « Déploiement ».
valeurs_upgrade() {
  local ligne nom chemin pile lancement couches ancienne vc noms=" "
  valeurs_de "$1" | grep -v '^version_composant='
  while IFS= read -r ligne; do
    IFS='|' read -r nom chemin pile lancement <<<"${ligne#- composant : }"
    nom="${nom// /}" chemin="${chemin// /}" pile="${pile// /}"
    lancement="${lancement# }"
    couches="$(sed -n "s/^- couche : $nom | \([a-z]*\) |.*/\1/p" "$1/docs/agents/harness.md" | paste -sd, -)"
    # Python et TypeScript : la commande unitaire de harness.md en sixième champ.
    # Jamais pour Rust, dont la colonne commande est une phrase.
    ancienne=""
    if [[ $pile == python || $pile == typescript ]]; then
      ancienne="$(sed -n "s/^- couche : $nom | unitaire | [^|]* | \(.*\)$/\1/p" "$1/docs/agents/harness.md" | tr -d '\r')"
      [[ $ancienne == 'à préciser' ]] && ancienne=""
    fi
    printf 'composant=%s|%s|%s|%s|%s|%s\n' "$nom" "$chemin" "$pile" "$lancement" "$couches" "$ancienne"
    noms+="$nom "
  done < <(grep -E '^- composant : ' "$1/docs/agents/harness.md" | tr -d '\r')
  vc="$(kv_get "$1/.izanagi/config.env" version_composant || true)"
  if [[ -n $vc && $noms == *" $vc "* ]]; then printf 'version_composant=%s\n' "$vc"; fi
  tr -d '\r' <"$1/docs/agents/harness.md" | sed -n 's/^- \*\*Systèmes cibles\*\* : \(.*\)\.$/systemes=\1/p; s/^- \*\*Type\*\* : \(.*\)\.$/type=\1/p
    s/^- \*\*Déploiement\*\* : `\(.*\)`\.$/deploiement=\1/p; s/^- \*\*Déploiement\*\* : à préciser\.$/deploiement=à préciser/p'
}

git -C "$racine" cat-file -e 'v0.6.0^{commit}' 2>/dev/null || echoue "tag v0.6.0 absent du dépôt : lance git fetch --tags"
mkdir -p "$tmp/v06"
git -C "$racine" archive v0.6.0 scripts templates .claude-plugin | tar -x -C "$tmp/v06"

# --- Projet Rust posé par la 0.6.0 : unitaire et intégration détectées ---
mkdir -p "$tmp/r06/src" "$tmp/r06/tests/commun"
printf 'composant=outil|.|rust|cargo run\nprojet=Essai\nspec=s.md\nlieu_test=ici\ntype=cli\nsystemes=%s\n' "$ici" >"$tmp/r06v"
bash "$tmp/v06/scripts/install.sh" "$tmp/r06" "$tmp/r06v" >/dev/null
printf 'fn main() {}\n' >"$tmp/r06/src/main.rs"
printf '#[test]\nfn aide() {}\n' >"$tmp/r06/tests/cli.rs"
printf 'pub fn x() {}\n' >"$tmp/r06/tests/commun/mod.rs"
depot "$tmp/r06"
sortie="$(bash "$migration07" "$tmp/r06")"
[[ $sortie == $'écrit      .izanagi/config.env\nécrit      docs/agents/harness.md' ]] || echoue "migration 0.7.0 rust : $sortie"
config_r="$tmp/r06/.izanagi/config.env"
harness_r="$tmp/r06/docs/agents/harness.md"
[[ $(kv_get "$config_r" izanagi_version) == 0.7.0 ]] || echoue "migration 0.7.0 : izanagi_version"
[[ $(kv_get "$config_r" mutation) == oui ]] || echoue "migration 0.7.0 : mutation pour rust : $(kv_get "$config_r" mutation)"
[[ $(kv_get "$config_r" mutation_delai) == 15 ]] || echoue "migration 0.7.0 : mutation_delai"
[[ $(kv_get "$config_r" navigateur) == non ]] || echoue "migration 0.7.0 : navigateur sans Playwright"
[[ $(grep -A3 '^hook_destructif=' "$config_r" | tail -3 | tr '\n' ' ') == 'navigateur=non mutation=oui mutation_delai=15 ' ]] ||
  echoue "migration 0.7.0 : clés mal placées : $(cat "$config_r")"
grep -q 'Couches de test\*\*' "$harness_r" && echoue "migration 0.7.0 : ligne « Couches de test » gardée"
grep -qxF '## Couches de test' "$harness_r" || echoue "migration 0.7.0 : section des couches absente"
grep -qxF -- '- couche : outil | unitaire | src | cargo test --workspace --locked' "$harness_r" || echoue "migration 0.7.0 : couche unitaire : $(cat "$harness_r")"
grep -qxF -- '- couche : outil | integration | tests | cargo test --workspace --locked --test <nom>, pour chaque test hors fonctionnel_*' "$harness_r" ||
  echoue "migration 0.7.0 : couche intégration : $(cat "$harness_r")"
grep -q '^- couche : outil | fonctionnelle' "$harness_r" && echoue "migration 0.7.0 : couche fonctionnelle sans test"
grep -qxF '| outil | fonctionnelle | sans objet | sans objet |' "$harness_r" || echoue "migration 0.7.0 : tableau : $(cat "$harness_r")"
grep -qxF '| outil | unitaire | `src` | `cargo test --workspace --locked` |' "$harness_r" || echoue "migration 0.7.0 : tableau unitaire : $(cat "$harness_r")"
# check.sh et ci.yml ne sont pas écrits par la migration.
[[ -z $(git -C "$tmp/r06" status --porcelain -- scripts .github) ]] || echoue "migration 0.7.0 : check.sh ou ci.yml écrit"
git -C "$tmp/r06" add -A && git -C "$tmp/r06" commit -q -m migration

# La pose d'upgrade : config.env identique, harness.md ne diffère que par la commande
# unitaire, check.sh et ci.yml diffèrent. Repris, ils passent le contrat.
valeurs_upgrade "$tmp/r06" >"$tmp/r06v7"
grep -qxF 'composant=outil|.|rust|cargo run|unitaire,integration|' "$tmp/r06v7" || echoue "upgrade 0.7 : composant : $(cat "$tmp/r06v7")"
sortie="$("$install" "$tmp/r06" "$tmp/r06v7")"
controle_config_08 "migration 0.7.0" $'+langue_publique=fr\n+version_composant=outil'
for f in scripts/check.sh .github/workflows/ci.yml docs/agents/harness.md; do
  grep -qxF "différent  $f" <<<"$sortie" || echoue "upgrade 0.7 : $f pas différent : $sortie"
done
rapport07="$(sed -n 's/^rapport : //p' <<<"$sortie")"
ecarts07="$(grep -E '^[-+][^-+]' "$rapport07/diff/docs/agents/harness.md.diff")"
grep -v 'unitaire' <<<"$ecarts07" && echoue "migration 0.7.0 : harness.md diffère hors de la commande unitaire : $ecarts07"
grep -qF -- '--complet' "$rapport07/diff/.github/workflows/ci.yml.diff" || echoue "upgrade 0.7 : l'écart de ci.yml ne montre pas --complet"
for f in scripts/check.sh .github/workflows/ci.yml docs/agents/harness.md; do
  cp "$rapport07/rendu/$f" "$tmp/r06/$f"
done
sortie="$(bash "$racine/scripts/check-contract.sh" "$tmp/r06" 2>&1)" || echoue "upgrade 0.7 : contrat après la pose : $sortie"

# Relancée : rien à faire, rien de changé.
git -C "$tmp/r06" checkout -q -- scripts .github docs
[[ $(bash "$migration07" "$tmp/r06") == 'déjà migré' ]] || echoue "migration 0.7.0 relancée"
[[ -z $(git -C "$tmp/r06" status --porcelain --untracked-files=no) ]] || echoue "migration 0.7.0 relancée : fichiers changés"

# --- Espace de travail Cargo posé par la 0.6.0 : tests dans les membres (#44) ---
# Les tests de crates/*/tests/ comptent comme ceux de tests/. Un test fonctionnel
# d'un membre qui déclare la feature `fonctionnel` est rangé, celui d'un membre
# sans la feature va dans « à ranger ». target/ n'est pas lu.
mkdir -p "$tmp/cw06/crates/coeur/src" "$tmp/cw06/crates/coeur/tests" "$tmp/cw06/crates/cli/src" "$tmp/cw06/crates/cli/tests" \
  "$tmp/cw06/target/debug/build/x/tests"
printf 'composant=outil|.|rust|cargo run\nprojet=Essai\nspec=s.md\nlieu_test=ici\ntype=cli\nsystemes=%s\n' "$ici" >"$tmp/cw06v"
bash "$tmp/v06/scripts/install.sh" "$tmp/cw06" "$tmp/cw06v" >/dev/null
printf '[workspace]\nmembers = ["crates/*"]\nresolver = "2"\n' >"$tmp/cw06/Cargo.toml"
printf '[package]\nname = "coeur"\n\n[features]\nfonctionnel = []\n' >"$tmp/cw06/crates/coeur/Cargo.toml"
printf '[package]\nname = "cli"\n' >"$tmp/cw06/crates/cli/Cargo.toml"
printf 'pub fn x() {}\n' >"$tmp/cw06/crates/coeur/src/lib.rs"
printf 'fn main() {}\n' >"$tmp/cw06/crates/cli/src/main.rs"
printf '#[test]\nfn calcul() {}\n' >"$tmp/cw06/crates/coeur/tests/calcul.rs"
printf '#[test]\nfn parcours() {}\n' >"$tmp/cw06/crates/coeur/tests/fonctionnel_parcours.rs"
printf '#[test]\nfn aide() {}\n' >"$tmp/cw06/crates/cli/tests/fonctionnel_aide.rs"
printf 'fn genere() {}\n' >"$tmp/cw06/target/debug/build/x/tests/genere.rs"
depot "$tmp/cw06"
sortie="$(bash "$migration07" "$tmp/cw06")"
[[ $sortie == $'écrit      .izanagi/config.env\nécrit      docs/agents/harness.md\nà ranger   crates/cli/tests/fonctionnel_aide.rs' ]] ||
  echoue "migration 0.7.0 espace de travail : $sortie"
harness_cw="$tmp/cw06/docs/agents/harness.md"
grep -qxF -- '- couche : outil | integration | tests | cargo test --workspace --locked --test <nom>, pour chaque test hors fonctionnel_*' "$harness_cw" ||
  echoue "migration 0.7.0 espace de travail : couche intégration : $(cat "$harness_cw")"
grep -q '^- couche : outil | fonctionnelle | ' "$harness_cw" ||
  echoue "migration 0.7.0 espace de travail : couche fonctionnelle : $(cat "$harness_cw")"

# --- Projet Python posé par la 0.6.0, tests à plat ---
mkdir -p "$tmp/y06/src/app" "$tmp/y06/tests/outils"
printf 'composant=app|.|python|\nprojet=Essai\nspec=s.md\nlieu_test=ici\ntest_manuel=uv run app\ntype=library\nsystemes=%s\n' "$ici" >"$tmp/y06v"
bash "$tmp/v06/scripts/install.sh" "$tmp/y06" "$tmp/y06v" >/dev/null
printf 'def somme(a, b):\n    return a + b\n' >"$tmp/y06/src/app/calc.py"
printf 'def test_somme():\n    pass\n' >"$tmp/y06/tests/test_calc.py"
printf 'def test_aide():\n    pass\n' >"$tmp/y06/tests/outils/test_aide.py"
printf 'import pytest\n' >"$tmp/y06/tests/conftest.py"
depot "$tmp/y06"
sortie="$(bash "$migration07" "$tmp/y06")"
[[ $sortie == $'écrit      .izanagi/config.env\nécrit      docs/agents/harness.md\nà ranger   tests/outils/test_aide.py\nà ranger   tests/test_calc.py' ]] ||
  echoue "migration 0.7.0 python : $sortie"
harness_y="$tmp/y06/docs/agents/harness.md"
[[ $(grep -c '^- couche : ' "$harness_y") -eq 1 ]] || echoue "migration 0.7.0 python : une seule couche attendue : $(cat "$harness_y")"
grep -qxF -- '- couche : app | unitaire | tests/unitaires | uv run pytest' "$harness_y" || echoue "migration 0.7.0 python : couche unitaire : $(cat "$harness_y")"
[[ $(kv_get "$tmp/y06/.izanagi/config.env" mutation) == oui ]] || echoue "migration 0.7.0 python : mutation"
# Rien n'est déplacé.
[[ -f $tmp/y06/tests/test_calc.py && ! -e $tmp/y06/tests/unitaires ]] || echoue "migration 0.7.0 : un test a été déplacé"
# La pose d'upgrade reprend check.sh et ci.yml. Tant que tests/unitaires/ n'a pas de
# test, l'étape unitaire garde l'ancienne commande du projet (`uv run pytest`), et
# harness.md reste tel que la migration l'a écrit. Des faux uv et gitleaks rendent 0.
valeurs_upgrade "$tmp/y06" >"$tmp/y06v7"
grep -qxF 'composant=app|.|python||unitaire|uv run pytest' "$tmp/y06v7" || echoue "upgrade 0.7 python : composant : $(cat "$tmp/y06v7")"
sortie="$("$install" "$tmp/y06" "$tmp/y06v7")"
controle_harness_08 "upgrade 0.7 python"
rapport07="$(sed -n 's/^rapport : //p' <<<"$sortie")"
for f in scripts/check.sh .github/workflows/ci.yml; do
  cp "$rapport07/rendu/$f" "$tmp/y06/$f"
done
grep -A1 -F 'echo "-- app : unitaire"' "$tmp/y06/scripts/check.sh" | grep -qxF '    uv run pytest' ||
  echoue "upgrade 0.7 python : l'étape unitaire ne lance pas l'ancienne commande : $(cat "$tmp/y06/scripts/check.sh")"
grep -qF 'pytest tests/unitaires' "$tmp/y06/scripts/check.sh" && echoue "upgrade 0.7 python : check.sh lance tests/unitaires, vide"
sortie="$(bash "$racine/scripts/check-contract.sh" "$tmp/y06" 2>&1)" || echoue "upgrade 0.7 python : contrat après la pose : $sortie"
mkdir -p "$tmp/y06f"
printf '#!/bin/sh\necho "$*" >>"%s/uv.args"\nexit 0\n' "$tmp/y06f" >"$tmp/y06f/uv"
printf '#!/bin/sh\nexit 0\n' >"$tmp/y06f/gitleaks"
chmod +x "$tmp/y06f/uv" "$tmp/y06f/gitleaks"
code=0
sortie="$(cd "$tmp/y06" && PATH="$tmp/y06f:$PATH" bash scripts/check.sh --host --complet 2>&1)" || code=$?
[[ $code -eq 0 ]] || echoue "upgrade 0.7 python : vérification en échec : $sortie"
grep -qxF -- '-- app : unitaire' <<<"$sortie" || echoue "upgrade 0.7 python : pas d'étape unitaire : $sortie"
grep -qF -- '-- app : integration' <<<"$sortie" && echoue "upgrade 0.7 python : étape d'intégration sans test : $sortie"
grep -qxF 'run pytest' "$tmp/y06f/uv.args" || echoue "upgrade 0.7 python : commande unitaire : $(cat "$tmp/y06f/uv.args")"
git -C "$tmp/y06" checkout -q -- scripts .github
# Une fois un test rangé dans tests/unitaires/, la pose reprend la commande du gabarit.
mkdir -p "$tmp/y06/tests/unitaires"
printf 'def test_somme():\n    pass\n' >"$tmp/y06/tests/unitaires/test_calc.py"
sortie="$("$install" "$tmp/y06" "$tmp/y06v7")"
rapport07="$(sed -n 's/^rapport : //p' <<<"$sortie")"
grep -A10 -F 'echo "-- app : unitaire"' "$rapport07/rendu/scripts/check.sh" | grep -qF 'uv run pytest tests/unitaires' ||
  echoue "upgrade 0.7 python : tests rangés, commande du gabarit absente : $(cat "$rapport07/rendu/scripts/check.sh")"
grep -qxF -- '- couche : app | unitaire | tests/unitaires | uv run pytest tests/unitaires' "$rapport07/rendu/docs/agents/harness.md" ||
  echoue "upgrade 0.7 python : tests rangés, harness.md : $(cat "$rapport07/rendu/docs/agents/harness.md")"
rm -rf "$tmp/y06/tests/unitaires"

# --- Projet TypeScript posé par la 0.6.0, sans les scripts npm des couches ---
mkdir -p "$tmp/w06/src" "$tmp/w06/tests/integration"
printf 'composant=web|.|typescript|npm run dev\nprojet=Essai\nspec=s.md\nlieu_test=ici\ntest_manuel=npm run dev\ntype=web-frontend\nsystemes=%s\n' "$ici" >"$tmp/w06v"
bash "$tmp/v06/scripts/install.sh" "$tmp/w06" "$tmp/w06v" >/dev/null
printf '{\n  "scripts": {\n    "test": "vitest run"\n  }\n}\n' >"$tmp/w06/package.json"
echo 'x' >"$tmp/w06/src/a.test.ts"
echo 'x' >"$tmp/w06/tests/integration/b.test.ts"
depot "$tmp/w06"
sortie="$(bash "$migration07" "$tmp/w06")"
# Sans script test:integration, le dossier d'intégration ne fait pas une couche : ses tests sont à ranger.
[[ $sortie == $'écrit      .izanagi/config.env\nécrit      docs/agents/harness.md\nà ranger   tests/integration/b.test.ts' ]] ||
  echoue "migration 0.7.0 typescript 0.6 : $sortie"
grep -qxF -- '- couche : web | unitaire | src | npm test' "$tmp/w06/docs/agents/harness.md" || echoue "migration 0.7.0 typescript 0.6 : $(cat "$tmp/w06/docs/agents/harness.md")"
grep -q '^- couche : web | integration' "$tmp/w06/docs/agents/harness.md" && echoue "migration 0.7.0 typescript 0.6 : intégration sans script npm"
valeurs_upgrade "$tmp/w06" >"$tmp/w06v7"
sortie="$("$install" "$tmp/w06" "$tmp/w06v7")"
rapport07="$(sed -n 's/^rapport : //p' <<<"$sortie")"
controle_harness_08 "upgrade 0.7 typescript"
grep -A1 -F 'echo "-- web : unitaire"' "$rapport07/rendu/scripts/check.sh" | grep -qxF '    npm test' ||
  echoue "upgrade 0.7 typescript : l'étape unitaire ne lance pas npm test : $(cat "$rapport07/rendu/scripts/check.sh")"
grep -qF 'test:unitaire' "$rapport07/rendu/scripts/check.sh" && echoue "upgrade 0.7 typescript : check.sh lance test:unitaire, absent de package.json"
cp "$rapport07/rendu/scripts/check.sh" "$tmp/w06/scripts/check.sh"
cp "$rapport07/rendu/.github/workflows/ci.yml" "$tmp/w06/.github/workflows/ci.yml"
sortie="$(bash "$racine/scripts/check-contract.sh" "$tmp/w06" 2>&1)" || echoue "upgrade 0.7 typescript : contrat après la pose : $sortie"

# --- Projet à la main : TypeScript avec Playwright, et une pile sans gabarit ---
pt="$tmp/t06"
mkdir -p "$pt/.izanagi" "$pt/docs/agents" "$pt/scripts" "$pt/web/src" "$pt/web/tests/integration" "$pt/web/e2e" \
  "$pt/web/node_modules/x" "$pt/outil/tests/integration"
printf 'izanagi_version=0.6.0\nhook_destructif=demande\nmutation_delai=30\n' >"$pt/.izanagi/config.env"
printf -- '# Harnais\n\n- **Couches de test** : à préciser.\n\n## Composants\n\n- composant : web | web | typescript | npm run dev\n- composant : outil | outil | zig |\n' \
  >"$pt/docs/agents/harness.md"
printf '# --- composant web (typescript) ---\nverifier_web() {\n  (\n    cd "web"\n    echo "-- web : tests"\n    npx vitest run\n  )\n}\n' \
  >"$pt/scripts/check.sh"
printf '{\n  "scripts": {\n    "test:integration": "vitest run --project integration"\n  }\n}\n' >"$pt/web/package.json"
for f in src/a.test.ts tests/integration/b.test.ts e2e/c.spec.ts node_modules/x/d.test.js playwright.config.ts; do
  echo 'x' >"$pt/web/$f"
done
echo 'x' >"$pt/outil/tests/integration/essai.zig"
sortie="$(bash "$migration07" "$pt")"
[[ $sortie == $'écrit      .izanagi/config.env\nécrit      docs/agents/harness.md\nà ranger   web/e2e/c.spec.ts' ]] || echoue "migration 0.7.0 typescript : $sortie"
[[ $(kv_get "$pt/.izanagi/config.env" navigateur) == oui ]] || echoue "migration 0.7.0 : navigateur avec playwright.config.ts"
[[ $(kv_get "$pt/.izanagi/config.env" mutation) == non ]] || echoue "migration 0.7.0 : mutation avec une pile sans gabarit"
[[ $(kv_get "$pt/.izanagi/config.env" mutation_delai) == 30 ]] || echoue "migration 0.7.0 : mutation_delai du projet écrasé"
[[ $(grep -c '^mutation_delai=' "$pt/.izanagi/config.env") -eq 1 ]] || echoue "migration 0.7.0 : mutation_delai en double"
for l in '- couche : web | unitaire | web/src | npx vitest run' '- couche : web | integration | web/tests/integration | npm run test:integration' \
  '- couche : outil | unitaire | à préciser | à préciser' '- couche : outil | integration | outil/tests/integration | à préciser'; do
  grep -qxF -- "$l" "$pt/docs/agents/harness.md" || echoue "migration 0.7.0 : ligne « $l » absente : $(cat "$pt/docs/agents/harness.md")"
done
[[ $(bash "$migration07" "$pt") == 'déjà migré' ]] || echoue "migration 0.7.0 relancée sur le projet à la main"

# --- Enchaînée de la 0.4.0 à la 0.7.0 sur le projet posé en 0.3.0 ---
[[ $(kv_get "$config" mutation) == non ]] || echoue "migration 0.4.0 : mutation devrait valoir non"
sortie="$(bash "$migration05" "$tmp/p03" >/dev/null; bash "$migration06" "$tmp/p03" >/dev/null; bash "$migration07" "$tmp/p03")"
grep -qxF 'écrit      .izanagi/config.env' <<<"$sortie" || echoue "migration 0.7.0 après 0.6.0 : $sortie"
[[ $(kv_get "$config" izanagi_version) == 0.7.0 ]] || echoue "migration 0.7.0 après 0.6.0 : izanagi_version"
[[ $(kv_get "$config" mutation) == oui ]] || echoue "migration 0.7.0 après 0.4.0 : mutation non recalculée"
[[ $(grep -c '^mutation=' "$config") -eq 1 && $(grep -c '^navigateur=' "$config") -eq 1 ]] || echoue "migration 0.7.0 après 0.4.0 : clé en double : $(cat "$config")"
[[ $(kv_get "$config" projet) == 'Essai Rapide' ]] || echoue "migration 0.7.0 a perdu une valeur"
grep -q '^- couche : rust | unitaire | ' "$tmp/p03/docs/agents/harness.md" || echoue "migration 0.7.0 sur 0.3.0 : harness.md : $(cat "$tmp/p03/docs/agents/harness.md")"
git -C "$tmp/p03" checkout -q -- .izanagi docs
rm -rf "$tmp/p03/.claude"

code=0; bash "$migration07" "$tmp/nu" >/dev/null 2>&1 || code=$?
[[ $code -eq 2 ]] || echoue "migration 0.7.0 sans config.env : code $code"

# ============ Migration 0.8.0 ============
migration08="$racine/scripts/migrations/0.8.0.sh"
[[ -f $migration08 ]] || echoue "scripts/migrations/0.8.0.sh absent"
a_preciser08='à préciser  déploiement : écris la commande dans docs/agents/harness.md, puis relance /izanagi:upgrade'

git -C "$racine" cat-file -e 'v0.7.0^{commit}' 2>/dev/null || echoue "tag v0.7.0 absent du dépôt : lance git fetch --tags"
mkdir -p "$tmp/v07"
git -C "$racine" archive v0.7.0 scripts templates .claude-plugin | tar -x -C "$tmp/v07"

# pose_upgrade_08 <cas> <projet> : la pose d'upgrade après la migration. config.env et
# harness.md sortent identiques, ci.yml, securite.yml et dependabot.yml différents,
# release.yml, notes-de-version.sh et le template de PR créés, sans CHANGELOG.md.
# Chaque fichier différent est repris du rendu, puis le contrat est respecté.
# Avec un troisième argument, `ancien`, pour un projet posé avant la 0.7 et jamais
# reposé : seul config.env doit sortir identique.
pose_upgrade_08() {
  local rap f
  valeurs_upgrade "$2" >"$tmp/valeurs08"
  sortie="$("$install" "$2" "$tmp/valeurs08")" || echoue "$1 : pose : $sortie"
  grep -qxF "identique  .izanagi/config.env" <<<"$sortie" || echoue "$1 : config.env pas identique : $sortie"
  if [[ ${3:-} != ancien ]]; then
    grep -qxF "identique  docs/agents/harness.md" <<<"$sortie" || echoue "$1 : harness.md pas identique : $sortie"
    for f in .github/workflows/ci.yml .github/workflows/securite.yml .github/dependabot.yml; do
      grep -qxF "différent  $f" <<<"$sortie" || echoue "$1 : $f pas différent : $sortie"
    done
    for f in .github/workflows/release.yml scripts/notes-de-version.sh .github/pull_request_template.md; do
      grep -qxF "créé       $f" <<<"$sortie" || echoue "$1 : $f non créé : $sortie"
    done
  fi
  [[ ! -e $2/CHANGELOG.md ]] || echoue "$1 : CHANGELOG.md créé par la pose"
  rap="$(sed -n 's/^rapport : //p' <<<"$sortie")"
  while IFS= read -r f; do
    cp "$rap/rendu/$f" "$2/$f"
  done < <(sed -n 's/^différent  //p' <<<"$sortie")
  sortie="$(bash "$racine/scripts/check-contract.sh" "$2" 2>&1)" || echoue "$1 : contrat après la pose : $sortie"
  [[ $sortie == 'contrat : respecté' ]] || echoue "$1 : contrat : $sortie"
}

# --- Projet api posé par la 0.7.0 ---
mkdir -p "$tmp/a07/src"
printf 'composant=serveur|.|rust|cargo run\nprojet=Essai\nspec=s.md\nlieu_test=ici\ntype=api\nsystemes=%s\n' "$ici" >"$tmp/a07v"
bash "$tmp/v07/scripts/install.sh" "$tmp/a07" "$tmp/a07v" >/dev/null
printf 'fn main() {}\n' >"$tmp/a07/src/main.rs"
depot "$tmp/a07"
sortie="$(bash "$migration08" "$tmp/a07")"
[[ $sortie == "écrit      .izanagi/config.env"$'\n'"écrit      docs/agents/harness.md"$'\n'"$a_preciser08" ]] || echoue "migration 0.8.0 api : $sortie"
config_a="$tmp/a07/.izanagi/config.env"
[[ $(kv_get "$config_a" izanagi_version) == 0.8.0 ]] || echoue "migration 0.8.0 : izanagi_version"
[[ $(kv_get "$config_a" langue_publique) == fr ]] || echoue "migration 0.8.0 : langue_publique : $(cat "$config_a")"
[[ $(kv_get "$config_a" version_composant) == serveur ]] || echoue "migration 0.8.0 : version_composant : $(cat "$config_a")"
[[ $(grep -A2 '^mutation_delai=' "$config_a" | tail -2 | tr '\n' ' ') == 'langue_publique=fr version_composant=serveur ' ]] ||
  echoue "migration 0.8.0 : clés mal placées : $(cat "$config_a")"
[[ $(grep -A1 '^- \*\*Test manuel\*\* : ' "$tmp/a07/docs/agents/harness.md" | tail -1) == '- **Déploiement** : à préciser.' ]] ||
  echoue "migration 0.8.0 : ligne Déploiement : $(cat "$tmp/a07/docs/agents/harness.md")"
[[ -z $(git -C "$tmp/a07" status --porcelain -- .github scripts) ]] || echoue "migration 0.8.0 : un workflow ou un script écrit"
git -C "$tmp/a07" add -A && git -C "$tmp/a07" commit -q -m migration

# Relancée : rien à faire, rien de changé.
[[ $(bash "$migration08" "$tmp/a07") == 'déjà migré' ]] || echoue "migration 0.8.0 relancée"
[[ -z $(git -C "$tmp/a07" status --porcelain) ]] || echoue "migration 0.8.0 relancée : fichiers changés"

# La pose d'upgrade, puis le contrat.
grep -qxF 'deploiement=à préciser' <(valeurs_upgrade "$tmp/a07") || echoue "upgrade 0.8 : deploiement : $(valeurs_upgrade "$tmp/a07")"
grep -qxF 'langue_publique=fr' <(valeurs_upgrade "$tmp/a07") || echoue "upgrade 0.8 : langue_publique"
grep -qxF 'version_composant=serveur' <(valeurs_upgrade "$tmp/a07") || echoue "upgrade 0.8 : version_composant"
pose_upgrade_08 "upgrade 0.8 api" "$tmp/a07"
[[ ! -e $tmp/a07/.github/workflows/deploiement.yml ]] || echoue "upgrade 0.8 : deploiement.yml sans commande"

# Une commande de déploiement dans harness.md : la pose crée deploiement.yml. Un
# version_composant qui ne nomme plus de composant est retiré des valeurs.
sed -i 's/^- \*\*Déploiement\*\* : à préciser\.$/- **Déploiement** : `.\/deployer.sh "prod"`./' "$tmp/a07/docs/agents/harness.md"
sed -i 's/^version_composant=.*/version_composant=ancien/' "$config_a"
valeurs_upgrade "$tmp/a07" >"$tmp/a07v8"
grep -qxF 'deploiement=./deployer.sh "prod"' "$tmp/a07v8" || echoue "upgrade 0.8 : commande de déploiement : $(cat "$tmp/a07v8")"
grep -q '^version_composant=' "$tmp/a07v8" && echoue "upgrade 0.8 : version_composant inconnu gardé"
sortie="$("$install" "$tmp/a07" "$tmp/a07v8")" || echoue "upgrade 0.8 : pose avec un version_composant inconnu : $sortie"
grep -qxF 'créé       .github/workflows/deploiement.yml' <<<"$sortie" || echoue "upgrade 0.8 : deploiement.yml non créé : $sortie"
grep -qxF 'identique  docs/agents/harness.md' <<<"$sortie" || echoue "upgrade 0.8 : harness.md avec commande : $sortie"
sortie="$(bash "$racine/scripts/check-contract.sh" "$tmp/a07" 2>&1)" || echoue "upgrade 0.8 : contrat avec deploiement.yml : $sortie"

# --- Projet cli posé par la 0.7.0 : pas de déploiement à préciser ---
mkdir -p "$tmp/c07/src"
printf 'composant=outil|.|rust|cargo run\nprojet=Essai\nspec=s.md\nlieu_test=ici\ntype=cli\nsystemes=%s\n' "$ici" >"$tmp/c07v"
bash "$tmp/v07/scripts/install.sh" "$tmp/c07" "$tmp/c07v" >/dev/null
printf 'fn main() {}\n' >"$tmp/c07/src/main.rs"
depot "$tmp/c07"
sortie="$(bash "$migration08" "$tmp/c07")"
[[ $sortie == $'écrit      .izanagi/config.env\nécrit      docs/agents/harness.md' ]] || echoue "migration 0.8.0 cli : $sortie"
grep -qxF -- '- **Déploiement** : à préciser.' "$tmp/c07/docs/agents/harness.md" || echoue "migration 0.8.0 cli : ligne Déploiement absente"
[[ $(bash "$migration08" "$tmp/c07") == 'déjà migré' ]] || echoue "migration 0.8.0 cli relancée"

# --- Projet à la main sans composant, langue_publique déjà là ---
mkdir -p "$tmp/m07/.izanagi" "$tmp/m07/docs/agents"
printf 'izanagi_version=0.7.0\nmutation_delai=15\nlangue_publique=en\n' >"$tmp/m07/.izanagi/config.env"
printf -- '# Harnais\n\n- **Type** : web-frontend.\n- **Test manuel** : `npm run dev`.\n\n## Composants\n' >"$tmp/m07/docs/agents/harness.md"
sortie="$(bash "$migration08" "$tmp/m07")"
[[ $sortie == "écrit      .izanagi/config.env"$'\n'"écrit      docs/agents/harness.md"$'\n'"$a_preciser08" ]] || echoue "migration 0.8.0 à la main : $sortie"
[[ $(cat "$tmp/m07/.izanagi/config.env") == $'izanagi_version=0.8.0\nmutation_delai=15\nlangue_publique=en\nversion_composant=' ]] ||
  echoue "migration 0.8.0 à la main : config.env : $(cat "$tmp/m07/.izanagi/config.env")"
[[ $(bash "$migration08" "$tmp/m07") == 'déjà migré' ]] || echoue "migration 0.8.0 à la main relancée"

# --- Enchaînée de la 0.4.0 à la 0.8.0 sur le projet posé en 0.3.0 ---
sortie="$(for m in "$migration05" "$migration06" "$migration07"; do bash "$m" "$tmp/p03" >/dev/null; done; bash "$migration08" "$tmp/p03")"
grep -qxF 'écrit      .izanagi/config.env' <<<"$sortie" || echoue "migration 0.8.0 après 0.7.0 : $sortie"
[[ $(kv_get "$config" izanagi_version) == 0.8.0 ]] || echoue "migration 0.8.0 après 0.7.0 : izanagi_version"
[[ $(grep -c '^langue_publique=' "$config") -eq 1 && $(grep -c '^version_composant=' "$config") -eq 1 ]] ||
  echoue "migration 0.8.0 après 0.4.0 : clé en double : $(cat "$config")"
[[ $(kv_get "$config" version_composant) == rust ]] || echoue "migration 0.8.0 après 0.4.0 : version_composant : $(cat "$config")"
[[ $(kv_get "$config" projet) == 'Essai Rapide' ]] || echoue "migration 0.8.0 a perdu une valeur"
grep -qxF -- '- **Déploiement** : à préciser.' "$tmp/p03/docs/agents/harness.md" || echoue "migration 0.8.0 sur 0.3.0 : ligne Déploiement"
pose_upgrade_08 "upgrade 0.8 depuis 0.3" "$tmp/p03" ancien
git -C "$tmp/p03" checkout -q -- .
git -C "$tmp/p03" clean -qfd
rm -rf "$tmp/p03/.claude"

code=0; bash "$migration08" "$tmp/nu" >/dev/null 2>&1 || code=$?
[[ $code -eq 2 ]] || echoue "migration 0.8.0 sans config.env : code $code"

# ============ check.sh : recherche de secrets ============
# Un faux gitleaks note ses arguments et rend le code de $GITLEAKS_CODE. Le projet n'a
# qu'un composant sans gabarit, dont la section ne lance rien, et pour seul système
# cible le système courant : `check.sh --host` ne lance que la recherche de secrets.
mkdir -p "$tmp/faux" "$tmp/sec"
cat >"$tmp/faux/gitleaks" <<'FAUX'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$GITLEAKS_ARGS"
exit "${GITLEAKS_CODE:-0}"
FAUX
chmod +x "$tmp/faux/gitleaks"
export GITLEAKS_ARGS="$tmp/gitleaks.args"
printf 'projet=sec\nspec=s.md\nlieu_test=ici\ntest_manuel=x\nfichier_version=y\ncomposant=api|.|zig|\nsystemes=%s\n' "$ici" >"$tmp/secv"
"$install" "$tmp/sec" "$tmp/secv" >/dev/null
grep -qF 'verifier_secrets' "$tmp/sec/scripts/check.sh" || echoue "check.sh : pas de verifier_secrets"
depot "$tmp/sec"
git -C "$tmp/sec" switch -q -c task/x
echo x >"$tmp/sec/x.txt" && git -C "$tmp/sec" add x.txt && git -C "$tmp/sec" commit -q -m x
# secrets <dossier> : lance check.sh --host avec le faux gitleaks ; remplit $sortie et $code.
secrets() {
  code=0
  rm -f "$GITLEAKS_ARGS"
  sortie="$(cd "$1" && PATH="$tmp/faux:$PATH" bash scripts/check.sh --host 2>&1)" || code=$?
}
secrets "$tmp/sec"
[[ $code -eq 0 ]] || echoue "secrets : code $code : $sortie"
[[ $(cat "$GITLEAKS_ARGS") == 'git --redact --no-banner --log-opts=main..HEAD .' ]] || echoue "secrets : arguments « $(cat "$GITLEAKS_ARGS") »"
grep -qF -- '-- secrets' <<<"$sortie" || echoue "secrets : étape non annoncée : $sortie"
GITLEAKS_CODE=1 secrets "$tmp/sec"
[[ $code -ne 0 ]] || echoue "secrets : une fuite ne fait pas échouer check.sh"

# Clone sans branche principale locale, comme le checkout d'une CI.
git clone -q "$tmp/sec" "$tmp/sec-clone"
git -C "$tmp/sec-clone" rev-parse -q --verify refs/heads/main >/dev/null && echoue "secrets : le clone a une branche main locale"
secrets "$tmp/sec-clone"
[[ $(cat "$GITLEAKS_ARGS") == 'git --redact --no-banner --log-opts=origin/main..HEAD .' ]] || echoue "secrets : clone : « $(cat "$GITLEAKS_ARGS") »"

# Aucune des deux références : tout l'historique, et une ligne qui le dit.
git -C "$tmp/sec" branch -q -D main
secrets "$tmp/sec"
[[ $(cat "$GITLEAKS_ARGS") == 'git --redact --no-banner .' ]] || echoue "secrets : sans branche principale : « $(cat "$GITLEAKS_ARGS") »"
grep -qF -- '-- secrets : branche principale introuvable, analyse de tout l'"'"'historique' <<<"$sortie" || echoue "secrets : sans branche principale : $sortie"

# Hors d'un dépôt git, comme la copie WSL : étape sautée.
mkdir "$tmp/sec-copie"
git -C "$tmp/sec" archive HEAD | tar -x -C "$tmp/sec-copie"
secrets "$tmp/sec-copie"
[[ $code -eq 0 && ! -e $GITLEAKS_ARGS ]] || echoue "secrets : hors dépôt git : code $code : $sortie"
grep -qF -- '-- secrets : pas de dépôt git, sauté' <<<"$sortie" || echoue "secrets : hors dépôt git : $sortie"

if command -v gitleaks >/dev/null; then
  # Une fausse clé AWS commitée fait échouer check.sh, et la sortie la masque.
  git -C "$tmp/sec" switch -q -c main 2>/dev/null || true
  git -C "$tmp/sec" switch -q -c task/fuite
  cle='AKIA'"ZQ3DRSJ7XKW4PLMB"
  printf 'aws_access_key_id = %s\n' "$cle" >"$tmp/sec/conf.ini"
  git -C "$tmp/sec" add conf.ini && git -C "$tmp/sec" commit -q -m fuite
  code=0
  sortie="$(cd "$tmp/sec" && bash scripts/check.sh --host 2>&1)" || code=$?
  [[ $code -ne 0 ]] || echoue "gitleaks : fuite non trouvée : $sortie"
  grep -qF "$cle" <<<"$sortie" && echoue "gitleaks : la clé apparaît dans la sortie"
else
  echo "tools.sh : gitleaks absent, cas réel sauté"
  # Sans gitleaks, check.sh échoue et renvoie à doctor.
  code=0
  sortie="$(cd "$tmp/sec" && bash scripts/check.sh --host 2>&1)" || code=$?
  [[ $code -ne 0 ]] || echoue "secrets : gitleaks absent accepté"
  grep -qF -- '-- secrets : gitleaks absent, voir /izanagi:doctor' <<<"$sortie" || echoue "secrets : gitleaks absent : $sortie"
fi

# ============ refus.sh ============
refus="$racine/scripts/refus.sh"
[[ -f $refus ]] || echoue "scripts/refus.sh absent"
mkdir -p "$tmp/rf/.izanagi"
printf 'branche=main\n' >"$tmp/rf/.izanagi/config.env"
depot "$tmp/rf"
# Fichier absent : aucune sortie, code 0.
[[ -z $(cd "$tmp/rf" && bash "$refus" task/a) ]] || echoue "refus.sh : sortie sans refus.log"
printf '%s\n' '2026-11-18T10:00:00Z|task/a|push|push direct sur main' \
  '2026-11-18T10:01:00Z|task/b|destructif|git reset --hard' \
  '2026-11-18T10:02:00Z|task/a|verification|vérification rouge' >"$tmp/rf/.izanagi/refus.log"
sortie="$(cd "$tmp/rf" && bash "$refus" task/a)"
[[ $sortie == $'2026-11-18T10:00:00Z|task/a|push|push direct sur main\n2026-11-18T10:02:00Z|task/a|verification|vérification rouge' ]] || echoue "refus.sh : filtre : $sortie"
[[ -z $(cd "$tmp/rf" && bash "$refus" task/c) ]] || echoue "refus.sh : branche sans refus"
# Une branche dont le nom est le préfixe d'une autre ne prend pas ses lignes.
[[ -z $(cd "$tmp/rf" && bash "$refus" task) ]] || echoue "refus.sh : préfixe de branche"
# Un « | » dans un nom de branche est noté comme une espace : refus.sh le retrouve.
printf '%s\n' '2026-11-18T10:03:00Z|task/a b|push|push direct sur main' >>"$tmp/rf/.izanagi/refus.log"
[[ $(cd "$tmp/rf" && bash "$refus" 'task/a|b') == '2026-11-18T10:03:00Z|task/a b|push|push direct sur main' ]] || echoue "refus.sh : branche avec |"
(cd "$tmp/rf" && bash "$refus" 'task/a|b' --vider)
(cd "$tmp/rf" && bash "$refus" task/a --vider)
[[ $(cat "$tmp/rf/.izanagi/refus.log") == '2026-11-18T10:01:00Z|task/b|destructif|git reset --hard' ]] || echoue "refus.sh : vidage : $(cat "$tmp/rf/.izanagi/refus.log")"
if (cd "$tmp/rf" && bash "$refus" task/a --tout >/dev/null 2>&1); then echoue "refus.sh : option inconnue acceptée"; fi
if (cd "$tmp/rf" && bash "$refus" >/dev/null 2>&1); then echoue "refus.sh : sans argument accepté"; fi
mkdir "$tmp/rf-hors" && git -C "$tmp/rf-hors" init -q
code=0; (cd "$tmp/rf-hors" && bash "$refus" task/a >/dev/null 2>&1) || code=$?
[[ $code -eq 2 ]] || echoue "refus.sh : hors projet Izanagi : code $code"

# ============ status.sh ============
status="$racine/scripts/status.sh"
[[ -f $status ]] || echoue "scripts/status.sh absent"

mkdir "$tmp/st"
printf 'pile=rust\nprojet=Essai\nspec=s.md\nlieu_test=ici\n' >"$tmp/stv"
"$install" "$tmp/st" "$tmp/stv" >/dev/null
depot "$tmp/st"
cd "$tmp/st"
[[ $(bash "$status") == 'aucun flux ouvert' ]] || echoue "status sans flux : $(bash "$status")"

git switch -q -c jalon/essai
bash "$racine/scripts/state.sh" start jalon essai
bash "$racine/scripts/state.sh" set phase=tranches --commit
git switch -q -c jalon/essai-t1
bash "$racine/scripts/state.sh" set tranche=1 tour=2 risque=eleve --commit
git switch -q main
git switch -q -c task/x
git switch -q main
git switch -q -c autre/branche
git switch -q jalon/essai-t1
sortie="$(bash "$status")"
jour="$(date -u +%Y-%m-%d)"
attendu="  jalon/essai  jalon « essai », phase tranches  ($jour)
*   jalon/essai-t1  jalon « essai », phase tranches, tranche 1, tour 2, risque eleve  ($jour)
  task/x  sans état"
[[ $sortie == "$attendu" ]] || echoue "status : sortie inattendue :
$sortie"

# Un correctif né du jalon s'affiche sous son jalon, avant les tranches.
git switch -q jalon/essai
git switch -q -c fix/bouton
bash "$racine/scripts/state.sh" set correctif=bouton --commit
git switch -q jalon/essai-t1
sortie="$(bash "$status")"
attendu="  jalon/essai  jalon « essai », phase tranches  ($jour)
    fix/bouton  correctif « bouton »  ($jour)
*   jalon/essai-t1  jalon « essai », phase tranches, tranche 1, tour 2, risque eleve  ($jour)
  task/x  sans état"
[[ $sortie == "$attendu" ]] || echoue "status : correctif de jalon mal rangé :
$sortie"
# Un flux fix hors jalon garde sa propre ligne.
git switch -q main
git switch -q -c fix/seul
bash "$racine/scripts/state.sh" start fix seul --commit
sortie="$(bash "$status")"
grep -qF "* fix/seul  fix « seul », phase diagnostic" <<<"$sortie" || echoue "status : flux fix hors jalon : $sortie"
git switch -q jalon/essai-t1
git branch -q -D fix/seul

# Une branche qui n'existe que sur le dépôt distant apparaît une fois.
git init -q --bare "$tmp/st-distant.git"
git remote add origin "$tmp/st-distant.git"
git push -q origin jalon/essai task/x
git branch -q -D task/x
git fetch -q origin
sortie="$(bash "$status")"
[[ $(grep -c 'task/x' <<<"$sortie") -eq 1 ]] || echoue "status : branche distante absente ou en double : $sortie"
[[ $(grep -c 'jalon/essai  ' <<<"$sortie") -eq 1 ]] || echoue "status : branche locale et distante en double : $sortie"

mkdir "$tmp/hors" && git -C "$tmp/hors" init -q -b main
if (cd "$tmp/hors" && bash "$status" >/dev/null 2>&1); then echoue "status hors projet Izanagi accepté"; fi

# ============ doctor.sh ============
doctor="$racine/scripts/doctor.sh"
[[ -f $doctor ]] || echoue "scripts/doctor.sh absent"

mkdir "$tmp/dr"
"$install" "$tmp/dr" "$tmp/stv" >/dev/null
depot "$tmp/dr"
git -C "$tmp/dr" config core.hooksPath .githooks
cd "$tmp/dr"
controles_projet='hook pre-push|config.env|version du cadre|hook_push|hook_verification|hook_destructif|permissions|actions épinglées|contrat|état|jalon.md'

# diagnostic : remplit $sortie et $code.
diagnostic() {
  code=0
  sortie="$(bash "$doctor" "$tmp/dr" 2>&1)" || code=$?
}
# ecart <contrôle> <détail> : la ligne d'écart existe et le code vaut 1.
ecart() {
  diagnostic
  grep -qE "^écart   $1 : .*$2" <<<"$sortie" || echoue "doctor : écart « $1 : $2 » absent : $sortie"
  [[ $code -eq 1 ]] || echoue "doctor : code $code avec un écart sur $1"
}

diagnostic
for c in 'outil git' 'outil bash' 'outil gh' 'outil gitleaks' 'outil cargo'; do
  grep -qE "^(ok|écart)   +$c" <<<"$sortie" || echoue "doctor : contrôle « $c » absent : $sortie"
done
grep -E "^écart   ($controles_projet)" <<<"$sortie" && echoue "doctor : écart sur un projet sain : $sortie"
for c in 'hook pre-push' 'config.env' 'version du cadre' 'hook_push' 'hook_verification' 'hook_destructif' 'permissions' 'actions épinglées' 'contrat' 'état' 'jalon.md'; do
  grep -qxF "ok      $c" <<<"$sortie" || echoue "doctor : « ok      $c » absent : $sortie"
done

config="$tmp/dr/.izanagi/config.env"
cp "$config" "$tmp/dr-config"
retablir() { cp "$tmp/dr-config" "$config"; }

sed -i 's/^hook_push=.*/hook_push=avertit/' "$config"
ecart hook_push 'en avertissement'
retablir
sed -i 's/^hook_destructif=.*/hook_destructif=avertit/' "$config"
ecart hook_destructif 'en avertissement \(avertit\)'
retablir
sed -i 's/^hook_destructif=.*/hook_destructif=bloque/' "$config"
diagnostic
grep -qxF 'ok      hook_destructif' <<<"$sortie" || echoue "doctor : hook_destructif=bloque signalé : $sortie"
retablir
reglages="$tmp/dr/.claude/settings.json"
cp "$reglages" "$tmp/dr-settings"
sed -i '/"Read(\*.pem)"/d' "$reglages"
ecart permissions 'règles absentes de .claude/settings.json : Read\(\*\.pem\)'
rm "$reglages"
ecart permissions 'Read\(\.env\*\)'
cp "$tmp/dr-settings" "$reglages"
ci_dr="$tmp/dr/.github/workflows/ci.yml"
cp "$ci_dr" "$tmp/dr-ci"
sed -i '0,/uses: actions\/checkout@[0-9a-f]*/s//uses: actions\/checkout@v4/' "$ci_dr"
ecart 'actions épinglées' 'ci.yml:[0-9]+ actions/checkout@v4'
cp "$tmp/dr-ci" "$ci_dr"
# `chemins_sensibles` peut être vide, pas absent.
grep -qxF 'chemins_sensibles=' "$config" || echoue "doctor : le projet sain n'a pas chemins_sensibles vide"
sed -i '/^chemins_sensibles=/d' "$config"
ecart config.env 'chemins_sensibles'
retablir
sed -i 's/^izanagi_version=.*/izanagi_version=0.0.1/' "$config"
ecart 'version du cadre' '0.0.1'
retablir
sed -i '/^verification=/d' "$config"
ecart config.env 'verification'
retablir


# Navigateurs Playwright et outils de mutation : `navigateur` et `mutation` viennent de
# config.env, une clé absente vaut `non`. Des faux outils rendent 0 (présents) ou 1 (absents).
harness_dr="$tmp/dr/docs/agents/harness.md"
cp "$harness_dr" "$tmp/dr-harness"
printf -- '- composant : web | web | typescript |\n- composant : api | api | python |\n- couche : web | fonctionnelle | web/e2e | npx playwright test\n' >>"$harness_dr"
mkdir -p "$tmp/dr/web" "$tmp/dr/api" "$tmp/fm"
for f in cargo npx uv; do
  printf '#!/bin/sh\npwd >>"%s/$(basename "$0").cwd"\nexit "${FAUX_CODE:-0}"\n' "$tmp/fm" >"$tmp/fm/$f"
  chmod +x "$tmp/fm/$f"
done
path_initial="$PATH"
export PATH="$tmp/fm:$PATH" PLAYWRIGHT_BROWSERS_PATH="$tmp/pw"
mkdir -p "$tmp/pw"
# La pose écrit `mutation=oui` pour Rust : le cas de départ remet les deux clés à
# `non`, et les lignes ajoutées plus bas l'emportent (kv_get lit la dernière).
sed -i -e 's/^navigateur=.*/navigateur=non/' -e 's/^mutation=.*/mutation=non/' "$config" "$tmp/dr-config"

# Clés à `non` : aucun contrôle, aucun écart.
diagnostic
grep -qE 'Playwright|mutants|stryker|mutmut' <<<"$sortie" && echoue "doctor : contrôle sans navigateur ni mutation : $sortie"

printf 'navigateur=oui\n' >>"$config"
ecart 'navigateurs Playwright' 'absents : npx playwright install chromium'
mkdir "$tmp/pw/chromium-1234"
diagnostic
grep -qxF 'ok      navigateurs Playwright' <<<"$sortie" || echoue "doctor : navigateurs présents refusés : $sortie"
rmdir "$tmp/pw/chromium-1234"
# Chemin de style Windows (antislash) : le cache est trouvé quand même.
if command -v cygpath >/dev/null 2>&1; then
  mkdir "$tmp/pw/chromium-1234"
  PLAYWRIGHT_BROWSERS_PATH="$(cygpath -w "$tmp/pw")" diagnostic
  grep -qxF 'ok      navigateurs Playwright' <<<"$sortie" || echoue "doctor : chemin Windows du cache refusé : $sortie"
  rmdir "$tmp/pw/chromium-1234"
fi
# Sans couche fonctionnelle, navigateur=oui ne contrôle rien.
cp "$tmp/dr-harness" "$harness_dr"
diagnostic
grep -q 'Playwright' <<<"$sortie" && echoue "doctor : Playwright contrôlé sans couche fonctionnelle : $sortie"
printf -- '- composant : web | web | typescript |\n- composant : api | api | python |\n- couche : web | fonctionnelle | web/e2e | npx playwright test\n' >>"$harness_dr"
retablir

printf 'mutation=oui\n' >>"$config"
# Stryker sans le lanceur Vitest prendrait son lanceur par défaut : écart.
FAUX_CODE=0 ecart stryker 'absent pour web : npm install --save-dev @stryker-mutator/core @stryker-mutator/vitest-runner'
mkdir -p "$tmp/dr/web/node_modules/@stryker-mutator/vitest-runner"
FAUX_CODE=0 diagnostic
for c in 'cargo-mutants' 'stryker' 'mutmut'; do
  grep -qE "^ok      $c" <<<"$sortie" || echoue "doctor : $c présent refusé : $sortie"
done
grep -qF "$tmp/dr/web" "$tmp/fm/npx.cwd" || echoue "doctor : stryker pas lancé dans le dossier du composant"
export FAUX_CODE=1
ecart cargo-mutants 'absent pour .* : cargo install cargo-mutants'
ecart stryker 'absent pour web : npm install --save-dev @stryker-mutator/core @stryker-mutator/vitest-runner'
ecart mutmut 'absent pour api : uv add --dev mutmut'
unset FAUX_CODE
export PATH="$path_initial"
unset PLAYWRIGHT_BROWSERS_PATH
retablir
cp "$tmp/dr-harness" "$harness_dr"

git config --unset core.hooksPath
ecart 'hook pre-push' 'core.hooksPath'
git config core.hooksPath .githooks

printf 'flux=jalon\nnom=essai\nphase=tranches\n' >.izanagi/state.env
ecart état 'branche principale'
git switch -q -c task/x
ecart état 'task/x'
git switch -q -c jalon/essai
diagnostic
grep -qxF 'ok      état' <<<"$sortie" || echoue "doctor : état cohérent refusé : $sortie"
printf 'flux=jalon\nnom=essai\nphase=tranches\nplan=docs/plans/absent.md\n' >.izanagi/state.env
ecart état 'docs/plans/absent.md'
# Un correctif né du jalon : cohérent sur sa branche fix/<nom>, en écart ailleurs.
printf 'flux=jalon\nnom=essai\nphase=test\ncorrectif=bouton\n' >.izanagi/state.env
ecart état 'correctif « bouton » resté'
git switch -q -c fix/bouton
diagnostic
grep -qxF 'ok      état' <<<"$sortie" || echoue "doctor : correctif de jalon refusé sur sa branche : $sortie"
rm .izanagi/state.env
git switch -q main

mkdir -p docs/agents && echo x >docs/agents/jalon.md
ecart jalon.md 'upgrade'
rm docs/agents/jalon.md

if (cd "$tmp/hors" && bash "$doctor" "$tmp/hors" >/dev/null 2>&1); then echoue "doctor hors projet Izanagi accepté"; fi


# ============ mutation.sh ============
mutation="$racine/scripts/mutation.sh"
[[ -f $mutation ]] || echoue "scripts/mutation.sh absent"

# Projet à quatre composants : une pile par outil, et une pile sans outil.
mu="$tmp/mu"
mkdir -p "$mu/.izanagi" "$mu/docs/agents" "$mu/rs/src" "$mu/web/src" "$mu/api/src/app" "$mu/api/tests/unitaires" "$mu/outils"
printf 'mutation=oui\nmutation_delai=15\n' >"$mu/.izanagi/config.env"
printf -- '# Harnais\n\n- composant : rs | rs | rust |\n- composant : web | web | typescript |\n- composant : api | api | python |\n- composant : outils | outils | go |\n' >"$mu/docs/agents/harness.md"
printf 'pub fn somme(a: i32, b: i32) -> i32 {\n    a + b\n}\n' >"$mu/rs/src/lib.rs"
printf 'export function max(a: number, b: number) {\n  return a > b ? a : b;\n}\n' >"$mu/web/src/calc.ts"
printf '"""Calcul."""\n\ndef somme(a, b):\n    return a + b\n' >"$mu/api/src/app/calc.py"
printf 'package outils\n' >"$mu/outils/main.go"
echo '# Lisez-moi' >"$mu/README.md"
depot "$mu"
git -C "$mu" switch -q -c jalon/mu
base_mu="$(git -C "$mu" rev-parse HEAD)"

# Faux outils. Chacun note ses arguments et son dossier, et écrit le résultat que
# l'outil réel produit : missed.txt pour cargo-mutants, le rapport clear-text de
# Stryker, et `mutmut results` puis `mutmut show` pour mutmut.
# FAUX_ABSENT=<outil> : sa sonde `--version` échoue. FAUX_DORT=<s> : il dort avant d'agir.
fx="$tmp/fx"
mkdir -p "$fx"
cat >"$fx/cargo" <<'FAUX'
#!/bin/sh
[ "$1 $2" = "mutants --version" ] && { [ "$FAUX_ABSENT" = cargo ] && exit 1; exit 0; }
[ -n "$FAUX_DORT" ] && exec sleep "$FAUX_DORT"
pwd >"$FAUX_JOURNAL/cargo.cwd"
echo "$*" >"$FAUX_JOURNAL/cargo.args"
while [ $# -gt 0 ]; do
  case "$1" in
    --in-diff) cp "$2" "$FAUX_JOURNAL/cargo.diff"; shift ;;
    --output) sortie="$2"; shift ;;
  esac
  shift
done
mkdir -p "$sortie/mutants.out"
# FAUX_ECHEC=1 : tests de base en échec, listes vides et code 4.
[ -n "$FAUX_ECHEC" ] && { : >"$sortie/mutants.out/missed.txt"; exit 4; }
printf 'src/lib.rs:2:5: replace + with - in somme\n' >"$sortie/mutants.out/missed.txt"
printf 'src/lib.rs:2:5: replace somme -> i32 with 0\n' >"$sortie/mutants.out/caught.txt"
exit 2
FAUX
cat >"$fx/npx" <<'FAUX'
#!/bin/sh
[ "$*" = "--no-install stryker --version" ] && { [ "$FAUX_ABSENT" = npx ] && exit 1; exit 0; }
[ -n "$FAUX_DORT" ] && exec sleep "$FAUX_DORT"
pwd >"$FAUX_JOURNAL/npx.cwd"
echo "$*" >"$FAUX_JOURNAL/npx.args"
e=$(printf '\033')
printf '%s[Survived]%s ConditionalExpression\n' "$e[31m" "$e[39m"
printf '%ssrc/calc.ts%s:%s2%s:%s10%s\n' "$e[36m" "$e[39m" "$e[33m" "$e[39m" "$e[33m" "$e[39m"
printf '%s-     return a > b ? a : b;%s\n' "$e[31m" "$e[39m"
printf '%s+     return true ? a : b;%s\n' "$e[32m" "$e[39m"
printf 'Tests ran:\n    calc > max\n\n'
printf '[NoCoverage] StringLiteral\nsrc/calc.ts:9:1\n-   "a"\n+   ""\n'
exit 0
FAUX
cat >"$fx/uv" <<'FAUX'
#!/bin/sh
[ "$*" = "run mutmut --version" ] && { [ "$FAUX_ABSENT" = uv ] && exit 1; exit 0; }
case "$3" in
  run)
    [ -n "$FAUX_DORT" ] && exec sleep "$FAUX_DORT"
    pwd >"$FAUX_JOURNAL/uv.cwd"
    echo "$*" >"$FAUX_JOURNAL/uv.args"
    echo "$PYTEST_ADDOPTS" >"$FAUX_JOURNAL/uv.addopts"
    ;;
  results)
    printf '    app.calc.x_somme__mutmut_1: survived\n    autre.x_f__mutmut_1: survived\n    app.calc.x_somme__mutmut_2: no tests\n'
    ;;
  show)
    printf '# %s: survived\n--- src/app/calc.py\n+++ src/app/calc.py\n@@ -1,2 +1,2 @@\n def somme(a, b):\n-    return b + a\n+    return b - a\n' "$4"
    ;;
esac
exit 0
FAUX
chmod +x "$fx/cargo" "$fx/npx" "$fx/uv"
path_initial="$PATH"
export PATH="$fx:$PATH" FAUX_JOURNAL="$tmp/fxj"
mkdir -p "$FAUX_JOURNAL"

# passe [arguments] : remplit $sortie et $code.
passe() {
  code=0
  sortie="$(bash "$mutation" "$@" 2>&1)" || code=$?
}

# Usage faux : code 2.
passe
[[ $code -eq 2 ]] || echoue "mutation : sans argument : code $code : $sortie"
passe "$mu"
[[ $code -eq 2 ]] || echoue "mutation : un seul argument : code $code : $sortie"
passe "$tmp/introuvable" "$base_mu"
[[ $code -eq 2 ]] || echoue "mutation : dossier introuvable : code $code : $sortie"
passe "$mu" inconnu-xyz
[[ $code -eq 2 ]] || echoue "mutation : point fixe inconnu : code $code : $sortie"

# mutation=non, puis clé absente : désactivée, aucun outil lancé.
sed -i 's/^mutation=oui/mutation=non/' "$mu/.izanagi/config.env"
passe "$mu" "$base_mu"
[[ $code -eq 0 && $sortie == 'mutation : désactivée' ]] || echoue "mutation=non : $code : $sortie"
sed -i '/^mutation=/d' "$mu/.izanagi/config.env"
passe "$mu" "$base_mu"
[[ $code -eq 0 && $sortie == 'mutation : désactivée' ]] || echoue "mutation absente : $code : $sortie"
printf 'mutation=oui\n' >>"$mu/.izanagi/config.env"

# Diff de documentation et de test seuls : rien à muter.
echo 'Suite.' >>"$mu/README.md"
printf 'def test_x():\n    pass\n' >"$mu/api/tests/unitaires/test_calc.py"
git -C "$mu" add -A && git -C "$mu" commit -q -m doc
passe "$mu" "$base_mu"
[[ $code -eq 0 && $sortie == 'mutation : rien à muter' ]] || echoue "mutation : diff de documentation : $code : $sortie"
[[ -z $(ls "$FAUX_JOURNAL") ]] || echoue "mutation : outil lancé sur un diff de documentation"

# Un fichier de code par composant : un survivant par pile.
sed -i 's/a + b/b + a/' "$mu/rs/src/lib.rs" "$mu/api/src/app/calc.py"
sed -i 's/a > b ?/b < a ?/' "$mu/web/src/calc.ts"
# Un nom accentué : git le citerait en octal sans core.quotePath=false.
git -C "$mu" config core.quotePath true
printf 'export const e = 1;\n' >"$mu/web/src/éclat.ts"
printf 'import { max } from "./calc";\n' >"$mu/web/src/calc.test.ts"
echo '// x' >>"$mu/outils/main.go"
git -C "$mu" add -A && git -C "$mu" commit -q -m code
passe "$mu" "$base_mu"
[[ $code -eq 0 ]] || echoue "mutation : code $code : $sortie"
attendu='survivant | rs | rs/src/lib.rs:2 | replace + with - in somme
survivant | web | web/src/calc.ts:2 | ConditionalExpression : return true ? a : b;
survivant | api | api/src/app/calc.py:4 | app.calc.x_somme__mutmut_1
non muté | outils | pile sans outil
mutation : 3 survivants'
[[ $sortie == "$attendu" ]] || echoue "mutation : rapport faux : $sortie"
grep -qF "$mu/rs" "$FAUX_JOURNAL/cargo.cwd" || echoue "mutation : cargo pas lancé dans rs"
grep -qE '^mutants --in-diff .* --output ' "$FAUX_JOURNAL/cargo.args" || echoue "mutation : arguments cargo : $(cat "$FAUX_JOURNAL/cargo.args")"
grep -qF -- '+++ b/src/lib.rs' "$FAUX_JOURNAL/cargo.diff" || echoue "mutation : diff de cargo pas relatif au composant : $(cat "$FAUX_JOURNAL/cargo.diff")"
grep -qF 'main.go' "$FAUX_JOURNAL/cargo.diff" && echoue "mutation : diff de cargo hors du composant"
grep -qF "$mu/web" "$FAUX_JOURNAL/npx.cwd" || echoue "mutation : stryker pas lancé dans web"
[[ $(cat "$FAUX_JOURNAL/npx.args") == '--no-install stryker run --testRunner vitest --mutate src/calc.ts,src/éclat.ts --reporters clear-text' ]] ||
  echoue "mutation : arguments stryker : $(cat "$FAUX_JOURNAL/npx.args")"
grep -qF "$mu/api" "$FAUX_JOURNAL/uv.cwd" || echoue "mutation : mutmut pas lancé dans api"
[[ $(cat "$FAUX_JOURNAL/uv.args") == 'run mutmut run app.calc.x*' ]] || echoue "mutation : arguments mutmut : $(cat "$FAUX_JOURNAL/uv.args")"
grep -qF -- '--ignore=tests/fonctionnels' "$FAUX_JOURNAL/uv.addopts" || echoue "mutation : mutmut lance la couche fonctionnelle"

# cargo-mutants en échec (code 4) avec un missed.txt vide : échec signalé, pas
# « 0 survivant » en silence.
FAUX_ECHEC=1 passe "$mu" "$base_mu"
[[ $code -eq 0 ]] || echoue "mutation : échec de cargo : code $code"
grep -qxF "non muté | rs | échec de l'outil (code 4)" <<<"$sortie" || echoue "mutation : échec de cargo non signalé : $sortie"
grep -q '^survivant | rs ' <<<"$sortie" && echoue "mutation : survivant rs malgré l'échec : $sortie"

# Un outil absent : le composant n'est pas muté, les autres le sont.
rm -f "$FAUX_JOURNAL"/*
FAUX_ABSENT=npx passe "$mu" "$base_mu"
[[ $code -eq 0 ]] || echoue "mutation : outil absent : code $code"
grep -qxF 'non muté | web | outil absent' <<<"$sortie" || echoue "mutation : outil absent non signalé : $sortie"
[[ -f $FAUX_JOURNAL/npx.args ]] && echoue "mutation : stryker lancé alors qu'absent"
grep -qxF 'mutation : 2 survivants' <<<"$sortie" || echoue "mutation : outil absent : décompte faux : $sortie"

# Délai nul : aucun outil ne tourne.
rm -f "$FAUX_JOURNAL"/*
sed -i 's/^mutation_delai=.*/mutation_delai=0/' "$mu/.izanagi/config.env"
FAUX_DORT=30 passe "$mu" "$base_mu"
[[ $code -eq 0 ]] || echoue "mutation : délai nul : code $code"
for c in rs web api; do
  grep -qxF "non muté | $c | délai dépassé" <<<"$sortie" || echoue "mutation : délai nul : $c : $sortie"
done
grep -qxF 'mutation : 0 survivants' <<<"$sortie" || echoue "mutation : délai nul : décompte faux : $sortie"
[[ -z $(ls "$FAUX_JOURNAL") ]] || echoue "mutation : outil lancé avec un délai nul"
sed -i 's/^mutation_delai=.*/mutation_delai=15/' "$mu/.izanagi/config.env"

# Délai dépassé en cours de passe : timeout arrête l'outil qui dort, et le délai
# usé ne revient pas aux composants suivants.
if command -v timeout >/dev/null; then
  debut=$SECONDS
  IZANAGI_MUTATION_DELAI=2 FAUX_DORT=30 passe "$mu" "$base_mu"
  [[ $code -eq 0 ]] || echoue "mutation : délai dépassé : code $code"
  ((SECONDS - debut < 20)) || echoue "mutation : outil pas arrêté au délai"
  for c in rs web api; do
    grep -qxF "non muté | $c | délai dépassé" <<<"$sortie" || echoue "mutation : délai dépassé : $c : $sortie"
  done
fi
export PATH="$path_initial"
unset FAUX_JOURNAL

# ============ historique.sh ============
# Compte les commits de la branche absents de la base, par type, chore(izanagi) à part.
hi="$tmp/hi"
mkdir -p "$hi/.izanagi"
echo 'branche=main' >"$hi/.izanagi/config.env"
depot "$hi"
git -C "$hi" checkout -q -b jalon/essai
git -C "$hi" commit -q --allow-empty -m 'feat: a'
git -C "$hi" branch essai-base
for m in 'chore(izanagi): journal, tâche 1' 'chore(izanagi): état' 'fix(core): b' 'feat!: c' 'wip'; do
  git -C "$hi" commit -q --allow-empty -m "$m"
done
# Une tranche fusionnée par un commit de fusion : ses commits comptent, la fusion non.
git -C "$hi" checkout -q -b jalon/essai-t1
git -C "$hi" commit -q --allow-empty -m 'chore(izanagi): journal, tâche 2'
git -C "$hi" checkout -q jalon/essai
git -C "$hi" merge -q --no-ff --no-edit jalon/essai-t1
sortie="$(cd "$hi" && bash "$racine/scripts/historique.sh" jalon/essai)" || echoue "historique : code $?"
attendu='commits : 7
chore(izanagi) : 3 (43 %)
feat : 2 (29 %)
autre : 1 (14 %)
fix : 1 (14 %)'
[[ $sortie == "$attendu" ]] || echoue "historique : sortie fausse : $sortie"
sortie="$(cd "$hi" && bash "$racine/scripts/historique.sh" jalon/essai essai-base)"
grep -qxF 'commits : 6' <<<"$sortie" || echoue "historique : base passée en argument : $sortie"
code=0
(cd "$hi" && bash "$racine/scripts/historique.sh" absente 2>/dev/null) || code=$?
[[ $code -eq 2 ]] || echoue "historique : branche absente : code $code"
code=0
(cd "$tmp" && bash "$racine/scripts/historique.sh" main 2>/dev/null) || code=$?
[[ $code -eq 2 ]] || echoue "historique : hors projet : code $code"

# ============ attendre-ci.sh ============
# Un faux gh rend, à son k-ième appel, le fichier $FAUX_GH/<k> (le dernier s'il n'y en
# a pas d'autre) : la première ligne est son code, la suite sa sortie.
fg="$tmp/fg"
mkdir -p "$fg/bin"
cat >"$fg/bin/gh" <<'FAUX'
#!/usr/bin/env bash
n=$(($(cat "$FAUX_GH/n" 2>/dev/null || echo 0) + 1))
echo "$n" >"$FAUX_GH/n"
f="$FAUX_GH/$n"
[[ -f $f ]] || f="$FAUX_GH/$(ls "$FAUX_GH" | grep -E '^[0-9]+$' | sort -n | tail -1)"
tail -n +2 "$f"
exit "$(head -1 "$f")"
FAUX
chmod +x "$fg/bin/gh"
path_initial="$PATH"
export PATH="$fg/bin:$PATH" IZANAGI_CI_PAUSE=0 IZANAGI_CI_APPARITION=2

# reponses <code> <sortie> [<code> <sortie>]… : les réponses successives du faux gh.
reponses() {
  rm -rf "$fg/r"
  mkdir -p "$fg/r"
  export FAUX_GH="$fg/r"
  local k=1
  while (($#)); do
    printf '%s\n%s\n' "$1" "$2" >"$fg/r/$k"
    shift 2
    k=$((k + 1))
  done
}
ci() {
  code=0
  sortie="$(bash "$racine/scripts/attendre-ci.sh" "$@" 2>&1)" || code=$?
}

# Pas de check juste après le push, puis un check en cours, puis tout vert.
reponses 1 "no checks reported on the 'jalon/x' branch" \
  8 $'pending\tcheck (ubuntu-latest)\npass\taudit' \
  0 $'pass\tcheck (ubuntu-latest)\npass\taudit'
ci 7
[[ $code -eq 0 ]] || echoue "attendre-ci : vert : code $code : $sortie"
grep -qxF 'ci : verte' <<<"$sortie" || echoue "attendre-ci : vert : $sortie"
# Le vert se confirme par une relecture : 4 appels au moins.
(($(cat "$fg/r/n") >= 4)) || echoue "attendre-ci : vert sans relecture"

# Un check apparu à la relecture est attendu lui aussi.
reponses 0 $'pass\tcheck (ubuntu-latest)' \
  8 $'pass\tcheck (ubuntu-latest)\npending\tcheck (windows-latest)' \
  1 $'pass\tcheck (ubuntu-latest)\nfail\tcheck (windows-latest)'
ci 7
[[ $code -eq 1 ]] || echoue "attendre-ci : check tardif : code $code : $sortie"
grep -qE '^fail +check \(windows-latest\)$' <<<"$sortie" || echoue "attendre-ci : rouge : check non cité : $sortie"

# Aucun check : code 3, sans attendre au-delà du délai d'apparition.
reponses 1 "no checks reported on the 'task/x' branch"
debut=$SECONDS
ci 7
[[ $code -eq 3 ]] || echoue "attendre-ci : aucun check : code $code : $sortie"
((SECONDS - debut < 10)) || echoue "attendre-ci : aucun check : attente trop longue"

# Délai dépassé : code 4.
reponses 8 $'pending\tcheck (ubuntu-latest)'
IZANAGI_CI_PAUSE=1 ci 7 --delai 0
[[ $code -eq 4 ]] || echoue "attendre-ci : délai : code $code : $sortie"

# Erreur de gh : code 2.
reponses 4 'HTTP 401: Bad credentials'
ci 7
[[ $code -eq 2 ]] || echoue "attendre-ci : erreur gh : code $code : $sortie"

# Appel refusé.
ci
[[ $code -eq 2 ]] || echoue "attendre-ci : sans argument : code $code"
ci 7 --delai x
[[ $code -eq 2 ]] || echoue "attendre-ci : délai invalide : code $code"
export PATH="$path_initial"
unset FAUX_GH IZANAGI_CI_PAUSE IZANAGI_CI_APPARITION

echo "tools.sh : tous les cas passent"
