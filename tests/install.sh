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
grep -q 'cache/essai-rapide-target' "$tmp/p/scripts/check.sh" || echoue "cache WSL sans le nom du projet en minuscules"
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
grep -qF 'cache/lan-d-t-co-x-target"' "$tmp/r/scripts/check.sh" || echoue "cache WSL : nom de dossier non filtré"
# Même résultat sous une locale UTF-8, où `${x,,}` changerait « É ».
mkdir "$tmp/r8"
LC_ALL=C.UTF-8 "$install" "$tmp/r8" "$tmp/u" >/dev/null
cmp -s "$tmp/r/scripts/check.sh" "$tmp/r8/scripts/check.sh" || echoue "projet_dossier dépend de la locale"
bash -n "$tmp/r/scripts/check.sh" || echoue "check.sh n'est plus du shell valide"
grep -qF "# Élan d'été & Co/x" "$tmp/r/CLAUDE.md" || echoue "CLAUDE.md : le nom du projet doit rester tel quel"

# projet_dossier donné par le fichier de valeurs (le name de Cargo.toml).
mkdir "$tmp/s"
printf 'pile=rust\nprojet=Atelier\nprojet_dossier=atelier-editeur\nspec=s.md\nlieu_test=ici\n' >"$tmp/x"
"$install" "$tmp/s" "$tmp/x" >/dev/null
grep -qF 'cache/atelier-editeur-target"' "$tmp/s/scripts/check.sh" || echoue "projet_dossier fourni ignoré"

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
