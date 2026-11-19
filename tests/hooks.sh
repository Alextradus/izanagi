#!/usr/bin/env bash
# Teste les quatre hooks du plugin : entrée JSON sur l'entrée standard, code de
# retour, sortie standard et sortie d'erreur.
#
# Faits lus le 2026-11-12 dans https://code.claude.com/docs/en/hooks.md :
# - un sous-agent de plugin a pour `agent_type` son nom préfixé, `izanagi:implementer`,
#   et le filtre s'écrit `^izanagi:implementer$` ;
# - l'entrée de SubagentStop porte `agent_id`, `agent_type`, `stop_hook_active`,
#   `agent_transcript_path` et `last_assistant_message` ;
# - depuis Claude Code 2.1.271, un sous-agent peut rendre son rapport par l'outil
#   SubagentHandback : `last_assistant_message` ne le contient alors pas. Le hook lit
#   donc aussi la fin du transcript du sous-agent ;
# - le code 2 bloque, et la sortie d'erreur devient la consigne suivante du sous-agent ;
# - le texte qu'un hook SessionStart écrit sur sa sortie standard entre dans le contexte.
set -euo pipefail

racine="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export TMPDIR="$tmp/tmpdir"
mkdir -p "$TMPDIR"
# Les hooks prennent le dossier de l'entrée JSON, sinon le dossier courant.
unset CLAUDE_PROJECT_DIR

echoue() { echo "ÉCHEC : $*" >&2; exit 1; }

# lancer <script> <dossier> <entrée JSON> : remplit $sortie, $erreur et $code.
lancer() {
  local script="$racine/hooks/$1" dossier=$2 entree=$3
  code=0
  sortie="$(cd "$dossier" && printf '%s' "$entree" | bash "$script" 2>"$tmp/err")" || code=$?
  erreur="$(cat "$tmp/err")"
}

# nouveau_projet <nom> : dépôt git avec un config.env, sur la branche main.
nouveau_projet() {
  local p="$tmp/$1"
  mkdir -p "$p/.izanagi"
  git -C "$p" init -q -b main
  git -C "$p" config user.email essai@example.invalid
  git -C "$p" config user.name Essai
  printf 'izanagi_version=%s\nbranche=main\nhook_push=bloque\nhook_verification=bloque\n' "$version" >"$p/.izanagi/config.env"
  git -C "$p" add -A
  git -C "$p" commit -q -m cadre
  printf '%s' "$p"
}

regler() { # regler <projet> <clé> <valeur>
  sed -i "/^$2=/d" "$1/.izanagi/config.env"
  printf '%s=%s\n' "$2" "$3" >>"$1/.izanagi/config.env"
}

# shellcheck source=../scripts/lib.sh
. "$racine/scripts/lib.sh"
version="$(plugin_version)"

# --- hooks.json ---
json="$racine/hooks/hooks.json"
[[ -f $json ]] || echoue "hooks/hooks.json absent"
for mot in '"SessionStart"' '"PreToolUse"' '"SubagentStop"' 'session-start.sh' 'guard-push.sh' 'guard-destructive.sh' 'verify-implementer.sh' '^izanagi:implementer$' 'CLAUDE_PLUGIN_ROOT'; do
  grep -qF -- "$mot" "$json" || echoue "hooks.json ne contient pas $mot"
done

# --- json_string ---
[[ $(json_string '{"a":"x","command":"git push \"origin\" main","b":1}' command) == 'git push "origin" main' ]] || echoue "json_string : guillemets échappés"
[[ $(json_string '{"cwd":"C:\\Users\\moi\\projet"}' cwd) == 'C:\Users\moi\projet' ]] || echoue "json_string : barres obliques inverses"
[[ $(json_string '{"command": "a\nb"}' command) == 'a b' ]] || echoue "json_string : saut de ligne"
[[ $(json_string '{"command": "a\nb"}' command '|') == 'a|b' ]] || echoue "json_string : saut de ligne remplacé"
json_string '{"a":"x"}' absente >/dev/null && echoue "json_string : clé absente"

