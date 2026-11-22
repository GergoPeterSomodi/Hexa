## The HUD's M7 wiring (B28): the battle and country asks of the log, the notifications, the task flag and the army panel go out
## through the Hud, and the odds card is the hover's.
extends GutTest

const HUD_SCENE := preload("res://shell/hud/hud.tscn")

var _harness: UIHarness = null
var _hud: Hud = null
var _prev_game: Game = null


func before_each() -> void:
	Bindings.reset_defaults()
	_prev_game = Session.game
	Session.new_game(MapScene.MAP_ID, MapScene.START_SEED)
	_harness = UIHarness.new()
	_harness.mount(self)
	_hud = HUD_SCENE.instantiate() as Hud
	_harness.viewport.add_child(_hud)
	_hud.root().theme = KitTheme.load_for(1.0)
	_hud.setup(_harness.ctx)


func after_each() -> void:
	_hud = null
	Session.game = _prev_game
	Bindings.reset_defaults()


## The hud forwards the battle asks (a log line, a notification, the army panel) and the country asks of a notification and the
## task flag; its odds card is the hover's.
func test_the_hud_forwards_the_battle_and_country_asks_and_has_the_odds_card() -> void:
	var records: Array[int] = []
	var countries: Array[StringName] = []
	_hud.battle_requested.connect(func(record: int) -> void: records.append(record))
	_hud.country_requested.connect(func(tag: StringName) -> void: countries.append(tag))
	_hud.action_log().battle_requested.emit(3)
	_hud.notifications().battle_requested.emit(4)
	_hud.army_panel().battle_requested.emit(5)
	_hud.notifications().country_requested.emit(&"MLO")
	_hud.task_flag().country_requested.emit(&"GEN")
	assert_eq(records, [3, 4, 5], "three openers of the dock")
	assert_eq(countries, [&"MLO", &"GEN"], "two openers of a country")
	assert_same(_hud.odds_card(), _hud.map_hover().odds_card(), "the odds card is the hover's")


func test_the_castle_areas_switch_is_a_layer_of_the_popover_and_follows_the_setting() -> void:
	var settings := Settings.new("Windows", false)
	_hud.configure(settings)
	var popover := _hud.layers_popover()
	popover.set_castle_available(true)
	assert_true(popover.castle_switch().button_pressed, "on by default")
	var toggled: Array = []
	popover.layer_toggled.connect(func(key: StringName, on: bool) -> void: toggled.append([key, on]))
	popover.castle_switch().toggled.emit(false)
	assert_false(bool(settings.get_value("map/castle_areas")), "the switch writes the setting")
	assert_eq(toggled, [[LayersPopover.LAYER_CASTLE, false]], "and says which layer")
	settings.set_value("map/castle_areas", true)
	assert_true(popover.castle_switch().button_pressed, "the setting's change moves the switch")
	settings.set_value("map/castle_areas", "maybe")
	assert_true(bool(settings.get_value("map/castle_areas")), "planted: a bad value falls back to the default")
