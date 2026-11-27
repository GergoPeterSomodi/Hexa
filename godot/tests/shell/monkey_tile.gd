## The tile window part of the UI monkey (test_ui_monkey.gd extends this, which extends MonkeyFog): the tile window of the tile
## build (docs/architecture/tilewin-build-spec.md 7.4; plan TW18). A tile step picks random hexes of each case (its case key:
## the case, the sight and the picture kind of TileView), opens the window on one (a click on the hex, or the map's selection)
## and then does one of: a click on a tab (dimmed tabs too: nothing happens), the tab keys (Ctrl+] by the window key path), a hover on
## a Buildings row, the hex menu's items, the RaiseScreen opened through open_for and closed, a hammer on the Buildings tab.
## Invariants, every frame a tile step looks at the window (_tile_assert): the open tab is live; the strip holds exactly the tabs
## that apply (none on an undiscovered hex, which says only "Unexplored"); a dimmed tab is disabled and its tooltip is its
## reason; nothing under the window names the owner of an undiscovered hex (the fog check of monkey_fog.gd); every foreign army
## row is one ArmyView.visible allows; the window lies in the viewport. A hover, a tab click, a menu or a Raise screen opened
## leaves the game as it was (the digest, the version, the treasury and the stores of M4); the treasury and the stores are
## never negative after a raise or a hammer.
class_name MonkeyTile
extends MonkeyFog

## The tile counters a tile seed must raise above 0 (tile_cases: distinct case keys picked, at least TILE_MIN_CASES).
const TILE_REQUIRED: Array[String] = ["tile_opens", "tile_tab_switches", "tile_cases", "raise_screen_opens", "tile_key_tabs"]
## The counters the log shows (not asserted).
const TILE_LOGGED: Array[String] = ["tile_steps", "tile_hovers", "tile_menus", "tile_hammers", "tile_raises", "tile_dimmed_clicks"]
## A tile seed picks at least this many distinct cases.
const TILE_MIN_CASES := 3
## One M8 step in this many is a tile step (when no screen is up and the computer is not replaying).
const TILE_STEP_ODDS := 5
## Random hexes sampled per tile step to find the cases.
const TILE_PICK_TRIES := 60
## From this step on, a required tile counter still short gets a forced tile step after each step, up to TILE_FORCED_MAX.
const TILE_FORCE_STEP := 200
const TILE_FORCED_MAX := 80

## The tile actions are on (a tile seed).
var _tile: bool = false
## The case keys picked in this seed (each new one is counted once in tile_cases).
var _tile_seen: Dictionary = {}
## Forced tile steps so far in this seed.
var _tile_forced: int = 0


## Starts the tile counters on a tile seed (after the fog ones).
func _tile_begin(on: bool) -> void:
	_tile = on
	_tile_seen = {}
	_tile_forced = 0
	if not on:
		return
	for key: String in TILE_REQUIRED:
		_n[key] = 0
	for key: String in TILE_LOGGED:
		_n[key] = 0


## Stops the tile actions and checks that each tile counter was raised and that the seed picked enough cases.
func _tile_end(on: bool, seed_value: int) -> void:
	_tile = false
	if not on:
		return
	gut.p("monkey tile seed %d counters: %s" % [seed_value, JSON.stringify(_n)])
	for key: String in TILE_REQUIRED:
		assert_gt(int(_n[key]), 0, "seed %d: the tile monkey did %s" % [seed_value, key])
	assert_true(int(_n["tile_cases"]) >= TILE_MIN_CASES, "seed %d: the tile monkey picked at least %d cases (%d)" % [seed_value, TILE_MIN_CASES, int(_n["tile_cases"])])


## The M8 step, with a tile step on some of them (the fog step and the M8 ones keep the rest).
func _m8_step(rng: Rng, vp: SubViewport, app: App) -> void:
	if _tile and _tile_ready(app) and rng.randi_range(0, TILE_STEP_ODDS - 1) == 0:
		await _tile_step(rng, vp, app)
		await _wait_frames(2)
		return
	await super._m8_step(rng, vp, app)


