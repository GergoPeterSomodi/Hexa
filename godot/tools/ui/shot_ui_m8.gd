## The M8 pictures (docs/architecture/m8-build-spec.md section 9, names m8_*): the computer's turn in the App. A standalone script
## like shot_ui_m7.gd (its CLI and capture loop are copied from there, and it reaches the autoloads and the shell's classes only by
## name at run time, so it compiles before them). Each picture is made in a Genoa game on seed 1480 with calm weather, except the
## watch picture (a pick game that the console's watch ends). The turn is slowed to one seat a frame, so the pill's count is caught:
##   m8_pill_turn      the busy pill over the map mid-turn: "Countries are moving 7 / 12"
##   m8_pill_replay    the busy pill while the moves of the season play: "The moves of ... Space skips them"
##   m8_blocked_toast  a click on the map during the turn: the toast says the map takes orders when they are done
##   m8_watch_bar      a watched game: the top bar's sandbox seal "S" with "Watching"
##   m8_replay_war     the replay of a season of war (the M7 war sample as Savoy): the moves play, the pill says "Space skips them"
##   m8_log_others     the action log open with 30 of others' lines in one season: the "and 6 more about other countries" line
##   m8_reminder_peace_risk  the task flag's list with the peace_risk line: an enemy at war holds three of Genoa's districts (take_score)
##
## Windowed (GPU or xvfb + Mesa):
##   godot --path godot -s res://tools/ui/shot_ui_m8.gd -- --out=DIR [--scale=1,2] [--only=m8_pill_turn,...]
## Each scene is written to DIR/1x/NAME.png (1280 x 720) and DIR/2x/NAME.png (2560 x 1440). Headless it prepares every scene and
## exits 0 without writing PNGs; a scene that does not come up exits 1 and says which.
extends SceneTree

const DEFAULT_OUT_DIR := "/tmp/hexa_ui_shots_m8"
const APP_SCENE_PATH := "res://shell/app/app.tscn"
const LOGICAL_H := 720
const LOGICAL_W := 1280
const SCENES: Array[String] = ["m8_pill_turn", "m8_pill_replay", "m8_blocked_toast", "m8_watch_bar", "m8_replay_war",
	"m8_peace_alert", "m8_report_befell", "m8_log_others", "m8_reminder_peace_risk"]
## Others' lines of one season in the log: the cap (24) and six more, so the "more" line shows (issue 443).
const OTHER_LINES := 30
## Districts of Genoa an enemy holds in the peace_risk picture: take_score (war.tres), so the line is serious.
const PEACE_RISK_DISTRICTS := 3
## The scenes whose movement replay is on, with the report off between seasons.
const REPLAY_SCENES: Array[String] = ["m8_pill_replay", "m8_replay_war"]
## SeasonFlow.State values (the numbers stand for the enum: the shell's classes compile after the autoloads).
const STATE_IDLE := 0
const STATE_RUNNING := 1
const STATE_REPLAY := 2
## The seat count the turn is held at for the mid-turn pictures.
const HOLD_AT := 7
## The map's centre in the viewport (the logical size; a click is pushed into the viewport at this point).
const MAP_CLICK := Vector2(640.0, 360.0)
## Frames a scene waits for its state at most.
const FRAMES_MAX := 1200

var _out_dir := DEFAULT_OUT_DIR
var _scales: Array[int] = [1, 2]
var _only: Array[String] = []


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out=") or arg.begins_with("--dir="):
			_out_dir = arg.substr(arg.find("=") + 1)
		elif arg.begins_with("--scale="):
			_scales.clear()
			for part: String in arg.substr(8).split(",", false):
				var s := int(part.strip_edges())
				if s == 1 or s == 2:
					_scales.append(s)
		elif arg.begins_with("--only="):
			_only.clear()
			for part: String in arg.substr(7).split(",", false):
				_only.append(part.strip_edges())
	if _scales.is_empty():
		_scales = [1, 2]
	_run()


func _run() -> void:
	await process_frame
	var code := await _capture_all()
	quit(code)


