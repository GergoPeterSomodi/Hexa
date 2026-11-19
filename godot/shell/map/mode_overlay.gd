## Per-hex map mode overlay (docs/architecture/m2-build-spec.md sections 6.1 and 6.2):
## draws one map-sized quad at z_index 80 with mode_overlay.gdshader over four data textures
## (owner_ids R8, heights R8, palette RGBA8 256x1, ramp RGBA8 256x1).
@tool
class_name ModeOverlay
extends Node2D

const LAYER_Z := 80
const SHADER_PATH := "res://shell/map/mode_overlay.gdshader"

## Texel writes performed by update_hexes (mode/tint/hot switches write 0 texels).
var texel_writes := 0
## GPU texture updates performed by update_hexes (one per batch).
var texture_updates := 0

var _mode: MapModes.Mode = MapModes.Mode.TERRAIN
var _tint_on := true
var _hot_id := 0
var _colour_blind := false
var _game: Game = null
var _map: MapData = null
var _map_size := Vector2.ZERO
var _grid_size := Vector2i.ZERO

var _owner_bytes := PackedByteArray()
var _owner_image: Image = null
var _owner_tex: ImageTexture = null
var _heights_image: Image = null
var _heights_tex: ImageTexture = null
var _palette_image: Image = null
var _palette_tex: ImageTexture = null
var _ramp_image: Image = null
var _ramp_tex: ImageTexture = null
var _material: ShaderMaterial = null


func _init() -> void:
	z_index = LAYER_Z


## Builds all four GPU textures from plain inputs and applies shader uniforms.
func setup_from(map: MapData, owner: PackedByteArray, palette: PackedColorArray) -> void:
	_game = null
	if map == null or map.cols <= 0 or map.rows <= 0:
		return
	_map = map
	_grid_size = Vector2i(map.cols, map.rows)
	_map_size = Vector2(
		(float(map.cols) + 0.5) * float(MapTiles.CELL.x),
		float(map.rows) * MapTiles.ROW + float(MapTiles.CELL.y) - MapTiles.ROW
	)
	var count := map.hex_count()
	if owner.size() == count:
		_owner_bytes = owner.duplicate()
	else:
		_owner_bytes = PackedByteArray()
		_owner_bytes.resize(count)
		_owner_bytes.fill(0)

	_owner_image = Image.create_from_data(map.cols, map.rows, false, Image.FORMAT_R8, _owner_bytes)
	_owner_tex = ImageTexture.create_from_image(_owner_image)

	var h_bytes := MapModes.height_bytes(map)
	_heights_image = Image.create_from_data(map.cols, map.rows, false, Image.FORMAT_R8, h_bytes)
	_heights_tex = ImageTexture.create_from_image(_heights_image)

	_palette_image = _image_from_colours(palette)
	_palette_tex = ImageTexture.create_from_image(_palette_image)

	_ramp_image = _image_from_colours(MapModes.relief_ramp())
	_ramp_tex = ImageTexture.create_from_image(_ramp_image)

	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = load(SHADER_PATH) as Shader
	_material.set_shader_parameter(&"owner_ids", _owner_tex)
	_material.set_shader_parameter(&"heights", _heights_tex)
	_material.set_shader_parameter(&"palette", _palette_tex)
	_material.set_shader_parameter(&"ramp", _ramp_tex)
	_material.set_shader_parameter(&"map_size", _map_size)
	_material.set_shader_parameter(&"grid_size", _grid_size)
	_material.set_shader_parameter(&"from_uv", false)
	_material.set_shader_parameter(&"tint_alpha", MapModes.TINT_ALPHA)
	_material.set_shader_parameter(&"owner_alpha", MapModes.OWNER_ALPHA)
	_material.set_shader_parameter(&"relief_alpha", MapModes.RELIEF_ALPHA)
	_material.set_shader_parameter(&"hot_alpha", MapModes.HOT_ALPHA)
	_material.set_shader_parameter(&"hot_lighten", MapModes.HOT_LIGHTEN)
	_sync_uniforms()
	material = _material
	_update_visibility()
	queue_redraw()


## Configures the overlay directly from `game` using standard or colour-blind safe colours.
func setup(game: Game, colour_blind: bool = false) -> void:
	_colour_blind = colour_blind
	if game == null or game.map == null or game.state == null:
		_game = null
		return
	setup_from(game.map, game.state.owner, MapModes.palette(game, colour_blind))
	_game = game


