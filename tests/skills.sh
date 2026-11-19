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

skills=(grilling domain-modeling brainstorming planning tdd task-loop review diagnosing merge-conflicts jalon init upgrade status doctor task fix retro contribuer)
commandes=" init jalon grilling upgrade status doctor task fix retro contribuer "

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
# Couches de test (décision 93) : chaque fiche de type a les trois puces dans sa
# section, et la couche fonctionnelle d'un front emploie Playwright.
for t in references/types/*.md; do
  section="$(awk '/^## / { dedans = ($0 == "## Couches de test") ; next } dedans' "$t")"
  for couche in Unitaire Intégration Fonctionnelle; do
    grep -q "^- $couche : " <<<"$section" || echoue "$t : pas de puce « $couche » dans la section Couches de test"
  done
done
grep -qE '^- Fonctionnelle : .*Playwright' references/types/web-frontend.md || echoue "web-frontend : la couche fonctionnelle ne nomme pas Playwright"
# L'entretien et `init` suivent les couches : plus de clé `couches`, le cinquième
# champ de `composant=`, la vérification complète à la fin de la pose.
grep -qF 'couches=' references/interview.md && echoue "references/interview.md garde la clé couches="
grep -qF '| `couches` |' skills/init/SKILL.md && echoue "skills/init garde la clé couches"
for mot in '<lancement>|<couches>' 'navigateur=oui' 'fonctionnel_projet=' 'test:unitaire' 'test:integration' 'test:fonctionnel' '@vitest/coverage-v8' 'required-features = ["fonctionnel"]' 'tests/unitaires' 'tests/fonctionnels'; do
  grep -qF -- "$mot" references/interview.md || echoue "references/interview.md ne nomme pas « $mot »"
done
for mot in '`navigateur`' '`fonctionnel_projet`' '<lancement>\|<couches>' 'check.sh --host --complet'; do
  grep -qF -- "$mot" skills/init/SKILL.md || echoue "skills/init ne nomme pas « $mot »"
done
grep -qF 'izanagi:reviewer-security' skills/review/SKILL.md || echoue "skills/review ne lance pas izanagi:reviewer-security"
grep -qF 'Standards, Spec et Sécurité' references/risk.md || echoue "references/risk.md : pas de relecteur Sécurité au niveau élevé"

# Règles générales par langage : chaque fichier que l'index nomme existe, et chaque
# règle (`## R<n>. …`) a sa ligne `Source : …`.
[[ -f references/langages/index.md ]] || echoue "references/langages/index.md absent"
fichiers_langage="$(grep -oE '`[a-z-]+\.md`' references/langages/index.md | tr -d '`' | sort -u)"
[[ -n $fichiers_langage ]] || echoue "references/langages/index.md ne nomme aucun fichier"
for f in $fichiers_langage; do
  [[ -f references/langages/$f ]] || echoue "references/langages/$f nommé par l'index et absent"
  regles="$(grep -cE '^## R[0-9]+\. ' "references/langages/$f" || true)"
  sources="$(grep -cE '^Source : ' "references/langages/$f" || true)"
  ((regles >= 8)) || echoue "references/langages/$f : $regles règles, huit au moins attendues"
  ((regles == sources)) || echoue "references/langages/$f : $regles règles pour $sources sources"
done

# Les deux couches de règles par langage : le relecteur Standards et l'implémenteur
# les lisent, et les flux qui les lancent leur passent le chemin de l'index.
for a in reviewer-standards implementer; do
  grep -qF 'docs/standards/' "agents/$a.md" || echoue "agents/$a.md ne lit pas docs/standards/"
  grep -qF 'langages/index.md' "agents/$a.md" || echoue "agents/$a.md ne lit pas l'index des langages"
done
for s in review task-loop task fix; do
  grep -qF 'references/langages/index.md' "skills/$s/SKILL.md" || echoue "skills/$s ne passe pas references/langages/index.md"
done

# Les flux notent au journal les corrections de l'utilisateur, que la rétrospective lit.
for s in task-loop task fix; do
  grep -qF 'Correction : ' "skills/$s/SKILL.md" || echoue "skills/$s ne note pas les corrections au journal"
done

# Rétrospective : `jalon` la lance à la clôture (par l'outil Skill, donc sans
# disable-model-invocation), à la place de `/retro`. `task` et `fix` posent la question.
[[ -z $(champ skills/retro/SKILL.md disable-model-invocation) ]] || echoue "skills/retro porte disable-model-invocation : jalon ne pourrait pas le lancer"
grep -qF 'izanagi:retro' skills/jalon/SKILL.md || echoue "la clôture de jalon ne lance pas izanagi:retro"
grep -qF '/retro' skills/jalon/SKILL.md && echoue "la clôture de jalon propose encore /retro"
awk '/izanagi:retro/ { r = NR } /git rm -f --ignore-unmatch/ { s = NR } END { exit !(r && s && r < s) }' skills/jalon/SKILL.md ||
  echoue "la clôture de jalon supprime le journal avant la rétrospective"
for s in task fix; do
  grep -qF 'une leçon à garder ?' "skills/$s/SKILL.md" || echoue "skills/$s ne pose pas la question de la leçon"
done
for mot in 'scripts/refus.sh' 'Correction : ' 'docs/standards/' '## À proposer au plugin' 'chemins_sensibles' 'gh issue create'; do
  grep -qF -- "$mot" skills/retro/SKILL.md || echoue "skills/retro ne nomme pas « $mot »"
done

# Remontée des règles au plugin : jamais sans l'utilisateur. `contribuer` ne se lance
# que sur sa demande, montre le diff et attend son accord avant de pousser.
[[ $(champ skills/contribuer/SKILL.md disable-model-invocation) == true ]] || echoue "skills/contribuer peut être lancé par le modèle"
for mot in '## À proposer au plugin' 'repository' 'gh repo fork' 'langage/<langage>-' 'gh pr create' '**Accord.**'; do
  grep -qF -- "$mot" skills/contribuer/SKILL.md || echoue "skills/contribuer ne nomme pas « $mot »"
done
awk '/\*\*Accord\.\*\*/ { a = NR } /git push/ { if (!p) p = NR } END { exit !(a && p && a < p) }' skills/contribuer/SKILL.md ||
  echoue "skills/contribuer pousse avant l'étape d'accord"
