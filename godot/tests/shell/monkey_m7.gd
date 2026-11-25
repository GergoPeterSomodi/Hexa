## The M7 part of the UI monkey (test_ui_monkey.gd extends this, which extends MonkeyM6): the war's inputs (m7-build-spec.md
## section 9). Every M7 seed plays Savoy (the pick is steered) with a Milanese army made by the console and a war declared through the
## country panel's Confirm. The inputs: Shift+right click and Shift+O (Storm), B (the newest battle's dock), clicks on the battle
## badges and the siege dials, the dock (open, the stepper keys, Play, Full log, Esc), the hex menu's war items, the console's war
## commands (the right ones and hostile ones: no word, no army, no hex, no such terms), a declaration and a peace through the
## country panel (its Confirm answered or kept), the Castle areas switch, the standing orders (the army panel's segment and the
## console) and End season until a battle is fought. A battle record of two other countries that Savoy did not see is planted
## once a season (a developer rig: the planted fault of the leak check). Invariants: no visible string names a battle or a war
## line the player is not told of; the dock is on the stack exactly when the App has it, it shows a record the player may read
## and a day of it, and it never changes the digest; the Castle areas gate follows its setting; no two countries' armies share a
## hex at idle; no Confirm stays up through STUCK_STEPS steps; a refused console command leaves the digest and the version.
## Split out of the monkey like MonkeyM6.
class_name MonkeyM7
extends MonkeyM6

## An M7 action a seed must do runs from this step on when its counter is still 0 (after the M6 ones).
const FORCE_M7_STEP := 300
## The M7 counters a seed must raise above 0 (so its invariants cannot pass empty).
const M7_REQUIRED: Array[String] = [
	"m7_storms", "m7_b_keys", "m7_badges", "m7_docks", "m7_hex_menus", "m7_console", "m7_declares", "m7_peaces", "m7_castle",
	"m7_standing", "m7_checks",
]
const SAV := &"SAV"
const MLO := &"MLO"
const VERCELLI := Vector2i(6, 9)
const ALESS := Vector2i(7, 9)
const PAVIA := Vector2i(10, 9)
## A Confirm that stays on the stack through this many steps is a stuck modal.
const STUCK_STEPS := 16
## Forced steps without progress after which a season is played (a badge needs a battle of last season, a peace needs seasons of war).
const STALL_STEPS := 3
## The environment variable that names a file the monkey appends its progress to (empty: no progress file).
const PROGRESS_ENV := "HEXA_MONKEY_PROGRESS"
const PLANT_NAME := "Battle of Nowhere, 1480"
const TERMS: Array[StringName] = [&"take", &"white", &"yield"]
## The hostile and the right console lines; %a is an army of the player's (or 99999), the rest are as typed.
const CONSOLE_LINES: Array[String] = [
	"wars", "wars now", "declare", "declare ZZZ", "declare SAV", "declare MLO", "peace", "peace MLO", "peace MLO sue", "peace ZZZ take",
	"peace MLO white", "storm", "storm 99999 1 1", "storm %a 9999 9999", "storm %a 10 9", "storm %a x y", "standing", "standing %a fight",
	"standing 99999 hold", "standing %a hold", "standing %a withdraw", "as MLO declare SAV", "as ZZZ declare MLO", "as SAV declare SAV",
	"as MLO peace SAV take", "as MLO standing 99999 hold", "armies", "declare MLO extra",
]
## The M7 actions are on (a country game as Savoy).
var _m7: bool = false
var _m7_plant_turn: int = -1
var _m7_plant_game: Game = null
var _m7_confirm_steps: int = 0
## Forced steps in a row that raised no M7 counter.
var _m7_stalled: int = 0
var _m7_hidden_key: String = ""
var _m7_hidden: PackedStringArray = PackedStringArray()


## The country the pick takes: Savoy on an M7 seed (the random draw is made all the same, so older seeds are unchanged).
func _m7_choose(tags: Array[StringName], index: int) -> StringName:
	return SAV if _m7 and tags.has(SAV) else tags[index]


# ----- the dice and the forced steps -------------------------------------------------------------------------------------------------


