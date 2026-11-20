## Seeded deterministic UI & map monkey test (3 seeds x 600 synthetic events):
## exercises bound keys, viewport/HUD/screen clicks, mouse wheel with factors, trackpad
## pan/magnify gestures, drags, screen stack push/pop, Esc ladder, layers/seasons, and
## checks stack/shade/focus/zoom/bounds/digest invariants and zero leaked orphan nodes
## (docs/architecture/ui-and-controls-spec.md section 9; ui-style-and-feedback-spec.md section 11).
extends GutTest

const APP_SCENE := preload("res://shell/app/app.tscn")
const SEEDS: Array[int] = [1480, 1481, 1482]
const EVENTS_PER_SEED := 600

## Documented non-fatal quirks (empty when clean; matches ui-and-controls-spec.md section 9).
const KNOWN_ISSUES: Array[Dictionary] = []

const SAFE_KEYS: Array[Key] = [
	KEY_ESCAPE,
	KEY_M,
	KEY_F1,
	KEY_F3,
	KEY_1,
	KEY_2,
	KEY_3,
	KEY_4,
	KEY_G,
	KEY_N,
	KEY_H,
	KEY_U,
	KEY_F,
	KEY_EQUAL,
	KEY_MINUS,
	KEY_W,
	KEY_A,
	KEY_S,
	KEY_D,
	KEY_TAB,
	KEY_C,
	KEY_ENTER,
	KEY_UP,
	KEY_DOWN,
]

var _prev_game: Game = null
var _prev_unsaved: int = 0
var _old_max_fps: int = 0
var _old_low_proc: bool = false
var _old_tooltip_delay: float = 0.5
var _old_save_dir: String = ""
var _old_lock_path: String = ""
## Hexes whose state an action changed during the current step (Events.hex_changed).
var _changed_hexes: Array[Vector2i] = []
## The player seen after the pick, and the game it belongs to.
var _player_seen: StringName = &""
var _player_game: Game = null


func before_each() -> void:
	Bindings.reset_defaults()
	_prev_game = Session.game
	_prev_unsaved = Session.unsaved_actions
	_old_max_fps = Engine.max_fps
	_old_low_proc = OS.low_processor_usage_mode
	_old_tooltip_delay = float(ProjectSettings.get_setting("gui/timers/tooltip_delay_sec", 0.5))
	# Enter now ends seasons and autosaves: never the real user://saves (R11 rewrites the monkey for M3).
	_old_save_dir = Session.save_dir
	_old_lock_path = RunLock.path
	Session.save_dir = "user://test_monkey_saves"
	RunLock.path = "user://test_monkey_running.lock"


func after_each() -> void:
	for slot: String in SaveFile.SLOTS + SaveFile.AUTO_SLOTS:
		SaveFile.remove(slot, Session.save_dir)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Session.save_dir))
	RunLock.clear()
	Session.save_dir = _old_save_dir
	RunLock.path = _old_lock_path
	Session.game = _prev_game
	Session.unsaved_actions = _prev_unsaved
	Bindings.reset_defaults()
	Engine.max_fps = _old_max_fps
	OS.low_processor_usage_mode = _old_low_proc
	ProjectSettings.set_setting("gui/timers/tooltip_delay_sec", _old_tooltip_delay)
	RenderingServer.set_default_clear_color(MapScene.SEA_COLOUR)


func test_ui_monkey_seed_1480() -> void:
	await _run_monkey_seed(SEEDS[0])


func test_ui_monkey_seed_1481() -> void:
	await _run_monkey_seed(SEEDS[1])


func test_ui_monkey_seed_1482() -> void:
	await _run_monkey_seed(SEEDS[2])


## M2: the same monkey on a New game (the country pick first, then Play as and the country game).
func test_ui_monkey_m2_seed_1480() -> void:
	await _run_monkey_seed(SEEDS[0], true)


func test_ui_monkey_m2_seed_1481() -> void:
	await _run_monkey_seed(SEEDS[1], true)


func test_ui_monkey_m2_seed_1482() -> void:
	await _run_monkey_seed(SEEDS[2], true)


