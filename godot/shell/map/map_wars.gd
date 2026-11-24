## The war layer of the map (docs/architecture/m7-build-spec.md 6.3; M7 B25): the WarMarks (battle sites, sieges and the replay's
## badges), the castle-area lines and the overlay's area tint behind one gate (map/castle_areas, an army of yours selected, a war
## of yours), the hover card of a mark, the siege and battle ribbons, and the refresh on the war events. A child of the map scene,
## made by the scene's one-line hook beside MapArmies, as MapArmies is beside MapPeople. It reads the game through the core views
## and changes nothing in it. Settings reach it through configure(); until the App calls that (B28), the setting reads on.
class_name MapWars
extends Node

## The hover card's layer: over the map, under the HUD (10).
const CARD_LAYER := 8
const CARD_OFFSET := Vector2(20.0, 20.0)
const HOVER_CARD_SCENE := preload("res://shell/ui/hover_card.tscn")
const SETTING_AREAS := "map/castle_areas"
const SETTING_REDUCE := "accessibility/reduce_motion"
const FLOATERS := "Names/Floaters"

var _scene: MapScene = null
var _view: TileMapView = null
var _marks: WarMarks = null
var _card_layer: CanvasLayer = null
var _card: HoverCard = null
var _settings: Settings = null
var _links: Array[Array] = []
var _zoom := 0.0
var _area_on := false
var _area_key: Array = []
var _area_queue: Array[Vector2i] = []
var _replay_last: Array[Dictionary] = []
var _hold_last: Array = []
var _fog_rev := -1  # the player's explored revision the marks were built for (R37)


func _init() -> void:
	name = &"MapWars"  # the map scene finds it as $MapWars


func _ready() -> void:
	_scene = get_parent() as MapScene
	_view = _scene.view()
	_marks = WarMarks.new()
	_marks.name = "WarMarks"
	_marks.setup(_view)
	_scene.add_child(_marks)
	_link(_marks.site_clicked, _on_site_clicked)
	_card_layer = CanvasLayer.new()
	_card_layer.name = "WarCards"
	_card_layer.layer = CARD_LAYER
	add_child(_card_layer)
	_card = HOVER_CARD_SCENE.instantiate() as HoverCard
	_card.visible = false
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_layer.add_child(_card)
	var input := _scene.map_input()
	_link(input.select_requested, _on_select)
	_link(input.hover_changed, _on_hover)
	for sig: Signal in [Events.battle_started, Events.battle_joined, Events.battle_ended, Events.siege_started,
			Events.district_captured, Events.controllers_changed, Events.owners_changed, Events.war_declared,
			Events.peace_made, Events.season_ended, Events.game_started, Events.game_ended, Events.army_selected,
			Events.army_cleared]:
		_link(sig, _on_war_event)
	_link(Events.battle_fought, _on_battle_fought)
	_link(Events.siege_progress, _on_siege_progress)
	_link(Events.siege_lifted, _on_siege_lifted)
	_on_war_event()


func _exit_tree() -> void:
	for pair: Array in _links:
		var sig := pair[0] as Signal
		var fn := pair[1] as Callable
		if sig.is_connected(fn):
			sig.disconnect(fn)
	_links.clear()
	_disconnect_settings()
	if _area_on and is_instance_valid(_scene) and _scene.overlay() != null:
		_scene.overlay().set_areas_on(false)
	if is_instance_valid(_marks):
		_marks.queue_free()


func _link(sig: Signal, fn: Callable) -> void:
	sig.connect(fn)
	_links.append([sig, fn])


## Applies the setting map/castle_areas and accessibility/reduce_motion, and listens for their changes.
func configure(settings: Settings) -> void:
	_disconnect_settings()
	_settings = settings
	if _settings != null:
		_settings.changed.connect(_on_setting_changed)
	_marks.set_reduce_motion(_reduce_motion())
	_sync_gate()


func _disconnect_settings() -> void:
	if _settings != null and _settings.changed.is_connected(_on_setting_changed):
		_settings.changed.disconnect(_on_setting_changed)
	_settings = null


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key == SETTING_AREAS:
		_sync_gate()
	elif key == SETTING_REDUCE:
		_marks.set_reduce_motion(_reduce_motion())


func _process(_delta: float) -> void:
	if _scene == null:
		return
	if not is_equal_approx(_scene.zoom(), _zoom):
		_zoom = _scene.zoom()
		_marks.set_zoom(_zoom)
	_sync_fog()
	_sync_replay()
	_build_areas()


# --- the gate and the castle areas ------------------------------------------------------------------------------------


