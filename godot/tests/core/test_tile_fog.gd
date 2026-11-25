## The twin test of the tile window (tilewin-build-spec R5, R7, R9; 7.1). On FogFixture.duel_thin (Milan, MLO, thin at radius 2)
## the viewer is Milan and the player is Genoa, so the viewer is not the player. Copy A is the duel. Copy B changes only what the
## fog hides from Milan: the owner, use, level, people and garrison of undiscovered land, a work on it, and the foreign armies
## out of sight (hex, men, order, standing). Every hex must read the same for the viewer in TileView.of, in TileArmy.of(...)
## ["armies"] and in TileBuildings.of (own land only). The sensitivity cases (S) change one read class on a hex the viewer may
## see: the reads must then differ, so the comparison is not vacuous. P: a planted leak of a hidden owner is reported.
extends GutTest

const VIEWER := AiFixture.MILAN
const PLAYER := AiFixture.GENOA
const OTHER := AiFixture.VENICE
## How many undiscovered land hexes copy B changes (the first in index order).
const CHANGED_HEXES := 60


## The duel as the twin test reads it: Milan the viewer, Genoa the player, and one army of Milan's own on its land.
func _game() -> Game:
	var g := FogFixture.duel_thin()
	g.player = PLAYER
	var home := _own_land(g)
	assert_ne(home, Army.NO_HEX, "Milan owns a hex in sight")
	WarFixture.army_at(g, VIEWER, home, 2)
	return g


## The first land hex of the viewer that is in sight; Army.NO_HEX when none.
func _own_land(g: Game) -> Vector2i:
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if g.map.is_land(hex) and Territory.owner_tag(g, hex) == VIEWER and Knowledge.sees(g, VIEWER, hex):
			return hex
	return Army.NO_HEX


## The first land hex other than `hex`; Army.NO_HEX when the map has none.
func _other_land(g: Game, hex: Vector2i) -> Vector2i:
	for i: int in g.map.hex_count():
		var other := g.map.hex_of(i)
		if g.map.is_land(other) and other != hex:
			return other
	return Army.NO_HEX


## The land hexes the viewer has not discovered, in index order.
func _hidden_land(g: Game) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if g.map.is_land(hex) and not Knowledge.discovered(g, VIEWER, hex):
			out.append(hex)
	return out


## The land hexes in light fog (discovered, not in sight), in index order.
func _light_land(g: Game) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if g.map.is_land(hex) and Knowledge.discovered(g, VIEWER, hex) and not Knowledge.sees(g, VIEWER, hex):
			out.append(hex)
	return out


## Makes one work on `hex` for `tag`: a vineyard built in four seasons (a state edit, as the works door would leave it).
func _add_work(g: Game, tag: StringName, hex: Vector2i) -> void:
	var w := Work.new()
	w.id = g.state.next_work_id
	g.state.next_work_id += 1
	w.tag = tag
	w.hex = hex
	w.action = Works.BUILD
	w.family = ImproveRules.VINEYARD
	w.level_to = 1
	w.started_turn = g.turn
	w.seasons = 4
	w.seasons_left = 4
	g.state.works.append(w)


## Copy B's change: what the fog hides from the viewer. Returns how many undiscovered hexes changed.
func _change_hidden(g: Game) -> int:
	var hidden := _hidden_land(g)
	var other := Countries.by_tag(g, OTHER).id
	var n := mini(hidden.size(), CHANGED_HEXES)
	for k: int in n:
		var i := g.map.index_of(hidden[k])
		g.state.owner[i] = other
		g.state.main_use[i] = ImproveRules.WHEAT
		g.state.level[i] = 1
		g.state.people[i] += 900
		g.state.garrison[i] = 400
	if n > 0:
		_add_work(g, OTHER, hidden[0])
	var k := 0
	for army: Army in g.armies:
		if army.tag == VIEWER or Knowledge.sees(g, VIEWER, army.hex) or hidden.is_empty():
			continue
		var dest := hidden[(k * 7 + 3) % hidden.size()]
		k += 1
		army.hex = dest
		army.goal = hidden[(k * 5) % hidden.size()]
		army.order = Army.ORDER_MARCH
		army.standing = Army.STANDING_WITHDRAW
		if not army.units.is_empty():
			army.units[0].men += 77
	_refresh(g)
	return n


## Ends a change of a game: the war cache forgets the control, the sight is refreshed, the version moves on.
func _refresh(g: Game) -> void:
	g.war_cache.forget_control()
	Sight.refresh(g)
	g.version += 1


## What a view shows of one hex to the viewer: the tile, the armies (TileArmy.of's "armies") and the own buildings.
func _reads(g: Game, hex: Vector2i) -> Dictionary:
	return {
		"view": TileView.of(g, VIEWER, hex),
		"armies": TileArmy.of(g, VIEWER, hex)["armies"],
		"buildings": TileBuildings.of(g, VIEWER, hex),
	}


## The hexes of the map where the two games read differently for the viewer.
func _differs(a: Game, b: Game) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i: int in a.map.hex_count():
		var hex := a.map.hex_of(i)
		if _reads(a, hex) != _reads(b, hex):
			out.append(hex)
	return out


## True when both games give the viewer the same discovered and in-sight sets (the fog is the same; only what it hides moved).
func _same_fog(a: Game, b: Game) -> bool:
	for i: int in a.map.hex_count():
		var hex := a.map.hex_of(i)
		if Knowledge.discovered(a, VIEWER, hex) != Knowledge.discovered(b, VIEWER, hex):
			return false
		if Knowledge.sees(a, VIEWER, hex) != Knowledge.sees(b, VIEWER, hex):
			return false
	return true