func _capture_all() -> int:
	var headless := DisplayServer.get_name() == "headless"
	var global_out := ProjectSettings.globalize_path(_out_dir) if _out_dir.begins_with("res://") or _out_dir.begins_with("user://") else _out_dir
	DirAccess.make_dir_recursive_absolute(global_out)
	var packed := ResourceLoader.load(APP_SCENE_PATH) as PackedScene
	if packed == null:
		printerr("shot_ui_m8: cannot load %s" % APP_SCENE_PATH)
		return 1
	var target_scenes: Array[String] = SCENES if _only.is_empty() else _only
	var rendered := 0
	var saved := 0
	for scale_mult: int in _scales:
		var scale_dir := global_out.path_join("%dx" % scale_mult)
		DirAccess.make_dir_recursive_absolute(scale_dir)
		for scene_name: String in target_scenes:
			if not SCENES.has(scene_name):
				printerr("shot_ui_m8: unknown scene '%s'" % scene_name)
				return 1
			var ok := await _capture_one(packed, scene_name, scale_mult, scale_dir, headless)
			if not ok:
				printerr("shot_ui_m8: %s did not come up at %dx" % [scene_name, scale_mult])
				return 1
			rendered += 1
			if not headless:
				saved += 1
	if headless:
		print("shot_ui_m8: headless dummy renderer; prepared %d scene renders (%s) without PNG output" % [rendered, global_out])
	else:
		print("shot_ui_m8: saved %d UI pictures to %s" % [saved, global_out])
	return 0


func _capture_one(packed: PackedScene, scene_name: String, scale_mult: int, scale_dir: String, headless: bool) -> bool:
	var vp := SubViewport.new()
	vp.gui_embed_subwindows = true
	vp.size = Vector2i(LOGICAL_W, LOGICAL_H) * scale_mult
	if scale_mult > 1:
		vp.size_2d_override = Vector2i(LOGICAL_W, LOGICAL_H)
		vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.gui_disable_input = false
	root.add_child(vp)

	var app := packed.instantiate()
	app.set("settings_path", "")
	app.set("allow_tree_quit", false)
	app.set("pause_tree_when_modal", false)
	app.set("skip_loading_frames", true)
	var country := "SAV" if (scene_name == "m8_replay_war" or scene_name == "m8_report_befell") else "GEN"
	var cli := PackedStringArray(["--new-game", "--scenario=north_italy_1480", "--seed=1480"]) if scene_name == "m8_watch_bar" \
		else PackedStringArray(["--new-game", "--country=%s" % country, "--seed=1480"])
	app.set("cli_args_override", cli)
	var s := Settings.new("macOS", true)
	s.set_value("state/help_seen", true)
	s.set_value("graphics/preload_next_season", false)
	s.set_value("accessibility/reduce_motion", not REPLAY_SCENES.has(scene_name))
	s.set_value("display/ui_scale", "100" if scale_mult == 1 else "200")
	s.set_value("game/season_report", "off" if REPLAY_SCENES.has(scene_name) else "full")  # the replay scenes: no report between seasons
	s.set_value("game/autosave", "off")
	s.set_value("graphics/season_change", "instant")
	s.set_value("game/movement", "normal" if REPLAY_SCENES.has(scene_name) else "instant")
	app.call("set_settings_override", s)
	vp.add_child(app)
	await _wait_frames(3)

	var session := root.get_node_or_null("Session")
	var ok: bool = await _wait_up(app, scene_name) and await _prepare(app, scene_name, session, vp)
	await _wait_frames(3)
	if ok and not headless:
		var tex := vp.get_texture()
		var img := tex.get_image() if tex != null else null
		if img == null or img.is_empty():
			printerr("shot_ui_m8: empty viewport image for %s (%dx)" % [scene_name, scale_mult])
			ok = false
		else:
			var png_path := scale_dir.path_join("%s.png" % scene_name)
			if img.save_png(png_path) != OK:
				printerr("shot_ui_m8: failed saving %s" % png_path)
				ok = false

	if session != null:
		session.call("end_game")
	root.remove_child(vp)
	vp.queue_free()
	await _wait_frames(2)
	return ok