## The castle-area gate (spec 6.3): the setting is on, an army of the viewer is selected and the viewer is at war.
func area_gate() -> bool:
	if not _area_setting() or _scene.get_node_or_null("MapArmies") == null:
		return false
	if (_scene.get_node("MapArmies") as MapArmies).selected_army() < 0:
		return false
	var game := Session.game
	if game == null or not game.has_countries():
		return false
	return not Wars.enemies(game, Session.player_tag()).is_empty()


## Whether the castle-area lines are built and the tint is on.
func areas_on() -> bool:
	return _area_on


## The chunks whose area lines are built now (the view's area nodes); for tests.
func area_chunks() -> Array[Vector2i]:
	return _view.area_chunks()


## Brings the gate's state to the game: the overlay's tint and the lines follow it; the lines are rebuilt when the game changed.
func _sync_gate() -> void:
	var on := area_gate()
	if on != _area_on:
		_area_on = on
		_scene.overlay().set_areas_on(on)
		if not on:
			_area_queue.clear()
			_area_key = []
			_view.clear_areas()
			return
	if on:
		var key := _key_now()
		if key != _area_key:
			_area_key = key
			_queue_all()


func _key_now() -> Array:
	var game := Session.game
	return [game.version if game != null else -1, Session.player_tag(), _colour_blind()]


func _queue_all() -> void:
	_area_queue.clear()
	var map := Session.game.map
	var chunks_x := ceili(float(map.cols) / float(EdgeLines.CHUNK))
	var chunks_y := ceili(float(map.rows) / float(EdgeLines.CHUNK))
	for cy: int in chunks_y:
		for cx: int in chunks_x:
			_area_queue.append(Vector2i(cx, cy))


## Builds the queued chunks' area lines, a few per frame within the scene's slice (a chunk is never split).
func _build_areas() -> void:
	_build_until(_scene.slice_ms)


## Builds every queued chunk now (a test, a tool); the frame's slice does the same a few at a time.
func finish_areas() -> void:
	_build_until(1.0e9)


func _build_until(budget_ms: float) -> void:
	if _area_queue.is_empty():
		return
	var game := Session.game
	if game == null or game.map == null or not _area_on:
		_area_queue.clear()
		return
	var until := Time.get_ticks_usec() + int(budget_ms * 1000.0)
	var viewer := Session.player_tag()
	var palette := MapModes.palette(game, _colour_blind())
	while not _area_queue.is_empty():
		var chunk: Vector2i = _area_queue.pop_front()
		var lines := AreaLines.for_chunk(game, viewer, chunk)
		for line: Dictionary in lines:
			line["colour"] = _ink(palette, int(line["colour_id"]))
		_view.set_chunk_areas(chunk, lines)
		if Time.get_ticks_usec() >= until:
			break


func _ink(palette: PackedColorArray, id: int) -> Color:
	var base: Color = palette[clampi(id, 0, palette.size() - 1)]
	return Color(base.r, base.g, base.b, Tokens.AREA_INK_ALPHA)


func _area_setting() -> bool:
	return _settings == null or bool(_settings.get_value(SETTING_AREAS))


func _reduce_motion() -> bool:
	return _settings != null and bool(_settings.get_value(SETTING_REDUCE))


func _colour_blind() -> bool:
	return _scene.overlay().is_colour_blind()


# --- the discovery of the marks (R37) ---------------------------------------------------------------------------


## The player's explored revision (-1 with no game or player); it grows when a hex is discovered.
func _explored_rev() -> int:
	var game := Session.game
	if game == null or game.player == &"":
		return -1
	var c := Countries.by_tag(game, game.player)
	return game.sight.explored_revision(c.id) if c != null else -1


## The war marks follow the player's discovery: a newly discovered hex brings its marks back.
func _sync_fog() -> void:
	var rev := _explored_rev()
	if rev != _fog_rev:
		_fog_rev = rev
		_refresh_marks()


## The replay badges on discovered hexes only (R37).
func _discovered_only(marks: Array[Dictionary]) -> Array[Dictionary]:
	var game := Session.game
	var out: Array[Dictionary] = []
	for item: Dictionary in marks:
		if game == null or Knowledge.discovered(game, game.player, item["hex"] as Vector2i):
			out.append(item)
	return out


# --- the marks, the replay and the events -----------------------------------------------------------------------------


## The war marks follow the views (their own refresh) and the gate follows the game (a changed version rebuilds the lines).
func _on_war_event(_a: Variant = null, _b: Variant = null, _c: Variant = null, _d: Variant = null) -> void:
	_refresh_marks()
	_sync_gate()


## The battle and siege marks, held back (their battles' sites) while a movement replay runs (M7 B25: no spoiler).
func _refresh_marks() -> void:
	_marks.refresh(Session.game, Session.player_tag(), _palette(), _held_hexes())


func _held_hexes() -> Array:
	var replay := _replay_node()
	return replay.battle_hexes() if replay != null and replay.active() else []


