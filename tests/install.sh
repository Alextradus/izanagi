#!/usr/bin/env bash
# Teste scripts/install.sh : première pose, relance sans écrasement, écart signalé,
# valeur manquante refusée.
set -euo pipefail

racine="$(cd "$(dirname "$0")/.." && pwd)"
install="$racine/scripts/install.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echoue() { echo "ÉCHEC : $*" >&2; exit 1; }

mkdir "$tmp/p"
cat >"$tmp/v" <<'FIN'
pile=rust
projet=Essai Rapide
spec=docs/spec.md
lieu_test=dans WSL
decisions=le §14 de la spec
FIN

sortie="$("$install" "$tmp/p" "$tmp/v")"
[[ $(grep -c '^créé' <<<"$sortie") -eq 10 ]] || echoue "première pose : $sortie"
[[ -x $tmp/p/scripts/check.sh && -x $tmp/p/.githooks/pre-push ]] || echoue "bit exécutable"
grep -q '{{' "$tmp/p/CLAUDE.md" && echoue "CLAUDE.md garde un {{"
grep -qF 'Les décisions sont dans le §14 de la spec.' "$tmp/p/docs/agents/domain.md" || echoue "domain.md : décisions mal accordées"
grep -qF 'de le §14' "$tmp/p/docs/agents/domain.md" && echoue "domain.md contient « de le »"
grep -qxF -- '- **Vault** : non.' "$tmp/p/docs/agents/jalon.md" || echoue "jalon.md : vault absent mal affiché"
grep -q 'github.workflow' "$tmp/p/.github/workflows/ci.yml" || echoue "ci.yml a perdu ses expressions"
[[ -e $tmp/p/docs/agents/vault.md ]] && echoue "vault.md posé sans vault"

echo "règle du projet" >>"$tmp/p/docs/CODING_STANDARDS.md"
avant="$(cat "$tmp/p/docs/CODING_STANDARDS.md")"
sortie="$("$install" "$tmp/p" "$tmp/v")"
grep -q '^différent  docs/CODING_STANDARDS.md' <<<"$sortie" || echoue "écart non signalé : $sortie"
[[ $(grep -c '^identique' <<<"$sortie") -eq 9 ]] || echoue "relance : $sortie"
[[ $(cat "$tmp/p/docs/CODING_STANDARDS.md") == "$avant" ]] || echoue "fichier écrasé"
rapport="$(sed -n 's/^rapport : //p' <<<"$sortie")"
grep -q '^-règle du projet' "$rapport/diff/docs/CODING_STANDARDS.md.diff" || echoue "diff sans l'ajout du projet"

echo "vault=C:/Vault/essai" >>"$tmp/v"
sortie="$("$install" "$tmp/p" "$tmp/v")"
grep -q '^créé       docs/agents/vault.md' <<<"$sortie" || echoue "vault.md non posé : $sortie"
rapport="$(sed -n 's/^rapport : //p' <<<"$sortie")"
grep -qxF -- '- **Vault** : `C:/Vault/essai`.' "$rapport/rendu/docs/agents/jalon.md" || echoue "jalon.md : chemin du vault sans accents graves"

# Nom de projet hostile au shell : apostrophe, &, /, majuscule accentuée.
mkdir "$tmp/r"
printf "pile=rust\nprojet=Élan d'été & Co/x\nspec=s.md\nlieu_test=ici\n" >"$tmp/u"
LC_ALL=C "$install" "$tmp/r" "$tmp/u" >/dev/null
# Même résultat sous une locale UTF-8, où `${x,,}` changerait « É ».
mkdir "$tmp/r8"
LC_ALL=C.UTF-8 "$install" "$tmp/r8" "$tmp/u" >/dev/null
cmp -s "$tmp/r/scripts/check.sh" "$tmp/r8/scripts/check.sh" || echoue "projet_dossier dépend de la locale"
bash -n "$tmp/r/scripts/check.sh" || echoue "check.sh n'est plus du shell valide"
grep -qF '.cache/lan-d-t-co-x-wsl' "$tmp/r/scripts/check.sh" || echoue "cache WSL du nom hostile"
grep -qF "# Élan d'été & Co/x" "$tmp/r/CLAUDE.md" || echoue "CLAUDE.md : le nom du projet doit rester tel quel"

# projet_dossier donné par le fichier de valeurs (le name de Cargo.toml).
mkdir "$tmp/s"
printf 'pile=rust\nprojet=Atelier\nprojet_dossier=atelier-editeur\nspec=s.md\nlieu_test=ici\n' >"$tmp/x"
"$install" "$tmp/s" "$tmp/x" >/dev/null
grep -qF '.cache/atelier-editeur-wsl' "$tmp/s/scripts/check.sh" || echoue "cache WSL : projet_dossier explicite"