## The next M7 action, by the dice. During the replay only the replay's rules are tried.
func _m7_step(rng: Rng, vp: SubViewport, app: App) -> void:
	if _m6_replaying(app):
		await _m6_during_replay(rng, vp, app)
		return
	if not _m4_ready(app) or not _m7_savoy():
		return
	_m4_note("m7")
	_m7_plant(app)
	await _m7_dice(rng, vp, app)
	_changed_hexes.clear()  # a war input changes land by the rules (a peace's terms, a capture, a release), never by a works action


func _m7_dice(rng: Rng, vp: SubViewport, app: App) -> void:
	match rng.randi_range(0, 14):
		0:
			await _m7_storm(rng, vp, app)
		1:
			await _m7_b_key(rng, vp, app)
		2, 3:
			await _m7_dock(rng, vp, app)
		4:
			await _m7_badge(rng, vp, app)
		5:
			await _m7_hex_menu(rng, vp, app)
		6, 7:
			await _m7_console(rng, vp, app)
		8:
			await _m7_declare(rng, vp, app, _m7_target(rng), false)
		9:
			await _m7_peace(rng, vp, app)
		10:
			await _m7_castle(rng, vp, app)
		11:
			await _m7_standing(rng, vp, app)
		12, 13:
			await _m6_end(rng, vp, app)
		_:
			await _m7_prepare(rng, vp, app)


## From FORCE_M7_STEP on, the first M7 action whose counter is still 0 (one a step). Until a battle is fought the war is prepared
## and a season played; the peace comes last (a truce follows it).
func _m7_force(rng: Rng, vp: SubViewport, app: App) -> void:
	if Session.in_season():  # a season runs (its end is one phase a frame, issue 441): no stall counted, nothing forced into it
		return
	var before := _m7_progress()
	# The H key (a random key of the monkey) hides the HUD, and a forced action then finds its buttons hidden for good (a press
	# that cannot land, step after step: seed 1504 never made its peace): the forced action starts from a shown HUD.
	if app.hud() != null and not app.hud().is_hud_visible():
		app.hud().set_hud_visible(true)
	await _m7_force_one(rng, vp, app)
	_changed_hexes.clear()  # as in _m7_step
	if _m7_progress() > before:
		_m7_stalled = 0
		return
	_m7_stalled += 1
	if _m7_stalled >= STALL_STEPS and _m4_ready(app) and _m7_savoy():  # the wanted input has nothing to act on (no badge, no army): the war moves on a season
		_m7_stalled = 0
		await _m7_prepare(rng, vp, app)
		await _m6_end(rng, vp, app)


## The M7 counters added up (the checks excluded).
func _m7_progress() -> int:
	var total := 0
	for key: String in M7_REQUIRED:
		if key != "m7_checks":
			total += int(_n[key])
	return total


func _m7_force_one(rng: Rng, vp: SubViewport, app: App) -> void:
	if not _m4_ready(app):
		if app.stack().count() > 0 and not _m6_replaying(app):
			await _m6_clear(vp, app)
		return
	if not _m7_savoy():
		return
	_m7_plant(app)
	if _m7_latest() < 0:
		await _m7_prepare(rng, vp, app)
		if int(_n["m7_declares"]) > 0 or Wars.at_war(Session.game, SAV, MLO):
			await _m6_end(rng, vp, app)
	elif int(_n["m7_docks"]) == 0:
		await _m7_dock(rng, vp, app)
	elif int(_n["m7_b_keys"]) == 0:
		await _m7_b_key(rng, vp, app)
	elif int(_n["m7_badges"]) == 0:
		await _m7_badge(rng, vp, app)
	elif int(_n["m7_hex_menus"]) == 0:
		await _m7_hex_menu(rng, vp, app)
	elif int(_n["m7_storms"]) == 0:
		await _m7_storm(rng, vp, app)
	elif int(_n["m7_console"]) == 0:
		await _m7_console(rng, vp, app)
	elif int(_n["m7_standing"]) == 0:
		await _m7_standing(rng, vp, app)
	elif int(_n["m7_castle"]) == 0:
		await _m7_castle(rng, vp, app)
	elif int(_n["m7_declares"]) == 0:
		await _m7_prepare(rng, vp, app)
	elif int(_n["m7_peaces"]) == 0:
		if Wars.enemies(Session.game, SAV).is_empty():
			await _m7_declare(rng, vp, app, MLO, true)  # no war to end: one is declared first (a peace needs one)
		else:
			await _m7_peace(rng, vp, app, true)
			if int(_n["m7_peaces"]) == 0:  # every term is locked (a white peace needs 4 seasons of war, a take needs a held district): a season passes
				await _m6_end(rng, vp, app)


