## The war marks of the map (docs/architecture/m7-build-spec.md 6.3; M7 B25): one WarMark per battle site (BattleView.sites),
## one per siege (SiegeView.all) and the replay's battle badges (MoveReplay.marks, shown ones only) while the movement replay runs.
## refresh() adds, updates and frees the marks to match the views, so the fog is theirs: a battle the viewer may not see has no
## mark. z 89, under the selection. Below zoom 0.6 a mark keeps its screen size (set_zoom). A click on a battle mark emits
## site_clicked (the battle dock, through Events); the hover card is WarCards.site / WarCards.siege (card_at).
class_name WarMarks
extends Node2D

signal site_clicked(record: int)
signal siege_clicked(hex: Vector2i)

const LAYER_Z := 89
## The group MapHover asks whether a war card owns a hex (MapHover.war_mark_at, M7 B25).
const GROUP := &"war_marks"
## A battle badge sits this many map px above its hex's middle.
const BATTLE_LIFT := 30.0
## Below this zoom a mark keeps the screen size it has at this zoom.
const ZOOM_KEEP := 0.6
## The grey flash of a lifted siege (seconds; instant under reduce motion).
const FLASH_TIME := 0.6
const FLASH_TINT := Color(0.7, 0.7, 0.7, 1.0)
const BATTLE_PREFIX := "b"
const SIEGE_PREFIX := "s"
const REPLAY_PREFIX := "r"
const BADGE_BATTLE := &"badge_battle"
const BADGE_SIEGE := &"badge_siege"

var _view: TileMapView = null
var _nodes: Dictionary[String, WarMark] = {}
var _zoom := 1.0
var _reduce_motion := false
var _palette := PackedColorArray()


func _init() -> void:
	z_index = LAYER_Z
	add_to_group(GROUP)


func setup(view: TileMapView) -> void:
	_view = view


## Sets the reduce-motion setting (the flash is instant when it is on).
func set_reduce_motion(on: bool) -> void:
	_reduce_motion = on


## The marks on the map now (battle, siege and replay marks; a flash that is fading is not counted).
func mark_count() -> int:
	return _nodes.size()


## The mark at `hex`: the newest battle badge there, else the siege dial, else a replay badge; null for none.
func mark_at(hex: Vector2i) -> WarMark:
	var found: WarMark = null
	for key: String in _nodes:
		var mark := _nodes[key]
		if mark.hex != hex:
			continue
		if found == null or (mark.kind == WarMark.KIND_BATTLE and mark.record > found.record) or (found.kind == WarMark.KIND_REPLAY and mark.kind != WarMark.KIND_REPLAY):
			found = mark
	return found


## The battle mark of record `record`; null when it has none.
func battle_mark(record: int) -> WarMark:
	return _nodes.get(BATTLE_PREFIX + str(record), null) as WarMark


## The siege mark at `hex`; null when none.
func siege_mark(hex: Vector2i) -> WarMark:
	return _nodes.get(_siege_key(hex), null) as WarMark


## Brings the battle and siege marks to the views of `viewer` in `game`. `palette` colours the front bars (default: the
## standard palette of `game`). A battle at a hex in `hold` (a running replay's battles) has no badge until the replay ends.
## Null or an empty game clears them.
func refresh(game: Game, viewer: StringName, palette := PackedColorArray(), hold: Array = []) -> void:
	var want: Dictionary[String, Dictionary] = {}
	if game != null and game.map != null and _view != null:
		_palette = palette if not palette.is_empty() else MapModes.palette(game, false)
		for site: Dictionary in BattleView.sites(game, viewer):
			if hold.has(site["hex"]) or not Knowledge.discovered(game, viewer, site["hex"] as Vector2i):  # R37
				continue
			want[BATTLE_PREFIX + str(site["record"])] = _battle_fields(site)
		for siege: Dictionary in SiegeView.all(game, viewer):
			if not Knowledge.discovered(game, viewer, siege["hex"] as Vector2i):  # R37: no dial off the map of the player
				continue
			want[_siege_key(siege["hex"] as Vector2i)] = _siege_fields(siege)
	_sync(want, [BATTLE_PREFIX, SIEGE_PREFIX])


## The replay's battle badges: `marks` is MoveReplay.marks() ({hex, shown}); a battle the viewer may not see (shown false)
## shows no badge. An empty list takes them away.
func set_replay(marks: Array[Dictionary]) -> void:
	var want: Dictionary[String, Dictionary] = {}
	if _view != null:
		for item: Dictionary in marks:
			if not bool(item.get("shown", false)):
				continue
			var hex := item["hex"] as Vector2i
			want[REPLAY_PREFIX + _hex_text(hex)] = {"kind": WarMark.KIND_REPLAY, "hex": hex, "tone": &"plain"}
	_sync(want, [REPLAY_PREFIX])


## The grey flash of a siege that was lifted at `hex`: it fades out in FLASH_TIME, at once under reduce motion.
func flash_lifted(hex: Vector2i) -> void:
	if _view == null:
		return
	var flash := WarMark.new()
	flash.kind = WarMark.KIND_SIEGE
	flash.hex = hex
	flash.badge = _badge(BADGE_SIEGE)
	flash.modulate = FLASH_TINT
	flash.position = _view.centre_of(hex)
	flash.scale = Vector2.ONE * _scale_at(_zoom)
	add_child(flash)
	if _reduce_motion or SimClock.fixed():
		flash.queue_free()
		return
	var tween := flash.create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, FLASH_TIME)
	tween.tween_callback(flash.queue_free)


