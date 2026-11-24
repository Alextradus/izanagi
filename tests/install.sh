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
[[ $(grep -c '^créé' <<<"$sortie") -eq 21 ]] || echoue "première pose : $sortie"
grep -qxF 'useDefault = true' "$tmp/p/.gitleaks.toml" || echoue ".gitleaks.toml n'étend pas la configuration par défaut"
grep -qF 'gitleaks git' "$tmp/p/scripts/check.sh" || echoue "check.sh ne lance pas gitleaks"
for f in .izanagi/config.env .izanagi/.gitignore .claude/settings.json AGENTS.md .github/pull_request_template.md; do
  grep -qxF "créé       $f" <<<"$sortie" || echoue "$f non posé : $sortie"
done
[[ ! -e $tmp/p/docs/agents/jalon.md ]] || echoue "docs/agents/jalon.md encore posé"
# shellcheck source=../scripts/lib.sh
. "$racine/scripts/lib.sh"
config="$tmp/p/.izanagi/config.env"
[[ $(kv_get "$config" branche) == main ]] || echoue "config.env : branche"
[[ $(kv_get "$config" verification) == scripts/check.sh ]] || echoue "config.env : verification"
[[ $(kv_get "$config" izanagi_version) == "$(plugin_version)" ]] || echoue "config.env : izanagi_version"
[[ $(kv_get "$config" hook_push) == bloque && $(kv_get "$config" hook_verification) == bloque ]] || echoue "config.env : hooks"
[[ $(kv_get "$config" decisions) == 'le §14 de la spec' ]] || echoue "config.env : decisions"
[[ $(kv_get "$config" spec) == docs/spec.md ]] || echoue "config.env : spec"
[[ $(kv_get "$config" lieu_test) == 'dans WSL' ]] || echoue "config.env : lieu_test"
grep -q '{{' "$config" && echoue "config.env garde un {{"
[[ $(cat "$tmp/p/.izanagi/.gitignore") == $'journal/*/\nrefus.log' ]] || echoue ".izanagi/.gitignore"
[[ $(kv_get "$config" hook_destructif) == demande ]] || echoue "config.env : hook_destructif"
# Mutation (décision 111) : `oui` quand toutes les piles des composants ont un gabarit.
[[ $(kv_get "$config" mutation) == oui ]] || echoue "config.env : mutation pour rust"
[[ $(kv_get "$config" mutation_delai) == 15 ]] || echoue "config.env : mutation_delai"
[[ $(kv_get "$config" navigateur) == non ]] || echoue "config.env : navigateur par défaut"
[[ $(kv_get "$config" langue_publique) == fr ]] || echoue "config.env : langue_publique par défaut"
[[ $(kv_get "$config" version_composant) == rust ]] || echoue "config.env : version_composant par défaut vaut le premier composant"
# Le template de PR : quatre titres, chacun suivi d'un commentaire HTML.
pr="$tmp/p/.github/pull_request_template.md"
[[ $(grep -c '^## ' "$pr") -eq 4 ]] || echoue "template de PR : quatre titres attendus"
for titre in Quoi Pourquoi Vérification Risque; do
  grep -qxF "## $titre" "$pr" || echoue "template de PR : titre « $titre » absent"
  [[ $(grep -A2 -xF "## $titre" "$pr" | grep -c '^<!-- .* -->$') -eq 1 ]] || echoue "template de PR : « $titre » sans ligne de commentaire HTML"
done
for regle in 'Read(.env*)' 'Read(!.env.example)' 'Read(*.pem)' 'Read(*.key)' 'Read(id_rsa*)' 'Read(id_ed25519*)' 'Read(id_ecdsa*)' 'Read(credentials*)' 'Edit(.env*)' 'Edit(!.env.example)' 'Edit(*.pem)' 'Edit(*.key)' 'Edit(id_rsa*)' 'Edit(id_ed25519*)' 'Edit(id_ecdsa*)' 'Edit(credentials*)'; do
  grep -qF "\"$regle\"" "$tmp/p/.claude/settings.json" || echoue ".claude/settings.json : règle $regle absente"
done
grep -q '{{' "$tmp/p/AGENTS.md" && echoue "AGENTS.md garde un {{"
grep -qi 'izanagi' "$tmp/p/AGENTS.md" && echoue "AGENTS.md nomme Izanagi"
grep -qF 'docs/spec.md' "$tmp/p/AGENTS.md" || echoue "AGENTS.md : spec"
grep -qF 'scripts/check.sh' "$tmp/p/AGENTS.md" || echoue "AGENTS.md : vérification"
grep -qF '.izanagi/config.env' "$tmp/p/CLAUDE.md" || echoue "CLAUDE.md ne cite pas config.env"
[[ -x $tmp/p/scripts/check.sh && -x $tmp/p/.githooks/pre-push ]] || echoue "bit exécutable"
grep -q '{{' "$tmp/p/CLAUDE.md" && echoue "CLAUDE.md garde un {{"
grep -qF 'Les décisions sont dans le §14 de la spec.' "$tmp/p/docs/agents/domain.md" || echoue "domain.md : décisions mal accordées"
grep -qF 'de le §14' "$tmp/p/docs/agents/domain.md" && echoue "domain.md contient « de le »"
[[ $(kv_get "$config" vault) == non ]] || echoue "config.env : vault absent"
grep -q 'github.workflow' "$tmp/p/.github/workflows/ci.yml" || echoue "ci.yml a perdu ses expressions"
[[ -e $tmp/p/docs/agents/vault.md ]] && echoue "vault.md posé sans vault"

echo "règle du projet" >>"$tmp/p/docs/CODING_STANDARDS.md"
avant="$(cat "$tmp/p/docs/CODING_STANDARDS.md")"
sortie="$("$install" "$tmp/p" "$tmp/v")"
grep -q '^différent  docs/CODING_STANDARDS.md' <<<"$sortie" || echoue "écart non signalé : $sortie"
[[ $(grep -c '^identique' <<<"$sortie") -eq 20 ]] || echoue "relance : $sortie"
[[ $(cat "$tmp/p/docs/CODING_STANDARDS.md") == "$avant" ]] || echoue "fichier écrasé"
rapport="$(sed -n 's/^rapport : //p' <<<"$sortie")"
grep -q '^-règle du projet' "$rapport/diff/docs/CODING_STANDARDS.md.diff" || echoue "diff sans l'ajout du projet"

echo "vault=C:/Vault/essai" >>"$tmp/v"
sortie="$("$install" "$tmp/p" "$tmp/v")"
grep -q '^créé       docs/agents/vault.md' <<<"$sortie" || echoue "vault.md non posé : $sortie"
rapport="$(sed -n 's/^rapport : //p' <<<"$sortie")"
[[ $(kv_get "$rapport/rendu/.izanagi/config.env" vault) == C:/Vault/essai ]] || echoue "config.env : chemin du vault"

# Une version passée dans les valeurs remplace celle du plugin : la relance compare à valeurs égales.
mkdir "$tmp/iv"
printf 'pile=rust\nprojet=Essai\nspec=s.md\nlieu_test=ici\nizanagi_version=0.1.0\n' >"$tmp/ivv"
"$install" "$tmp/iv" "$tmp/ivv" >/dev/null
[[ $(kv_get "$tmp/iv/.izanagi/config.env" izanagi_version) == 0.1.0 ]] || echoue "izanagi_version des valeurs ignorée"
# Un délai de mutation choisi par le projet passe dans config.env : upgrade le garde.
mkdir "$tmp/md"
printf 'pile=rust\nprojet=Essai\nspec=s.md\nlieu_test=ici\nmutation_delai=30\n' >"$tmp/mdv"
"$install" "$tmp/md" "$tmp/mdv" >/dev/null
[[ $(kv_get "$tmp/md/.izanagi/config.env" mutation_delai) == 30 ]] || echoue "mutation_delai des valeurs ignoré"

# Valeur de hook refusée avant toute écriture.
mkdir "$tmp/hk"
for cle in hook_push hook_verification hook_destructif; do
  printf 'pile=rust\nprojet=Essai\nspec=s.md\nlieu_test=ici\n%s=parfois\n' "$cle" >"$tmp/hkv"
  if sortie="$("$install" "$tmp/hk" "$tmp/hkv" 2>&1)"; then echoue "$cle=parfois accepté"; fi
  grep -q 'refusé' <<<"$sortie" || echoue "$cle=parfois : message : $sortie"
  [[ -z $(ls -A "$tmp/hk") ]] || echoue "$cle=parfois : écriture avant le refus"
done
printf 'pile=rust\nprojet=Essai\nspec=s.md\nlieu_test=ici\nhook_push=avertit\n' >"$tmp/hkv"
"$install" "$tmp/hk" "$tmp/hkv" >/dev/null
[[ $(kv_get "$tmp/hk/.izanagi/config.env" hook_push) == avertit ]] || echoue "hook_push=avertit non posé"

# CI : actions épinglées par SHA, jeton non gardé, gitleaks vérifié, audit des dépendances.
for f in .github/dependabot.yml .github/workflows/securite.yml; do
  [[ -f $tmp/p/$f ]] || echoue "$f non posé"
done
non_epinglees="$(grep -hE '^[[:space:]]*-?[[:space:]]*uses:' "$tmp/p/.github/workflows/"*.yml | grep -vE '@[0-9a-f]{40} # ' || true)"
[[ -z $non_epinglees ]] || echoue "actions non épinglées : $non_epinglees"
for mot in 'persist-credentials: false' 'fetch-depth: 0' 'gitleaks_8.30.1_' 'sha256' 'cargo audit' 'severity_threshold = "high"'; do
  grep -qF -- "$mot" "$tmp/p/.github/workflows/ci.yml" || echoue "ci.yml : « $mot » absent"
done
for mot in 'cron:' 'workflow_dispatch:' 'issues: write' 'gitleaks git --redact --no-banner .' 'cargo audit' 'securite'; do
  grep -qF -- "$mot" "$tmp/p/.github/workflows/securite.yml" || echoue "securite.yml : « $mot » absent"
done
# Seul le job de l'issue peut écrire, et il ne lance aucune action tierce.
[[ $(grep -c 'issues: write' "$tmp/p/.github/workflows/securite.yml") -eq 1 ]] || echoue "securite.yml : issues: write hors du seul job de l'issue"
[[ -z $(sed -n '/^  issue:/,$p' "$tmp/p/.github/workflows/securite.yml" | grep 'uses:') ]] || echoue "securite.yml : le job de l'issue lance une action"
grep -qF 'package-ecosystem: github-actions' "$tmp/p/.github/dependabot.yml" || echoue "dependabot.yml : écosystème"

