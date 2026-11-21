## GUT test for the top bar's fifth mode segment (docs/architecture/m5-build-spec.md 6.1, 6.10): Food, key 5, only in a game with a
## player. It sits beside test_hud.gd, whose size it keeps down.
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
	_harness = null
	Session.game = _prev_game
	Bindings.reset_defaults()


func test_the_mode_switch_has_six_segments_food_is_key_5_and_supply_is_key_6() -> void:
	await _harness.wait_frames(self, 2)
	var top := _hud.top_bar()
	var seg := top.mode_segmented()
	var food := int(MapModes.Mode.FOOD)
	assert_null(seg.button_for(food), "no Food in a sandbox")
	assert_eq(Session.new_scenario("north_italy_1480", 1480), "")
	top.refresh_game()
	assert_null(seg.button_for(food), "no Food while picking")
	assert_true(bool(Session.act("choose_country", {"tag": "GEN"})["ok"]))
	await _harness.wait_frames(self, 1)
	var btn := seg.button_for(food)
	assert_not_null(btn, "Food is the fifth segment once you play")
	assert_eq(btn.text, "Food")
	assert_true(btn.tooltip_text.contains("[5]"), "its tooltip names key 5")
	assert_eq(TopBar.MODE_LABELS.size(), 6, "six mode segments: Supply is the sixth (M6)")
	assert_eq(TopBar.MODE_KEYS.size(), 6)
	var supply := seg.button_for(int(MapModes.Mode.SUPPLY))
	assert_not_null(supply, "Supply is the sixth segment once you play")
	assert_eq(supply.text, "Supply")
	assert_true(supply.tooltip_text.contains("[6]"), "its tooltip names key 6")
	var chosen: Array[int] = []
	_hud.mode_requested.connect(func(mode: int) -> void: chosen.append(mode))
	seg.select(food, true)
	assert_eq(chosen, [4], "the fifth segment reaches the Hud as mode 4")
	seg.select(int(MapModes.Mode.SUPPLY), true)
	assert_eq(chosen, [4, 5], "the sixth segment reaches the Hud as mode 5 (Supply)")
	top.set_mode(food)
	assert_true(btn.button_pressed, "Food is shown selected, not Yields")
	assert_false(seg.button_for(int(MapModes.Mode.YIELDS)).button_pressed)
	top.set_mode(int(MapModes.Mode.SUPPLY))
	assert_true(supply.button_pressed, "Supply is shown selected when set")
