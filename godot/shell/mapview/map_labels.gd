## The names of the places on screen (docs/architecture/m1-build-spec.md section 5, layer "names", z 100): a dark rounded
## plate under each place, sized by the place's level, placed without overlaps (the collision placement of the prototype's
## WorldLabels, adapted: a plate tries the spot below its hex first, then above, then to the sides, and is dropped when
## none is free; the great places are placed first, so on a conflict the smaller name goes). It holds no facts: the places
## are read from MapData, the hexes' pixels from MapTiles, and the screen position from the viewport's canvas transform,
## so it follows the camera by itself.
##
## OFF by default (owner, 2026-11-15: no plates on the normal map for now). Key N (via MapInput -> MapScene) or
## set_visible(bool) turns it on and off, and `toggled(on)` tells whoever listens. Put it in a CanvasLayer above the map
## (screen space).
class_name MapLabels
extends Control

signal toggled(on: bool)

## Plate padding (px) round the text, and the gap between a hex's middle and its plate.
const PAD_X := 7.0
const PAD_Y := 2.0
const GAP := 9.0
## Half the size of the box a place keeps clear of other plates (the hex's middle).
const MARKER_HALF := 5.0
const TEXT_COLOUR := Color(0.98, 0.965, 0.918)
const PLATE_MAJOR := Color(0.118, 0.141, 0.220, 0.91)
const PLATE_MINOR := Color(0.204, 0.227, 0.290, 0.84)
const GOLD := Color(0.839, 0.729, 0.431)
## Where a plate may sit, in order: below, above, right, left, then the four corners.
enum Spot { BELOW, ABOVE, RIGHT, LEFT, BELOW_RIGHT, BELOW_LEFT, ABOVE_RIGHT, ABOVE_LEFT }
const SPOTS: Array[int] = [Spot.BELOW, Spot.ABOVE, Spot.RIGHT, Spot.LEFT, Spot.BELOW_RIGHT, Spot.BELOW_LEFT,
	Spot.ABOVE_RIGHT, Spot.ABOVE_LEFT]

## Boxes in screen px the plates keep off (the hex panel, the top bar...): the scene sets them.
var obstacles: Array[Rect2] = []

var _map: MapData = null
var _capitals: Array[Vector2i] = []
var _use_game_capitals := false
var _placed: Array[Dictionary] = []
var _last_transform := Transform2D()
var _last_size := Vector2.ZERO
var _dirty := true
var _major: StyleBoxFlat = null
var _minor: StyleBoxFlat = null
var _capital: StyleBoxFlat = null
## The state the settlement levels come from (set_state), and each settlement place's level by hex (levels_of).
var _state: MapState = null
var _levels: Dictionary = {}


func _init() -> void:
	visible = false  # off by default
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	_major = _box(PLATE_MAJOR, null)
	_minor = _box(PLATE_MINOR, null)
	_capital = _box(PLATE_MAJOR, GOLD)


func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)


## The map whose places are named. When `capitals` is provided, capital styling comes from that list
## (use MapLabels.capitals_from(game) in M2); otherwise falls back to MapData.places[].capital.
func setup(map: MapData, capitals_list: Variant = null) -> void:
	_map = map
	_capitals.clear()
	if capitals_list is Array:
		_use_game_capitals = true
		for h: Variant in (capitals_list as Array):
			if h is Vector2i:
				_capitals.append(h as Vector2i)
	else:
		_use_game_capitals = false
	_sync_levels()
	_dirty = true
	queue_redraw()


## Sets explicit capital hexes from the active Game and forces a relayout.
func set_capitals(capitals_list: Array[Vector2i]) -> void:
	_capitals = capitals_list.duplicate()
	_use_game_capitals = true
	_dirty = true
	queue_redraw()


## Returns the active explicit capital hexes (empty when using MapData.places[].capital or map-only).
func capitals() -> Array[Vector2i]:
	return _capitals.duplicate()