# --- commandes_simples ---
# montrer : affiche les mots d'une commande simple séparés par `|`, et ne vise rien.
montrer() { local IFS='|'; printf '%s\n' "$*"; return 1; }
vise_push() { [[ $1 == git && $2 == push ]]; }
decoupe() { commandes_simples "$1" montrer || true; }
[[ $(decoupe 'git commit -m "a; b" && git push') == $'git|commit|-m|a; b\ngit|push' ]] || echoue "commandes_simples : guillemets et && : « $(decoupe 'git commit -m "a; b" && git push') »"
[[ $(decoupe $'git push origin \\\n  main') == 'git|push|origin|main' ]] || echoue "commandes_simples : ligne continuée"
[[ $(decoupe '(cd x && git push)') == $'cd|x\ngit|push' ]] || echoue "commandes_simples : sous-shell"
[[ $(decoupe "echo \"l'a\" 'b \"c\"'") == "echo|l'a|b \"c\"" ]] || echoue "commandes_simples : guillemets imbriqués"
[[ $(decoupe 'a ""') == 'a|' ]] || echoue "commandes_simples : mot vide entre guillemets"
# Entre guillemets doubles, la barre oblique inverse n'échappe que $, `, ", \ et le
# saut de ligne, comme dans bash : un chemin Windows garde ses barres.
[[ $(decoupe 'rm -rf "C:\Users\x"') == 'rm|-rf|C:\Users\x' ]] || echoue "commandes_simples : chemin Windows entre guillemets : « $(decoupe 'rm -rf "C:\Users\x"') »"
[[ $(decoupe 'echo "a\"b\\c\$d"') == 'echo|a"b\c$d' ]] || echoue "commandes_simples : échappements entre guillemets doubles"
[[ -z $(decoupe ' ; ') ]] || echoue "commandes_simples : commande vide"
commandes_simples 'ls; git push' vise_push || echoue "commandes_simples : visée non rendue"
commandes_simples 'git status' vise_push && echoue "commandes_simples : visée rendue à tort"

# --- session-start.sh ---
mkdir "$tmp/vide"
lancer session-start.sh "$tmp/vide" '{}'
[[ $code -eq 0 && -z $sortie ]] || echoue "démarrage hors dépôt git : code $code, sortie « $sortie »"

mkdir "$tmp/sans" && git -C "$tmp/sans" init -q -b main
lancer session-start.sh "$tmp/sans" '{}'
[[ $code -eq 0 && -z $sortie ]] || echoue "démarrage hors projet Izanagi : code $code, sortie « $sortie »"

p="$(nouveau_projet demarrage)"
lancer session-start.sh "$p" '{}'
[[ $code -eq 0 && $sortie == 'Izanagi : aucun flux en cours sur cette branche.' ]] || echoue "démarrage sans état : « $sortie »"

printf 'flux=jalon\nnom=essai\nphase=tranches\ntranche=2\n' >"$p/.izanagi/state.env"
lancer session-start.sh "$p" '{}'
[[ $sortie == 'Izanagi : flux jalon « essai », phase tranches, tranche 2. Reprends avec /izanagi:jalon.' ]] || echoue "démarrage avec état : « $sortie »"

printf 'flux=jalon\nnom=essai\nphase=revue\ntranche=2\ntour=3\n' >"$p/.izanagi/state.env"
lancer session-start.sh "$p" '{}'
[[ $sortie == 'Izanagi : flux jalon « essai », phase revue, tranche 2, tour de revue 3. Reprends avec /izanagi:jalon.' ]] || echoue "démarrage avec tour : « $sortie »"

printf 'flux=task\nnom=petit\nphase=debut\n' >"$p/.izanagi/state.env"
lancer session-start.sh "$p" '{}'
[[ $sortie == 'Izanagi : flux task « petit », phase debut. Reprends avec /izanagi:task.' ]] || echoue "démarrage d'un flux task : « $sortie »"

