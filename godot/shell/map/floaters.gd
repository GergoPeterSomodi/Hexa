## Floating ribbons (docs/architecture/m3-build-spec.md 6.6): a PanelToast ribbon with a tone dot and the line's floating word
## (Begun, Finished, Built, Cancelled, Gained, Lost, Taken) rises from a hex when Events.chronicled brings the line (read
## through LogLines for the viewer). The ribbons are screen-space Controls in the map scene's Names layer, placed each
## frame from the hex's map position through the camera's transform, so they keep one size at every zoom.
##
## Motion (v0.2.2's): born BORN_ABOVE px above the hex, rising RISE px with an ease-out over LIFETIME; popping in within
## POP_TIME; scale SCALE_START to SCALE_PEAK to 1.0 in 0.14 s; fading from FADE_FROM. Ribbons at one hex start STAGGER s
## apart and sit STEP_DOWN px lower each. Caps: MAX_PER_HEX a hex and MAX_TOTAL in all (the oldest goes first). A ribbon is
## drawn only while wholly inside the view and clear of the dock. wait() freezes their clock while a modal is up; resume()
## lets it run. Reduce motion: no rise and no scale, a fade in place.
##
## MapScene calls setup(game), set_xform(), set_zoom(), set_view() and set_reduce_motion(); the App task adds the node.
## This node never changes the game.
class_name Floaters
extends Node2D

const RIBBON_SCENE := preload("res://shell/map/floater.tscn")
## Seconds a ribbon lives from its start; the rise takes all of it.
const LIFETIME := 1.1
## Pixels a ribbon rises (ease-out over LIFETIME).
const RISE := 40.0
## Pixels above the hex's centre where a ribbon is born.
const BORN_ABOVE := 28.0
## Pixels a ribbon sits lower than the one before it at the same hex.
const STEP_DOWN := 18.0
## Seconds between the starts of two ribbons at one hex.
const STAGGER := 0.3
## The pop-in: alpha 0 to 1 within this many seconds.
const POP_TIME := 0.06
const SCALE_START := 0.6
const SCALE_PEAK := 1.2
## The scale runs SCALE_START to SCALE_PEAK, then SCALE_PEAK to 1.0; together 0.14 s.
const SCALE_UP_TIME := 0.07
const SCALE_SETTLE_TIME := 0.07
## The fade-out starts at this age and ends at LIFETIME.
const FADE_FROM := 0.6
const MAX_PER_HEX := 3
const MAX_TOTAL := 16
## A land line (Gained, Lost) shows a ribbon on up to this many of its hexes.
const LAND_HEXES := 3
## A word that is only written in the log, never floated on the map (the owner does not want a flag for it).
const QUIET_WORD := "Begun"

var _game: Game = null
var _xform := Transform2D.IDENTITY
var _zoom := 1.0
var _view := Rect2()
var _dock := Rect2()
var _reduce_motion := false
var _waiting := false
var _clock := 0.0
## Held (the season and its movement replay run): new ribbons wait in _queued and rise when the hold is released (M6 6.4).
var _held := false
var _queued: Array[Dictionary] = []
## Live ribbons, oldest first: {node, hex, start (clock seconds), slot}.
var _ribbons: Array[Dictionary] = []


func _enter_tree() -> void:
	if not Events.chronicled.is_connected(_on_chronicled):
		Events.chronicled.connect(_on_chronicled)
	if not Events.game_started.is_connected(_on_game_changed):
		Events.game_started.connect(_on_game_changed)
	if not Events.game_ended.is_connected(_on_game_changed):
		Events.game_ended.connect(_on_game_changed)


func _exit_tree() -> void:
	if Events.chronicled.is_connected(_on_chronicled):
		Events.chronicled.disconnect(_on_chronicled)
	if Events.game_started.is_connected(_on_game_changed):
		Events.game_started.disconnect(_on_game_changed)
	if Events.game_ended.is_connected(_on_game_changed):
		Events.game_ended.disconnect(_on_game_changed)


