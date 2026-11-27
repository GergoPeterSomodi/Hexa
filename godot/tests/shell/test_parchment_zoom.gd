## The parchment's switch through the real camera rig (docs/architecture/map-overview-build-spec.md D2, R17, amended
## 2026-11-27 after the owner's playtest): the wheel and Fit at the slowest, default and fastest zoom speed with the
## rig's clamping and easing; a large map; what the panels and a hidden HUD do to the free area; and what a new or a
## loaded game starts on. Each planted case (P) shows that a check has something to find.
extends GutTest

const MAP_SCENE := preload("res://shell/map/map_scene.tscn")
const APP_SCENE := preload("res://shell/app/app.tscn")
const GEN := &"GEN"
const SCREEN := Vector2i(1920, 1080)
const PARCHMENT := "parchment"
const TILES := "tiles"
## For each zoom speed (%): the wheel notches from the whole map to the parchment, from the limit back to the tiles, and
## from the whole map to the limit.
const NOTCHES: Dictionary[int, Vector3i] = {50: Vector3i(4, 4, 7), 100: Vector3i(2, 2, 4), 200: Vector3i(1, 1, 2)}

var _harness: UIHarness = null
var _settings: Settings = null
var _scene: MapScene = null
var _prev_game: Game = null
var _told: Array[bool] = []


func before_each() -> void:
	Bindings.reset_defaults()
	_prev_game = Session.game
	_harness = UIHarness.new(SCREEN)
	_harness.mount(self)
	_settings = _harness.settings
	_told.clear()
	Events.map_parchment.connect(_on_told)
	assert_eq(Session.new_scenario("north_italy_1480", 1480, GEN), "")


func after_each() -> void:
	Events.map_parchment.disconnect(_on_told)
	_scene = null
	_harness = null
	_settings = null
	Session.game = _prev_game
	Bindings.reset_defaults()


func _on_told(solid: bool) -> void:
	_told.append(solid)


## A map scene in the harness's view, configured with the settings, two frames old.
func _open() -> void:
	_scene = MAP_SCENE.instantiate() as MapScene
	_scene.preload_next_season = false
	_scene.configure(_settings)
	_harness.viewport.add_child(_scene)
	_scene.finish_loading()
	await _harness.wait_frames(self, 2)


## Frames the middle of the map at a zoom, lets a frame pass and spends a second of time (a cross-fade ends).
func _at(zoom: float) -> void:
	_scene.frame_at(_scene.map_size() / 2.0, zoom)
	await _harness.wait_frames(self, 2)
	_scene._process(1.0)


func _fit_zoom() -> float:
	return _scene.camera_rig().fit_zoom()


## The zoom-out limit, past the whole-map view.
func _limit() -> float:
	return _scene.camera_rig().min_zoom()


## What the scene shows whole: the solid parchment, the tiles (or their far picture), or something of both.
func _side() -> String:
	var parchment := _scene.parchment()
	var names := _scene.parchment_names()
	if parchment.visible and names.visible and not parchment.is_fading() and not _scene.view().ground_shown():
		return PARCHMENT
	if not parchment.visible and not names.visible:
		return TILES
	return "between"


