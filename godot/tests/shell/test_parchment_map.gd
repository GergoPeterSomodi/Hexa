## The parchment node (docs/architecture/map-overview-build-spec.md R1 to R7, R12 to R14, R16, R18, R26, R28, D1 to D3,
## D5, D6, D8, section 4; the switch by the zoom: test_parchment_switch.gd): the alpha a mode gets, the fade of the
## picture, the masked data textures, the geometry (made once, the
## same at once and in slices, in the vertex format the shaders read) and the colours. Headless: the shaders are compiled
## by the engine (their uniforms show it) but draw no pixel here. Each planted case (P) feeds a check the fault it is
## there for.
extends GutTest

const GEN := &"GEN"
const SCRIPT_PATH := "res://shell/map/parchment_map.gd"
const SHADERS: Array[String] = ["res://shell/map/parchment_land.gdshader", "res://shell/map/parchment_line.gdshader",
	"res://shell/map/parchment_hatch.gdshader", "res://shell/map/parchment_sea.gdshader"]
const DATA_MODES: Array[int] = [MapModes.Mode.RELIEF, MapModes.Mode.YIELDS, MapModes.Mode.FOOD, MapModes.Mode.SUPPLY]
const SMALL_COLS := 150
const SMALL_ROWS := 70
static var _small: Game = null


## The planted fault of the fade: the alpha put on the node, so each layer fades by itself.
class FadesEachLayer:
	extends ParchmentMap

	func apply_zoom(zoom: float, fit: float) -> float:
		var alpha := super(zoom, fit)
		modulate.a = alpha
		return alpha


## The planted fault of R28: a node that makes its geometry again when land changes owner.
class RebuildsOnOwners:
	extends ParchmentMap

	func owners_changed(hexes: Array[Vector2i]) -> void:
		super(hexes)
		var game := _game
		_map = null
		begin(game)
		step(1.0e9)


func _italy() -> Game:
	return EconomyFixture.game(GEN)


## A made-up map of three chunks by three, with countries (read only: shared by the tests that use it).
func _small_game() -> Game:
	if _small == null:
		var map := FakeMap.build(SMALL_COLS, SMALL_ROWS, 1480)
		var built := FakeScenario.build(map, 8, 1480)
		_small = Game.new_scenario(map, built["defs"] as GameDefs, built["scenario"] as ScenarioDef, 1480)
		_small.act("choose_country", {"tag": _small.countries[0].tag})
	return _small


func _node() -> ParchmentMap:
	var node := ParchmentMap.new()
	add_child_autofree(node)
	return node


## A node with `game` begun and its geometry built at once.
func _built(game: Game) -> ParchmentMap:
	var node := _node()
	node.begin(game)
	node.step(1.0e9)
	return node