# ----- helpers --------------------------------------------------------------------------------------------------------------------------


func _m7_savoy() -> bool:
	var game := Session.game
	return game != null and game.has_countries() and game.player == SAV


## The newest battle Savoy fought (a record id), -1 for none.
func _m7_latest() -> int:
	return BattleView.latest_of(Session.game, SAV)


## A country to declare on: Milan most of the time, else a neighbour of Savoy.
func _m7_target(rng: Rng) -> StringName:
	var game := Session.game
	if rng.randi_range(0, 2) != 0:
		return MLO
	var near := Territory.neighbours(game, Countries.by_tag(game, SAV).id)
	if near.is_empty():
		return MLO
	var other := Countries.by_id(game, near[rng.randi_range(0, near.size() - 1)])
	return other.tag if other != null else MLO


## A Shift+right click (Storm's gesture): the pointer moves there first.
func _m7_shift_click(vp: SubViewport, pos: Vector2) -> void:
	_m45_move(vp, pos)
	for pressed: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_RIGHT
		ev.position = pos
		ev.global_position = pos
		ev.shift_pressed = true
		ev.pressed = pressed
		vp.push_input(ev)


## Whether `hex` shows in the window.
func _m7_on_screen(vp: SubViewport, app: App, hex: Vector2i) -> bool:
	return Rect2(Vector2(60.0, 60.0), Vector2(vp.size) - Vector2(120.0, 120.0)).has_point(_m6_screen_pos(app, hex))


## A record of the player's that the dock may show (random among the kept ones); -1 for none.
func _m7_record(rng: Rng) -> int:
	var found := Battles.records_of(Session.game, SAV)
	if found.is_empty():
		return -1
	return found[rng.randi_range(0, found.size() - 1)].id


## A battle of two other countries on Vercelli, last season, that Savoy did not see: the leak check's planted fault (a developer
## rig written straight into the game, so the step's digest check is excused). Once a season.
func _m7_plant(app: App) -> void:
	var game := Session.game
	if game == null or (_m7_plant_game == game and _m7_plant_turn == game.turn):
		return
	_m7_plant_game = game
	_m7_plant_turn = game.turn
	var others: Array[StringName] = []
	for c: Country in game.countries:
		if c.tag != SAV and c.tag != MLO:
			others.append(c.tag)
	if others.size() < 2 or game.defs.war == null:
		return
	var war := CombatFixture.war()
	var fighters := [CombatFixture.pikemen(101, 0), CombatFixture.pikemen(201, 1)]
	var input := CombatFixture.input_of(war, fighters, 0, false, false)
	for f: Dictionary in fighters:
		for ud: UnitDef in game.defs.units:
			if String(ud.branch) == str(f["branch"]):
				f["kind"] = ud.id
				break
		f["army"] = 1 if int(f["side"]) == 0 else 2
	input["attacker"] = String(others[0])
	input["defender"] = String(others[1])
	var rng := Rng.new()
	rng.seed_with(1480)
	var before: int = rng.get_state()
	var out: Dictionary = Combat.fight(war, input, rng)
	var r := BattleRecord.new()
	r.id = game.next_record_id
	game.next_record_id += 1
	r.turn = maxi(game.turn - 1, 1)  # a record of turn 0 is refused when the save loads
	r.hex = VERCELLI
	r.name = PLANT_NAME
	r.year = game.start_year
	r.attacker = others[0]
	r.defender = others[1]
	r.input = input.duplicate(true)
	r.luck_before = before
	r.frames.assign(out["frames"])
	r.end = out["end"]
	r.witnesses = PackedStringArray()
	game.battle_records.append(r)
	game.version += 1
	_dev_changed = true
	app.hud().refresh_economy()


## The top Confirm answered: `confirm` presses its Confirm (or the alert's show or report), else its cancel, else Esc.
func _m7_answer(rng: Rng, vp: SubViewport, app: App, confirm: bool) -> void:
	for _i: int in 2:
		var top := app.stack().top()
		if not (top is Confirm):
			return
		var pick := confirm or rng.randi_range(0, 2) != 0
		var order: Array[StringName] = []
		order.assign([&"confirm", &"show", &"report"] if pick else [&"cancel", &"keep"])
		var button: Button = null
		for id: StringName in order:
			button = (top as Confirm).button_for(id)
			if button != null:
				break
		if button != null:
			_m4_press(vp, button)
		else:
			_send_chord(vp, KEY_ESCAPE)
		await _wait_frames(2)


