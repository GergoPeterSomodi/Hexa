## Fair warning for every country, the player included (docs/architecture/moves-build-spec.md R73, D24; MV20): in the season a
## country declares a war, none of its armies may enter that enemy's land (the hexes the enemy owns). It binds the country that
## declared the war (War.a) in the season the war began (War.start_turn), never the country it was declared on. One check for the
## orders (march, Continue and storm: Movement asks `refusal` for the goal), for both walks (MarchLeg's step asks `enemy_on` and
## stops before the hex: &"warned", the points kept, the march standing) and for the preview (`first_barred`). Fog: an order and the
## preview read the owner of a hex only where the country has discovered it (explored or in sight); the walk reads the owner of the
## step it is about to take, as its other stops do (R24). The words name only the country the walker's own country declared war on.
## Pure reads; no luck; integer maths.
class_name FairWarning
extends RefCounted

const OWNS: Array[String] = []
## The stop word of a walk that ends before the closed land: not a halt, the march stays standing and goes on next season.
const WHY := &"warned"
const REFUSAL_TEXT := "You declared war on %s this season. Your armies may not enter its land until next season."
const HINT_TEXT := "Hint: march to your own or unclaimed land, or wait for the next season."
## The words of a walk's stop (WalkNow's `text`; MoveWords makes the toast).
const STOP_TEXT := "you declared war on %s this season"


## The country whose land `hex` is closed to the armies of `tag` this season: its owner, when `tag` declared a live war on it
## this season; else &"".
static func enemy_on(game: Game, tag: StringName, hex: Vector2i) -> StringName:
	if game == null or game.wars.is_empty() or game.map == null or game.state == null or game.map.index_of(hex) < 0:
		return &""
	var owner := Territory.owner_tag(game, hex)
	if owner == &"" or owner == tag:
		return &""
	var war := Wars.war_between(game, tag, owner)
	return owner if war != null and war.a == tag and war.start_turn == game.turn else &""


## The refusal of an order of `tag` whose goal is `hex`: the words and, on a second line, the hint; "" when the order is not
## refused (the land is open, or `tag` has not discovered the hex: then the walk stops at it).
static func refusal(game: Game, tag: StringName, hex: Vector2i) -> String:
	var enemy := _known_enemy_on(game, tag, hex)
	if enemy == &"":
		return ""
	return REFUSAL_TEXT % the_name(game, enemy) + "\n" + HINT_TEXT


## True when `reason` is a refusal of this rule (it ends with the hint).
static func is_refusal(reason: String) -> bool:
	return reason.ends_with(HINT_TEXT)


## The place in `hexes` of the first one `tag` knows to be closed to it this season, or -1 (the preview's read).
static func first_barred(game: Game, tag: StringName, hexes: Array[Vector2i]) -> int:
	for k: int in hexes.size():
		if _known_enemy_on(game, tag, hexes[k]) != &"":
			return k
	return -1


## A country's name for a sentence: "the Duchy of Milan" (its long name, else its name, else its tag).
static func the_name(game: Game, tag: StringName) -> String:
	var def := Countries.def_of(game, tag)
	if def != null and not def.long_name.is_empty():
		return "the " + def.long_name
	return "the " + Movement.country_name(game, tag)


static func _known_enemy_on(game: Game, tag: StringName, hex: Vector2i) -> StringName:
	var enemy := enemy_on(game, tag, hex)
	if enemy == &"" or not (Sight.explored(game, tag, hex) or Sight.sees(game, tag, hex)):
		return &""
	return enemy
