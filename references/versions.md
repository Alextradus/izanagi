# Versions pendant un jalon

Le numéro de version distingue une version validée par l'utilisateur d'une version en cours de test. La clé `fichier_version` de `.izanagi/config.env` dit quel fichier porte la version.

- **Entre deux jalons**, seul le patch monte : chaque PR fusionnée sur la branche principale hors jalon passe 0.1.0, 0.1.1, 0.1.2, dans son propre diff. La version mineure reste celle du dernier jalon validé. Les tranches d'un jalon ne touchent pas à la version.
- **À la validation du jalon** par l'utilisateur, après son test manuel : la mineure suivante (0.2.0) monte sur la branche du jalon, dans un commit, avant la fusion. Le tag `v0.2.0` se pose ensuite sur le commit de fusion, et se pousse. La branche principale ne reçoit aucun commit direct. Le jalon suivant repart en 0.2.1.
- **Jamais de numéro écrit d'avance.** Un plan dit « le patch suivant celui de la branche principale au moment de la PR », pas « 0.3.1 » : d'autres sessions fusionnent en parallèle. Lis la version sur la branche principale à jour juste avant de monter le patch.
- **Fichier de verrouillage.** Si la pile en a un qui recopie la version (`Cargo.lock`, `package-lock.json`, `uv.lock`), regénère-le et commite-le avec le changement de version.
- **La 1.0.0** marque la première version publique. Ne la pose que sur demande de l'utilisateur.
