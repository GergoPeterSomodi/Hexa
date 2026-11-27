## The parchment map under the names (docs/architecture/map-overview-build-spec.md R1 to R7, R12 to R14, R16, R18, R26,
## R28, D1 to D3, D5, D6, D8): the sea, the hatched water, the land, the district lines, the mountain marks, the borders
## and the coast. It holds no rules. The geometry is ParchmentShape's, made once a map into one mesh a chunk (CHUNK
## hexes) with the hex index in a vertex attribute. What changes is one texel a hex, masked by the fog in core: the known
## owner (ParchmentView.owner_bytes) and the goods (ParchmentView.goods_bytes). The shaders decide what to draw from
## those texels, and a change never rebuilds geometry. Land out of sight looks as land in sight (R14): the parchment is
## given no sight and lays no veil.
##
## The scene drives it: begin(game), step(ms) a frame while is_building(), sync(game) a frame, owners_changed(hexes),
## set_mode, set_good, set_options, step_fade(delta) a frame, and apply_zoom(zoom, fit), which returns how solid the
## parchment is (0 while it is being built or during the country pick). Which zooms show it is ParchmentSwitch's (D2):
## at rest it is solid or hidden. While it cross-fades the layers are drawn into one picture (the CanvasGroup "Picture")
## that fades as a whole; solid or hidden, they are drawn straight to the screen. The node also applies the
## two detail steps of R9 that are geometry: the mountain marks from TOWN_VIEW_PX screen px a hex, the district lines
## from DISTRICT_VIEW_PX.
##
## Colours are ParchmentTokens' and reach the shaders as uniforms; every shader takes only the alpha of a modulate. The
## hatch's vertex colour holds a hex index, so nothing above this node may modulate its red, green or blue.
class_name ParchmentMap
extends Node2D

const LAYER_Z := 81
const CHUNK := Vector2i(64, 32)
## R9, in screen px a hex (zoom x the cell's width): the town view fades in over TOWN_FADE_PX from TOWN_VIEW_PX.
const TOWN_VIEW_PX := 24.0
const TOWN_FADE_PX := 4.0
const DISTRICT_VIEW_PX := 40.0
## The hatched water, in map px (the mockup's pattern at the 104 px hex): the band's half width (half a hex), the space
## from line to line, a line's width, a wave's length and rise. Under HATCH_MIN_PX screen px of space it is a flat tint.
const HATCH_RADIUS := 52.0
const HATCH_SPACING := 12.5
const HATCH_WIDTH := 2.7
const HATCH_WAVE := 82.5
const HATCH_RISE := 2.0
const HATCH_MIN_PX := 3.0
## The sea's speckle in map px: one dot a cell of SPECKLE_CELL, of SPECKLE_RADIUS at most.
const SPECKLE_CELL := 64.0
const SPECKLE_RADIUS := 2.5
## The screen the sea reaches past the map by, while the node is in no window.
const SEA_SCREEN := Vector2(3840.0, 2160.0)
## Screen px of the district lines' dots and of the mountain marks' ink (the other lines' widths are tokens).
const DISTRICT_DOT_PX := 1.0
const DISTRICT_GAP_PX := 5.0
const MOUNTAIN_PX := 1.5
## An edge's length from corner to corner, about, in map px: where the dash pattern of the line shader starts.
const EDGE_LENGTH := 55.0
## How far past its mesh a line may be drawn, in map px (its screen width at the farthest zoom).
const LINE_BOUNDS_PX := 96.0
## How the coast's and the mountain marks' UV.y packs an angle and a byte (packed_uv): ANGLE_STEPS a turn; the byte is
## the segment's length (COAST_STEPS a map px) or the mitre's reach (MITRE_STEPS a half width).
const ANGLE_STEPS := 4096
const COAST_STEPS := 2.0
const MITRE_STEPS := 64.0

const FILL_SHADER := preload("res://shell/map/parchment_land.gdshader")
const LINE_SHADER := preload("res://shell/map/parchment_line.gdshader")
const HATCH_SHADER := preload("res://shell/map/parchment_hatch.gdshader")
const SEA_SHADER := preload("res://shell/map/parchment_sea.gdshader")

## The layers, bottom to top (R2).
const LAYERS: Array[StringName] = [&"sea", &"hatch", &"land", &"district", &"mountains", &"borders", &"coast"]
## The line layers and the line shader's `kind` for each.
const LINE_KINDS: Dictionary[StringName, int] = {&"district": 0, &"borders": 1, &"coast": 2, &"mountains": 3}