func _on_hex_changed(hex: Vector2i) -> void:
	_changed_hexes.append(hex)


func _run_monkey_seed(seed_value: int, new_game: bool = false) -> void:
	await _wait_frames(2)
	var orphans_before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_player_seen = &""
	_player_game = null
	Events.hex_changed.connect(_on_hex_changed)

	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.gui_disable_input = false
	add_child(vp)

	var app := APP_SCENE.instantiate() as App
	app.settings_path = ""
	app.allow_tree_quit = false
	app.pause_tree_when_modal = false
	app.skip_loading_frames = true
	if new_game:
		app.cli_args_override = PackedStringArray(["--new-game", "--seed=%d" % seed_value])
	else:
		app.cli_args_override = PackedStringArray(["--sandbox", "--seed=%d" % seed_value])
	var s := Settings.new("macOS", true)
	s.set_value("state/help_seen", true)
	s.set_value("graphics/preload_next_season", false)
	app.set_settings_override(s)
	vp.add_child(app)
	await _wait_frames(2)

	var waited := 0
	while app.is_starting() and waited < 240:
		await _wait_frames(1)
		waited += 1

	var rng := Rng.new()
	rng.seed_with(seed_value)
	var land_hexes := _collect_land_hexes()

	for step: int in range(EVENTS_PER_SEED):
		var prev_game := Session.game
		var prev_digest := prev_game.digest() if (prev_game != null and prev_game.map != null and prev_game.state != null) else ""
		var prev_unsaved := Session.unsaved_actions
		var prev_player := Session.player_tag()
		_changed_hexes.clear()

		_perform_monkey_step(rng, vp, app, land_hexes, step)
		await _wait_frames(1)

		_assert_invariants(vp, app, prev_game, prev_digest, prev_unsaved, prev_player, seed_value, step)

	Events.hex_changed.disconnect(_on_hex_changed)
	Session.end_game()
	remove_child(vp)
	vp.queue_free()
	await _wait_frames(4)

	var orphans_after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	assert_eq(orphans_after, orphans_before, "seed %d teardown must leave zero orphan nodes" % seed_value)


func _perform_monkey_step(
	rng: Rng,
	vp: SubViewport,
	app: App,
	land_hexes: Array[Vector2i],
	step: int
) -> void:
	var roll := rng.randi_range(0, 99)
	if roll < 28:
		_send_random_key(rng, vp)
	elif roll < 48:
		_click_visible_control(rng, vp, app)
	elif roll < 64:
		_send_random_viewport_click(rng, vp)
	elif roll < 76:
		_send_random_wheel(rng, vp)
	elif roll < 86:
		_send_random_gesture(rng, vp)
	elif roll < 93:
		_send_random_drag(rng, vp)
	else:
		_exercise_screen_or_hud_flow(rng, app, land_hexes, step)


func _send_random_key(rng: Rng, vp: SubViewport) -> void:
	var key := SAFE_KEYS[rng.randi_range(0, SAFE_KEYS.size() - 1)]
	# Ctrl+F (place search) is F with Ctrl; plain F is Fit whole map.
	var ctrl := key == KEY_F and rng.randi_range(0, 2) == 0
	var press := InputEventKey.new()
	press.keycode = key
	press.physical_keycode = key
	press.pressed = true
	press.ctrl_pressed = ctrl
	vp.push_input(press)

	var release := InputEventKey.new()
	release.keycode = key
	release.physical_keycode = key
	release.pressed = false
	release.ctrl_pressed = ctrl
	vp.push_input(release)


func _click_visible_control(rng: Rng, vp: SubViewport, app: App) -> void:
	var stack := app.stack()
	var root_ctrl: Node = stack.top() if stack.count() > 0 else app.hud().root()
	# With a screen up (the pick), the HUD's dock still gets clicks: Play as, the country panel.
	if stack.count() > 0 and app.hud() != null and rng.randi_range(0, 2) == 0:
		root_ctrl = app.hud().root()
	if root_ctrl == null:
		return
	var buttons := _collect_clickable_buttons(root_ctrl)
	if buttons.is_empty():
		return
	var btn := buttons[rng.randi_range(0, buttons.size() - 1)]
	var rect := btn.get_global_rect()
	if rect.has_area() and Rect2(Vector2.ZERO, Vector2(vp.size)).intersects(rect):
		_send_click(vp, rect.get_center(), MOUSE_BUTTON_LEFT)
	else:
		btn.pressed.emit()