## The fog step's invariants, then a forced tile step while a required tile counter is still short (from TILE_FORCE_STEP on).
func _fog_after_step(app: App, seed_value: int, step: int) -> void:
	await super._fog_after_step(app, seed_value, step)
	if not _tile or step < TILE_FORCE_STEP or _tile_forced >= TILE_FORCED_MAX or not _tile_missing() or not _tile_ready(app):
		return
	var vp := app.get_viewport() as SubViewport
	if vp == null:
		return
	_tile_forced += 1
	var rng := Rng.new()
	rng.seed_with(seed_value * 1000 + step)
	await _tile_step(rng, vp, app)
	await _wait_frames(2)


## True while a tile counter is short of its requirement.
func _tile_missing() -> bool:
	for key: String in TILE_REQUIRED:
		if int(_n[key]) <= 0:
			return true
	return int(_n["tile_cases"]) < TILE_MIN_CASES


## A tile step may start: a game with a player, the map shown, no screen up (so no Confirm either), and the turn idle (no season
## moving or replaying: the M8 steps of those states keep their own counters).
func _tile_ready(app: App) -> bool:
	return Session.game != null and Session.game.has_countries() and Session.player_tag() != &"" and app.map_scene() != null \
		and not app.is_starting() and app.stack().count() == 0 and app.requests().flow.state() == SeasonFlow.State.IDLE


## One tile step: a hex of a random case is opened, then one action on the window, with the invariants after the open and the action.
func _tile_step(rng: Rng, vp: SubViewport, app: App) -> void:
	var game := Session.game
	var viewer := Session.player_tag()
	if game == null or not game.has_countries() or viewer == &"" or app.map_scene() == null:
		return
	_bump("tile_steps")
	var hex := _tile_pick_hex(rng, game, viewer)
	if hex == MapInput.NO_HEX:
		return
	await _tile_open(rng, vp, app, hex)
	await _wait_frames(2)
	var panel := app.hud().tile_window()
	if not panel.is_visible_in_tree() or panel.shown_hex() != hex:
		return
	_bump("tile_opens")
	_tile_assert(app, vp, "the window opened")
	if app.stack().count() != 0:  # the click on the hex ended a live walk that fought: its dock is up and the tab keys are the screen's (R32)
		return
	var roll := rng.randi_range(0, 9)
	if roll < 4:
		await _tile_tab_click(rng, vp, app)
	elif roll < 6:
		await _tile_row_hover(rng, app)
	elif roll < 8:
		await _tile_menu(rng, vp, app)
	elif roll < 9:
		await _tile_raise(rng, vp, app)
	else:
		await _tile_hammer(rng, vp, app)
	await _wait_frames(2)
	_tile_assert(app, vp, "after the action")


## Opens the window on `hex`: by the map's selection, or by a click on the hex when it is in the viewport.
func _tile_open(rng: Rng, vp: SubViewport, app: App, hex: Vector2i) -> void:
	_m4_note("tile open")
	var pos := _m6_screen_pos(app, hex)
	if rng.randi_range(0, 1) == 0 or not Rect2(Vector2.ZERO, Vector2(vp.size)).has_point(pos):
		app.map_scene().select_hex(hex)
	else:
		_send_click(vp, pos, MOUSE_BUTTON_LEFT)


## A random hex of a random case (the case key of its view); MapInput.NO_HEX when the sample finds none.
func _tile_pick_hex(rng: Rng, game: Game, viewer: StringName) -> Vector2i:
	var count := game.map.hex_count()
	if count == 0:
		return MapInput.NO_HEX
	var buckets: Dictionary = {}
	for _t: int in TILE_PICK_TRIES:
		var hex := game.map.hex_of(rng.randi_range(0, count - 1))
		var view := TileView.of(game, viewer, hex)
		if view.is_empty():
			continue
		var key := _tile_key(view)
		if not buckets.has(key):
			buckets[key] = []
		(buckets[key] as Array).append(hex)
	if buckets.is_empty():
		return MapInput.NO_HEX
	var keys := buckets.keys()
	var key: String = keys[rng.randi_range(0, keys.size() - 1)]
	if not _tile_seen.has(key):
		_tile_seen[key] = true
		_bump("tile_cases")
	var hexes: Array = buckets[key]
	return hexes[rng.randi_range(0, hexes.size() - 1)]