## A button of the country panel scrolled into view first: below the fold a click on its middle lands on what covers it.
func _m7_reveal(button: Control) -> void:
	if button == null or not is_instance_valid(button):
		return
	var scroll := _m4_scroll_of(button)
	if scroll != null:
		scroll.ensure_control_visible(button)
		await _wait_frames(2)


## Esc until the stack is empty (a Confirm answers its Esc); false when a screen stays.
func _m7_close_all(vp: SubViewport, app: App) -> bool:
	if app.stack().count() > 0:
		await _m6_clear(vp, app)
	return app.stack().count() == 0


# ----- the war's setup ----------------------------------------------------------------------------------------------------------------


## Money and iron for Savoy, Milan's army at Alessandria, the war with Milan (the country panel's Confirm) and a Savoyard army on
## the march to Alessandria. Each part only when it is not there yet; the developer's gifts excuse the digest check.
func _m7_prepare(rng: Rng, vp: SubViewport, app: App) -> void:
	var game := Session.game
	var ctx := app.context()
	Session.dev_money(SAV, 100000 - Countries.by_tag(game, SAV).treasury)
	var iron := game.defs.good_id(&"iron")
	Session.dev_goods(SAV, iron, 20 - Countries.by_tag(game, SAV).stock[iron])
	_dev_changed = true
	app.hud().refresh_economy()
	var milan_there := false
	for a: Army in Armies.at(game, ALESS):
		milan_there = milan_there or a.tag == MLO
	if not milan_there and Armies.at(game, ALESS).is_empty():
		DevCommands.run("as MLO raise 7 9 pikemen 2", ctx)
	if not Wars.at_war(game, SAV, MLO):
		await _m7_declare(rng, vp, app, MLO, true)
	var mine: Array[Army] = Armies.of_country(game, SAV)
	var marching := false
	for a: Army in mine:
		marching = marching or a.order == Army.ORDER_MARCH
	if not marching:
		if mine.is_empty() and Armies.at(game, VERCELLI).is_empty():
			DevCommands.run("raise 6 9 pikemen 2", ctx)
			mine = Armies.of_country(game, SAV)
		if not mine.is_empty():
			DevCommands.run("march %d 7 9" % mine[0].id, ctx)
	_changed_hexes.clear()  # `as MLO raise` changes Milan's hex: it is not a works action of the player's (the owner check of the step)
	await _wait_frames(2)


## A declaration through the country panel: its war section's button (a click) or the App's request, then the Confirm answered
## (kept when `confirm` is false and the dice say so). `declares` counts a war that stood after the step and not before it.
func _m7_declare(rng: Rng, vp: SubViewport, app: App, target: StringName, confirm: bool) -> void:
	var game := Session.game
	var was := Wars.at_war(game, SAV, target)
	if rng.randi_range(0, 1) == 0:
		app.context().request(&"country", {"tag": target})
		await _wait_frames(2)
		var button: Button = null
		if app.hud().country_panel().visible:
			button = app.hud().country_panel().war_section().action_button("declare_war")
		await _m7_reveal(button)
		if not _m4_press(vp, button):
			app.context().request(&"declare_war", {"target": target})
	else:
		app.context().request(&"declare_war", {"target": target})
	await _wait_frames(2)
	await _m7_answer(rng, vp, app, confirm)
	if Session.game == game and not was and Wars.at_war(game, SAV, target):
		_bump("m7_declares")
	await _wait_frames(1)


## A peace through the country panel on the terms the dice pick (another enabled one when it is locked), the Confirm answered.
func _m7_peace(rng: Rng, vp: SubViewport, app: App, forced: bool = false) -> void:
	var game := Session.game
	var enemies := Wars.enemies(game, SAV)
	if enemies.is_empty():
		return
	var target := enemies[rng.randi_range(0, enemies.size() - 1)]
	var terms := TERMS[rng.randi_range(0, TERMS.size() - 1)]
	app.context().request(&"country", {"tag": target})
	await _wait_frames(2)
	var panel := app.hud().country_panel()
	if not panel.visible and forced:  # a request for the country already shown may toggle it off: once more
		app.context().request(&"country", {"tag": target})
		await _wait_frames(2)
	if not panel.visible:
		return
	var button := panel.war_section().action_button("make_peace", terms)
	for other: StringName in TERMS:
		if button == null or button.disabled:
			button = panel.war_section().action_button("make_peace", other)
	await _m7_reveal(button)
	if not _m4_press(vp, button):
		return
	await _wait_frames(2)
	await _m7_answer(rng, vp, app, forced or rng.randi_range(0, 3) != 0)
	if Session.game == game and not Wars.at_war(game, SAV, target):
		_bump("m7_peaces")
	await _wait_frames(1)