## A game began or ended: its ribbons do not float over the next game.
func _on_game_changed() -> void:
	clear()


func _process(delta: float) -> void:
	advance(delta)


## The game whose lines are shown (null: none); the viewer is its player.
func setup(game: Game) -> void:
	_game = game


## Map to screen transform of the camera: a ribbon sits over the hex's centre, moved by this.
func set_xform(value: Transform2D) -> void:
	_xform = value
	_update()


## The camera's zoom. Ribbons keep their size at every zoom, so this changes nothing drawn.
func set_zoom(value: float) -> void:
	_zoom = value


func zoom() -> float:
	return _zoom


## The screen rectangle ribbons must sit inside (empty: the viewport) and the dock's rectangle they must stay clear of
## (empty: none).
func set_view(view: Rect2, dock: Rect2 = Rect2()) -> void:
	_view = view
	_dock = dock
	_update()


func set_reduce_motion(on: bool) -> void:
	_reduce_motion = on
	_update()


## A modal is up: the ribbons keep their place and their clock stops.
func wait() -> void:
	_waiting = true


## The modal closed: the ribbons' clock runs again.
func resume() -> void:
	_waiting = false


func is_waiting() -> bool:
	return _waiting


## Holds the new ribbons while a season and its replay run (on), and lets the held ones rise when released (off). A held
## ribbon is queued and counts as started (spawn returns true for it); the view and dock are checked when it rises.
func hold(on: bool) -> void:
	_held = on
	if on:
		return
	var queued := _queued
	_queued = []
	for item: Dictionary in queued:
		spawn(str(item["text"]), item["tone"] as StringName, item["hex"] as Vector2i)


func is_held() -> bool:
	return _held


## Advances the clock by `delta` seconds (unless waiting) and places every ribbon. _process calls it each frame.
func advance(delta: float) -> void:
	if not _waiting:
		_clock += delta
	_update()


## Starts a ribbon with `text` in the tone `tone` (good, plain, bad, muted) at `hex`. False when the hex is not in the view,
## is under the dock, or the text is empty. At most MAX_PER_HEX a hex and MAX_TOTAL in all: the oldest ribbon goes first.
func spawn(text: String, tone: StringName, hex: Vector2i) -> bool:
	if text.is_empty():
		return false
	if _held:
		_queued.append({"text": text, "tone": tone, "hex": hex})
		return true
	var screen := _xform * MapTiles.cell_centre(hex)
	if not _view_rect().has_point(screen) or (_dock.size != Vector2.ZERO and _dock.has_point(screen)):
		return false
	_make_room(hex)
	var start := maxf(_clock, _last_start_at(hex) + STAGGER)
	var node := RIBBON_SCENE.instantiate() as PanelContainer
	var word := node.get_node("HBox/Word") as Label
	word.text = text
	# The word keeps the width of its own text (and a little air), so a long line is never clipped at the ribbon's edge.
	var font := word.get_theme_font("font")
	if font != null:
		var size := word.get_theme_font_size("font_size")
		word.custom_minimum_size.x = ceilf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x) + 6.0
	(node.get_node("HBox/Dot") as ColorRect).color = _tone_color(tone)
	node.accessibility_name = text
	node.visible = false
	add_child(node)
	var ribbon := {"node": node, "hex": hex, "start": start, "slot": _free_slot(hex)}
	_ribbons.append(ribbon)
	_place(ribbon, _clock - start)
	return true


## Starts a ribbon of `text` in the tone `tone` at `hex`. This is the public way in: the chronicled path and the map
## scene's season ribbons call it. A quiet word (QUIET_WORD, and any word starting with it) is written in the log
## only and never floats. The limits are spawn's: 3 a hex, 16 in all, only hexes on the view and not under the dock;
## a modal waits them.
func add_ribbon(hex: Vector2i, text: String, tone: StringName) -> void:
	if text.begins_with(QUIET_WORD):
		return
	spawn(text, tone, hex)


