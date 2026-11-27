## The words of an order's walk (docs/architecture/moves-build-spec.md R52, R57): the toast that says what an army did when it
## was ordered to march. `of` reads the walk dictionary that WalkNow gives (steps, from, to, stopped, text, points, full,
## standing, battle: spec section 4) and the game after the walk, and gives {text, tone}. One text for each way a walk ends:
## walked, walked with a standing rest, stored, stopped on sight, a battle, a zone of control, and the other stops (a closed pass,
## a way blocked, a shaken army, unmapped land, the border of a country declared war on this season). Fog (R57): only the viewer's own army has words; a country, an army or a place is
## named only where the viewer sees it or has discovered it, and the words of a blocked way and of a zone of control are made here
## from what the viewer sees, never taken from the engine's text. A march through stops (MV19, R72) names the stops still ahead
## (the walk's `via`): "... walks to Cerano (7, 9) on its way to Pavia (10, 9) by Novara (8, 9): 8 of 12 move points left." and
## "... sets out for Pavia (10, 9) by Novara (8, 9) at End turn.", each place named only where the viewer has
## discovered it. Pure core/views/ code: no nodes, no engine calls, no luck.
class_name MoveWords
extends RefCounted

const STORED_TAIL := " at End turn."
const SIGHTED_GENERIC := "an army came into sight"


## {text, tone} of the walk of army `army_id`, as the viewer reads it. Empty text for an army that is not the viewer's (or does
## not exist): another country's order is not the viewer's to read.
static func of(game: Game, viewer: StringName, army_id: int, walk: Dictionary) -> Dictionary:
	var a := Armies.by_id(game, army_id) if game != null and game.map != null else null
	if a == null or (viewer != &"" and a.tag != viewer) or walk.is_empty():
		return {"text": "", "tone": MovePreview.TONE_PLAIN}
	var who := "The " + a.name
	var stopped := StringName(walk.get("stopped", &""))
	var to: Vector2i = walk.get("to", a.hex)
	var at := Words.place(game, to)
	match stopped:
		&"":
			if int(walk.get("steps", 0)) <= 0:
				return _plain("%s stays at %s." % [who, at])
			return _plain("%s walks to %s: %s." % [who, at, _left(walk)])
		&"points":
			return _points(game, viewer, a, who, walk)
		&"mustering", &"no_points":
			return _plain("%s sets out for %s%s%s" % [who, _named(game, viewer, a.goal), _by(game, viewer, walk), STORED_TAIL])
		&"winter":
			return _winter(game, who, walk)
		&"sighted":
			return _warn("%s stops at %s: %s." % [who, at, _sighted(game, viewer, walk)])
		&"battle":
			return _battle(game, viewer, who, walk)
		&"zoc":
			return _warn("%s stops beside %s at %s: its season is over." % [who, _enemy_beside(game, viewer, a, to), at])
		&"blocked":
			return _warn("%s stops at %s: %s." % [who, at, _blocked(game, viewer, a, to)])
		&"shaken":
			return _warn("%s stops at %s: too shaken to attack." % [who, at])
		&"enemy":
			return _warn("%s stops at %s: the way is held against it." % [who, at])
		&"fog":
			return _warn("%s stops at %s: it spends its season finding the way through unmapped land." % [who, at])
		&"warned":
			return _warn("%s stops at the border%s: you declared war this season." % [who, _border(game, a)])
	return _warn("%s stops at %s." % [who, at])


static func _plain(text: String) -> Dictionary:
	return {"text": text, "tone": MovePreview.TONE_PLAIN}


static func _warn(text: String) -> Dictionary:
	return {"text": text, "tone": MovePreview.TONE_WARN}


## "8 of 12 move points left".
static func _left(walk: Dictionary) -> String:
	return "%d of %d move points left" % [int(walk.get("points", 0)), int(walk.get("full", 0))]


## A place as the viewer may name it: its name and coordinates where it has discovered the hex, else the coordinates alone.
static func _named(game: Game, viewer: StringName, hex: Vector2i) -> String:
	if game.map.index_of(hex) >= 0 and Knowledge.discovered(game, viewer, hex):
		return Words.place(game, hex)
	return "(%d, %d)" % [hex.x, hex.y]