## The meshes of a chunk.
enum Part { FILL, LINES, COAST, HATCH, MOUNTAINS }
## The layers that draw each Part: the district lines and the borders are two passes over one mesh.
const _PART_LAYERS: Array[Array] = [[&"land"], [&"district", &"borders"], [&"coast"], [&"hatch"], [&"mountains"]]
## One unit of each Part: its vertices, and its triangles as vertex numbers of the unit.
const _UNIT_VERTICES: Array[int] = [13, 6, 4, 8, 10]
const _UNIT_INDICES: Array[Array] = [
	# A hex: the 12 points of its outline, then its centre; a fan.
	[12, 0, 1, 12, 1, 2, 12, 2, 3, 12, 3, 4, 12, 4, 5, 12, 5, 6, 12, 6, 7, 12, 7, 8, 12, 8, 9, 12, 9, 10, 12, 10, 11,
		12, 11, 0],
	[0, 3, 1, 1, 3, 4, 1, 4, 2, 2, 4, 5],  # a land edge: its 3 points on one side, the same 3 on the other
	[0, 1, 2, 1, 3, 2],  # a segment of the coast: a quad that reaches past both its points
	[0, 1, 2, 1, 3, 2, 2, 3, 4, 3, 5, 4, 4, 5, 6, 5, 7, 6],  # a hatch strip: a round end, the edge, a round end
	[0, 1, 2, 1, 3, 2, 2, 3, 4, 3, 5, 4, 4, 5, 6, 5, 7, 6, 6, 7, 8, 7, 9, 8],  # a mountain mark: one strip
]
## The vertex codes of a land edge (UV.x = hex a x 8 + code): points 0 to 2 on one side (codes 0 to 2) and on the other.
const _EDGE_CODES: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(2, 0), Vector2(3, 0), Vector2(4, 0),
	Vector2(5, 0)]


## One data texture: its bytes (this node's own copy), image and texture.
class Texels:
	extends RefCounted

	var size := Vector2i.ZERO
	var format := Image.FORMAT_R8
	var stride := 1
	var bytes := PackedByteArray()
	var image: Image = null
	var texture: ImageTexture = null

	func _init(p_size: Vector2i, p_format: Image.Format, p_stride: int, value: int) -> void:
		size = p_size
		format = p_format
		stride = p_stride
		bytes.resize(size.x * size.y * stride)
		bytes.fill(value)
		image = Image.create_from_data(size.x, size.y, false, format, bytes)
		texture = ImageTexture.create_from_image(image)

	## Takes the texels of `fresh` that differ and uploads once; returns how many differ (0, and no upload, when none do
	## or `fresh` is of another size). `fresh` is copied: the views' arrays are cached and stay unwritten.
	func write(fresh: PackedByteArray) -> int:
		if fresh.size() != bytes.size() or fresh == bytes:
			return 0
		var wrote := 0
		var row := size.x * stride
		for from: int in range(0, bytes.size(), row):
			if bytes.slice(from, from + row) == fresh.slice(from, from + row):
				continue
			for at: int in range(from, from + row, stride):
				if bytes[at] != fresh[at] or (stride > 1 and bytes[at + 1] != fresh[at + 1]):
					wrote += 1
		bytes = fresh.duplicate()
		image.set_data(size.x, size.y, false, format, bytes)
		texture.update(image)
		return wrote


## The vertex arrays of one Part of a chunk while it is being built.
class Soup:
	extends RefCounted

	var verts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var colours := PackedColorArray()  # the hatch only: the land hex's index in red, green and blue


## Geometry builds started: 1 for a map however its owners, goods or modes change (R28).
var geometry_builds := 0
## Texels changed in the owner and goods textures, and the uploads that did it.
var texel_writes := 0
var texture_updates := 0

static var _index_cache: Dictionary[int, PackedInt32Array] = {}  # Part -> the indices of its first units

var _game: Game = null
var _map: MapData = null
var _mode := int(MapModes.Mode.TERRAIN)
var _good := -1
var _tint_on := true
var _borders_on := true
var _colour_blind := false
var _high_contrast := false
var _enabled := true
var _zoom := 0.0  # 0: apply_zoom has not been called
var _switch := ParchmentSwitch.new()

