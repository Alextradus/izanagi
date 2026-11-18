#!/usr/bin/env bash
# Hook SubagentStop sur izanagi:implementer : lance la vérification du projet (clé
# `verification` de .izanagi/config.env) quand un implémenteur s'arrête.
#
# - Statut « bloqué » ou « question » : pas de vérification, l'implémenteur s'arrête.
# - Vérification verte : l'implémenteur s'arrête.
# - Vérification rouge, `hook_verification=bloque` (défaut) : sort avec 2. La sortie
#   d'erreur devient la consigne suivante de l'implémenteur. Après deux refus pour
#   le même sous-agent, le hook le laisse s'arrêter et avertit l'utilisateur.
# - Vérification rouge, `hook_verification=avertit` : avertit l'utilisateur.

# shellcheck source=../scripts/lib.sh
. "$(dirname "$0")/../scripts/lib.sh"

entree="$(cat)"
hook_enter "$entree"
racine="$(izanagi_root)" || exit 0
config="$racine/.izanagi/config.env"
verification="$(kv_get "$config" verification || true)"
[[ -n $verification ]] || exit 0

# Le statut est dans le dernier message, ou dans la fin du transcript quand
# l'implémenteur a rendu son rapport par un outil. Le message de refus de ce hook
# n'écrit jamais ce motif, pour ne pas se relire lui-même dans le transcript.
statut_sans_verification='Statut : (bloqu|question)'
if grep -qE "$statut_sans_verification" <<<"$entree"; then exit 0; fi
if transcript="$(json_string "$entree" agent_transcript_path)"; then
  transcript="${transcript/#\~/$HOME}"
  if [[ -f $transcript ]] && tail -n 3 "$transcript" | grep -qE "$statut_sans_verification"; then
    exit 0
  fi
fi

identifiant="$(json_string "$entree" agent_id || true)"
identifiant="${identifiant//[^A-Za-z0-9_-]/}"
compteur="${TMPDIR:-/tmp}/izanagi-verify-${identifiant:-inconnu}"

journal="$(mktemp)"
trap 'rm -f "$journal"' EXIT
if (cd "$racine" && bash -c "$verification") >"$journal" 2>&1; then
  rm -f "$compteur"
  exit 0
fi

if [[ $(kv_get "$config" hook_verification || true) == avertit ]]; then
  refus_noter "$racine" verification "vérification rouge"
  printf '%s\n' "{\"systemMessage\": \"Izanagi : la vérification échoue à l'arrêt de l'implémenteur.\"}"
  exit 0
fi

refus=0
[[ -f $compteur ]] && refus="$(cat "$compteur")"
if ((refus >= 2)); then
  rm -f "$compteur"
  refus_noter "$racine" verification "vérification rouge après deux refus"
  printf '%s\n' "{\"systemMessage\": \"Izanagi : la vérification échoue encore après deux refus, l'implémenteur s'arrête.\"}"
  exit 0
fi
echo $((refus + 1)) >"$compteur"
refus_noter "$racine" verification "vérification rouge"
{
  echo "Izanagi : la vérification échoue ($verification). Corrige, puis rends ton rapport. Si tu ne peux pas corriger, rends un rapport au statut bloqué."
  echo "Fin de la sortie de la vérification :"
  tail -n 40 "$journal"
} >&2
exit 2