# --- composants multiples, systèmes, squelette de check.sh ---
base=(projet=essai spec=s.md lieu_test=ici test_manuel=x fichier_version=y)
mkdir "$tmp/m1"
printf '%s
' 'composant=cli|.|rust|cargo run' systemes=linux,windows "${base[@]}" >"$tmp/m1v"
sortie="$("$install" "$tmp/m1" "$tmp/m1v")"
grep -q '^composants : cli(rust)$' <<<"$sortie" || echoue "ligne composants : $sortie"
grep -q '^pile :' <<<"$sortie" && echoue "ligne pile : conservée"
grep -q '^à écrire' <<<"$sortie" && echoue "à écrire pour une pile connue"
grep -qxF '# --- composant cli (rust) ---' "$tmp/m1/scripts/check.sh" || echoue "marqueur de composant"
grep -qx '  verifier_cli' "$tmp/m1/scripts/check.sh" || echoue "appel verifier_cli"
bash -n "$tmp/m1/scripts/check.sh" || echoue "check.sh invalide"
grep -qxF '        os: [ubuntu-latest, windows-latest]' "$tmp/m1/.github/workflows/ci.yml" || echoue "ci.yml : os"
grep -qF 'run: bash scripts/check.sh --host' "$tmp/m1/.github/workflows/ci.yml" || echoue "ci.yml : run"
grep -q 'cargo test' "$tmp/m1/.github/workflows/ci.yml" && echoue "ci.yml garde cargo test"
grep -qF 'rust-toolchain' "$tmp/m1/.github/workflows/ci.yml" || echoue "ci.yml : installation Rust"
[[ -e $tmp/m1/fragments || -e $tmp/m1/defaults.env ]] && echoue "fragments posés"

# 0.1 : pile=rust sans composant= équivaut à un composant `rust|.|rust|`.
mkdir "$tmp/m2"
printf '%s\n' pile=rust "${base[@]}" >"$tmp/m2v"
sortie="$("$install" "$tmp/m2" "$tmp/m2v")"
grep -q '^composants : rust(rust)$' <<<"$sortie" || echoue "compat pile : $sortie"
diff <(sed -e 's/\bcli\b/rust/g' -e 's/verifier_cli/verifier_rust/' "$tmp/m1/scripts/check.sh") "$tmp/m2/scripts/check.sh" >/dev/null || echoue "compat pile : check.sh diffère"

# Vérification dans WSL par copie, et --clean.
grep -qF '.cache/essai-wsl' "$tmp/m1/scripts/check.sh" || echoue "cache WSL du projet"
grep -qF 'CARGO_TARGET_DIR' "$tmp/m1/scripts/check.sh" && echoue "CARGO_TARGET_DIR subsiste"
grep -qxF 'cibles="linux,windows"' "$tmp/m1/scripts/check.sh" || echoue "cibles linux,windows"
grep -qF 'verifier_wsl' "$tmp/m1/scripts/check.sh" || echoue "verifier_wsl absent"
grep -qF 'wsl : absent, étape sautée' "$tmp/m1/scripts/check.sh" || echoue "message wsl absent"
grep -qF 'cache WSL vidé' "$tmp/m1/scripts/check.sh" || echoue "message --clean"
mkdir "$tmp/w1"
printf '%s
' 'composant=cli|.|rust|' systemes=windows "${base[@]}" >"$tmp/w1v"
"$install" "$tmp/w1" "$tmp/w1v" >/dev/null
grep -qxF 'cibles="windows"' "$tmp/w1/scripts/check.sh" || echoue "cibles windows seul"
bash -n "$tmp/w1/scripts/check.sh" || echoue "check.sh windows seul invalide"
# Test de la sélection de cibles : éléments entiers, pas sous-chaînes.
grep -qF '",$cibles," == *,linux,*' "$tmp/m1/scripts/check.sh" || echoue "cibles : élément entier"

