## GUT tests for PreviewCard over the spec 4.15 (c), (d), (e) samples (tests/fixtures/preview_sample.gd): the accepted
## card, the refusal for money (the whole card with its bar), the rule refusal (only the refusal), the two gain
## measures, the one-scale comparison and the keys (ui-style-and-feedback-spec.md sections 5, 6.5 and 7.1).
extends GutTest

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


func _card() -> PreviewCard:
	var card := PREVIEW_CARD_SCENE.instantiate() as PreviewCard
	_root.add_child(card)
	return card


func _caption(card: PreviewCard) -> HBoxContainer:
	return card.get_node("VBox/BodyScroll/Content/Body/Cols/ChartBox/Caption") as HBoxContainer


func _strip_gain(card: PreviewCard, index: int) -> DeltaChip:
	return card.season_strip().cell(index).get_node("VBox/Gain") as DeltaChip


func test_accepted_vineyard_fills_every_part_of_spec_6_5() -> void:
	var card := _card()
	card.show_preview(PreviewSample.vineyard())

	assert_eq(card.accessibility_name, "Vineyard, first stage")
	assert_eq(card.title_label().text, "Vineyard, first stage")
	assert_true(card.sub_label().visible)
	assert_eq(card.brings_container().get_child_count(), 4, "four brings lines")
	assert_false(card.refusal_panel().visible, "no refusal bar")
	assert_false(card.begin_button().disabled, "Begin is enabled")
	assert_true(card.season_strip().visible, "seasons differ, so the strip shows")
	assert_eq(card.season_strip().now_index(), 0, "Spring is now")
	assert_eq(card.season_strip().cell(0).theme_type_variation, &"PanelStripCellNow")
	assert_eq(card.cost_label().text, "40 ducats · 4 seasons · ready Spring 1481 · first vintage Autumn 1481")
	assert_eq(card.requirements_container().get_child_count(), 3)
	assert_eq(card.payback_label().text, "Pays back in Autumn 1482, 10 seasons from now (at today's prices).")
	assert_eq(card.next_label().text,
		"Stage 2 possible (Savona (6, 13) 1 hex away). Stage 3 possible (a town within two hexes, under 1,200 m).")

	var caption := _caption(card)
	assert_true(caption.visible)
	assert_eq((caption.get_child(0) as Label).text, "A year 511 → 533")
	assert_eq((caption.get_child(1) as DeltaChip).text(), "+22", "realm gain a year by default")

	var chart := card.chart()
	assert_eq(chart.kind, InkChart.Kind.PAIRED_BARS)
	assert_false(chart.summary().is_empty(), "the chart has a text summary")


func test_each_season_cell_matches_spec_4_15_c() -> void:
	var card := _card()
	card.show_preview(PreviewSample.vineyard())
	var strip := card.season_strip()
	assert_eq((strip.cell(0).get_node("VBox/Head") as Label).text, "Spring")
	assert_eq(_strip_gain(card, 0).text(), "−2", "Spring gain -2 (down, bad)")
	assert_eq(_strip_gain(card, 2).text(), "+28", "Autumn gain +28")
	var winter_lines := strip.cell(3).get_node("VBox/Lines") as VBoxContainer
	assert_eq((winter_lines.get_child(0) as Label).text, "frost: nothing grows", "winter's note")


func test_treasury_only_switch_changes_the_gains_and_payback() -> void:
	var card := _card()
	var treas: Array[bool] = []
	card.treasury_only_toggled.connect(func(on: bool) -> void: treas.append(on))
	card.show_preview(PreviewSample.vineyard())
	assert_eq(_strip_gain(card, 2).text(), "+28")

	card.treasury_only_switch().set_pressed(true)
	assert_eq(treas, [true], "switch emits treasury_only_toggled")
	assert_true(card.treasury_only)
	card.show_preview(PreviewSample.vineyard())
	assert_eq(_strip_gain(card, 2).text(), "+14", "treasury measure in the strip")
	assert_eq(_strip_gain(card, 0).text(), "−1")
	assert_eq((_caption(card).get_child(1) as DeltaChip).text(), "+10", "treasury year gain")
	assert_eq(card.payback_label().text, "Autumn 1484, 18 seasons from now.", "treasury payback line")


func test_money_refusal_keeps_the_whole_card_with_its_bar() -> void:
	var card := _card()
	card.show_preview(PreviewSample.genoa_city_refused())
	assert_true(card.refusal_panel().visible, "refusal bar shows")
	assert_eq(card.refusal_label().text, "Not enough ducats: 1,000 needed, 610 in the treasury.")
	assert_true(card.begin_button().disabled, "Begin is off")
	assert_true(card.body_visible(), "the card still shows everything")
	assert_eq(card.brings_container().get_child_count(), 6, "every brings line stays")
	assert_true(card.season_strip().visible)
	assert_eq(card.payback_label().text, "Pays back in Winter 1500, 83 seasons from now (at today's prices).")


func test_rule_refusal_shows_only_the_refusal() -> void:
	var card := _card()
	card.show_preview(PreviewSample.savona_walls_refused())
	assert_true(card.refusal_panel().visible)
	assert_eq(card.refusal_label().text,
		"Cuneo (5, 13) is a town beside Savona: two towns may not stand side by side.",
		"the reason in words, not the rule's text")
	assert_false(card.body_visible(), "no body for a rule refusal")
	assert_false(card.foot_visible(), "no Begin or Pin for a rule refusal")
	assert_true(card.begin_button().disabled)


func test_planted_fault_same_money_refusal_as_rule_hides_the_body() -> void:
	# P: if a money refusal were tagged "rule", the card would hide its figures; this case makes sure it does not.
	var card := _card()
	var sample := PreviewSample.genoa_city_refused()
	sample["blocked_by"] = &"rule"
	card.show_preview(sample)
	assert_false(card.body_visible(), "a rule-tagged refusal hides the body (the check that would catch a mis-tag)")


