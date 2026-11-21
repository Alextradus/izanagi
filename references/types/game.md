# Type : game

Jeu vidéo (moteur maison, Bevy, Godot, Unity, Phaser).

## Couches de test

- Unitaire : les règles, le score et les déplacements, sans rendu (`cargo test`, `vitest`, `pytest`).
- Intégration : la boucle de jeu sans fenêtre pendant N images, avec une graine aléatoire fixe. Le test vérifie l'état final, avec les mêmes outils.
- Fonctionnelle : sans objet par défaut, le test manuel en tient lieu.

## Test manuel par défaut

Lancer le jeu (`cargo run`, `npm run dev`) et jouer une partie complète, à la main. Le rendu et la sensation de jeu ne se testent pas par script.

## Sections de CODING_STANDARDS.md

- **Dépendance au taux d'images.** Une vitesse ou une durée varie avec les images par seconde au lieu du temps écoulé.
- **Aléa non reproductible.** Un bug dépend d'un tirage qu'on ne peut pas rejouer, faute de graine.
- **Sauvegarde corrompue.** Un plantage pendant l'écriture ou un changement de format rend la sauvegarde illisible.

## Sécurité

Classes de failles que le relecteur sécurité cherche dans le diff, au niveau de risque élevé.

- **Confiance au client.** En multijoueur, le serveur accepte une position, un score ou un inventaire envoyé par le client sans le recalculer.
- **Fichier du joueur chargé sans contrôle.** Une sauvegarde ou un mod fourni par le joueur est désérialisé par un format qui exécute du code, ou écrit hors du dossier du jeu.
- **Script de mod sans bac à sable.** Un script tiers accède au système de fichiers ou au réseau.
- **Secret dans le build.** Une clé de service en ligne est livrée dans les fichiers du jeu.

## Livrable

Ce type n'a pas de livrable par défaut. Le projet écrit dans `release.yml` le job `livrable`, qui construit le jeu qu'il distribue. Tant que le projet ne l'a pas écrit, ce job échoue et la release ne se crée pas.

## Prérequis

La toolchain de la pile, un GPU ou un pilote logiciel pour le rendu, et l'éditeur du moteur s'il y en a un (Godot, Unity).
