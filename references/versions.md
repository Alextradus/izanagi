# Versions pendant un jalon

Le numéro de version distingue une version validée par l'utilisateur d'une version en cours de test. La clé `fichier_version` de `.izanagi/config.env` dit quel fichier porte la version.

- **Entre deux jalons**, seul le patch monte : chaque PR fusionnée sur la branche principale hors jalon passe 0.1.0, 0.1.1, 0.1.2, dans son propre diff. La version mineure reste celle du dernier jalon validé. Les tranches d'un jalon ne touchent pas à la version.
- **À la validation du jalon** par l'utilisateur, après son test manuel : la mineure suivante (0.2.0) monte sur la branche du jalon, dans un commit, avant la fusion. Le tag `v0.2.0` se pose ensuite sur le commit de fusion, et se pousse. La branche principale ne reçoit aucun commit direct. Le jalon suivant repart en 0.2.1.
- **Un patch par branche, relu avant la fusion.** Une branche hors jalon monte le patch une seule fois : si sa version dépasse déjà celle de la branche principale, ne la remonte pas. Juste avant de fusionner, relis la version de la branche principale à jour. Si une autre PR a pris ce patch entre-temps, fusionne la branche principale dans la tienne, monte au patch suivant, regénère le fichier de verrouillage et pousse.
- **Jamais de numéro écrit d'avance.** Un plan dit « le patch suivant celui de la branche principale au moment de la PR », pas « 0.3.1 » : d'autres sessions fusionnent en parallèle. Lis la version sur la branche principale à jour juste avant de monter le patch.
- **Fichier de verrouillage.** Si la pile en a un qui recopie la version (`Cargo.lock`, `package-lock.json`, `uv.lock`), regénère-le et commite-le avec le changement de version.
- **Release.** Chaque tag `vX.Y.Z` donne une release : `release.yml` la construit au push du tag. Le commit de fusion porte déjà la version et la section `## [X.Y.Z]` de `CHANGELOG.md`, commitées avant la fusion, parce que `release.yml` échoue sans elles. Un patch hors jalon n'a de tag que si `izanagi:fix` le publie, sur accord de l'utilisateur. Un patch de `izanagi:task` n'a jamais de tag.
- **La 1.0.0** marque la première version publique. Ne la pose que sur demande de l'utilisateur.
