## The barracks tile in the running App (docs/design/recruitment-queue.md 8; task RQ3): its icon and tooltip, the hover
## card from the pointer and the keyboard, a click that begins it (and one that cards it first), the toasts, the tile's
## states as the work runs, the footer's Cancel and the work mark. Milan on seed 1480 with a passive world.
extends GutTest

const APP_SCENE := preload("res://shell/app/app.tscn")
const MLO := &"MLO"
const MILAN := Vector2i(9, 9)

var _prev_game: Game = null
var _old_save_dir: String = ""
var _old_lock_path: String = ""


func before_each() -> void:
	Session.ai_enabled = false
	Bindings.reset_defaults()
	_prev_game = Session.game
	_old_save_dir = Session.save_dir
	_old_lock_path = RunLock.path
	Session.save_dir = "user://test_barracks_ui_saves"
	RunLock.path = "user://test_barracks_ui_running.lock"


func after_each() -> void:
	for slot: String in SaveFile.SLOTS + SaveFile.AUTO_SLOTS:
		SaveFile.remove(slot, Session.save_dir)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Session.save_dir))
	RunLock.clear()
	Session.save_dir = _old_save_dir
	RunLock.path = _old_lock_path
	Session.game = _prev_game
	Session.ai_enabled = true
	Bindings.reset_defaults()
	RenderingServer.set_default_clear_color(MapScene.SEA_COLOUR)


func _wait_frames(frames: int = 3) -> void:
	for _i: int in range(frames):
		await get_tree().process_frame


## A Milan game in a SubViewport, the map ready.
func _app() -> App:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.gui_disable_input = false
	add_child_autofree(vp)
	var app := APP_SCENE.instantiate() as App
	app.settings_path = ""
	app.allow_tree_quit = false
	app.pause_tree_when_modal = false
	app.cli_args_override = PackedStringArray(["--new-game", "--country=MLO", "--seed=1480"])
	var s := Settings.new("macOS", true)
	s.set_value("state/help_seen", true)
	s.set_value("graphics/preload_next_season", false)
	app.set_settings_override(s)
	vp.add_child(app)
	var frames := 0
	while (app.map_scene() == null or app.stack().count() > 0 or app.is_starting()) and frames < 3000:
		await get_tree().process_frame
		frames += 1
	assert_not_null(app.map_scene(), "the game is up")
	app.settings().set_value("game/autosave", "off")
	await _wait_frames()
	return app


## The first town or larger of Milan with no barracks, in a climate where no winter halts a work.
func _town() -> Vector2i:
	var g := Session.game
	for i: int in Territory.districts(g, Countries.by_tag(g, MLO).id):
		if int(g.state.main_use[i]) == ImproveRules.SETTLEMENT and g.state.barracks[i] == 0 and int(g.state.level[i]) >= 3 \
				and g.map.climate[i] != 0:
			return g.map.hex_of(i)
	return Army.NO_HEX


func _select(app: App, hex: Vector2i) -> void:
	app.map_scene().select_hex(hex)
	await _wait_frames()
	assert_true(app.hud().tile_window().show_tab(&"town"))
	await _wait_frames()


func _tile(app: App) -> BuildingRow:
	var found: Array[BuildingRow] = []
	for row: BuildingRow in app.hud().tile_window().building_rows():
		if row.data().get("kind", &"") == BarracksView.KIND:
			found.append(row)
	assert_eq(found.size(), 1, "one barracks tile")
	return found[0] if found.size() == 1 else null