var _owners: Texels = null
var _goods: Texels = null
var _palette: ImageTexture = null
var _palette_image: Image = null
var _facts_key: Array = []  # what the owner texels were made from
var _goods_key: Array = []

var _layers: Dictionary[StringName, CanvasItem] = {}
var _materials: Dictionary[StringName, ShaderMaterial] = {}
var _sea: Polygon2D = null
var _picture := CanvasGroup.new()  # holds the layers; a canvas group only while the parchment fades
var _fading := false

var _building := false
var _jobs: Array[Callable] = []
var _job := 0
var _band := 0
var _mesh_bytes := 0


func _init() -> void:
	z_index = LAYER_Z
	visible = false
	_picture.name = "Picture"
	add_child(_picture)
	_group_picture(false)
	for layer_name: StringName in LAYERS:
		var node: Node2D = Polygon2D.new() if layer_name == &"sea" else Node2D.new()
		node.name = String(layer_name).capitalize()
		_picture.add_child(node)
		_layers[layer_name] = node
		var material_of_layer := ShaderMaterial.new()
		if layer_name == &"sea":
			material_of_layer.shader = SEA_SHADER
			node.material = material_of_layer
		elif layer_name == &"hatch":
			material_of_layer.shader = HATCH_SHADER
		elif layer_name == &"land":
			material_of_layer.shader = FILL_SHADER
		else:
			material_of_layer.shader = LINE_SHADER
		_materials[layer_name] = material_of_layer
	_sea = _layers[&"sea"] as Polygon2D
	_set_fixed_uniforms()


# ----- the zoom's rules ----------------------------------------------------------------------------------------------


## How far the town view's mountain marks have faded in at a zoom (R9).
static func town_alpha_at(zoom: float) -> float:
	return clampf((zoom * float(MapTiles.CELL.x) - TOWN_VIEW_PX) / TOWN_FADE_PX, 0.0, 1.0)


## Whether the district lines show at a zoom (R9).
static func districts_at(zoom: float) -> bool:
	return zoom * float(MapTiles.CELL.x) >= DISTRICT_VIEW_PX


## Whether the hatched water is a flat tint at a zoom (R4).
static func hatch_flat_at(zoom: float) -> bool:
	return HATCH_SPACING * zoom < HATCH_MIN_PX


## How much of an owner's colour is mixed into its land (R6): none in Goods mode, or in Terrain with the tint off.
static func owner_strength(mode: int, tint_on: bool) -> float:
	if mode == MapModes.Mode.OWNER:
		return ParchmentTokens.OWNER_MIX
	return MapModes.TINT_ALPHA if mode == MapModes.Mode.TERRAIN and tint_on else 0.0


# ----- the game ------------------------------------------------------------------------------------------------------


## A game began (or null: none). The textures are made new from what its viewer knows; the geometry is queued for step()
## when the map is another than the one built, and kept when it is the same.
func begin(game: Game) -> void:
	_switch.settle()
	if game == null or game.map == null or game.state == null:
		_game = null
		_map = null
		_drop_geometry()
		_owners = null
		_goods = null
		_apply_view()
		return
	_game = game
	var size := Vector2i(game.map.cols, game.map.rows)
	# Until the first write nothing is known: no owner (the fog's fill), no goods.
	_owners = Texels.new(size, Image.FORMAT_R8, 1, ParchmentView.UNKNOWN)
	_goods = Texels.new(size, Image.FORMAT_RG8, ParchmentView.GOODS_STRIDE, 0)
	_facts_key = []
	_goods_key = []
	if game.map != _map:
		_start_geometry(game.map)
	_bind_textures()
	_write_palette()
	sync(game)
	_apply_view()


func is_building() -> bool:
	return _building


## Builds geometry for up to `budget_ms` milliseconds (at least one job: a row of edges, a chunk's row of hexes, or one
## mesh).
func step(budget_ms: float) -> void:
	if not _building:
		return
	var until := SimClock.usec() + int(budget_ms * 1000.0)
	while _building:
		_run_job()
		if SimClock.usec() >= until:
			break
	if not _building:
		_apply_view()


## Brings the textures to what the viewer of `game` knows now. One compare while nothing moved; the goods only in Goods
## mode. A game other than the one begun is ignored.
func sync(game: Game) -> void:
	if game == null or game != _game or _owners == null:
		return
	var key: Array = [game.version, MapModes.discovered_key(game, game.player)]
	if key != _facts_key:
		_facts_key = key
		_write_facts()
	if _mode == MapModes.Mode.GOODS and key != _goods_key:
		_goods_key = key
		_count(_goods.write(ParchmentView.goods_bytes(game, game.player)))


