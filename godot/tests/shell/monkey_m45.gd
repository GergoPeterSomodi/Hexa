## The M4.5 part of the UI monkey (test_ui_monkey.gd extends this, which extends MonkeyM4): the study's new inputs. Ctrl+[ and
## Ctrl+] (the tabs), [ and ] (the pages), clicks on the nav, the tab strips and every page's buttons, clicks and keys on the
## tables (a heading, a row, Enter, Ctrl+arrows), a click on a season of the timeline and its keys, a header of the action log,
## the pointer over a chart's points, "Show on the map", and keys 4 and 1 with a hover on the map. Invariants (m4-5-build-spec.md
## sections 6 and 9): the digest, the version, the Snapshot bytes and the Stats are unchanged by every study, page, tab, sort,
## hover, legend and Yields action (only Begin, set_tax, the dev actions and a Space may change them: a season that ended inside
## the step is counted and excuses the comparison); the legend shows exactly in Yields or Food (MonkeyM4) and the world is hidden exactly while the
## study is up (MonkeyM4's per-step invariants); no orphan growth, no error. Split out of the monkey to keep it under the lint's
## 1,200 lines.
class_name MonkeyM45
extends MonkeyM4

## An M4.5 action a seed must do runs from this step on when its counter is still 0 (after the M4 ones).
const FORCE_M45_STEP := 220
## The M4.5 counters a seed must raise above 0 (so its invariants cannot pass empty).
const M45_REQUIRED: Array[String] = [
	"m45_opens", "m45_tab_clicks", "m45_nav_clicks", "m45_head_clicks", "m45_row_clicks", "m45_row_keys", "m45_timeline",
	"m45_log_headers", "m45_chart_hovers", "m45_show_map", "m45_yields_keys", "m45_checks",
]
const PAGE_IDS: Array[StringName] = [&"economy", &"people", &"rankings", &"history"]
## The M4.5 actions are on (a country game with the M4.5 study).
var _m45: bool = false


# ----- what an action must leave -------------------------------------------------------------------------------------------------


## What no study input may change: M4's snapshot (digest, version, treasury, stores) with the Stats' digest, the bytes of the
## whole snapshot and the count of seasons ended so far (a season that ends inside a step excuses the comparison).
func _m45_snap() -> Dictionary:
	var out := _m4_snapshot()
	var game := Session.game
	out["stats"] = game.stats.digest() if game.stats != null else ""
	out["body"] = hash(var_to_bytes(Snapshot.of(game, {})))
	out["seasons"] = int(_n.get("seasons", 0))
	return out


## `what` leaves the digest, the version, the Stats and the snapshot as `before` took them (unless a season ended meanwhile).
func _m45_untouched(before: Dictionary, what: String) -> void:
	if Session.game == null or Session.game != before["game"] or int(_n.get("seasons", 0)) != int(before["seasons"]):
		return
	var now := _m45_snap()
	assert_eq(now["digest"], before["digest"], "%s: %s leaves the game digest" % [_tag, what])
	assert_eq(now["version"], before["version"], "%s: %s is not an action" % [_tag, what])
	assert_eq(now["stats"], before["stats"], "%s: %s leaves the Stats" % [_tag, what])
	assert_eq(now["body"], before["body"], "%s: %s leaves the snapshot" % [_tag, what])
	assert_eq(now["treasury"], before["treasury"], "%s: %s leaves the treasury" % [_tag, what])
	assert_eq(now["stock"], before["stock"], "%s: %s leaves the stores" % [_tag, what])
	_bump("m45_checks")


# ----- the dice ------------------------------------------------------------------------------------------------------------------


## The next M4.5 action, by the dice.
func _m45_step(rng: Rng, vp: SubViewport, app: App) -> void:
	if not _m4_ready(app):
		return
	_m4_note("m4.5")
	match rng.randi_range(0, 11):
		0, 1:
			await _m45_pages(rng, vp, app)
		2, 3:
			await _m45_table(rng, vp, app)
		4:
			await _m45_timeline(rng, vp, app)
		5:
			await _m45_log_header(rng, vp, app)
		6, 7:
			await _m45_chart(rng, vp, app)
		8:
			await _m45_show_on_map(rng, vp, app)
		9, 10:
			await _m45_yields(rng, vp, app)
		_:
			await _m45_buttons(rng, vp, app)


