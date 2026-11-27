## The moves monkey's aim under a moving camera (the failure of seed 1512, step 381). A live walk's camera follow glides the
## map while it plays, so a screen point taken a frame before the click may lie over another hex when the click arrives: the
## game orders the hex under the pointer, as it should, and a monkey that aimed a frame earlier expects the wrong one. Here a
## real walk plays in the App on the shell's fixed clock, and the monkey's path order is made at every phase of the walk's
## step (0 to PHASES - 1 frames after the follow starts): each order goes to the hex the monkey aimed at.
extends MonkeyMoves

const APP_SCENE := preload("res://shell/app/app.tscn")
const TURIN := Vector2i(5, 9)
## A walk long enough to last a whole path order, away to the south of Savoy's land.
const WALK_GOAL := Vector2i(4, 16)
## The point the monkey adds: far enough north of the walk that its follow moves the camera.
const AIM := Vector2i(2, 3)
## Frames of one step of a walk at the normal speed (ReplayPlan: 0.2 s at 60 frames a second).
const PHASES := 12
## Dice seeds tried for one whose first path order is the key asked for (_moves_path_act: V one time in three).
const DICE_TRIES := 200

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
	Session.save_dir = "user://test_monkey_aim_saves"
	RunLock.path = "user://test_monkey_aim_running.lock"


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


## Savoy's 1480 game in the App (its own viewport), the walk played at the normal speed, no question before a risky move.
func _app() -> Dictionary:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.gui_disable_input = false
	add_child_autofree(vp)
	var app := APP_SCENE.instantiate() as App
	app.settings_path = ""
	app.allow_tree_quit = false
	app.pause_tree_when_modal = false
	app.skip_loading_frames = true
	app.cli_args_override = PackedStringArray(["--new-game", "--country=SAV", "--seed=1480"])
	var s := Settings.new("macOS", true)
	s.set_value("state/help_seen", true)
	s.set_value("graphics/preload_next_season", false)
	s.set_value("display/background_fps", 0)
	s.set_value("game/autosave", "off")
	s.set_value("game/movement", "normal")
	s.set_value("game/confirm_moves", false)
	s.set_value("accessibility/reduce_motion", false)
	app.set_settings_override(s)
	vp.add_child(app)
	await _m8_wait_until(func() -> bool: return app.map_scene() != null and app.stack().count() == 0 and not app.is_starting(), 600)
	await _wait_frames(3)
	var army := ArmyFixture.army(Session.game, Session.player_tag(), TURIN, 0, 2)
	Session.game.version += 1
	var layer := _m6_map_armies(app)
	layer.sync()
	assert_true(layer.select_army(army.id))
	return {"vp": vp, "app": app, "army": army}


## The army back on Turin with a fresh season, then the walk to WALK_GOAL ordered; waits until the walk's follow has started to
## move the camera away from AIM, then `phase` frames more.
func _walk_playing(app: App, army: Army, phase: int) -> bool:
	var game := Session.game
	var layer := _m6_map_armies(app)
	app.requests().replay.skip_live()
	if army.order == Army.ORDER_MARCH:
		Session.act("halt", {"army": army.id})
	Armies.set_hex(game, army, TURIN, army.hex)
	Armies.set_points(game, army, Allowance.full(game, army))
	game.version += 1
	layer.sync()
	await _moves_frame_on(app, AIM)
	if not layer.extend_path(WALK_GOAL):
		return false
	var still := app.map_scene().camera().position
	await _m8_wait_until(func() -> bool: return app.map_scene().camera().position != still, 60)
	if app.map_scene().camera().position == still:
		return false
	await _wait_frames(phase)
	return true


## Every phase of a walk's step: the monkey's path order, made while the walk plays, goes to the hex it aimed at.
func _orders_hit_the_aim(dice: int) -> void:
	var env := await _app()
	var vp := env.vp as SubViewport
	var app := env.app as App
	var army := env.army as Army
	for key: String in MOVES_REQUIRED + MOVES_LOGGED:
		_n[key] = 0  # the counters the monkey's path order raises (not _moves_begin: its frame watch is the monkey's)
	var under_a_walk := 0
	for phase: int in PHASES:
		_tag = "phase %d" % phase
		if not await _walk_playing(app, army, phase):
			fail_test("%s: no walk moved the camera" % _tag)
			break
		under_a_walk += 1 if app.requests().replay.live_active() else 0
		var rng := Rng.new()
		rng.seed_with(dice)
		assert_true(await _moves_path_act(rng, vp, app, army.id, AIM), "%s: the order was made" % _tag)
		assert_eq(army.goal, AIM, "%s: the order went to the aimed hex" % _tag)
	assert_gt(under_a_walk, 0, "some orders were made while the walk played")


func test_a_shift_right_click_during_a_walk_orders_the_aimed_hex() -> void:
	await _orders_hit_the_aim(_dice_for(false))


func test_v_during_a_walk_orders_the_aimed_hex() -> void:
	await _orders_hit_the_aim(_dice_for(true))


## The first dice seed whose path order is the V key (`v`), else a Shift+right click.
func _dice_for(v: bool) -> int:
	for seed_value: int in range(1, DICE_TRIES):
		var rng := Rng.new()
		rng.seed_with(seed_value)
		if (rng.randi_range(0, 2) == 0) == v:
			return seed_value
	fail_test("no dice seed picks %s" % ("V" if v else "Shift+right"))
	return 0