func _replay_node() -> MoveReplay:
	return get_tree().get_first_node_in_group(MoveReplay.GROUP) as MoveReplay


func _army_selected() -> bool:
	var armies := _scene.get_node_or_null("MapArmies") as MapArmies
	return armies != null and armies.selected_army() >= 0


func _palette() -> PackedColorArray:
	return MapModes.palette(Session.game, _colour_blind()) if Session.game != null else PackedColorArray()


## The replay's battle badges: MoveReplay (found by its group) lists the battles whose tick has begun while it runs.
func _sync_replay() -> void:
	var replay := _replay_node()
	var list: Array[Dictionary] = []
	if replay != null and replay.active():
		list = _discovered_only(replay.marks())
	if list != _replay_last:
		_replay_last = list
		_marks.set_replay(list)
	var hold := _held_hexes()
	if hold != _hold_last:
		_hold_last = hold
		_refresh_marks()


## A lifted siege flashes only for the viewer's own siege (the tag is the viewer) or a hex the viewer sees: the siege object
## is gone by now, so nothing is read from it (no fog leak).
func _on_siege_lifted(hex: Vector2i, tag: StringName, _why: StringName) -> void:
	var game := Session.game
	var viewer := Session.player_tag()
	if game == null or viewer == &"":
		return
	if tag == viewer or Knowledge.sees(game, viewer, hex):
		_marks.flash_lifted(hex)


func _on_siege_progress(hex: Vector2i, _tag: StringName, _progress: int, _need: int) -> void:
	var game := Session.game
	if game == null:
		return
	var v := SiegeView.at(game, Session.player_tag(), hex)
	if v.is_empty():
		return
	_ribbon(hex, "Siege %d/%d" % [int(v.progress), int(v.need)], &"plain")


## A battle's men lost by the viewer's side ("−420 men") at `hex`, from the newest record of this season or the last.
func _on_battle_fought(hex: Vector2i) -> void:
	var game := Session.game
	var viewer := Session.player_tag()
	if game == null or viewer == &"":
		return
	var lost := men_lost(game, viewer, hex)
	if lost > 0:
		_ribbon(hex, "−%d men" % lost, &"bad")


## The men the viewer's side lost at `hex`: killed and wounded of the newest battle record there this season (or the last
## one) in which the viewer has a side; records the viewer cannot see or has no side in are passed over. 0 for none.
static func men_lost(game: Game, viewer: StringName, hex: Vector2i) -> int:
	var older := -1
	for i: int in range(game.battle_records.size() - 1, -1, -1):
		var r := game.battle_records[i]
		if r.hex != hex or (r.turn != game.turn and r.turn != game.turn - 1):
			continue
		var lost := _lost_in(game, viewer, r)
		if lost < 0:
			continue
		if r.turn == game.turn:
			return lost
		if older < 0:
			older = lost
	return maxi(older, 0)


## The viewer's side's killed and wounded in one record; -1 when the viewer may not see it or has no side in it.
static func _lost_in(game: Game, viewer: StringName, r: BattleRecord) -> int:
	var v := BattleView.of(game, viewer, r.id)
	if v.is_empty() or not bool(v.kept):
		return -1
	var side_key := str(v.viewer_side)
	if side_key == "":
		return -1
	var tags := (v.sides as Dictionary).get(side_key, []) as Array
	if tags.is_empty():
		return -1
	var side := (v.side as Dictionary).get(tags[0], {}) as Dictionary
	return int(side.get("killed", 0)) + int(side.get("wounded", 0))


func _ribbon(hex: Vector2i, text: String, tone: StringName) -> void:
	var game := Session.game
	if game != null and not Knowledge.discovered(game, game.player, hex):  # R37: no ribbon on an undiscovered hex
		return
	var floaters := _scene.get_node_or_null(FLOATERS) as Floaters
	if floaters != null:
		floaters.add_ribbon(hex, text, tone)


func _on_select(map_px: Vector2) -> void:
	_marks.click_hex(_view.hex_at(map_px))


func _on_site_clicked(record: int) -> void:
	Events.battle_mark_clicked.emit(record)


func _on_hover(hex: Vector2i) -> void:
	# One card per hex: with an army of yours selected the move card (MapHover) owns the hover; else a mark's war card.
	var card: Dictionary = _marks.card_at(hex) if hex != MapInput.NO_HEX and not _army_selected() else {}
	if card.is_empty():
		_card.show_card({})
		return
	_card.show_card(card)
	var screen := _view.get_global_transform_with_canvas() * _view.centre_of(hex)
	var card_size := _card.get_combined_minimum_size()
	var vp := get_viewport().get_visible_rect().size
	_card.position = Vector2(minf(screen.x + CARD_OFFSET.x, vp.x - card_size.x), minf(screen.y + CARD_OFFSET.y, vp.y - card_size.y))