func test_the_offer_has_its_icon_tooltip_and_card_by_pointer_and_keyboard() -> void:
	var app := await _app()
	var town := _town()
	await _select(app, town)
	var tile := _tile(app)
	assert_eq(tile.hammer().tooltip_text, "Build a barracks")
	assert_eq(tile.hammer().accessibility_name, "Build a barracks")
	assert_false(tile.hammer().disabled)
	assert_eq([tile.marks()["icon"], tile.marks()["corner"], tile.level_text()], [&"barracks", &"plus", ""])
	assert_true(tile.has_theme_icon(&"barracks", &"Kit"), "the kit has the barracks icon")
	var icon := tile.get_theme_icon(&"barracks", &"Kit")
	assert_ne(icon, tile.get_theme_icon(&"settlement", &"Kit"), "its own icon")
	tile.mouse_entered.emit()
	await _wait_frames()
	var card := app.hud().row_card()
	assert_true(card != null and card.visible, "the hover card shows")
	assert_eq(card.title_text(), "Build: Barracks")
	assert_true(AppFlowHelpers.labels_under(card).has(BarracksView.ABOUT))
	tile.mouse_exited.emit()
	await _wait_frames()
	assert_false(card.visible)
	tile.hammer().grab_focus()
	await _wait_frames()
	assert_true(card.visible, "the keyboard shows it too")
	assert_eq(card.title_text(), "Build: Barracks")
	var summary := (app.hud().tile_window().tab_node() as TownTab)
	summary.finish_now()
	assert_eq(tile.state_text(), "cost 150 · 10 timber · 10 stone · upkeep 4", "the upkeep once")
	assert_eq(tile.gain_text(), "", "no gain")


func test_enter_begins_it_with_its_toast_row_mark_and_cancel() -> void:
	var app := await _app()
	var town := _town()
	app.settings().set_value("game/confirm_works", "off")
	await _select(app, town)
	var vp := app.get_viewport() as SubViewport
	_tile(app).hammer().grab_focus()
	for pressed: bool in [true, false]:
		var ev := InputEventAction.new()
		ev.action = &"ui_accept"
		ev.pressed = pressed
		vp.push_input(ev)
	await _wait_frames()
	var work := Session.game.state.work_at(town)
	assert_not_null(work, "Enter on the tile began the work")
	assert_eq(work.action, Works.BARRACKS)
	var at := Words.at(Session.game, town)
	assert_true(AppFlowHelpers.has_toast(app, "Barracks begun %s. −150 ducats, −10 timber, −10 stone. Ready Spring 1481." % at),
		str(AppFlowHelpers.toasts(app)))
	var tile := _tile(app)
	assert_eq([tile.name_text(), tile.state_text(), tile.shows_bar(), tile.level_text()],
		["Barracks", "building · 1 of 4 seasons", true, ""])
	assert_eq(tile.marks()["icon"], &"barracks")
	assert_eq(app.map_scene().work_marks().mark_at(town).get("text"), "1/4")
	tile.mouse_entered.emit()
	await _wait_frames()
	assert_true(AppFlowHelpers.labels_under(app.hud().row_card()).has("Being built: 1 of 4 seasons, ready Spring 1481."))
	var cancel := AppFlowHelpers.row_button(app, "Cancel the work")
	assert_not_null(cancel)
	cancel.pressed.emit()
	await _wait_frames()
	assert_null(Session.game.state.work_at(town))
	assert_true(AppFlowHelpers.has_toast(app, "Barracks cancelled %s. +150 ducats, +10 timber, +10 stone back." % at),
		str(AppFlowHelpers.toasts(app)))
	assert_eq(_tile(app).data()["state"], &"ready")


func test_confirm_always_cards_it_and_begin_builds_it() -> void:
	var app := await _app()
	var town := _town()
	app.settings().set_value("game/confirm_works", "always")
	await _select(app, town)
	_tile(app).press_hammer()
	await _wait_frames()
	var screen := app.stack().top() as WorksPreview
	assert_not_null(screen, "the works card opens")
	assert_eq(screen.shown_option(), BarracksView.option())
	var card := screen.card()
	assert_eq(card.title_label().text, "%s, barracks" % str(Improve.place_of(Session.game.map, town)["name"]))
	assert_false(card.begin_button().disabled)
	assert_eq(card.cost_label().text, "150 ducats · 10 timber · 10 stone · 4 seasons · ready Spring 1481")
	assert_false(card.season_strip().visible, "no seasons to compare")
	assert_false(card.chart().is_visible_in_tree(), "no gain chart")
	assert_eq(card.next_label().text, BarracksView.ABOUT)
	assert_null(Session.game.state.work_at(town))
	card.begin_pressed.emit()
	await _wait_frames()
	assert_not_null(Session.game.state.work_at(town), "Begin builds it")
	assert_eq(Session.game.state.work_at(town).action, Works.BARRACKS)