# Analyse Semgrep : un job `analyse` dans ci.yml et securite.yml, la première étape sans échec,
# la seconde qui échoue sur un constat ERROR.
for wf in ci securite; do
  w="$tmp/p/.github/workflows/$wf.yml"
  grep -qxF "  analyse:" "$w" || echoue "$wf.yml : job analyse absent"
  job="$(awk '/^  analyse:$/ {d=1; print; next} d && /^  [a-z]+:$/ {d=0} d' "$w")"
  grep -qxF "    runs-on: ubuntu-latest" <<<"$job" || echoue "$wf.yml : analyse hors ubuntu-latest"
  grep -qxF "    permissions:" <<<"$job" || echoue "$wf.yml : analyse sans permissions"
  grep -qF "pipx install semgrep==1.186.0" <<<"$job" || echoue "$wf.yml : semgrep non épinglé"
  grep -qxF "        run: semgrep scan --config p/default --metrics=off" <<<"$job" || echoue "$wf.yml : première étape Semgrep"
  grep -qxF "        run: semgrep scan --config p/default --metrics=off --severity ERROR --error" <<<"$job" || echoue "$wf.yml : seconde étape Semgrep"
  [[ $(grep -c -- "--error" <<<"$job") -eq 1 ]] || echoue "$wf.yml : --error hors de la seconde étape"
  [[ $(grep -c -- "--metrics=off" <<<"$job") -eq 2 ]] || echoue "$wf.yml : --metrics=off manquant"
  grep -qF "# nosemgrep: <règle>" "$w" || echoue "$wf.yml : faux positifs non expliqués"
  grep -qF "continue-on-error: true" <<<"$job" || echoue "$wf.yml : première étape bloquante"
done
grep -qF "needs: [secrets, audit, analyse]" "$tmp/p/.github/workflows/securite.yml" || echoue "securite.yml : issue n'attend pas analyse"
grep -qF 'echecs+="analyse statique ($ANALYSE) "' "$tmp/p/.github/workflows/securite.yml" || echoue "securite.yml : issue sans analyse"

# Un projet à trois piles et une pile sans gabarit : un audit par composant.
mkdir "$tmp/au"
printf '%s\n' pile=aucune projet=Audit spec=s.md lieu_test=ici test_manuel=x fichier_version=y \
  'composant=moteur|moteur|rust|' 'composant=web|web|typescript|' 'composant=ml|ml|python|' 'composant=api|api|zig|' >"$tmp/auv"
"$install" "$tmp/au" "$tmp/auv" >/dev/null
for mot in 'cargo audit' 'npm audit --audit-level=high' 'pip-audit' 'À ÉCRIRE : audit des dépendances de api (zig)' 'working-directory: moteur' 'working-directory: web' 'working-directory: ml'; do
  grep -qF -- "$mot" "$tmp/au/.github/workflows/ci.yml" || echoue "audit à trois piles : « $mot » absent de ci.yml"
  grep -qF -- "$mot" "$tmp/au/.github/workflows/securite.yml" || echoue "audit à trois piles : « $mot » absent de securite.yml"
done
non_epinglees="$(grep -hE '^[[:space:]]*-?[[:space:]]*uses:' "$tmp/au/.github/workflows/"*.yml | grep -vE '@[0-9a-f]{40} # ' || true)"
[[ -z $non_epinglees ]] || echoue "trois piles : actions non épinglées : $non_epinglees"

# Règles par langage : un fichier par pile des composants, qui renvoie aux règles du
# plugin quand elles existent.
for l in rust typescript python zig; do
  [[ -f $tmp/au/docs/standards/$l.md ]] || echoue "docs/standards/$l.md non posé"
  grep -qx "# Règles $l" "$tmp/au/docs/standards/$l.md" || echoue "docs/standards/$l.md : titre"
  grep -qx '## À proposer au plugin' "$tmp/au/docs/standards/$l.md" || echoue "docs/standards/$l.md : section À proposer au plugin"
  grep -qF 'Écarte : R<n>, parce que <raison>' "$tmp/au/docs/standards/$l.md" || echoue "docs/standards/$l.md : forme d'une exception"
done
for l in rust typescript python; do
  grep -qF "references/langages/$l.md" "$tmp/au/docs/standards/$l.md" || echoue "docs/standards/$l.md ne renvoie pas aux règles du plugin"
done
grep -qF 'references/langages/' "$tmp/au/docs/standards/zig.md" && echoue "docs/standards/zig.md renvoie à des règles du plugin qui n'existent pas"
grep -qF 'docs/standards/' "$tmp/au/docs/CODING_STANDARDS.md" || echoue "CODING_STANDARDS.md ne renvoie pas à docs/standards/"
for f in AGENTS.md CLAUDE.md; do
  grep -qF 'docs/standards/' "$tmp/au/$f" || echoue "$f ne nomme pas docs/standards/"
done
# Deux composants de même pile : un seul fichier.
mkdir "$tmp/deux"
printf '%s\n' pile=aucune projet=Deux spec=s.md lieu_test=ici test_manuel=x fichier_version=y \
  'composant=a|a|rust|' 'composant=b|b|rust|' >"$tmp/deuxv"
sortie="$("$install" "$tmp/deux" "$tmp/deuxv")"
[[ $(grep -c 'docs/standards/' <<<"$sortie") -eq 1 ]] || echoue "deux composants rust : $sortie"
# Sans composant : aucun fichier de langage.
mkdir "$tmp/nu"
printf '%s\n' projet=Nu spec=s.md lieu_test=ici test_manuel=x fichier_version=y >"$tmp/nuv"
"$install" "$tmp/nu" "$tmp/nuv" >/dev/null
[[ ! -e $tmp/nu/docs/standards ]] || echoue "docs/standards posé sans composant"
[[ $(kv_get "$tmp/nu/.izanagi/config.env" mutation) == non ]] || echoue "config.env : mutation sans composant"
# Sans composant, le template de PR est posé et version_composant reste vide.
[[ -f $tmp/nu/.github/pull_request_template.md ]] || echoue "template de PR absent sans composant"
grep -qxF 'version_composant=' "$tmp/nu/.izanagi/config.env" || echoue "config.env : version_composant sans composant"
# langue_publique et version_composant : la valeur donnée passe dans config.env.
mkdir "$tmp/lp"
printf '%s\n' langue_publique=en 'composant=api|api|rust|' 'composant=web|web|rust|' version_composant=web projet=Lp spec=s.md lieu_test=ici test_manuel=x fichier_version=y >"$tmp/lpv"
"$install" "$tmp/lp" "$tmp/lpv" >/dev/null
[[ $(kv_get "$tmp/lp/.izanagi/config.env" langue_publique) == en ]] || echoue "config.env : langue_publique=en refusée"
[[ $(kv_get "$tmp/lp/.izanagi/config.env" version_composant) == web ]] || echoue "config.env : version_composant explicite"
mkdir "$tmp/lp2"
printf '%s\n' 'composant=api|api|rust|' 'composant=web|web|rust|' projet=Lp spec=s.md lieu_test=ici test_manuel=x fichier_version=y >"$tmp/lpv2"
"$install" "$tmp/lp2" "$tmp/lpv2" >/dev/null
[[ $(kv_get "$tmp/lp2/.izanagi/config.env" version_composant) == api ]] || echoue "config.env : version_composant par défaut avec deux composants"

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
ci_m1="$tmp/m1/.github/workflows/ci.yml"
grep -qxF '        run: bash scripts/check.sh --host --complet' "$ci_m1" || echoue "ci.yml : run --host --complet"
grep -qxF '        run: bash scripts/check.sh --host' "$ci_m1" && echoue "ci.yml : run --host seul"
grep -q 'cargo test' "$ci_m1" && echoue "ci.yml garde cargo test"
# Job couverture : Ubuntu seul, jamais bloquant, outils de couverture Rust.
job_couverture="$(sed -n '/^  couverture:/,/^  [a-z]*:$/p' "$ci_m1")"
for mot in 'runs-on: ubuntu-latest' 'continue-on-error: true' 'run: IZANAGI_COUVERTURE=1 bash scripts/check.sh --host --complet' \
  'rustup component add llvm-tools-preview' 'tool: cargo-llvm-cov@' 'taiki-e/install-action@' 'rust-toolchain' 'gitleaks_8.30.1_' 'fetch-depth: 0'; do
  grep -qF -- "$mot" <<<"$job_couverture" || echoue "job couverture : « $mot » absent"
done
sed -n '/^  check:/,/^  couverture:/p' "$ci_m1" | grep -qF 'cargo-llvm-cov' && echoue "job check : outil de couverture installé"
# Sans navigateur=oui : ni Playwright ni IZANAGI_NAVIGATEUR.
grep -qE 'playwright|IZANAGI_NAVIGATEUR' "$ci_m1" && echoue "ci.yml : Playwright sans navigateur=oui"
non_epinglees="$(grep -hE '^[[:space:]]*-?[[:space:]]*uses:' "$ci_m1" | grep -vE '@[0-9a-f]{40} # ' || true)"
[[ -z $non_epinglees ]] || echoue "m1 : actions non épinglées : $non_epinglees"
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
# Dans WSL, les dossiers Windows (/mnt/...) sortent du PATH avant la vérification.
grep -qF '[[ $d == /mnt/* ]] || linux_seul+=' "$tmp/m1/scripts/check.sh" || echoue "PATH WSL garde les dossiers Windows"
grep -qF '. "$HOME/.nvm/nvm.sh"' "$tmp/m1/scripts/check.sh" || echoue "nvm non chargé dans WSL"
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