## The case key of a view: its case, its sight and its picture kind ("" for none).
static func _tile_key(view: Dictionary) -> String:
	var head: Dictionary = view.get("header", {})
	var picture: Dictionary = head.get("picture", {})
	return "%s|%s|%s" % [str(view.get("case", "")), str(view.get("sight", "")), str(picture.get("kind", ""))]


## A click on a tab of the strip. A dimmed tab is clicked too: it must do nothing. The tab keys go instead when map_input has them.
func _tile_tab_click(rng: Rng, vp: SubViewport, app: App) -> void:
	var panel := app.hud().tile_window()
	if rng.randi_range(0, 2) == 0 or (int(_n["tile_key_tabs"]) == 0 and _step_no >= TILE_FORCE_STEP):
		await _tile_key_switch(vp, app)
		return
	var buttons := _tile_strip_buttons(panel)
	if buttons.is_empty():
		return
	# A tab other than the open one when there is one (a click on the open tab switches nothing).
	var pool: Array[Button] = []
	for candidate: Button in buttons:
		if StringName(str(candidate.get_meta("tab_id"))) != panel.tab_open():
			pool.append(candidate)
	if pool.is_empty():
		pool = buttons
	var button := pool[rng.randi_range(0, pool.size() - 1)]
	if not button.is_visible_in_tree():
		return
	var rect := button.get_global_rect()
	if not Rect2(Vector2.ZERO, Vector2(vp.size)).has_point(rect.get_center()):
		return
	var id := StringName(str(button.get_meta("tab_id")))
	var dimmed := button.disabled
	var before := panel.tab_open()
	var snap := _m4_snapshot()
	_m4_note("tab click %s" % id)
	_send_click(vp, rect.get_center(), MOUSE_BUTTON_LEFT)
	await _wait_frames(2)
	_m4_assert_untouched(snap, "a tab click")
	if dimmed:
		_bump("tile_dimmed_clicks")
		assert_eq(panel.tab_open(), before, "%s: a dimmed tab does nothing" % _tag)
		return
	assert_eq(panel.tab_open(), id, "%s: a live tab opens on its click" % _tag)
	if id != before:
		_bump("tile_tab_switches")
	_tile_assert(app, vp, "a tab click")


## Ctrl+] to the next live tab (wrapping): TileWindow.handle_key takes it (no screen is up in a tile step).
func _tile_key_switch(vp: SubViewport, app: App) -> void:
	var panel := app.hud().tile_window()
	var live := panel.live_tab_ids()
	if live.size() < 2:
		return
	var before := panel.tab_open()
	var at := live.find(before)
	var expected: StringName = live[posmod(at + 1, live.size())] if at >= 0 else live[0]
	_m4_note("tab key")
	_send_chord(vp, KEY_BRACKETRIGHT, true)
	await _wait_frames(2)
	_bump("tile_key_tabs")
	assert_eq(panel.tab_open(), expected, "%s: Ctrl+] opens the next live tab" % _tag)
	if expected != before:
		_bump("tile_tab_switches")
	_tile_assert(app, vp, "the tab key")


## A hover on a row of the Buildings tab (its hammer, or the row), then the pointer leaves: the game is untouched.
func _tile_row_hover(rng: Rng, app: App) -> void:
	var panel := app.hud().tile_window()
	if panel.live_tab_ids().has(&"town"):
		panel.show_tab(&"town")
		await _wait_frames(2)
	var rows := panel.building_rows()
	if rows.is_empty():
		return
	var row := rows[rng.randi_range(0, rows.size() - 1)]
	var button: Control = row
	if row.hammer() != null:
		button = row.hammer()
	var hex := panel.shown_hex()
	var snap := _m4_snapshot()
	_m4_note("row hover")
	AppFlowHelpers.hover_card(app, hex, button)
	await _wait_frames(2)
	_m4_assert_untouched(snap, "hovering a row")
	AppFlowHelpers.hover_out(button)
	await _wait_frames(2)
	_m4_assert_untouched(snap, "the pointer leaving a row")
	_bump("tile_hovers")


