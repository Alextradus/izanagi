# Règles générales : Rust

Règles valables pour tout projet Rust, lues avec `docs/standards/rust.md` du projet. Un projet écarte une règle par une ligne `Écarte : R<n>, parce que <raison>` dans son fichier.

## R1. Une bibliothèque rend des erreurs typées

Une fonction publique d'une bibliothèque rend une erreur d'un type que l'appelant peut examiner, pas une `String` ni un `Box<dyn Error>`.

Exemple : `fn lire(chemin: &Path) -> Result<Config, ConfigError>`, où `ConfigError` est une énumération qui implémente `std::error::Error`.

Source : Rust API Guidelines, C-GOOD-ERR (https://rust-lang.github.io/api-guidelines/interoperability.html#c-good-err).

## R2. Une panique ne sert qu'à un invariant prouvé

Hors des tests, `unwrap` et `expect` ne servent que là où le code prouve que la valeur existe. `expect` dit alors l'invariant. Une erreur que l'appelant peut provoquer passe par `Result`.

Exemple : `let premier = liste.first().expect("liste non vide : vérifiée par le constructeur");`

Source : The Rust Programming Language, chapitre 9.3 « To panic! or Not to panic! » (https://doc.rust-lang.org/book/ch09-03-to-panic-or-not-to-panic.html).

## R3. Un identifiant ou une unité a son propre type

Un identifiant, une durée ou une quantité dans une unité porte un type dédié, pour que le compilateur refuse de les mélanger.

Exemple : `struct IdClient(u64);` et `struct IdCommande(u64);` au lieu de deux `u64`.

Source : Rust API Guidelines, C-NEWTYPE (https://rust-lang.github.io/api-guidelines/type-safety.html#c-newtype).

## R4. Un argument booléen devient une énumération

Un paramètre `bool` d'une fonction publique, dont le sens ne se lit pas à l'appel, devient une énumération à deux variantes.

Exemple : `ouvrir(chemin, Mode::Lecture)` plutôt que `ouvrir(chemin, true)`.

Source : Rust API Guidelines, C-CUSTOM-TYPE (https://rust-lang.github.io/api-guidelines/type-safety.html#c-custom-type).

## R5. Une fonction qui ne garde pas la donnée l'emprunte

Une fonction qui lit une donnée sans la conserver prend un emprunt (`&str`, `&[T]`, `&Path`), et laisse l'appelant décider des copies.

Exemple : `fn compter_mots(texte: &str) -> usize` plutôt que `fn compter_mots(texte: String) -> usize`.

Source : Rust API Guidelines, C-CALLER-CONTROL (https://rust-lang.github.io/api-guidelines/flexibility.html#c-caller-control).

## R6. Un type public implémente les traits courants qui ont un sens

Un type public implémente `Debug`, et `Clone`, `PartialEq`, `Eq`, `Hash` ou `Default` quand ils ont un sens pour lui. Un client ne peut pas les ajouter lui-même.

Exemple : `#[derive(Debug, Clone, PartialEq, Eq)] pub struct Version { … }`.

Source : Rust API Guidelines, C-COMMON-TRAITS (https://rust-lang.github.io/api-guidelines/interoperability.html#c-common-traits).

## R7. Une conversion passe par `From` ou `TryFrom`

Une conversion entre deux types s'écrit avec `From`, `TryFrom` ou `AsRef`, pas avec une méthode au nom choisi pour l'occasion.

Exemple : `impl TryFrom<&str> for Couleur` plutôt que `Couleur::depuis_texte(&str)`.

Source : Rust API Guidelines, C-CONV-TRAITS (https://rust-lang.github.io/api-guidelines/interoperability.html#c-conv-traits).

## R8. Un type qui a un invariant garde ses champs privés

Les champs d'une structure dont les valeurs doivent respecter une règle restent privés. Un constructeur vérifie la règle.

Exemple : `pub struct Pourcentage(u8);` avec `pub fn new(v: u8) -> Option<Pourcentage>` qui refuse une valeur au-dessus de 100.

Source : Rust API Guidelines, C-STRUCT-PRIVATE (https://rust-lang.github.io/api-guidelines/future-proofing.html#c-struct-private).

## R9. La documentation dit les erreurs et les paniques

La documentation d'une fonction publique qui rend une erreur ou peut paniquer a une section `# Errors` ou `# Panics` qui dit dans quels cas.

Exemple : `/// # Errors` puis `/// Rend ConfigError::Absent si le fichier n'existe pas.`

Source : Rust API Guidelines, C-FAILURE (https://rust-lang.github.io/api-guidelines/documentation.html#c-failure).

## R10. Chaque bloc `unsafe` dit pourquoi il est sûr

Chaque bloc `unsafe` est précédé d'un commentaire `// SAFETY:` qui nomme l'invariant dont il dépend et dit pourquoi il tient à cet endroit.

Exemple : `// SAFETY: i < self.len(), vérifié deux lignes plus haut.` avant `unsafe { self.get_unchecked(i) }`.

Source : The Rustonomicon, « Working with Unsafe » (https://doc.rust-lang.org/nomicon/working-with-unsafe.html).