# ----- Storm ----------------------------------------------------------------------------------------------------------------------------


## Shift+right click, or the pointer over the hex and Shift+O, with a Savoyard army selected: a storm of the rules, or its toast.
func _m7_storm(rng: Rng, vp: SubViewport, app: App) -> void:
	var armies := _m6_map_armies(app)
	var game := Session.game
	var mine: Array[Army] = Armies.of_country(game, SAV)
	if armies == null or mine.is_empty():
		return
	var army := mine[rng.randi_range(0, mine.size() - 1)]
	var goals: Array[Vector2i] = [PAVIA, ALESS, VERCELLI, army.hex]
	var goal := goals[rng.randi_range(0, goals.size() - 1)]
	app.map_scene().frame_at(app.map_scene().view().centre_of(goal), 1.0)
	await _wait_frames(3)
	armies.select_army(army.id)
	await _wait_frames(2)
	var pos := _m6_screen_pos(app, goal)
	if not Rect2(Vector2.ZERO, Vector2(vp.size)).has_point(pos):
		return
	if rng.randi_range(0, 1) == 0:
		_m7_shift_click(vp, pos)
	else:
		_m45_move(vp, pos)
		await _wait_frames(2)
		_send_chord(vp, KEY_O, false, true)
	_bump("m7_storms")
	await _wait_frames(2)


# ----- B, the dock, the badges and the hex menu ---------------------------------------------------------------------------------


## B: the newest battle's dock (a toast with none). Esc closes it again; the digest stays.
func _m7_b_key(_rng: Rng, vp: SubViewport, app: App) -> void:
	var before := _m4_snapshot()
	var fought := _m7_latest() >= 0
	_send_chord(vp, KEY_B)
	await _wait_frames(3)
	var dock := app.requests().war.dock()
	assert_eq(dock != null, fought, "%s: B opens the dock exactly when a battle was fought" % _tag)
	_bump("m7_b_keys")
	if dock != null:
		assert_eq(dock.shown_record(), _m7_latest(), "%s: B shows the newest battle" % _tag)
		await _m7_close_dock(vp, app)
		_bump("m7_checks")
	_m4_assert_untouched(before, "B")


## The dock opened (B, a badge's click or the App's call), stepped with its keys, Play and Full log, closed with Esc.
func _m7_dock(rng: Rng, vp: SubViewport, app: App) -> void:
	var record := _m7_record(rng)
	if record < 0:
		return
	var before := _m4_snapshot()
	match rng.randi_range(0, 2):
		0:
			_send_chord(vp, KEY_B)
			record = _m7_latest()
		1:
			Events.battle_mark_clicked.emit(record)
		_:
			app.requests().war.open_battle(record)
	await _wait_frames(3)
	var dock := app.requests().war.dock()
	if dock == null:
		return
	_bump("m7_docks")
	assert_eq(dock.shown_record(), record, "%s: the dock shows the battle asked for" % _tag)
	for _i: int in rng.randi_range(1, 5):
		match rng.randi_range(0, 6):
			0:
				_send_chord(vp, KEY_LEFT)
			1:
				_send_chord(vp, KEY_RIGHT)
			2:
				_send_chord(vp, KEY_HOME)
			3:
				_send_chord(vp, KEY_END)
			4:
				dock.play()
			5:
				dock.set_full_log(not dock.full_log())
			_:
				dock.go_to_day(rng.randi_range(0, dock.day_count() + 1))
		await _wait_frames(2)
		if app.requests().war.dock() == null:
			break
		assert_between(dock.shown_day(), 1, maxi(dock.day_count(), 1), "%s: the dock's day is a day of the battle" % _tag)
	_m4_assert_untouched(before, "the battle dock")
	await _m7_close_dock(vp, app)
	_bump("m7_checks")


