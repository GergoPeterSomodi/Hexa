## The parchment map in the map scene (docs/architecture/map-overview-build-spec.md R16 to R18, R28, R29, D2, D4, D13): it
## drives ParchmentMap and ParchmentLabels from the scene's game, camera, mode and settings; as the parchment comes in it
## takes away what lies under it (the tile ground and lines, the far picture, the capital pennants, the tile view's
## country names and the place plates), and it tells the HUD when the parchment is solid (Events.map_parchment). Reach,
## the marks, the card's preview, the paths, the army tokens, the war marks and the floaters stay above at every alpha
## (R17); the next-season reach is hatched while it shows (ParchmentReach) and all reach keeps off unexplored hexes
## (MapArmies.follow_drawn_map). While map/parchment is on the tile view itself
## is never hidden: showing it again builds every tile layer (0.4 s on a large map), so its parts are switched instead.
## It holds no rules and changes no game.
class_name MapSceneParchment
extends RefCounted

var _scene: MapScene = null
var _map: ParchmentMap = null
var _names: ParchmentLabels = null
var _game: Game = null  # the game begun
var _names_stale := false  # the state changed since the names read it
var _running := false  # the scene's first frame has come: what is solid may be told
var _loading := false  # the game begun is still being put on the view
var _told := -1  # what Events.map_parchment last said (0 or 1), -1 nothing yet
var _reach := ParchmentReach.new()
# The looks: the scene's own switches and the settings it hears (what ParchmentMap is told).
var _tint := true
var _borders := true
var _colour_blind := false
var _high_contrast := false
var _enabled := true
var _text_size := 100


## `scene` is a Node for the reason MapSeasons gives: MapScene creates this helper in a member initialiser.
func _init(scene: Node) -> void:
	_scene = scene as MapScene


## The scene is ready: its two parchment nodes. Nothing shows until apply() says so.
func attach(map_node: ParchmentMap, names: ParchmentLabels) -> void:
	_map = map_node
	_names = names
	_names.set_alpha(0.0)
	_push_options()


## A new or loaded game (null: none). The geometry is queued for step(); the names read their facts here, on the loading
## path (a first reading of the country names takes a while on a large map).
func begin(game: Game) -> void:
	if _map == null:
		return
	_game = game
	_names_stale = false
	_loading = game != null
	_map.begin(game)
	_names.set_alpha(0.0)
	# A parchment nothing is to show (switched off, or the country pick) reads the names' facts when it first shows.
	_names.setup(game, wanted() and not _scene.picking())


func is_building() -> bool:
	return _map != null and _map.is_building()


## Whether the parchment is to be seen at some zoom now: switched on, or the Goods mode.
func wanted() -> bool:
	return _map != null and (_map.enabled() or _map.mode() == MapModes.Mode.GOODS)


## A loading frame's turn for the geometry, until `until` (SimClock.usec): `first` is the turn before the tiles, taken
## when the parchment is wanted; else it waits for the turn after them.
func load_step(until: int, first: bool) -> void:
	if first == wanted() and is_building() and SimClock.usec() < until:
		step(float(until - SimClock.usec()) / 1000.0)


## Builds the parchment's geometry for up to `budget_ms` milliseconds (at least one job).
func step(budget_ms: float) -> void:
	if _map != null:
		_map.step(budget_ms)


## Once a frame of `delta` seconds, before apply(): a cross-fade goes on and the textures follow what the viewer knows.
func tick(delta: float) -> void:
	if _map == null:
		return
	_running = true
	if Session.game == null:
		if _game != null:
			begin(null)
		return
	if _loading:
		# A large map loads over many frames, and the App places the camera after the last: that still switches at once.
		_map.settle()
		_loading = _scene.is_loading()
	_map.step_fade(delta)
	_map.sync(Session.game)


