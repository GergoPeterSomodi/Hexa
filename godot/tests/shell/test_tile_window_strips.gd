## The building strips wrap (issue 436): a tile of the economy milestone may have 8 or more buildings (the settlement or castle,
## a raw family, the harbour, up to 4 workshop slots), more than one row of tiles. A fixture (synthetic groups of 26 tiles over 3
## strips, laid out through BuildingStrips.fill_groups in the real window) checks that the strips wrap their tiles onto more rows
## and grow: no tile outside its strip, nothing wider than the body, the body's scroll range grows, the window keeps its size,
## and every tile still explains itself (its tooltip).
extends GutTest

const WINDOW := "res://shell/panels/tile_window.tscn"
## A Town tab that lays out the fixture's groups instead of the model's.
const STUB := """extends TileTab
const ID := &"town"
const LABEL := "Town"
const ORDER := 10
const STRIPS := preload("res://shell/panels/tile_tabs/building_strips.gd")
static func applies(view: Dictionary) -> bool:
	return str(view.get("case", "")) != "unexplored"

func fill(game: Game, viewer: StringName, hex: Vector2i, _view: Dictionary) -> void:
	var part := STRIPS.new() as TileTab
	part.name = "Strips"
	add_child(part)
	part.call("fill_groups", game, viewer, hex, Engine.get_meta(&"tile_fixture_groups", []))
"""
const STATES: Array[StringName] = [&"built", &"building", &"ready", &"short", &"locked", &"refused"]


func after_each() -> void:
	if Engine.has_meta(&"tile_fixture_groups"):
		Engine.remove_meta(&"tile_fixture_groups")


func before_each() -> void:
	Bindings.ensure()
	var defs := Session.defs()
	var scenario: ScenarioDef = defs.scenarios[defs.scenarios.size() - 1]
	Session.new_scenario(scenario.id, MapScene.START_SEED, &"GEN")


## Three groups of 12, 8 and 6 synthetic rows in every state.
func _groups() -> Array:
	var out: Array = []
	var n := 0
	for spec: Array in [[&"settlement", "Settlement", 12], [&"land", "Land", 8], [&"harbour", "Harbour", 6]]:
		var rows: Array = []
		for i: int in int(spec[2]):
			var state: StringName = STATES[n % STATES.size()]
			rows.append({"id": "fixture:%d" % n, "group": spec[0], "name": "Fixture building %d" % n, "icon": "settlements",
				"option": {} if state == &"built" or state == &"building" else {"action": &"build", "family": 1},
				"state": state, "state_text": "state line %d" % n, "tone": &"plain", "progress": 0.5, "gain": null,
				"upkeep": null, "cost": {}, "build_seasons": 2, "payback": {}, "hammer": state == &"ready",
				"reason": "" if state == &"ready" else "a fixture reason", "gate": {}})
			n += 1
		out.append({"id": spec[0], "name": spec[1], "slots": {}, "rows": rows})
	return out


func test_strips_wrap_their_tiles_and_grow_while_the_window_keeps_its_size() -> void:
	var sub := SubViewport.new()
	sub.size = Vector2i(1280, 720)
	add_child_autofree(sub)
	var win := (load(WINDOW) as PackedScene).instantiate() as TileWindow
	sub.add_child(win)
	win.theme = KitTheme.load_for(1.0)
	win.position = Vector2(740.0, 64.0)
	var stub := GDScript.new()
	stub.source_code = STUB
	assert_eq(stub.reload(), OK, "the fixture tab parses")
	var own := Vector2i(-1, -1)
	for i: int in Session.game.map.hex_count():
		var hex := Session.game.map.hex_of(i)
		if str(TileView.of(Session.game, &"GEN", hex).get("case", "")) == "own":
			own = hex
			break
	Engine.set_meta(&"tile_fixture_groups", _groups())
	win.use_tabs([stub] as Array[GDScript])
	win.show_hex(own)
	for i: int in 3:
		await get_tree().process_frame
	var tab := win.tab_node()
	var scroll := win.get_node("%Scroll") as ScrollContainer
	var body := win.get_node("%TabBody") as Control
	assert_eq(win.size, Vector2(Tokens.TILE_WINDOW_W, 720.0 - 64.0), "the window keeps its one size: full height under the bar")
	assert_lte(body.size.x, scroll.size.x + 0.5, "no horizontal overflow: the body is no wider than the scroll area")
	assert_gt((tab as Control).size.y, 3.0 * 60.0, "the strips grow taller as their tiles wrap (three strips, more rows)")
	var tiles := tab.find_children("*", "BuildingRow", true, false)
	assert_eq(tiles.size(), 26, "every fixture tile is laid out")
	var rows_seen := {}
	for node: Node in tiles:
		var tile := node as BuildingRow
		var strip := _strip_of(tile)
		assert_not_null(strip, "the tile sits on a strip")
		assert_true(strip.get_global_rect().grow(0.5).encloses(tile.get_global_rect()), "%s inside its strip" % tile.name_text())
		assert_lte(tile.get_global_rect().end.x, body.get_global_rect().end.x + 0.5, "%s within the body" % tile.name_text())
		assert_ne(tile.tooltip_text, "", "%s explains itself" % tile.name_text())
		rows_seen[roundi(tile.get_global_rect().position.y)] = true
	assert_gt(rows_seen.size(), 3, "the strips wrap onto more rows than there are strips")


func _strip_of(tile: Control) -> Control:
	var at := tile.get_parent()
	while at != null:
		if at is PanelContainer and (at as PanelContainer).theme_type_variation == &"PanelTileStrip":
			return at as Control
		at = at.get_parent()
	return null