## From FORCE_M45_STEP on, the first M4.5 action whose counter is still 0 (one a step, so a seed never passes empty).
func _m45_force(rng: Rng, vp: SubViewport, app: App) -> void:
	if not _m4_ready(app):
		return
	if int(_n["m45_opens"]) == 0 or int(_n["m45_tab_clicks"]) == 0 or int(_n["m45_nav_clicks"]) == 0:
		await _m45_pages(rng, vp, app, true)
	elif int(_n["m45_head_clicks"]) == 0 or int(_n["m45_row_clicks"]) == 0 or int(_n["m45_row_keys"]) == 0:
		await _m45_table(rng, vp, app, true)
	elif int(_n["m45_timeline"]) == 0:
		await _m45_timeline(rng, vp, app)
	elif int(_n["m45_log_headers"]) == 0:
		await _m45_log_header(rng, vp, app)
	elif int(_n["m45_chart_hovers"]) == 0:
		await _m45_chart(rng, vp, app)
	elif int(_n["m45_show_map"]) == 0:
		await _m45_show_on_map(rng, vp, app)
	elif int(_n["m45_yields_keys"]) == 0:
		await _m45_yields(rng, vp, app)


# ----- opening ----------------------------------------------------------------------------------------------------------------------


## L, then the keys to `page` and (on Economy) Ctrl+] to the tab at `tab`. The Study, or null when it did not open.
func _m45_goto(vp: SubViewport, app: App, page: StringName, tab: int) -> Study:
	_send_chord(vp, KEY_L)
	_bump("study_l")
	await _wait_frames(3)
	var study := app.stack().top() as Study
	if study == null:
		return null
	_bump("m45_opens")
	_bump("studies")
	var guard := 0
	while study.current_page_id() != page and guard < 4:
		_send_chord(vp, KEY_BRACKETRIGHT)
		_bump("study_page_keys")
		await _wait_frames(2)
		guard += 1
	assert_eq(study.current_page_id(), page, "%s: [ and ] reach the %s page" % [_tag, String(page)])
	if page == &"economy":
		for _i: int in tab:
			_send_chord(vp, KEY_BRACKETRIGHT, true)
			_bump("study_tab_keys")
			await _wait_frames(2)
		var shown := study.current_page().shown_tabs()
		if tab < shown.size():
			assert_eq(study.current_page().current_tab(), StringName(str(shown[tab]["id"])), "%s: Ctrl+] reaches tab %d" % [_tag, tab])
	return study


func _m45_study_of(app: App) -> Study:
	return app.stack().top() as Study


## Every visible node of `class_label` under `root` that shows in the window.
func _m45_visible(root: Node, class_label: String) -> Array[Control]:
	var out: Array[Control] = []
	for node: Node in root.find_children("*", class_label, true, false):
		var ctrl := node as Control
		if ctrl != null and ctrl.is_visible_in_tree() and ctrl.get_global_rect().has_area():
			out.append(ctrl)
	return out


## A point of `ctrl` (a fraction of its size) in the window, clamped to its rectangle.
func _m45_point(ctrl: Control, fx: float, fy: float) -> Vector2:
	var rect := ctrl.get_global_rect()
	return rect.position + Vector2(rect.size.x * clampf(fx, 0.02, 0.98), rect.size.y * clampf(fy, 0.02, 0.98))


func _m45_move(vp: SubViewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)


# ----- pages, tabs, the nav -----------------------------------------------------------------------------------------------------------


## L, a page and a tab by the keys, then clicks on the nav and the tab strip and more keys; nothing changes the game.
func _m45_pages(rng: Rng, vp: SubViewport, app: App, force: bool = false) -> void:
	var before := _m45_snap()
	var page := &"economy" if force else PAGE_IDS[rng.randi_range(0, PAGE_IDS.size() - 1)]
	var study := await _m45_goto(vp, app, page, rng.randi_range(0, 3))
	if study == null:
		return
	_m45_untouched(before, "opening a page by the keys")
	for _i: int in range(rng.randi_range(2, 4)):
		study = _m45_study_of(app)
		if study == null:
			break
		var dice := 0 if (force and _i == 0) else (1 if (force and _i == 1) else rng.randi_range(0, 4))
		match dice:
			0:  # a click on a tab of the strip
				var strip := study.current_page().get_node_or_null("TabStrip") as Segmented
				if strip != null and strip.visible:
					var shown := study.current_page().shown_tabs()
					var id: Variant = shown[rng.randi_range(0, shown.size() - 1)]["id"]
					if _m4_press(vp, strip.button_for(StringName(str(id)))):
						_bump("m45_tab_clicks")
					await _wait_frames(2)
					assert_true(app.stack().top() is Study, "%s: a tab click keeps the study" % _tag)
			1:  # a click on a page of the nav
				var ids := PAGE_IDS
				var button := study.nav().button_for(ids[rng.randi_range(0, ids.size() - 1)])
				if _m4_press(vp, button):
					_bump("m45_nav_clicks")
				await _wait_frames(2)
			2:
				_send_chord(vp, KEY_BRACKETRIGHT if rng.randi_range(0, 1) == 0 else KEY_BRACKETLEFT)
				_bump("study_page_keys")
				await _wait_frames(2)
			_:
				_send_chord(vp, KEY_BRACKETRIGHT if rng.randi_range(0, 1) == 0 else KEY_BRACKETLEFT, true)
				_bump("study_tab_keys")
				await _wait_frames(2)
		_m45_untouched(before, "a click or a key in the study's frame")
	await _m4_close_study(rng, vp, app)
	_m45_untouched(before, "closing the study")