printf 'flux=fix\nnom=bouton\nphase=revue\ntour=1\nrisque=eleve\n' >"$p/.izanagi/state.env"
lancer session-start.sh "$p" '{}'
[[ $sortie == 'Izanagi : flux fix « bouton », phase revue, tour de revue 1, risque eleve. Reprends avec /izanagi:fix.' ]] || echoue "démarrage d'un flux fix : « $sortie »"
printf 'flux=jalon\nnom=essai\nphase=test\ncorrectif=bouton-mort\n' >"$p/.izanagi/state.env"
lancer session-start.sh "$p" '{}'
[[ $sortie == 'Izanagi : flux jalon « essai », phase test, correctif « bouton-mort ». Reprends avec /izanagi:fix.' ]] || echoue "démarrage d'un correctif de jalon : « $sortie »"
printf 'flux=task\nnom=petit\nphase=debut\n' >"$p/.izanagi/state.env"

# Le dossier vient de l'entrée JSON quand elle le donne.
lancer session-start.sh "$tmp/vide" "{\"cwd\":\"$p\"}"
[[ $sortie == 'Izanagi : flux task « petit », phase debut. Reprends avec /izanagi:task.' ]] || echoue "démarrage : cwd de l'entrée ignoré : « $sortie »"

rm "$p/.izanagi/state.env"
regler "$p" izanagi_version 0.0.1
lancer session-start.sh "$p" '{}'
grep -qxF "Izanagi : le cadre de ce projet est en 0.0.1, le plugin en $version. Lance /izanagi:upgrade." <<<"$sortie" || echoue "démarrage : version en retard : « $sortie »"

mkdir -p "$tmp/ancien/docs/agents" && git -C "$tmp/ancien" init -q -b main
echo "- **Spec** : \`s.md\`." >"$tmp/ancien/docs/agents/jalon.md"
lancer session-start.sh "$tmp/ancien" '{}'
[[ $sortie == "Izanagi : ce projet a un cadre d'avant la 0.4. Lance /izanagi:upgrade." ]] || echoue "démarrage : cadre ancien : « $sortie »"

# --- guard-push.sh ---
entree_push() { # entree_push <commande>
  local c="${1//\\/\\\\}"
  c="${c//$'\n'/\\n}"
  printf '{"tool_name":"Bash","tool_input":{"command":"%s","description":"x"}}' "${c//\"/\\\"}"
}
refuse() { # refuse <projet> <commande>
  lancer guard-push.sh "$1" "$(entree_push "$2")"
  [[ $code -eq 2 ]] || echoue "push non refusé (code $code) : $2"
  grep -qF 'refusé' <<<"$erreur" || echoue "push refusé sans message : $2"
}
passe() { # passe <projet> <commande>
  lancer guard-push.sh "$1" "$(entree_push "$2")"
  [[ $code -eq 0 && -z $sortie ]] || echoue "push refusé à tort (code $code, « $sortie ») : $2"
}

p="$(nouveau_projet push)"
git -C "$p" switch -q -c task/x
for c in 'git push origin main' 'git push origin HEAD:main' 'git push -f origin task/x:main' \
  'git push origin refs/heads/main' 'cd sub && git push origin main' 'git push origin +main' \
  'git push "origin" "main"' 'git -C . push origin main' 'git add -A; git push origin main' \
  $'git status\ngit push origin main' $'git add .\ngit commit -m x\ngit push origin main' \
  'git -C "mon dossier" push origin main' "git -C 'mon dossier' push origin main" \
  'git push origin main --tags' 'git push --all' 'git push --mirror origin' \
  'git push -o ci.skip origin main' '(git push origin main)' 'git push --repo=origin main' 'git commit -m "é; à" && git push origin main' $'git push origin \\\n  main'; do
  refuse "$p" "$c"
done
grep -qF 'hook_push=avertit' <<<"$erreur" || echoue "le refus ne dit pas comment l'autoriser : $erreur"
for c in 'git push' 'git push -u origin task/x' 'git push origin maintenance' 'git push origin HEAD' \
  'git push origin main-backup' 'git status && echo push main' 'git log --oneline main' \
  'git commit -m "a; git push origin main"' "git commit -m 'x && git push origin main'" \
  $'git commit -m "titre\n\ngit push origin main"' 'git push -o ci.skip origin task/x' \
  'git push origin task/x --tags'; do
  passe "$p" "$c"
