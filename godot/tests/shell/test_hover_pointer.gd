## The hovered hex is the hex under the pointer (issues 479 and 480; moves-build-spec.md R62: V acts at the order cursor after
## Alt+arrows, else the hovered hex): after a selection change, and after a camera move under a resting pointer (a pan by key
## or drag, a zoom, a glide such as a walk's follow), the route, the move card and V use it. The keyboard's order cursor is not
## taken over by a camera move, and a pointer on a panel hovers nothing. The App with real events on the shell's fixed clock;
## Savoy's 1480 game, the hexes of test_waypoints.gd. Every case names its planted fault (P).
extends GutTest

const APP_SCENE := preload("res://shell/app/app.tscn")
const SAV := &"SAV"
const TURIN := Vector2i(5, 9)
const SUSA := Vector2i(4, 9)
const EAST := Vector2i(6, 9)
const PINEROLO := Vector2i(4, 10)
## A second army's place, south of Turin.
const SOUTH_ARMY := Vector2i(5, 11)
const FRAME_LIMIT := 600

var _vp: SubViewport = null
var _app: App = null
var _scene: MapScene = null
var _army: Army = null
var _old_save_dir := ""
var _old_lock_path := ""
var _prev_game: Game = null


func before_each() -> void:
	Bindings.reset_defaults()
	SimClock.reset()
	SimClock.step_s = 1.0 / 60.0
	_prev_game = Session.game
	_old_save_dir = Session.save_dir
	_old_lock_path = RunLock.path
	Session.ai_enabled = false
	Session.save_dir = "user://test_hover_pointer_saves"
	RunLock.path = "user://test_hover_pointer_running.lock"


func after_each() -> void:
	Session.end_game()
	for slot: String in SaveFile.SLOTS + SaveFile.AUTO_SLOTS:
		SaveFile.remove(slot, Session.save_dir)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Session.save_dir))
	RunLock.clear()
	SimClock.step_s = -1.0
	Session.save_dir = _old_save_dir
	RunLock.path = _old_lock_path
	Session.game = _prev_game
	Bindings.reset_defaults()
	RenderingServer.set_default_clear_color(MapScene.SEA_COLOUR)


# ----- the app --------------------------------------------------------------------------------------------------------------


## The game up in its own viewport, an army of Savoy on Turin selected, the camera framing Turin.
func _start() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(1280, 720)
	_vp.gui_disable_input = false
	add_child_autofree(_vp)
	_app = APP_SCENE.instantiate() as App
	_app.settings_path = ""
	_app.allow_tree_quit = false
	_app.pause_tree_when_modal = false
	_app.cli_args_override = PackedStringArray(["--new-game", "--country=SAV", "--seed=1480"])
	var s := Settings.new("macOS", true)
	s.set_value("state/help_seen", true)
	s.set_value("graphics/preload_next_season", false)
	s.set_value("game/autosave", "off")
	s.set_value("game/movement", "instant")
	_app.set_settings_override(s)
	_vp.add_child(_app)
	var up := func() -> bool: return _app.map_scene() != null and _app.stack().count() == 0 and not _app.is_starting()
	assert_true(await _wait_until(up, 3000), "the game is up")
	await _frames(3)
	_scene = _app.map_scene()
	_army = _new_army(TURIN)
	assert_true(_armies().select_army(_army.id))
	_scene.frame_at(_scene.view().centre_of(TURIN), 1.0)
	await _frames(10)


func _new_army(hex: Vector2i) -> Army:
	var a := ArmyFixture.army(Session.game, SAV, hex, 0, 2)
	Session.game.version += 1
	_armies().sync()
	return a


func _armies() -> MapArmies:
	return _scene.get_node("MapArmies") as MapArmies


func _frames(count: int) -> void:
	for _i: int in count:
		SimClock.tick()
		await get_tree().process_frame


func _wait_until(done: Callable, limit: int = FRAME_LIMIT) -> bool:
	var frames := 0
	while not bool(done.call()) and frames < limit:
		await _frames(1)
		frames += 1
	return bool(done.call())


## The camera at rest: no glide and no zoom step for a few frames.
func _settle() -> void:
	var camera := _scene.camera()
	var last := [Vector2.INF, 0.0]
	var still := 0
	for _i: int in FRAME_LIMIT:
		await _frames(1)
		var now := [camera.position, camera.zoom.x]
		still = still + 1 if now == last else 0
		last = now
		if still >= 5:
			return
	fail_test("the camera never came to rest")


func _screen_of(hex: Vector2i) -> Vector2:
	return _scene.view().get_global_transform_with_canvas() * _scene.view().centre_of(hex)