## A click on any button of the open page but the tax levels and the page's own country rows (those pop the study at once).
func _m45_buttons(rng: Rng, vp: SubViewport, app: App) -> void:
	var before := _m45_snap()
	var study := await _m45_goto(vp, app, PAGE_IDS[rng.randi_range(0, PAGE_IDS.size() - 1)], rng.randi_range(1, 3))
	if study == null:
		return
	var buttons: Array[BaseButton] = []
	for button: BaseButton in _collect_clickable_buttons(study.current_page()):
		if not _m4_in_tax_row(button):
			buttons.append(button)
	if not buttons.is_empty():
		var btn := buttons[rng.randi_range(0, buttons.size() - 1)]
		var scroll := _m4_scroll_of(btn)
		if scroll != null:
			scroll.ensure_control_visible(btn)
			await _wait_frames(1)
		_m4_press(vp, btn)
		await _wait_frames(3)
	_m45_untouched(before, "a click on a button of a page")
	await _m4_close_study(rng, vp, app)


# ----- tables ---------------------------------------------------------------------------------------------------------------------------


## The tables the open study shows.
func _m45_tables(app: App) -> Array[StudyTable]:
	var out: Array[StudyTable] = []
	var study := _m45_study_of(app)
	if study == null:
		return out
	for ctrl: Control in _m45_visible(study.current_page(), "StudyTable"):
		out.append(ctrl as StudyTable)
	return out


## A heading, a row, Enter, Ctrl+arrows, End, "show more" on a table of Districts, Goods, Rankings or History.
func _m45_table(rng: Rng, vp: SubViewport, app: App, force: bool = false) -> void:
	var before := _m45_snap()
	var page := &"economy" if force else PAGE_IDS[rng.randi_range(0, PAGE_IDS.size() - 1)]
	var study := await _m45_goto(vp, app, page, 1 if force else rng.randi_range(1, 2))
	if study == null:
		return
	var tables := _m45_tables(app)
	if tables.is_empty():
		await _m4_close_study(rng, vp, app)
		return
	var table := tables[rng.randi_range(0, tables.size() - 1)]
	var tree := table.tree()
	var steps := 3 if force else rng.randi_range(2, 5)
	for i: int in steps:
		if _m45_study_of(app) == null or not is_instance_valid(table):
			break
		var dice := rng.randi_range(0, 6)
		if force:
			dice = i % 3
		match dice:
			0:  # a heading: the signal or a real click on it
				var column := rng.randi_range(0, maxi(tree.columns - 1, 0))
				if rng.randi_range(0, 1) == 0:
					tree.column_title_clicked.emit(column, MOUSE_BUTTON_LEFT)
				else:
					var x := 0.0
					for c: int in column:
						x += float(tree.get_column_width(c))
					x += float(tree.get_column_width(column)) * 0.5
					_send_click(vp, tree.get_global_rect().position + Vector2(x, 8.0), MOUSE_BUTTON_LEFT)
				_bump("m45_head_clicks")
			1:  # a row: a real click on its first cell, or select_id
				var root := tree.get_root()
				var ids := table.sorted_ids()
				if root != null and root.get_child_count() > 0 and not ids.is_empty():
					var item := root.get_child(rng.randi_range(0, root.get_child_count() - 1))
					var rect := tree.get_item_area_rect(item, 0)
					var at := tree.get_global_rect().position + rect.get_center()
					if tree.get_global_rect().has_point(at) and Rect2(Vector2.ZERO, Vector2(vp.size)).has_point(at):
						_send_click(vp, at, MOUSE_BUTTON_LEFT)
					else:
						table.select_id(int(ids[rng.randi_range(0, ids.size() - 1)]))
					_bump("m45_row_clicks")
			2:  # Enter on the selected row looks there or opens a country (the study may pop)
				tree.grab_focus()
				_send_chord(vp, KEY_ENTER)
				_bump("m45_row_keys")
			3:
				tree.grab_focus()
				_send_chord(vp, KEY_LEFT if rng.randi_range(0, 1) == 0 else KEY_RIGHT, true)
				_bump("m45_row_keys")
			4:
				tree.grab_focus()
				_send_chord(vp, KEY_UP if rng.randi_range(0, 1) == 0 else KEY_DOWN, true)
				_bump("m45_row_keys")
			5:
				tree.grab_focus()
				_send_chord(vp, KEY_END if rng.randi_range(0, 1) == 0 else KEY_HOME)
				_bump("m45_row_keys")
			_:
				if table.total_count() > table.shown_count():
					table.show_more()
					_bump("m45_row_keys")
		await _wait_frames(2)
		_m45_untouched(before, "a click or a key on a table")
	if not (_m45_study_of(app) == null):
		await _m4_close_study(rng, vp, app)
	_m45_untouched(before, "a table's sort and rows")