func test_compare_uses_one_chart_scale_for_both_columns() -> void:
	var card := _card()
	var a := PreviewSample.vineyard()
	var b := PreviewSample.vineyard()
	b["title"] = "Olive grove, third stage"
	var autumn: Dictionary = (b["by_season"] as Array)[2]
	autumn["after_realm"] = 400
	autumn["gain_realm"] = 260
	card.show_compare(a, b)

	assert_true(card.compare_container().visible)
	assert_false(card.body_visible(), "compare hides the single body")
	var charts: Array[InkChart] = []
	for col_name: String in ["ColA", "ColB"]:
		for child: Node in (card.compare_container().get_node(col_name) as Control).get_children():
			if child is InkChart:
				charts.append(child as InkChart)
	assert_eq(charts.size(), 2, "one chart per column")
	assert_eq(charts[0].y_ticks, charts[1].y_ticks, "both charts take the same y ticks")
	assert_true(charts[0].y_ticks.has(400), "the scale covers the larger option")
	assert_eq(charts[0].y_ticks[0], 0, "bars start from the zero line, shared by both")


func test_compare_refused_column_names_the_reason() -> void:
	var card := _card()
	card.show_compare(PreviewSample.vineyard(), PreviewSample.savona_walls_refused())
	var col_b := card.compare_container().get_node("ColB") as VBoxContainer
	var reason_found := false
	for child: Node in col_b.get_children():
		if child is Label and (child as Label).text.begins_with("Cuneo (5, 13)"):
			reason_found = true
	assert_true(reason_found, "a refused column shows its reason in words")


func test_escape_closes_and_pin_syncs_with_both_controls() -> void:
	var card := _card()
	card.show_preview(PreviewSample.vineyard())
	var closed_n := [0]
	var pins: Array[bool] = []
	card.closed.connect(func() -> void: closed_n[0] += 1)
	card.pin_toggled.connect(func(on: bool) -> void: pins.append(on))

	card.pin_button().set_pressed(true)
	assert_eq(pins, [true], "toggling Pin to compare emits pin_toggled once")
	assert_true(card.pin_button().button_pressed)
	assert_null(card.get_node_or_null("VBox/Top/PinCheck"), "no second pin control")

	await _harness.wait_frames(self, 2)
	_harness.send_key(KEY_ESCAPE)
	await _harness.wait_frames(self, 2)
	assert_eq(closed_n[0], 1, "Esc closes")


func test_begin_and_look_at_signals() -> void:
	var card := _card()
	card.show_preview(PreviewSample.vineyard())
	var began := [0]
	var looks: Array[Vector2i] = []
	card.begin_pressed.connect(func() -> void: began[0] += 1)
	card.look_at_requested.connect(func(h: Vector2i) -> void: looks.append(h))
	card.begin_button().pressed.emit()
	assert_eq(began[0], 1)
	card.look_at_requested.emit(Vector2i(7, 12))
	assert_eq(looks, [Vector2i(7, 12)])


func test_brings_row_has_label_left_value_and_chip() -> void:
	var card := _card()
	card.show_preview(PreviewSample.vineyard())
	var row := card.brings_container().get_child(0) as HBoxContainer
	assert_eq(row.get_child_count(), 3, "label, value, chip")
	assert_eq((row.get_child(0) as Label).text, "Wine, a year")
	assert_eq((row.get_child(1) as Label).text, "0 → 12")
	assert_eq((row.get_child(2) as DeltaChip).text(), "+12")
	var upkeep := card.brings_container().get_child(3) as HBoxContainer
	assert_true((upkeep.get_child(2) as DeltaChip).invert, "upkeep is a cost")


func test_upkeep_is_the_years_change_shown_as_a_cost() -> void:
	var card := _card()
	card.show_preview(PreviewSample.vineyard())
	var found := false
	for row: Node in card.lands_container().get_children():
		var lbl := row.get_child(0) as Label
		if lbl != null and lbl.text == "Upkeep":
			found = true
			var chip := row.get_child(1) as DeltaChip
			assert_eq(chip.text(), "+4", "an increase reads with a plus sign")
			assert_true(chip.invert, "and is a cost (bad colour)")
	assert_true(found, "an Upkeep row shows")


func test_real_vineyard_preview_draws_in_the_card() -> void:
	var g := EconomyFixture.game(&"GEN", true)
	var real := ImprovePreview.of(g, &"GEN", Vector2i(7, 12), {"action": Works.BUILD, "family": ImproveRules.VINEYARD})
	var card := _card()
	card.show_preview(real)
	assert_eq(card.title_label().text, real["title"])
	assert_false(card.refusal_panel().visible, "accepted: no refusal bar")
	assert_false(card.begin_button().disabled, "Begin is enabled")
	assert_eq(card.brings_container().get_child_count(), (real["brings"] as Array).size())
	assert_eq(card.requirements_container().get_child_count(), (real["requirements"] as Array).size())
	assert_true(card.season_strip().visible, "the four seasons differ")
	assert_eq(card.chart().kind, InkChart.Kind.PAIRED_BARS)
	assert_eq(card.cost_label().text, real["cost"]["text"])
	assert_eq(card.payback_label().text, real["payback"]["text"])
	var year: Dictionary = real["year"]
	assert_eq((_caption(card).get_child(0) as Label).text, "A year %d → %d" % [int(year["before_realm"]), int(year["after_realm"])])
	assert_eq(_strip_gain(card, 2).text(), "+%d" % int((real["by_season"] as Array)[2]["gain_realm"]))