## Esc closes the dock (the stack's, not the dock's). The Esc ladder first releases the console's focus and closes an open popover
## (the Layers one): an Esc or two more, and then nothing of the dock stays.
func _m7_close_dock(vp: SubViewport, app: App) -> void:
	for _i: int in 3:
		if app.requests().war.dock() == null:
			break
		_send_chord(vp, KEY_ESCAPE)
		await _wait_frames(3)
	assert_null(app.requests().war.dock(), "%s: Esc closes the dock" % _tag)
	assert_false(app.stack().has_screen(&"battle_dock"), "%s: and the stack has none" % _tag)


## A click on a battle badge or a siege dial: the dock opens on the badge's battle, the dial's hex is selected.
func _m7_badge(rng: Rng, vp: SubViewport, app: App) -> void:
	var marks := app.map_scene().get_node_or_null("WarMarks") as WarMarks
	if marks == null:
		return
	var shown: Array[WarMark] = []
	for child: Node in marks.get_children():
		var mark := child as WarMark
		if mark != null and mark.visible and mark.kind != WarMark.KIND_REPLAY:
			shown.append(mark)
	if shown.is_empty():
		return
	var mark := shown[rng.randi_range(0, shown.size() - 1)]
	var hex := mark.hex
	app.map_scene().frame_at(app.map_scene().view().centre_of(hex), 1.0)
	await _wait_frames(3)
	var pos := mark.get_global_transform_with_canvas().origin
	if not Rect2(Vector2.ZERO, Vector2(vp.size)).has_point(pos):
		marks.click_hex(hex)
	else:
		_send_click(vp, pos, MOUSE_BUTTON_LEFT)
	_bump("m7_badges")
	await _wait_frames(3)
	var dock := app.requests().war.dock()
	if dock != null:
		if mark.kind == WarMark.KIND_BATTLE:
			assert_eq(dock.shown_record(), mark.record, "%s: a badge opens its battle" % _tag)
		await _m7_close_dock(vp, app)
		_bump("m7_checks")


## O on a hex of yours with no army selected: the war items (Open the battle, the siege, the castle area) are chosen or hidden.
func _m7_hex_menu(rng: Rng, vp: SubViewport, app: App) -> void:
	var armies := _m6_map_armies(app)
	var game := Session.game
	if armies == null:
		return
	armies.clear_army()
	var hexes: Array[Vector2i] = [VERCELLI, PAVIA, ALESS]
	for i: int in game.war_cache.fortresses(game):
		var hex := game.map.hex_of(i)
		if Territory.owner_tag(game, hex) == SAV:
			hexes.append(hex)
	for site: Dictionary in BattleView.sites(game, SAV):
		hexes.append(site["hex"] as Vector2i)
	app.map_scene().select_hex(hexes[rng.randi_range(0, hexes.size() - 1)])
	await _wait_frames(2)
	_send_chord(vp, KEY_O)
	await _wait_frames(2)
	var found := armies.find_children("*", "HexMenu", false, false)
	if found.is_empty() or not (found[0] as HexMenu).visible:
		return
	var menu := found[0] as HexMenu
	var war_ids: Array[int] = []
	for kind: StringName in [&"battle", &"siege", &"castle_area"]:
		var id := menu.item_id_of(kind)
		if id >= 0:
			war_ids.append(id)
	if war_ids.is_empty():
		menu.hide()
		return
	_bump("m7_hex_menus")
	var before := _m4_snapshot()
	menu.id_pressed.emit(war_ids[rng.randi_range(0, war_ids.size() - 1)])
	await _wait_frames(3)
	if app.requests().war.dock() != null:
		await _m7_close_dock(vp, app)
		_bump("m7_checks")
	_m4_assert_untouched(before, "a war item of the hex menu")


# ----- the console, the switch and the standing orders ----------------------------------------------------------------------------------