## Shows the parchment as the mode and the camera's zoom say, the far picture and the tile view as `far_zoom` says (the
## camera's, or 0 under the far lock), and hides what the parchment covers. Returns the parchment's alpha.
func apply(far_zoom: float) -> float:
	if _map == null:
		return 0.0
	var alpha := _map.apply_zoom(_scene.zoom(), _scene.camera_rig().fit_zoom())
	var solid := alpha >= 1.0
	if _names_stale and alpha > 0.0:
		_names_stale = false
		_names.refresh()
	_names.set_alpha(alpha)
	var tiles := _scene.far().apply_zoom(far_zoom, solid)  # decided once: the far picture is not shown and hidden again
	_apply_view(tiles, solid)
	_scene.view().set_lines_alpha(1.0 - alpha)
	_scene.capital_marks().set_covered(solid)
	_scene.country_labels().modulate.a = 1.0 - alpha
	_scene.labels().modulate.a = 1.0 - alpha
	MapLabelSync.block(_scene.labels(), _scene.country_labels())
	_scene.preview_marks().set_ghost_raised(alpha > 0.0)
	_reach.apply(_scene.view(), alpha, _scene.zoom(), _high_contrast)
	var armies := _scene.get_node_or_null(^"MapArmies") as MapArmies  # none before the scene is ready
	if armies != null:
		armies.follow_drawn_map()  # at once: no frame shows reach on the drawn map's unexplored paper
	_tell(solid)
	return alpha


## Lays the names out for the camera's view.
func relayout() -> void:
	if _map == null:
		return
	var camera := _scene.camera()
	var size := MapLabelSync.view_size(_scene.get_viewport_rect().size if _scene.is_inside_tree() else Vector2.ZERO)
	_names.relayout(MapLabelSync.transform_of(camera, size), camera.zoom.x, size)


## Land changed owner: the textures at once, the names at the next apply() that shows them.
func owners_changed(hexes: Array[Vector2i]) -> void:
	if _map == null:
		return
	_map.owners_changed(hexes)
	_names_stale = true


## Works, levels or a season changed the state (a town grows or declines within a season): the names read it again at
## the next apply() that shows them.
func state_changed() -> void:
	_names_stale = true


## The map mode on show and the Goods mode's good (a GameDefs good id).
func set_mode(mode: int, good_id: int) -> void:
	if _map == null:
		return
	_map.set_mode(mode)
	_names.set_mode(mode)
	set_good(good_id)


func set_good(good_id: int) -> void:
	if _map == null:
		return
	_map.set_good(good_id)
	_names.set_good(good_id)


## The scene's switches: map/owner_tint, map/borders and the colour-blind country colours.
func set_looks(tint: bool, borders: bool, colour_blind: bool) -> void:
	_tint = tint
	_borders = borders
	_colour_blind = colour_blind
	_push_options()


## map/parchment, high contrast, the text size and reduce motion.
func read_settings(settings: Settings) -> void:
	if _map != null:
		_map.set_instant(bool(settings.get_value("accessibility/reduce_motion")))
	_enabled = bool(settings.get_value("map/parchment"))
	_high_contrast = bool(settings.get_value("accessibility/high_contrast"))
	_text_size = int(settings.get_value("accessibility/text_size"))
	_push_options()


## The HUD's covering rects: the names keep clear of them.
func set_cover(rects: Array[Rect2]) -> void:
	if _names != null:
		_names.set_cover(rects)


func map_node() -> ParchmentMap:
	return _map


func names() -> ParchmentLabels:
	return _names


## The tile view under the parchment and the far picture: `tiles` is the far picture's answer (the tiles show at this
## zoom), `solid` the parchment's. The reach and the marks show with the tiles and over a solid parchment. With the
## parchment on the view stays shown and its parts are switched; with it off (the Goods mode aside) it is hidden at the
## far zoom as ever. One write each: showing the view builds every tile layer again.
func _apply_view(tiles: bool, solid: bool) -> void:
	var view := _scene.view()
	var marks := tiles or solid
	var enabled := _map.enabled()
	view.set_ground_shown((tiles or not enabled) and not solid)
	view.visible = enabled or marks
	for layer_name: String in TileMapView.OVERLAYS:
		var layer := view.layer(layer_name)
		if layer.visible != marks:
			layer.visible = marks


func _push_options() -> void:
	if _map == null:
		return
	_map.set_options(_tint, _borders, _colour_blind, _high_contrast, _enabled)
	_names.set_options(_text_size, _high_contrast)


## Says on the bus when the parchment becomes solid or stops being so; the first time in the scene's first frame, whatever
## it is (the HUD may still hold the word of the scene before).
func _tell(solid: bool) -> void:
	if not _running or _told == int(solid):
		return
	_told = int(solid)
	Events.map_parchment.emit(solid)