func _collect_clickable_buttons(root_node: Node) -> Array[BaseButton]:
	var out: Array[BaseButton] = []
	var queue: Array[Node] = [root_node]
	while not queue.is_empty():
		var cur := queue.pop_front() as Node
		if cur is CanvasItem and not (cur as CanvasItem).visible:
			continue
		if cur is BaseButton:
			var btn := cur as BaseButton
			if btn.is_visible_in_tree() and not btn.disabled:
				var bname := String(btn.name)
				if bname != "QuitButton" and not bname.contains("Quit") and not bname.contains("OpenDataFolder"):
					out.append(btn)
		for child: Node in cur.get_children():
			queue.append(child)
	return out


func _send_random_viewport_click(rng: Rng, vp: SubViewport) -> void:
	var pos := Vector2(
		float(rng.randi_range(12, vp.size.x - 12)),
		float(rng.randi_range(8, vp.size.y - 12))
	)
	var button := MOUSE_BUTTON_LEFT if rng.randi_range(0, 3) != 0 else MOUSE_BUTTON_RIGHT
	_send_click(vp, pos, button)


func _send_random_wheel(rng: Rng, vp: SubViewport) -> void:
	var pos := Vector2(
		float(rng.randi_range(60, vp.size.x - 60)),
		float(rng.randi_range(60, vp.size.y - 60))
	)
	var wheel_buttons: Array[MouseButton] = [
		MOUSE_BUTTON_WHEEL_UP,
		MOUSE_BUTTON_WHEEL_DOWN,
		MOUSE_BUTTON_WHEEL_LEFT,
		MOUSE_BUTTON_WHEEL_RIGHT,
	]
	var factors: Array[float] = [0.5, 1.0, 2.0]
	var ev := InputEventMouseButton.new()
	ev.button_index = wheel_buttons[rng.randi_range(0, wheel_buttons.size() - 1)]
	ev.factor = factors[rng.randi_range(0, factors.size() - 1)]
	ev.position = pos
	ev.global_position = pos
	ev.pressed = true
	ev.ctrl_pressed = rng.randi_range(0, 5) == 0
	ev.shift_pressed = rng.randi_range(0, 5) == 0
	vp.push_input(ev)


func _send_random_gesture(rng: Rng, vp: SubViewport) -> void:
	var pos := Vector2(
		float(rng.randi_range(100, vp.size.x - 100)),
		float(rng.randi_range(80, vp.size.y - 80))
	)
	if rng.randi_range(0, 1) == 0:
		var pan := InputEventPanGesture.new()
		pan.position = pos
		pan.delta = Vector2(float(rng.randi_range(-8, 8)), float(rng.randi_range(-8, 8)))
		vp.push_input(pan)
	else:
		var mag := InputEventMagnifyGesture.new()
		mag.position = pos
		mag.factor = 0.85 if rng.randi_range(0, 1) == 0 else 1.15
		vp.push_input(mag)


func _send_random_drag(rng: Rng, vp: SubViewport) -> void:
	var start := Vector2(
		float(rng.randi_range(120, vp.size.x - 120)),
		float(rng.randi_range(100, vp.size.y - 100))
	)
	var delta := Vector2(float(rng.randi_range(-90, 90)), float(rng.randi_range(-70, 70)))
	var mid := start + delta * 0.5
	var end := start + delta

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = start
	press.global_position = start
	press.pressed = true
	vp.push_input(press)

	for pt: Vector2 in [mid, end]:
		var motion := InputEventMouseMotion.new()
		motion.position = pt
		motion.global_position = pt
		motion.relative = pt - start
		vp.push_input(motion)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = end
	release.global_position = end
	release.pressed = false
	vp.push_input(release)


