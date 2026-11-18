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

skills=(grilling domain-modeling brainstorming planning tdd task-loop review diagnosing merge-conflicts jalon init upgrade status doctor task fix)
commandes=" init jalon grilling upgrade status doctor task fix "

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

for a in implementer reviewer-standards reviewer-spec reviewer-security diagnostician; do
  f="agents/$a.md"
  [[ -f $f ]] || echoue "$f absent"
  [[ $(champ "$f" name) == "$a" ]] || echoue "$f : name différent de « $a »"
  [[ -n $(champ "$f" description) ]] || echoue "$f : description vide"
done

for a in reviewer-standards reviewer-spec reviewer-security; do
  f="agents/$a.md"
  outils="$(champ "$f" tools)"
  [[ -n $outils ]] || echoue "$f : champ tools absent ou hors de la forme sur une ligne"
  for interdit in Edit MultiEdit Write NotebookEdit Bash Agent Task; do
    grep -qw "$interdit" <<<"$outils" && echoue "$f : le relecteur a l'outil $interdit"
  done
done

externes="$(grep -rnoE '(mattpocock-skills|superpowers):[a-z*-]+' skills agents references templates 2>/dev/null |
  grep -vE ':(mattpocock-skills|superpowers):(codebase-design|prototype|research|wizard)$' |
  grep -v '^skills/doctor/' || true)" # doctor nomme les skills en double pour les signaler
[[ -z $externes ]] || echoue "renvoi à un skill externe obligatoire :
$externes"

# Depuis la 0.4, les réglages sont dans .izanagi/config.env. Seuls `jalon`, `init` et
# `upgrade` nomment encore docs/agents/jalon.md, pour renvoyer à la migration.
anciens="$(grep -rnF 'docs/agents/jalon.md' skills agents references templates 2>/dev/null |
  grep -vE '^skills/(jalon|init|upgrade)/' || true)"
[[ -z $anciens ]] || echoue "renvoi à docs/agents/jalon.md, remplacé par .izanagi/config.env :
$anciens"

# Seul scripts/state.sh écrit l'état : `jalon` et `review` doivent le nommer.
for s in jalon review task fix; do
  grep -qF 'scripts/state.sh' "skills/$s/SKILL.md" || echoue "skills/$s ne passe pas par scripts/state.sh"
done
# Niveaux de risque : la table est dans references/risk.md, et seul risk.sh dit
# qu'un chemin est sensible.
[[ -f references/risk.md ]] || echoue "references/risk.md absent"
for s in review planning jalon task fix; do
  [[ -f skills/$s/SKILL.md ]] || continue
  grep -qF 'references/risk.md' "skills/$s/SKILL.md" || echoue "skills/$s ne renvoie pas à references/risk.md"
done
grep -qF 'scripts/risk.sh' skills/review/SKILL.md || echoue "skills/review ne lance pas scripts/risk.sh"
grep -qF '**Risque :**' skills/planning/SKILL.md || echoue "le gabarit de plan n'a pas de ligne Risque"

# La clôture met en index la suppression de l'état, que `state.sh clear` ne fait pas.
grep -qF 'git add -u -- .izanagi' skills/jalon/SKILL.md || echoue "la clôture de jalon ne retire pas state.env de l'index"
# `task` s'arrête au cadrage quand le changement est trop gros, et clôt comme `jalon`.
grep -qF '**Garde-fou.**' skills/task/SKILL.md || echoue "skills/task n'a pas de garde-fou"
grep -qF '/izanagi:jalon' skills/task/SKILL.md || echoue "le garde-fou de task ne propose pas /izanagi:jalon"
grep -qF 'git add -u -- .izanagi' skills/task/SKILL.md || echoue "la clôture de task ne retire pas state.env de l'index"
# `fix` : `jalon` le lance par l'outil Skill, ce que `disable-model-invocation` interdit.
# Lu le 2026-11-13 dans https://code.claude.com/docs/en/skills.md : avec ce champ,
# Claude Code bloque l'appel du skill par le modèle.
[[ -z $(champ skills/fix/SKILL.md disable-model-invocation) ]] || echoue "skills/fix porte disable-model-invocation : jalon ne pourrait pas le lancer"
grep -qF 'izanagi:fix' skills/jalon/SKILL.md || echoue "les retours de test de jalon ne passent pas par izanagi:fix"
grep -qF '**Hors jalon.**' skills/fix/SKILL.md && grep -qF '**Dans un jalon.**' skills/fix/SKILL.md || echoue "skills/fix ne nomme pas ses deux cas à la clôture"
for s in task fix; do
  grep -qF '**Abandon.**' "skills/$s/SKILL.md" || echoue "skills/$s ne dit pas quoi faire d'un flux abandonné"
  grep -qF 'ne la remonte pas' "skills/$s/SKILL.md" || echoue "skills/$s peut monter le patch deux fois"
done
grep -qF 'Dans un flux' skills/review/SKILL.md || echoue "skills/review n'écrit le tour que dans un jalon"
grep -qF 'izanagi:diagnostician' skills/fix/SKILL.md || echoue "skills/fix ne lance pas le diagnostiqueur"
grep -qF 'set correctif=<nom court> --commit' skills/fix/SKILL.md || echoue "skills/fix ne pose pas la clé correctif dans un jalon"
grep -qF 'set correctif= --commit' skills/fix/SKILL.md || echoue "skills/fix ne retire pas la clé correctif"
grep -qF 'git add -u -- .izanagi' skills/fix/SKILL.md || echoue "la clôture de fix ne retire pas state.env de l'index"
# `upgrade` crée sa branche avant la section des migrations, qu'un cadre à jour saute.
awk '/^## 2\. Migrer/ { exit } /crée `task\/izanagi-upgrade`/ { vu = 1 } END { exit !vu }' skills/upgrade/SKILL.md ||
  echoue "upgrade ne crée pas sa branche avant la section Migrer"

# Relecteur sécurité : chaque fiche de type a sa section, et `review` le lance au
# niveau élevé.
for t in references/types/*.md; do
  grep -qx '## Sécurité' "$t" || echoue "$t : pas de section ## Sécurité"
done
grep -qF 'izanagi:reviewer-security' skills/review/SKILL.md || echoue "skills/review ne lance pas izanagi:reviewer-security"
grep -qF 'Standards, Spec et Sécurité' references/risk.md || echoue "references/risk.md : pas de relecteur Sécurité au niveau élevé"

# Chaque renvoi `izanagi:<nom>` désigne un skill ou un sous-agent du plugin.
while IFS= read -r nom; do
  [[ -f skills/$nom/SKILL.md || -f agents/$nom.md ]] || echoue "renvoi izanagi:$nom sans skill ni sous-agent"
done < <(grep -rhoE 'izanagi:[a-z][a-z-]*' skills agents references templates README.md | sed 's/^izanagi://' | sort -u)

[[ -f NOTICE ]] || echoue "NOTICE absent"
for mot in 'Matt Pocock' 'Jesse Vincent' 'MIT'; do
  grep -qF "$mot" NOTICE || echoue "NOTICE ne cite pas « $mot »"
done

echo "skills.sh : tous les cas passent"