# ----- the timeline, the log's headers, the charts -------------------------------------------------------------------------------------------


## History: a click on a season of the timeline, then Left, Right, Shift+Right, Home, End, Enter on it.
func _m45_timeline(rng: Rng, vp: SubViewport, app: App) -> void:
	var game := Session.game
	if game.turn <= Calendar.FIRST_TURN:
		return  # no season has ended: the timeline has none
	var before := _m45_snap()
	var study := await _m45_goto(vp, app, &"history", 0)
	if study == null:
		return
	var page := study.current_page() as PageHistory
	if page != null and page.timeline().is_visible_in_tree():
		var strip := page.timeline()
		var turn := rng.randi_range(Calendar.FIRST_TURN, game.turn - 1)
		_send_click(vp, strip.get_global_rect().position + Vector2(strip.season_x(turn), strip.size.y * 0.5), MOUSE_BUTTON_LEFT)
		_bump("m45_timeline")
		await _wait_frames(2)
		assert_between(page.cursor_turn(), Calendar.FIRST_TURN, game.turn - 1, "%s: the cursor stays on a season" % _tag)
		strip.grab_focus()
		var keys: Array[Key] = [KEY_LEFT, KEY_RIGHT, KEY_HOME, KEY_END, KEY_ENTER]
		for _i: int in range(rng.randi_range(1, 4)):
			if _m45_study_of(app) == null:
				break
			_send_chord(vp, keys[rng.randi_range(0, keys.size() - 1)], false, rng.randi_range(0, 3) == 0)
			await _wait_frames(2)
			_m45_untouched(before, "a key on the timeline")
		_m45_move(vp, _m45_point(strip, 0.4, 0.5))
		await _wait_frames(2)
		_m45_move(vp, Vector2(4.0, 4.0))
		await _wait_frames(1)
	_m45_untouched(before, "the timeline")
	if _m45_study_of(app) != null:
		await _m4_close_study(rng, vp, app)


## The log's bar, a header of an older season (the study at History) or the newest (the report); nothing changes the game.
func _m45_log_header(rng: Rng, vp: SubViewport, app: App) -> void:
	var before := _m45_snap()
	var action_log := app.hud().action_log()
	action_log.open()
	await _wait_frames(3)
	var headers := action_log.header_buttons()
	if not headers.is_empty():
		var header := headers[rng.randi_range(0, headers.size() - 1)]
		if _m4_press(vp, header):
			_bump("m45_log_headers")
		await _wait_frames(3)
		var top := app.stack().top()
		if top != null:
			assert_true(top is Study or top is SeasonReport, "%s: a log header opens the study or the report (%s)" % [_tag, str(top.screen_id)])
			var study := top as Study
			if study != null:
				assert_eq(study.current_page_id(), &"history", "%s: an older header opens History" % _tag)
				assert_true(app.hides_world(), "%s: the study hides the world" % _tag)
	_m45_untouched(before, "a header of the log")
	if action_log.is_open():
		action_log.close()
	var guard := 0
	while app.stack().count() > 0 and guard < 8:
		if not app.stack().back():
			app.stack().pop()
		guard += 1
		await _wait_frames(1)
	assert_eq(app.stack().count(), 0, "%s: the screens closed" % _tag)