## One wheel event on the camera rig, as the player turns the wheel with the pointer at the screen's middle.
func _wheel(out: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_DOWN if out else MOUSE_BUTTON_WHEEL_UP
	event.pressed = true
	event.position = Vector2(_harness.viewport.size) / 2.0
	_scene.camera_rig()._unhandled_input(event)


## Steps the rig and the scene frame by frame until the eased zoom has arrived, then ends any cross-fade. Returns the
## frames it took.
func _ease() -> int:
	var rig := _scene.camera_rig()
	var frames := 0
	while rig.zoom() != float(Vector2(rig.target_zoom(), 0.0).x) and frames < 200:
		rig._process(1.0 / 60.0)
		_scene._process(1.0 / 60.0)
		frames += 1
	assert_lt(frames, 200, "the zoom arrives")
	_scene._process(1.0)
	return frames


## The Fit button's call.
func _fit() -> void:
	_scene.fit()
	_scene._process(1.0)


func test_the_wheel_and_fit_through_the_camera_rig_at_every_zoom_speed() -> void:
	await _open()
	var rig := _scene.camera_rig()
	assert_true(rig.zoom_smoothing and not rig.reduce_motion, "the zoom is eased")
	for speed: int in NOTCHES:
		assert_true(_settings.set_value("controls/zoom_speed", speed))
		var notch := ZoomModel.notch_factor(float(speed))
		var to_parchment: int = NOTCHES[speed].x
		var to_tiles: int = NOTCHES[speed].y
		var to_limit: int = NOTCHES[speed].z
		_fit()
		assert_eq(_side(), TILES, "Fit, at %d %%" % speed)
		for k: int in range(1, to_limit + 1):
			var what := "%d notches out at %d %%" % [k, speed]
			_wheel(true)
			assert_gt(_ease(), 1, "it took frames")
			assert_almost_eq(_scene.zoom(), maxf(_fit_zoom() / pow(notch, k), _limit()), 0.0001, what)
			assert_eq(_side(), PARCHMENT if k >= to_parchment else TILES, what)
		assert_almost_eq(_scene.zoom(), _limit(), 0.0001, "clamped at the limit, at %d %%" % speed)
		_wheel(true)
		_ease()
		assert_almost_eq(_scene.zoom(), _limit(), 0.0001, "no farther, at %d %%" % speed)
		for k: int in range(1, to_tiles + 1):
			var what := "%d notches in from the limit at %d %%" % [k, speed]
			_wheel(false)
			_ease()
			assert_almost_eq(_scene.zoom(), _limit() * pow(notch, k), 0.0001, what)
			assert_eq(_side(), TILES if k >= to_tiles else PARCHMENT, what)
		for _i: int in to_limit:
			_wheel(true)
		_ease()
		assert_eq(_side(), PARCHMENT)
		_fit()
		assert_eq(_side(), TILES, "Fit from the parchment, at %d %%" % speed)
		assert_almost_eq(_scene.zoom(), ZoomModel.fit_zoom(Vector2(SCREEN), _scene.map_size()), 0.0001, "the fit as before")


## The made-up large map: its fit is far under north Italy's, and the switch lies inside the camera's range.
func test_a_large_map_reaches_the_parchment_only_past_its_whole_view() -> void:
	await _open()
	var map := FakeMap.build(494, 247, 1480)  # the made-up Europe's size
	Session.start_game(Game.with_state(map, MapState.create(map)))
	_scene.finish_loading()
	await _harness.wait_frames(self, 3)
	_fit()
	var fit := _fit_zoom()
	assert_lt(fit, 0.05, "far under the old floor of 0.28")
	assert_between(fit * ParchmentSwitch.PARCHMENT_UNDER_FIT, _limit(), fit, "the switch is inside the camera's range")
	assert_eq(_side(), TILES, "the whole map")
	assert_true(_scene.far().visible, "as the tiles' far picture")
	_wheel(true)
	_ease()
	assert_eq(_side(), TILES, "one notch out")
	assert_true(_scene.far().visible)
	for k: int in [2, 3]:
		_wheel(true)
		_ease()
		assert_eq(_side(), PARCHMENT, "%d notches out" % k)
		assert_false(_scene.far().visible)
	for _i: int in 3:
		_wheel(false)
	_ease()
	assert_eq(_side(), TILES, "and back")


## The HUD hidden and shown moves the free area and so the fit (the only panel that does): what shows is kept, also
## where, at 1280 x 720, the new ratio lies past a threshold.
func test_a_change_of_the_free_area_flips_nothing_by_itself() -> void:
	_harness.viewport.size = Vector2i(1280, 720)
	await _open()
	var rig := _scene.camera_rig()
	var shown := Rect2(0.0, 56.0, 1280.0, 664.0)
	var hidden := Rect2(0.0, 0.0, 1280.0, 720.0)
	rig.set_free_rect(shown)
	_fit()
	await _harness.wait_frames(self, 2)
	var fit := _fit_zoom()
	await _toggle([hidden, shown], TILES, "at the whole map")
	assert_almost_eq(_scene.zoom(), fit, 0.0001)
	await _at(fit * 0.85)
	await _toggle([hidden], TILES, "a little past one notch")
	assert_lt(_scene.zoom() / _fit_zoom(), ParchmentSwitch.PARCHMENT_UNDER_FIT, "P: by the ratio alone: parchment")
	await _toggle([shown], TILES, "and shown again")
	await _at(_limit())
	await _toggle([hidden, shown], PARCHMENT, "at the limit")
	rig.set_free_rect(hidden)
	await _at(_limit())
	await _at(_fit_zoom() * 0.79)
	await _toggle([shown], PARCHMENT, "zoomed in a little from the limit")
	assert_gt(_scene.zoom() / _fit_zoom(), ParchmentSwitch.TILES_FROM_FIT, "P: by the ratio alone: tiles")
	_fit()
	assert_eq(_side(), TILES, "Fit shows the tiles")


## A large map loads over many frames, and the App places the camera after the last of them: at once, no fade.
func test_a_large_map_shows_what_its_zoom_says_at_once_after_loading() -> void:
	await _open()
	var map := FakeMap.build(80, 60, 3)  # sliced over frames
	for share: float in [0.75, 1.0]:
		Session.start_game(Game.with_state(map, MapState.create(map)))
		var frames := 0
		while _scene.is_loading() and frames < 2000:
			await get_tree().process_frame
			frames += 1
		assert_between(frames, 3, 1999, "the load took frames")
		_scene.frame_at(_scene.map_size() / 2.0, _fit_zoom() * share)  # as a load restores the saved camera
		assert_eq(_scene.parchment().visible, share < 1.0, "%s of the fit" % share)
		assert_false(_scene.parchment().is_fading(), "at once at %s of the fit" % share)
	await _harness.wait_frames(self, 4)
	_scene.frame_at(_scene.map_size() / 2.0, _limit())
	_scene._process(0.125)
	assert_true(_scene.parchment().is_fading(), "loaded: a zoom crossing fades again")


## Gives the rig each free area in turn and expects `side` after every one.
func _toggle(areas: Array[Rect2], side: String, what: String) -> void:
	for area: Rect2 in areas:
		_scene.camera_rig().set_free_rect(area)
		await _harness.wait_frames(self, 2)
		_scene._process(1.0)
		assert_eq(_side(), side, "%s, %s" % [what, area])


# ----- the whole App --------------------------------------------------------------------------------------------------


## The App on Genoa with `settings`, its game on the screen.
func _start_app(settings: Settings) -> App:
	var app := APP_SCENE.instantiate() as App
	app.settings_path = ""
	app.allow_tree_quit = false
	app.pause_tree_when_modal = false
	app.cli_args_override = PackedStringArray(["--new-game", "--country=GEN", "--seed=1480"])
	app.set_settings_override(settings)
	_harness.viewport.add_child(app)
	for _i: int in 600:
		if app.map_scene() != null and app.stack().count() == 0 and not app.is_starting():
			break
		await get_tree().process_frame
	await _harness.wait_frames(self, 4)
	_scene = app.map_scene()
	return app


## At the whole map and past it: the zoom card's readout and buttons, the minus and plus keys (two notches a press), the
## minimap's view box and a pan at the limit.
func test_in_the_app_the_zoom_card_the_keys_and_the_minimap_at_the_limit() -> void:
	var ai := Session.ai_enabled
	Session.ai_enabled = false
	var s := Settings.new("macOS", true)
	for pair: Array in [["state/help_seen", true], ["graphics/preload_next_season", false], ["game/autosave", "off"],
			["accessibility/reduce_motion", true]]:
		s.set_value(pair[0], pair[1])
	var app: App = await _start_app(s)
	var card := app.hud().zoom_control()
	var fit := _fit_zoom()
	assert_almost_eq(_scene.zoom(), fit, 0.0001)
	assert_false(card.zoom_out_button().disabled, "the whole map is not the limit")
	_harness.send_key(KEY_MINUS)
	_harness.send_key(KEY_MINUS, false)
	await _harness.wait_frames(self, 3)
	assert_almost_eq(_scene.zoom(), fit / pow(1.15, 2.0), 0.0001, "a press is two notches")
	assert_eq(_side(), PARCHMENT)
	card.zoom_out_button().pressed.emit()
	await _harness.wait_frames(self, 3)
	assert_almost_eq(_scene.zoom(), fit * ZoomModel.MIN_MARGIN, 0.0001, "the limit")
	assert_true(card.zoom_out_button().disabled)
	assert_false(card.zoom_in_button().disabled)
	assert_eq(card.readout_button().text, "%d%%" % roundi(_scene.zoom() * 100.0))
	var minimap := app.hud().minimap()
	var corner := minimap.map_to_px(Vector2.ZERO)
	var whole := Rect2(corner, minimap.map_to_px(_scene.map_size()) - corner)
	var box := minimap.frame_rect()
	assert_true(box.position.distance_to(whole.position) < 0.5 and box.end.distance_to(whole.end) < 0.5,
		"the view box is the whole map: %s in %s" % [box, whole])
	_scene.camera_rig().pan_by(Vector2(500.0, -300.0))
	await _harness.wait_frames(self, 3)
	assert_eq(_scene.camera().position, Vector2(_scene.map_size() * 0.5), "the map stays centred")
	_harness.send_key(KEY_EQUAL)
	_harness.send_key(KEY_EQUAL, false)
	await _harness.wait_frames(self, 3)
	assert_eq(_side(), TILES, "plus: two notches in")
	card.fit_button().pressed.emit()
	await _harness.wait_frames(self, 3)
	assert_almost_eq(_scene.zoom(), fit, 0.0001, "Fit as before")
	app.free()
	Session.end_game()
	Session.ai_enabled = ai
	RenderingServer.set_default_clear_color(MapScene.SEA_COLOUR)


## Opens and closes the tile window and the country panel, then hides and shows the HUD; the parchment stays as it was
## and nothing is told on the way.
func _panels_flip_nothing(app: App, side: String) -> void:
	var flips := _told.size()
	var area := _scene.camera_rig().free_rect
	_scene.select_hex(Countries.by_tag(Session.game, GEN).capital)
	await _harness.wait_frames(self, 4)
	assert_true(app.hud().is_dock_open(), "the tile window is open")
	assert_eq(_scene.camera_rig().free_rect, area, "it takes none of the camera's free area")
	app.hud().close_dock()
	_scene.select_hex(MapScene.NO_HEX)
	app.hud().show_country(GEN, false)
	await _harness.wait_frames(self, 4)
	assert_eq(_scene.camera_rig().free_rect, area, "nor does the country panel")
	app.hud().close_dock()
	for shown: bool in [false, true]:
		app.hud().set_hud_visible(shown)
		await _harness.wait_frames(self, 4)
		assert_eq(_scene.camera_rig().free_rect == area, shown, "P: the HUD hidden does move it")
		assert_eq(_side(), side, "HUD shown: %s" % shown)
	assert_eq(_told.size(), flips, "and nothing flipped on the way")


## Panels at the whole map, at a zoom where hiding the HUD takes the ratio past a threshold, and at the limit; then a
## save made at the limit and one made at the whole map, each loaded from the other view with the cross-fade on.
func test_in_the_app_panels_flip_nothing_and_a_load_starts_on_its_zoom() -> void:
	var old_dir := Session.save_dir
	var old_lock := RunLock.path
	var ai := Session.ai_enabled
	Session.ai_enabled = false
	Session.save_dir = "user://test_parchment_zoom_saves"
	RunLock.path = "user://test_parchment_zoom_running.lock"
	_harness.viewport.size = Vector2i(1280, 720)
	var s := Settings.new("macOS", true)
	for pair: Array in [["state/help_seen", true], ["graphics/preload_next_season", false], ["game/autosave", "off"],
			["accessibility/reduce_motion", true]]:
		s.set_value(pair[0], pair[1])
	var app: App = await _start_app(s)
	_scene.camera_rig().fit()  # (a small window's new game opens closer, on the capital)
	await _harness.wait_frames(self, 3)
	assert_eq(_side(), TILES, "the whole map")
	await _panels_flip_nothing(app, TILES)
	await _at(_fit_zoom() * 0.85)
	await _panels_flip_nothing(app, TILES)
	_scene.camera_rig().zoom_by(-8.0)
	await _harness.wait_frames(self, 3)
	assert_almost_eq(_scene.zoom(), _limit(), 0.0001)
	assert_eq(_side(), PARCHMENT, "the limit")
	await _panels_flip_nothing(app, PARCHMENT)
	s.set_value("accessibility/reduce_motion", false)  # a crossing fades now: a load must not
	for at_limit: bool in [true, false]:
		_scene = app.map_scene()
		await _at(_limit() if at_limit else _fit_zoom())
		var saved := _scene.zoom()
		SaveFile.remove(SaveRows.QUICK_SLOT, Session.save_dir)
		_harness.send_key(KEY_F5)
		_harness.send_key(KEY_F5, false)
		for _i: int in 600:
			if SaveFile.read_header(SaveRows.QUICK_SLOT, Session.save_dir)["state"] == &"ok":
				break
			await get_tree().process_frame
		await _at(_fit_zoom() if at_limit else _limit())
		assert_eq(_side(), TILES if at_limit else PARCHMENT, "the other view before the load")
		var before := _scene
		await app.launch("Reading the save", "Reading the save...",
			func() -> String: return Session.load_game(SaveRows.QUICK_SLOT), true)
		_scene = app.map_scene()
		assert_ne(_scene, before, "a new scene")
		assert_almost_eq(_scene.zoom(), saved, 0.0001, "the saved camera")
		assert_eq(_scene.parchment().visible, at_limit, "a load starts on what its zoom says")
		assert_false(_scene.parchment().is_fading(), "at once")
	app.free()
	Session.end_game()
	for slot: String in SaveFile.SLOTS + SaveFile.AUTO_SLOTS:
		SaveFile.remove(slot, Session.save_dir)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Session.save_dir))
	RunLock.clear()
	Session.save_dir = old_dir
	RunLock.path = old_lock
	Session.ai_enabled = ai
	RenderingServer.set_default_clear_color(MapScene.SEA_COLOUR)
