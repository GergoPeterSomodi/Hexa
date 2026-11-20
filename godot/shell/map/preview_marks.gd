## The map's marks while a card is open (docs/architecture/m4-build-spec.md 6.6; a World child at z 82): a GHOST of the piece
## (translucent, its layers from MapCells.piece_cells and the season's TileSet, z 75), a TINT of the hexes whose output changes
## (MapModes.delta_colour: good green, bad red) and LABELS ("+16 timber") on those hexes. They come and go with
## show_preview and clear_marks; they write no cell of TileMapView's layers (the ghost has layers of its own, made on show and
## freed on clear), draw in map space (so they follow zoom and pan) and take no input. Shown nothing: no nodes, no redraws.
class_name PreviewMarks
extends Node2D

const LAYER_Z := 82
const GHOST_Z := 75
const GHOST_ALPHA := 0.55
## At most this many labels (the biggest changes first).
const MAX_LABELS := 7
const FONT_SIZE := 16
const OUTLINE := 3
## The labels keep their size on the screen as the map zooms out: FONT_SIZE / zoom map px, at most this many times FONT_SIZE.
const MAX_LABEL_SCALE := 2.5
## The parts of a piece the ghost leaves out (the shadow layers have their own material in the view).
const SKIP := ["piece_shadow", "addon_shadow"]
## The radius of a hex of the map's lattice (a pointy-top hexagon CELL.x wide).
const HEX_RADIUS := float(MapTiles.CELL.x) / 1.7320508

var _view: TileMapView = null
var _enabled := true
var _zoom := 1.0
var _ghost: CanvasGroup = null
var _layers: Array[TileMapLayer] = []
var _tint: Array[Dictionary] = []  # {hex, colour}
var _labels: Array[Dictionary] = []  # {hex, text, delta}


func _init() -> void:
	z_index = LAYER_Z


## The view whose TileSet the ghost uses.
func setup(view: TileMapView) -> void:
	if _view != null and _view.season_swapped.is_connected(_on_season_swapped):
		_view.season_swapped.disconnect(_on_season_swapped)
	_view = view
	if _view != null:
		_view.season_swapped.connect(_on_season_swapped)


## false (the setting game/preview_on_map): nothing is drawn, and what is drawn goes.
func set_enabled(on: bool) -> void:
	_enabled = on
	if not on:
		clear_marks()


## The camera's zoom: the labels keep their size on the screen. Redraws only when something is shown.
func set_zoom(value: float) -> void:
	if is_equal_approx(value, _zoom):
		return
	_zoom = value
	if not _labels.is_empty():
		queue_redraw()


## Draws a card's preview: `preview` is ImprovePreview's dictionary (ghost {hex, tiles}, map_marks {hex: {delta, label}}).
## The marks of the card before go. Nothing is drawn when the setting is off or the card has no marks.
func show_preview(preview: Dictionary) -> void:
	clear_marks()
	if not _enabled or _view == null:
		return
	_make_ghost(preview.get("ghost", {}) as Dictionary)
	_make_marks(preview.get("map_marks", {}) as Dictionary)
	if not _tint.is_empty() or not _labels.is_empty():
		queue_redraw()


## Takes everything off the map: the ghost's layers are freed, nothing is drawn.
func clear_marks() -> void:
	var had := not _tint.is_empty() or not _labels.is_empty()
	_tint.clear()
	_labels.clear()
	_layers.clear()
	if _ghost != null:
		remove_child(_ghost)
		_ghost.free()
		_ghost = null
	if had:
		queue_redraw()


## Whether anything is shown.
func shown() -> bool:
	return _ghost != null or not _tint.is_empty() or not _labels.is_empty()


func ghost_layers() -> Array[TileMapLayer]:
	return _layers


## {hex, colour} of each tinted hex.
func tinted() -> Array[Dictionary]:
	return _tint