## The pointer over a chart's points (and a click or keys on the one that has the focus); the chart's hover card comes and goes.
func _m45_chart(rng: Rng, vp: SubViewport, app: App) -> void:
	var before := _m45_snap()
	var tab := rng.randi_range(2, 3)
	var page_ids: Array[StringName] = [&"economy", &"people", &"rankings", &"history"]
	var page := page_ids[rng.randi_range(0, page_ids.size() - 1)]
	var study := await _m45_goto(vp, app, page, tab)
	if study == null:
		return
	var charts := _m45_visible(study.current_page(), "InkChart")
	if not charts.is_empty():
		var chart := charts[rng.randi_range(0, charts.size() - 1)] as InkChart
		for _i: int in range(rng.randi_range(2, 4)):
			_m45_move(vp, _m45_point(chart, rng.randf(), rng.randf()))
			await _wait_frames(2)
			_bump("m45_chart_hovers")
		if rng.randi_range(0, 2) == 0:
			_send_click(vp, _m45_point(chart, rng.randf(), 0.5), MOUSE_BUTTON_LEFT)
			await _wait_frames(2)
		chart.grab_focus()
		for _i: int in range(rng.randi_range(0, 3)):
			_send_chord(vp, KEY_LEFT if rng.randi_range(0, 1) == 0 else KEY_RIGHT)
			await _wait_frames(1)
		_m45_untouched(before, "the pointer over a chart")
		_m45_move(vp, Vector2(4.0, 4.0))
		await _wait_frames(2)
	_m45_untouched(before, "a chart's points")
	if _m45_study_of(app) != null:
		await _m4_close_study(rng, vp, app)


# ----- Show on the map, Yields -----------------------------------------------------------------------------------------------------------------


## Districts, "Show on the map" (or Look there): the study closes; Show on the map leaves the map in Yields with its legend.
func _m45_show_on_map(rng: Rng, vp: SubViewport, app: App) -> void:
	var before := _m45_snap()
	var study := await _m45_goto(vp, app, &"economy", 1)
	if study == null:
		return
	var tab := study.current_page().get_node_or_null("districts") as EconomyDistrictsTab
	if tab != null:
		var show := rng.randi_range(0, 2) != 0
		var button := tab.show_button() if show else tab.look_button()
		if _m4_press(vp, button):
			await _wait_frames(3)
			if show:
				_bump("m45_show_map")
				assert_eq(app.map_scene().mode(), int(MapModes.Mode.YIELDS), "%s: Show on the map leaves the map in Yields" % _tag)
				if app.hud().is_hud_visible():  # H hides the HUD, the legend with it
					assert_true(app.hud().mode_legend().visible, "%s: and its legend shows" % _tag)
			assert_false(app.stack().has_screen(&"study"), "%s: the study closes" % _tag)
	_m45_untouched(before, "Show on the map")
	if _m45_study_of(app) != null:
		await _m4_close_study(rng, vp, app)


## Key 4 (Yields: the legend shows), the pointer over some land (the hex card, with its Worth line), key 1 (the legend is gone).
func _m45_yields(rng: Rng, vp: SubViewport, app: App) -> void:
	var before := _m45_snap()
	_send_chord(vp, KEY_4)
	_bump("m45_yields_keys")
	await _wait_frames(3)
	var legend := app.hud().mode_legend()
	if app.map_scene().mode() == int(MapModes.Mode.YIELDS) and app.hud().is_hud_visible() and not app.hides_world():  # H hides the HUD
		assert_true(legend.visible, "%s: Yields: the legend shows" % _tag)
	for _i: int in range(rng.randi_range(1, 3)):
		_m45_move(vp, Vector2(float(rng.randi_range(200, vp.size.x - 200)), float(rng.randi_range(120, vp.size.y - 120))))
		await _wait_frames(2)
	_m45_untouched(before, "key 4 and the pointer over the map")
	if rng.randi_range(0, 3) != 0:
		_send_chord(vp, [KEY_1, KEY_2, KEY_3][rng.randi_range(0, 2)] as Key)
		await _wait_frames(3)
		assert_false(legend.visible, "%s: another mode: no legend" % _tag)
	_m45_untouched(before, "a map mode key")
