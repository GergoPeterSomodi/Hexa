## The parchment's fog proofs on what the shell draws (docs/architecture/map-overview-build-spec.md R12 to R14,
## done-when 2; plan PM6; the facts are proved in tests/core/test_parchment_fog.gd). On FogFixture.thin, in Terrain,
## Owner and Goods mode: nothing ParchmentLabels.placed() shows is of or on a hex the viewer has not discovered, owners
## and goods are exact on light fog, and the textures ParchmentMap hands the shaders are masked. Headless runs no
## shader, so the fog rules of the shader sources are pinned by their text.
## Each check returns what is wrong as a list that is asserted once (GUT keeps the text of every passed check). Each
## planted case (P) feeds a check what a fault would leave.
extends ParchmentLabelsCase

## The map px a box is sampled at, in screen px.
const SAMPLE_PX := 4.0
## Screen px a hex of the views: Terrain and Owner (the far view to close in) and Goods (icons from 16 px).
const HEX_PX: Array[float] = [5.0, 20.0, 29.0, 50.0, 104.0]
const GOODS_HEX_PX: Array[float] = [20.0, 50.0, 104.0]
## Where the views look, as shares of the map.
const CENTRES: Array[Vector2] = [Vector2(0.5, 0.5), Vector2(0.3, 0.65)]
## The lines of the shaders that hold the fog's rules: what each shader may draw from a hex the viewer has not
## discovered is nothing (tests/core/test_parchment_fog.gd works the lines out by these).
const SHADER_RULES: Dictionary[String, Array] = {
	"res://shell/map/parchment_line.gdshader": [
		"bool shown = owner != UNKNOWN;",
		"shown = shown && other != UNKNOWN && ((other == owner) == (kind == DISTRICT));",
		"if (!shown) {\n\t\tVERTEX = vec2(0.0);",
	],
	"res://shell/map/parchment_land.gdshader": [
		"fill = unknown_colour;\n\tif (owner != UNKNOWN) {",
	],
	"res://shell/map/parchment_hatch.gdshader": [
		"== UNKNOWN) {\n\t\tVERTEX = vec2(0.0);",
	],
}


## One thin game and what its viewer knows, hex by hex.
class Case:
	extends RefCounted

	var what := ""
	var game: Game = null
	var viewer: StringName = &""
	var known := PackedByteArray()  # 1: discovered
	var light := PackedByteArray()  # 1: discovered and out of sight

	func _init(p_what: String, p_game: Game, p_viewer: StringName) -> void:
		what = p_what
		game = p_game
		viewer = p_viewer
		game.player = viewer
		var n := game.map.hex_count()
		known.resize(n)
		light.resize(n)
		for i: int in n:
			var hex := game.map.hex_of(i)
			known[i] = int(Knowledge.discovered(game, viewer, hex))
			light[i] = int(known[i] == 1 and not Knowledge.sees(game, viewer, hex))


func _cases() -> Array[Case]:
	var italy := EconomyFixture.game(GEN)
	FogFixture.thin(italy, GEN, 2)
	return [Case.new("duel, Milan", FogFixture.duel_thin(), VIEWER), Case.new("north Italy, Genoa", italy, GEN)]


## The views [mode, good, hex px, text size, centre share]: Terrain and Owner at every zoom and both text sizes, Goods
## with every good the map makes, under the fog too.
func _views(c: Case) -> Array[Array]:
	var out: Array[Array] = []
	for mode: int in [MapModes.Mode.TERRAIN, MapModes.Mode.OWNER]:
		for hex_px: float in HEX_PX:
			for text_size: int in [100, 150]:
				for centre: Vector2 in CENTRES:
					out.append([mode, -1, hex_px, text_size, centre])
	for good: Dictionary in ParchmentView.goods_list(c.game):
		if ParchmentView.count_of(c.game, &"", good["id"]) == 0:
			continue
		for hex_px: float in GOODS_HEX_PX:
			for centre: Vector2 in CENTRES:
				out.append([int(MapModes.Mode.GOODS), int(good["id"]), hex_px, 100, centre])
	return out


