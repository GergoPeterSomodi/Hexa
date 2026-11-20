## The 14 improvement families' ids, names and top levels: the tables the family definitions are checked against.
## They live in the defs layer so FamilyDef and GameDefs need nothing above them; ImproveRules re-exports them.
class_name FamilyIds
extends RefCounted

## Ids run 1 to COUNT - 1; 0 is "none".
const COUNT := 15
## The names are the piece modules' names: the first part of a key of the baked piece index.
const NAMES: Array[String] = [
	"none", "settlements", "castles", "wheat", "hemp", "silk", "dyes", "vineyard", "olives", "grazing", "timber",
	"mines", "quarry", "salt", "harbour",
]
## The highest level of each family (settlements 5, the rest 3).
const TOP_LEVEL: Array[int] = [0, 5, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3]

## The words for a level, per family (docs/design/map/pieces/GUIDE.md section 8); other families use STAGE_WORDS.
## One source for the hex card, the works view and the works' own refusal texts.
const LEVEL_WORDS := {
	"settlements": ["", "hamlet", "village", "town", "walled town", "city"],
	"castles": ["", "watchtower", "castle", "fortress"],
	"harbour": ["", "fishing jetty", "quay", "port"],
}
const STAGE_WORDS: Array[String] = ["wild", "first stage", "second stage", "third stage"]
