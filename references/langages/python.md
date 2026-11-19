# Règles générales : Python

Règles valables pour tout projet Python, lues avec `docs/standards/python.md` du projet. Un projet écarte une règle par une ligne `Écarte : R<n>, parce que <raison>` dans son fichier.

## R1. Une exception attrapée est précise

Un bloc `except` nomme les exceptions qu'il sait traiter. `except Exception` ne sert qu'à une frontière (boucle principale, gestionnaire de requête), où il journalise et relance ou rend une erreur.

Exemple : `except FileNotFoundError:` plutôt que `except Exception: pass`.

Source : PEP 8, Programming Recommendations (https://peps.python.org/pep-0008/#programming-recommendations).

## R2. Une exception relancée garde sa cause

Une exception levée en réponse à une autre la chaîne avec `raise … from`, pour que la trace montre l'origine.

Exemple : `except KeyError as e: raise ConfigError(f"clé {cle} absente") from e`.

Source : Python Tutorial, 8.5 Exception Chaining (https://docs.python.org/3/tutorial/errors.html#exception-chaining).

## R3. Pas de valeur par défaut modifiable

Un argument par défaut n'est jamais une liste, un dictionnaire ou un objet modifiable : la valeur est partagée entre les appels. Le défaut vaut `None`, et la fonction crée la valeur.

Exemple : `def ajouter(x, liste=None):` puis `liste = [] if liste is None else liste`.

Source : Python Tutorial, 4.9.1 Default Argument Values (https://docs.python.org/3/tutorial/controlflow.html#default-argument-values).

## R4. Une fonction rend toujours le même genre de résultat

Si un chemin d'une fonction rend une valeur, tous les chemins rendent une valeur explicite, `return None` compris. Une fonction ne rend pas tantôt une liste, tantôt `False`.

Exemple : `return None` écrit en fin de fonction, plutôt qu'un chemin qui tombe sans `return`.

Source : PEP 8, Programming Recommendations, « Be consistent in return statements » (https://peps.python.org/pep-0008/#programming-recommendations).

## R5. Une ressource s'ouvre avec `with`

Un fichier, un verrou, une connexion ou un dossier temporaire s'ouvre dans un bloc `with`, qui le ferme même en cas d'exception.

Exemple : `with open(chemin, encoding="utf-8") as f:` plutôt que `f = open(chemin)` sans `close` garanti.

Source : Python Tutorial, 7.2 Reading and Writing Files (https://docs.python.org/3/tutorial/inputoutput.html#reading-and-writing-files).

## R6. Les fonctions publiques sont annotées

Les paramètres et le résultat d'une fonction publique portent des annotations de type, que le vérificateur de types du projet contrôle.

Exemple : `def charger(chemin: Path) -> Config:`.

Source : PEP 484, Type Hints (https://peps.python.org/pep-0484/).

## R7. Une donnée structurée est une `dataclass`

Un ensemble de champs qui voyage ensemble devient une `dataclass` (ou un `NamedTuple`), pas un dictionnaire aux clés implicites.

Exemple : `@dataclass(frozen=True) class Point: x: float; y: float` plutôt que `{"x": 1.0, "y": 2.0}`.

Source : documentation de Python, `dataclasses` (https://docs.python.org/3/library/dataclasses.html).

## R8. Un chemin de fichier passe par `pathlib`

Les chemins se construisent et se comparent avec `pathlib.Path`, pas par concaténation de chaînes.

Exemple : `racine / "donnees" / nom` plutôt que `racine + "/donnees/" + nom`.

Source : documentation de Python, `pathlib` (https://docs.python.org/3/library/pathlib.html).

## R9. Une commande externe reçoit une liste d'arguments

`subprocess` reçoit une liste d'arguments, sans `shell=True` dès qu'une partie de la commande vient d'une entrée.

Exemple : `subprocess.run(["git", "log", branche], check=True)` plutôt que `subprocess.run(f"git log {branche}", shell=True)`.

Source : documentation de Python, `subprocess`, Security Considerations (https://docs.python.org/3/library/subprocess.html#security-considerations).

## R10. `pickle` ne lit pas une donnée non maîtrisée

`pickle`, `shelve` et les formats qui exécutent du code au chargement ne lisent que des données produites par le programme lui-même. Une donnée reçue passe par JSON ou un format sans code.

Exemple : `json.loads(corps)` pour une requête, et pas `pickle.loads(corps)`.

Source : documentation de Python, `pickle`, avertissement de sécurité (https://docs.python.org/3/library/pickle.html).
