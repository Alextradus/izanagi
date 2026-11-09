# Type : game

Jeu vidéo (moteur maison, Bevy, Godot, Unity, Phaser).

## Couches de test

- Tests unitaires de la logique de jeu, sans rendu : règles, score, déplacements (`cargo test`, `vitest`, `pytest`).
- Tests de simulation : faire tourner la boucle de jeu sans fenêtre pendant N images, avec une graine aléatoire fixe, et vérifier l'état final.

## Test manuel par défaut

Lancer le jeu (`cargo run`, `npm run dev`) et jouer une partie complète, à la main. Le rendu et la sensation de jeu ne se testent pas par script.

## Sections de CODING_STANDARDS.md

- **Dépendance au taux d'images.** Une vitesse ou une durée varie avec les images par seconde au lieu du temps écoulé.
- **Aléa non reproductible.** Un bug dépend d'un tirage qu'on ne peut pas rejouer, faute de graine.
- **Sauvegarde corrompue.** Un plantage pendant l'écriture ou un changement de format rend la sauvegarde illisible.

## Prérequis

La toolchain de la pile, un GPU ou un pilote logiciel pour le rendu, et l'éditeur du moteur s'il y en a un (Godot, Unity).