awk '/\*\*Accord\.\*\*/ { a = NR } /gh repo fork <dépôt>/ { if (!f) f = NR } END { exit !(a && f && a < f) }' skills/contribuer/SKILL.md ||
  echoue "skills/contribuer crée le fork avant l'étape d'accord"
grep -qF '/izanagi:contribuer' skills/jalon/SKILL.md || echoue "la clôture de jalon ne propose pas /izanagi:contribuer"
grep -qF '## À proposer au plugin' skills/upgrade/SKILL.md || echoue "upgrade ne retire pas les règles reprises par le plugin"

# Chaque renvoi `izanagi:<nom>` désigne un skill ou un sous-agent du plugin.
while IFS= read -r nom; do
  [[ -f skills/$nom/SKILL.md || -f agents/$nom.md ]] || echoue "renvoi izanagi:$nom sans skill ni sous-agent"
done < <(grep -rhoE 'izanagi:[a-z][a-z-]*' skills agents references templates README.md | sed 's/^izanagi://' | sort -u)

# Couches de test (0.7) : le plan donne une couche à chaque couture et une ligne
# d'acceptation à la couche fonctionnelle ; `tdd` décrit les couches, la double boucle
# et les propriétés.
for mot in '- couche :' '<interface> (<couche>)' '**Acceptation :**' 'fonctionnelle' 'harness.md'; do
  grep -qF -- "$mot" skills/planning/SKILL.md || echoue "skills/planning ne nomme pas « $mot »"
done
grep -qF 'couche de chaque couture' skills/planning/SKILL.md || echoue "la relecture du plan ne contrôle pas la couche de chaque couture"
grep -qF 'couche à chaque couture' skills/jalon/SKILL.md || echoue "la phase plan de jalon n'exige pas une couche à chaque couture"
for titre in '## Couches' '## Double boucle' '## Propriétés'; do
  grep -qxF -- "$titre" skills/tdd/SKILL.md || echoue "skills/tdd n'a pas la section « $titre »"
done
for mot in 'check.sh --complet' 'proptest' 'fast-check' 'hypothesis' 'tests/fonctionnels' 'premier besoin'; do
  grep -qF -- "$mot" skills/tdd/SKILL.md || echoue "skills/tdd ne nomme pas « $mot »"
done

# Vérification complète et couches dans les flux (0.7).
for s in task-loop task fix; do
  grep -qF -- '--complet' "skills/$s/SKILL.md" || echoue "skills/$s ne nomme pas --complet"
done
grep -qF 'scénario d'"'"'acceptation' skills/task-loop/SKILL.md || echoue "task-loop ne commence pas par le scénario d'acceptation"
grep -qF -- '- couche :' agents/reviewer-spec.md || echoue "reviewer-spec ne lit pas les lignes « - couche : »"
grep -qF 'couche la plus basse' agents/diagnostician.md || echoue "diagnostician ne nomme pas la couche la plus basse"
grep -qF 'couche de ta couture' agents/implementer.md || echoue "implementer ne lit pas la couche de sa couture"

# Mutation dans la revue (0.7).
grep -qF 'mutation.txt' skills/review/SKILL.md || echoue "review ne nomme pas mutation.txt"
grep -qF 'Stryker' skills/review/SKILL.md || echoue "review ne dit pas que Stryker lance toute la configuration Vitest"
for s in jalon task fix; do
  grep -qF 'mutation.sh' "skills/$s/SKILL.md" || echoue "skills/$s ne lance pas mutation.sh"
done
grep -qF 'survivant' agents/reviewer-standards.md || echoue "reviewer-standards ne nomme pas les survivants"
grep -qF 'non muté' agents/reviewer-standards.md || echoue "reviewer-standards ne traite pas les lignes « non muté »"
grep -qF 'mutation' references/risk.md || echoue "risk.md ne place pas la mutation au niveau élevé"
for s in task fix; do
  awk '/scripts\/risk\.sh/ { if (!r) r = NR } /scripts\/mutation\.sh/ { if (!m) m = NR } END { exit !(r && m && r < m) }' "skills/$s/SKILL.md" ||
    echoue "skills/$s ne lance pas risk.sh avant mutation.sh"
done

[[ -f NOTICE ]] || echoue "NOTICE absent"
for mot in 'Matt Pocock' 'Jesse Vincent' 'MIT'; do
  grep -qF "$mot" NOTICE || echoue "NOTICE ne cite pas « $mot »"
done

echo "skills.sh : tous les cas passent"