# Système courant hors des cibles. `uname` et `wsl.exe` factices simulent
# Windows sans WSL réel : wsl.exe note ses arguments dans `appels` et sort 0.
mkdir "$tmp/fx" "$tmp/hc"
printf '#!/bin/sh\necho MINGW64_NT-10.0\n' >"$tmp/fx/uname"
printf '#!/usr/bin/env bash\ncat >/dev/null\necho "$*" >>"%s/appels"\n' "$tmp/fx" >"$tmp/fx/wsl.exe"
# Faux gitleaks : la recherche de secrets passe, ces cas testent le choix des systèmes.
printf '#!/bin/sh\nexit 0\n' >"$tmp/fx/gitleaks"
chmod +x "$tmp/fx/uname" "$tmp/fx/wsl.exe" "$tmp/fx/gitleaks"
# Un dépôt git avec un composant zig dont la section écrit `lance` quand elle
# tourne. Les cas changent ensuite la seule ligne `cibles=`.
git -C "$tmp/hc" init -q
printf '%s\n' 'composant=outil|.|zig|' systemes=linux "${base[@]}" >"$tmp/hcv"
"$install" "$tmp/hc" "$tmp/hcv" >/dev/null
sed -i "s|^.*# À ÉCRIRE.*\$|    echo x >>\"$tmp/hc/lance\"|" "$tmp/hc/scripts/check.sh"
# lancer_fx <systemes> [option] : lance check.sh sous le faux Windows.
lancer_fx() {
  sed -i "s/^cibles=.*/cibles=\"$1\"/" "$tmp/hc/scripts/check.sh"
  rm -f "$tmp/fx/appels" "$tmp/hc/lance"
  (cd "$tmp/hc" && PATH="$tmp/fx:$PATH" bash scripts/check.sh ${2:-} 2>&1)
}
for option in "" --host; do
  sortie="$(lancer_fx linux "$option")" || echoue "linux seul $option : échec : $sortie"
  [[ -e $tmp/hc/lance ]] && echoue "linux seul $option : Windows vérifié hors des cibles"
  grep -q -- '--exec' "$tmp/fx/appels" 2>/dev/null || echoue "linux seul $option : copie WSL non vérifiée"
  [[ -n $option ]] || grep -qxF 'windows : hors des cibles, sauté' <<<"$sortie" || echoue "linux seul : message de saut : $sortie"
  sortie="$(lancer_fx macos "$option")" || echoue "macos seul $option : échec : $sortie"
  grep -qxF 'windows : hors des cibles, sauté' <<<"$sortie" || echoue "macos seul $option : $sortie"
  [[ -e $tmp/hc/lance || -e $tmp/fx/appels ]] && echoue "macos seul $option : quelque chose a tourné"
done
lancer_fx windows,linux --host >/dev/null || echoue "windows,linux --host : échec"
[[ -e $tmp/hc/lance ]] || echoue "windows,linux --host : Windows non vérifié"
[[ -e $tmp/fx/appels ]] && echoue "windows,linux --host : WSL lancé"
lancer_fx windows,linux >/dev/null || echoue "windows,linux : échec"
[[ -e $tmp/hc/lance && -e $tmp/fx/appels ]] || echoue "windows,linux : Windows et WSL attendus"

# --- arguments de check.sh : --host, --complet, --clean ---
# Faux cargo et npm : ils notent leurs arguments dans `journal` et réussissent.
# `cargo metadata` affiche le contenu de `meta` : une bibliothèque, un test
# d'intégration `integ` et un test fonctionnel `fonctionnel_cli`.
mkdir "$tmp/ar" "$tmp/ar/bin" "$tmp/ar/web"
git -C "$tmp/ar" init -q
for outil in cargo npm gitleaks; do
  printf '#!/bin/sh\necho "%s $*" >>"%s/journal"\n' "$outil" "$tmp/ar" >"$tmp/ar/bin/$outil"
  chmod +x "$tmp/ar/bin/$outil"
done
printf '[ "$1" = metadata ] && cat "%s/meta"\nexit 0\n' "$tmp/ar" >>"$tmp/ar/bin/cargo"
# Le test `avec_cli` déclare sa propre feature : l'étape integration le saute.
meta_complet='{"packages":[{"name":"cli","targets":[{"kind":["lib"],"crate_types":["lib"],"name":"cli","doctest":true},{"kind":["test"],"crate_types":["bin"],"name":"avec_cli","src_path":"tests/avec_cli.rs","required-features":["cli"],"doctest":false},{"kind":["test"],"crate_types":["bin"],"name":"fonctionnel_cli","required-features":["fonctionnel"],"doctest":false},{"kind":["test"],"crate_types":["bin"],"name":"integ","doctest":false}]}]}'
printf '%s\n' "$meta_complet" >"$tmp/ar/meta"
printf '%s\n' 'composant=cli|.|rust||unitaire,integration,fonctionnelle' 'composant=web|web|typescript|' \
  'fonctionnel_projet=tests/fonctionnels|npm run test:projet' systemes=windows,linux,macos "${base[@]}" >"$tmp/arv"
"$install" "$tmp/ar" "$tmp/arv" >/dev/null
bash -n "$tmp/ar/scripts/check.sh" || echoue "check.sh à deux composants invalide"
# lancer_ar [arguments] : code de sortie dans `code_ar`, sortie dans `sortie_ar`.
lancer_ar() {
  rm -f "$tmp/ar/journal"
  set +e
  sortie_ar="$(cd "$tmp/ar" && PATH="$tmp/ar/bin:$PATH" bash scripts/check.sh "$@" 2>&1)"
  code_ar=$?
  set -e
}
for args in "--host" "--host --complet" "--complet --host"; do
  # shellcheck disable=SC2086
  lancer_ar $args
  [[ $code_ar -eq 0 ]] || echoue "check.sh $args : code $code_ar : $sortie_ar"
  attendu=$'cargo test --workspace --locked --lib --bins\ncargo test --workspace --locked --doc\ncargo test --workspace --locked --test integ\nnpm run test:unitaire'
  if [[ $args == *--complet* ]]; then
    attendu+=$'\ncargo test --workspace --locked --features fonctionnel --test fonctionnel_*\nnpm run test:projet'
  fi
  [[ $(grep -vE '^(cargo (fmt|clippy|metadata)|npm (ci|run (format:check|lint))|gitleaks)' "$tmp/ar/journal") == "$attendu" ]] ||
    echoue "check.sh $args : étapes de test : $(cat "$tmp/ar/journal")"
  if [[ $args == *--complet* ]]; then
    grep -qE ' : tout passe \(complet\)$' <<<"$sortie_ar" || echoue "check.sh $args : fin sans (complet) : $sortie_ar"
  else
    grep -qE ' : tout passe$' <<<"$sortie_ar" || echoue "check.sh $args : fin de sortie : $sortie_ar"
  fi
done
# Entrée du projet sans Playwright ni navigateur, avec un verrou à la racine : la
# racine s'installe aussi.
touch "$tmp/ar/package-lock.json"
lancer_ar --host --complet
[[ $code_ar -eq 0 ]] || echoue "entrée du projet avec verrou : code $code_ar : $sortie_ar"
[[ $(grep -A1 -xF -- '-- projet : installation' <<<"$sortie_ar" | tail -1) == '-- projet : fonctionnelle' ]] ||
  echoue "entrée du projet sans Playwright : pas d'installation : $sortie_ar"
rm "$tmp/ar/package-lock.json"
# Sans bibliothèque : ni `--lib` ni `--doc`, qui échoueraient.
cible_lib='{"kind":["lib"],"crate_types":["lib"],"name":"cli","doctest":true},'
printf '%s\n' "${meta_complet/"$cible_lib"/}" >"$tmp/ar/meta"
lancer_ar --host
[[ $code_ar -eq 0 ]] || echoue "sans bibliothèque : code $code_ar : $sortie_ar"
grep -qxF 'cargo test --workspace --locked --bins' "$tmp/ar/journal" || echoue "sans bibliothèque : --bins seul attendu : $(cat "$tmp/ar/journal")"
grep -qE -- '--lib|--doc' "$tmp/ar/journal" && echoue "sans bibliothèque : --lib ou --doc lancé"
# Bibliothèque cdylib : `--lib` lance ses tests, `--doc` ne tourne pas (pas de doctest).
cible_cdylib='{"kind":["cdylib"],"crate_types":["cdylib"],"name":"cli","doctest":false},'
printf '%s\n' "${meta_complet/"$cible_lib"/"$cible_cdylib"}" >"$tmp/ar/meta"
lancer_ar --host
[[ $code_ar -eq 0 ]] || echoue "cdylib : code $code_ar : $sortie_ar"
grep -qxF 'cargo test --workspace --locked --lib --bins' "$tmp/ar/journal" || echoue "cdylib : --lib attendu : $(cat "$tmp/ar/journal")"
grep -qF -- '--doc' "$tmp/ar/journal" && echoue "cdylib : --doc lancé"
grep -qF -- '--test avec_cli' "$tmp/ar/journal" && echoue "test à feature propre nommé par --test"
# Sans test d'intégration : l'étape échoue, une couche ne tolère pas un dossier vide.
printf '%s\n' '{"packages":[{"name":"cli","targets":[{"kind":["bin"],"crate_types":["bin"],"name":"cli"},{"kind":["test"],"crate_types":["bin"],"name":"fonctionnel_cli"}]}]}' >"$tmp/ar/meta"
lancer_ar --host
[[ $code_ar -ne 0 ]] || echoue "sans test d'intégration : l'étape réussit"
grep -qF "aucun test d'intégration" <<<"$sortie_ar" || echoue "sans test d'intégration : message : $sortie_ar"
printf '%s\n' "$meta_complet" >"$tmp/ar/meta"
for args in "--clean --complet" "--complet --clean" "--inconnu" "--host --inconnu" "--clean --host"; do
  # shellcheck disable=SC2086
  lancer_ar $args
  [[ $code_ar -eq 2 ]] || echoue "check.sh $args : code $code_ar au lieu de 2"
  [[ -e $tmp/ar/journal ]] && echoue "check.sh $args : un outil a tourné"
  [[ $sortie_ar == 'usage : scripts/check.sh [--host] [--complet] | --clean' ]] || echoue "check.sh $args : usage : $sortie_ar"
done
# Sous le faux Windows, la copie WSL reçoit `--complet` quand il est demandé.
sortie="$(lancer_fx linux "--host --complet")" || echoue "wsl --complet : échec : $sortie"
grep -qE -- 'essai-wsl --complet$' "$tmp/fx/appels" || echoue "wsl --complet : option non transmise : $(cat "$tmp/fx/appels")"
sortie="$(lancer_fx linux --host)" || echoue "wsl sans --complet : échec : $sortie"
grep -qE -- 'essai-wsl --complet$' "$tmp/fx/appels" && echoue "wsl sans --complet : option transmise"