done

git -C "$p" switch -q main
for c in 'git push' 'git push origin' 'git push -u origin' 'git push origin HEAD' \
  'git push -o ci.skip origin' 'git push --follow-tags'; do
  refuse "$p" "$c"
done
for c in 'git push origin v1.2.0' 'git push --tags' 'git push origin --tags' 'git push origin refs/tags/v1.2.0' \
  'git push origin --delete jalon/essai' 'git push origin -d jalon/essai' 'git push --follow-tags origin v0.4.0'; do
  passe "$p" "$c"
done

# Une commande trop longue pour être découpée passe, avec un avertissement.
longue="$(printf 'echo %020000d; ' 0)git push origin main"
lancer guard-push.sh "$p" "$(entree_push "$longue")"
[[ $code -eq 0 ]] || echoue "commande trop longue : code $code"
[[ $sortie == '{"systemMessage": "Izanagi : commande de plus de 20000 caractères, push non contrôlé."}' ]] || echoue "commande trop longue : sortie « ${sortie:0:200} »"

regler "$p" hook_push avertit
lancer guard-push.sh "$p" "$(entree_push 'git push origin main')"
[[ $code -eq 0 ]] || echoue "hook_push=avertit : code $code"
[[ $sortie == '{"systemMessage": "Izanagi : push direct sur main."}' ]] || echoue "hook_push=avertit : sortie « $sortie »"
[[ $(tail -n 1 "$p/.izanagi/refus.log") == *'|main|push|push direct sur main' ]] || echoue "refus.log : avertissement du push non noté"

regler "$p" hook_push bloque
regler "$p" branche trunk
git -C "$p" switch -q task/x
refuse "$p" 'git push origin trunk'
[[ $(tail -n 1 "$p/.izanagi/refus.log") == *'|task/x|push|push direct sur trunk' ]] || echoue "refus.log : refus du push non noté"
passe "$p" 'git push origin main'

passe "$tmp/sans" 'git push origin main'
passe "$tmp/vide" 'git push origin main'

# --- guard-destructive.sh ---
# Faits lus le 2026-11-18 dans https://code.claude.com/docs/en/hooks.md : un hook
# PreToolUse qui sort avec 0 et écrit `permissionDecision: "ask"` dans
# `hookSpecificOutput` fait demander confirmation à l'utilisateur, qui voit la raison.
demande() { # demande <projet> <commande> [motif attendu]
  lancer guard-destructive.sh "$1" "$(entree_push "$2")"
  [[ $code -eq 0 ]] || echoue "destructif : code $code : $2"
  [[ $sortie == '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "ask", "permissionDecisionReason": "Izanagi : '* ]] || echoue "destructif : pas de demande (« $sortie ») : $2"
  if [[ -n ${3:-} ]]; then
    [[ $(tail -n 1 "$1/.izanagi/refus.log") =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z\|[^|]+\|destructif\|(.*)$ ]] || echoue "destructif : ligne de refus.log illisible : $2"
    [[ ${BASH_REMATCH[1]} == "$3" ]] || echoue "destructif : motif « ${BASH_REMATCH[1]} » au lieu de « $3 » : $2"
  fi
}
laisse() { # laisse <projet> <commande>
  lancer guard-destructive.sh "$1" "$(entree_push "$2")"
  [[ $code -eq 0 && -z $sortie ]] || echoue "destructif : demande à tort (code $code, « $sortie ») : $2"
}

p="$(nouveau_projet destructif)"
mkdir -p "$p/src" "$p/node_modules"
echo a >"$p/src/a.txt"
git -C "$p" add -A && git -C "$p" commit -q -m src
git -C "$p" switch -q -c task/x
# Arbre propre : `checkout -- .` et `restore .` ne perdent rien.
laisse "$p" 'git checkout -- .'
laisse "$p" 'git restore .'
[[ ! -e $p/.izanagi/refus.log ]] || echoue "destructif : refus.log écrit sans demande"