## A console line, the right ones and the hostile ones. A line the console did not do (not "Done") leaves the digest and the
## version; an alert it made (a war declared on you) is answered at once.
func _m7_console(rng: Rng, vp: SubViewport, app: App) -> void:
	var game := Session.game
	var mine: Array[Army] = Armies.of_country(game, SAV)
	var id := mine[rng.randi_range(0, mine.size() - 1)].id if not mine.is_empty() else 99999
	var line := CONSOLE_LINES[rng.randi_range(0, CONSOLE_LINES.size() - 1)].replace("%a", str(id))
	var before := _m4_snapshot()
	var answer := DevCommands.run(line, app.context())
	_bump("m7_console")
	assert_false(answer.is_empty(), "%s: the console answers '%s'" % [_tag, line])
	if not answer.begins_with("Done"):
		_m4_assert_untouched(before, "the console line '%s' (%s)" % [line, answer])
	else:
		_dev_changed = true
	if rng.randi_range(0, 2) == 0 and app.hud().debug_overlay().console() != null:
		app.hud().debug_overlay().console().submit("wars")
	await _wait_frames(2)
	await _m7_answer(rng, vp, app, rng.randi_range(0, 1) == 0)
	_bump("m7_checks")


## The Castle areas switch (Layers popover): the setting and the war layer's gate agree.
func _m7_castle(rng: Rng, vp: SubViewport, app: App) -> void:
	var switch := app.hud().layers_popover().castle_switch()
	var armies := _m6_map_armies(app)
	if switch == null or armies == null:
		return
	var mine: Array[Army] = Armies.of_country(Session.game, SAV)
	if not mine.is_empty() and rng.randi_range(0, 1) == 0:
		armies.select_army(mine[0].id)
	var on := rng.randi_range(0, 2) != 0
	switch.toggled.emit(on)
	await _wait_frames(3)
	var wars := app.map_scene().get_node("MapWars") as MapWars
	assert_eq(bool(app.settings().get_value("map/castle_areas")), on, "%s: the switch writes the setting" % _tag)
	if not on:
		assert_false(wars.area_gate(), "%s: the setting off closes the gate" % _tag)
	if armies.selected_army() >= 0 and not Wars.enemies(Session.game, SAV).is_empty():
		assert_eq(wars.area_gate(), on, "%s: a war and an army selected: the gate follows the setting" % _tag)
	assert_eq(app.map_scene().overlay().is_areas_on(), wars.area_gate(), "%s: the overlay's tint follows the gate" % _tag)
	_bump("m7_castle")
	_bump("m7_checks")
	if not on:
		switch.toggled.emit(true)
		await _wait_frames(2)


## A standing order: the army panel's segment or the console's `standing`; the segment shows what the army has.
func _m7_standing(rng: Rng, vp: SubViewport, app: App) -> void:
	var armies := _m6_map_armies(app)
	var game := Session.game
	var mine: Array[Army] = Armies.of_country(game, SAV)
	if armies == null or mine.is_empty():
		return
	var army := mine[rng.randi_range(0, mine.size() - 1)]
	armies.select_army(army.id)
	await _wait_frames(3)
	var word := "withdraw" if army.standing == Army.STANDING_HOLD else "hold"
	if rng.randi_range(0, 2) == 0:
		DevCommands.run("standing %d %s" % [army.id, word], app.context())
	else:
		var seg := _m7_segment(app)
		if seg != null:
			seg.select(word, true)
	_bump("m7_standing")
	await _wait_frames(3)
	var now := Armies.by_id(game, army.id)
	var seg := _m7_segment(app)
	if now != null and seg != null and app.hud().army_panel().shown_army() == army.id:
		assert_eq(str(seg.selected_id()), String(now.standing), "%s: the standing segment shows the army's standing" % _tag)
		_bump("m7_checks")


## The army panel's "If attacked" segment, null when it is not shown.
func _m7_segment(app: App) -> Segmented:
	for node: Node in app.hud().army_panel().find_children("*", "Segmented", true, false):
		var seg := node as Segmented
		if seg.is_visible_in_tree() and seg.button_for(String(Army.STANDING_HOLD)) != null:
			return seg
	return null


# ----- after every step ---------------------------------------------------------------------------------------------------------------


## Every visible text under `node`: labels, buttons, tooltips and the items of a shown menu.
func _m7_words(node: Node, out: PackedStringArray) -> void:
	var item := node as CanvasItem
	if item != null and not item.visible:
		return
	if node is Label:
		out.append((node as Label).text)
	elif node is BaseButton and node is Button:
		out.append((node as Button).text)
	elif node is PopupMenu and (node as PopupMenu).visible:
		for index: int in (node as PopupMenu).item_count:
			out.append((node as PopupMenu).get_item_text(index))
	var control := node as Control
	if control != null and not control.tooltip_text.is_empty():
		out.append(control.tooltip_text)
	for child: Node in node.get_children():
		_m7_words(child, out)


