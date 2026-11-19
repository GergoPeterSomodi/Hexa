## Country name labels in screen space (docs/architecture/m2-build-spec.md sections 6.1 and 6.4):
## sits in the Names CanvasLayer before MapLabels, draws upper-cased Cinzel TitlePanel text
## sized by region span and zoom, recomputed only on game_started and owners_changed and laid out
## only on CameraRig.view_changed (never every frame).
class_name CountryLabels
extends Node2D

const LAYER_Z := 95
const MIN_FONT_PX := 13
const MAX_FONT_PX := 40
const OUTLINE_PX := 4
const TEXT_ALPHA := 0.9
const TERRAIN_MAX_ZOOM := 0.9
## Gap (px) kept between a name and the window's edge or a covering HUD element.
const EDGE_GAP := 6.0

## Last country ids passed to CountryNames.places_of on owners_changed (for tests).
var last_recomputed_ids := PackedInt32Array()
## Count of _relayout() runs (for tests verifying no per-frame relayout).
var layout_count := 0

var _game: Game = null
var _entries: Array[Dictionary] = []
var _prev_owners := PackedByteArray()
var _placed: Array[Dictionary] = []
var _boxes: Array[Rect2] = []
var _mode: MapModes.Mode = MapModes.Mode.TERRAIN
var _picking := false
var _xform := Transform2D.IDENTITY
var _zoom := 1.0
var _vp_size := Vector2(1280.0, 720.0)
var _dirty := true
## Screen rects the HUD covers (top bar, dock, minimap, a screen's side list): names slide out of them or hide.
var _cover: Array[Rect2] = []
var _fallback_theme: Theme = null


func _init() -> void:
	z_index = LAYER_Z
	visible = false


## Computes the raw (unclamped-min) label size in px from region span, zoom, and letter count.
static func raw_font_size(span_px: float, zoom_val: float, letters: int) -> int:
	return roundi(0.6 * span_px * zoom_val / (0.62 * float(maxi(letters, 1))))


## Returns clamped label size in [13, 40], or 0 when under 13 px (hidden).
static func font_size_for(span_px: float, zoom_val: float, letters: int) -> int:
	var raw := raw_font_size(span_px, zoom_val, letters)
	if raw < MIN_FONT_PX:
		return 0
	return mini(raw, MAX_FONT_PX)


## Recomputes all country region entries for `game` (or clears when null / map-only).
func setup(game: Game) -> void:
	_game = game
	_entries.clear()
	_prev_owners = PackedByteArray()
	last_recomputed_ids = PackedInt32Array()
	if _game != null and _game.has_countries() and _game.state != null:
		_entries = CountryNames.places(_game)
		_prev_owners = _game.state.owner.duplicate()
	_dirty = true
	_relayout()


## Incrementally recomputes entries only for countries whose ownership changed on `hexes`.
func on_owners_changed(hexes: Array[Vector2i]) -> void:
	if _game == null or not _game.has_countries() or _game.map == null or _game.state == null:
		return
	if _prev_owners.size() != _game.state.owner.size():
		setup(_game)
		return
	var changed_map: Dictionary[int, bool] = {}
	for hex: Vector2i in hexes:
		var idx := _game.map.index_of(hex)
		if idx < 0 or idx >= _game.state.owner.size():
			continue
		var old_id := int(_prev_owners[idx])
		var new_id := int(_game.state.owner[idx])
		if old_id > 0:
			changed_map[old_id] = true
		if new_id > 0:
			changed_map[new_id] = true
		_prev_owners[idx] = new_id
	if changed_map.is_empty():
		return
	var keys: Array = changed_map.keys()
	keys.sort()
	var changed_ids := PackedInt32Array()
	changed_ids.resize(keys.size())
	for i: int in keys.size():
		changed_ids[i] = int(keys[i])
	last_recomputed_ids = changed_ids
	var fresh := CountryNames.places_of(_game, changed_ids)
	var merged: Array[Dictionary] = []
	var fresh_idx := 0
	for entry: Dictionary in _entries:
		var eid := int(entry["id"])
		if changed_map.has(eid):
			continue
		while fresh_idx < fresh.size() and int(fresh[fresh_idx]["id"]) < eid:
			merged.append(fresh[fresh_idx])
			fresh_idx += 1
		merged.append(entry)
	while fresh_idx < fresh.size():
		merged.append(fresh[fresh_idx])
		fresh_idx += 1
	_entries = merged
	_dirty = true
	_relayout()