demande "$p" 'git reset --hard' 'git reset --hard'
demande "$p" 'git reset --hard HEAD~1'
demande "$p" 'cd src && git reset --hard'
demande "$p" 'FOO=1 git -C . reset --hard'
demande "$p" 'git clean -fd' 'git clean -f'
demande "$p" 'git clean -xfd'
demande "$p" 'git clean --force'
demande "$p" 'git push --force origin task/x' 'git push --force'
demande "$p" 'git push -f'
demande "$p" 'git push origin +task/x'
demande "$p" 'git branch -D vieille' 'git branch -D'
demande "$p" 'git branch --delete --force vieille'
echo b >"$p/src/a.txt"
demande "$p" 'git checkout -- .' 'git checkout . sur un arbre modifié'
demande "$p" 'git restore .' 'git restore . sur un arbre modifié'
git -C "$p" checkout -q -- .
demande "$p" 'rm -rf ..' 'rm -rf ..'
demande "$p" 'rm -rf ~/x'
demande "$p" 'rm -rf "$DOSSIER"' 'rm -rf $DOSSIER'
demande "$p" 'rm -rf `pwd`/src'
demande "$p" 'rm -fr /'
demande "$p" 'rm -r -f ../x'
demande "$p" 'rm --recursive --force ..'
demande "$p" 'rm -rf .' 'rm -rf .'
demande "$p" 'rm -rf *'
demande "$p" "rm -rf $p"
demande "$p" 'rm -Rf src/../..'
demande "$p" 'cat .env' 'lecture de .env'
demande "$p" 'source .env.local' 'lecture de .env.local'
demande "$p" '. .env'
demande "$p" 'cp .env /tmp/x'
demande "$p" 'cat .envrc'
demande "$p" 'cat cle.pem'
demande "$p" 'less config/server.key' 'lecture de config/server.key'
demande "$p" 'cat ~/.ssh/id_rsa'
demande "$p" 'base64 credentials.json'
demande "$p" 'grep KEY .env | wc -l'
demande "$p" 'cat ~/.ssh/id_ed25519' 'lecture de ~/.ssh/id_ed25519'
demande "$p" 'cp ~/.ssh/id_ecdsa /tmp/k'
# Un `cd` plus tôt dans la commande change le dossier où `rm` résout ses cibles.
demande "$p" 'cd .. && rm -rf *' 'rm -rf *'
demande "$p" 'cd /tmp; rm -rf x'
demande "$p" 'cd "$AILLEURS" && rm -rf build'
demande "$p" 'cd && rm -rf x'
demande "$p" 'rm -rf "C:\Users\x"' 'rm -rf C:\Users\x'
# Les préfixes courants ne cachent pas la commande.
demande "$p" 'env GIT_DIR=.git git reset --hard'
demande "$p" 'command rm -rf ..'
demande "$p" 'time git clean -fd'
demande "$p" 'nohup rm -rf ~/x'
demande "$p" 'exec git push --force'

for c in 'git commit -m "doc: git reset --hard"' "git commit -m 'rm -rf / et cat .env'" \
  'git push --force-with-lease' 'git push --force-with-lease origin task/x' 'git push -u origin task/x' \
  'git reset --soft HEAD~1' 'git reset HEAD a.txt' 'git clean -n' 'git clean -nd' 'git branch -d vieille' \
  'git restore src/a.txt' 'git checkout main' 'rm -rf node_modules' 'rm -rf src/*' 'rm -rf build/out' \
  "rm -rf $p/node_modules" 'rm -f ../x' 'rm -r ../x' 'cat .env.example' 'cat README.md' 'ls .env' \
  'git status' 'echo rm -rf ..'; do
  laisse "$p" "$c"
