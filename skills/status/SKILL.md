---
name: status
description: Lister les flux Izanagi ouverts d'un projet (jalons, tâches, correctifs), avec la phase, la tranche et le tour de revue de chacun. À lancer quand l'utilisateur demande où en est le projet ou ce qui est en cours.
---

# Status

Tu montres les flux ouverts du projet courant. Un flux est une branche `jalon/*`, `task/*` ou `fix/*`, et son état est dans le `.izanagi/state.env` de cette branche.

1. Lance `git fetch --prune`, pour voir les branches du dépôt distant telles qu'elles sont. Sans dépôt distant, saute cette étape.
2. Lance :

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/status.sh"
   ```

3. Rends sa sortie telle quelle, dans un bloc de code. Une ligne a cette forme : `<branche>  <flux> « <nom> », phase <phase>, tranche <n>, tour <n>, risque <niveau>  (<date de mise à jour>)`. Une branche de tranche est en retrait sous son jalon, comme la branche `fix/<nom>` d'un correctif né de ce jalon, affichée `correctif « <nom> »`. `*` marque la branche courante. `sans état` désigne une branche de flux sans `state.env` : une branche de cadrage `jalon/<nom>-cadrage`, qui n'en porte jamais, ou un jalon commencé avant la 0.4.
4. Si la branche courante porte un flux, propose en une ligne la commande qui le reprend : `/izanagi:jalon` pour un jalon, `/izanagi:task` pour un flux `task`, `/izanagi:fix` pour un flux `fix` ou un correctif de jalon.

Si le script sort avec `status.sh : pas un projet Izanagi`, dis-le et renvoie à `/izanagi:init`, ou à `/izanagi:upgrade` si le projet a un cadre d'avant la 0.4.
