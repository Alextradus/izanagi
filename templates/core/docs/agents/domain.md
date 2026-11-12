# Documentation du domaine

Comment les skills d'ingénierie lisent la documentation du domaine de ce dépôt quand ils explorent le code.

## Avant d'explorer, lire

- **`CONTEXT.md`** à la racine : le glossaire.
- **`{{spec}}`** : la spec fait foi. Lire les sections qui touchent la zone de travail, et les décisions datées qui la concernent. Les décisions sont dans {{decisions}}.

Si `CONTEXT.md` n'existe pas, **continuer sans le dire**. Ne pas signaler son absence et ne pas proposer de le créer d'avance. Le skill `izanagi:domain-modeling` le crée quand un terme est tranché.

## Disposition

Ce dépôt a un seul contexte et pas de `docs/adr/`. Les décisions tiennent lieu d'ADR : chacune est datée dans {{decisions}} et reportée dans la section concernée. Un skill qui veut écrire un ADR écrit donc dans la spec.

```
/
├── CONTEXT.md
└── {{spec}}
```

## Employer le vocabulaire du glossaire

Quand une sortie nomme une notion du domaine (titre d'issue, proposition de refactorisation, hypothèse, nom de test), elle emploie le terme défini dans `CONTEXT.md`. Pas de synonyme que le glossaire écarte.

Si la notion manque au glossaire, c'est un signal : soit tu inventes un langage que le projet n'emploie pas (à reconsidérer), soit il y a un vrai manque (à noter pour `izanagi:domain-modeling`).

## Signaler les contradictions avec la spec

Si une sortie contredit la spec, le dire explicitement au lieu de passer outre :

> _Contredit la spec §4 (…), mais mérite d'être rouvert parce que…_
