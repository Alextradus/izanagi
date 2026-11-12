#!/usr/bin/env bash
# Contrôle la structure du plugin : skills intégrés, sous-agents, renvois externes, NOTICE.
#
# Champs de frontmatter, lus le 2026-11-12 dans la documentation de Claude Code :
# - `user-invocable: false` retire un skill du menu des commandes ; le modèle peut
#   toujours le charger. Vaut pour les skills d'un plugin.
#   https://code.claude.com/docs/en/skills.md
# - `skills` (liste YAML de noms) précharge des skills dans un sous-agent.
#   https://code.claude.com/docs/en/sub-agents.md
#   Essayé le 2026-11-12 avec Claude Code 2.1.321 et `--plugin-dir` : le nom nu (`tdd`)
#   charge le skill du plugin, et les sous-agents s'appellent `izanagi:<nom>`.
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

# Un dossier de skills/ hors de la liste n'est contrôlé nulle part.
for d in skills/*/; do
  s="$(basename "$d")"
  [[ " ${skills[*]} " == *" $s "* ]] || echoue "skills/$s absent de la liste de ce test"
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
  for interdit in Edit MultiEdit Write NotebookEdit Bash Agent Task; do
    grep -qw "$interdit" <<<"$outils" && echoue "$f : le relecteur a l'outil $interdit"
  done
done

externes="$(grep -rnoE '(mattpocock-skills|superpowers):[a-z*-]+' skills agents references templates 2>/dev/null |
  grep -vE ':(mattpocock-skills|superpowers):(codebase-design|prototype|research|wizard)$' || true)"
[[ -z $externes ]] || echoue "renvoi à un skill externe obligatoire :
$externes"

# Depuis la 0.4, les réglages sont dans .izanagi/config.env. Seuls `jalon`, `init` et
# `upgrade` nomment encore docs/agents/jalon.md, pour renvoyer à la migration.
anciens="$(grep -rnF 'docs/agents/jalon.md' skills agents references templates 2>/dev/null |
  grep -vE '^skills/(jalon|init|upgrade)/' || true)"
[[ -z $anciens ]] || echoue "renvoi à docs/agents/jalon.md, remplacé par .izanagi/config.env :
$anciens"

# Seul scripts/state.sh écrit l'état : aucun skill ne nomme state.env comme fichier à écrire.
for s in jalon review; do
  grep -qF 'scripts/state.sh' "skills/$s/SKILL.md" || echoue "skills/$s ne passe pas par scripts/state.sh"
done

# Chaque renvoi `izanagi:<nom>` désigne un skill ou un sous-agent du plugin.
while IFS= read -r nom; do
  [[ -f skills/$nom/SKILL.md || -f agents/$nom.md ]] || echoue "renvoi izanagi:$nom sans skill ni sous-agent"
done < <(grep -rhoE 'izanagi:[a-z][a-z-]*' skills agents references templates README.md | sed 's/^izanagi://' | sort -u |
  grep -vx 'upgrade') # `upgrade` arrive à la tâche 7 du plan 0.4 : retirer ce filtre avec elle.

[[ -f NOTICE ]] || echoue "NOTICE absent"
for mot in 'Matt Pocock' 'Jesse Vincent' 'MIT'; do
  grep -qF "$mot" NOTICE || echoue "NOTICE ne cite pas « $mot »"
done

echo "skills.sh : tous les cas passent"
