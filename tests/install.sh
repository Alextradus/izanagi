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
[[ $(grep -c '^créé' <<<"$sortie") -eq 18 ]] || echoue "première pose : $sortie"
grep -qxF 'useDefault = true' "$tmp/p/.gitleaks.toml" || echoue ".gitleaks.toml n'étend pas la configuration par défaut"
grep -qF 'gitleaks git' "$tmp/p/scripts/check.sh" || echoue "check.sh ne lance pas gitleaks"
for f in .izanagi/config.env .izanagi/.gitignore .claude/settings.json AGENTS.md; do
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
[[ $(grep -c '^identique' <<<"$sortie") -eq 17 ]] || echoue "relance : $sortie"
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
for mot in 'cron:' 'workflow_dispatch:' 'issues: write' 'needs: [secrets, audit]' 'gitleaks git --redact --no-banner .' 'cargo audit' 'securite'; do
  grep -qF -- "$mot" "$tmp/p/.github/workflows/securite.yml" || echoue "securite.yml : « $mot » absent"
done
# Seul le job de l'issue peut écrire, et il ne lance aucune action tierce.
[[ $(grep -c 'issues: write' "$tmp/p/.github/workflows/securite.yml") -eq 1 ]] || echoue "securite.yml : issues: write hors du seul job de l'issue"
[[ -z $(sed -n '/^  issue:/,$p' "$tmp/p/.github/workflows/securite.yml" | grep 'uses:') ]] || echoue "securite.yml : le job de l'issue lance une action"
grep -qF 'package-ecosystem: github-actions' "$tmp/p/.github/dependabot.yml" || echoue "dependabot.yml : écosystème"

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
mkdir "$tmp/ar" "$tmp/ar/bin" "$tmp/ar/web"
git -C "$tmp/ar" init -q
for outil in cargo npm gitleaks; do
  printf '#!/bin/sh\necho "%s $*" >>"%s/journal"\n' "$outil" "$tmp/ar" >"$tmp/ar/bin/$outil"
  chmod +x "$tmp/ar/bin/$outil"
done
printf '%s\n' 'composant=cli|.|rust|' 'composant=web|web|typescript|' systemes=windows,linux,macos "${base[@]}" >"$tmp/arv"
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
  grep -qxF 'cargo test --workspace --locked' "$tmp/ar/journal" || echoue "check.sh $args : cargo non lancé"
  grep -qxF 'npm test' "$tmp/ar/journal" || echoue "check.sh $args : npm non lancé"
  if [[ $args == *--complet* ]]; then
    grep -qE ' : tout passe \(complet\)$' <<<"$sortie_ar" || echoue "check.sh $args : fin sans (complet) : $sortie_ar"
  else
    grep -qE ' : tout passe$' <<<"$sortie_ar" || echoue "check.sh $args : fin de sortie : $sortie_ar"
  fi
done
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

# --- piles TypeScript et Python, dev.sh ---
mkdir "$tmp/t1"
printf '%s
' 'composant=api|api|typescript|npm run dev' 'composant=web|web|typescript|npm run dev' projet=essai spec=s.md lieu_test=ici >"$tmp/t1v"
sortie="$("$install" "$tmp/t1" "$tmp/t1v")"
[[ $(sed '/^  audit:/q' "$tmp/t1/.github/workflows/ci.yml" | grep -c 'actions/setup-node') -eq 1 ]] || echoue "setup-node : un seul attendu dans le job check"
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
grep -qxF -- '- composant : a | a | typescript |' "$tmp/t4/docs/agents/harness.md" || echoue "harness.md : espace final sans lancement"

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

# La mise à jour d'un projet posé avant la 0.4 est testée dans tests/tools.sh,
# avec la migration.

echo "install.sh : tous les cas passent"
