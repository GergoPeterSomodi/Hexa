## GUT tests for Studiolo feedback, medallion, chip, season strip, preview card, and relation
## matrix components: DeltaChip, Medallion, ResourceChip, SeasonStrip, PreviewCard, RelationMatrix
## (docs/architecture/ui-style-and-feedback-spec.md sections 4.11, 5 and 11).
extends GutTest

const RESOURCE_CHIP_SCENE := preload("res://shell/ui/resource_chip.tscn")
const SEASON_STRIP_SCENE := preload("res://shell/ui/season_strip.tscn")
const PREVIEW_CARD_SCENE := preload("res://shell/ui/preview_card.tscn")

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


func test_delta_chip_signs_icons_invert_ink_boxed_and_a11y() -> void:
	var chip := DeltaChip.new()
	_root.add_child(chip)

	chip.set_delta(86, "ducats")
	assert_eq(chip.text(), "+86 ducats")
	assert_eq(chip.icon_name(), &"arrow_up")
	assert_eq(chip.label_node().theme_type_variation, &"NumberGood")
	assert_eq(chip.accessibility_name, "up 86 ducats")
	assert_not_null(chip.icon_node().texture)

	chip.set_delta(-6, "ducats")
	assert_eq(chip.text(), "\u22126 ducats", "uses U+2212 minus sign")
	assert_eq(chip.icon_name(), &"arrow_down")
	assert_eq(chip.label_node().theme_type_variation, &"NumberBad")
	assert_eq(chip.accessibility_name, "down 6 ducats")

	chip.set_delta(0)
	assert_eq(chip.text(), "0")
	assert_eq(chip.icon_name(), &"dash")
	assert_eq(chip.label_node().theme_type_variation, &"Hint")
	assert_eq(chip.accessibility_name, "no change")

	chip.invert = true
	chip.set_delta(4, "", "upkeep")
	assert_eq(chip.text(), "upkeep +4")
	assert_eq(chip.label_node().theme_type_variation, &"NumberBad", "invert marks rise as bad")
	chip.set_delta(-4, "", "upkeep")
	assert_eq(chip.label_node().theme_type_variation, &"NumberGood", "invert marks fall as good")

	chip.invert = false
	chip.ink = true
	chip.set_delta(12)
	assert_eq(chip.label_node().theme_type_variation, &"NumberInkGood")
	chip.set_delta(-3)
	assert_eq(chip.label_node().theme_type_variation, &"NumberInkBad")
	chip.set_delta(0)
	assert_eq(chip.label_node().theme_type_variation, &"LabelInkMuted")

	assert_almost_eq(chip.self_modulate.a, 0.0, 0.001)
	chip.boxed = true
	assert_almost_eq(chip.self_modulate.a, 1.0, 0.001)
	assert_eq(chip.theme_type_variation, &"PanelSlot")


func test_delta_chip_every_state_has_icon_and_sign_on_leather_and_vellum() -> void:
	var theme := _root.theme
	var chip := DeltaChip.new()
	_root.add_child(chip)

	# Style spec 5: every state shows its Kit icon and its sign, on leather (plain) and on vellum (ink).
	var cases: Array[Dictionary] = [
		{"amount": 9, "icon": &"arrow_up", "sign": "+", "leather": &"NumberGood", "vellum": &"NumberInkGood"},
		{"amount": -9, "icon": &"arrow_down", "sign": "−", "leather": &"NumberBad", "vellum": &"NumberInkBad"},
		{"amount": 0, "icon": &"dash", "sign": "0", "leather": &"Hint", "vellum": &"LabelInkMuted"},
	]
	for c: Dictionary in cases:
		for ink_on: bool in [false, true]:
			for boxed_on: bool in [false, true]:
				for inverted: bool in [false, true]:
					chip.ink = ink_on
					chip.boxed = boxed_on
					chip.invert = inverted
					chip.set_delta(c["amount"], "ducats")
					var tag := "amount %d ink %s boxed %s invert %s" % [c["amount"], ink_on, boxed_on, inverted]
					assert_eq(chip.icon_name(), c["icon"], tag)
					assert_not_null(chip.icon_node().texture, "icon present: " + tag)
					assert_eq(chip.icon_node().texture, theme.get_icon(c["icon"], &"Kit"), "Kit icon: " + tag)
					assert_true(chip.text().begins_with(c["sign"]), "sign: " + tag)
					var variation: StringName = c["vellum"] if ink_on else c["leather"]
					if inverted and c["amount"] != 0:
						variation = (&"NumberInkBad" if ink_on else &"NumberBad") if c["amount"] > 0 else (&"NumberInkGood" if ink_on else &"NumberGood")
					assert_eq(chip.label_node().theme_type_variation, variation, "tone: " + tag)
					assert_true(theme.has_color(&"font_color", variation), "variation has a colour: " + tag)
					assert_eq(chip.icon_node().self_modulate, theme.get_color(&"font_color", variation), "icon takes the tone: " + tag)
					assert_almost_eq(chip.self_modulate.a, 1.0 if boxed_on else 0.0, 0.001, "plate: " + tag)

	# The three icons differ, so no state is drawn with the wrong one.
	assert_ne(theme.get_icon(&"arrow_up", &"Kit"), theme.get_icon(&"arrow_down", &"Kit"))
	assert_ne(theme.get_icon(&"arrow_up", &"Kit"), theme.get_icon(&"dash", &"Kit"))
	assert_ne(theme.get_icon(&"arrow_down", &"Kit"), theme.get_icon(&"dash", &"Kit"))


