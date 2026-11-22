## The ground of one cover (docs/architecture/m6-build-spec.md sections 4.3 and 5.1; amendment A2): the move points to
## enter it at relief 0 to 3 and the share of its people fed as soldiers a season. Stored one file per cover in
## data/defs/terrain/<key>.tres and listed by GameDefs in cover order. The defs layer cannot read MapTiles, so the keys
## are kept here; the tests check that they equal MapTiles.COVERS and ImproveRules.COVER_WORDS.
@tool
class_name TerrainDef
extends Resource

const KEYS: Array[StringName] = [
	&"farmland", &"grassland", &"woods", &"marsh", &"rock", &"snow", &"tundra", &"sand",
]
const COUNT := 8

## The MapData.cover number, 0 to 7.
@export var id: int = 0
@export var key: StringName = &""
@export var name: String = ""
## Move points to enter at relief 0 to 3.
@export var move: int = 1
## Its people fed as soldiers a season, permille.
@export var forage_permille: int = 0
## The defence of a defender on it, permille (M7 spec 4.6): woods 250, marsh 150, rock 50, snow 250, the rest 0.
@export var defence_permille: int = 0
## Rough ground (woods, marsh, rock, snow): the battle's rough column.
@export var rough := false
## Narrow ground (marsh, snow): the right lane is closed in a battle.
@export var narrow := false


## Problems found, empty when valid: id 0 to 7, the key KEYS gives it, a name, move 1 to 20, forage 0 to 1000,
## defence 0 to 1000.
func validate() -> Array[String]:
	var errors: Array[String] = []
	var label := _label()
	if id < 0 or id >= COUNT:
		errors.append("%s: id %d is outside 0 to %d" % [label, id, COUNT - 1])
		return errors
	if key != KEYS[id]:
		errors.append("%s: key '%s' should be '%s' for id %d" % [label, String(key), String(KEYS[id]), id])
	if name.strip_edges().is_empty():
		errors.append("%s: name is empty" % label)
	if move < 1 or move > 20:
		errors.append("%s: move is %d, expected 1 to 20" % [label, move])
	if forage_permille < 0 or forage_permille > 1000:
		errors.append("%s: forage_permille is %d, expected 0 to 1000" % [label, forage_permille])
	if defence_permille < 0 or defence_permille > 1000:
		errors.append("%s: defence_permille is %d, expected 0 to 1000" % [label, defence_permille])
	return errors


func _label() -> String:
	if key != &"":
		return "terrain %s" % String(key)
	return "terrain %d" % id