## Land changed owner: the owner texels that now differ are written at once (and the goods in Goods mode).
func owners_changed(hexes: Array[Vector2i]) -> void:
	if hexes.is_empty() or _game == null or _owners == null:
		return
	_facts_key = []
	_goods_key = []
	sync(_game)


func set_mode(mode: int) -> void:
	if mode != _mode:
		_switch.snap()  # another mode shows at once: only a zoom crossing fades
	_mode = mode
	_apply_fill()
	sync(_game)
	_apply_view()


## The good of the Goods mode (a GameDefs good id; below 0 none): one uniform, no texel.
func set_good(good_id: int) -> void:
	_good = good_id
	_materials[&"land"].set_shader_parameter(&"good", maxi(good_id + 1, 0))


## `tint` and `borders` are map/owner_tint and map/borders, `enabled` map/parchment (Goods mode shows the parchment
## either way, R18).
func set_options(tint: bool, borders: bool, colour_blind: bool, high_contrast: bool, enabled: bool) -> void:
	var new_palette := colour_blind != _colour_blind
	if enabled != _enabled:
		_switch.snap()
	_tint_on = tint
	_borders_on = borders
	_colour_blind = colour_blind
	_high_contrast = high_contrast
	_enabled = enabled
	if new_palette:
		_write_palette()
	_apply_colours()
	_apply_fill()
	_apply_view()


## Shows the parchment as the zoom, the fit zoom and the mode say; returns the alpha used (1 solid, 0 hidden). A part
## alpha is the picture's self_modulate; this node's modulate is not written.
func apply_zoom(zoom: float, fit: float) -> float:
	var moved := zoom != _zoom
	_zoom = maxf(zoom, 0.001)
	if moved:
		_apply_detail()
	_switch.follow(_zoom, fit, _zoom_decides())
	return _apply_view()


## Spends `delta` seconds of a cross-fade: once a frame (a test or a capture steps the time itself).
func step_fade(delta: float) -> void:
	if _switch.step(delta):
		_apply_view()


## Under reduce motion the parchment and the tiles change places at once.
func set_instant(on: bool) -> void:
	_switch.instant = on


func mode() -> int:
	return _mode


## map/parchment as set_options was last told.
func enabled() -> bool:
	return _enabled


func good() -> int:
	return _good


# ----- what the tests and the tools read -----------------------------------------------------------------------------


## The node that holds the layers and fades them as one.
func picture() -> CanvasGroup:
	return _picture


## Whether the layers are drawn as one picture now (only while they cross-fade: the alpha between 0 and 1).
func is_fading() -> bool:
	return _fading


func layer(layer_name: StringName) -> CanvasItem:
	return _layers.get(layer_name) as CanvasItem


func layer_material(layer_name: StringName) -> ShaderMaterial:
	return _materials.get(layer_name) as ShaderMaterial


## The mesh a layer draws for a chunk (column, row of chunks), or null when it has nothing there.
func chunk_mesh(layer_name: StringName, chunk: Vector2i) -> ArrayMesh:
	var holder := layer(layer_name)
	var node := holder.get_node_or_null(_chunk_name(chunk)) as MeshInstance2D if holder != null else null
	return node.mesh as ArrayMesh if node != null else null


func owner_image() -> Image:
	return _owners.image if _owners != null else null


func goods_image() -> Image:
	return _goods.image if _goods != null else null


func palette_image() -> Image:
	return _palette_image


## Bytes of the meshes (vertex and index buffers) and of the three textures, as sent to the graphics card.
func memory_bytes() -> int:
	var total := _mesh_bytes
	for texels: Texels in [_owners, _goods]:
		if texels != null:
			total += texels.bytes.size()
	if _palette_image != null:
		total += _palette_image.get_data().size()
	return total


# ----- the textures and the uniforms ---------------------------------------------------------------------------------


func _write_facts() -> void:
	_count(_owners.write(ParchmentView.owner_bytes(_game, _game.player)))


func _count(wrote: int) -> void:
	if wrote > 0:
		texel_writes += wrote
		texture_updates += 1


