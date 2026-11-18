#!/usr/bin/env bash
# Teste les scripts des commandes upgrade, status et doctor :
# scripts/migrations/0.4.0.sh, scripts/status.sh et scripts/doctor.sh.
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
grep -qxF 'identique  .izanagi/config.env' <<<"$sortie" || echoue "config.env migré différent du gabarit : $sortie"
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
# La pose courante, relancée avec ces valeurs, trouve ces trois fichiers identiques au gabarit.
{ echo pile=rust; valeurs_de "$tmp/p04"; } >"$tmp/p04v6"
sortie="$("$install" "$tmp/p04" "$tmp/p04v6")"
for f in .izanagi/config.env .izanagi/.gitignore .claude/settings.json; do
  grep -qxF "identique  $f" <<<"$sortie" || echoue "migration 0.6.0 : $f différent du gabarit : $sortie"
done
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
  for f in docs/agents/harness.md AGENTS.md .claude/settings.json .gitleaks.toml .github/dependabot.yml .github/workflows/securite.yml docs/standards/rust.md; do
    grep -qxF "créé       $f" <<<"$sortie" || echoue "0.1.1 : $f non créé : $sortie"
  done
  [[ $(grep -c '^créé' <<<"$sortie") -eq 7 ]] || echoue "0.1.1 : créations en trop : $sortie"
  grep -qxF 'identique  .izanagi/config.env' <<<"$sortie" || echoue "0.1.1 : config.env migré différent du gabarit : $sortie"
else
  echo "0.1.1 : commit 5bb1144 absent du dépôt, cas sauté"
fi

# ============ check.sh : recherche de secrets ============
# Un faux gitleaks note ses arguments et rend le code de $GITLEAKS_CODE. Le projet n'a
# qu'un composant sans gabarit, dont la section ne lance rien, et pour seul système
# cible le système courant : `check.sh --host` ne lance que la recherche de secrets.
case "$(uname -s)" in
  MINGW* | MSYS* | CYGWIN*) ici=windows ;;
  Darwin*) ici=macos ;;
  *) ici=linux ;;
esac
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

echo "tools.sh : tous les cas passent"
