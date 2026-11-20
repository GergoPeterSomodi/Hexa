## GUT tests for the top-bar ResourceChip (docs/architecture/m4-build-spec.md 6.3; ui-style-and-feedback-spec.md
## sections 4.11 and 5): the medal and icon, the name, the value through Words, the DeltaChip, the hover card from a
## dictionary, the accessibility name, the click, and the plate on leather at 1x and 2x.
extends GutTest

const RESOURCE_CHIP_SCENE := preload("res://shell/ui/resource_chip.tscn")

var _harness: UIHarness = null
var _root: Control = null


func before_each() -> void:
	_harness = UIHarness.new()
	_harness.mount(self)
	_root = VBoxContainer.new()
	_root.theme = KitTheme.load_for(1.0)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_harness.viewport.add_child(_root)


func after_each() -> void:
	_root = null
	_harness = null


func _chip() -> ResourceChip:
	var chip := RESOURCE_CHIP_SCENE.instantiate() as ResourceChip
	_root.add_child(chip)
	chip.set_resource(&"ducats", &"ducats", "Ducats")
	return chip


func test_medal_carries_the_icon_and_the_name_shows() -> void:
	var chip := _chip()
	assert_eq(chip.resource_id, &"ducats")
	assert_true(chip.medallion().small, "the chip's medal is the 30 px size")
	assert_eq(chip.medallion().icon_name, &"ducats")
	assert_eq(chip.name_label().text, "Ducats")
	assert_true(chip.name_label().visible)
	assert_eq(chip.medallion().focus_mode, Control.FOCUS_NONE, "the medal takes no focus")
	assert_eq(chip.medallion().mouse_filter, Control.MOUSE_FILTER_IGNORE, "the chip takes the click")


func test_value_is_formatted_through_words_and_the_change_is_a_delta() -> void:
	var chip := _chip()
	chip.set_value(1240, 86, "ducats")
	assert_eq(chip.value_label().text, "1,240", "value through Words.number")
	assert_eq(chip.delta_chip().text(), "+86 ducats")
	chip.set_value(610, -6)
	assert_eq(chip.value_label().text, "610")
	assert_eq(chip.delta_chip().text(), "\u22126")


func test_accessibility_name_reads_name_value_and_change() -> void:
	var chip := _chip()
	chip.set_value(658, 48)
	assert_eq(chip.accessibility_name, "Ducats: 658, up 48")
	chip.set_value(610, 86, "ducats")
	assert_eq(chip.accessibility_name, "Ducats: 610, up 86 ducats")


func test_name_and_change_can_be_narrowed_but_the_value_stays() -> void:
	var chip := _chip()
	chip.set_value(610, 86)
	chip.set_name_shown(false)
	assert_false(chip.name_label().visible, "the name hides first when narrowing")
	assert_true(chip.value_label().visible, "the value never hides")
	assert_true(chip.medallion().visible, "the medal never hides")
	chip.set_change_shown(false)
	assert_false(chip.delta_chip().visible, "the change hides after the name")
	chip.set_name_shown(true)
	chip.set_change_shown(true)
	assert_true(chip.name_label().visible)
	assert_true(chip.delta_chip().visible)


func test_invert_flips_the_tone_of_a_rise() -> void:
	var chip := _chip()
	chip.set_value(10, 5)
	assert_eq(chip.delta_chip().label_node().theme_type_variation, &"NumberGood")
	chip.invert = true
	assert_eq(chip.delta_chip().label_node().theme_type_variation, &"NumberBad", "a rise is bad when inverted")


func test_hover_card_comes_from_the_dictionary() -> void:
	var chip := _chip()
	assert_eq(chip._get_tooltip(Vector2.ZERO), "", "no card, no tooltip")
	assert_null(chip._make_custom_tooltip("card"), "no card, no hover card")

	chip.set_card({
		"title": "Ducats",
		"subtitle": "",
		"lines": [["Expected this season", &"good", "+95"]],
	})
	assert_eq(chip._get_tooltip(Vector2.ZERO), "card", "a card asks for the hover card")
	var tip := chip._make_custom_tooltip("card")
	assert_true(tip is HoverCard, "returns a HoverCard")
	var card := tip as HoverCard
	assert_eq(card.rows_container().get_child_count(), 1, "one row from the card")
	assert_null(chip._make_custom_tooltip("other"), "only the card key asks for it")
	card.free()


func test_click_on_the_chip_emits_pressed() -> void:
	var chip := _chip()
	chip.set_value(610, 86)
	var clicks := [0]
	chip.pressed.connect(func() -> void: clicks[0] += 1)
	await _harness.wait_frames(self, 2)
	_harness.send_click(chip.value_label().get_global_rect().get_center())
	await _harness.wait_frames(self, 2)
	assert_eq(clicks[0], 1, "a click on the value emits pressed")
	_harness.send_click(chip.medallion().get_global_rect().get_center())
	await _harness.wait_frames(self, 2)
	assert_eq(clicks[0], 2, "a click on the medal emits pressed")


func test_plate_sits_on_leather_at_1x_and_2x() -> void:
	for scale: float in [1.0, 2.0]:
		_root.theme = KitTheme.load_for(scale)
		var chip := _chip()
		chip.set_value(610, 86)
		await _harness.wait_frames(self, 2)
		var plate := chip.get_node("Plate") as PanelContainer
		assert_eq(plate.theme_type_variation, &"PanelSlot", "the plate is the PanelSlot at %s" % scale)
		assert_true(_root.theme.has_stylebox(&"panel", &"PanelSlot"), "the theme has the slot plate at %s" % scale)
		assert_not_null(chip.medallion().ring_node(), "medal rim at %s" % scale)
		assert_not_null(chip.delta_chip().icon_node().texture, "the change icon exists at %s" % scale)
		assert_lte(chip.get_combined_minimum_size().y, float(Tokens.BAR_H), "fits the top bar at %s" % scale)
		chip.free()