## Sets the camera's zoom: the marks keep their screen size below ZOOM_KEEP.
func set_zoom(value: float) -> void:
	_zoom = value
	for key: String in _nodes:
		_nodes[key].scale = Vector2.ONE * _scale_at(value)


## A click on the map at `hex`: a battle badge there emits site_clicked, a siege dial siege_clicked. True when one was hit.
func click_hex(hex: Vector2i) -> bool:
	var battle := _newest_battle_at(hex)
	if battle != null:
		site_clicked.emit(battle.record)
		return true
	if siege_mark(hex) != null:
		siege_clicked.emit(hex)
		return true
	return false


## The hover card of the mark at `hex` for the viewer (WarCards); {} when no mark is there or the viewer may not see it.
func card_at(hex: Vector2i) -> Dictionary:
	var game := Session.game
	var viewer := Session.player_tag()
	if game == null:
		return {}
	var battle := _newest_battle_at(hex)
	if battle != null:
		return WarCards.site(game, viewer, battle.record)
	if siege_mark(hex) != null:
		return WarCards.siege(game, viewer, hex)
	return {}


# --- private ----------------------------------------------------------------------------------------------------------


func _newest_battle_at(hex: Vector2i) -> WarMark:
	var found: WarMark = null
	for key: String in _nodes:
		var mark := _nodes[key]
		if mark.kind == WarMark.KIND_BATTLE and mark.hex == hex and (found == null or mark.record > found.record):
			found = mark
	return found


## Adds, updates and frees the marks whose key starts with one of `prefixes`, to match `want` (key -> fields).
func _sync(want: Dictionary[String, Dictionary], prefixes: Array) -> void:
	for key: String in _nodes.keys():
		if not _has_prefix(key, prefixes) or want.has(key):
			continue
		var gone := _nodes[key]
		_nodes.erase(key)
		remove_child(gone)
		gone.queue_free()
	for key: String in want:
		var fields := want[key]
		var mark: WarMark = _nodes.get(key, null) as WarMark
		if mark == null:
			mark = WarMark.new()
			_nodes[key] = mark
			add_child(mark)
		_apply(mark, fields)


func _apply(mark: WarMark, fields: Dictionary) -> void:
	mark.kind = fields["kind"] as StringName
	mark.hex = fields["hex"] as Vector2i
	mark.tone = fields.get("tone", &"plain") as StringName
	mark.record = int(fields.get("record", -1))
	mark.dial_done = int(fields.get("progress", 0))
	mark.need = maxi(int(fields.get("need", 1)), 1)
	mark.front = fields.get("front", PackedInt32Array([0, 0])) as PackedInt32Array
	mark.attacker_colour = _colour_of(int(fields.get("attacker_colour_id", -1)))
	mark.defender_colour = _colour_of(int(fields.get("defender_colour_id", -1)))
	mark.badge = _badge(BADGE_SIEGE if mark.kind == WarMark.KIND_SIEGE else BADGE_BATTLE)
	mark.position = _view.centre_of(mark.hex) + (Vector2(0.0, -BATTLE_LIFT) if mark.kind != WarMark.KIND_SIEGE else Vector2.ZERO)
	mark.scale = Vector2.ONE * _scale_at(_zoom)
	mark.queue_redraw()


func _battle_fields(site: Dictionary) -> Dictionary:
	return {"kind": WarMark.KIND_BATTLE, "hex": site["hex"], "tone": site["tone"], "record": site["record"],
		"front": site["front"], "attacker_colour_id": site["attacker_colour_id"], "defender_colour_id": site["defender_colour_id"]}


func _siege_fields(siege: Dictionary) -> Dictionary:
	return {"kind": WarMark.KIND_SIEGE, "hex": siege["hex"], "tone": siege["tone"], "progress": siege["progress"], "need": siege["need"]}


func _colour_of(id: int) -> Color:
	if id >= 0 and id < _palette.size():
		return _palette[id]
	return Tokens.MUTED


static func _scale_at(zoom_value: float) -> float:
	return ZOOM_KEEP / zoom_value if zoom_value > 0.0 and zoom_value < ZOOM_KEEP else 1.0


static func _siege_key(hex: Vector2i) -> String:
	return SIEGE_PREFIX + _hex_text(hex)


static func _hex_text(hex: Vector2i) -> String:
	return "%d_%d" % [hex.x, hex.y]


static func _has_prefix(key: String, prefixes: Array) -> bool:
	for prefix: Variant in prefixes:
		if key.begins_with(str(prefix)):
			return true
	return false


## The kit's badge texture: the project theme's, else the shipped Studiolo theme's; null when neither has it.
static func _badge(icon_name: StringName) -> Texture2D:
	var theme := ThemeDB.get_project_theme()
	if theme != null and theme.has_icon(icon_name, &"Kit"):
		return theme.get_icon(icon_name, &"Kit")
	if ResourceLoader.exists(KitTheme.THEME_PATH):
		var kit := load(KitTheme.THEME_PATH) as Theme
		if kit != null and kit.has_icon(icon_name, &"Kit"):
			return kit.get_icon(icon_name, &"Kit")
	return null