done
(cd "$p/src" && laisse "$p/src" 'rm -rf ../node_modules')
demande "$p/src" 'rm -rf ..'
laisse "$p" 'cd src && rm -rf build'
laisse "$p" 'cd src/.. && rm -rf node_modules'
# Les options de `cd` ne sont pas des dossiers ; `pushd` change de dossier comme `cd`,
# et `popd` rend le dossier inconnu.
demande "$p" 'cd -P .. && rm -rf *'
demande "$p" 'cd -- .. && rm -rf *'
demande "$p" 'pushd .. && rm -rf *'
demande "$p" 'popd && rm -rf build'
laisse "$p" 'cd -P src && rm -rf build'
# La valeur d'une option de préfixe n'est pas la commande.
demande "$p" 'sudo -u root rm -rf ~/x'
demande "$p" 'env -u GIT_DIR git reset --hard'
laisse "$p" 'sudo -E rm -rf node_modules'
demande "$p" 'sudo --user root rm -rf ~/x'
demande "$p" 'pushd +1 && rm -rf build'
demande "$p" 'pushd && rm -rf build'
# `checkout .` regarde l'arbre du dépôt visé par `-C` ou par un `cd`.
p2="$(nouveau_projet destructif-autre)"
echo a >"$p2/b.txt" && git -C "$p2" add b.txt && git -C "$p2" commit -q -m b && echo c >"$p2/b.txt"
demande "$p" "git -C $p2 checkout ."
demande "$p" "cd $p2 && git restore ."
laisse "$p2" "git -C $p checkout ."

regler "$p" hook_destructif bloque
lancer guard-destructive.sh "$p" "$(entree_push 'git reset --hard')"
[[ $code -eq 2 ]] || echoue "hook_destructif=bloque : code $code"
[[ $erreur == 'Izanagi : git reset --hard refusé. Pour être consulté à la place, mets hook_destructif=demande dans .izanagi/config.env.' ]] || echoue "hook_destructif=bloque : « $erreur »"
regler "$p" hook_destructif avertit
lancer guard-destructive.sh "$p" "$(entree_push 'git reset --hard')"
[[ $code -eq 0 && $sortie == '{"systemMessage": "Izanagi : git reset --hard."}' ]] || echoue "hook_destructif=avertit : code $code, « $sortie »"
sed -i '/^hook_destructif=/d' "$p/.izanagi/config.env"
demande "$p" 'git reset --hard'
# Un nom de fichier qui porte un guillemet reste du JSON valide.
lancer guard-destructive.sh "$p" "$(entree_push 'cat "a\"b.pem"')"
[[ $sortie == *'lecture de a\"b.pem'* ]] || echoue "destructif : guillemet non échappé : « $sortie »"

lancer guard-destructive.sh "$p" "$(entree_push "$longue")"
[[ $code -eq 0 && $sortie == '{"systemMessage": "Izanagi : commande de plus de 20000 caractères, gestes destructeurs non contrôlés."}' ]] || echoue "destructif : commande trop longue : « ${sortie:0:200} »"

laisse "$tmp/sans" 'git reset --hard'
laisse "$tmp/vide" 'rm -rf ..'

# --- verify-implementer.sh ---
p="$(nouveau_projet verif)"
cat >"$p/verif.sh" <<'FIN'
echo "ligne de la vérification"
touch temoin
exit "$(cat code)"
FIN
regler "$p" verification 'bash verif.sh'
entree_arret() { # entree_arret <identifiant> [dernier message] [transcript]
  printf '{"hook_event_name":"SubagentStop","stop_hook_active":false,"agent_id":"%s","agent_type":"izanagi:implementer","agent_transcript_path":"%s","last_assistant_message":"%s"}' \
    "$1" "${3:-}" "${2:-fini}"
}

echo 0 >"$p/code"
lancer verify-implementer.sh "$p" "$(entree_arret a1)"
[[ $code -eq 0 && -z $sortie && -e $p/temoin ]] || echoue "vérification verte : code $code, sortie « $sortie »"

echo 1 >"$p/code"
for essai in 1 2; do
  lancer verify-implementer.sh "$p" "$(entree_arret a1)"
  [[ $code -eq 2 ]] || echoue "vérification rouge, essai $essai : code $code"
  grep -qF 'ligne de la vérification' <<<"$erreur" || echoue "le refus ne montre pas la sortie de la vérification : $erreur"
  grep -qF 'statut bloqué' <<<"$erreur" || echoue "le refus ne nomme pas le statut de sortie : $erreur"
  grep -qE 'Statut : (bloqu|question)' <<<"$erreur" && echoue "le refus écrit le motif que le hook cherche dans le transcript"
  [[ $(tail -n 1 "$p/.izanagi/refus.log") == *'|main|verification|vérification rouge' ]] || echoue "refus.log : vérification rouge non notée, essai $essai"
