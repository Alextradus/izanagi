# Versions pendant un jalon

Le numéro de version distingue une version validée par l'utilisateur d'une version en cours de test. Le fichier qui porte la version est dans `docs/agents/jalon.md` (ligne « Version »).

- **Pendant le jalon**, seul le patch monte : chaque PR fusionnée sur la branche principale passe 0.1.0, 0.1.1, 0.1.2. La version mineure reste celle du dernier jalon validé.
- **À la validation du jalon** par l'utilisateur, après son test manuel : mineure suivante (0.2.0), commit, puis tag `v0.2.0` poussé. Le jalon suivant repart en 0.2.1.
- **Jamais de numéro écrit d'avance.** Un plan dit « le patch suivant celui de la branche principale au moment de la PR », pas « 0.3.1 » : d'autres sessions fusionnent en parallèle. Lis la version sur la branche principale à jour juste avant de monter le patch.
- **Fichier de verrouillage.** Si la pile en a un qui recopie la version (`Cargo.lock` pour Rust), regénère-le et commite-le avec le changement de version.
- **La 1.0.0** marque la première version publique. Ne la pose que sur demande de l'utilisateur.