func test_medallion_sizes_dial_and_busy_motion() -> void:
	var medal := Medallion.new()
	_root.add_child(medal)
	assert_eq(medal.theme_type_variation, &"ButtonMedallion")
	assert_eq(medal.custom_minimum_size, Vector2(float(Tokens.MEDAL), float(Tokens.MEDAL)))
	assert_eq(medal.dial, -1)
	assert_false(medal.is_spinning())

	medal.small = true
	assert_eq(medal.custom_minimum_size, Vector2(float(Tokens.MEDAL_SM), float(Tokens.MEDAL_SM)))

	medal.dial = 2
	assert_eq(medal.dial, 2)

	medal.set_busy(true, false)
	assert_true(medal.is_spinning(), "busy without reduce_motion spins ring")
	assert_false((medal.get_node("BusyIndicator") as Control).visible)

	medal.set_busy(true, true)
	assert_false(medal.is_spinning(), "busy with reduce_motion stays still")
	var static_shown: bool = (medal.get_node("BusyIndicator") as Control).visible or (medal.get_node("BusyIcon") as Control).visible
	assert_true(static_shown, "reduce_motion busy shows static indicator")

	medal.set_busy(false)
	assert_false(medal.is_spinning())
	assert_false((medal.get_node("BusyIndicator") as Control).visible)
	assert_false((medal.get_node("BusyIcon") as Control).visible)


func test_resource_chip_sets_values_and_emits_pressed() -> void:
	var chip := RESOURCE_CHIP_SCENE.instantiate() as ResourceChip
	chip.icon_name = &"tick"
	_root.add_child(chip)

	chip.set_value(1240, 86, "ducats", "Treasury")
	assert_eq(chip.name_label().text, "Treasury")
	assert_true(chip.name_label().visible)
	assert_eq(chip.value_label().text, "1,240", "value is formatted through Words")
	assert_eq(chip.delta_chip().text(), "+86 ducats")
	assert_true(chip.medallion().small)

	var clicks := [0]
	chip.pressed.connect(func() -> void: clicks[0] += 1)
	await _harness.wait_frames(self, 2)
	_harness.send_click(chip.medallion().get_global_rect().get_center())
	await _harness.wait_frames(self, 2)
	assert_eq(clicks[0], 1, "clicking chip medallion emits pressed")

	_harness.send_click(chip.value_label().get_global_rect().get_center())
	await _harness.wait_frames(self, 2)
	assert_eq(clicks[0], 2, "clicking chip body emits pressed")