func set_mode(mode: MapModes.Mode) -> void:
	if _mode == mode and not _dirty:
		return
	_mode = mode
	_dirty = true
	_relayout()


func set_picking(on: bool) -> void:
	if _picking == on and not _dirty:
		return
	_picking = on
	_dirty = true
	_relayout()


## Updates screen transform and zoom from CameraRig.view_changed (or fit/frame_at).
func set_view(to_screen: Transform2D, zoom_val: float, vp_size: Vector2 = Vector2.ZERO) -> void:
	var next_vp := vp_size if vp_size.x > 0.0 and vp_size.y > 0.0 else _vp_size
	if not _dirty and to_screen == _xform and is_equal_approx(zoom_val, _zoom) and next_vp == _vp_size:
		return
	_xform = to_screen
	_zoom = zoom_val
	_vp_size = next_vp
	_relayout()


## The HUD's covering rects in screen px (Hud.cover_rects). An empty list frees the whole window.
func set_cover(rects: Array[Rect2]) -> void:
	if rects == _cover and not _dirty:
		return
	_cover = rects.duplicate()
	_relayout()


func cover() -> Array[Rect2]:
	return _cover


## Whether country names should be displayed at the given mode, zoom, and picking state.
func should_show_at(mode: int, zoom_val: float, is_picking: bool) -> bool:
	if _game == null or not _game.has_countries():
		return false
	if is_picking or mode == MapModes.Mode.OWNER:
		return true
	if mode == MapModes.Mode.TERRAIN:
		return zoom_val < TERRAIN_MAX_ZOOM
	return false


func entries() -> Array[Dictionary]:
	return _entries


func placed() -> Array[Dictionary]:
	return _placed


func obstacles() -> Array[Rect2]:
	return _boxes