## How many hexes have another owner in the two games (the change B makes is real).
func _owners_differ(a: Game, b: Game) -> int:
	var n := 0
	for i: int in a.map.hex_count():
		if a.state.owner[i] != b.state.owner[i]:
			n += 1
	return n


# ----- the twin test (R5) -----------------------------------------------------------------------------------------------


func test_what_the_fog_hides_changes_no_read_of_the_viewer() -> void:
	var a := _game()
	var b := _game()
	assert_gt(_hidden_land(a).size(), 0, "the thin duel leaves undiscovered land")
	var changed := _change_hidden(b)
	assert_gt(changed, 0, "copy B changes undiscovered hexes")
	assert_gt(_owners_differ(a, b), 0, "copy B really changes an owner of an undiscovered hex")
	assert_true(_same_fog(a, b), "the fog is the same in both copies: only what it hides differs")
	assert_eq(_differs(a, b), [] as Array[Vector2i], "every hex reads the same for the viewer (R5)")


func test_the_viewer_is_not_the_player() -> void:
	var a := _game()
	var b := _game()
	b.player = VIEWER
	assert_eq(_differs(a, b), [] as Array[Vector2i], "the player changes no view of the viewer (R4)")


func test_p_a_view_that_shows_a_hidden_owner_is_reported() -> void:
	var a := _game()
	var b := _game()
	_change_hidden(b)
	var hex := _hidden_land(a)[0]
	assert_eq(_reads(a, hex), _reads(b, hex), "the honest reads of a hidden hex are equal")
	# A planted view that names the hidden owner (Venice) in its header is the leak: the comparison reports it.
	var leaked := _reads(b, hex).duplicate(true)
	leaked["view"]["header"]["owner"] = {"tag": OTHER, "name": "Venice", "relation": &"foreign"}
	assert_ne(_reads(a, hex), leaked, "P: a hidden owner shown in a view is reported")


# ----- the sensitivity cases (S): each read class moves the views when the viewer sees it ---------------------------


## Changes one read class on a hex the viewer may see (copy C) and counts the hexes whose reads move. 0 when the class is
## not found in the duel.
func _sensitive(kind: StringName) -> int:
	var base := _game()
	var c := _game()
	if not _mutate(c, kind):
		return 0
	_refresh(c)
	return _differs(base, c).size()


## Mutates copy C for one read class; false when the duel has no hex or army of that class to change.
func _mutate(g: Game, kind: StringName) -> bool:
	var viewer_id := Countries.by_tag(g, VIEWER).id
	var light := _light_land(g)
	match kind:
		&"owner":
			for hex: Vector2i in light:
				var owner := Territory.owner_tag(g, hex)
				if owner != &"" and owner != VIEWER:
					g.state.owner[g.map.index_of(hex)] = viewer_id
					return true
		&"use":
			for hex: Vector2i in light:
				if Improve.piece_at(g, hex).is_empty():
					var i := g.map.index_of(hex)
					g.state.main_use[i] = ImproveRules.WHEAT
					g.state.level[i] = 1
					return true
		&"people":
			for hex: Vector2i in light:
				g.state.people[g.map.index_of(hex)] += 1000
				return true
		&"garrison":
			for hex: Vector2i in light:
				var owner := Territory.owner_tag(g, hex)
				if owner != &"" and owner != VIEWER and Occupation.fortress_level(g, hex) > 0:
					g.state.garrison[g.map.index_of(hex)] = 400
					return true
		&"work":
			for hex: Vector2i in light:
				_add_work(g, OTHER, hex)
				return true
		&"men":
			for seen: Dictionary in Knowledge.armies_seen(g, VIEWER):
				var army := seen["army"] as Army
				if army.tag != VIEWER and not army.units.is_empty():
					army.units[0].men += 100
					return true
		&"order":
			for army: Army in g.armies:
				if army.tag == VIEWER:
					army.order = Army.ORDER_MARCH
					army.goal = _other_land(g, army.hex)
					return army.goal != Army.NO_HEX
	return false


func test_s_an_owner_seen_in_light_fog_moves_the_tile() -> void:
	assert_gt(_sensitive(&"owner"), 0, "S: the owner of a light-fog hex is read")


func test_s_a_use_seen_in_light_fog_moves_the_tile() -> void:
	assert_gt(_sensitive(&"use"), 0, "S: the use of a light-fog hex is read")


func test_s_people_seen_in_light_fog_move_the_tile() -> void:
	assert_gt(_sensitive(&"people"), 0, "S: the people of a light-fog hex are read (R6)")


func test_s_a_garrison_of_a_light_fortress_moves_the_tile() -> void:
	assert_gt(_sensitive(&"garrison"), 0, "S: the garrison of a light-fog fortress is read (R6)")


func test_s_a_work_seen_in_light_fog_moves_the_tile() -> void:
	assert_gt(_sensitive(&"work"), 0, "S: the work of a light-fog hex is read (R12)")


func test_s_the_men_of_a_foreign_army_in_sight_move_the_tile() -> void:
	assert_gt(_sensitive(&"men"), 0, "S: the men of a foreign army in sight are read (R7)")


func test_s_the_order_of_an_own_army_moves_the_tile() -> void:
	assert_gt(_sensitive(&"order"), 0, "S: an own army's order is read (own rows only)")