func _write_palette() -> void:
	if _game == null:
		return
	var colours := MapModes.palette(_game, _colour_blind)
	var bytes := PackedByteArray()
	bytes.resize(MapModes.PALETTE_SIZE * 4)
	for i: int in mini(colours.size(), MapModes.PALETTE_SIZE):
		var c := colours[i]
		bytes[i * 4] = c.r8
		bytes[i * 4 + 1] = c.g8
		bytes[i * 4 + 2] = c.b8
		bytes[i * 4 + 3] = c.a8
	_palette_image = Image.create_from_data(MapModes.PALETTE_SIZE, 1, false, Image.FORMAT_RGBA8, bytes)
	_palette = ImageTexture.create_from_image(_palette_image)
	_materials[&"land"].set_shader_parameter(&"palette", _palette)


## The uniforms that no setting changes.
func _set_fixed_uniforms() -> void:
	for layer_name: StringName in LINE_KINDS:
		var line := _materials[layer_name]
		line.set_shader_parameter(&"kind", LINE_KINDS[layer_name])
		line.set_shader_parameter(&"cell_size", Vector2(MapTiles.CELL))
		line.set_shader_parameter(&"row_height", MapTiles.ROW)
		line.set_shader_parameter(&"edge_length", EDGE_LENGTH)
		var dashed := layer_name == &"borders"
		var dotted := layer_name == &"district"
		line.set_shader_parameter(&"dash_px", ParchmentTokens.BORDER_DASH_PX if dashed else (DISTRICT_DOT_PX if dotted else 0.0))
		line.set_shader_parameter(&"gap_px", ParchmentTokens.BORDER_GAP_PX if dashed else (DISTRICT_GAP_PX if dotted else 0.0))
	var hatch := _materials[&"hatch"]
	hatch.set_shader_parameter(&"radius", HATCH_RADIUS)
	hatch.set_shader_parameter(&"spacing", HATCH_SPACING)
	hatch.set_shader_parameter(&"line_width", HATCH_WIDTH)
	hatch.set_shader_parameter(&"wave_length", HATCH_WAVE)
	hatch.set_shader_parameter(&"wave_rise", HATCH_RISE)
	var sea := _materials[&"sea"]
	sea.set_shader_parameter(&"cell", SPECKLE_CELL)
	sea.set_shader_parameter(&"radius", SPECKLE_RADIUS)
	_apply_colours()
	_apply_fill()
	set_good(_good)
	_zoom = 1.0
	_apply_detail()  # every uniform has a value before the first apply_zoom
	_zoom = 0.0


func _bind_textures() -> void:
	var cols := _owners.size.x
	for layer_name: StringName in LAYERS:
		if layer_name == &"sea":
			continue
		_materials[layer_name].set_shader_parameter(&"owners", _owners.texture)
		_materials[layer_name].set_shader_parameter(&"cols", cols)
	_materials[&"land"].set_shader_parameter(&"goods", _goods.texture)


func _apply_colours() -> void:
	var colours := ParchmentTokens.colours(_high_contrast)
	var sea := _materials[&"sea"]
	sea.set_shader_parameter(&"sea_colour", colours[&"sea"])
	sea.set_shader_parameter(&"speckle_colour", colours[&"speckle"])
	# The hatch is drawn opaque, already laid over the sea's colour, so two strips that overlap are no darker than one.
	var thin := colours[&"hatch"]
	thin.a *= HATCH_WIDTH / HATCH_SPACING
	var hatch := _materials[&"hatch"]
	hatch.set_shader_parameter(&"line_colour", colours[&"sea"].blend(colours[&"hatch"]))
	hatch.set_shader_parameter(&"flat_colour", colours[&"sea"].blend(thin))
	var land := _materials[&"land"]
	for role: StringName in [&"land", &"unknown", &"goods_1", &"goods_2", &"goods_3"]:
		land.set_shader_parameter(StringName(String(role) + "_colour"), colours[role])
	var inks: Dictionary[StringName, Array] = {
		&"district": [colours[&"district"], ParchmentTokens.district_px(_high_contrast)],
		&"borders": [colours[&"border"], ParchmentTokens.border_px(_high_contrast)],
		&"coast": [colours[&"coast"], ParchmentTokens.coast_px(_high_contrast)],
		&"mountains": [colours[&"mountain"], MOUNTAIN_PX],
	}
	for layer_name: StringName in inks:
		_materials[layer_name].set_shader_parameter(&"ink", inks[layer_name][0])
		_materials[layer_name].set_shader_parameter(&"width_px", inks[layer_name][1])


