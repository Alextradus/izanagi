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
[[ $(grep -c '^créé' <<<"$sortie") -eq 11 ]] || echoue "première pose : $sortie"
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
[[ $(grep -c '^identique' <<<"$sortie") -eq 10 ]] || echoue "relance : $sortie"
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
# Liste des fichiers à copier, sans WSL : le fichier supprimé non indexé disparaît.
eval "$(sed -n '/^lister_fichiers() {/,/^}/p' "$tmp/m1/scripts/check.sh")"
mkdir "$tmp/l"
(
  cd "$tmp/l"
  git init -q
  mkdir "d e"
  echo 1 >"d e/f g.txt"; echo 2 >gone.txt; echo 3 >ign.txt; echo 4 >.gitignore
  echo ign.txt >.gitignore
  git add -A
  echo 5 >neuf.txt
  rm gone.txt
  [[ $(lister_fichiers | sort -z | tr '\0' '|') == ".gitignore|d e/f g.txt|neuf.txt|" ]] || exit 1
) || echoue "lister_fichiers : liste inattendue"
# Test de la sélection de cibles : éléments entiers, pas sous-chaînes.
grep -qF '",$cibles," == *,linux,*' "$tmp/m1/scripts/check.sh" || echoue "cibles : élément entier"

# --- piles TypeScript et Python, dev.sh ---
mkdir "$tmp/t1"
printf '%s
' 'composant=api|api|typescript|npm run dev' 'composant=web|web|typescript|npm run dev' projet=essai spec=s.md lieu_test=ici >"$tmp/t1v"
sortie="$("$install" "$tmp/t1" "$tmp/t1v")"
[[ $(grep -c 'actions/setup-node' "$tmp/t1/.github/workflows/ci.yml") -eq 1 ]] || echoue "setup-node : un seul attendu"
grep -qF 'node-version: lts/*' "$tmp/t1/.github/workflows/ci.yml" || echoue "ci.yml : node-version"
grep -qF 'cache: npm' "$tmp/t1/.github/workflows/ci.yml" && echoue "ci.yml : cache npm sans cache-dependency-path"
[[ $(grep -c '^# --- composant' "$tmp/t1/scripts/check.sh") -eq 2 ]] || echoue "check.sh : deux sections"
grep -qF 'npm ci' "$tmp/t1/scripts/check.sh" || echoue "check.sh : npm ci"
grep -qF 'npm run format:check' "$tmp/t1/scripts/check.sh" || echoue "check.sh : format:check"
bash -n "$tmp/t1/scripts/check.sh" || echoue "check.sh typescript invalide"
[[ -x $tmp/t1/scripts/dev.sh ]] || echoue "dev.sh absent ou non exécutable"
grep -qxF '(cd "api" && npm run dev) &' "$tmp/t1/scripts/dev.sh" || echoue "dev.sh : lancement api"
grep -qxF '(cd "web" && npm run dev) &' "$tmp/t1/scripts/dev.sh" || echoue "dev.sh : lancement web"
grep -qF 'trap arreter EXIT' "$tmp/t1/scripts/dev.sh" || echoue "dev.sh : trap"
bash -n "$tmp/t1/scripts/dev.sh" || echoue "dev.sh invalide"
grep -qF 'kill 0' "$tmp/t1/scripts/dev.sh" && echoue "dev.sh : kill 0 subsiste"
grep -qxF 'pids+=("$!")' "$tmp/t1/scripts/dev.sh" || echoue "dev.sh : PID non noté"
grep -qF 'taskkill' "$tmp/t1/scripts/dev.sh" || echoue "dev.sh : taskkill absent"
# Aucun lancement : dev.sh refuse de tourner à vide.
mkdir "$tmp/t4"
printf '%s
' 'composant=a|a|typescript|' 'composant=b|b|typescript|' projet=essai spec=s.md lieu_test=ici >"$tmp/t4v"
"$install" "$tmp/t4" "$tmp/t4v" >/dev/null
set +e; "$tmp/t4/scripts/dev.sh" 2>"$tmp/err"; code=$?; set -e
[[ $code -eq 1 ]] || echoue "dev.sh sans lancement : code $code"
grep -qF 'aucun composant à lancer' "$tmp/err" || echoue "dev.sh sans lancement : message"
# hors_revue : union des piles, sans doublon.
mkdir "$tmp/t5"
printf '%s
' 'composant=cli|cli|rust|' 'composant=web|web|typescript|' projet=essai spec=s.md lieu_test=ici >"$tmp/t5v"
"$install" "$tmp/t5" "$tmp/t5v" >/dev/null
grep -qF '`Cargo.lock`' "$tmp/t5/docs/CODING_STANDARDS.md" || echoue "hors_revue : Cargo.lock"
grep -qF '`package-lock.json`' "$tmp/t5/docs/CODING_STANDARDS.md" || echoue "hors_revue : package-lock.json"
[[ $(grep -o 'docs/superpowers/plans/' "$tmp/t5/docs/CODING_STANDARDS.md" | wc -l) -eq $(grep -o 'docs/superpowers/plans/' "$tmp/t1/docs/CODING_STANDARDS.md" | wc -l) ]] || echoue "hors_revue : doublon"
grep -qF 'avec `scripts/dev.sh`' "$tmp/t1/docs/agents/jalon.md" || echoue "jalon.md : test manuel dev.sh"
grep -qF '`package-lock.json`' "$tmp/t1/docs/CODING_STANDARDS.md" || echoue "CODING_STANDARDS.md : package-lock.json"