func test_season_strip_marks_now_styles_zero_and_hides_when_equal() -> void:
	var strip := SEASON_STRIP_SCENE.instantiate() as SeasonStrip
	_root.add_child(strip)

	strip.set_seasons([
		{"season": "Spring", "note": "", "goods": [{"name": "wine", "before": 0, "after": 0}], "gain": -2},
		{"season": "Summer", "note": "", "goods": [{"name": "wine", "before": 0, "after": 0}], "gain": -3},
		{"season": "Autumn", "note": "", "goods": [{"name": "wine", "before": 0, "after": 12}], "gain": 28},
		{"season": "Winter", "note": "frost: nothing grows", "goods": [{"name": "wine", "before": 0, "after": 0}], "gain": -1},
	], 2)

	assert_true(strip.visible, "unequal seasons stay visible")
	assert_eq(strip.now_index(), 2)
	assert_eq(strip.cell(0).theme_type_variation, &"PanelStripCell")
	assert_eq(strip.cell(2).theme_type_variation, &"PanelStripCellNow")

	var spring_lines := strip.cell(0).get_node("VBox/Lines") as VBoxContainer
	assert_eq(spring_lines.get_child_count(), 1)
	assert_eq((spring_lines.get_child(0) as Label).theme_type_variation, &"Hint", "zero good row uses Hint")

	var autumn_lines := strip.cell(2).get_node("VBox/Lines") as VBoxContainer
	assert_eq((autumn_lines.get_child(0) as Label).theme_type_variation, &"TableRow")

	var winter_lines := strip.cell(3).get_node("VBox/Lines") as VBoxContainer
	assert_eq((winter_lines.get_child(0) as Label).theme_type_variation, &"Reason")

	# Four equal cells hide the strip
	var equal_cell := {"season": "Season", "note": "", "goods": [{"name": "grain", "before": 4, "after": 6}], "gain": 10}
	strip.set_seasons([
		{"season": "Spring", "note": "", "goods": equal_cell["goods"], "gain": 10},
		{"season": "Summer", "note": "", "goods": equal_cell["goods"], "gain": 10},
		{"season": "Autumn", "note": "", "goods": equal_cell["goods"], "gain": 10},
		{"season": "Winter", "note": "", "goods": equal_cell["goods"], "gain": 10},
	], 0)
	assert_false(strip.visible, "four equal seasons hide the strip")


func test_preview_card_accepted_refused_compare_and_signals() -> void:
	var card := PREVIEW_CARD_SCENE.instantiate() as PreviewCard
	_root.add_child(card)
	assert_eq(card.theme_type_variation, &"PanelCard")
	assert_gte(card.custom_minimum_size.x, 556.0)

	var accepted := {
		"verdict": {"ok": true, "reason": ""},
		"title": "Vineyard, first stage",
		"subtitle": "Hills above Savona (7, 12)",
		"brings": [
			{"field": &"wine", "label": "Wine", "before": 0, "after": 12, "per": &"year"},
			{"field": &"upkeep", "label": "Upkeep", "before": 0, "after": 4, "per": &"year"},
		],
		"by_season": [
			{"season": "Spring", "now": false, "note": "", "goods": [{"name": "wine", "before": 0, "after": 0}], "before": 164, "after": 162, "gain": -2},
			{"season": "Summer", "now": false, "note": "", "goods": [{"name": "wine", "before": 0, "after": 0}], "before": 171, "after": 168, "gain": -3},
			{"season": "Autumn", "now": true, "note": "", "goods": [{"name": "wine", "before": 0, "after": 12}], "before": 205, "after": 233, "gain": 28},
			{"season": "Winter", "now": false, "note": "frost", "goods": [{"name": "wine", "before": 0, "after": 0}], "before": 118, "after": 117, "gain": -1},
		],
		"lands": {
			"district": {"before": 6, "after": 32},
			"upkeep": 4,
			"ring": [{"hex": Vector2i(6, 13), "name": "Savona (6, 13)", "text": "buys wine"}],
			"country": {"before": 658, "after": 680},
		},
		"cost": {"text": "40 ducats · 4 seasons"},
		"requirements": [
			{"text": "farmland or meadow", "ok": true},
			{"text": "no snow winter", "ok": true},
		],
		"payback": {"text": "Pays back in Autumn 1482"},
		"next_stages": [{"level": 2, "ok": true, "text": "Stage 2 possible"}],
	}

	card.show_preview(accepted)
	assert_eq(card.title_label().text, "Vineyard, first stage")
	assert_false(card.refusal_panel().visible)
	assert_false(card.begin_button().disabled)
	assert_eq(card.brings_container().get_child_count(), 2)
	assert_true(card.season_strip().visible)
	assert_eq(card.cost_label().text, "40 ducats · 4 seasons")
	assert_eq(card.requirements_container().get_child_count(), 2)
	assert_eq(card.payback_label().text, "Pays back in Autumn 1482")

	var began := [0]
	var closed_n := [0]
	var pins: Array[bool] = []
	var treas: Array[bool] = []
	var looks: Array[Vector2i] = []
	card.begin_pressed.connect(func() -> void: began[0] += 1)
	card.closed.connect(func() -> void: closed_n[0] += 1)
	card.pin_toggled.connect(func(on: bool) -> void: pins.append(on))
	card.treasury_only_toggled.connect(func(on: bool) -> void: treas.append(on))
	card.look_at_requested.connect(func(h: Vector2i) -> void: looks.append(h))

	await _harness.wait_frames(self, 2)
	_harness.send_click(card.begin_button().get_global_rect().get_center())
	_harness.send_click(card.pin_button().get_global_rect().get_center())
	_harness.send_click(card.treasury_only_switch().get_global_rect().get_center())
	await _harness.wait_frames(self, 2)
	assert_eq(began[0], 1)
	assert_eq(pins, [true])
	assert_true(card.pin_button().button_pressed, "the Foot's Pin to compare is pressed")
	assert_eq(treas, [true])
	assert_true(card.treasury_only, "treasury_only property reflects switch state")
	card.treasury_only = false
	assert_false(card.treasury_only_switch().button_pressed, "setting treasury_only syncs switch")
	assert_eq(treas.size(), 1, "setting treasury_only programmatically does not emit toggled")

	var ring_link := card.lands_container().get_child(2).get_child(0) as KitButton
	_harness.send_click(ring_link.get_global_rect().get_center())
	await _harness.wait_frames(self, 2)
	assert_eq(looks, [Vector2i(6, 13)])

	_harness.send_key(KEY_ESCAPE)
	await _harness.wait_frames(self, 2)
	assert_eq(closed_n[0], 1, "Esc closes visible PreviewCard")

	# Refused preview
	card.show_preview({
		"verdict": {"ok": false, "reason": "pair"},
		"title": "Savona: town to walled town",
		"reason_words": "Cuneo (5, 13) is a town beside Savona.",
	})
	assert_true(card.refusal_panel().visible)
	assert_eq(card.refusal_label().text, "Cuneo (5, 13) is a town beside Savona.")
	assert_true(card.begin_button().disabled)

	# Compare mode
	var opt_b := accepted.duplicate(true)
	opt_b["title"] = "Olive grove"
	opt_b["year"] = {"gain": 40}
	card.show_compare(accepted, opt_b)
	assert_true(card.compare_container().visible)
	assert_eq((card.compare_container().get_node("ColA") as Control).get_child_count() > 0, true)
	assert_eq((card.compare_container().get_node("ColB") as Control).get_child_count() > 0, true)


