# Type : mobile

Application pour téléphone ou tablette (React Native, Flutter, Kotlin, Swift).

## Couches de test

- Tests unitaires de la logique (`vitest` ou Jest pour React Native, `flutter test`, JUnit).
- Tests d'interface sur émulateur ou simulateur (Maestro, Detox, `flutter drive`). Ils sont lents : `scripts/check.sh` ne les lance que si l'émulateur est prévu dans la CI.

## Test manuel par défaut

Lancer l'application sur un émulateur ou un appareil branché (`npx expo start`, `flutter run`), à la main.

## Sections de CODING_STANDARDS.md

- **Perte d'état en arrière-plan.** L'application oublie son état quand le système la suspend ou la tue.
- **Fonctionnement hors ligne.** Un écran plante ou reste vide sans réseau.
- **Permission refusée.** Un refus de caméra, de position ou de notification casse le parcours au lieu de le dégrader.

## Prérequis

La toolchain de la pile, le SDK Android (Android Studio) et un émulateur. Pour iOS, un Mac avec Xcode : un poste Windows ou Linux ne peut pas compiler pour iOS.