# Le fichier de valeurs l'emporte sur le test manuel par défaut de dev.sh.
mkdir "$tmp/t2"
printf '%s
' 'composant=api|api|typescript|npm run dev' 'composant=web|web|typescript|' projet=essai spec=s.md lieu_test=ici 'test_manuel=npm start' >"$tmp/t2v"
"$install" "$tmp/t2" "$tmp/t2v" >/dev/null
grep -qF 'avec `npm start`' "$tmp/t2/docs/agents/jalon.md" || echoue "test_manuel du fichier de valeurs ignoré"
grep -qF '"web"' "$tmp/t2/scripts/dev.sh" && echoue "dev.sh lance un composant sans lancement"

mkdir "$tmp/t3"
printf '%s
' 'composant=outil|.|python|' projet=essai spec=s.md lieu_test=ici test_manuel=x >"$tmp/t3v"
"$install" "$tmp/t3" "$tmp/t3v" >/dev/null
grep -qF 'uv sync --locked' "$tmp/t3/scripts/check.sh" || echoue "check.sh : uv sync"
grep -qF 'uv run ruff check' "$tmp/t3/scripts/check.sh" || echoue "check.sh : ruff check"
grep -qF 'astral-sh/setup-uv' "$tmp/t3/.github/workflows/ci.yml" || echoue "ci.yml : setup-uv"
bash -n "$tmp/t3/scripts/check.sh" || echoue "check.sh python invalide"
[[ -e $tmp/t3/scripts/dev.sh ]] && echoue "dev.sh posé avec un seul composant"

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

# --- harness.md ---
grep -qxF -- '- composant : cli | . | rust | cargo run' "$tmp/m1/docs/agents/harness.md" || echoue "harness.md : ligne composant"
grep -qxF -- '- **Systèmes cibles** : linux,windows.' "$tmp/m1/docs/agents/harness.md" || echoue "harness.md : systèmes"
grep -qF '| cli | `.` | rust | `cargo run` |' "$tmp/m1/docs/agents/harness.md" || echoue "harness.md : tableau"
grep -q '{{' "$tmp/m1/docs/agents/harness.md" && echoue "harness.md garde un {{"
[[ -f $tmp/m6/docs/agents/harness.md ]] || echoue "harness.md absent sans composant"
grep -q '^- composant :' "$tmp/m6/docs/agents/harness.md" && echoue "harness.md : ligne composant sans composant"
grep -qF 'Aucun composant' "$tmp/m6/docs/agents/harness.md" || echoue "harness.md : note de tableau vide"

echo "install.sh : tous les cas passent"