func test_relation_matrix_words_icons_cursor_and_activation() -> void:
	var mat := RelationMatrix.new()
	_root.add_child(mat)

	assert_eq(RelationMatrix.cell_word_for(&"war"), "War")
	assert_eq(RelationMatrix.cell_word_for(&"ally"), "Ally")
	assert_eq(RelationMatrix.cell_word_for(&"truce"), "Truce")
	assert_eq(RelationMatrix.cell_word_for(&"peace"), "Peace")
	assert_eq(RelationMatrix.cell_word_for(&"self"), "Self")
	assert_ne(RelationMatrix.cell_icon_for(&"war"), RelationMatrix.cell_icon_for(&"ally"))

	mat.set_matrix(
		[&"genoa", &"milan", &"venice"],
		["Genoa", "Milan", "Venice"],
		[
			[{"state": &"self"}, {"state": &"war", "opinion": -80}, {"state": &"ally", "opinion": 65}],
			[{"state": &"war", "opinion": -80}, {"state": &"self"}, {"state": &"truce", "seasons_left": 3, "opinion": -10}],
			[{"state": &"ally", "opinion": 65}, {"state": &"truce", "seasons_left": 3, "opinion": -10}, {"state": &"self"}],
		]
	)

	assert_eq(mat.custom_minimum_size, Vector2(RelationMatrix.HEADER_W + 3.0 * 64.0, RelationMatrix.HEADER_H + 3.0 * 34.0))
	assert_eq(mat.cursor(), Vector2i(0, 0))

	var activated: Array[Array] = []
	mat.cell_activated.connect(func(a: StringName, b: StringName) -> void: activated.append([a, b]))

	await _harness.wait_frames(self, 2)
	mat.grab_focus()
	_harness.send_key(KEY_RIGHT)
	_harness.send_key(KEY_DOWN)
	_harness.send_key(KEY_RIGHT)
	await _harness.wait_frames(self, 2)
	assert_eq(mat.cursor(), Vector2i(2, 1))

	_harness.send_key(KEY_ENTER)
	await _harness.wait_frames(self, 2)
	assert_eq(activated, [[&"milan", &"venice"]], "Enter emits cell_activated(row_tag, col_tag)")

	var tip := mat._make_custom_tooltip("1:2") as HoverCard
	assert_not_null(tip)
	assert_eq(tip.rows_container().get_child_count(), 3, "truce tooltip shows state, seasons left, opinion")
	tip.free()