## The hex menu of an own hex (O): the menu opens without a change, then one of its enabled items is picked or the menu is hidden.
func _tile_menu(rng: Rng, vp: SubViewport, app: App) -> void:
	var armies := _m6_map_armies(app)
	var game := Session.game
	var hex := app.hud().tile_window().shown_hex()
	if armies == null or armies.selected_army() >= 0 or Territory.owner_tag(game, hex) != Session.player_tag():
		return
	app.map_scene().select_hex(hex)
	await _wait_frames(1)
	var snap := _m4_snapshot()
	_m4_note("hex menu")
	_send_chord(vp, KEY_O)
	await _wait_frames(2)
	var found := armies.find_children("*", "HexMenu", false, false)
	if found.is_empty() or not (found[0] as HexMenu).visible:
		return
	var menu := found[0] as HexMenu
	_m4_assert_untouched(snap, "opening the hex menu")
	_bump("tile_menus")
	var enabled: Array[int] = []
	for entry: Dictionary in menu.entries():
		if bool(entry["enabled"]):
			enabled.append(int(entry["id"]))
	if enabled.is_empty() or rng.randi_range(0, 2) == 0:
		menu.hide()
		return
	menu.id_pressed.emit(enabled[rng.randi_range(0, enabled.size() - 1)])
	await _wait_frames(2)
	_tile_assert(app, vp, "a menu item")


## The RaiseScreen of an own settlement: pushed, opened for the hex, one company raised when one is ready, then removed.
func _tile_raise(rng: Rng, vp: SubViewport, app: App) -> void:
	var game := Session.game
	var viewer := Session.player_tag()
	var hex := app.hud().tile_window().shown_hex()
	if app.stack().count() != 0:
		return
	if Territory.owner_tag(game, hex) != viewer:  # the Raise screen is for an own settlement: the window moves to one
		hex = _m4_pick_hex(rng, true)
		if hex == MapScene.NO_HEX:
			return
		app.map_scene().select_hex(hex)
		await _wait_frames(2)
	var snap := _m4_snapshot()
	_m4_note("raise screen")
	var screen := ScreenIds.make(&"raise_screen") as RaiseScreen
	app.stack().push(screen)
	screen.open_for(hex)
	await _wait_frames(2)
	_bump("raise_screen_opens")
	_m4_assert_untouched(snap, "opening the Raise screen")
	assert_eq(screen.shown_hex(), hex, "%s: the Raise screen shows the hex it opened for" % _tag)
	var raise: Dictionary = TileArmy.of(game, viewer, hex).get("raise", {})
	var ready: Array[int] = []
	for row: Dictionary in raise.get("rows", []):
		if StringName(str(row.get("state", ""))) == &"ready":
			ready.append(int(row.get("kind", -1)))
	if not ready.is_empty() and rng.randi_range(0, 1) == 0:
		screen.raise_company(ready[rng.randi_range(0, ready.size() - 1)])
		_bump("tile_raises")
		await _wait_frames(2)
		_tile_money_ok()
	app.stack().remove(screen)
	screen.queue_free()
	await _wait_frames(2)
	assert_false(app.stack().has_screen(&"raise_screen"), "%s: the Raise screen is closed" % _tag)


## A build on the Buildings tab: the first enabled hammer of a random row (a disabled hammer is not pressed).
func _tile_hammer(rng: Rng, vp: SubViewport, app: App) -> void:
	var panel := app.hud().tile_window()
	if panel.live_tab_ids().has(&"town"):
		panel.show_tab(&"town")
		await _wait_frames(2)
	var hammers: Array[Button] = []
	for row: BuildingRow in panel.building_rows():
		var hammer := row.hammer()
		if hammer != null and not hammer.disabled and hammer.is_visible_in_tree():
			hammers.append(hammer)
	if hammers.is_empty():
		return
	_m4_note("hammer")
	if not _m4_press(vp, hammers[rng.randi_range(0, hammers.size() - 1)]):
		return
	await _wait_frames(2)
	_bump("tile_hammers")
	_tile_money_ok()