func _apply_fill() -> void:
	var land := _materials[&"land"]
	land.set_shader_parameter(&"goods_mode", _mode == MapModes.Mode.GOODS)
	land.set_shader_parameter(&"owner_strength", owner_strength(_mode, _tint_on))


## The uniforms and layers that follow the zoom.
func _apply_detail() -> void:
	for layer_name: StringName in LINE_KINDS:
		_materials[layer_name].set_shader_parameter(&"zoom", _zoom)
	_materials[&"hatch"].set_shader_parameter(&"flat_tint", hatch_flat_at(_zoom))
	_materials[&"sea"].set_shader_parameter(&"zoom", _zoom)
	_layers[&"district"].visible = districts_at(_zoom)
	var marks := town_alpha_at(_zoom)
	_layers[&"mountains"].visible = marks > 0.0
	_layers[&"mountains"].modulate.a = marks


## The sea reaches one screen past the map on every side (R2), once a zoom is known.
func _apply_sea() -> void:
	if _map == null or _zoom <= 0.0:
		return
	var screen := get_viewport_rect().size if is_inside_tree() else SEA_SCREEN
	var map_size := Vector2((float(_map.cols) + 0.5) * float(MapTiles.CELL.x),
		float(_map.rows) * MapTiles.ROW + float(MapTiles.CELL.y) - MapTiles.ROW)
	var reach := screen / _zoom
	var low := -reach
	var high := map_size + reach
	var corners := PackedVector2Array([low, Vector2(high.x, low.y), high, Vector2(low.x, high.y)])
	if _sea.polygon != corners:
		_sea.polygon = corners


## The alpha the parchment shows at now.
func _alpha() -> float:
	if not _can_show():
		return 0.0
	if _mode == MapModes.Mode.GOODS:
		return 1.0
	return _switch.blend() if _zoom_decides() else 0.0


## There is a parchment to show: a game, its geometry, a zoom, and no country pick (R16).
func _can_show() -> bool:
	if _game == null or _building or _zoom <= 0.0:
		return false
	return not (_game.has_countries() and _game.player == &"" and not _game.ai_only)


## Whether the zoom chooses between the parchment and the tiles now: Terrain or Owner with map/parchment on.
func _zoom_decides() -> bool:
	return _enabled and (_mode == MapModes.Mode.TERRAIN or _mode == MapModes.Mode.OWNER) and _can_show()


## What follows the state as it is now: the sea's reach (a new map has none until here), the borders, the alpha and how
## the picture is drawn.
func _apply_view() -> float:
	_apply_sea()
	_layers[&"borders"].visible = _borders_on
	var alpha := _alpha()
	var fading := alpha > 0.0 and alpha < 1.0
	if fading != _fading:
		_group_picture(fading)
	_picture.self_modulate.a = alpha if fading else 1.0
	visible = alpha > 0.0
	return alpha


## On: the layers are drawn into a buffer that is laid over the map once at the picture's alpha, so none shows through
## another. Off: they are drawn straight to the screen, with no buffer to pay for.
func _group_picture(on: bool) -> void:
	_fading = on
	var group := RenderingServer.CANVAS_GROUP_MODE_TRANSPARENT if on else RenderingServer.CANVAS_GROUP_MODE_DISABLED
	# The server's own call, as CanvasGroup makes it (fit_empty: the rect is the children's, the node draws nothing).
	RenderingServer.canvas_item_set_canvas_group_mode(_picture.get_canvas_item(), group, _picture.clear_margin, true,
		_picture.fit_margin, _picture.use_mipmaps)


# ----- the geometry --------------------------------------------------------------------------------------------------


func _drop_geometry() -> void:
	_building = false
	_jobs.clear()
	_job = 0
	_band = 0
	_mesh_bytes = 0
	for layer_name: StringName in LAYERS:
		for child: Node in _layers[layer_name].get_children():
			child.free()


func _start_geometry(map: MapData) -> void:
	_drop_geometry()
	_map = map
	geometry_builds += 1
	_building = map.cols > 0 and map.rows > 0


## Runs the next job; a band of chunks (CHUNK.y rows) is queued when the one before is done.
func _run_job() -> void:
	if _job >= _jobs.size():
		_queue_band()
	_jobs[_job].call()
	_job += 1
	if _job < _jobs.size():
		return
	_jobs.clear()
	_job = 0
	_band += 1
	_building = _band * CHUNK.y < _map.rows


