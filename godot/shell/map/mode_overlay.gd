## Per-hex map mode overlay (docs/architecture/m2-build-spec.md sections 6.1 and 6.2):
## draws one map-sized quad at z_index 80 with mode_overlay.gdshader over four data textures
## (owner_ids R8, heights R8, palette RGBA8 256x1, ramp RGBA8 256x1), and for the Yields mode (docs/architecture/m4-5-build-spec.md
## 6.7) two more: yields R8 (one band byte a hex) and yield_ramp RGBA8 256x1. M6 (spec 6.6) adds the Supply mode (supply R8
## and supply_ramp RGBA8 256x1) and the sight veil (sight R8, 1 where the viewer sees the hex): the veil goes over every land
## hex nobody of the viewer's sees, in every mode, when map/sight_veil is on.
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
var _yield_bytes := PackedByteArray()
var _yields_version := -1  # the game.version the Yields texture shows (-1: none)
var _yields_image: Image = null
var _yields_tex: ImageTexture = null
var _yield_ramp_image: Image = null
var _yield_ramp_tex: ImageTexture = null
var _food_bytes := PackedByteArray()
var _food_version := -1  # the game.version the Food texture shows (-1: none)
var _food_image: Image = null
var _food_tex: ImageTexture = null
var _food_ramp_image: Image = null
var _food_ramp_tex: ImageTexture = null
var _supply_bytes := PackedByteArray()
var _supply_version := -1  # the game.version the Supply texture shows (-1: none)
var _supply_image: Image = null
var _supply_tex: ImageTexture = null
var _supply_ramp_image: Image = null
var _supply_ramp_tex: ImageTexture = null
var _sight_bytes := PackedByteArray()
var _sight_version := -1  # the game.version the sight texture shows (-1: none)
var _sight_image: Image = null
var _sight_tex: ImageTexture = null
var _sight_veil_on := false
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

	_yields_version = -1
	_yield_bytes = PackedByteArray()
	_yield_bytes.resize(count)  # zero: no worth known
	_yields_image = Image.create_from_data(map.cols, map.rows, false, Image.FORMAT_R8, _yield_bytes)
	_yields_tex = ImageTexture.create_from_image(_yields_image)
	_yield_ramp_image = _image_from_colours(MapModes.yield_ramp())
	_yield_ramp_tex = ImageTexture.create_from_image(_yield_ramp_image)

	_food_version = -1
	_food_bytes = PackedByteArray()
	_food_bytes.resize(count)  # zero: not your land
	_food_image = Image.create_from_data(map.cols, map.rows, false, Image.FORMAT_R8, _food_bytes)
	_food_tex = ImageTexture.create_from_image(_food_image)
	_food_ramp_image = _image_from_colours(MapModes.food_ramp())
	_food_ramp_tex = ImageTexture.create_from_image(_food_ramp_image)

	_supply_version = -1
	_supply_bytes = PackedByteArray()
	_supply_bytes.resize(count)  # zero: not your land
	_supply_image = Image.create_from_data(map.cols, map.rows, false, Image.FORMAT_R8, _supply_bytes)
	_supply_tex = ImageTexture.create_from_image(_supply_image)
	_supply_ramp_image = _image_from_colours(MapModes.supply_ramp())
	_supply_ramp_tex = ImageTexture.create_from_image(_supply_ramp_image)

	_sight_version = -1
	_sight_bytes = PackedByteArray()
	_sight_bytes.resize(count)
	_sight_bytes.fill(1)  # everything seen until the first sync: no veil before the viewer's sight is known
	_sight_image = Image.create_from_data(map.cols, map.rows, false, Image.FORMAT_R8, _sight_bytes)
	_sight_tex = ImageTexture.create_from_image(_sight_image)

	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = load(SHADER_PATH) as Shader
	_material.set_shader_parameter(&"owner_ids", _owner_tex)
	_material.set_shader_parameter(&"heights", _heights_tex)
	_material.set_shader_parameter(&"palette", _palette_tex)
	_material.set_shader_parameter(&"ramp", _ramp_tex)
	_material.set_shader_parameter(&"yields", _yields_tex)
	_material.set_shader_parameter(&"yield_ramp", _yield_ramp_tex)
	_material.set_shader_parameter(&"yield_alpha", MapModes.YIELD_ALPHA)
	_material.set_shader_parameter(&"food", _food_tex)
	_material.set_shader_parameter(&"food_ramp", _food_ramp_tex)
	_material.set_shader_parameter(&"food_alpha", MapModes.FOOD_ALPHA)
	_material.set_shader_parameter(&"supply", _supply_tex)
	_material.set_shader_parameter(&"supply_ramp", _supply_ramp_tex)
	_material.set_shader_parameter(&"supply_alpha", MapModes.SUPPLY_ALPHA)
	_material.set_shader_parameter(&"sight", _sight_tex)
	_material.set_shader_parameter(&"sight_alpha", MapModes.SIGHT_VEIL_ALPHA)
	_material.set_shader_parameter(&"veil_alpha", MapModes.VEIL_ALPHA)
	_material.set_shader_parameter(&"stripe_px", MapModes.STRIPE_PX)
	_material.set_shader_parameter(&"veil_colour", MapModes.VEIL)
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