## The game is up (its map, no screen over it) or, for the watch picture, the pick is up.
func _wait_up(app: Node, scene_name: String) -> bool:
	for _i: int in FRAMES_MAX:
		var stack: Object = _obj(app.call("stack"))
		var up := app.call("map_scene") != null and not bool(app.call("is_starting"))
		if scene_name == "m8_watch_bar":
			if up and int(stack.call("count")) > 0:
				return true
		elif up and int(stack.call("count")) == 0:
			return true
		await process_frame
	return false


## The scene's state. The turn is slowed to one seat a frame and then held, so the pill's count is caught and stays in the picture.
func _prepare(app: Node, scene_name: String, session: Node, vp: SubViewport) -> bool:
	var req: Object = app.call("requests")
	if scene_name == "m8_watch_bar":
		var watched: bool = bool(session.call("watch"))
		req.call("handle", &"watch", {})
		await _wait_frames(3)
		return watched
	var flow: Object = req.get("flow")
	var hold := {"frozen": false}
	if not REPLAY_SCENES.has(scene_name):
		flow.set("step_orders", func(_budget: float) -> bool:
			if bool(hold["frozen"]):
				return false
			return bool(session.call("step_orders", 0.0)))
	if scene_name == "m8_log_others":
		return await _others_log(app, session)
	if scene_name == "m8_reminder_peace_risk":
		return await _peace_risk_list(app, session)
	if scene_name == "m8_peace_alert":
		# A take peace of Milan with Genoa (the player) that moves one district: the decision queue shows its Confirm.
		var decisions := req.get("decisions") as Object
		decisions.call("push", {"kind": &"peace_made", "tag": &"MLO", "target": &"GEN", "terms": &"take",
			"moved": [Vector2i(10, 13)], "turn": 1})
		var shown := bool(decisions.call("next", (app as Object).call("context")))
		await _wait_frames(3)
		return shown
	if scene_name == "m8_report_befell":
		# The M7 war sample as Savoy, then the season ends: the report with What befell (the computer's lines among them).
		var war_sample: Dictionary = UiSample.war(session, session.get("game") as Object)
		if not bool(war_sample["ok"]):
			printerr("shot_ui_m8: the war sample did not come up: %s" % str(war_sample["problem"]))
			return false
		flow.call("request_end", false)
		for _i: int in FRAMES_MAX:
			await process_frame
			var st := (app.call("stack") as Object).call("top") as Object
			if st != null and str(st.get("screen_id")) == "season_report":
				(st.call("sheet") as Object).call("scroll_to", &"befell")  # the What befell section is the picture
				await _wait_frames(3)
				return true
		return false
	if scene_name == "m8_replay_war":
		# The M7 war sample (Savoy's army at Vercelli, Milan's at Alessandria, a siege at Pavia), then seasons with the walks.
		var sample: Dictionary = UiSample.war(session, session.get("game") as Object)
		if not bool(sample["ok"]):
			printerr("shot_ui_m8: the war sample did not come up: %s" % str(sample["problem"]))
			return false
		return await _replay_season(app, flow)
	if scene_name == "m8_pill_replay":
		return await _replay_season(app, flow)
	flow.call("request_end", false)
	var clicked := false
	for _i: int in FRAMES_MAX:
		await process_frame
		var state := int(flow.call("state"))
		var pill: Object = _obj(app.call("hud")).call("busy_pill")
		var text := str(pill.call("text"))
		if scene_name == "m8_pill_replay" and state == STATE_REPLAY and bool(pill.get("visible")):
			return true
		if scene_name == "m8_pill_turn" and state == STATE_RUNNING and text.contains("%d / 12" % HOLD_AT):
			hold["frozen"] = true
			return true
		if scene_name == "m8_blocked_toast" and state == STATE_RUNNING:
			if not clicked and text.begins_with("Countries are moving"):
				_click(vp, MAP_CLICK)
				clicked = true
			elif clicked and _has_toast(app, "takes orders"):
				hold["frozen"] = true
				return true
	return false