## The jobs of one band: its edges and mountain marks a row at a time, its hexes a chunk's row at a time, then its
## meshes one at a time.
func _queue_band() -> void:
	var across := ceili(float(_map.cols) / float(CHUNK.x))
	var soups: Array[Array] = []  # per chunk of the band: a Soup a Part
	for _x: int in across:
		var parts: Array[Soup] = []
		for _part: int in Part.size():
			parts.append(Soup.new())
		soups.append(parts)
	var first := _band * CHUNK.y
	var end := mini(first + CHUNK.y, _map.rows)
	for row: int in range(first, end):
		_jobs.append(_add_edges.bind(row, soups))
		_jobs.append(_add_mountains.bind(row, soups))
	for row: int in range(first, end):
		for x: int in across:
			_jobs.append(_add_hexes.bind(row, x, soups[x][Part.FILL]))
	for x: int in across:
		for part: int in Part.size():
			_jobs.append(_commit.bind(soups[x][part], part, Vector2i(x, _band)))


## One row of one chunk: every hex's outline and centre, with its index and whether it is land in UV.
func _add_hexes(row: int, chunk_x: int, soup: Soup) -> void:
	var cols := _map.cols
	var land := _map.land
	var uv := PackedVector2Array()
	uv.resize(_UNIT_VERTICES[Part.FILL])
	for col: int in range(chunk_x * CHUNK.x, mini((chunk_x + 1) * CHUNK.x, cols)):
		var hex := Vector2i(col, row)
		var i := row * cols + col
		soup.verts.append_array(ParchmentShape.polygon(hex))
		soup.verts.append(MapTiles.cell_centre(hex))
		uv.fill(Vector2(float(i), float(land[i])))
		soup.uvs.append_array(uv)


## The edges of one row's hexes, each to the chunk of its hex `a`'s column: a land edge to the lines (an edge on the rim
## of the map is drawn by nothing; UV is (a x 8 + code, b)), a coast edge to the coast and to the hatch.
func _add_edges(row: int, soups: Array[Array]) -> void:
	var edges := ParchmentShape.edges(_map, Vector2i(row, row + 1))
	var points: PackedVector2Array = edges["points"]
	var a: PackedInt32Array = edges["a"]
	var b: PackedInt32Array = edges["b"]
	var kind: PackedByteArray = edges["kind"]
	var cols := _map.cols
	var codes := PackedVector2Array(_EDGE_CODES)
	for k: int in a.size():
		var other := b[k]
		if other < 0:
			continue
		var one := a[k]
		var parts: Array = soups[floori(float(one % cols) / float(CHUNK.x))]
		var three := points.slice(3 * k, 3 * k + 3)
		if kind[k] == ParchmentShape.Edge.COAST:
			_add_coast(parts[Part.COAST], three, one)
			_add_hatch(parts[Part.HATCH], three[0], three[2], one)
			continue
		var soup: Soup = parts[Part.LINES]
		soup.verts.append_array(three)
		soup.verts.append_array(three)
		soup.uvs.append_array(Transform2D(Vector2.RIGHT, Vector2.DOWN, Vector2(float(one * 8), float(other))) * codes)


## One coast edge, a quad a segment, drawn as a stroke with round ends (so segments meet in round joins): UV is
## (land hex x 8 + code, the angle of the segment's course and its length, packed); code 1 is the side, 2 the end.
func _add_coast(soup: Soup, three: PackedVector2Array, land_hex: int) -> void:
	for s: int in 2:
		var from := three[s]
		var to := three[s + 1]
		var data := packed_uv((to - from).angle(), roundi(from.distance_to(to) * COAST_STEPS))
		soup.verts.append_array(PackedVector2Array([from, from, to, to]))
		for code: int in 4:
			soup.uvs.append(Vector2(float(land_hex * 8 + code), data))


## An angle (radians) and a byte as one whole number that a float holds exactly: angle steps x 256 + the byte.
static func packed_uv(angle: float, value: int) -> float:
	return float(posmod(roundi(angle / TAU * float(ANGLE_STEPS)), ANGLE_STEPS) * 256 + clampi(value, 0, 255))