func _relayout() -> void:
	_dirty = false
	_placed.clear()
	_boxes.clear()
	layout_count += 1
	if not should_show_at(_mode, _zoom, _picking) or _entries.is_empty():
		visible = false
		queue_redraw()
		return
	var font := _resolve_font()
	var screen := Rect2(Vector2.ZERO, _vp_size)
	var free := screen.grow(-EDGE_GAP)
	for entry: Dictionary in _entries:
		var text := str(entry["text"])
		var upper := text.to_upper()
		var fs := font_size_for(float(entry["span_px"]), _zoom, text.length())
		if fs < MIN_FONT_PX:
			continue
		var screen_at := _xform * (entry["at"] as Vector2)
		var text_size := font.get_string_size(upper, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var ascent := font.get_ascent(fs)
		var descent := font.get_descent(fs)
		var box_h := maxf(text_size.y, ascent + descent)
		var top_left := screen_at - Vector2(text_size.x * 0.5, box_h * 0.5)
		var box := Rect2(top_left, Vector2(text_size.x, box_h))
		if box.intersects(screen):  # off-screen names stay put (they are culled when drawn)
			var max_shift := maxf(0.5 * float(entry["span_px"]) * _zoom, box_h)
			box = fit_free(box, free, _cover, max_shift)
			if not box.has_area():
				continue
		var shift := _resolve_overlap(box, _boxes)
		box.position += shift
		if shift != Vector2.ZERO and box.intersects(screen) and not _is_clear(box, free, _cover):
			continue
		_placed.append({
			"id": entry["id"],
			"tag": entry["tag"],
			"text": upper,
			"font_size": fs,
			"baseline": Vector2(box.position.x, box.position.y + ascent),
			"box": box,
		})
		_boxes.append(box)
	visible = not _placed.is_empty()
	queue_redraw()


## Moves `box` the least distance that puts it inside `free` and clear of every `cover` rect (with EDGE_GAP), at most
## `max_shift` px from where it was. Returns an empty Rect2 when no such place exists (the name hides).
static func fit_free(box: Rect2, free: Rect2, cover: Array[Rect2], max_shift: float) -> Rect2:
	if box.size.x > free.size.x or box.size.y > free.size.y:
		return Rect2()
	var clamped := _clamp_into(box, free)
	var candidates: Array[Rect2] = [clamped]
	for c: Rect2 in cover:
		var pad := c.grow(EDGE_GAP)
		if not pad.intersects(clamped):
			continue
		var p := clamped.position
		var s := clamped.size
		candidates.append(_clamp_into(Rect2(Vector2(pad.position.x - s.x, p.y), s), free))
		candidates.append(_clamp_into(Rect2(Vector2(pad.end.x, p.y), s), free))
		candidates.append(_clamp_into(Rect2(Vector2(p.x, pad.position.y - s.y), s), free))
		candidates.append(_clamp_into(Rect2(Vector2(p.x, pad.end.y), s), free))
	var best := Rect2()
	var best_d := INF
	for cand: Rect2 in candidates:
		if not _is_clear(cand, free, cover):
			continue
		var d := cand.position.distance_to(box.position)
		if d < best_d:
			best_d = d
			best = cand
	if best_d > max_shift:
		return Rect2()
	return best


static func _clamp_into(box: Rect2, free: Rect2) -> Rect2:
	var x := clampf(box.position.x, free.position.x, free.end.x - box.size.x)
	var y := clampf(box.position.y, free.position.y, free.end.y - box.size.y)
	return Rect2(Vector2(x, y), box.size)


static func _is_clear(box: Rect2, free: Rect2, cover: Array[Rect2]) -> bool:
	if not free.encloses(box):
		return false
	for c: Rect2 in cover:
		if c.grow(EDGE_GAP).intersects(box):
			return false
	return true


static func _resolve_overlap(box: Rect2, taken: Array[Rect2]) -> Vector2:
	if not _intersects_any(box, taken):
		return Vector2.ZERO
	var step := box.size.y + 4.0
	for mult: int in [1, 2, 3]:
		for sign_y: float in [-1.0, 1.0]:
			var offset := Vector2(0.0, sign_y * step * float(mult))
			if not _intersects_any(Rect2(box.position + offset, box.size), taken):
				return offset
	return Vector2.ZERO


static func _intersects_any(box: Rect2, taken: Array[Rect2]) -> bool:
	var padded := box.grow(float(OUTLINE_PX) * 1.5)
	for other: Rect2 in taken:
		if padded.intersects(other):
			return true
	return false


func _draw() -> void:
	if not visible or _placed.is_empty():
		return
	var font := _resolve_font()
	var text_col := Color(Tokens.TEXT, TEXT_ALPHA)
	var screen := Rect2(Vector2.ZERO, _vp_size).grow(120.0) if _vp_size.x > 0.0 and _vp_size.y > 0.0 else Rect2()
	for item: Dictionary in _placed:
		var box := item["box"] as Rect2
		if screen.has_area() and not screen.intersects(box):
			continue
		var baseline := item["baseline"] as Vector2
		var upper := str(item["text"])
		var fs := int(item["font_size"])
		draw_string_outline(font, baseline, upper, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, OUTLINE_PX, Tokens.INK)
		draw_string(font, baseline, upper, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_col)


func _resolve_font() -> Font:
	if is_inside_tree():
		var win := get_window()
		if win != null and win.theme != null and win.theme.has_font(&"font", &"TitlePanel"):
			return win.theme.get_font(&"font", &"TitlePanel")
	var proj := ThemeDB.get_project_theme()
	if proj != null and proj.has_font(&"font", &"TitlePanel"):
		return proj.get_font(&"font", &"TitlePanel")
	if _fallback_theme == null and ResourceLoader.exists(KitTheme.THEME_PATH):
		_fallback_theme = load(KitTheme.THEME_PATH) as Theme
	if _fallback_theme != null and _fallback_theme.has_font(&"font", &"TitlePanel"):
		return _fallback_theme.get_font(&"font", &"TitlePanel")
	return ThemeDB.fallback_font