func _exercise_screen_or_hud_flow(
	rng: Rng,
	app: App,
	land_hexes: Array[Vector2i],
	step: int
) -> void:
	var top := app.stack().top()
	if top != null:
		if top.screen_id == &"country_pick":
			# The pick: a row opens its country; Play as (or Enter on it) chooses it.
			var pick := top as CountryPick
			var tags := pick.row_tags()
			if not tags.is_empty():
				var tag := tags[rng.randi_range(0, tags.size() - 1)]
				if rng.randi_range(0, 2) == 0:
					pick.play(tag)
				else:
					var row := pick.row_button(tag)
					if row != null:
						row.pressed.emit()
			return
		if top.screen_id == &"options":
			var opt := top as Options
			var page_idx := rng.randi_range(0, Options.PAGES.size() - 1)
			opt.select_page(Options.PAGES[page_idx]["id"] as StringName)
			return
		if top.screen_id == &"main_menu":
			var menu := top as MainMenu
			var pick := rng.randi_range(0, 2)
			if pick == 0 and menu.sandbox_button().visible:
				menu.sandbox_button().pressed.emit()
			elif pick == 1:
				menu.options_button().pressed.emit()
			else:
				menu.credits_button().pressed.emit()
			return
		if top.screen_id == &"sandbox":
			var sb := top as Sandbox
			sb.roll_random_seed()
			sb.start_button().pressed.emit()
			return
		app.stack().back()
		return

	var choice := rng.randi_range(0, 4)
	if choice == 0:
		var screen_pool: Array[StringName] = [&"pause_menu", &"options", &"help", &"about", &"credits"]
		var sid := screen_pool[rng.randi_range(0, screen_pool.size() - 1)]
		app.context().request(&"open_screen", {"id": sid})
	elif choice == 1 and app.map_scene() != null and not land_hexes.is_empty():
		var hex := land_hexes[rng.randi_range(0, land_hexes.size() - 1)]
		app.map_scene().select_hex(hex)
	elif choice == 2:
		app.hud().set_layers_open(not app.hud().is_layers_open())
	elif choice == 3 and app.map_scene() != null:
		var season_idx := (step + rng.randi_range(0, 3)) % TilesetBuilder.SEASONS.size()
		app.map_scene().set_season(TilesetBuilder.SEASONS[season_idx])
	elif app.map_scene() != null:
		app.map_scene().fit()