## A call result as an Object, for the chained calls on the shell (the typed reads of a Variant do not parse).
func _obj(value: Variant) -> Object:
	return value as Object


## Plays up to six seasons (the report off) until one has walks to replay: the replay state, with its pill up.
func _replay_season(app: Node, flow: Object) -> bool:
	for _season: int in 6:
		for _i: int in FRAMES_MAX:
			if Time.get_ticks_msec() > int(flow.get("guard_until")) and int(flow.call("state")) == STATE_IDLE:
				break
			await process_frame
		flow.call("request_end", false)
		for _i: int in FRAMES_MAX:
			await process_frame
			var state := int(flow.call("state"))
			if state == STATE_REPLAY:
				await _wait_frames(2)
				var pill: Object = _obj(_obj(app.call("hud")).call("busy_pill"))
				return bool(pill.get("visible"))
			if state == STATE_IDLE:
				break
	return false


func _click(vp: SubViewport, at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.position = at
		ev.global_position = at
		ev.pressed = pressed
		vp.push_input(ev)


func _has_toast(app: Node, part: String) -> bool:
	var messages: Array = _obj(_obj(app.call("hud")).call("toast_host")).call("messages")
	for m: Variant in messages:
		if str(m).contains(part):
			return true
	return false


## The log with others' lines (issue 443): OTHER_LINES works finished by the first country Genoa knows, in this season, with
## Genoa among the witnesses, then the log opened. The cap of 24 leaves the "more" line.
func _others_log(app: Node, session: Node) -> bool:
	var g: Game = session.get("game") as Game
	var known: Array = Knowledge.known(g, &"GEN")
	var other: StringName = &""
	for tag: StringName in known:
		if tag != &"GEN":
			other = tag
			break
	if other == &"":
		printerr("shot_ui_m8: Genoa knows no other country")
		return false
	for k: int in OTHER_LINES:
		var w := Work.new()
		w.id = 1000 + k
		w.tag = other
		w.hex = Vector2i(k % 20, 3 + k % 9)
		w.action = Works.BUILD
		w.family = ImproveRules.VINEYARD
		w.level_to = 1
		w.started_turn = g.turn
		w.seasons = 4
		w.seasons_left = 4
		g.emit({"kind": "work_finished", "tag": other, "hex": w.hex, "work": w.to_dict(),
			"witnesses": ["GEN", String(other)]})
	session.call("drain")
	await _wait_frames(2)
	var log_card: Object = (app.call("hud") as Object).call("action_log")
	log_card.call("open")
	await _wait_frames(3)
	return bool(log_card.call("is_open"))


## The peace_risk reminder (issue 443): a war with a neighbour that holds PEACE_RISK_DISTRICTS of Genoa's districts (its
## take score), then the task flag's list open.
func _peace_risk_list(app: Node, session: Node) -> bool:
	var g: Game = session.get("game") as Game
	var enemy: StringName = WarFixture.neighbour_of(g, &"GEN")
	if enemy == &"":
		printerr("shot_ui_m8: Genoa has no neighbour")
		return false
	WarFixture.at_war(g, &"GEN", enemy)
	var held: Country = Countries.by_tag(g, &"GEN")
	var done := 0
	for district: int in Territory.districts(g, held.id):
		if done >= PEACE_RISK_DISTRICTS:
			break
		var hex: Vector2i = g.map.hex_of(district)
		if hex == held.capital:
			continue
		WarFixture.set_occupier(g, hex, enemy)
		done += 1
	g.version += 1
	var flag: Object = (app.call("hud") as Object).call("task_flag")
	flag.call("refresh")
	flag.call("open_list")
	await _wait_frames(3)
	return bool(flag.call("is_list_open"))


func _wait_frames(n: int) -> void:
	for _i: int in n:
		await process_frame