## Writes the Yields texels that differ from `bytes` (one byte a hex, MapModes.yield_bytes) and uploads the texture once;
## returns how many texels it wrote (0, and no upload, when nothing differs or `bytes` is not one a hex).
func update_yields(bytes: PackedByteArray) -> int:
	if _map == null or _yields_image == null or _yields_tex == null or bytes.size() != _yield_bytes.size():
		return 0
	var wrote := 0
	var cols := _map.cols
	var idx := 0
	for row: int in _map.rows:
		for col: int in cols:
			var b := bytes[idx]
			if b != _yield_bytes[idx]:
				_yield_bytes[idx] = b
				_yields_image.set_pixel(col, row, Color(float(b) / 255.0, 0.0, 0.0, 1.0))
				wrote += 1
			idx += 1
	if wrote > 0:
		texel_writes += wrote
		_yields_tex.update(_yields_image)
		texture_updates += 1
	return wrote


## Brings the Yields texture to `game`'s worth for its player: only while the mode is Yields, and (unless `force`) only
## when `game.version` changed since the last time. Returns the texels written.
func sync_yields(game: Game, force: bool = false) -> int:
	if _mode != MapModes.Mode.YIELDS or game == null or game.map == null:
		return 0
	if not force and game.version == _yields_version:
		return 0
	_yields_version = game.version
	return update_yields(MapModes.yield_bytes(game, game.player))


## Writes the Food texels that differ from `bytes` (one byte a hex, MapModes.food_bytes) and uploads the texture once;
## returns how many texels it wrote (0, and no upload, when nothing differs or `bytes` is not one a hex).
func update_food(bytes: PackedByteArray) -> int:
	if _map == null or _food_image == null or _food_tex == null or bytes.size() != _food_bytes.size():
		return 0
	var wrote := 0
	var cols := _map.cols
	var idx := 0
	for row: int in _map.rows:
		for col: int in cols:
			var b := bytes[idx]
			if b != _food_bytes[idx]:
				_food_bytes[idx] = b
				_food_image.set_pixel(col, row, Color(float(b) / 255.0, 0.0, 0.0, 1.0))
				wrote += 1
			idx += 1
	if wrote > 0:
		texel_writes += wrote
		_food_tex.update(_food_image)
		texture_updates += 1
	return wrote


## Brings the Food texture to `game`'s food for its player: only while the mode is Food, and (unless `force`) only when
## `game.version` changed since the last time. Returns the texels written.
func sync_food(game: Game, force: bool = false) -> int:
	if _mode != MapModes.Mode.FOOD or game == null or game.map == null:
		return 0
	if not force and game.version == _food_version:
		return 0
	_food_version = game.version
	return update_food(MapModes.food_bytes(game, game.player))


## The Food bytes the texture holds now (a copy; tests).
func food_bytes() -> PackedByteArray:
	return _food_bytes.duplicate()


## Brings the Yields, Food and Supply textures to `game` (each only while its mode is showing) and the sight texture (always,
## when the game's version moved); returns the texels written.
func sync_modes(game: Game, force: bool = false) -> int:
	return sync_yields(game, force) + sync_food(game, force) + sync_supply(game, force) + sync_sight(game, force)


## The Yields bytes the texture holds now (a copy; tests).
func yields_bytes() -> PackedByteArray:
	return _yield_bytes.duplicate()


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


## Bytes of the two Yields textures (kept out of texture_bytes, the four of M2).
func yields_texture_bytes() -> int:
	var total := 0
	for img: Image in [_yields_image, _yield_ramp_image]:
		if img != null:
			total += img.get_data().size()
	return total


## Bytes of the two Food textures.
func food_texture_bytes() -> int:
	var total := 0
	for img: Image in [_food_image, _food_ramp_image]:
		if img != null:
			total += img.get_data().size()
	return total


func food_image() -> Image:
	return _food_image


func food_texture() -> ImageTexture:
	return _food_tex


func food_ramp_texture() -> ImageTexture:
	return _food_ramp_tex


func yields_image() -> Image:
	return _yields_image


func yields_texture() -> ImageTexture:
	return _yields_tex


func yield_ramp_texture() -> ImageTexture:
	return _yield_ramp_tex


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