## Walked as far as the points reach: with the rest standing, "... walks to Cerano (7, 9); it marches on to Pavia (10, 9) at End
## turn." (the End-turn leg walks it with the next season's points, moves-build-spec.md R22a)
static func _points(game: Game, viewer: StringName, a: Army, who: String, walk: Dictionary) -> Dictionary:
	var head := "%s walks to %s" % [who, Words.place(game, walk.get("to", a.hex))]
	var by := _by(game, viewer, walk)
	if by != "" and bool(walk.get("standing", false)) and a.goal != Army.NO_HEX:
		return _plain("%s on its way to %s%s: %s." % [head, _named(game, viewer, a.goal), by, _left(walk)])
	if bool(walk.get("standing", false)) and a.goal != Army.NO_HEX:
		return _plain("%s; it marches on to %s%s" % [head, _named(game, viewer, a.goal), STORED_TAIL])
	return _plain("%s: %s." % [head, _left(walk)])


## " by Vercelli (6, 9), Novara (8, 9)": the stops the march still passes after the walk (R72); "" for none.
static func _by(game: Game, viewer: StringName, walk: Dictionary) -> String:
	var stops: Variant = walk.get("via", PackedInt32Array())
	if not (stops is PackedInt32Array) or (stops as PackedInt32Array).is_empty():
		return ""
	var names := PackedStringArray()
	for i: int in stops as PackedInt32Array:
		names.append(_named(game, viewer, game.map.hex_of(i)))
	return " by " + ", ".join(names)


## " of the Duchy of Milan": the country whose land the army's next step enters, declared war on this season (the viewer's own
## declaration, so it may be named); "" when the army's route does not tell.
static func _border(game: Game, a: Army) -> String:
	if a.route.is_empty():
		return ""
	var enemy := FairWarning.enemy_on(game, a.tag, game.map.hex_of(a.route[0]))
	return " of " + Words.country_the(game, enemy) if enemy != &"" else ""


## A closed pass: the army waits for spring where it stands (the pass is named by the engine's text, a place of the map).
static func _winter(game: Game, who: String, walk: Dictionary) -> Dictionary:
	var to: Vector2i = walk.get("to", Army.NO_HEX)
	var head := who
	if int(walk.get("steps", 0)) > 0:
		head = "%s walks to %s and" % [who, Words.place(game, to)]
	return _warn("%s waits for spring: the pass is closed." % head)


## The words of a stop on sight. The engine's text names the army that came into sight, which the viewer sees; it is kept only
## when every place in it is a hex the viewer sees, else the general words.
static func _sighted(game: Game, viewer: StringName, walk: Dictionary) -> String:
	var text := str(walk.get("text", ""))
	if text == "":
		return SIGHTED_GENERIC
	for h: Vector2i in MovePreview.named_hexes(text):
		if game.map.index_of(h) >= 0 and not Knowledge.sees(game, viewer, h):
			return SIGHTED_GENERIC
	return text


## "attacks at Novara (8, 9): the Battle of Novara, 1481." The record's name when the viewer may read it, else "a battle".
static func _battle(game: Game, viewer: StringName, who: String, walk: Dictionary) -> Dictionary:
	var to: Vector2i = walk.get("to", Army.NO_HEX)
	var name := ""
	var record := int(walk.get("battle", -1))
	if record >= 0:
		name = str(BattleView.of(game, viewer, record).get("name", ""))
	var tail := "the " + name if name != "" else "a battle"
	return _warn("%s attacks at %s: %s." % [who, Words.place(game, to), tail])


## "an army of the Duchy of Milan" for the first army of a country at war that the viewer sees beside `hex`; else "an enemy".
static func _enemy_beside(game: Game, viewer: StringName, a: Army, hex: Vector2i) -> String:
	for d: int in 6:
		var n := game.map.neighbour(hex, d)
		if game.map.index_of(n) < 0 or not Knowledge.sees(game, viewer, n):
			continue
		for o: Army in Armies.at(game, n):
			if o.tag != a.tag and Wars.at_war(game, a.tag, o.tag):
				return "an army of " + Words.country_the(game, o.tag)
	return "an enemy"


## The words of a way blocked by an army of another country at peace: named, with its place, when the viewer sees it beside the
## army (R24); else the general words, with no country and no place.
static func _blocked(game: Game, viewer: StringName, a: Army, hex: Vector2i) -> String:
	for d: int in 6:
		var n := game.map.neighbour(hex, d)
		if game.map.index_of(n) < 0 or not Knowledge.sees(game, viewer, n):
			continue
		for o: Army in Armies.at(game, n):
			if o.tag != a.tag and not Wars.at_war(game, a.tag, o.tag):
				return "an army of %s is at %s" % [Words.country_the(game, o.tag), Words.place(game, n)]
	return "another country's army stands in the way"