# --- couverture : IZANAGI_COUVERTURE=1 ---
# Faux npx : il note ses arguments comme cargo et npm.
printf '#!/bin/sh\necho "npx $*" >>"%s/journal"\n' "$tmp/ar" >"$tmp/ar/bin/npx"
chmod +x "$tmp/ar/bin/npx"
# Sans la variable, aucune mesure, et le résumé n'est pas écrit.
export GITHUB_STEP_SUMMARY="$tmp/ar/resume.md"
lancer_ar --host --complet
[[ $code_ar -eq 0 ]] || echoue "sans couverture : code $code_ar : $sortie_ar"
grep -qE 'llvm-cov|--coverage|merge-reports' "$tmp/ar/journal" && echoue "sans couverture : une mesure a tourné : $(cat "$tmp/ar/journal")"
[[ -e $tmp/ar/resume.md ]] && echoue "sans couverture : résumé écrit"
# Avec la variable : les commandes de mesure, puis un résumé par composant.
export IZANAGI_COUVERTURE=1
lancer_ar --host --complet
unset IZANAGI_COUVERTURE
[[ $code_ar -eq 0 ]] || echoue "couverture : code $code_ar : $sortie_ar"
attendu='cargo llvm-cov clean --workspace
cargo llvm-cov --no-report --workspace --locked --lib --bins
cargo test --workspace --locked --doc
cargo llvm-cov --no-report --workspace --locked --test integ
npm run test:unitaire -- --coverage --coverage.reportsDirectory=node_modules/.izanagi-couverture/unitaire --reporter=default --reporter=blob --outputFile.blob=node_modules/.izanagi-couverture/blob/unitaire.json
cargo llvm-cov --no-report --workspace --locked --features fonctionnel --test fonctionnel_*
npm run test:projet
cargo llvm-cov report
npx vitest run --merge-reports=node_modules/.izanagi-couverture/blob --coverage --coverage.reporter=text-summary --coverage.reportsDirectory=node_modules/.izanagi-couverture/rapport'
[[ $(grep -vE '^(cargo (fmt|clippy|metadata)|npm (ci|run (format:check|lint))|gitleaks)' "$tmp/ar/journal") == "$attendu" ]] ||
  echoue "couverture : commandes : $(cat "$tmp/ar/journal")"
[[ -f $tmp/ar/resume.md ]] || echoue "couverture : résumé non écrit dans GITHUB_STEP_SUMMARY"
for mot in '## Couverture des tests' '### cli (rust)' '### web (typescript)'; do
  grep -qxF -- "$mot" "$tmp/ar/resume.md" || echoue "couverture : résumé sans « $mot » : $(cat "$tmp/ar/resume.md")"
done
grep -qxF '### projet' "$tmp/ar/resume.md" && echoue "couverture : l'entrée du projet a un résumé"
unset GITHUB_STEP_SUMMARY
# Hors des cibles : le résumé le dit au lieu de rester vide.
sed -i 's/^cibles=.*/cibles="macos"/' "$tmp/ar/scripts/check.sh"
GITHUB_STEP_SUMMARY="$tmp/ar/resume2.md" IZANAGI_COUVERTURE=1 lancer_ar --host --complet
[[ $code_ar -eq 0 ]] || echoue "couverture hors cibles : code $code_ar : $sortie_ar"
grep -qF 'hors des cibles, rien de mesuré' "$tmp/ar/resume2.md" || echoue "couverture hors cibles : résumé : $(cat "$tmp/ar/resume2.md" 2>/dev/null)"
sed -i 's/^cibles=.*/cibles="windows,linux,macos"/' "$tmp/ar/scripts/check.sh"

# --- navigateur=oui : Playwright sur Ubuntu seulement ---
mkdir "$tmp/nv" "$tmp/nv/bin"
git -C "$tmp/nv" init -q
for outil in npm npx gitleaks; do
  printf '#!/bin/sh\necho "%s $*" >>"%s/journal"\n' "$outil" "$tmp/nv" >"$tmp/nv/bin/$outil"
  chmod +x "$tmp/nv/bin/$outil"
done
printf '%s\n' 'composant=web|web|typescript||unitaire,fonctionnelle' 'composant=api|api|typescript||unitaire' \
  'fonctionnel_projet=tests/fonctionnels|npx playwright test' navigateur=oui systemes=linux,windows "${base[@]}" >"$tmp/nvv"
"$install" "$tmp/nv" "$tmp/nvv" >/dev/null || echoue "navigateur=oui : install.sh échoue"
[[ $(kv_get "$tmp/nv/.izanagi/config.env" navigateur) == oui ]] || echoue "config.env : navigateur=oui non rendu"
mkdir "$tmp/nv/web" "$tmp/nv/api"
ci_nv="$tmp/nv/.github/workflows/ci.yml"
job_check="$(sed -n '/^  check:/,/^  couverture:/p' "$ci_nv")"
job_couverture="$(sed -n '/^  couverture:/,/^  audit:/p' "$ci_nv")"
for mot in 'npx playwright install --with-deps chromium' "if: matrix.os == 'ubuntu-latest'" 'working-directory: web' 'working-directory: .' \
  "IZANAGI_NAVIGATEUR: \${{ matrix.os == 'ubuntu-latest' && 'oui' || 'non' }}" 'run: bash scripts/check.sh --host --complet'; do
  grep -qF -- "$mot" <<<"$job_check" || echoue "navigateur=oui : job check sans « $mot »"
done
grep -qF 'working-directory: api' <<<"$job_check" && echoue "navigateur=oui : Playwright pour un composant sans couche fonctionnelle"
[[ $(grep -c '^ *npx playwright install' <<<"$job_check") -eq 2 ]] || echoue "navigateur=oui : deux installations attendues dans le job check"
grep -qF 'npx playwright install --with-deps chromium' <<<"$job_couverture" || echoue "navigateur=oui : job couverture sans navigateurs"
grep -qF 'matrix.os' <<<"$job_couverture" && echoue "navigateur=oui : job couverture conditionné à la matrice"
bash -n "$tmp/nv/scripts/check.sh" || echoue "navigateur=oui : check.sh invalide"
lancer_nv() {
  rm -f "$tmp/nv/journal"
  set +e
  sortie_nv="$(cd "$tmp/nv" && PATH="$tmp/nv/bin:$PATH" bash scripts/check.sh --host --complet 2>&1)"
  code_nv=$?
  set -e
}
# Sans IZANAGI_NAVIGATEUR : les étapes Playwright tournent.
sed -i 's/^cibles=.*/cibles="windows,linux,macos"/' "$tmp/nv/scripts/check.sh"
lancer_nv
[[ $code_nv -eq 0 ]] || echoue "navigateur : code $code_nv : $sortie_nv"
grep -qxF 'npm run test:fonctionnel' "$tmp/nv/journal" || echoue "navigateur : étape web non lancée : $(cat "$tmp/nv/journal")"
grep -qxF 'npx playwright test' "$tmp/nv/journal" || echoue "navigateur : entrée du projet non lancée"
grep -qxF -- '-- projet : installation' <<<"$sortie_nv" && echoue "entrée du projet : installation sans package-lock.json : $sortie_nv"
# Avec un verrou à la racine, l'entrée du projet installe ses dépendances avant la commande.
touch "$tmp/nv/package-lock.json"
lancer_nv
[[ $code_nv -eq 0 ]] || echoue "entrée du projet avec verrou : code $code_nv : $sortie_nv"
[[ $(grep -A1 -xF -- '-- projet : installation' <<<"$sortie_nv" | tail -1) == '-- projet : fonctionnelle' ]] ||
  echoue "entrée du projet : pas d'installation avant la commande : $sortie_nv"
[[ $(grep -cxF 'npm ci' "$tmp/nv/journal") -eq 3 ]] || echoue "entrée du projet : npm ci de la racine absent : $(cat "$tmp/nv/journal")"
# IZANAGI_NAVIGATEUR=non : les deux étapes sont sautées et rendent 0.
export IZANAGI_NAVIGATEUR=non
lancer_nv
unset IZANAGI_NAVIGATEUR
[[ $code_nv -eq 0 ]] || echoue "navigateur=non : code $code_nv : $sortie_nv"
grep -qxF -- '-- web : fonctionnelle : navigateur absent de ce système, sauté' <<<"$sortie_nv" || echoue "navigateur=non : saut web : $sortie_nv"
grep -qxF -- '-- projet : fonctionnelle : navigateur absent de ce système, sauté' <<<"$sortie_nv" || echoue "navigateur=non : saut projet : $sortie_nv"
grep -qxF -- '-- projet : installation' <<<"$sortie_nv" && echoue "navigateur=non : la racine s'installe alors que l'étape est sautée : $sortie_nv"
grep -qE 'test:fonctionnel|playwright test' "$tmp/nv/journal" && echoue "navigateur=non : une étape Playwright a tourné"
grep -qxF 'npm run test:unitaire' "$tmp/nv/journal" || echoue "navigateur=non : l'étape unitaire doit tourner"
# Valeur fausse : refus avant écriture.
mkdir "$tmp/nvx"
printf '%s\n' 'composant=web|web|typescript|' navigateur=peut-etre "${base[@]}" >"$tmp/nvxv"
set +e; "$install" "$tmp/nvx" "$tmp/nvxv" >/dev/null 2>"$tmp/err"; code=$?; set -e
[[ $code -eq 2 ]] || echoue "navigateur=peut-etre : code $code au lieu de 2"
grep -qF 'navigateur « peut-etre » refusé : oui ou non' "$tmp/err" || echoue "navigateur faux : message : $(cat "$tmp/err")"
[[ -z $(ls -A "$tmp/nvx") ]] || echoue "navigateur faux : écriture avant le refus"

# --- piles TypeScript et Python, dev.sh ---
mkdir "$tmp/t1"
printf '%s
' 'composant=api|api|typescript|npm run dev' 'composant=web|web|typescript|npm run dev' projet=essai spec=s.md lieu_test=ici >"$tmp/t1v"
sortie="$("$install" "$tmp/t1" "$tmp/t1v")"
[[ $(sed -n '/^  check:/,/^  couverture:/p' "$tmp/t1/.github/workflows/ci.yml" | grep -c 'actions/setup-node') -eq 1 ]] || echoue "setup-node : un seul attendu dans le job check"
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
[[ $(kv_get "$tmp/t5/.izanagi/config.env" mutation) == oui ]] || echoue "config.env : mutation pour rust et typescript"
grep -qF '`package-lock.json`' "$tmp/t5/docs/CODING_STANDARDS.md" || echoue "hors_revue : package-lock.json"
[[ $(grep -o 'docs/plans/' "$tmp/t5/docs/CODING_STANDARDS.md" | wc -l) -eq $(grep -o 'docs/plans/' "$tmp/t1/docs/CODING_STANDARDS.md" | wc -l) ]] || echoue "hors_revue : doublon"
[[ $(kv_get "$tmp/t1/.izanagi/config.env" test_manuel) == scripts/dev.sh ]] || echoue "config.env : test manuel dev.sh"
grep -qF '`package-lock.json`' "$tmp/t1/docs/CODING_STANDARDS.md" || echoue "CODING_STANDARDS.md : package-lock.json"