## The hex under the screen point `at`, as the camera stands now.
func _under(at: Vector2) -> Vector2i:
	return _scene.view().hex_at(_scene.map_input().map_px_of(at))


func _motion(at: Vector2, held: MouseButtonMask = 0 as MouseButtonMask) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = at
	ev.global_position = at
	ev.button_mask = held
	_vp.push_input(ev)


func _button(at: Vector2, button: MouseButton, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.position = at
	ev.global_position = at
	ev.pressed = pressed
	_vp.push_input(ev)


## The key of `action`, down or up.
func _key(action: StringName, pressed: bool) -> void:
	var ev := Bindings.events_for(action)[0].duplicate() as InputEventKey
	ev.pressed = pressed
	_vp.push_input(ev)


func _tap(action: StringName) -> void:
	_key(action, true)
	_key(action, false)
	await _frames(2)


## The route, the move card and V all take `hex` for the selected army `a`.
func _assert_all_use(hex: Vector2i, a: Army, what: String) -> void:
	assert_ne(hex, a.hex, "%s: a hex the army does not stand on" % what)
	assert_true(bool(MovePreview.to(Session.game, SAV, a.id, hex).verdict.ok), "%s: %s can be marched to" % [what, hex])
	assert_eq(_scene.map_input().current_hover(), hex, "%s: the hover" % what)
	var points := _armies().route_marks().points()
	assert_eq(points.back() if not points.is_empty() else Vector2.INF, _scene.view().centre_of(hex), "%s: the route" % what)
	var card := _app.hud().map_hover().move_card()
	assert_eq(card.title_text() if card.is_open() else "", Words.place(Session.game, hex), "%s: the move card" % what)
	await _tap(&"map_waypoint_key")
	assert_eq(_bound_for(a), hex, "%s: V" % what)


## Where `a` is bound after an order: its march's goal, or where it stands (it walked there at once).
func _bound_for(a: Army) -> Vector2i:
	return a.goal if a.order == Army.ORDER_MARCH else a.hex


# ----- 479: a selection change ----------------------------------------------------------------------------------------------


func test_v_after_another_army_is_selected_orders_the_hex_under_the_resting_pointer() -> void:
	await _start()
	var second := _new_army(SOUTH_ARMY)
	var at := _screen_of(SUSA)
	_motion(at)
	await _frames(2)
	assert_true(_armies().select_army(second.id))  # the army panel's and the report's way: no pointer move
	await _frames(2)
	_motion(at + Vector2(3.0, 0.0))  # and a move within the same hex changes nothing of it
	await _frames(2)
	await _assert_all_use(SUSA, second, "P: a selection that forgets the hovered hex")


func test_v_after_tab_orders_the_hex_under_the_pointer_after_the_glide() -> void:
	await _start()
	var second := _new_army(SOUTH_ARMY)
	var at := _screen_of(SUSA)
	_motion(at)
	await _frames(2)
	await _tap(&"game_next_unit")
	await _settle()
	assert_eq(_armies().selected_army(), second.id, "Tab took the other army")
	var hex := _under(at)
	assert_ne(hex, SUSA, "the glide moved the map under the pointer")
	await _assert_all_use(hex, second, "P: a Tab after which V reads the army's own hex or the old one")


func test_v_after_tab_with_no_camera_move_orders_the_hovered_hex() -> void:
	await _start()
	var at := _screen_of(SUSA)
	_motion(at)
	await _frames(2)
	await _tap(&"game_next_unit")  # one army: the same one again, already in view
	await _settle()
	await _assert_all_use(_under(at), _army, "P: a Tab that forgets the hovered hex")


# ----- 480: the camera moves under a resting pointer ------------------------------------------------------------------------


func test_a_key_pan_moves_the_hover_to_the_hex_now_under_the_pointer() -> void:
	await _start()
	var at := _screen_of(TURIN)
	_motion(at)
	await _frames(2)
	_key(&"cam_pan_right", true)
	assert_true(await _wait_until(func() -> bool: return _under(at) == EAST, 120), "panned a hex east")
	_key(&"cam_pan_right", false)
	await _settle()
	await _assert_all_use(_under(at), _army, "P: a pan after which the hover stays")


func test_a_drag_pan_leaves_the_hover_on_the_hex_under_the_pointer() -> void:
	await _start()
	var from := _screen_of(EAST)
	var at := _screen_of(TURIN)  # dragged a hex to the west: the map moves a hex east under the pointer's end
	_motion(from)
	_button(from, MOUSE_BUTTON_LEFT, true)
	_motion(from.lerp(at, 0.5), MOUSE_BUTTON_MASK_LEFT)
	_motion(at + Vector2(0.0, 1.0), MOUSE_BUTTON_MASK_LEFT)
	_motion(at, MOUSE_BUTTON_MASK_LEFT)
	await _settle()  # the button is still down: the camera has come to rest before the release
	_button(at, MOUSE_BUTTON_LEFT, false)
	await _settle()
	assert_eq(_armies().selected_army(), _army.id, "the drag selected nothing else")
	await _assert_all_use(_under(at), _army, "P: a drag after which nothing is hovered")


func test_a_zoom_moves_the_hover_to_the_hex_now_under_the_pointer() -> void:
	await _start()
	var at := _screen_of(PINEROLO)
	_motion(at)
	await _frames(2)
	var zoom := _scene.camera().zoom.x
	for _i: int in 6:  # about the middle of the map's area: the pointer is off it
		await _tap(&"cam_zoom_in")
		await _settle()
		if _under(at) != PINEROLO:
			break
	assert_gt(_scene.camera().zoom.x, zoom)
	var hex := _under(at)
	assert_ne(hex, PINEROLO, "the zoom moved the map under the pointer")
	await _assert_all_use(hex, _army, "P: a zoom after which the hover stays")


## The glide a walk's follow makes (GameRequests asks the map to glide to the walker's hex).
func test_a_glide_moves_the_hover_to_the_hex_now_under_the_pointer() -> void:
	await _start()
	var at := _screen_of(SUSA)
	_motion(at)
	await _frames(2)
	_scene.glide_to_hex(Vector2i(8, 10))
	await _settle()
	var hex := _under(at)
	assert_ne(hex, SUSA, "the glide moved the map under the pointer")
	await _assert_all_use(hex, _army, "P: a follow after which the hover stays")


func test_the_keyboard_cursor_is_not_taken_over_until_the_pointer_moves() -> void:
	await _start()
	var at := _screen_of(SUSA)
	_motion(at)
	await _frames(2)
	await _tap(&"map_cursor_right")
	await _tap(&"map_cursor_down")
	var cursor := _armies().cursor_hex()
	await _settle()
	_scene.glide_to_hex(Vector2i(8, 10))  # and any later camera move
	await _settle()
	assert_ne(_under(at), cursor)
	var points := _armies().route_marks().points()
	assert_eq(points.back() if not points.is_empty() else Vector2.INF, _scene.view().centre_of(cursor),
			"P: a camera move that takes the route from the order cursor")
	assert_eq(_app.hud().map_hover().move_card().title_text(), Words.place(Session.game, cursor), "P: and the card")
	await _tap(&"map_waypoint_key")
	assert_eq(_bound_for(_army), cursor, "P: a camera move that takes V from the order cursor")
	# The pointer moves to another hex: it leads again, and the next camera move follows it.
	var moved := _screen_of(EAST)
	_motion(moved)
	await _frames(2)
	_scene.glide_to_hex(TURIN)
	await _settle()
	assert_eq(_scene.map_input().current_hover(), _under(moved), "P: a pointer that never leads again")


func test_a_camera_move_with_the_pointer_on_a_panel_hovers_nothing() -> void:
	await _start()
	_motion(_screen_of(SUSA))
	await _frames(2)
	var panel := _app.hud().army_panel() as Control
	assert_true(panel.is_visible_in_tree(), "the selected army's panel is up")
	var on_panel := panel.get_global_rect().get_center()
	_motion(on_panel)
	await _frames(3)
	assert_not_null(_vp.gui_get_hovered_control(), "the pointer is on the panel")
	var heard: Array[Vector2i] = []
	_scene.map_input().hover_changed.connect(func(hex: Vector2i) -> void: heard.append(hex))
	_scene.glide_to_hex(Vector2i(8, 10))
	await _settle()
	assert_eq(_scene.map_input().current_hover(), MapInput.NO_HEX, "P: a hover through a panel")
	assert_eq(heard, [] as Array[Vector2i], "P: a hex hovered through the panel for a frame")


func test_a_camera_move_after_the_pointer_left_the_window_hovers_nothing() -> void:
	await _start()
	_motion(_screen_of(SUSA))
	await _frames(2)
	_scene.map_input().notification(NOTIFICATION_WM_MOUSE_EXIT)
	_scene.glide_to_hex(Vector2i(8, 10))
	await _settle()
	assert_eq(_scene.map_input().current_hover(), MapInput.NO_HEX, "P: a hover with the pointer out of the window")
