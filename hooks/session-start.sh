#!/usr/bin/env bash
# Hook SessionStart : écrit l'état du flux de la branche courante sur la sortie
# standard, que Claude Code ajoute au contexte. Ne bloque jamais et sort avec 0.
# Hors d'un projet Izanagi, n'écrit rien.

# shellcheck source=../scripts/lib.sh
. "$(dirname "$0")/../scripts/lib.sh"

entree="$(cat)"
hook_enter "$entree"
racine="$(project_root)" || exit 0

if [[ ! -f $racine/.izanagi/config.env ]]; then
  if [[ -f $racine/docs/agents/jalon.md ]]; then
    echo "Izanagi : ce projet a un cadre d'avant la 0.4. Lance /izanagi:upgrade."
  fi
  exit 0
fi

etat="$racine/.izanagi/state.env"
if flux="$(kv_get "$etat" flux)"; then
  ligne="Izanagi : flux $flux « $(kv_get "$etat" nom || true) », phase $(kv_get "$etat" phase || true)"
  if tranche="$(kv_get "$etat" tranche)"; then ligne+=", tranche $tranche"; fi
  if tour="$(kv_get "$etat" tour)"; then ligne+=", tour de revue $tour"; fi
  ligne+="."
  [[ $flux == jalon ]] && ligne+=" Reprends avec /izanagi:jalon."
  echo "$ligne"
else
  echo "Izanagi : aucun flux en cours sur cette branche."
fi

cadre="$(kv_get "$racine/.izanagi/config.env" izanagi_version || true)"
plugin="$(plugin_version)"
if [[ -n $cadre && -n $plugin ]] && version_lt "$cadre" "$plugin"; then
  echo "Izanagi : le cadre de ce projet est en $cadre, le plugin en $plugin. Lance /izanagi:upgrade."
fi
exit 0