# Le fichier de valeurs l'emporte sur le test manuel par défaut de dev.sh.
mkdir "$tmp/t2"
printf '%s
' 'composant=api|api|typescript|npm run dev' 'composant=web|web|typescript|' projet=essai spec=s.md lieu_test=ici 'test_manuel=npm start' >"$tmp/t2v"
"$install" "$tmp/t2" "$tmp/t2v" >/dev/null
[[ $(kv_get "$tmp/t2/.izanagi/config.env" test_manuel) == 'npm start' ]] || echoue "test_manuel du fichier de valeurs ignoré"
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
grep -qxF '    # À ÉCRIRE : outil (zig), format, lint' "$tmp/m3/scripts/check.sh" || echoue "section à écrire"
grep -qxF '    # À ÉCRIRE : outil (zig), couche unitaire' "$tmp/m3/scripts/check.sh" || echoue "couche unitaire à écrire"
[[ $(kv_get "$tmp/m3/.izanagi/config.env" mutation) == non ]] || echoue "config.env : mutation pour une pile sans gabarit"
mkdir "$tmp/mx"
printf '%s\n' 'composant=cli|cli|rust|' 'composant=outil|outil|zig|' "${base[@]}" >"$tmp/mxv"
"$install" "$tmp/mx" "$tmp/mxv" >/dev/null
[[ $(kv_get "$tmp/mx/.izanagi/config.env" mutation) == non ]] || echoue "config.env : mutation avec une pile sans gabarit parmi d'autres"
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
grep -qxF -- '- composant : a | a | typescript |' "$tmp/t4/docs/agents/harness.md" || echoue "harness.md : espace final sans lancement"

# --- couches de test ---
# Sans cinquième champ, un composant n'a que la couche unitaire.
grep -qF 'Couches de test** :' "$tmp/m1/docs/agents/harness.md" && echoue "harness.md garde la ligne Couches de test"
grep -qxF -- '- couche : cli | unitaire | src | cargo test --workspace --locked --lib --bins, puis --doc' "$tmp/m1/docs/agents/harness.md" ||
  echoue "harness.md : couche unitaire par défaut"
grep -q -- '- couche : cli | integration' "$tmp/m1/docs/agents/harness.md" && echoue "harness.md : couche integration non déclarée"
grep -qF 'echo "-- cli : unitaire"' "$tmp/m1/scripts/check.sh" || echoue "check.sh : étape unitaire par défaut"
grep -qE -- '-- [a-z]+ : tests"' "$tmp/m1/scripts/check.sh" && echoue "check.sh garde l'étape tests"
grep -qE -- '-- cli : (integration|fonctionnelle)' "$tmp/m1/scripts/check.sh" && echoue "check.sh : couche non déclarée rendue"
grep -qF 'verifier_cli_fonctionnelle' "$tmp/m1/scripts/check.sh" && echoue "check.sh : fonction fonctionnelle sans la couche"
[[ $(sed -n '/^verifier_tout_complet() {/,/^}/p' "$tmp/m1/scripts/check.sh") == $'verifier_tout_complet() {\n  :\n}' ]] ||
  echoue "check.sh : verifier_tout_complet non vide sans couche fonctionnelle"
grep -q '^couches=' "$racine/templates/core/defaults.env" && echoue "defaults.env garde la clé couches"

# Un composant de chaque pile avec les trois couches, un composant unitaire
# seul, et l'entrée fonctionnelle du projet.
mkdir "$tmp/co"
trois=unitaire,integration,fonctionnelle
printf '%s\n' "composant=cli|cli|rust||$trois" "composant=web|web|typescript|npm run dev|$trois" \
  "composant=ml|ml|python||$trois" "composant=outil|outil|zig||$trois" 'composant=noyau|noyau|rust||unitaire' \
  'fonctionnel_projet=tests/fonctionnels|npx playwright test' "${base[@]}" >"$tmp/cov"
"$install" "$tmp/co" "$tmp/cov" >/dev/null || echoue "trois couches : install.sh échoue"
check_co="$tmp/co/scripts/check.sh"
bash -n "$check_co" || echoue "trois couches : check.sh invalide"
# fonction <nom> : le corps rendu d'une fonction de check.sh.
fonction() { sed -n "/^$1() {/,/^}/p" "$check_co"; }
for ligne in \
  'verifier_cli|echo "-- cli : unitaire"' \
  'verifier_cli|cibles_unitaires=(--lib --bins)' \
  'verifier_cli|cargo test --workspace --locked "${cibles_unitaires[@]}"' \
  'verifier_cli|cargo test --workspace --locked --doc' \
  'verifier_cli|echo "-- cli : integration"' \
  'verifier_cli|cargo test --workspace --locked "${tests_integration[@]}"' \
  'verifier_cli_fonctionnelle|cd "cli"' \
  'verifier_cli_fonctionnelle|echo "-- cli : fonctionnelle"' \
  "verifier_cli_fonctionnelle|cargo test --workspace --locked --features fonctionnel --test 'fonctionnel_*'" \
  'verifier_web|npm run test:unitaire' \
  'verifier_web|npm run test:integration' \
  'verifier_web_fonctionnelle|cd "web"' \
  'verifier_web_fonctionnelle|npm run test:fonctionnel' \
  'verifier_ml|uv run pytest tests/unitaires' \
  'verifier_ml|uv run pytest tests/integration' \
  'verifier_ml_fonctionnelle|uv run pytest tests/fonctionnels' \
  'verifier_outil|# À ÉCRIRE : outil (zig), couche unitaire' \
  'verifier_outil|# À ÉCRIRE : outil (zig), couche integration' \
  'verifier_outil_fonctionnelle|# À ÉCRIRE : outil (zig), couche fonctionnelle' \
  'verifier_noyau|echo "-- noyau : unitaire"' \
  'verifier_projet_fonctionnelle|echo "-- projet : fonctionnelle"' \
  'verifier_projet_fonctionnelle|npx playwright test'; do
  fonction "${ligne%%|*}" | grep -qF -- "${ligne#*|}" || echoue "trois couches : ${ligne%%|*} sans « ${ligne#*|} »"
done
fonction verifier_cli | grep -qF -- '--features fonctionnel' && echoue "trois couches : verifier_cli lance la couche fonctionnelle"
fonction verifier_noyau | grep -qF 'integration' && echoue "unitaire seul : étape integration rendue"
grep -qF 'verifier_noyau_fonctionnelle' "$check_co" && echoue "unitaire seul : fonction fonctionnelle rendue"
[[ $(fonction verifier_tout_complet) == $'verifier_tout_complet() {\n  verifier_cli_fonctionnelle\n  verifier_web_fonctionnelle\n  verifier_ml_fonctionnelle\n  verifier_outil_fonctionnelle\n  verifier_projet_fonctionnelle\n}' ]] ||
  echoue "trois couches : verifier_tout_complet : $(fonction verifier_tout_complet)"
[[ $(grep -c '# --- composant ' "$check_co") -eq 5 ]] || echoue "trois couches : un marqueur de composant par composant"
# Couverture des piles Python et sans gabarit, et pas de garde de navigateur sans navigateur=oui.
for ligne in \
  'verifier_ml|uv run --with pytest-cov==7.1.0 pytest tests/unitaires --cov --cov-append --cov-report=' \
  'verifier_ml|uv run --with pytest-cov==7.1.0 pytest tests/integration --cov --cov-append --cov-report=' \
  'verifier_ml_fonctionnelle|uv run --with pytest-cov==7.1.0 pytest tests/fonctionnels --cov --cov-append --cov-report=' \
  'verifier_web_fonctionnelle|npm run test:fonctionnel' \
  'preparer_couverture|(cd "cli" && cargo llvm-cov clean --workspace)' \
  'preparer_couverture|rm -rf "web/node_modules/.izanagi-couverture"' \
  'preparer_couverture|rm -f "ml/.coverage"' \
  'resumer_couverture|couverture_composant cli rust "cli" cargo llvm-cov report' \
  'resumer_couverture|couverture_composant ml python "ml" uv run --with pytest-cov==7.1.0 coverage report' \
  'resumer_couverture|couverture_composant outil zig "outil" echo "pas de mesure de couverture pour zig"'; do
  fonction "${ligne%%|*}" | grep -qF -- "${ligne#*|}" || echoue "couverture : ${ligne%%|*} sans « ${ligne#*|} »"
done
fonction verifier_web_fonctionnelle | grep -qF -- '--coverage' && echoue "couverture : l'étape fonctionnelle TypeScript mesure (Playwright possible)"
grep -qF '${IZANAGI_NAVIGATEUR' "$check_co" && echoue "sans navigateur=oui : garde de navigateur rendue"
grep -qE -- '-- [a-z]+ : tests"' "$check_co" && echoue "trois couches : étape tests restante"
harness_co="$tmp/co/docs/agents/harness.md"
grep -qxF '## Couches de test' "$harness_co" || echoue "harness.md : section Couches de test"
grep -qxF '| Composant | Couche | Dossier | Commande |' "$harness_co" || echoue "harness.md : tableau des couches"
grep -qxF '| noyau | intégration | sans objet | sans objet |' "$harness_co" || echoue "harness.md : couche sans objet"
for ligne in \
  '- couche : cli | unitaire | cli/src | cargo test --workspace --locked --lib --bins, puis --doc' \
  "- couche : cli | integration | cli/tests | cargo test --workspace --locked --test <nom>, pour chaque test hors fonctionnel_*" \
  "- couche : cli | fonctionnelle | cli/tests/fonctionnel_*.rs | cargo test --workspace --locked --features fonctionnel --test 'fonctionnel_*'" \
  '- couche : web | unitaire | web/src | npm run test:unitaire' \
  '- couche : web | integration | web/tests/integration | npm run test:integration' \
  '- couche : web | fonctionnelle | web/tests/fonctionnels | npm run test:fonctionnel' \
  '- couche : ml | unitaire | ml/tests/unitaires | uv run pytest tests/unitaires' \
  '- couche : ml | integration | ml/tests/integration | uv run pytest tests/integration' \
  '- couche : ml | fonctionnelle | ml/tests/fonctionnels | uv run pytest tests/fonctionnels' \
  '- couche : outil | unitaire | à préciser | à préciser' \
  '- couche : noyau | unitaire | noyau/src | cargo test --workspace --locked --lib --bins, puis --doc' \
  '- couche : projet | fonctionnelle | tests/fonctionnels | npx playwright test'; do
  grep -qxF -- "$ligne" "$harness_co" || echoue "harness.md : ligne « $ligne » absente"