func test_the_capital_shows_its_standing_barracks_with_no_level() -> void:
	var app := await _app()
	await _select(app, MILAN)
	var tile := _tile(app)
	assert_eq([tile.name_text(), tile.shows_check(), tile.level_text(), tile.hammer().visible], ["Barracks", true, "", false])
	var tab := app.hud().tile_window().tab_node() as TownTab
	tab.finish_now()
	assert_eq(tile.state_text(), "working · upkeep 4")
	assert_eq(tile.gain_text(), "")
	assert_eq(tab.summary_text(), "Buildings here make 0 a year · upkeep -4")
	var cards: Array = []
	tab.row_hovered.connect(func(card: Dictionary, _anchor: Rect2) -> void: cards.append(card))
	tile.mouse_entered.emit()
	assert_eq(cards, [BuildingCard.of(Session.game, MLO, MILAN, BarracksView.option())])


## A barracks has no year: pinned beside another work, the compare column shows no gain chip for it.
func test_the_compare_column_shows_no_gain_for_a_barracks() -> void:
	var app := await _app()
	var town := _town()
	await _select(app, town)
	var preview := ImprovePreview.of(Session.game, MLO, town, BarracksView.option())
	var card := (load("res://shell/ui/preview_card.tscn") as PackedScene).instantiate() as PreviewCard
	add_child_autofree(card)
	card.show_compare(preview, preview)
	await _wait_frames(1)
	assert_eq(card.compare_container().find_children("*", "DeltaChip", true, false).size(), 0)
	var with_year := preview.duplicate(true)
	with_year["year"] = {"gain": 3}
	card.show_compare(with_year, preview)
	await _wait_frames(1)
	assert_eq(card.compare_container().find_children("*", "DeltaChip", true, false).size(), 1, "a card with a year has one")
	var losing := preview.duplicate(true)
	losing["year"] = {"gain": -4}
	card.show_compare(preview, losing)
	await _wait_frames(1)
	var marked := card.compare_container().find_children("*", "Label", true, false).filter(
		func(n: Node) -> bool: return (n as Label).theme_type_variation == &"SectionHead" and (n as Label).text == str(preview["title"]))
	assert_eq(marked.size(), 0, "a barracks is not marked better than a card that loses money")


## Milan's villages with no barracks, in a climate where no winter halts a work.
func _villages() -> Array[Vector2i]:
	var g := Session.game
	var out: Array[Vector2i] = []
	for i: int in Territory.districts(g, Countries.by_tag(g, MLO).id):
		if int(g.state.main_use[i]) == ImproveRules.SETTLEMENT and g.state.barracks[i] == 0 and int(g.state.level[i]) <= 2 \
				and g.map.climate[i] != 0:
			out.append(g.map.hex_of(i))
	return out


## Gives every town of Milan to Savoy, its capital and the barracks there with them (decision 25's country).
func _lose_every_town() -> void:
	var g := Session.game
	var towns: Array[Vector2i] = []
	for i: int in Territory.districts(g, Countries.by_tag(g, MLO).id):
		if int(g.state.main_use[i]) == ImproveRules.SETTLEMENT and int(g.state.level[i]) >= 3:
			towns.append(g.map.hex_of(i))
	g.dev_transfer(towns, Countries.by_tag(g, &"SAV").id)