## A land hex of north Italy for each of `count` transfers: {hex, to} with `to` another owner than the hex's.
func _transfers(game: Game, count: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in game.map.hex_count():
		var owner := int(game.state.owner[i])
		if game.map.land[i] == 0 or owner == 0:
			continue
		out.append({"hex": game.map.hex_of(i), "to": 1 + owner % game.countries.size()})
		if out.size() == count:
			break
	return out


# ----- the switch by the zoom and the modes --------------------------------------------------------------------------


func test_apply_zoom_gives_the_alpha_of_the_mode_and_shows_it() -> void:
	var node := _built(_italy())
	assert_false(node.visible, "hidden before the first apply_zoom")
	for mode: int in [MapModes.Mode.TERRAIN, MapModes.Mode.OWNER]:
		node.set_mode(mode)
		for row: Array in [[0.04, 0.65, 1.0], [0.65, 0.65, 1.0], [0.9, 0.65, 0.0], [0.04, 0.04, 1.0], [0.5, 0.04, 0.0]]:
			var got := node.apply_zoom(row[0], row[1])
			assert_eq(got, float(row[2]), "mode %d zoom %s fit %s" % [mode, row[0], row[1]])
			assert_eq(node.visible, got > 0.0, "visible follows")
			assert_eq(_fade_problems(node, got), 0, "one picture at alpha %s" % got)
	node.set_mode(MapModes.Mode.GOODS)
	for zoom: float in [0.04, 0.65, 0.7475, 0.9, 2.0]:
		assert_eq(node.apply_zoom(zoom, 0.65), 1.0, "Goods is solid at zoom %s" % zoom)
		assert_true(node.visible)
	for mode: int in DATA_MODES:
		node.set_mode(mode)
		for zoom: float in [0.04, 0.65, 2.0]:
			assert_eq(node.apply_zoom(zoom, 0.65), 0.0, "mode %d has no parchment" % mode)
			assert_false(node.visible)


## What is wrong with how a node shows `alpha`: only the picture fades, as one, and it is a group only in between 0
## and 1. (Headless cannot read the canvas group's mode back: is_fading is the node's own account of it.)
func _fade_problems(node: ParchmentMap, alpha: float) -> int:
	var between := alpha > 0.0 and alpha < 1.0
	var out := int(node.is_fading() != between)
	out += int(not is_equal_approx(node.picture().self_modulate.a, alpha if between else 1.0))
	out += int(node.modulate != Color.WHITE or node.picture().modulate != Color.WHITE)
	for layer_name: StringName in ParchmentMap.LAYERS:
		var layer := node.layer(layer_name)
		out += int(layer.get_parent() != node.picture())
		out += int(layer_name != &"mountains" and layer.modulate != Color.WHITE)
	return out


## A node half way through a cross-fade: settled on the parchment (two steps of no time), then half the time of a
## crossing.
func _half_faded(node: ParchmentMap) -> float:
	node.apply_zoom(0.65, 0.65)
	node.step_fade(0.0)
	node.step_fade(0.0)
	node.apply_zoom(1.0, 0.65)
	node.step_fade(ParchmentSwitch.FADE_SEC * 0.5)
	return node.apply_zoom(1.0, 0.65)


func test_p_a_fade_of_each_layer_is_reported() -> void:
	var node := FadesEachLayer.new()
	add_child_autofree(node)
	node.begin(_italy())
	node.step(1.0e9)
	assert_gt(_fade_problems(node, _half_faded(node)), 0, "P: the alpha on the node")


func test_the_parchment_setting_leaves_goods_mode_alone() -> void:
	var node := _built(_italy())
	node.set_options(true, true, false, false, false)
	for mode: int in [MapModes.Mode.TERRAIN, MapModes.Mode.OWNER]:
		node.set_mode(mode)
		assert_eq(node.apply_zoom(0.3, 0.65), 0.0, "map/parchment off: no parchment in mode %d" % mode)
	node.set_mode(MapModes.Mode.GOODS)
	assert_eq(node.apply_zoom(0.3, 0.65), 1.0, "R18: the goods map still shows")


func test_the_country_pick_shows_no_parchment() -> void:
	var game := EconomyFixture.game()
	var node := _built(game)
	node.set_mode(MapModes.Mode.OWNER)
	assert_eq(node.apply_zoom(0.3, 0.65), 0.0, "picking")
	game.act("choose_country", {"tag": GEN})
	assert_eq(node.apply_zoom(0.3, 0.65), 1.0, "a country chosen")


func test_a_game_without_countries_has_a_parchment() -> void:
	var game := Game.new_game(EconomyFixture.map(), 1480, EconomyFixture.committed())
	var node := _built(game)
	assert_eq(node.apply_zoom(0.3, 0.65), 1.0)
	assert_eq(node.owner_image().get_data(), ParchmentView.owner_bytes(game, &""))


func test_nothing_shows_while_building_or_without_a_game() -> void:
	var node := _node()
	assert_eq(node.apply_zoom(0.3, 0.65), 0.0, "no game")
	assert_false(node.is_building())
	node.begin(_small_game())
	node.set_mode(MapModes.Mode.GOODS)
	assert_true(node.is_building())
	assert_eq(node.apply_zoom(0.3, 0.04), 0.0, "still building")
	node.step(1.0e9)
	assert_false(node.is_building())
	assert_true(node.visible, "shown when the last job is done, with no new apply_zoom")
	node.begin(null)
	assert_false(node.visible)
	assert_null(node.owner_image())
	assert_null(node.chunk_mesh(&"land", Vector2i.ZERO))


# ----- the textures --------------------------------------------------------------------------------------------------


## The undiscovered hexes whose owner byte is not UNKNOWN, plus the hexes whose byte is not the view's.
func _owner_problems(game: Game, bytes: PackedByteArray) -> int:
	var seen := MapModes.discovered_bytes(game, game.player)
	var want := ParchmentView.owner_bytes(game, game.player)
	if bytes.size() != want.size():
		return want.size()
	var out := 0
	for i: int in bytes.size():
		if bytes[i] != want[i] or (seen[i] == 0 and bytes[i] != ParchmentView.UNKNOWN):
			out += 1
	return out


func _thin() -> Game:
	var game := FogFixture.duel_thin()
	game.player = AiFixture.MILAN
	return game


func test_the_textures_hold_the_views_bytes_exactly() -> void:
	for game: Game in [_italy(), _thin()]:
		var node := _built(game)
		assert_eq(node.owner_image().get_format(), Image.FORMAT_R8)
		assert_eq(node.owner_image().get_size(), Vector2i(game.map.cols, game.map.rows))
		assert_eq(node.owner_image().get_data(), ParchmentView.owner_bytes(game, game.player), "owner")
		node.set_mode(MapModes.Mode.GOODS)
		assert_eq(node.goods_image().get_format(), Image.FORMAT_RG8)
		assert_eq(node.goods_image().get_data(), ParchmentView.goods_bytes(game, game.player), "goods")
		assert_eq(_owner_problems(game, node.owner_image().get_data()), 0)


func test_the_shaders_are_given_the_masked_textures_only() -> void:
	var game := _thin()
	var node := _built(game)
	node.set_mode(MapModes.Mode.GOODS)
	assert_gt(node.owner_image().get_data().count(ParchmentView.UNKNOWN), 20, "the thin fixture has unknown hexes")
	var owners: Texture2D = node.layer_material(&"land").get_shader_parameter(&"owners")
	assert_eq(owners.get_image().get_size(), Vector2i(game.map.cols, game.map.rows))
	for layer_name: StringName in [&"hatch", &"district", &"borders", &"coast", &"mountains"]:
		assert_same(node.layer_material(layer_name).get_shader_parameter(&"owners"), owners, "%s" % layer_name)
		assert_eq(node.layer_material(layer_name).get_shader_parameter(&"cols"), game.map.cols)
	var goods := node.goods_image().get_data()
	var seen := MapModes.discovered_bytes(game, game.player)
	var leaks := 0
	for i: int in game.map.hex_count():
		if seen[i] == 0 and (goods[2 * i] != 0 or goods[2 * i + 1] != 0):
			leaks += 1
	assert_eq(leaks, 0, "no goods on an undiscovered hex")


func test_p_raw_owner_bytes_in_the_texture_are_reported() -> void:
	var game := _thin()
	assert_gt(_owner_problems(game, game.state.owner), 20, "P: the raw owner gives the undiscovered hexes away")


func test_goods_texels_are_written_in_goods_mode_only() -> void:
	var game := _italy()
	var node := _built(game)
	var none := PackedByteArray()
	none.resize(2 * game.map.hex_count())
	assert_eq(node.goods_image().get_data(), none, "Terrain: no goods written")
	node.set_mode(MapModes.Mode.GOODS)
	assert_eq(node.goods_image().get_data(), ParchmentView.goods_bytes(game, game.player), "Goods: written at once")


func test_set_good_sets_a_uniform_and_writes_no_texel() -> void:
	var game := _italy()
	var node := _built(game)
	node.set_mode(MapModes.Mode.GOODS)
	var writes := node.texel_writes
	var uploads := node.texture_updates
	var held := node.goods_image().get_data()
	var goods := ParchmentView.goods_list(game)
	assert_gte(goods.size(), 8)
	for good: Dictionary in goods:
		node.set_good(good["id"])
		node.sync(game)
		assert_eq(node.good(), int(good["id"]))
		assert_eq(node.layer_material(&"land").get_shader_parameter(&"good"), int(good["id"]) + 1, "the goods byte")
	assert_eq(node.texel_writes, writes, "no texel written")
	assert_eq(node.texture_updates, uploads, "no upload")
	assert_eq(node.goods_image().get_data(), held)
	node.set_good(-1)
	assert_eq(node.layer_material(&"land").get_shader_parameter(&"good"), 0, "no good")


func test_a_still_game_writes_nothing() -> void:
	var game := _italy()
	var node := _built(game)
	var writes := node.texel_writes
	var uploads := node.texture_updates
	for _frame: int in 5:
		node.sync(game)
	assert_eq(node.texel_writes, writes)
	assert_eq(node.texture_updates, uploads)
	node.sync(_small_game())
	assert_eq(node.texel_writes, writes, "another game than the one begun is ignored")


func test_an_owner_change_writes_the_texels_that_changed() -> void:
	var game := _italy()
	var node := _built(game)
	var one := _transfers(game, 1)[0]
	var before := node.owner_image().get_data()
	var writes := node.texel_writes
	Territory.transfer(game, [one["hex"]] as Array[Vector2i], one["to"])
	node.owners_changed([one["hex"]] as Array[Vector2i])
	var after := node.owner_image().get_data()
	assert_eq(after, ParchmentView.owner_bytes(game, game.player))
	assert_eq(int(after[game.map.index_of(one["hex"])]), int(one["to"]))
	var changed := 0
	for i: int in after.size():
		changed += int(after[i] != before[i])
	assert_gte(changed, 1)
	assert_eq(node.texel_writes - writes, changed, "only the touched texels")
	writes = node.texel_writes
	node.sync(game)
	assert_eq(node.texel_writes, writes, "nothing left for the frame's sync")


func test_a_discovery_reaches_the_textures_by_sync() -> void:
	var game := _thin()
	var node := _built(game)
	var unknown := node.owner_image().get_data().count(ParchmentView.UNKNOWN)
	var given := ParchmentView.owner_bytes(game, game.player)
	var kept := given.duplicate()
	FogFixture.thin(game, AiFixture.MILAN, 6)
	node.sync(game)
	assert_eq(node.owner_image().get_data(), ParchmentView.owner_bytes(game, game.player))
	assert_lt(node.owner_image().get_data().count(ParchmentView.UNKNOWN), unknown, "more is known")
	assert_eq(given, kept, "the view's cached array was not written")


func test_a_new_game_on_the_same_map_keeps_the_geometry() -> void:
	var node := _built(_italy())
	var meshes := _mesh_ids(node)
	var next := EconomyFixture.game(AiFixture.MILAN)
	node.begin(next)
	assert_false(node.is_building())
	assert_eq(node.geometry_builds, 1)
	assert_eq(_mesh_ids(node), meshes)
	assert_eq(node.owner_image().get_data(), ParchmentView.owner_bytes(next, next.player), "the new game's facts")
	node.apply_zoom(0.3, 0.65)
	node.begin(_small_game())
	assert_eq(node.geometry_builds, 2, "another map is built")
	node.step(1.0e9)
	assert_eq(node.owner_image().get_size(), Vector2i(SMALL_COLS, SMALL_ROWS))
	# The zoom is known: the new map has its sea round it with no other apply_zoom.
	var corners := (node.layer(&"sea") as Polygon2D).polygon
	var end := MapTiles.cell_centre(Vector2i(SMALL_COLS - 1, SMALL_ROWS - 1))
	assert_true(node.visible and corners.size() == 4, "the sea is back")
	assert_true(corners.size() == 4 and corners[2].x >= end.x and corners[2].y >= end.y, "round the new map")


# ----- the geometry is made once -------------------------------------------------------------------------------------


func _mesh_ids(node: ParchmentMap) -> Array[int]:
	var out: Array[int] = []
	for layer_name: StringName in ParchmentMap.LAYERS:
		for child: Node in node.layer(layer_name).get_children():
			if child is MeshInstance2D:
				out.append((child as MeshInstance2D).mesh.get_instance_id())
	return out


## Runs 24 owner changes and 8 good switches on a built node; returns how many geometry rules broke (a second build, or
## meshes other than the first ones).
func _rebuild_problems(node: ParchmentMap, game: Game) -> int:
	node.begin(game)
	node.step(1.0e9)
	node.set_mode(MapModes.Mode.GOODS)
	var meshes := _mesh_ids(node)
	var changes := _transfers(game, 24)
	var goods := ParchmentView.goods_list(game)
	assert_eq(changes.size(), 24)
	for change: Dictionary in changes:
		Territory.transfer(game, [change["hex"]] as Array[Vector2i], change["to"])
		node.owners_changed([change["hex"]] as Array[Vector2i])
		node.sync(game)
	for k: int in 8:
		node.set_good(goods[k]["id"])
		node.sync(game)
	node.step(1.0e9)
	return int(node.geometry_builds != 1) + int(_mesh_ids(node) != meshes)


func test_owner_changes_and_good_switches_never_rebuild_geometry() -> void:
	var node := _node()
	assert_eq(_rebuild_problems(node, _italy()), 0)
	assert_eq(node.geometry_builds, 1)


func test_p_a_rebuild_on_owners_changed_is_reported() -> void:
	var node := RebuildsOnOwners.new()
	add_child_autofree(node)
	assert_gt(_rebuild_problems(node, _italy()), 0, "P: a rebuild on owners_changed")


## Every mesh of a node: "layer/chunk" -> its surface arrays.
func _meshes(node: ParchmentMap) -> Dictionary:
	var out := {}
	for layer_name: StringName in ParchmentMap.LAYERS:
		for child: Node in node.layer(layer_name).get_children():
			if not child is MeshInstance2D:
				continue
			var mesh := (child as MeshInstance2D).mesh as ArrayMesh
			out["%s/%s" % [layer_name, child.name]] = mesh.surface_get_arrays(0)
	return out


func test_a_build_at_once_and_a_sliced_build_give_equal_meshes() -> void:
	for game: Game in [_italy(), _small_game()]:
		var at_once := _built(game)
		var sliced := _node()
		sliced.begin(game)
		var slices := 0
		while sliced.is_building() and slices < 100000:
			sliced.step(0.0)  # one job a slice
			slices += 1
		assert_gt(slices, 50, "a job at a time (%d on %s)" % [slices, game.map.id])
		var whole := _meshes(at_once)
		var parts := _meshes(sliced)
		assert_gt(whole.size(), 3)
		assert_eq(parts.keys(), whole.keys(), "the same chunks in the same order")
		var differ := 0
		for key: String in whole:
			if parts.get(key) != whole[key]:
				differ += 1
		assert_eq(differ, 0, "equal arrays")
		assert_eq(sliced.memory_bytes(), at_once.memory_bytes())
	assert_not_null(_built(_small_game()).chunk_mesh(&"land", Vector2i(2, 2)), "three chunks by three")
	assert_null(_built(_small_game()).chunk_mesh(&"land", Vector2i(3, 0)))


## What the shaders read from the meshes, against ParchmentShape over the whole map: every hex's outline once with its
## index, every edge with land on a side once (the rim left out) and every mountain mark.
func test_the_meshes_hold_the_shapes_in_the_vertex_format_the_shaders_read() -> void:
	for game: Game in [_italy(), _small_game()]:
		var node := _built(game)
		var map := game.map
		var edges := ParchmentShape.edges(map, Vector2i(0, map.rows))
		var want_land := {}
		var want_coast := {}
		for k: int in (edges["a"] as PackedInt32Array).size():
			var a: int = edges["a"][k]
			var b: int = edges["b"][k]
			if b < 0:
				continue
			var coast: bool = edges["kind"][k] == ParchmentShape.Edge.COAST
			var three := (edges["points"] as PackedVector2Array).slice(3 * k, 3 * k + 3)
			(want_coast if coast else want_land)[Vector2i(a, b)] = three
		assert_eq(_hex_problems(node, map), 0, "fill")
		assert_eq(_edge_problems(node, &"borders", want_land), 0, "land edges")
		assert_eq(_coast_problems(node, want_coast), 0, "coast segments")
		assert_eq(_hatch_problems(node, want_coast), 0, "hatch")
		assert_eq(_mountain_problems(node, map), 0, "mountains")


func _arrays_of(node: ParchmentMap, layer_name: StringName) -> Array:
	var out := []
	for child: Node in node.layer(layer_name).get_children():
		out.append(((child as MeshInstance2D).mesh as ArrayMesh).surface_get_arrays(0))
	return out


func _hex_problems(node: ParchmentMap, map: MapData) -> int:
	var found := {}
	var wrong := 0
	for arrays: Array in _arrays_of(node, &"land"):
		var points: PackedVector2Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		wrong += int(indices.size() * 13 != points.size() * 36)
		for at: int in range(0, points.size(), 13):
			var i := int(uvs[at].x)
			var hex := map.hex_of(i)
			found[i] = true
			var want := ParchmentShape.polygon(hex)
			want.append(MapTiles.cell_centre(hex))
			wrong += int(points.slice(at, at + 13) != want)
			wrong += int(uvs.slice(at, at + 13).count(Vector2(i, map.land[i])) != 13)
		for k: int in indices.size():
			# Every triangle stays inside its own hex.
			wrong += int(floori(indices[k] / 13.0) != floori(k / 36.0))
	return wrong + absi(found.size() - map.hex_count())


func _edge_problems(node: ParchmentMap, layer_name: StringName, want: Dictionary) -> int:
	var found := {}
	var wrong := 0
	for arrays: Array in _arrays_of(node, layer_name):
		var points: PackedVector2Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		wrong += int((arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() != 2 * points.size())
		for at: int in range(0, points.size(), 6):
			var pair := Vector2i(floori(uvs[at].x / 8.0), int(uvs[at].y))
			found[pair] = true
			if not want.has(pair):
				wrong += 1
				continue
			for code: int in 6:
				wrong += int(uvs[at + code] != Vector2(pair.x * 8 + code, pair.y))
				wrong += int(points[at + code] != (want[pair] as PackedVector2Array)[code % 3])
	return wrong + absi(found.size() - want.size())


## Every coast edge's two segments, a quad each: its two points twice, and in UV the land hex, the code, the course's
## angle and the length.
func _coast_problems(node: ParchmentMap, want: Dictionary) -> int:
	var left := {}  # [land hex, first point, second point] -> true
	for pair: Vector2i in want:
		var three: PackedVector2Array = want[pair]
		left[[pair.x, three[0], three[1]]] = true
		left[[pair.x, three[1], three[2]]] = true
	var wrong := 0
	for arrays: Array in _arrays_of(node, &"coast"):
		var points: PackedVector2Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		wrong += int((arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() * 4 != points.size() * 6)
		for at: int in range(0, points.size(), 4):
			var hex := floori(uvs[at].x / 8.0)
			var from := points[at]
			var to := points[at + 2]
			wrong += int(not left.erase([hex, from, to]))
			wrong += int(points[at + 1] != from or points[at + 3] != to)
			var data := int(uvs[at].y)
			var course := Vector2.from_angle(float(data >> 8) * TAU / ParchmentMap.ANGLE_STEPS)
			var length := float(data & 255) / ParchmentMap.COAST_STEPS
			wrong += int((from + course * length).distance_to(to) > 0.35)
			for code: int in 4:
				wrong += int(uvs[at + code] != Vector2(hex * 8 + code, data))
	return wrong + left.size()


func _hatch_problems(node: ParchmentMap, coast: Dictionary) -> int:
	var want := {}  # the corner an edge starts at -> [its land hex, the corner it ends at]
	for pair: Vector2i in coast:
		want[(coast[pair] as PackedVector2Array)[0]] = [pair.x, (coast[pair] as PackedVector2Array)[2]]
	var count := 0
	var wrong := 0
	var r := ParchmentMap.HATCH_RADIUS
	for arrays: Array in _arrays_of(node, &"hatch"):
		var points: PackedVector2Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		for at: int in range(0, points.size(), 8):
			count += 1
			var from := (points[at + 2] + points[at + 3]) * 0.5
			var to := (points[at + 4] + points[at + 5]) * 0.5
			var key := _near(want, from)
			if key == Vector2.INF:
				wrong += 1
				continue
			wrong += int(to.distance_to(want[key][1]) > 0.01)
			wrong += int(absf(points[at + 2].distance_to(from) - r) > 0.01)
			wrong += int(absf(points[at].distance_to(points[at + 2]) - r) > 0.01)
			wrong += int(uvs[at] != Vector2(r, r) or uvs[at + 3] != Vector2(0, -r) or uvs[at + 7] != Vector2(r, -r))
			for k: int in 8:
				var c := colours[at + k]
				wrong += int((c.r8 << 16 | c.g8 << 8 | c.b8) != int(want[key][0]) or c.a8 != 255)
	return wrong + absi(count - coast.size())


## The key of `by_point` at (or within a hundredth of a px of) `point`, Vector2.INF for none.
func _near(by_point: Dictionary, point: Vector2) -> Vector2:
	for key: Vector2 in by_point:
		if key.distance_to(point) < 0.01:
			return key
	return Vector2.INF


## Every mountain mark as one strip: each point of its zig-zag twice (side 0 and 1), with a mitre that lies half a
## width from both strokes at the corner.
func _mountain_problems(node: ParchmentMap, map: MapData) -> int:
	var marks := ParchmentShape.mountains(map, Vector2i(0, map.rows))
	var hexes: PackedInt32Array = marks["hex"]
	var n := ParchmentShape.MOUNTAIN_POINTS
	assert_gt(hexes.size(), 0, "the map has mountains")
	var found := 0
	var wrong := 0
	for arrays: Array in _arrays_of(node, &"mountains"):
		var points: PackedVector2Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		wrong += int((arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() * 2 * n != points.size() * 6 * (n - 1))
		for at: int in range(0, points.size(), 2 * n):
			found += 1
			var i := floori(uvs[at].x / 8.0)
			var m := hexes.find(i)
			if m < 0:
				wrong += 1
				continue
			for k: int in n:
				var v := at + 2 * k
				var here: Vector2 = marks["points"][m * n + k]
				wrong += int(points[v] != here or points[v + 1] != here)
				wrong += int(uvs[v] != Vector2(i * 8, uvs[v].y) or uvs[v + 1] != Vector2(i * 8 + 1, uvs[v].y))
				var data := int(uvs[v].y)
				var mitre := Vector2.from_angle(float(data >> 8) * TAU / ParchmentMap.ANGLE_STEPS)
				mitre *= float(data & 255) / ParchmentMap.MITRE_STEPS
				for other: int in [k - 1, k + 1]:
					if other < 0 or other >= n:
						continue
					var course: Vector2 = (marks["points"][m * n + maxi(k, other)] - marks["points"][m * n + mini(k, other)])
					var normal := Vector2(-course.y, course.x).normalized()
					wrong += int(absf(mitre.dot(normal) - 1.0) > 0.02)
	return wrong + absi(found - hexes.size())


# ----- the layers, the settings and the colours ----------------------------------------------------------------------


func test_the_layers_stand_in_order_above_the_overlay() -> void:
	var node := _built(_italy())
	assert_eq(node.z_index, 81)
	assert_gt(node.z_index, ModeOverlay.LAYER_Z)
	var names: Array[StringName] = [&"sea", &"hatch", &"land", &"district", &"mountains", &"borders", &"coast"]
	assert_eq(ParchmentMap.LAYERS, names, "R2, bottom to top")
	assert_eq(node.get_child(0), node.picture())
	for k: int in names.size():
		assert_eq(node.picture().get_child(k), node.layer(names[k]), "%s" % names[k])
	assert_eq(node.chunk_mesh(&"district", Vector2i.ZERO), node.chunk_mesh(&"borders", Vector2i.ZERO),
		"one mesh, two passes")
	assert_eq(node.layer_material(&"district").get_shader_parameter(&"kind"), 0)
	assert_eq(node.layer_material(&"borders").get_shader_parameter(&"kind"), 1)
	assert_eq(node.layer_material(&"coast").get_shader_parameter(&"kind"), 2)
	assert_eq(node.layer_material(&"mountains").get_shader_parameter(&"kind"), 3)


## The uniforms a material's shader names that have no value; -1 when the shader names none (it did not compile).
func _uniform_problems(material_of: ShaderMaterial) -> int:
	var uniforms := material_of.shader.get_shader_uniform_list()
	if uniforms.is_empty():
		return -1
	var out := 0
	for uniform: Dictionary in uniforms:
		if material_of.get_shader_parameter(StringName(str(uniform["name"]))) == null:
			out += 1
	return out


func test_every_shader_compiles_and_has_every_uniform_set() -> void:
	var node := _built(_italy())
	node.apply_zoom(0.5, 0.65)
	for layer_name: StringName in ParchmentMap.LAYERS:
		assert_eq(_uniform_problems(node.layer_material(layer_name)), 0, "%s" % layer_name)
	for path: String in SHADERS:
		assert_gt((load(path) as Shader).get_shader_uniform_list().size(), 0, path)


func test_p_an_unset_uniform_is_reported() -> void:
	var bare := ShaderMaterial.new()
	bare.shader = load(SHADERS[0]) as Shader
	assert_gt(_uniform_problems(bare), 0, "P: a material nothing was set on")


func test_the_detail_steps_follow_the_screen_width_of_a_hex() -> void:
	assert_eq(ParchmentMap.town_alpha_at(23.9 / 104.0), 0.0)
	assert_almost_eq(ParchmentMap.town_alpha_at(26.0 / 104.0), 0.5, 0.001)
	assert_eq(ParchmentMap.town_alpha_at(28.0 / 104.0), 1.0)
	assert_false(ParchmentMap.districts_at(39.9 / 104.0))
	assert_true(ParchmentMap.districts_at(40.0 / 104.0))
	assert_true(ParchmentMap.hatch_flat_at(0.23), "12.5 map px are under 3 screen px")
	assert_false(ParchmentMap.hatch_flat_at(0.25))
	var node := _built(_italy())
	node.apply_zoom(0.2, 0.65)
	assert_false(node.layer(&"mountains").visible, "the far view has no mountain marks")
	assert_false(node.layer(&"district").visible)
	assert_true(node.layer_material(&"hatch").get_shader_parameter(&"flat_tint"))
	node.apply_zoom(0.25, 0.65)
	assert_true(node.layer(&"mountains").visible)
	assert_almost_eq(node.layer(&"mountains").modulate.a, 0.5, 0.001)
	assert_false(node.layer(&"district").visible)
	node.apply_zoom(0.65, 0.65)
	assert_true(node.layer(&"district").visible)
	assert_eq(node.layer(&"mountains").modulate.a, 1.0)
	assert_false(node.layer_material(&"hatch").get_shader_parameter(&"flat_tint"))
	for layer_name: StringName in [&"sea", &"district", &"borders", &"coast", &"mountains"]:
		assert_almost_eq(float(node.layer_material(layer_name).get_shader_parameter(&"zoom")), 0.65, 0.0001)


func test_the_sea_covers_the_map_and_a_screen_around_it() -> void:
	var game := _italy()
	var node := _built(game)
	for zoom: float in [0.1, 0.65]:
		node.apply_zoom(zoom, 0.65)
		var screen := node.get_viewport_rect().size / zoom
		var corners := (node.layer(&"sea") as Polygon2D).polygon
		assert_eq(corners.size(), 4)
		var end := MapTiles.cell_centre(Vector2i(game.map.cols - 1, game.map.rows - 1))
		assert_true(corners[0].x <= -screen.x and corners[0].y <= -screen.y, "above and left at %s" % zoom)
		assert_true(corners[2].x >= end.x + screen.x and corners[2].y >= end.y + screen.y, "below and right at %s" % zoom)


func test_the_lines_widths_and_dashes_are_the_tokens() -> void:
	var node := _built(_italy())
	for high: bool in [false, true]:
		node.set_options(true, true, false, high, true)
		var colours := ParchmentTokens.colours(high)
		var coast := node.layer_material(&"coast")
		var borders := node.layer_material(&"borders")
		assert_eq(coast.get_shader_parameter(&"width_px"), 4.0 if high else 3.0)
		assert_eq(borders.get_shader_parameter(&"width_px"), 3.0 if high else 2.0)
		assert_almost_eq(float(node.layer_material(&"district").get_shader_parameter(&"width_px")),
			1.0 if high else 0.8, 0.0001)
		assert_eq(coast.get_shader_parameter(&"ink"), colours[&"coast"])
		assert_eq(borders.get_shader_parameter(&"ink"), colours[&"border"])
		assert_eq(node.layer_material(&"district").get_shader_parameter(&"ink"), colours[&"district"])
		assert_eq(node.layer_material(&"mountains").get_shader_parameter(&"ink"), colours[&"mountain"])
		assert_eq(node.layer_material(&"sea").get_shader_parameter(&"sea_colour"), colours[&"sea"])
		for role: StringName in [&"land", &"unknown", &"goods_1", &"goods_2", &"goods_3"]:
			var uniform := StringName(String(role) + "_colour")
			assert_eq(node.layer_material(&"land").get_shader_parameter(uniform), colours[role], "%s" % role)
		var line: Color = node.layer_material(&"hatch").get_shader_parameter(&"line_colour")
		assert_eq(line.a, 1.0, "opaque over the sea: overlapping strips are no darker")
		assert_true(line.is_equal_approx(colours[&"sea"].blend(colours[&"hatch"])))
	assert_eq(node.layer_material(&"borders").get_shader_parameter(&"dash_px"), 9.0)
	assert_eq(node.layer_material(&"borders").get_shader_parameter(&"gap_px"), 6.0)
	assert_eq(node.layer_material(&"coast").get_shader_parameter(&"gap_px"), 0.0, "a solid coast")


func test_the_options_reach_the_borders_the_tint_and_the_palette() -> void:
	var game := _italy()
	var node := _built(game)
	var land := node.layer_material(&"land")
	assert_eq(land.get_shader_parameter(&"owner_strength"), MapModes.TINT_ALPHA, "Terrain with the tint")
	assert_true(node.layer(&"borders").visible)
	var standard := node.palette_image().get_data()
	node.set_options(false, false, true, false, true)
	assert_eq(land.get_shader_parameter(&"owner_strength"), 0.0, "Terrain without the tint")
	assert_false(node.layer(&"borders").visible, "map/borders off")
	node.apply_zoom(0.65, 0.65)
	assert_false(node.layer(&"borders").visible, "still off after a zoom")
	assert_true(node.layer(&"coast").visible)
	var safe := node.palette_image().get_data()
	assert_ne(safe, standard, "the colour-blind palette")
	var want := MapModes.palette(game, true)
	assert_eq(node.palette_image().get_pixel(1, 0), want[1])
	node.set_mode(MapModes.Mode.OWNER)
	assert_eq(land.get_shader_parameter(&"owner_strength"), 0.46, "Owner mode, whatever the tint setting")
	assert_false(land.get_shader_parameter(&"goods_mode"))
	node.set_mode(MapModes.Mode.GOODS)
	assert_eq(land.get_shader_parameter(&"owner_strength"), 0.0)
	assert_true(land.get_shader_parameter(&"goods_mode"))


## The colour literals in a script's or a shader's text: a Color constructor or constant, a hex string, or a shader
## colour uniform with a value of its own.
func _colour_literals(text: String) -> Array[String]:
	var out: Array[String] = []
	var found := RegEx.create_from_string("\\bColor8?\\s*\\(|\\bColor\\.[A-Z_]{3,}|\\bColor\\.(html|from_)|[\"']#[0-9a-fA-F]{6}"
		+ "|uniform\\s+vec[34][^;]*=|source_color")
	for hit: RegExMatch in found.search_all(text):
		out.append(hit.get_string())
	return out


func test_no_colour_is_written_outside_the_tokens() -> void:
	var paths: Array[String] = [SCRIPT_PATH]
	paths.append_array(SHADERS)
	for path: String in paths:
		var text := FileAccess.get_file_as_string(path)
		assert_gt(text.length(), 200, path)
		assert_eq(_colour_literals(text), [] as Array[String], path)


func test_p_a_colour_literal_is_reported() -> void:
	for line: String in ["var ink := Color(0.1, 0.2, 0.3)", "var c := Color.WHITE", "draw(Color8(1, 2, 3))",
			"const SEA := \"#e8cfae\"", "uniform vec4 ink = vec4(0.2, 0.1, 0.0, 1.0);"]:
		assert_eq(_colour_literals(line).size(), 1, "P: %s" % line)
	assert_eq(_colour_literals("index.fill(Color.hex((land_hex << 8) | 0xFF))"), [] as Array[String], "data, no literal")