func _assert_invariants(
	vp: SubViewport,
	app: App,
	prev_game: Game,
	prev_digest: String,
	prev_unsaved: int,
	prev_player: StringName,
	seed_value: int,
	step: int
) -> void:
	var stack := app.stack()
	var tag := "seed %d step %d" % [seed_value, step]

	# 1. ScreenStack + ModalShade consistency
	var shade_count := 0
	var shade_node: ColorRect = null
	var top_modal_idx := -1
	for idx: int in stack.get_child_count():
		var child := stack.get_child(idx)
		if child.name == &"ModalShade" and child is ColorRect:
			shade_count += 1
			shade_node = child as ColorRect
		elif child is Screen and (child as Screen).kind == Screen.Kind.MODAL:
			top_modal_idx = idx
	assert_eq(shade_count, 1, "%s: ScreenStack must maintain exactly one ModalShade node" % tag)
	if shade_node != null:
		if top_modal_idx >= 0:
			assert_true(shade_node.visible, "%s: ModalShade visible when modal is open" % tag)
			assert_lt(shade_node.get_index(), top_modal_idx, "%s: ModalShade sits beneath top modal" % tag)
		else:
			assert_false(shade_node.visible, "%s: ModalShade hidden when no modal is open" % tag)

	# 2. Pause & World/HUD visibility match stack state
	assert_eq(app.wants_pause(), stack.wants_pause(), "%s: App.wants_pause matches stack" % tag)
	assert_eq(app.hides_world(), stack.hides_world(), "%s: App.hides_world matches stack" % tag)
	assert_eq(app.world_host().visible, not stack.hides_world(), "%s: World visibility matches !hides_world" % tag)
	assert_eq(app.hud().visible, not stack.hides_world(), "%s: Hud visibility matches !hides_world" % tag)

	var top := stack.top()
	if top != null and top.kind == Screen.Kind.MODAL:
		var focus_owner := vp.gui_get_focus_owner()
		var has_live_focus := focus_owner != null and is_instance_valid(focus_owner) and top.is_ancestor_of(focus_owner)
		var has_default_target := not top.default_focus.is_empty() and top.get_node_or_null(top.default_focus) != null
		assert_true(has_live_focus or has_default_target, "%s: top modal (%s) must have valid focus target" % [tag, String(top.screen_id)])

	# 3. Camera zoom & bounds invariants when MapScene is active
	var map_scene := app.map_scene()
	if map_scene != null and is_instance_valid(map_scene):
		assert_eq(map_scene.map_input().enabled, not stack.wants_pause(), "%s: MapInput enabled iff not paused" % tag)
		assert_eq(map_scene.camera_rig().enabled, not stack.wants_pause(), "%s: CameraRig enabled iff not paused" % tag)
		if not stack.hides_world():
			var rig := map_scene.camera_rig()
			var z := rig.zoom()
			assert_gte(z, rig.min_zoom() - 0.001, "%s: zoom >= min_zoom" % tag)
			assert_lte(z, ZoomModel.ZOOM_MAX + 0.001, "%s: zoom <= ZOOM_MAX" % tag)
			var cam_pos := map_scene.camera().position
			var ms := map_scene.map_size()
			if ms.x > 0.0 and ms.y > 0.0:
				assert_gte(cam_pos.x, -0.5, "%s: camera x >= 0" % tag)
				assert_lte(cam_pos.x, ms.x + 0.5, "%s: camera x <= map_size.x" % tag)
				assert_gte(cam_pos.y, -0.5, "%s: camera y >= 0" % tag)
				assert_lte(cam_pos.y, ms.y + 0.5, "%s: camera y <= map_size.y" % tag)

	# 4. Digest invariant: same Game digest only changes on a successful action
	if Session.game != null and Session.game == prev_game and not prev_digest.is_empty():
		var cur_digest := Session.game.digest()
		if cur_digest != prev_digest:
			# The pick is an accepted action too; choosing a country resets unsaved_actions to 0 (AppRoutes).
			var picked := prev_player == &"" and Session.player_tag() != &""
			# A season (Enter) is an accepted action too; an autosave after it then leaves nothing unsaved.
			var autosaved := Session.unsaved_actions == 0 and Session.current_slot.begins_with("auto")
			if not picked and not autosaved:
				assert_gt(Session.unsaved_actions, prev_unsaved, "%s: game digest changed without an accepted action" % tag)

	# 5. M2: the player is fixed by the pick; an accepted works action (build, upgrade, clear) is on the player's land
	var game := Session.game
	if game != null and game.has_countries():
		if game.player != &"":
			if _player_game != game:
				_player_game = game
				_player_seen = game.player
			assert_eq(game.player, _player_seen, "%s: the player never changes after the pick" % tag)
		for hex: Vector2i in _changed_hexes:
			assert_eq(Territory.owner_tag(game, hex), game.player,
				"%s: an accepted works action on %s is on the player's land" % [tag, str(hex)])


func _send_click(vp: SubViewport, pos: Vector2, button: MouseButton) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)

	var press := InputEventMouseButton.new()
	press.button_index = button
	press.position = pos
	press.global_position = pos
	press.pressed = true
	vp.push_input(press)

	var release := InputEventMouseButton.new()
	release.button_index = button
	release.position = pos
	release.global_position = pos
	release.pressed = false
	vp.push_input(release)


func _collect_land_hexes() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if Session.game == null or Session.game.map == null:
		return out
	var m := Session.game.map
	for i: int in range(0, m.hex_count(), 17):
		if m.land[i] == 1:
			out.append(m.hex_of(i))
	return out


func _wait_frames(frames: int = 1) -> void:
	for _i: int in range(frames):
		await get_tree().process_frame