## Decision 25: while Milan has a town its villages need one; with no town and no barracks a village offers it and begins
## it, another village is locked while it is built, and a cancel opens it again.
func test_a_village_needs_a_town_until_there_is_neither_town_nor_barracks() -> void:
	var app := await _app()
	app.settings().set_value("game/confirm_works", "always")
	var villages := _villages()
	assert_gt(villages.size(), 1, "precondition: Milan has two villages")
	var first := villages[0]
	var second := villages[1]
	await _select(app, first)
	var tile := _tile(app)
	assert_eq([tile.data()["state"], tile.state_text(), tile.shows_lock(), tile.hammer().disabled],
		[&"locked", "needs a town", true, true])
	tile.press_hammer()
	await _wait_frames()
	assert_eq(app.stack().count(), 0, "a locked tile opens nothing")
	_lose_every_town()
	await _select(app, second)
	await _select(app, first)
	tile = _tile(app)
	(app.hud().tile_window().tab_node() as TownTab).finish_now()
	assert_eq([tile.data()["state"], tile.state_text(), tile.shows_lock(), tile.hammer().disabled],
		[&"ready", "cost 150 · 10 timber · 10 stone · upkeep 4", false, false])
	assert_eq(tile.hammer().tooltip_text, "Build a barracks")
	tile.press_hammer()
	await _wait_frames()
	var screen := app.stack().top() as WorksPreview
	assert_not_null(screen, "the works card opens")
	if screen == null:
		return
	var card := screen.card()
	var needs := AppFlowHelpers.labels_under(card.requirements_container())
	assert_true(needs.any(func(text: String) -> bool: return text.contains(BarracksView.SMALL_NEED)), str(needs))
	card.begin_pressed.emit()
	await _wait_frames()
	assert_not_null(Session.game.state.work_at(first), "Begin builds it on the village")
	await _select(app, second)
	tile = _tile(app)
	assert_eq([tile.data()["state"], tile.state_text(), tile.hammer().disabled], [&"locked", "needs a town", true])
	await _select(app, first)
	var cancel := AppFlowHelpers.row_button(app, "Cancel the work")
	assert_not_null(cancel)
	cancel.pressed.emit()
	await _wait_frames()
	assert_null(Session.game.state.work_at(first))
	await _select(app, second)
	assert_eq(_tile(app).data()["state"], &"ready", "cancelled: on offer again")


## A foreign barracks being built is marked on the map only while an army sees its hex (RQ3).
func test_a_foreign_barracks_mark_follows_sight() -> void:
	var g := EconomyFixture.game(&"GEN")
	var seen_never := Army.NO_HEX
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if int(g.state.main_use[i]) == ImproveRules.SETTLEMENT and not (Territory.owner_tag(g, hex) in [&"", &"GEN"]) 				and Knowledge.discovered(g, &"GEN", hex) and not Knowledge.sees(g, &"GEN", hex):
			seen_never = hex
			break
	assert_ne(seen_never, Army.NO_HEX, "a foreign settlement discovered and out of sight")
	var w := Work.new()
	w.id = g.state.next_work_id
	w.tag = Territory.owner_tag(g, seen_never)
	w.hex = seen_never
	w.action = Works.BARRACKS
	w.family = ImproveRules.SETTLEMENT
	w.started_turn = g.turn
	w.seasons = 4
	w.seasons_left = 4
	g.state.works.append(w)
	var marks := WorkMarks.new()
	add_child_autofree(marks)
	marks.setup(g)
	assert_eq(marks.mark_at(seen_never), {}, "no mark out of sight")
	var army := Army.new()
	army.id = 999
	army.tag = &"GEN"
	army.hex = seen_never
	g.armies.append(army)
	Sight.refresh(g)
	await _wait_frames(2)
	assert_false(marks.mark_at(seen_never).is_empty(), "marked while an army sees it")
	g.armies.erase(army)
	Sight.refresh(g)
	await _wait_frames(2)
	assert_eq(marks.mark_at(seen_never), {}, "gone when the army leaves")
