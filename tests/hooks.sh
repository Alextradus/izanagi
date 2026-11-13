#!/usr/bin/env bash
# Teste les trois hooks du plugin : entrée JSON sur l'entrée standard, code de
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
for mot in '"SessionStart"' '"PreToolUse"' '"SubagentStop"' 'session-start.sh' 'guard-push.sh' 'verify-implementer.sh' '^izanagi:implementer$' 'CLAUDE_PLUGIN_ROOT'; do
  grep -qF -- "$mot" "$json" || echoue "hooks.json ne contient pas $mot"
done

# --- json_string ---
[[ $(json_string '{"a":"x","command":"git push \"origin\" main","b":1}' command) == 'git push "origin" main' ]] || echoue "json_string : guillemets échappés"
[[ $(json_string '{"cwd":"C:\\Users\\moi\\projet"}' cwd) == 'C:\Users\moi\projet' ]] || echoue "json_string : barres obliques inverses"
[[ $(json_string '{"command": "a\nb"}' command) == 'a b' ]] || echoue "json_string : saut de ligne"
[[ $(json_string '{"command": "a\nb"}' command '|') == 'a|b' ]] || echoue "json_string : saut de ligne remplacé"
json_string '{"a":"x"}' absente >/dev/null && echoue "json_string : clé absente"

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
[[ $sortie == 'Izanagi : flux task « petit », phase debut.' ]] || echoue "démarrage hors jalon : « $sortie »"

# Le dossier vient de l'entrée JSON quand elle le donne.
lancer session-start.sh "$tmp/vide" "{\"cwd\":\"$p\"}"
[[ $sortie == 'Izanagi : flux task « petit », phase debut.' ]] || echoue "démarrage : cwd de l'entrée ignoré : « $sortie »"

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

regler "$p" hook_push avertit
lancer guard-push.sh "$p" "$(entree_push 'git push origin main')"
[[ $code -eq 0 ]] || echoue "hook_push=avertit : code $code"
[[ $sortie == '{"systemMessage": "Izanagi : push direct sur main."}' ]] || echoue "hook_push=avertit : sortie « $sortie »"

regler "$p" hook_push bloque
regler "$p" branche trunk
git -C "$p" switch -q task/x
refuse "$p" 'git push origin trunk'
passe "$p" 'git push origin main'

passe "$tmp/sans" 'git push origin main'
passe "$tmp/vide" 'git push origin main'

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
done
lancer verify-implementer.sh "$p" "$(entree_arret a1)"
[[ $code -eq 0 ]] || echoue "troisième échec : code $code"
grep -qF '"systemMessage"' <<<"$sortie" || echoue "troisième échec : pas d'avertissement : « $sortie »"
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
