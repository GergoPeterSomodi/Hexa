## The toasts of the Raise tab and the army panel's disband (docs/architecture/m6-build-spec.md 6.8 and 6.10; L19 follow-up).
## A raise click toasts "Raised 1 company of pikemen at Turin (5, 9): −25 ducats, −1 iron." once; a refused raise toasts its reason
## (warn); a disband that is done toasts "Disbanded 1 company of pikemen: +10 ducats back, 500 men home to Turin (5, 9)." once.
## Planted faults to catch: a toast twice on one click, a toast before a refused act, wording that drops the refund or the men.
extends GutTest

const WINDOW := "res://shell/panels/tile_window.tscn"
const ARMY_PANEL := "res://shell/panels/army_panel.tscn"
const TAG := ArmyFixture.TAG

var _g: Game
var _hex := Vector2i(-1, -1)
var _toasts: Array[Array] = []


func before_each() -> void:
	_g = ArmyFixture.game()
	_hex = ArmyFixture.find_town(_g)
	ArmyFixture.town(_g, _hex)
	ArmyFixture.rich(_g)
	Session.start_game(_g)
	_toasts = []


func after_each() -> void:
	Session.end_game()
	await get_tree().process_frame


func _listen(source: Signal) -> void:
	source.connect(func(text: String, tone: StringName) -> void: _toasts.append([text, tone]))


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func test_raise_click_toasts_its_words_once() -> void:
	var panel := (load(WINDOW) as PackedScene).instantiate() as TileWindow
	panel.theme = KitTheme.load_for(1.0)
	add_child_autofree(panel)
	_listen(panel.toast_requested)
	panel.show_hex(_hex)
	assert_true(panel.show_tab(&"army"), "the Army tab is live on an own settlement")
	await _settle()
	var cost := Military.cost_of(_g, 0, 1)
	var expected := "Raised 1 company of pikemen at %s: −%d ducats, −%d iron." % [
		Military.hex_text(_g, _hex), int(cost["ducats"]), int((cost["goods"] as Dictionary)["iron"])]
	(panel.tab_node() as ArmyTab).company_rows()[0].hammer().pressed.emit()
	assert_eq(_toasts.size(), 1, "one click, one toast")
	assert_eq(_toasts[0][0], expected, "the raise's words")
	assert_eq(_toasts[0][1], &"plain")


func test_refused_raise_toasts_its_reason_as_a_warning() -> void:
	var panel := (load(WINDOW) as PackedScene).instantiate() as TileWindow
	panel.theme = KitTheme.load_for(1.0)
	add_child_autofree(panel)
	_listen(panel.toast_requested)
	panel.show_hex(_hex)
	assert_true(panel.show_tab(&"army"), "the Army tab is live on an own settlement")
	await _settle()
	Countries.by_tag(_g, TAG).treasury = 0
	(panel.tab_node() as ArmyTab).raise_company(0)
	assert_eq(_toasts.size(), 1, "one refused click, one toast")
	assert_true(str(_toasts[0][0]).contains("not enough ducats"), str(_toasts[0][0]))
	assert_eq(_toasts[0][1], &"warn")
	assert_eq(Military.raised_here(_g, TAG, _hex), 0, "and nothing was raised")


func test_disband_toasts_its_words_once() -> void:
	var panel := (load(ARMY_PANEL) as PackedScene).instantiate() as ArmyPanel
	panel.theme = KitTheme.load_for(1.0)
	add_child_autofree(panel)
	var army := Armies.create(_g, TAG, _hex, "Army of test")
	Armies.add_units(_g, army, 0, 1, _g.turn, _hex, 10, {})
	_g.version += 1
	var men := Words.men(army.units[0].men)
	_listen(panel.toast_requested)
	panel.show_army(army.id)
	await _settle()
	panel.action_button("disband").pressed.emit()
	assert_eq(_toasts.size(), 1, "one disband, one toast")
	assert_eq(_toasts[0][0], "Disbanded 1 company of pikemen: +10 ducats back, %s home to %s." % [
		men, Military.hex_text(_g, _hex)], "the disband's words")
	assert_eq(_toasts[0][1], &"plain")
	assert_eq(Armies.by_id(_g, army.id), null, "the army is gone with its only company")
