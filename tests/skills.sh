#!/usr/bin/env bash
# Contrôle la structure du plugin : skills intégrés, sous-agents, renvois externes, NOTICE.
#
# Champs de frontmatter, lus le 2026-11-12 dans la documentation de Claude Code :
# - `user-invocable: false` retire un skill du menu des commandes ; le modèle peut
#   toujours le charger. Vaut pour les skills d'un plugin.
#   https://code.claude.com/docs/en/skills.md
# - `skills` (liste YAML de noms) précharge des skills dans un sous-agent. La page ne
#   dit pas si un skill de plugin s'écrit `tdd` ou `izanagi:tdd` : à essayer.
#   https://code.claude.com/docs/en/sub-agents.md
# - `tools` (liste séparée par des virgules, ou liste YAML) limite les outils d'un
#   sous-agent. Ce test attend la forme sur une ligne.
#   https://code.claude.com/docs/en/sub-agents.md
set -euo pipefail

racine="$(cd "$(dirname "$0")/.." && pwd)"
cd "$racine"

echoue() { echo "ÉCHEC : $*" >&2; exit 1; }

# Affiche la valeur d'une clé du frontmatter d'un fichier, ou rien si elle manque.
champ() {
  awk -v cle="$2" '
    NR == 1 && $0 != "---" { exit }
    NR > 1 && $0 == "---" { exit }
    index($0, cle ":") == 1 { sub("^" cle ":[ \t]*", ""); print; exit }
  ' "$1" | tr -d '\r'
}

skills=(grilling domain-modeling brainstorming planning tdd task-loop review diagnosing merge-conflicts jalon init)
commandes=" init jalon grilling "

for s in "${skills[@]}"; do
  f="skills/$s/SKILL.md"
  [[ -f $f ]] || echoue "$f absent"
  [[ $(champ "$f" name) == "$s" ]] || echoue "$f : name différent de « $s »"
  [[ -n $(champ "$f" description) ]] || echoue "$f : description vide"
  invocable="$(champ "$f" user-invocable)"
  if [[ $commandes == *" $s "* ]]; then
    [[ $invocable != false ]] || echoue "$f : commande de l'utilisateur masquée"
  else
    [[ $invocable == false ]] || echoue "$f : skill interne sans « user-invocable: false »"
  fi
done

for a in implementer reviewer-standards reviewer-spec diagnostician; do
  f="agents/$a.md"
  [[ -f $f ]] || echoue "$f absent"
  [[ $(champ "$f" name) == "$a" ]] || echoue "$f : name différent de « $a »"
  [[ -n $(champ "$f" description) ]] || echoue "$f : description vide"
done

for a in reviewer-standards reviewer-spec; do
  f="agents/$a.md"
  outils="$(champ "$f" tools)"
  [[ -n $outils ]] || echoue "$f : champ tools absent ou hors de la forme sur une ligne"
  for interdit in Edit Write NotebookEdit Bash; do
    grep -qw "$interdit" <<<"$outils" && echoue "$f : le relecteur a l'outil $interdit"
  done
done

externes="$(grep -rnoE '(mattpocock-skills|superpowers):[a-z*-]+' skills agents references templates 2>/dev/null |
  grep -vE ':(mattpocock-skills|superpowers):(codebase-design|prototype|research|wizard)$' || true)"
[[ -z $externes ]] || echoue "renvoi à un skill externe obligatoire :
$externes"

[[ -f NOTICE ]] || echoue "NOTICE absent"
for mot in 'Matt Pocock' 'Jesse Vincent' 'MIT'; do
  grep -qF "$mot" NOTICE || echoue "NOTICE ne cite pas « $mot »"
done

echo "skills.sh : tous les cas passent"