# Pile sans gabarit : section à écrire, et le script reste exécutable.
mkdir "$tmp/m3"
printf '%s\n' 'composant=outil|.|zig|' "${base[@]}" >"$tmp/m3v"
sortie="$("$install" "$tmp/m3" "$tmp/m3v")"
grep -qxF 'à écrire   outil (zig)' <<<"$sortie" || echoue "à écrire : $sortie"
grep -qxF '    # À ÉCRIRE : outil (zig), format, lint, tests' "$tmp/m3/scripts/check.sh" || echoue "section à écrire"
sed -i 's/^.*# À ÉCRIRE.*$/    true/' "$tmp/m3/scripts/check.sh"
(cd "$tmp/m3" && scripts/check.sh --host >/dev/null) || echoue "check.sh --host avec true"
sed -i 's/^    true$/    false/' "$tmp/m3/scripts/check.sh"
if (cd "$tmp/m3" && scripts/check.sh --host >/dev/null 2>&1); then echoue "check.sh --host avec false réussit"; fi
set +e; (cd "$tmp/m3" && scripts/check.sh --inconnu >/dev/null 2>&1); code=$?; set -e
[[ $code -eq 2 ]] || echoue "option inconnue : code $code"

# Chemin avec espace.
mkdir -p "$tmp/m4/apps/mon front"
printf '%s\n' 'composant=web|apps/mon front|zig|' "${base[@]}" >"$tmp/m4v"
"$install" "$tmp/m4" "$tmp/m4v" >/dev/null
sed -i "s|^.*# À ÉCRIRE.*\$|    pwd > \"$tmp/m4/vu\"|" "$tmp/m4/scripts/check.sh"
(cd "$tmp/m4" && scripts/check.sh --host >/dev/null) || echoue "chemin avec espace : échec"
[[ $(cat "$tmp/m4/vu") == */apps/mon\ front ]] || echoue "chemin avec espace : $(cat "$tmp/m4/vu")"

# Refus avant écriture : nom de composant invalide, système inconnu.
for ligne in 'composant=Web|.|rust|' 'systemes=linux,bsd' 'composant=a|a"b|rust|' 'composant=a|a$b|rust|' 'composant=a|a`b|rust|' 'composant=a|a\b|rust|'; do
  mkdir "$tmp/m5"
  printf '%s\n' "$ligne" "${base[@]}" >"$tmp/m5v"
  [[ $ligne == systemes=* ]] && printf '%s\n' 'composant=cli|.|rust|' "$ligne" "${base[@]}" >"$tmp/m5v"
  if "$install" "$tmp/m5" "$tmp/m5v" 2>"$tmp/err"; then echoue "$ligne accepté"; fi
  grep -q 'refusé' "$tmp/err" || echoue "$ligne : message sans refus"
  [[ -z $(ls -A "$tmp/m5") ]] || echoue "$ligne : écriture malgré le refus"
  rm -rf "$tmp/m5"
done

# Ni composant ni pile : pas de check.sh ni de CI.
mkdir "$tmp/m6"
printf '%s\n' "${base[@]}" >"$tmp/m6v"
sortie="$("$install" "$tmp/m6" "$tmp/m6v")"
grep -qxF 'composants : aucun' <<<"$sortie" || echoue "sans composant : $sortie"
[[ -e $tmp/m6/scripts/check.sh || -e $tmp/m6/.github/workflows/ci.yml ]] && echoue "check.sh ou ci.yml posé sans composant"

# Branche avec `,` et `#`, permis par git : la CI la garde en une seule entrée.
mkdir "$tmp/b"
printf 'pile=rust\nprojet=essai\nbranche=feat/x,y#z\nspec=s.md\nlieu_test=ici\n' >"$tmp/y"
"$install" "$tmp/b" "$tmp/y" >/dev/null
grep -qxF '    branches: ["feat/x,y#z"]' "$tmp/b/.github/workflows/ci.yml" || echoue "ci.yml : branche non citée"

# Branche avec `"` ou `\` : refusée avant toute écriture.
for branche in 'a"b' 'a\b'; do
  mkdir "$tmp/c"
  printf 'pile=rust\nprojet=essai\nbranche=%s\nspec=s.md\nlieu_test=ici\n' "$branche" >"$tmp/z"
  if "$install" "$tmp/c" "$tmp/z" 2>"$tmp/err"; then echoue "branche $branche acceptée"; fi
  grep -q 'refusée' "$tmp/err" || echoue "branche $branche : message sans refus"
  [[ -z $(ls -A "$tmp/c") ]] || echoue "branche $branche : écriture malgré le refus"
  rm -rf "$tmp/c"
done

mkdir "$tmp/q"
printf 'pile=rust\nprojet=essai\n' >"$tmp/w"
if "$install" "$tmp/q" "$tmp/w" 2>"$tmp/err"; then echoue "valeur manquante acceptée"; fi
grep -q 'spec' "$tmp/err" || echoue "message sans la clé manquante"
[[ -z $(ls -A "$tmp/q") ]] || echoue "écriture malgré une valeur manquante"

echo "install.sh : tous les cas passent"