done
[[ $(grep -c '^- couche : ' "$harness_co") -eq 14 ]] || echoue "harness.md : 14 lignes de couche attendues"
grep -q '^- couche : noyau | integration' "$harness_co" && echoue "harness.md : couche non déclarée listée"
# Le contrat garde ses lignes de composant.
grep -qxF -- '- composant : web | web | typescript | npm run dev' "$harness_co" || echoue "harness.md : ligne composant avec couches"

# Couche inconnue : refus avant toute écriture, code 1.
mkdir "$tmp/ci"
printf '%s\n' 'composant=cli|.|rust||unitaire,e2e' "${base[@]}" >"$tmp/civ"
set +e; "$install" "$tmp/ci" "$tmp/civ" >/dev/null 2>"$tmp/err"; code=$?; set -e
[[ $code -eq 1 ]] || echoue "couche inconnue : code $code au lieu de 1"
grep -qxF 'install.sh : couche « e2e » du composant cli refusée' "$tmp/err" || echoue "couche inconnue : message : $(cat "$tmp/err")"
[[ -z $(ls -A "$tmp/ci") ]] || echoue "couche inconnue : écriture malgré le refus"

# Pile réservée, même avec une ligne `composant=` : refus avant toute écriture.
for p in core code vault multi ../rust; do
  rm -rf "$tmp/pr" && mkdir "$tmp/pr"
  printf '%s\n' "pile=$p" 'composant=app|.|rust|' "${base[@]}" >"$tmp/prv"
  set +e; "$install" "$tmp/pr" "$tmp/prv" >/dev/null 2>"$tmp/err"; code=$?; set -e
  [[ $code -eq 2 ]] || echoue "pile $p : code $code au lieu de 2"
  grep -qxF "install.sh : pile « $p » refusée" "$tmp/err" || echoue "pile $p : message : $(cat "$tmp/err")"
  [[ -z $(ls -A "$tmp/pr") ]] || echoue "pile $p : écriture malgré le refus"
done

# Une valeur vide garde sa ligne `clé=` : la ligne suivante ne s'y colle pas.
mkdir "$tmp/cle-vide"
printf 'pile=rust\nprojet=Essai\nspec=s.md\nlieu_test=ici\n' >"$tmp/cle-vide-v"
"$install" "$tmp/cle-vide" "$tmp/cle-vide-v" >/dev/null
grep -qxF 'chemins_sensibles=' "$tmp/cle-vide/.izanagi/config.env" || echoue "valeur vide : la ligne chemins_sensibles= manque ou porte une valeur"
[[ $(grep -A1 '^chemins_sensibles=' "$tmp/cle-vide/.izanagi/config.env" | tail -1) == fichier_version=* ]] || echoue "valeur vide : la ligne suivante est collée ou perdue"
printf 'chemins_sensibles=db/*, src/auth/*\n' >>"$tmp/cle-vide-v"
mkdir "$tmp/cle-pleine"
"$install" "$tmp/cle-pleine" "$tmp/cle-vide-v" >/dev/null
grep -qxF 'chemins_sensibles=db/*, src/auth/*' "$tmp/cle-pleine/.izanagi/config.env" || echoue "chemins_sensibles donné n'est pas rendu"

# Ancienne commande `à préciser` (la migration 0.7.0 l'écrit quand check.sh n'avait
# pas d'étape `tests`) : ignorée, check.sh ne la lance pas comme une commande.
mkdir "$tmp/ap"
printf '%s\n' 'composant=app|.|python||unitaire|à préciser' "${base[@]}" >"$tmp/apv"
"$install" "$tmp/ap" "$tmp/apv" >/dev/null
grep -qF 'à préciser' "$tmp/ap/scripts/check.sh" && echoue "ancienne « à préciser » rendue dans check.sh : $(grep -nF 'à préciser' "$tmp/ap/scripts/check.sh")"
grep -qF 'uv run pytest tests/unitaires' "$tmp/ap/scripts/check.sh" || echoue "ancienne « à préciser » : commande du gabarit absente"

# --- notes-de-version.sh : la section d'une version dans CHANGELOG.md ---
mkdir "$tmp/nd"
"$install" "$tmp/nd" "$tmp/v" >/dev/null
[[ -x $tmp/nd/scripts/notes-de-version.sh ]] || echoue "notes-de-version.sh absent ou non exécutable"
bash -n "$tmp/nd/scripts/notes-de-version.sh" || echoue "notes-de-version.sh invalide"
grep -qF '{{' "$tmp/nd/scripts/notes-de-version.sh" && echoue "notes-de-version.sh garde un {{"
cat >"$tmp/nd/CHANGELOG.md" <<'FIN'
# Journal des modifications

## [Non publié]

### Ajouté

- Une chose à venir.

## [0.2.0] - 2026-11-20

### Ajouté

- Le deuxième ajout.

### Corrigé

- Une correction.

## [0.1.0] - 2026-11-01

### Ajouté

- Le premier ajout.
FIN
lancer_nd() {
  set +e
  sortie_nd="$(cd "$tmp/nd" && bash scripts/notes-de-version.sh "$@" 2>"$tmp/nd-err")"
  code_nd=$?
  set -e
}
lancer_nd 0.2.0
[[ $code_nd -eq 0 ]] || echoue "notes-de-version 0.2.0 : code $code_nd"
attendu_nd=$'### Ajouté\n\n- Le deuxième ajout.\n\n### Corrigé\n\n- Une correction.'
[[ $sortie_nd == "$attendu_nd" ]] || echoue "notes-de-version 0.2.0 : sortie : $sortie_nd"
lancer_nd 0.1.0
[[ $code_nd -eq 0 ]] || echoue "notes-de-version 0.1.0 : code $code_nd"
[[ $sortie_nd == $'### Ajouté\n\n- Le premier ajout.' ]] || echoue "notes-de-version 0.1.0 : sortie : $sortie_nd"
for arg_nd in "Non publié" 1.2 v0.2.0 0.2.0.1 ""; do
  lancer_nd "$arg_nd"
  [[ $code_nd -eq 2 ]] || echoue "notes-de-version « $arg_nd » : code $code_nd au lieu de 2"
  [[ $(cat "$tmp/nd-err") == 'usage : scripts/notes-de-version.sh <X.Y.Z>' ]] || echoue "notes-de-version « $arg_nd » : usage : $(cat "$tmp/nd-err")"
done
lancer_nd
[[ $code_nd -eq 2 ]] || echoue "notes-de-version sans argument : code $code_nd au lieu de 2"
lancer_nd 0.3.0
[[ $code_nd -eq 1 ]] || echoue "notes-de-version 0.3.0 : code $code_nd au lieu de 1"
[[ $(cat "$tmp/nd-err") == "notes-de-version.sh : CHANGELOG.md n'a pas de section [0.3.0]" ]] || echoue "notes-de-version 0.3.0 : message : $(cat "$tmp/nd-err")"
# Une section vide compte comme absente.
printf '## [0.4.0] - 2026-12-01\n\n## [0.3.0] - 2026-11-25\n\n- x\n' >"$tmp/nd/CHANGELOG.md"
lancer_nd 0.4.0
[[ $code_nd -eq 1 ]] || echoue "notes-de-version section vide : code $code_nd au lieu de 1"
# Fichier en CRLF : la sortie ne garde aucun retour chariot.
printf '## [0.2.0] - 2026-11-20\r\n\r\n- Un ajout.\r\n\r\n## [0.1.0] - 2026-11-01\r\n\r\n- Un autre.\r\n' >"$tmp/nd/CHANGELOG.md"
lancer_nd 0.2.0
[[ $code_nd -eq 0 && $sortie_nd == '- Un ajout.' ]] || echoue "notes-de-version CRLF : code $code_nd, sortie : $sortie_nd"
rm "$tmp/nd/CHANGELOG.md"
lancer_nd 0.2.0
[[ $code_nd -eq 1 ]] || echoue "notes-de-version sans CHANGELOG.md : code $code_nd au lieu de 1"
[[ $(cat "$tmp/nd-err") == 'notes-de-version.sh : CHANGELOG.md absent' ]] || echoue "notes-de-version sans CHANGELOG.md : message : $(cat "$tmp/nd-err")"