## Turns the sight veil on or off (the map/sight_veil setting; MapScene.configure applies it): the uniform and the visibility.
func set_sight_veil(on: bool) -> void:
	_sight_veil_on = on
	if _material != null:
		_material.set_shader_parameter(&"sight_veil_on", _sight_veil_on)
	_update_visibility()


func is_sight_veil_on() -> bool:
	return _sight_veil_on


## Whether the palette in use is the colour-blind one (the accessibility/country_colours setting, set through MapScene).
func is_colour_blind() -> bool:
	return _colour_blind


## Writes the Supply texels that differ from `bytes` (one byte a hex, MapModes.supply_bytes) and uploads the texture once;
## returns how many texels it wrote (0, and no upload, when nothing differs or `bytes` is not one a hex).
func update_supply(bytes: PackedByteArray) -> int:
	if _map == null or _supply_image == null or _supply_tex == null or bytes.size() != _supply_bytes.size():
		return 0
	var wrote := 0
	var cols := _map.cols
	var idx := 0
	for row: int in _map.rows:
		for col: int in cols:
			var b := bytes[idx]
			if b != _supply_bytes[idx]:
				_supply_bytes[idx] = b
				_supply_image.set_pixel(col, row, Color(float(b) / 255.0, 0.0, 0.0, 1.0))
				wrote += 1
			idx += 1
	if wrote > 0:
		texel_writes += wrote
		_supply_tex.update(_supply_image)
		texture_updates += 1
	return wrote


## Brings the Supply texture to `game`'s supply for its player: only while the mode is Supply, and (unless `force`) only when
## `game.version` changed since the last time. Returns the texels written.
func sync_supply(game: Game, force: bool = false) -> int:
	if _mode != MapModes.Mode.SUPPLY or game == null or game.map == null:
		return 0
	if not force and game.version == _supply_version:
		return 0
	_supply_version = game.version
	return update_supply(MapModes.supply_bytes(game, game.player))


## Writes the sight texels that differ from `bytes` (one byte a hex, 1 seen; MapModes.sight_bytes) and uploads the texture
## once; returns how many texels it wrote.
func update_sight(bytes: PackedByteArray) -> int:
	if _map == null or _sight_image == null or _sight_tex == null or bytes.size() != _sight_bytes.size():
		return 0
	var wrote := 0
	var cols := _map.cols
	var idx := 0
	for row: int in _map.rows:
		for col: int in cols:
			var b := bytes[idx]
			if b != _sight_bytes[idx]:
				_sight_bytes[idx] = b
				_sight_image.set_pixel(col, row, Color(float(b) / 255.0, 0.0, 0.0, 1.0))
				wrote += 1
			idx += 1
	if wrote > 0:
		texel_writes += wrote
		_sight_tex.update(_sight_image)
		texture_updates += 1
	return wrote


## Brings the sight texture to `game`'s sight for its player whenever `game.version` changed (every mode: the veil is in
## all of them). Returns the texels written.
func sync_sight(game: Game, force: bool = false) -> int:
	if game == null or game.map == null or game.state == null:
		return 0
	if not force and game.version == _sight_version:
		return 0
	_sight_version = game.version
	return update_sight(MapModes.sight_bytes(game, game.player))


## The Supply bytes the texture holds now (a copy; tests).
func supply_bytes() -> PackedByteArray:
	return _supply_bytes.duplicate()


## The sight bytes the texture holds now (a copy; tests).
func sight_bytes() -> PackedByteArray:
	return _sight_bytes.duplicate()


## Bytes of the Supply textures (the supply map and its ramp) and of the sight texture.
func supply_texture_bytes() -> int:
	var total := 0
	for img: Image in [_supply_image, _supply_ramp_image, _sight_image]:
		if img != null:
			total += img.get_data().size()
	return total


func supply_image() -> Image:
	return _supply_image


func supply_texture() -> ImageTexture:
	return _supply_tex


func supply_ramp_texture() -> ImageTexture:
	return _supply_ramp_tex


func sight_image() -> Image:
	return _sight_image


func sight_texture() -> ImageTexture:
	return _sight_tex


func _draw() -> void:
	if _map_size.x > 0.0 and _map_size.y > 0.0:
		draw_rect(Rect2(Vector2.ZERO, _map_size), Color.WHITE)


func _sync_uniforms() -> void:
	if _material == null:
		return
	_material.set_shader_parameter(&"mode", int(_mode))
	_material.set_shader_parameter(&"tint_on", _tint_on)
	_material.set_shader_parameter(&"hot_id", _hot_id)
	_material.set_shader_parameter(&"sight_veil_on", _sight_veil_on)


func _update_visibility() -> void:
	visible = not (_mode == MapModes.Mode.TERRAIN and not _tint_on and not _sight_veil_on)


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