## Updates screen-space obstacle boxes (e.g. CountryLabels) and refreshes when changed.
func set_obstacles(boxes: Array[Rect2]) -> void:
	if obstacles == boxes:
		return
	obstacles = boxes.duplicate()
	refresh()


## Extracts on-map capital hexes from the alive countries of `game`.
static func capitals_from(game: Game) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if game == null or not game.has_countries():
		return out
	for country: Country in game.countries:
		if country != null and country.alive and country.capital != Country.NO_HEX:
			out.append(country.capital)
	return out


## Forces a new layout at the next frame (a place was added, a panel moved).
func refresh() -> void:
	_dirty = true


## The map's state (the game's MapState). A place on a settlement hex takes its level from the state; the other
## places keep MapData.places[].level. The plates are relaid only when a label's level changed (the same state
## again, or a state with the same levels, costs nothing). null goes back to the data's levels.
func set_state(state: MapState) -> void:
	_state = state
	_sync_levels()


## Recomputes the settlement levels from the state; refreshes the plates when one of them changed.
func _sync_levels() -> void:
	var fresh := levels_of(_map, _state)
	var changed := fresh.size() != _levels.size()
	if not changed:
		for hex: Vector2i in fresh:
			if int(_levels.get(hex, -1)) != int(fresh[hex]):
				changed = true
				break
	_levels = fresh
	if changed:
		refresh()


## What is placed now: [{name, level, capital, hex, box (screen px)}], great places first.
func placed() -> Array[Dictionary]:
	return _placed


func _on_visibility_changed() -> void:
	_dirty = true
	set_process(visible)
	queue_redraw()
	toggled.emit(visible)