## What the player is not told of: the names of the battle records it may not read and the lines of the chronicle entries it
## was not told of (the exact viewer's sentence). Rebuilt when the game's version or the chronicle changes.
func _m7_hidden_texts(game: Game) -> PackedStringArray:
	var key := "%d|%d|%d|%d" % [game.get_instance_id(), game.version, game.chronicle.entries.size(), game.battle_records.size()]
	if key == _m7_hidden_key:
		return _m7_hidden
	_m7_hidden_key = key
	_m7_hidden = PackedStringArray()
	for r: BattleRecord in game.battle_records:
		if Knowledge.battle_access(game, game.player, r) == &"hidden" and not r.name.is_empty():
			_m7_hidden.append(r.name)
	for entry: Dictionary in game.chronicle.entries:
		if LogLinesWar.is_war_kind(str(entry.get("kind", ""))) and not Knowledge.witnessed(game, entry, game.player):
			var line := LogLines.line_of(game, entry, &"", {})
			if not line.is_empty() and not str(line.get("text", "")).is_empty():
				_m7_hidden.append(str(line["text"]))
	return _m7_hidden


## After every step: the leak check, the dock and the stack, no two countries' armies on a hex at idle, no stuck Confirm.
func _m7_assert_invariants(app: App, tag: String) -> void:
	var game := Session.game
	if OS.has_environment(PROGRESS_ENV):  # a long run says where it is: the step, the turn and the counters, one line a step
		var file := FileAccess.open(OS.get_environment(PROGRESS_ENV), FileAccess.READ_WRITE if FileAccess.file_exists(OS.get_environment(PROGRESS_ENV)) else FileAccess.WRITE)
		if file != null:
			file.seek_end()
			file.store_line("%s turn %d %s" % [tag, game.turn if game != null else -1, JSON.stringify(_n)])
	if game == null or not game.has_countries() or game.player != SAV or app.is_starting() or app.map_scene() == null:
		return
	var hidden := _m7_hidden_texts(game)
	if not hidden.is_empty():
		var words := PackedStringArray()
		_m7_words(app.hud(), words)
		_m7_words(app.stack(), words)
		_m7_words(app.map_scene(), words)
		for secret: String in hidden:
			for text: String in words:
				assert_false(text.contains(secret), "%s: a visible string tells of a battle or a war line the player was not told of: '%s'" % [tag, secret])
		_bump("m7_checks")
	var docks := 0
	for child: Node in app.stack().get_children():
		if child is Screen and (child as Screen).screen_id == &"battle_dock":
			docks += 1
	assert_lte(docks, 1, "%s: one battle dock on the stack at most" % tag)
	var dock := app.requests().war.dock()
	assert_eq(dock != null, docks == 1, "%s: the dock is on the stack exactly when the App has it" % tag)
	if dock != null and dock.visible:
		assert_gt(dock.shown_record(), -1, "%s: the dock shows a battle" % tag)
		assert_false(BattleView.of(game, SAV, dock.shown_record()).is_empty(), "%s: the dock shows a battle the player may read" % tag)
		assert_between(dock.shown_day(), 1, maxi(dock.day_count(), 1), "%s: the dock shows a day of it" % tag)
	if app.requests().flow.state() == SeasonFlow.State.IDLE and game.battles.is_empty():
		var seen := {}
		for army: Army in game.armies:
			if seen.has(army.hex):
				assert_eq(seen[army.hex], army.tag, "%s: two countries' armies share %s at idle" % [tag, str(army.hex)])
			seen[army.hex] = army.tag
	var war_confirm := false
	var said := PackedStringArray()
	if app.stack().top() is Confirm:  # the war's questions (a declaration, a peace, the alert); the load and delete questions are other milestones'
		_m7_words(app.stack().top(), said)
		var low := " ".join(said).to_lower()
		war_confirm = low.contains("war") or low.contains("peace") or low.contains("yield")
	if war_confirm:
		_m7_confirm_steps += 1
		assert_lt(_m7_confirm_steps, STUCK_STEPS, "%s: a war Confirm stays up through %d steps (a stuck modal): %s" % [tag, STUCK_STEPS, " | ".join(said)])
	else:
		_m7_confirm_steps = 0