## {hex, text, delta} of each label.
func labels() -> Array[Dictionary]:
	return _labels


func _make_ghost(ghost: Dictionary) -> void:
	var tiles: Dictionary = ghost.get("tiles", {})
	if tiles.is_empty() or not ghost.has("hex"):
		return
	var hex: Vector2i = ghost["hex"]
	_ghost = CanvasGroup.new()
	_ghost.name = "Ghost"
	_ghost.z_as_relative = false
	_ghost.z_index = GHOST_Z
	_ghost.self_modulate = Color(1.0, 1.0, 1.0, GHOST_ALPHA)
	add_child(_ghost)
	for layer_name: String in MapCells.LAYERS:  # (the order of the view's layers)
		if SKIP.has(layer_name) or not tiles.has(layer_name):
			continue
		var at := _view.tile_source(str(tiles[layer_name]), hex)
		if at == TileMapView.NO_TILE:
			continue
		var layer := TileMapLayer.new()
		layer.name = layer_name.to_pascal_case()
		layer.tile_set = _view.tileset()
		layer.scale = _layer_scale()
		layer.set_cell(hex, at.x, Vector2i(at.y, at.z))
		_ghost.add_child(layer)
		_layers.append(layer)
	if _layers.is_empty():
		remove_child(_ghost)
		_ghost.free()
		_ghost = null


func _make_marks(marks: Dictionary) -> void:
	var rows: Array[Dictionary] = []
	for key: Variant in marks:
		var one: Dictionary = marks[key]
		var delta := int(one.get("delta", 0))
		var hex: Vector2i = key
		if delta != 0:
			_tint.append({"hex": hex, "colour": MapModes.delta_colour(delta)})
		var text := str(one.get("label", ""))
		if text != "":
			rows.append({"hex": hex, "text": text, "delta": delta})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return absi(int(a["delta"])) > absi(int(b["delta"])) or (absi(int(a["delta"])) == absi(int(b["delta"])) and (a["hex"] as Vector2i) < (b["hex"] as Vector2i)))
	for k: int in mini(rows.size(), MAX_LABELS):
		_labels.append(rows[k])


## A season swap gave the view a new TileSet: the ghost takes it (the cells' source ids are the same in every season).
func _on_season_swapped() -> void:
	for layer: TileMapLayer in _layers:
		layer.tile_set = _view.tileset()
		layer.scale = _layer_scale()
		layer.update_internals()


## The scale of the view's layers (2 for the half-size textures).
func _layer_scale() -> Vector2:
	return Vector2(2.0, 2.0) if _view.is_half() else Vector2.ONE


func _draw() -> void:
	for one: Dictionary in _tint:
		var centre := MapTiles.cell_centre(one["hex"] as Vector2i)
		var corners := PackedVector2Array()
		for k: int in 6:
			var angle := deg_to_rad(30.0 + 60.0 * float(k))
			corners.append(centre + Vector2(cos(angle), sin(angle)) * HEX_RADIUS)
		draw_colored_polygon(corners, one["colour"] as Color)
	if _labels.is_empty():
		return
	var font := ThemeDB.fallback_font
	var theme := ThemeDB.get_project_theme()
	if theme != null and theme.get_font(&"font", &"Label") != null:
		font = theme.get_font(&"font", &"Label")
	var size := int(round(float(FONT_SIZE) * clampf(1.0 / maxf(_zoom, 0.01), 1.0, MAX_LABEL_SCALE)))
	for one: Dictionary in _labels:
		var text := str(one["text"])
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var centre := MapTiles.cell_centre(one["hex"] as Vector2i)
		var base := Vector2(centre.x - width / 2.0, centre.y + float(size) * 0.35)
		var colour := Tokens.GOOD if int(one["delta"]) > 0 else (Tokens.BAD if int(one["delta"]) < 0 else Tokens.TEXT)
		draw_string_outline(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, OUTLINE, Tokens.INK)
		draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)