## Lays the labels out for a view; returns [placed (a copy), the view's map-to-screen transform].
func _lay(c: Case, labels: ParchmentLabels, view: Array) -> Array:
	labels.set_options(view[3], false)
	labels.set_mode(view[0])
	labels.set_good(view[1])
	var map := c.game.map
	var at: Vector2 = Vector2(map.cols * MapTiles.CELL.x, map.rows * MapTiles.ROW) * (view[4] as Vector2)
	var items := _show(labels, c.game, view[2], at)
	return [items.duplicate(true), _view(c.game, view[2], at)]


## The first hex under the item's box (turned, for a country name) that the viewer has not discovered; (-1, -1) none.
## A dot with no name is its hex's own mark: its hex alone counts.
func _reaches_unknown(c: Case, item: Dictionary, inverse: Transform2D) -> Vector2i:
	if item.has("dot") and str(item["text"]) == "":
		return Vector2i(-1, -1)
	var rect: Rect2 = item["rect"]
	var centre := rect.get_center()
	var extent := rect.size
	var angle := 0.0
	if item["kind"] == ParchmentLabels.KIND_COUNTRY:
		centre = item["centre"]
		extent = item["extent"]
		angle = deg_to_rad(float(item["angle"]))
	var along := Vector2.from_angle(angle)
	var across := Vector2(-along.y, along.x)
	var nx := ceili(extent.x / SAMPLE_PX)
	var ny := ceili(extent.y / SAMPLE_PX)
	var screen := Rect2(Vector2.ZERO, SCREEN)
	for x: int in nx + 1:
		for y: int in ny + 1:
			var p := centre + along * (lerpf(-0.499, 0.499, float(x) / nx) * extent.x) \
				+ across * (lerpf(-0.499, 0.499, float(y) / ny) * extent.y)
			if not screen.has_point(p):
				continue
			var i := c.game.map.index_of(MapModes.hex_at_px(inverse * p))
			if i >= 0 and c.known[i] == 0:
				return c.game.map.hex_of(i)
	return Vector2i(-1, -1)


## What of a view's placed items shows the viewer something it may not know, or shows it wrong. `light` counts the
## entries that stand on light fog by kind.
func _item_problems(c: Case, view: Array, laid: Array, light: Dictionary) -> Array[String]:
	var g := c.game
	var state_view := StateView.of(g.state)
	var out: Array[String] = []
	var inverse: Transform2D = (laid[1] as Transform2D).affine_inverse()
	for item: Dictionary in laid[0]:
		var kind: StringName = item["kind"]
		var hex: Vector2i = item["hex"]
		var i := g.map.index_of(hex)
		var where := "%s %s: %s '%s' on %s" % [c.what, view.slice(0, 4), kind, item["text"], hex]
		if i < 0 or c.known[i] == 0:
			out.append("%s, which is undiscovered" % where)
			continue
		var reached := _reaches_unknown(c, item, inverse)
		if reached != Vector2i(-1, -1):
			out.append("%s reaches the undiscovered %s" % [where, reached])
		if c.light[i] == 1:
			light[kind] = int(light.get(kind, 0)) + 1
		if kind == ParchmentLabels.KIND_COUNTRY:
			if Territory.owner_tag(g, hex) != item["tag"] or str(item["text"]) != Countries.def_of(g, item["tag"]).name:
				out.append("%s: not on the land of %s" % [where, item["tag"]])
		elif kind == ParchmentLabels.KIND_ICON:
			var good := Economy.good_of(g, state_view, hex)
			if view[0] != MapModes.Mode.GOODS or good != view[1] or int(item["stage"]) != clampi(g.state.level[i], 1, 3):
				out.append("%s: the district makes good %d at level %d" % [where, good, g.state.level[i]])
		else:
			var country := Countries.by_tag(g, Territory.owner_tag(g, hex))
			var capital := g.countries.any(func(one: Country) -> bool: return one.alive and one.capital == hex)
			var town := g.state.main_use[i] == ImproveRules.SETTLEMENT and g.state.level[i] >= ParchmentView.TOWN_DOT_LEVEL
			var name := str(Improve.place_of(g.map, hex).get("name", ""))
			if name == "" and capital and country != null:
				name = Countries.def_of(g, country.tag).capital_name
			if (not town and not capital) or capital != (kind == ParchmentLabels.KIND_CAPITAL) \
					or (str(item["text"]) != "" and str(item["text"]) != name):
				out.append("%s: no such town there (%s)" % [where, name])
	return out