## Ribbons alive now (waiting or not).
func live_count() -> int:
	return _ribbons.size()


## Ribbons alive on `hex`.
func count_at(hex: Vector2i) -> int:
	var n := 0
	for ribbon: Dictionary in _ribbons:
		if ribbon["hex"] == hex:
			n += 1
	return n


## Removes every ribbon at once.
func clear() -> void:
	for ribbon: Dictionary in _ribbons:
		_discard(ribbon["node"] as Node)
	_ribbons.clear()


## A chronicle entry arrived: its floating word (LogLines) starts a ribbon on each of its hexes. A land line
## (Gained, Lost) uses up to LAND_HEXES of the entry's hexes; the others use the line's own hex.
func _on_chronicled(entry: Dictionary) -> void:
	if _game == null:
		return
	var line := LogLines.line_of(_game, entry, _game.player)
	var word := str(line.get("floating", ""))
	if word.is_empty():
		return
	var tone := StringName(str(line.get("tone", "plain")))
	for hex: Vector2i in _hexes_for(entry, line, word):
		add_ribbon(hex, word, tone)


func _hexes_for(entry: Dictionary, line: Dictionary, word: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if word == "Gained" or word == "Lost":
		var listed: Variant = entry.get("hexes", [])
		if listed is Array:
			for item: Variant in listed as Array:
				if item is Vector2i and out.size() < LAND_HEXES:
					out.append(item as Vector2i)
	var own: Variant = line.get("hex", null)
	if out.is_empty() and own is Vector2i:
		out.append(own as Vector2i)
	return out


## Makes room for one more ribbon on `hex`: the oldest there goes while MAX_PER_HEX are alive, then the oldest of all
## while MAX_TOTAL are.
func _make_room(hex: Vector2i) -> void:
	while count_at(hex) >= MAX_PER_HEX:
		_drop(_first_at(hex))
	while _ribbons.size() >= MAX_TOTAL:
		_drop(0)


func _first_at(hex: Vector2i) -> int:
	for i: int in _ribbons.size():
		if _ribbons[i]["hex"] == hex:
			return i
	return 0


func _drop(index: int) -> void:
	_discard(_ribbons[index]["node"] as Node)
	_ribbons.remove_at(index)


## The latest start among the ribbons alive on `hex` (a large negative number when none).
func _last_start_at(hex: Vector2i) -> float:
	var latest := -1.0e9
	for ribbon: Dictionary in _ribbons:
		if ribbon["hex"] == hex:
			latest = maxf(latest, float(ribbon["start"]))
	return latest


## The lowest slot no live ribbon on `hex` holds, so a gap left by an expired ribbon is reused and two never share one.
func _free_slot(hex: Vector2i) -> int:
	var used := {}
	for ribbon: Dictionary in _ribbons:
		if ribbon["hex"] == hex:
			used[int(ribbon["slot"])] = true
	var slot := 0
	while used.has(slot):
		slot += 1
	return slot


## Places every ribbon for its age, drops the ones past LIFETIME.
func _update() -> void:
	var kept: Array[Dictionary] = []
	for ribbon: Dictionary in _ribbons:
		var age := _clock - float(ribbon["start"])
		if age >= LIFETIME:
			_discard(ribbon["node"] as Node)
			continue
		kept.append(ribbon)
	_spread(kept)
	for ribbon: Dictionary in kept:
		_place(ribbon, _clock - float(ribbon["start"]))
	_ribbons = kept


## Ribbons of neighbouring hexes can be wider than the hexes are apart (a far zoom), and one would sit on the end of the
## other's text ("Hunger -7,98" under the next plate). Each ribbon takes the first extra row (a plate's height lower) in
## which it does not overlap, sideways, a ribbon before it; the row count is written to ribbon["extra"].
func _spread(list: Array[Dictionary]) -> void:
	var placed: Array[Dictionary] = []  # {x, y, w} of the ribbons already settled
	for ribbon: Dictionary in list:
		var node := ribbon["node"] as PanelContainer
		var screen := _xform * MapTiles.cell_centre(ribbon["hex"] as Vector2i)
		var w := node.get_combined_minimum_size().x * SCALE_PEAK
		var h := node.get_combined_minimum_size().y
		var y := screen.y - BORN_ABOVE + float(ribbon["slot"]) * STEP_DOWN
		var extra := 0
		while extra < MAX_PER_HEX * 4:
			var clash := false
			for other: Dictionary in placed:
				if other["hex"] == ribbon["hex"]:
					continue  # one hex's ribbons stack by their slots
				if absf(float(other["y"]) - (y + float(extra) * h)) < h * 0.9 						and absf(float(other["x"]) - screen.x) < (float(other["w"]) + w) * 0.5:
					clash = true
					break
			if not clash:
				break
			extra += 1
		ribbon["extra"] = float(extra) * h
		placed.append({"hex": ribbon["hex"], "x": screen.x, "y": y + float(extra) * h, "w": w})


## Sets one ribbon's position, scale, alpha and visibility for `age` seconds since its start.
func _place(ribbon: Dictionary, age: float) -> void:
	var node := ribbon["node"] as PanelContainer
	var hex := ribbon["hex"] as Vector2i
	var screen := _xform * MapTiles.cell_centre(hex)
	var box := node.get_combined_minimum_size()
	node.pivot_offset = box * 0.5
	if age < 0.0:
		node.visible = false
		return
	var rise := 0.0
	var scale_now := 1.0
	if not _reduce_motion:
		rise = RISE * _ease_out(clampf(age / LIFETIME, 0.0, 1.0))
		scale_now = _scale_at(age)
	var fade := clampf((age - FADE_FROM) / (LIFETIME - FADE_FROM), 0.0, 1.0)
	var alpha := clampf(age / POP_TIME, 0.0, 1.0) * (1.0 - fade)
	var centre := Vector2(screen.x, screen.y - BORN_ABOVE + float(ribbon["slot"]) * STEP_DOWN + float(ribbon.get("extra", 0.0)) - rise)
	node.scale = Vector2.ONE * scale_now
	node.position = centre - box * 0.5
	node.modulate.a = alpha
	node.visible = alpha > 0.0 and _fits(centre, box)


## Whether a ribbon centred on `centre` with box `box` (at its largest scale) lies inside the view and clear of the dock.
func _fits(centre: Vector2, box: Vector2) -> bool:
	var half := box * SCALE_PEAK * 0.5
	var rect := Rect2(centre - half, half * 2.0)
	if not _view_rect().encloses(rect):
		return false
	return _dock.size == Vector2.ZERO or not _dock.intersects(rect)


func _view_rect() -> Rect2:
	if _view.size != Vector2.ZERO:
		return _view
	if is_inside_tree():
		return get_viewport().get_visible_rect()
	return Rect2()


func _scale_at(age: float) -> float:
	if age < SCALE_UP_TIME:
		return lerpf(SCALE_START, SCALE_PEAK, age / SCALE_UP_TIME)
	if age < SCALE_UP_TIME + SCALE_SETTLE_TIME:
		return lerpf(SCALE_PEAK, 1.0, (age - SCALE_UP_TIME) / SCALE_SETTLE_TIME)
	return 1.0


func _ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)


func _tone_color(tone: StringName) -> Color:
	match tone:
		&"good":
			return Tokens.GOOD
		&"bad":
			return Tokens.BAD
		&"muted":
			return Tokens.FAINT
	return Tokens.TEXT


func _discard(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.get_parent() == self:
		remove_child(node)
	node.free()