## Replaces the 256 x 1 palette texture from plain colours (used by the editor and tests).
func set_palette_colours(palette: PackedColorArray) -> void:
	if _palette_tex == null:
		return
	_palette_image = _image_from_colours(palette)
	_palette_tex.update(_palette_image)


## Rewrites only the 256 x 1 palette texture for `colour_blind` when bound to a Game.
func set_palette(colour_blind: bool) -> void:
	_colour_blind = colour_blind
	if _game == null:
		return
	set_palette_colours(MapModes.palette(_game, colour_blind))


## Switches map mode via a shader uniform; hides the node in Terrain when tint is off.
func set_mode(mode: MapModes.Mode) -> void:
	_mode = mode
	if _material != null:
		_material.set_shader_parameter(&"mode", int(_mode))
	_update_visibility()


func mode() -> MapModes.Mode:
	return _mode


## Enables or disables the owner tint in Terrain mode via a uniform.
func set_tint(on: bool) -> void:
	_tint_on = on
	if _material != null:
		_material.set_shader_parameter(&"tint_on", _tint_on)
	_update_visibility()


func is_tint_on() -> bool:
	return _tint_on


## Highlights one country id while picking (0 clears highlight).
func set_hot(id: int) -> void:
	_hot_id = id
	if _material != null:
		_material.set_shader_parameter(&"hot_id", _hot_id)


func hot_id() -> int:
	return _hot_id


## Rewrites the owner texels for `hexes` (reading from `owner`, bound `game.state.owner`, or internal bytes)
## and uploads the updated owner texture once for the batch.
func update_hexes(hexes: Array[Vector2i], owner: PackedByteArray = PackedByteArray()) -> void:
	if _map == null or _owner_image == null or _owner_tex == null or hexes.is_empty():
		return
	var count := _map.hex_count()
	var src := PackedByteArray()
	if owner.size() == count:
		src = owner
	elif _game != null and _game.state != null and _game.state.owner.size() == count:
		src = _game.state.owner
	var has_src := src.size() == count
	var wrote := 0
	for hex: Vector2i in hexes:
		var idx := _map.index_of(hex)
		if idx < 0:
			continue
		var owner_id := int(src[idx]) if has_src else int(_owner_bytes[idx])
		_owner_bytes[idx] = owner_id
		_owner_image.set_pixel(hex.x, hex.y, Color(float(owner_id) / 255.0, 0.0, 0.0, 1.0))
		wrote += 1
	if wrote > 0:
		texel_writes += wrote
		_owner_tex.update(_owner_image)
		texture_updates += 1


## Returns a ShaderMaterial copy sharing the four textures, configured for minimap UV coordinates.
func material_for_minimap() -> ShaderMaterial:
	if _material == null:
		return null
	var copy := _material.duplicate(false) as ShaderMaterial
	copy.set_shader_parameter(&"from_uv", true)
	return copy


## Total bytes occupied by the four overlay textures (0 before setup).
func texture_bytes() -> int:
	var total := 0
	for img: Image in [_owner_image, _heights_image, _palette_image, _ramp_image]:
		if img != null:
			total += img.get_data().size()
	return total


func owner_texture() -> ImageTexture:
	return _owner_tex


func owner_image() -> Image:
	return _owner_image


func heights_texture() -> ImageTexture:
	return _heights_tex


func palette_texture() -> ImageTexture:
	return _palette_tex


func palette_image() -> Image:
	return _palette_image


func ramp_texture() -> ImageTexture:
	return _ramp_tex


func _draw() -> void:
	if _map_size.x > 0.0 and _map_size.y > 0.0:
		draw_rect(Rect2(Vector2.ZERO, _map_size), Color.WHITE)


func _sync_uniforms() -> void:
	if _material == null:
		return
	_material.set_shader_parameter(&"mode", int(_mode))
	_material.set_shader_parameter(&"tint_on", _tint_on)
	_material.set_shader_parameter(&"hot_id", _hot_id)


func _update_visibility() -> void:
	visible = not (_mode == MapModes.Mode.TERRAIN and not _tint_on)


static func _image_from_colours(colours: PackedColorArray) -> Image:
	var bytes := PackedByteArray()
	bytes.resize(MapModes.PALETTE_SIZE * 4)
	var count := mini(colours.size(), MapModes.PALETTE_SIZE)
	for i: int in count:
		var c := colours[i]
		var at := i * 4
		bytes[at] = c.r8
		bytes[at + 1] = c.g8
		bytes[at + 2] = c.b8
		bytes[at + 3] = c.a8
	return Image.create_from_data(MapModes.PALETTE_SIZE, 1, false, Image.FORMAT_RGBA8, bytes)