# --- release.yml : le livrable du type d'application ---
# controle_release <fichier> : `permissions: {}` en tête, une ligne `permissions:` par
# job, chaque action épinglée par SHA, aucun `${{` dans un `run:` (en ligne ou en bloc).
controle_release() {
  local f="$1" ecarts
  [[ -f $f ]] || echoue "$f absent"
  grep -qx 'permissions: {}' "$f" || echoue "$f : pas de « permissions: {} » en tête"
  ecarts="$(awk '
    /^jobs:$/ { dans = 1; next }
    dans && /^  [a-z][a-z0-9_-]*:$/ { if (job != "" && !perm) print "job " job " sans permissions"; job = $1; perm = 0 }
    dans && /^    permissions:/ { perm = 1 }
    END { if (job != "" && !perm) print "job " job " sans permissions" }' "$f")"
  [[ -z $ecarts ]] || echoue "$f : $ecarts"
  ecarts="$(grep -hE '^[[:space:]]*-?[[:space:]]*uses:' "$f" | grep -vE '@[0-9a-f]{40} # ' || true)"
  [[ -z $ecarts ]] || echoue "$f : actions non épinglées : $ecarts"
  ecarts="$(awk '
    bloc && match($0, /^ */) && RLENGTH <= retrait && $0 !~ /^ *$/ { bloc = 0 }
    bloc && /\$\{\{/ { print }
    /^ *(- )?run: *\|/ { bloc = 1; match($0, /^ */); retrait = RLENGTH; next }
    /^ *(- )?run: / && /\$\{\{/ { print }' "$f")"
  [[ -z $ecarts ]] || echoue "$f : expression dans un run: : $ecarts"
}
# job_release <fichier> <job> : les lignes du job, jusqu'au job suivant.
job_release() { sed -n "/^  $2:\$/,/^  [a-z][a-z0-9_-]*:\$/p" "$1"; }
# jobs_release <fichier> : les noms des jobs, un par ligne.
jobs_release() { sed -n '/^jobs:$/,$p' "$1" | sed -n 's/^  \([a-z][a-z0-9_-]*\):$/\1/p'; }

# Projet posé au début, sans type : verifier et release seulement.
controle_release "$tmp/p/.github/workflows/release.yml"
[[ $(jobs_release "$tmp/p/.github/workflows/release.yml") == $'verifier\nrelease' ]] ||
  echoue "release.yml sans type : jobs : $(jobs_release "$tmp/p/.github/workflows/release.yml")"
grep -qE '\{\{[a-z_]+\}\}' "$tmp/p/.github/workflows/release.yml" && echoue "release.yml garde un {{clé}}"

# cli Rust sur linux et windows : une archive par système, rien sur un registre.
mkdir "$tmp/rl1"
printf '%s\n' 'composant=cli|.|rust|' type=cli systemes=linux,windows "${base[@]}" >"$tmp/rl1v"
"$install" "$tmp/rl1" "$tmp/rl1v" >/dev/null
rl="$tmp/rl1/.github/workflows/release.yml"
controle_release "$rl"
[[ $(jobs_release "$rl") == $'verifier\nbinaires-cli\nrelease' ]] || echoue "cli rust : jobs : $(jobs_release "$rl")"
grep -qxF '    tags: ["v*"]' "$rl" || echoue "cli rust : release.yml ne part pas au push d'un tag v*"
for mot in 'cargo pkgid' 'TAG: ${{ github.ref_name }}' 'bash scripts/notes-de-version.sh "$VERSION" >notes.md' \
  "::error::release.yml : le tag \$TAG ne vaut pas la version \$VERSION du fichier de version"; do
  job_release "$rl" verifier | grep -qF -- "$mot" || echoue "cli rust : verifier sans « $mot »"
done
job_binaires="$(job_release "$rl" binaires-cli)"
for mot in 'cargo build --release --locked' '- { systeme: linux, os: ubuntu-latest }' '- { systeme: windows, os: windows-latest }' \
  'needs: verifier' 'contents: read' 'cli-$TAG-$SYSTEME.tar.gz' 'target/release'; do
  grep -qF -- "$mot" <<<"$job_binaires" || echoue "cli rust : binaires sans « $mot »"
done
[[ $(grep -c '{ systeme: ' <<<"$job_binaires") -eq 2 ]] || echoue "cli rust : deux systèmes attendus"
grep -qF 'id-token' "$rl" && echoue "cli rust : id-token sans publication"
job_rel="$(job_release "$rl" release)"
for mot in 'contents: write' 'needs: [verifier, binaires-cli]' 'gh release create "$TAG" --verify-tag --notes-file livraison/notes.md' 'GH_TOKEN: ${{ github.token }}'; do
  grep -qF -- "$mot" <<<"$job_rel" || echoue "cli rust : release sans « $mot »"
done

# library Python : publication sur PyPI, sans archive.
mkdir "$tmp/rl2"
printf '%s\n' 'composant=lib|.|python|' type=library "${base[@]}" >"$tmp/rl2v"
"$install" "$tmp/rl2" "$tmp/rl2v" >/dev/null
rl="$tmp/rl2/.github/workflows/release.yml"
controle_release "$rl"
[[ $(jobs_release "$rl") == $'verifier\npublier-lib\nrelease' ]] || echoue "library python : jobs : $(jobs_release "$rl")"
job_pub="$(job_release "$rl" publier-lib)"
for mot in 'id-token: write' 'contents: read' 'needs: verifier' 'uv build' 'uv publish' 'astral-sh/setup-uv@'; do
  grep -qF -- "$mot" <<<"$job_pub" || echoue "library python : publier sans « $mot »"
done
job_release "$rl" verifier | grep -qF 'uv version --short' || echoue "library python : version par uv"
[[ $(grep -cxF '      id-token: write' "$rl") -eq 1 ]] || echoue "library python : id-token hors du job publier"

# library à trois piles : un job de publication par composant, sur son registre.
mkdir "$tmp/rl3"
printf '%s\n' 'composant=noyau|noyau|rust|' 'composant=web|web|typescript|' 'composant=py|py|python|' type=library \
  version_composant=web "${base[@]}" >"$tmp/rl3v"
"$install" "$tmp/rl3" "$tmp/rl3v" >/dev/null
rl="$tmp/rl3/.github/workflows/release.yml"
controle_release "$rl"
[[ $(jobs_release "$rl") == $'verifier\npublier-noyau\npublier-web\npublier-py\nrelease' ]] || echoue "library trois piles : jobs : $(jobs_release "$rl")"
for ligne in \
  'publier-noyau|rust-lang/crates-io-auth-action@' 'publier-noyau|CARGO_REGISTRY_TOKEN: ${{ steps.auth.outputs.token }}' \
  'publier-noyau|cargo publish --locked' 'publier-noyau|working-directory: noyau' \
  'publier-web|actions/setup-node@' 'publier-web|registry-url: https://registry.npmjs.org' 'publier-web|npm install -g npm@11.21.3' \
  'publier-web|npm ci' 'publier-web|npm publish' 'publier-web|working-directory: web' \
  'publier-py|uv publish' 'publier-py|working-directory: py' \
  'verifier|node -p "require('"'"'./package.json'"'"').version"' 'verifier|working-directory: web'; do
  job_release "$rl" "${ligne%%|*}" | grep -qF -- "${ligne#*|}" || echoue "library trois piles : ${ligne%%|*} sans « ${ligne#*|} »"
done
[[ $(grep -cxF '      id-token: write' "$rl") -eq 3 ]] || echoue "library trois piles : id-token par job de publication"
job_release "$rl" verifier | grep -qE 'cargo pkgid|uv version' && echoue "library trois piles : version lue hors de version_composant"
job_release "$rl" release | grep -qF 'needs: [verifier, publier-noyau, publier-web, publier-py]' || echoue "library trois piles : needs de release"

# cli à deux composants, Rust et Python : une archive pour l'un, PyPI pour l'autre.
mkdir "$tmp/rl4"
printf '%s\n' 'composant=moteur|moteur|rust|' 'composant=outil|outil|python|' type=cli systemes=linux,windows,macos \
  version_composant=outil "${base[@]}" >"$tmp/rl4v"
"$install" "$tmp/rl4" "$tmp/rl4v" >/dev/null
rl="$tmp/rl4/.github/workflows/release.yml"
controle_release "$rl"
[[ $(jobs_release "$rl") == $'verifier\nbinaires-moteur\npublier-outil\nrelease' ]] || echoue "cli deux piles : jobs : $(jobs_release "$rl")"
[[ $(job_release "$rl" binaires-moteur | grep -c '{ systeme: ') -eq 3 ]] || echoue "cli deux piles : trois systèmes attendus"
job_release "$rl" binaires-moteur | grep -qF 'working-directory: moteur' || echoue "cli deux piles : binaires hors du dossier du composant"
job_release "$rl" verifier | grep -qF 'uv version --short' || echoue "cli deux piles : version de outil"
job_release "$rl" verifier | grep -qF 'cargo pkgid' && echoue "cli deux piles : version lue dans moteur"
# Une ligne vide sépare deux jobs de livrable (le commentaire du job suit la ligne vide).
[[ $(sed -n '/^  binaires-moteur:$/,/^  publier-outil:$/p' "$rl" | grep -c '^$') -eq 1 ]] || echoue "cli deux piles : jobs collés"
# Une publication sur un registre est irréversible : elle attend les binaires.
job_release "$rl" publier-outil | grep -qxF '    needs: [verifier, binaires-moteur]' ||
  echoue "cli deux piles : publier n'attend pas les binaires : $(job_release "$rl" publier-outil | grep needs)"
job_release "$rl" binaires-moteur | grep -qxF '    needs: verifier' || echoue "cli deux piles : needs des binaires"

# library d'une pile sans gabarit de publication : un job à écrire, qui échoue.
mkdir "$tmp/rl9"
printf '%s\n' 'composant=lib|.|go|' type=library "${base[@]}" >"$tmp/rl9v"
"$install" "$tmp/rl9" "$tmp/rl9v" >/dev/null
rl="$tmp/rl9/.github/workflows/release.yml"
controle_release "$rl"
[[ $(jobs_release "$rl") == $'verifier\npublier-lib\nrelease' ]] || echoue "library go : jobs : $(jobs_release "$rl")"
for mot in '# À ÉCRIRE : publication de lib (go)' 'echo "::error::release.yml : publication de lib à écrire pour go"' 'exit 1' 'needs: verifier' 'contents: read'; do
  job_release "$rl" publier-lib | grep -qF -- "$mot" || echoue "library go : publier sans « $mot »"
done
job_release "$rl" release | grep -qF 'needs: [verifier, publier-lib]' || echoue "library go : needs de release"

# api TypeScript : verifier et release seulement.
mkdir "$tmp/rl5"
printf '%s\n' 'composant=api|.|typescript|' type=api "${base[@]}" >"$tmp/rl5v"
"$install" "$tmp/rl5" "$tmp/rl5v" >/dev/null
rl="$tmp/rl5/.github/workflows/release.yml"
controle_release "$rl"
[[ $(jobs_release "$rl") == $'verifier\nrelease' ]] || echoue "api : jobs : $(jobs_release "$rl")"
job_release "$rl" release | grep -qF 'needs: [verifier]' || echoue "api : needs de release"
grep -qF 'id-token' "$rl" && echoue "api : id-token"

# game : un livrable à écrire, qui échoue.
mkdir "$tmp/rl6"
printf '%s\n' 'composant=jeu|.|rust|' type=game "${base[@]}" >"$tmp/rl6v"
"$install" "$tmp/rl6" "$tmp/rl6v" >/dev/null
rl="$tmp/rl6/.github/workflows/release.yml"
controle_release "$rl"
[[ $(jobs_release "$rl") == $'verifier\nlivrable\nrelease' ]] || echoue "game : jobs : $(jobs_release "$rl")"
for mot in '# À ÉCRIRE : livrable de game' 'echo "::error::release.yml : le livrable de game est à écrire"' 'exit 1' 'contents: read'; do
  job_release "$rl" livrable | grep -qF -- "$mot" || echoue "game : livrable sans « $mot »"
done

# Pile sans gabarit : la lecture de la version est à écrire.
mkdir "$tmp/rl7"
printf '%s\n' 'composant=srv|.|go|' type=api "${base[@]}" >"$tmp/rl7v"
"$install" "$tmp/rl7" "$tmp/rl7v" >/dev/null
rl="$tmp/rl7/.github/workflows/release.yml"
controle_release "$rl"
job_release "$rl" verifier | grep -qF 'echo "::error::release.yml : lecture de la version à écrire pour go"' || echoue "go : lecture de version à écrire"

# version_composant inconnu : refus avant toute écriture, code 1.
mkdir "$tmp/rl8"
printf '%s\n' 'composant=cli|.|rust|' version_composant=absent "${base[@]}" >"$tmp/rl8v"
set +e; "$install" "$tmp/rl8" "$tmp/rl8v" >/dev/null 2>"$tmp/err"; code=$?; set -e
[[ $code -eq 1 ]] || echoue "version_composant inconnu : code $code au lieu de 1"
[[ $(cat "$tmp/err") == 'install.sh : version_composant « absent » n'"'"'est pas un composant' ]] || echoue "version_composant inconnu : message : $(cat "$tmp/err")"
[[ -z $(ls -A "$tmp/rl8") ]] || echoue "version_composant inconnu : écriture malgré le refus"

# --- deploiement.yml : la commande de déploiement d'un tag ---
# Commande avec guillemets, `$` et `{{x}}` : posée telle quelle, sous `run: |`.
mkdir "$tmp/dp1"
printf '%s\n' 'composant=srv|.|typescript|' type=api "${base[@]}" 'deploiement=./deploy.sh "prod" $HOME {{x}}' >"$tmp/dp1v"
"$install" "$tmp/dp1" "$tmp/dp1v" >"$tmp/dp1out"
grep -qxF 'créé       .github/workflows/deploiement.yml' "$tmp/dp1out" || echoue "deploiement : fichier non posé"
dy="$tmp/dp1/.github/workflows/deploiement.yml"
controle_release "$dy"
grep -qxF '          ./deploy.sh "prod" $HOME {{x}}' "$dy" || echoue "deploiement : commande non recopiée telle quelle"
grep -qxF 'on:' "$dy" && grep -qxF '  workflow_dispatch:' "$dy" || echoue "deploiement : pas de workflow_dispatch"
grep -qxF '        type: string' "$dy" && grep -qxF '        required: true' "$dy" || echoue "deploiement : entrée tag mal déclarée"
[[ $(jobs_release "$dy") == deployer ]] || echoue "deploiement : jobs : $(jobs_release "$dy")"
job_release "$dy" deployer | grep -qxF '      contents: read' || echoue "deploiement : contents: read absent"
grep -qxF '          TAG: ${{ inputs.tag }}' "$dy" || echoue "deploiement : TAG ne passe pas par env:"
grep -qF '[[ ! $TAG =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]' "$dy" || echoue "deploiement : contrôle de forme absent"
grep -qF 'echo "::error::deploiement.yml : tag « $TAG » refusé : vX.Y.Z attendu"' "$dy" || echoue "deploiement : message de refus absent"
[[ $(grep -n 'TAG =~' "$dy" | cut -d: -f1) -lt $(grep -n 'actions/checkout@' "$dy" | cut -d: -f1) ]] || echoue "deploiement : contrôle du tag après le checkout"
grep -qx 'permissions: {}' "$dy" || echoue "deploiement : pas de permissions: {} en tête"
# Les lignes `run:` et le corps des blocs `run: |`.
lignes_run() {
  awk '
    bloc && match($0, /^ */) && RLENGTH <= retrait && $0 !~ /^ *$/ { bloc = 0 }
    bloc { print }
    /^ *(- )?run:/ { print; if ($0 ~ /run: *\|/) { bloc = 1; match($0, /^ */); retrait = RLENGTH } }' "$1"
}
lignes_run "$dy" | grep -qF './deploy.sh "prod"' || echoue "deploiement : lignes_run ne lit pas le corps du bloc"
grep -qF 'inputs.tag' <(lignes_run "$dy") && echoue "deploiement : inputs.tag dans un run:"
grep -qxF -- '- **Déploiement** : `./deploy.sh "prod" $HOME {{x}}`.' "$tmp/dp1/docs/agents/harness.md" || echoue "deploiement : ligne de harness.md : $(grep Déploiement "$tmp/dp1/docs/agents/harness.md")"
# Le contrôle du tag, lancé tel quel : vX.Y.Z passe, le reste sort avec 1.
sed -n '/^        run: |$/,/^          fi$/{p;/^          fi$/q}' "$dy" | sed '1d; s/^          //' >"$tmp/dp1ctl"
TAG=v1.2.3 bash "$tmp/dp1ctl" || echoue "deploiement : v1.2.3 refusé"
set +e; sortie_tag="$(TAG='main; rm -rf /' bash "$tmp/dp1ctl")"; code_tag=$?; set -e
[[ $code_tag -eq 1 ]] || echoue "deploiement : tag faux : code $code_tag au lieu de 1"
[[ $sortie_tag == '::error::deploiement.yml : tag « main; rm -rf / » refusé : vX.Y.Z attendu' ]] || echoue "deploiement : tag faux : message : $sortie_tag"
# Une relance ne change rien.
"$install" "$tmp/dp1" "$tmp/dp1v" >"$tmp/dp1bis"
grep -qxF 'identique  .github/workflows/deploiement.yml' "$tmp/dp1bis" || echoue "deploiement : relance non identique"

# Commande simple : indentée sous le bloc `run: |`.
mkdir "$tmp/dp3"
printf '%s\n' 'composant=srv|.|typescript|' type=api "${base[@]}" 'deploiement=echo a' >"$tmp/dp3v"
"$install" "$tmp/dp3" "$tmp/dp3v" >/dev/null
grep -qxF '          echo a' "$tmp/dp3/.github/workflows/deploiement.yml" || echoue "deploiement : commande simple mal indentée"

# Sans valeur : pas de fichier, ligne « à préciser ».
mkdir "$tmp/dp2"
printf '%s\n' 'composant=srv|.|typescript|' type=api "${base[@]}" >"$tmp/dp2v"
"$install" "$tmp/dp2" "$tmp/dp2v" >/dev/null
[[ ! -e $tmp/dp2/.github/workflows/deploiement.yml ]] || echoue "deploiement : fichier posé sans commande"
grep -qxF -- '- **Déploiement** : à préciser.' "$tmp/dp2/docs/agents/harness.md" || echoue "deploiement : ligne « à préciser » absente"

# Valeur vide : traitée comme « à préciser ».
mkdir "$tmp/dp4"
printf '%s\n' 'composant=srv|.|typescript|' type=api "${base[@]}" 'deploiement=' >"$tmp/dp4v"
"$install" "$tmp/dp4" "$tmp/dp4v" >/dev/null
[[ ! -e $tmp/dp4/.github/workflows/deploiement.yml ]] || echoue "deploiement vide : fichier posé"
grep -qxF -- '- **Déploiement** : à préciser.' "$tmp/dp4/docs/agents/harness.md" ||
  echoue "deploiement vide : ligne de harness.md : $(grep Déploiement "$tmp/dp4/docs/agents/harness.md")"

# Un secret lu par une expression `${{ secrets.X }}` passe tel quel.
mkdir "$tmp/dp5"
printf '%s\n' 'composant=srv|.|typescript|' type=api "${base[@]}" 'deploiement=FLY_API_TOKEN=${{ secrets.FLY_API_TOKEN }} flyctl deploy' >"$tmp/dp5v"
"$install" "$tmp/dp5" "$tmp/dp5v" >/dev/null
grep -qxF '          FLY_API_TOKEN=${{ secrets.FLY_API_TOKEN }} flyctl deploy' "$tmp/dp5/.github/workflows/deploiement.yml" ||
  echoue "deploiement : expression de secret modifiée"

# --- dependabot.yml : un écosystème par composant ---
# Rust à la racine et Python dans api/ : trois entrées, github-actions comprise.
mkdir "$tmp/db1"
printf '%s\n' 'composant=noyau|.|rust|' 'composant=api|api|python|' type=cli "${base[@]}" >"$tmp/db1v"
"$install" "$tmp/db1" "$tmp/db1v" >/dev/null
db="$tmp/db1/.github/dependabot.yml"
grep -q '{{' "$db" && echoue "dependabot : {{ restant"
grep -qxF '  - package-ecosystem: github-actions' "$db" || echoue "dependabot : github-actions absent"
[[ $(grep -c 'package-ecosystem:' "$db") -eq 3 ]] || echoue "dependabot : nombre d'entrées : $(grep -c 'package-ecosystem:' "$db")"
grep -qxF '  - package-ecosystem: "cargo"' "$db" || echoue "dependabot : cargo absent"
grep -qxF '  - package-ecosystem: "uv"' "$db" || echoue "dependabot : uv absent"
grep -qxF '    directory: "/"' "$db" || echoue "dependabot : directory de la racine"
grep -qxF '    directory: "/api"' "$db" || echoue "dependabot : directory /api"
grep -qF 'directory: "/."' "$db" && echoue "dependabot : directory /."
grep -qxF '      noyau-mineures:' "$db" && grep -qxF '      api-mineures:' "$db" || echoue "dependabot : groupes"
[[ $(grep -cxF '        update-types: ["minor", "patch"]' "$db") -eq 2 ]] || echoue "dependabot : update-types"
[[ $(grep -cxF '      interval: "weekly"' "$db") -eq 2 ]] || echoue "dependabot : intervalle des composants"
# Le YAML est valide : chaque entrée reste sous « updates: ».
[[ $(grep -c '^  - package-ecosystem' "$db") -eq 3 && $(grep -c '^[^ #]' "$db") -eq 2 ]] || echoue "dependabot : indentation"

# TypeScript dans web/ : npm.
mkdir "$tmp/db2"
printf '%s\n' 'composant=web|web|typescript|' type=web-frontend "${base[@]}" >"$tmp/db2v"
"$install" "$tmp/db2" "$tmp/db2v" >/dev/null
grep -qxF '  - package-ecosystem: "npm"' "$tmp/db2/.github/dependabot.yml" || echoue "dependabot : npm absent"
grep -qxF '    directory: "/web"' "$tmp/db2/.github/dependabot.yml" || echoue "dependabot : directory /web"

# Pile sans gabarit : pas d'entrée, un commentaire le dit.
mkdir "$tmp/db3"
printf '%s\n' 'composant=srv|.|go|' type=api "${base[@]}" >"$tmp/db3v"
"$install" "$tmp/db3" "$tmp/db3v" >/dev/null
db="$tmp/db3/.github/dependabot.yml"
[[ $(grep -c 'package-ecosystem:' "$db") -eq 1 ]] || echoue "dependabot : pile go : entrées"
grep -qxF '  # srv (go) : pas de gabarit Dependabot, à ajouter à la main.' "$db" || echoue "dependabot : commentaire de la pile sans gabarit"
grep -qxF '  - package-ecosystem: github-actions' "$db" || echoue "dependabot : github-actions absent (go)"

# La mise à jour d'un projet posé avant la 0.4 est testée dans tests/tools.sh,
# avec la migration.

echo "install.sh : tous les cas passent"