## The hatch strip of one coast edge: from corner to corner, half a hex to each side, with a round end past each corner.
## UV is (how far past the end, how far across), the colour holds the land hex's index.
func _add_hatch(soup: Soup, from: Vector2, to: Vector2, land_hex: int) -> void:
	var r := HATCH_RADIUS
	var along := (to - from).normalized() * r
	var side := Vector2(-along.y, along.x)
	soup.verts.append_array(PackedVector2Array([from - along + side, from - along - side, from + side, from - side,
		to + side, to - side, to + along + side, to + along - side]))
	soup.uvs.append_array(PackedVector2Array([Vector2(r, r), Vector2(r, -r), Vector2(0.0, r), Vector2(0.0, -r),
		Vector2(0.0, r), Vector2(0.0, -r), Vector2(r, r), Vector2(r, -r)]))
	var index := PackedColorArray()
	index.resize(_UNIT_VERTICES[Part.HATCH])
	index.fill(Color.hex((land_hex << 8) | 0xFF))
	soup.colours.append_array(index)


## The mountain marks of one row, each one strip along its zig-zag with mitred corners (no stroke lies over another,
## so the see-through ink is even): UV is (hex x 8 + side, the angle of the corner's mitre and its reach, packed).
func _add_mountains(row: int, soups: Array[Array]) -> void:
	var marks := ParchmentShape.mountains(_map, Vector2i(row, row + 1))
	var points: PackedVector2Array = marks["points"]
	var hexes: PackedInt32Array = marks["hex"]
	var n := ParchmentShape.MOUNTAIN_POINTS
	for m: int in hexes.size():
		var i := hexes[m]
		var soup: Soup = soups[floori(float(i % _map.cols) / float(CHUNK.x))][Part.MOUNTAINS]
		for k: int in n:
			var at := points[m * n + k]
			# The normals (-d.y, d.x) of the strokes before and after this corner; an end has one stroke only.
			var before := -(at - points[m * n + k - 1]).normalized().orthogonal() if k > 0 else Vector2.ZERO
			var after := -(points[m * n + k + 1] - at).normalized().orthogonal() if k < n - 1 else Vector2.ZERO
			var mitre := (before + after).normalized()
			var reach := 1.0 / mitre.dot(after if k == 0 else before)
			var data := packed_uv(mitre.angle(), roundi(reach * MITRE_STEPS))
			soup.verts.append(at)
			soup.verts.append(at)
			soup.uvs.append(Vector2(float(i * 8), data))
			soup.uvs.append(Vector2(float(i * 8 + 1), data))


## One mesh of a chunk, under each layer that draws its Part; nothing for a Part with no geometry.
func _commit(soup: Soup, part: int, chunk: Vector2i) -> void:
	if soup.verts.is_empty():
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = soup.verts
	arrays[Mesh.ARRAY_TEX_UV] = soup.uvs
	if not soup.colours.is_empty():
		arrays[Mesh.ARRAY_COLOR] = soup.colours
	var vertices := soup.verts.size()
	var indices := _indices_of(part, floori(float(vertices) / float(_UNIT_VERTICES[part])))
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if part == Part.LINES or part == Part.COAST or part == Part.MOUNTAINS:
		mesh.custom_aabb = mesh.get_aabb().grow(LINE_BOUNDS_PX)
	var vertex_bytes := 16 if soup.colours.is_empty() else 20
	_mesh_bytes += vertices * vertex_bytes + indices.size() * (2 if vertices <= 65536 else 4)
	for layer_name: StringName in _PART_LAYERS[part]:
		var node := MeshInstance2D.new()
		node.name = _chunk_name(chunk)
		node.mesh = mesh
		node.material = _materials[layer_name]
		_layers[layer_name].add_child(node)


## The indices of `units` units of a Part (the same for every chunk, so made once and cut to length).
static func _indices_of(part: int, units: int) -> PackedInt32Array:
	var pattern: Array = _UNIT_INDICES[part]
	var wanted := units * pattern.size()
	var held: PackedInt32Array = _index_cache.get(part, PackedInt32Array())
	if held.size() < wanted:
		var made := floori(float(held.size()) / float(pattern.size()))
		held.resize(wanted)
		for unit: int in range(made, units):
			var base := unit * _UNIT_VERTICES[part]
			var at := unit * pattern.size()
			for k: int in pattern.size():
				held[at + k] = base + int(pattern[k])
		_index_cache[part] = held
	return held.slice(0, wanted)


static func _chunk_name(chunk: Vector2i) -> String:
	return "c%d_%d" % [chunk.x, chunk.y]