done
lancer verify-implementer.sh "$p" "$(entree_arret a1)"
[[ $code -eq 0 ]] || echoue "troisième échec : code $code"
grep -qF '"systemMessage"' <<<"$sortie" || echoue "troisième échec : pas d'avertissement : « $sortie »"
[[ $(tail -n 1 "$p/.izanagi/refus.log") == *'|main|verification|vérification rouge après deux refus' ]] || echoue "refus.log : troisième échec non noté"
lancer verify-implementer.sh "$p" "$(entree_arret a1)"
[[ $code -eq 2 ]] || echoue "le compteur n'est pas remis à zéro après l'avertissement : code $code"

# Un autre sous-agent a son propre compteur.
lancer verify-implementer.sh "$p" "$(entree_arret b2)"
[[ $code -eq 2 ]] || echoue "second sous-agent : code $code"
lancer verify-implementer.sh "$p" "$(entree_arret b2)"
[[ $code -eq 2 ]] || echoue "second sous-agent, deuxième échec : code $code"

# Une vérification verte remet le compteur à zéro.
echo 0 >"$p/code"
lancer verify-implementer.sh "$p" "$(entree_arret b2)"
echo 1 >"$p/code"
lancer verify-implementer.sh "$p" "$(entree_arret b2)"
lancer verify-implementer.sh "$p" "$(entree_arret b2)"
[[ $code -eq 2 ]] || echoue "compteur non remis à zéro par une vérification verte : code $code"

# Statut « bloqué » ou « question » : pas de vérification.
for statut in 'bloqué' 'question'; do
  rm -f "$p/temoin"
  lancer verify-implementer.sh "$p" "$(entree_arret c3 "Statut : $statut\\nUn test casse.")"
  [[ $code -eq 0 && -z $sortie ]] || echoue "statut $statut : code $code"
  [[ ! -e $p/temoin ]] || echoue "statut $statut : la vérification a tourné"
done
# Le statut peut n'être que dans la fin du transcript du sous-agent.
printf '%s\n' '{"type":"user","message":"Statut : fait"}' '{"type":"assistant","tool_input":{"message":"Statut : bloqué\nUn test casse."}}' >"$tmp/transcript.jsonl"
rm -f "$p/temoin"
lancer verify-implementer.sh "$p" "$(entree_arret d4 'Rapport rendu.' "$tmp/transcript.jsonl")"
[[ $code -eq 0 && ! -e $p/temoin ]] || echoue "statut lu dans le transcript : code $code"
# Un statut « fait » avec une vérification rouge reste refusé.
lancer verify-implementer.sh "$p" "$(entree_arret e5 'Statut : fait')"
[[ $code -eq 2 ]] || echoue "statut fait avec vérification rouge : code $code"

regler "$p" hook_verification avertit
lancer verify-implementer.sh "$p" "$(entree_arret f6)"
[[ $code -eq 0 ]] || echoue "hook_verification=avertit : code $code"
[[ $sortie == "{\"systemMessage\": \"Izanagi : la vérification échoue à l'arrêt de l'implémenteur.\"}" ]] || echoue "hook_verification=avertit : « $sortie »"

sed -i '/^verification=/d' "$p/.izanagi/config.env"
regler "$p" hook_verification bloque
rm -f "$p/temoin"
lancer verify-implementer.sh "$p" "$(entree_arret g7)"
[[ $code -eq 0 && -z $sortie && ! -e $p/temoin ]] || echoue "sans clé verification : code $code"

cp "$p/verif.sh" "$tmp/sans/verif.sh" && echo 1 >"$tmp/sans/code"
lancer verify-implementer.sh "$tmp/sans" "$(entree_arret h8)"
[[ $code -eq 0 && ! -e $tmp/sans/temoin ]] || echoue "hors projet Izanagi : code $code"

echo "hooks.sh : tous les cas passent"