## Every problem of every view of a case with the labels given.
func _label_problems(c: Case, labels: ParchmentLabels, light: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for view: Array in _views(c):
		out.append_array(_item_problems(c, view, _lay(c, labels, view), light))
	return out


func test_nothing_placed_shows_the_deep_fog_in_terrain_owner_and_goods() -> void:
	for c: Case in _cases():
		var labels := _labels(c.game)
		var light: Dictionary = {}
		assert_eq(_label_problems(c, labels, light), [] as Array[String], c.what)
		for kind: StringName in [&"country", &"capital", &"town", &"icon"]:
			assert_gt(int(light.get(kind, 0)), 0, "%s: a %s on light fog is shown, exact" % [c.what, kind])


func test_p_labels_that_see_all_are_reported() -> void:
	for c: Case in _cases():
		var found := _label_problems(c, _labels(c.game, StaleViewer.new()), {})
		for what: String in ["country", "capital", "town", "icon"]:
			assert_true(found.any(func(line: String) -> bool:
				return line.contains(": %s '" % what) and line.ends_with("which is undiscovered")),
				"%s (P): a %s on an undiscovered hex" % [c.what, what])


## Changes who owns the land and what stands on it on every undiscovered hex (never to the viewer) and drops the view
## cache. Returns how many hexes changed.
func _scramble_dark(c: Case) -> int:
	var g := c.game
	var mine := Countries.by_tag(g, c.viewer).id
	var changed := 0
	for i: int in g.map.hex_count():
		if c.known[i] == 1 or g.map.land[i] == 0:
			continue
		var owner := (int(g.state.owner[i]) + 1 + i % 5) % (g.countries.size() + 1)
		g.state.owner[i] = 0 if owner == mine else owner
		g.state.main_use[i] = (int(g.state.main_use[i]) + 1 + i % 7) % FamilyIds.COUNT
		g.state.level[i] = 1 + (int(g.state.level[i]) + i) % 3
		changed += 1
	g.view_cache.clear()
	g.version += 1
	return changed


## The views whose layout changed when the land under the deep fog did.
func _moved_by_the_fog(c: Case, labels: ParchmentLabels) -> Array[String]:
	var before: Array[String] = []
	for view: Array in _views(c):
		before.append(var_to_str(_lay(c, labels, view)[0]))
	var views := _views(c)  # the goods of the map as it was
	assert_gt(_scramble_dark(c), 20, "%s: land under deep fog to change" % c.what)
	labels.refresh()
	var out: Array[String] = []
	for k: int in views.size():
		if var_to_str(_lay(c, labels, views[k])[0]) != before[k]:
			out.append("%s %s" % [c.what, views[k].slice(0, 4)])
	return out


func test_no_layout_changes_with_the_land_under_deep_fog() -> void:
	for c: Case in _cases():
		assert_eq(_moved_by_the_fog(c, _labels(c.game)), [] as Array[String], c.what)


func test_p_layouts_that_read_the_deep_fog_change_with_it() -> void:
	var c := _cases()[1]
	assert_gt(_moved_by_the_fog(c, _labels(c.game, StaleViewer.new())).size(), 0, "(P) labels that see all")


# ----- the textures --------------------------------------------------------------------------------------------------


## The texels of the node that are not the viewer's facts: the owner UNKNOWN under deep fog and exact elsewhere; the
## goods 0, 0 under deep fog and, in Goods mode, the good and stage of every discovered district.
func _texel_problems(c: Case, node: ParchmentMap) -> Array[String]:
	var g := c.game
	var state_view := StateView.of(g.state)
	var owners := node.owner_image().get_data()
	var goods := node.goods_image().get_data()
	var out: Array[String] = []
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		var owner := ParchmentView.UNKNOWN
		var made := Vector2i.ZERO
		if c.known[i] == 1:
			owner = Territory.owner_id(g, hex) if g.map.land[i] == 1 else 0
			var good := Economy.good_of(g, state_view, hex)
			if good >= 0:
				made = Vector2i(good + 1, clampi(g.state.level[i], 1, 3))
		if owners[i] != owner:
			out.append("%s mode %d: %s owner texel %d, not %d" % [c.what, node.mode(), hex, owners[i], owner])
		var have := Vector2i(goods[2 * i], goods[2 * i + 1])
		var wanted := made if node.mode() == MapModes.Mode.GOODS or c.known[i] == 0 else have
		if have != wanted:
			out.append("%s mode %d: %s goods texel %s, not %s" % [c.what, node.mode(), hex, have, wanted])
	return out


func _built(c: Case) -> ParchmentMap:
	var node := ParchmentMap.new()
	add_child_autofree(node)
	node.begin(c.game)
	node.step(1.0e9)
	return node


func test_the_textures_are_masked_and_exact_in_every_mode() -> void:
	for c: Case in _cases():
		var node := _built(c)
		# Owner comes after Goods and so keeps its goods texels, which must stay clean.
		for mode: int in [MapModes.Mode.TERRAIN, MapModes.Mode.GOODS, MapModes.Mode.OWNER]:
			node.set_mode(mode)
			node.set_good(Economy.GRAIN)
			assert_eq(_texel_problems(c, node), [] as Array[String], "%s mode %d" % [c.what, mode])
		var writes := node.texel_writes
		assert_gt(_scramble_dark(c), 20, c.what)
		node.set_mode(MapModes.Mode.GOODS)
		node.sync(c.game)
		assert_eq(node.texel_writes, writes, "%s: the land under deep fog writes no texel" % c.what)
		assert_eq(_texel_problems(c, node), [] as Array[String], "%s after a change under the fog" % c.what)
		# A change of owner on light fog shows at once.
		var taken: Array[Vector2i] = []
		var mine := Countries.by_tag(c.game, c.viewer).id
		var to := 0
		for i: int in c.game.map.hex_count():
			var owner := int(c.game.state.owner[i])
			if c.light[i] == 1 and owner != 0 and owner != mine:
				if taken.is_empty():
					taken.append(c.game.map.hex_of(i))
					to = 1 + owner % c.game.countries.size()
					to = to if to != mine else 1 + to % c.game.countries.size()
		assert_eq(taken.size(), 1, "%s: a foreign hex under light fog" % c.what)
		assert_eq(Territory.transfer(c.game, taken, to), 1, c.what)
		c.game.version += 1
		node.owners_changed(taken)
		assert_eq(int(node.owner_image().get_data()[c.game.map.index_of(taken[0])]), to, "%s: the new owner" % c.what)


func test_p_raw_texels_are_reported() -> void:
	var c := _cases()[0]
	var node := _built(c)
	c.game.player = &""  # a node that reads as a viewer that sees all
	node.set_mode(MapModes.Mode.GOODS)
	node.begin(c.game)
	var found := _texel_problems(c, node)
	assert_true(found.any(func(line: String) -> bool: return line.contains("owner texel")), "(P) the owners")
	assert_true(found.any(func(line: String) -> bool: return line.contains("goods texel")), "(P) the goods")


# ----- the shaders' rules --------------------------------------------------------------------------------------------


func _source(path: String) -> String:
	return FileAccess.get_file_as_string(path).replace("\r", "")


## The fog rules of SHADER_RULES that a shader's source (path -> text) does not hold.
func _rule_problems(sources: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for path: String in SHADER_RULES:
		for rule: String in SHADER_RULES[path]:
			if not str(sources.get(path, "")).contains(rule):
				out.append("%s lacks: %s" % [path, rule])
	return out


func _sources() -> Dictionary:
	var out: Dictionary = {}
	for path: String in SHADER_RULES:
		out[path] = _source(path)
	return out


func test_the_shaders_hold_the_fog_rules() -> void:
	assert_eq(_rule_problems(_sources()), [] as Array[String])


func test_p_a_border_rule_without_the_other_hex_is_reported() -> void:
	var sources := _sources()
	var path := "res://shell/map/parchment_line.gdshader"
	sources[path] = str(sources[path]).replace("other != UNKNOWN && ", "")
	assert_eq(_rule_problems(sources).size(), 1, "(P) a border drawn into the deep fog")