func _process(_delta: float) -> void:
	if not visible or _map == null:
		return
	var xform := get_viewport().get_canvas_transform()
	var screen := get_viewport_rect().size
	if _dirty or xform != _last_transform or screen != _last_size:
		_last_transform = xform
		_last_size = screen
		_dirty = false
		var cap_override: Variant = _capitals if _use_game_capitals else null
		_placed = layout(_map, xform, Rect2(Vector2.ZERO, screen), ThemeDB.fallback_font, obstacles, cap_override,
			_levels)
		queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var font := ThemeDB.fallback_font
	for item: Dictionary in _placed:
		var box: Rect2 = item["box"]
		var level := int(item["level"])
		var plate := _capital if bool(item["capital"]) or level >= 4 else (_major if level >= 2 else _minor)
		draw_style_box(plate, box)
		var fs := font_size(level)
		draw_string(font, box.position + Vector2(PAD_X, PAD_Y + font.get_ascent(fs)), str(item["name"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TEXT_COLOUR)


static func _box(fill: Color, edge: Variant) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.set_corner_radius_all(8)
	if edge != null:
		s.border_color = edge as Color
		s.set_border_width_all(1)
	return s


## The font size of a name by its place's level: the great city largest, the hamlet smallest.
static func font_size(level: int) -> int:
	if level >= 5:
		return 17
	if level == 4:
		return 15
	if level == 3:
		return 13
	if level == 2:
		return 12
	return 11


## The places of `map` that are on screen, with their plates placed. `to_screen` carries map px (MapTiles.cell_centre) to
## screen px, `screen` is the area the plates must stay in, `blocked` the boxes they keep off. When `capitals_override`
## is provided (an Array of capital Vector2i hexes), capital status comes from that set instead of MapData.places[].capital.
## Returns [{name, level, capital, hex, box}] in placing order (rank: level, capital first, then by name).
## `levels` (hex to level, see levels_of) replaces the data's level of a place on a settlement hex.
static func layout(map: MapData, to_screen: Transform2D, screen: Rect2, font: Font,
		blocked: Array[Rect2], capitals_override: Variant = null, levels: Dictionary = {}) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var taken: Array[Rect2] = blocked.duplicate()
	var cap_set: Dictionary[Vector2i, bool] = {}
	var has_cap_override := capitals_override is Array
	if has_cap_override:
		for c: Variant in (capitals_override as Array):
			if c is Vector2i:
				cap_set[c as Vector2i] = true
	var reach := screen.grow(40.0)
	for place: Dictionary in map.places:
		var hex: Vector2i = place["hex"]
		var at: Vector2 = to_screen * MapTiles.cell_centre(hex)
		if not reach.has_point(at):
			continue
		taken.append(Rect2(at - Vector2(MARKER_HALF, MARKER_HALF), Vector2(MARKER_HALF, MARKER_HALF) * 2.0))
		var label := str(place.get("name", ""))
		if label == "":
			continue
		var level := int(levels[hex]) if levels.has(hex) else int(place.get("level", 0))
		var fs := font_size(level)
		var text := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var is_cap := cap_set.has(hex) if has_cap_override else bool(place.get("capital", false))
		items.append({"name": label, "level": level, "capital": is_cap, "hex": hex, "at": at,
			"size": Vector2(text.x + 2.0 * PAD_X, text.y + 2.0 * PAD_Y)})
	return _place(items, taken, screen)


## The level of each settlement place by hex, read from `state`: where the hex's main use is a settlement
## (ImproveRules.SETTLEMENT) the state's level. Empty without a map or a state; a place off the map is skipped.
static func levels_of(map: MapData, state: MapState) -> Dictionary:
	var out: Dictionary = {}
	if map == null or state == null:
		return out
	for place: Dictionary in map.places:
		var hex: Vector2i = place["hex"]
		var i := map.index_of(hex)
		if i < 0 or i >= state.main_use.size() or i >= state.level.size():
			continue
		if int(state.main_use[i]) == ImproveRules.SETTLEMENT:
			out[hex] = int(state.level[i])
	return out


## The collision placement: by rank, each plate takes the first free spot inside `bounds`.
static func _place(items: Array[Dictionary], taken: Array[Rect2], bounds: Rect2) -> Array[Dictionary]:
	var order := items.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ra := int(a["level"]) * 10 + (5 if bool(a["capital"]) else 0)
		var rb := int(b["level"]) * 10 + (5 if bool(b["capital"]) else 0)
		if ra != rb:
			return ra > rb
		return str(a["name"]) < str(b["name"]))
	var placed: Array[Dictionary] = []
	for item: Dictionary in order:
		var chosen := Rect2()
		for spot: int in SPOTS:
			var box := box_at(spot, item["at"] as Vector2, item["size"] as Vector2)
			if not bounds.encloses(box):
				continue
			var clear := true
			for other: Rect2 in taken:
				if other.intersects(box):
					clear = false
					break
			if clear:
				chosen = box
				break
		if chosen.size == Vector2.ZERO:
			continue
		taken.append(chosen)
		placed.append({"name": item["name"], "level": item["level"], "capital": item["capital"], "hex": item["hex"],
			"box": chosen})
	return placed


## The box of a plate of `size` at a spot round the point `at`.
static func box_at(spot: int, at: Vector2, size: Vector2) -> Rect2:
	var x := at.x - size.x / 2.0
	var y := at.y + GAP
	match spot:
		Spot.ABOVE:
			y = at.y - GAP - size.y
		Spot.RIGHT:
			x = at.x + GAP
			y = at.y - size.y / 2.0
		Spot.LEFT:
			x = at.x - GAP - size.x
			y = at.y - size.y / 2.0
		Spot.BELOW_RIGHT:
			x = at.x + GAP * 0.5
		Spot.BELOW_LEFT:
			x = at.x - GAP * 0.5 - size.x
		Spot.ABOVE_RIGHT:
			x = at.x + GAP * 0.5
			y = at.y - GAP - size.y
		Spot.ABOVE_LEFT:
			x = at.x - GAP * 0.5 - size.x
			y = at.y - GAP - size.y
	return Rect2(Vector2(x, y), size)
