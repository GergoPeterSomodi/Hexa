## The Ships tab (tile-window spec R23, D5; TW13): shown only on the player's own port settlements, an empty bordered box
## ("No ships yet" and the later-milestone line), never dimmed. Genoa (own port), Savona (own inland), Asti (foreign),
## and a foreign port found by Improve.is_port. Planted fault: the tab shown on a foreign port.
extends GutTest

const MAP_PATH := "res://data/maps/north_italy.tres"
const DEFS_PATH := "res://data/defs/game_defs.tres"
const GEN := &"GEN"
const ShipsScript := preload("res://shell/panels/tile_tabs/ships_tab.gd")
# The owner's decision 3 (issue 436 round 3): the game's words, no milestone talk.
const HEADING := "No ships in port."
const NOTE := "Shipyards come with the age of sail."


func _italy() -> Game:
	var defs := load(DEFS_PATH) as GameDefs
	var scenario: ScenarioDef = null
	for s: ScenarioDef in defs.scenarios:
		scenario = s
	return Game.new_scenario(load(MAP_PATH) as MapData, defs, scenario, 1480)


func _named(g: Game, place: String) -> Vector2i:
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if str(Improve.place_of(g.map, hex).get("name", "")) == place:
			return hex
	return Vector2i(-1, -1)


## The first foreign hex (own_port false) that is a port, or (-1, -1).
func _foreign_port(g: Game) -> Vector2i:
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if TileView.case_of(g, GEN, hex) == &"foreign" and Improve.is_port(g, hex):
			return hex
	return Vector2i(-1, -1)


func _labels(node: Node, out: Array[Label]) -> Array[Label]:
	if node is Label:
		out.append(node)
	for child: Node in node.get_children():
		_labels(child, out)
	return out


func test_genoa_own_port_shows_the_tab() -> void:
	var g := _italy()
	var v := TileView.of(g, GEN, _named(g, "Genoa"))
	assert_true(ShipsScript.applies(v), "the Ships tab applies on Genoa, the player's own port")


func test_savona_own_inland_hides_the_tab() -> void:
	var g := _italy()
	var v := TileView.of(g, GEN, _named(g, "Savona"))
	assert_false(ShipsScript.applies(v), "no Ships tab on an own inland town")


func test_asti_foreign_hides_the_tab() -> void:
	var g := _italy()
	var v := TileView.of(g, GEN, _named(g, "Asti"))
	assert_false(ShipsScript.applies(v), "no Ships tab on Asti (Savoy's, foreign)")


func test_foreign_port_hides_the_tab() -> void:
	## Planted fault: a foreign port with own_port set would show the tab. The real view must not, and the flag itself
	## must be false on a foreign port.
	var g := _italy()
	var hex := _foreign_port(g)
	if hex == Vector2i(-1, -1):
		pending("no foreign port in the committed map to test on")
		return
	var v := TileView.of(g, GEN, hex)
	assert_false(bool(v["own_port"]), "a foreign port is not the own_port flag")
	assert_false(ShipsScript.applies(v), "no Ships tab on a foreign port")


func test_applies_reads_own_port_only() -> void:
	assert_true(ShipsScript.applies({"own_port": true}), "own_port true applies")
	assert_false(ShipsScript.applies({"own_port": false}), "own_port false does not apply")
	assert_false(ShipsScript.applies({}), "a view without own_port does not apply")


func test_never_dimmed() -> void:
	var g := _italy()
	assert_eq(ShipsScript.dimmed(TileView.of(g, GEN, _named(g, "Genoa"))), "", "the own port is live")
	assert_eq(ShipsScript.dimmed({"own_port": false}), "", "never dimmed elsewhere either")


func test_constants() -> void:
	assert_eq(ShipsScript.ID, &"ships")
	assert_eq(ShipsScript.ORDER, 40)
	assert_eq(ShipsScript.LABEL, "Ships")


func test_fill_writes_the_empty_box() -> void:
	var g := _italy()
	var hex := _named(g, "Genoa")
	var tab := ShipsScript.new()
	add_child_autofree(tab)
	tab.fill(g, GEN, hex, TileView.of(g, GEN, hex))
	var texts: Array[String] = []
	for label: Label in _labels(tab, []):
		texts.append(label.text)
	assert_true(texts.has(HEADING), "the bold heading reads No ships in port")
	assert_true(texts.has(NOTE), "the note says when shipyards come")
	assert_eq(texts.size(), 2, "one box: a heading and one line, no list")
	var box := tab.get_node("EmptyBox") as PanelContainer
	assert_eq(box.theme_type_variation, &"PanelSlot", "the bordered box is the PanelSlot variation")
	assert_eq(tab.get_child_count(), 1, "one box only")


func test_fill_twice_leaves_one_box() -> void:
	var g := _italy()
	var hex := _named(g, "Genoa")
	var tab := ShipsScript.new()
	add_child_autofree(tab)
	tab.fill(g, GEN, hex, {})
	tab.fill(g, GEN, hex, {})
	var boxes := 0
	for child: Node in tab.get_children():
		if child.name == &"EmptyBox":
			boxes += 1
	assert_eq(boxes, 1, "a second fill replaces the box, never adds one")