## The player's treasury and stores are not negative.
func _tile_money_ok() -> void:
	var game := Session.game
	var country := Countries.by_tag(game, game.player)
	if country == null:
		return
	assert_true(country.treasury >= 0, "%s: the treasury is not negative" % _tag)
	for value: int in country.stock:
		assert_true(value >= 0, "%s: no store is negative" % _tag)


## The tab buttons of the strip, in order (the strip holds one button per shown tab, dimmed ones included).
func _tile_strip_buttons(panel: TileWindow) -> Array[Button]:
	var out: Array[Button] = []
	var strip := panel.get("_tab_strip") as Node
	if strip == null:
		return out
	for child: Node in strip.get_children():
		if child is Button and child.has_meta("tab_id"):
			out.append(child as Button)
	return out


## The invariants of the window on the hex it shows (see the module comment). Nothing is checked when no window is up.
func _tile_assert(app: App, vp: SubViewport, what: String) -> void:
	var panel := app.hud().tile_window()
	if panel == null or not panel.is_visible_in_tree() or panel.shown_hex() == MapInput.NO_HEX:
		return
	_m4_note(what)
	var game := Session.game
	var viewer := Session.player_tag()
	var hex := panel.shown_hex()
	var view := TileView.of(game, viewer, hex)
	assert_false(view.is_empty(), "%s: a shown hex has a tile view" % _tag)
	var unexplored := StringName(str(view.get("case", ""))) == &"unexplored"
	var dimmed := TileTabs.dimmed_for(view)
	var expected: Array[StringName] = []
	if not unexplored:
		expected = TileTabs.for_view(view)
	assert_eq(panel.tab_ids(), expected, "%s: the strip holds the tabs that apply" % _tag)
	if unexplored:
		var head: Dictionary = view.get("header", {})
		assert_eq(str(head.get("title", "")), "Unexplored", "%s: an undiscovered hex is Unexplored" % _tag)
	var strip := _tile_strip_buttons(panel)
	var strip_ids: Array[StringName] = []
	for button: Button in strip:
		var id := StringName(str(button.get_meta("tab_id")))
		strip_ids.append(id)
		var reason := str(dimmed.get(id, ""))
		assert_eq(button.disabled, reason != "", "%s: tab %s is disabled exactly when it is dimmed" % [_tag, id])
		if reason != "":
			assert_eq(button.tooltip_text, reason, "%s: dimmed tab %s gives its reason" % [_tag, id])
	assert_eq(strip_ids, panel.tab_ids(), "%s: the strip shows exactly the shown tabs" % _tag)
	var live := panel.live_tab_ids()
	if live.is_empty():
		assert_eq(panel.tab_open(), &"", "%s: no live tab means no open tab" % _tag)
	else:
		assert_true(live.has(panel.tab_open()), "%s: the open tab is live" % _tag)
	if not Knowledge.discovered(game, viewer, hex):
		assert_true(unexplored, "%s: an undiscovered hex has the Unexplored view" % _tag)
		assert_true(panel.tab_ids().is_empty(), "%s: an undiscovered hex shows no tab" % _tag)
		if _fog:
			_fog_check_texts(panel, game, hex, "the tile window", _tag)
	for row: Dictionary in TileArmy.of(game, viewer, hex).get("armies", []):
		var army_tag := StringName(str(row.get("tag", "")))
		if army_tag == viewer:
			continue
		var seen := false
		for army: Army in game.armies:
			if army.hex == hex and army.tag == army_tag and ArmyView.visible(game, viewer, army):
				seen = true
				break
		assert_true(seen, "%s: a foreign army row is one the viewer sees (%s)" % [_tag, str(army_tag)])
	var rect := panel.get_global_rect()
	assert_true(Rect2(Vector2.ZERO, Vector2(vp.size)).grow(0.5).encloses(rect), "%s: the tile window lies in the viewport (%s)" % [_tag, str(rect)])
	var top := app.stack().top()
	if top is RaiseScreen:
		assert_ne((top as RaiseScreen).shown_hex(), RaiseScreen.NO_HEX, "%s: the Raise screen shows a hex" % _tag)
