# Forme d'un constat

Lue par chaque relecteur de la revue convergente, avec les règles du projet (`docs/CODING_STANDARDS.md`). Elle fixe la forme de ce que le relecteur rend ; le fond vient des règles du projet.

- **Une preuve.** Chaque constat cite un fichier et une ligne, et dit ce qui casse : l'entrée, puis le résultat faux. Une supposition sans emplacement n'est pas un constat.
- **Une étiquette.** **Important** : un bug, ou une règle du projet enfreinte. **Nit** : du style ou du nommage, sans effet sur le comportement ; un Nit ne bloque jamais. **Préexistant** : un défaut que le diff n'a pas introduit, que le code touché expose ou côtoie ; il ne bloque pas la PR et devient une issue.
- **La classe de bug.** Quand un défaut peut se répéter ailleurs (même règle, même motif), nomme-le en tant que classe et cite toutes les occurrences trouvées, pour qu'une seule correction les couvre.
- **Pas de redite.** Sur une re-revue, ne reprends pas un constat déjà traité dans un tour précédent, corrigé ou écarté avec une raison.
- **Le résumé commence par un compte.** Par exemple « 2 Important, 1 Nit, 1 Préexistant ». S'il n'y a rien à corriger, écris « Rien à corriger. »
