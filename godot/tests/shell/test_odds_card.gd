## The odds card (docs/architecture/m7-build-spec.md 6.4; M7 B26): the hover card of a war target of the selected army, in place of the
## move card. Its words are OddsView's and MovePreview's, laid out as they are (the card text equals card_of of them). Fog: a hex the
## player has not discovered gives no odds card (the move card's words, with no numbers); an enemy army out of sight is never
## numbered. A shaken army's refusal gives its two sentences in
## BAD. This season's walk and its risks stand above the arrival in the preview's tones (moves-build-spec.md R47). The card takes
## no mouse and no focus. Planted faults: an odds card that shows an unseen enemy's numbers; a card that drops the walk or a risk,
## or says a line twice; a card that steals the focus; a card that wraps past its width or is taller than a 1280x720 window.
extends GutTest

var _game: Game = null
var _scene: MapScene = null
var _hover: MapHover = null


func before_each() -> void:
	_game = ArmyFixture.game()
	Session.start_game(_game)
	_scene = (load("res://shell/map/map_scene.tscn") as PackedScene).instantiate() as MapScene
	_scene.preload_next_season = false
	add_child_autofree(_scene)
	_scene.finish_loading()
	_hover = MapHover.new()
	add_child_autofree(_hover)


func after_each() -> void:
	Session.end_game()
	await get_tree().process_frame


func _armies() -> MapArmies:
	return _scene.get_node("MapArmies") as MapArmies


## A land hex of Genoa beside an enemy's land (the enemy at war with Genoa): {ours, theirs, enemy}; {} when none.
func _contact() -> Dictionary:
	var enemy := WarFixture.neighbour_of(_game, ArmyFixture.TAG)
	WarFixture.at_war(_game, enemy, ArmyFixture.TAG)
	var eid := ArmyFixture.id_of(_game, enemy)
	var mine := ArmyFixture.id_of(_game, ArmyFixture.TAG)
	for i: int in _game.map.hex_count():
		var hex := _game.map.hex_of(i)
		if not _game.map.is_land(hex) or Territory.owner_id(_game, hex) != mine:
			continue
		for d: int in 6:
			var beside := ImproveRules.neighbour(hex, d)
			if _game.map.is_land(beside) and Territory.owner_id(_game, beside) == eid:
				return {"ours": hex, "theirs": beside, "enemy": enemy}
	return {}


## The first hex of an enemy at war with Genoa that Genoa has not discovered and holds no army on; NO_HEX when none.
func _unseen_enemy_hex(enemy: StringName) -> Vector2i:
	var eid := ArmyFixture.id_of(_game, enemy)
	for i: int in _game.map.hex_count():
		var hex := _game.map.hex_of(i)
		if _game.map.is_land(hex) and int(_game.state.owner[i]) == eid and not Knowledge.discovered(_game, ArmyFixture.TAG, hex) \
				and Armies.at(_game, hex).is_empty():
			return hex
	return ArmyFixture.NO_HEX


## Our army beside the contact and the enemy army on the far hex; selects ours on the map. Returns {army (id), c (contact)}.
func _fight_set_up() -> Dictionary:
	var c := _contact()
	assert_false(c.is_empty(), "Genoa borders an enemy on the 1480 map")
	var mine := ArmyFixture.army(_game, ArmyFixture.TAG, c.ours, 0, 2)
	ArmyFixture.army(_game, c.enemy, c.theirs, 0, 1)
	_game.version += 1
	_armies().sync()
	assert_true(_armies().select_army(mine.id))
	return {"army": mine.id, "c": c}


func _texts(lines: Array) -> Array[String]:
	var out: Array[String] = []
	for line: Variant in lines:
		out.append(str((line as Array)[0]))
	return out


func _card_texts() -> Array[String]:
	var out: Array[String] = []
	for text: String in _hover.odds_card().line_texts():
		out.append(text)
	return out


func test_hovering_an_enemy_with_an_army_selected_shows_the_odds_card() -> void:
	var set_up := _fight_set_up()
	_hover.on_hover_changed(set_up.c.theirs, Vector2(200, 200))
	assert_true(_hover.odds_card().is_open(), "the odds card shows over an enemy hex")
	assert_false(_hover.move_card().is_open(), "and the move card does not")


func test_the_card_text_is_the_odds_view_words() -> void:
	var set_up := _fight_set_up()
	var hex: Vector2i = set_up.c.theirs
	_hover.on_hover_changed(hex, Vector2(200, 200))
	var preview := MovePreview.to(_game, ArmyFixture.TAG, set_up.army, hex)
	var odds := OddsView.of(_game, ArmyFixture.TAG, set_up.army, hex)
	var card := OddsCard.card_of(preview, odds)
	assert_eq(_hover.odds_card().title_text(), str(card.title), "the title is the place")
	assert_eq(_card_texts(), _texts(card.lines), "the lines are the card's words, in order")
	assert_eq(_hover.odds_card().way_text(), str(card.way_out), "and the way out is the hint")
	assert_eq(str(odds.kind), "attack", "an enemy army is an attack")
	assert_eq(str(card.lines[0][0]), str(odds.kind_text), "the first line is the kind and the word")
	assert_true(str(odds.kind_text).begins_with("Attack · "), "the word follows the kind")


func test_the_odds_word_is_in_its_tone() -> void:
	var set_up := _fight_set_up()
	var hex: Vector2i = set_up.c.theirs
	_hover.on_hover_changed(hex, Vector2(200, 200))
	var odds := OddsView.of(_game, ArmyFixture.TAG, set_up.army, hex)
	var first := _hover.odds_card().get_node("VBox/Rows").get_child(0) as Label
	var want: String = {"good": "NumberGood", "bad": "NumberBad"}.get(str(odds.tone), "Label")
	assert_eq(str(first.theme_type_variation), want, "the kind line takes the odds tone")
	assert_eq(str(first.get_meta(&"words", "")), str(odds.kind_text))


func test_unseen_enemy_hex_shows_no_odds_card() -> void:
	var set_up := _fight_set_up()
	FogFixture.thin(_game, ArmyFixture.TAG, 0)
	var hex := _unseen_enemy_hex(set_up.c.enemy)
	if hex == ArmyFixture.NO_HEX:
		pending("no unseen enemy hex on this map")
		return
	_hover.on_hover_changed(hex, Vector2(200, 200))
	assert_false(_hover.odds_card().is_open(), "an unseen hex gives no odds card")
	for text: String in _card_texts():
		assert_false(text.contains("morale"), "and no numbers of its army: %s" % text)


func test_shaken_army_gets_its_refusal_in_the_odds_card() -> void:
	var set_up := _fight_set_up()
	var army := Armies.by_id(_game, set_up.army)
	for u: Unit in army.units:
		u.morale = 200
	_game.version += 1
	var hex: Vector2i = set_up.c.theirs
	_hover.on_hover_changed(hex, Vector2(200, 200))
	assert_true(_hover.odds_card().is_open(), "a shaken army's refusal is an odds card")
	var texts: Array[String] = _card_texts()
	var last: String = texts.back()
	assert_true(last.begins_with("Too shaken to attack: morale"), "the refusal's first sentence: %s" % last)
	assert_true(last.contains("needed"), "and its way out: the morale needed")


func test_refusals_that_name_no_war_stay_the_move_card() -> void:
	var odds := {"kind": "attack", "ok": false, "reason": "Not your land."}
	assert_false(OddsCard.wants({"verdict": {"ok": false, "reason": "x"}}, odds), "a refusal that is not a shaken army")
	assert_false(OddsCard.wants({"verdict": {"ok": true}}, {"kind": "none"}), "no war target, no odds card")
	assert_false(OddsCard.wants({"verdict": {"ok": true}}, {}), "an empty odds is none")
	assert_true(OddsCard.wants({"verdict": {"ok": true}}, {"kind": "walk_in"}), "a walk in is a war target")


func test_card_of_siege_lines_and_way_out() -> void:
	var odds := {"kind": "siege", "ok": true, "title": "Pavia (10, 9)", "kind_text": "Besiege · falls in about 4 seasons",
		"tone": "plain", "attack": {"men": 2000, "morale": 1000}, "defence": {"access": "hidden"},
		"chips": [{"text": "Uphill −5 % for you"}], "notes": ["Garrison starves after 3 seasons"],
		"hint": "", "reason": ""}
	var card := OddsCard.card_of({"title": "x", "verdict": {"ok": true}}, odds)
	assert_eq(card.title, "Pavia (10, 9)")
	assert_eq(_texts(card.lines), ["Besiege · falls in about 4 seasons", "You 2,000 men · morale 100 %",
		"Uphill −5 % for you", "Garrison starves after 3 seasons"], "the siege's lines in order")
	odds["ok"] = false
	odds["reason"] = "Not at war with it."
	var refused := OddsCard.card_of({"verdict": {"ok": false}}, odds)
	assert_eq((refused.lines as Array).back(), ["Not at war with it.", "bad"], "a refusal is its reason in BAD")
	assert_eq(refused.way_out, "", "with no way out line")


## The theme variation of the odds card's line with this text, &"" when there is none.
func _variation_of(text: String) -> StringName:
	for node: Node in _hover.odds_card().find_children("*", "Label", true, false):
		if str((node as Label).get_meta(MoveCard.RAW, "")) == text:
			return (node as Label).theme_type_variation
	return &""


func test_the_card_shows_this_seasons_walk_and_its_risks() -> void:
	var set_up := _fight_set_up()
	var hex: Vector2i = set_up.c.theirs
	_hover.on_hover_changed(hex, Vector2(200, 200))
	var preview := MovePreview.to(_game, ArmyFixture.TAG, set_up.army, hex)
	var texts: Array[String] = _card_texts()
	var walk := "Walks 1 hex now: "
	var battle := "This opens a battle at %s." % Words.place(_game, hex)
	var at := -1
	for i: int in texts.size():
		if texts[i].begins_with(walk):
			at = i
	assert_gt(at, 0, "this season's walk, after the odds: %s" % str(texts))
	assert_gt(texts.find(battle), at, "then the risk of a battle: %s" % str(texts))
	assert_gt(texts.find(str(preview.arrives_text)), texts.find(battle), "then the arrival: %s" % str(texts))
	assert_eq(_variation_of(battle), &"NumberWarn", "a risk is in the warning tone")
	if at >= 0:
		assert_true(texts[at].ends_with("its season is over."), texts[at])
		assert_eq(_variation_of(texts[at]), &"Label", "the walk is plain")
	for risk: Dictionary in preview.risks as Array:
		assert_eq(texts.count(str(risk.text)), 1, "each risk once: %s" % str(risk.text))
	assert_false(texts.has(str((preview.war as Dictionary).text)), "the move card's war line stays out: the odds say it")


func test_card_of_puts_the_walk_and_risks_before_the_arrival_in_their_tones() -> void:
	var walk := ["Walks 1 hex now: 4 of 12 move points; its season is over.", MovePreview.TONE_PLAIN]
	var risk := ["This opens a battle at Pavia (10, 9).", MovePreview.TONE_WARN]
	var preview := {"verdict": {"ok": true}, "leg_lines": [walk, risk], "arrives_text": "There in Spring 1481 (1 season)",
		"lines": [["Attacks the Duchy of Milan: odds Even.", &"plain"], walk, risk, ["In supply.", &"good"]]}
	var odds := {"kind": "attack", "ok": true, "title": "Pavia (10, 9)", "kind_text": "Attack · Even", "tone": "plain",
		"attack": {"men": 2000, "morale": 1000}, "defence": {"access": "hidden"}, "chips": [], "notes": [], "hint": "",
		"reason": ""}
	var card := OddsCard.card_of(preview, odds)
	assert_eq(_texts(card.lines), ["Attack · Even", "You 2,000 men · morale 100 %", "They: unknown", str(walk[0]),
		str(risk[0]), "There in Spring 1481 (1 season)"], "the odds, the walk, the risk, the arrival: no war or supply line")
	assert_eq((card.lines as Array)[3], walk, "the preview's tone")
	assert_eq((card.lines as Array)[4], risk, "the preview's tone")
	odds["ok"] = false
	odds["reason"] = "Too shaken to attack."
	assert_eq(_texts(OddsCard.card_of(preview, odds).lines), ["Attack · Even", "Too shaken to attack."],
		"a refusal walks nowhere")


## A full attack card: every odds row, the longest walk and all three kinds of risk stay inside a 1280x720 window.
func test_a_full_card_fits_a_1280_by_720_window() -> void:
	var preview := {"verdict": {"ok": true}, "arrives_text": "There in Autumn 1481 (3 seasons)", "leg_lines": [
		["Walks 4 hexes now: 11 of 12 move points, 1 left.", &"plain"],
		["Stops at near Alessandria (10, 11) this season; walks on at End turn, there in Autumn 1481.", &"plain"],
		["Enters land held by the Duchy of Milan, a country at war with you.", &"warn"],
		["Enters land held by the Most Serene Republic of Venice, a country at war with you.", &"warn"],
		["Out of supply: the land feeds 1,000 men a season; 200 men lost a season.", &"warn"]]}
	var odds := {"kind": "attack", "ok": true, "title": "near Alessandria (10, 11)", "kind_text": "Attack · Unfavourable",
		"tone": "bad", "attack": {"men": 2000, "morale": 1000},
		"defence": {"access": "seen", "men": 3000, "morale": 1000, "garrison": {"men": 500, "weight_permille": 1500}},
		"chips": [{"text": "Hills +25 % for them"}, {"text": "Uphill −10 % for you"},
			{"text": "Garrison counts ×1.5 behind its walls"}, {"text": "Across a pass −20 % on day 1"},
			{"text": "Across the river −15 % on day 1"}], "notes": [], "hint": "", "reason": ""}
	var window := Rect2(0.0, 0.0, 1280.0, 720.0)
	var card := _hover.odds_card()
	card.show_odds(preview, odds)
	card.place(Vector2(1270.0, 710.0), window)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(card.line_texts().size(), 14, "every line is on the card")
	assert_true(window.encloses(Rect2(card.position, card.size)),
		"inside the window: at %s, %s big" % [card.position, card.size])


func test_the_card_takes_no_focus_and_no_mouse() -> void:
	var set_up := _fight_set_up()
	_hover.on_hover_changed(set_up.c.theirs, Vector2(200, 200))
	var card := _hover.odds_card()
	assert_eq(card.focus_mode, Control.FOCUS_NONE, "the card is never focusable")
	assert_eq(card.mouse_filter, Control.MOUSE_FILTER_IGNORE, "and ignores the mouse")
	assert_false(card.has_focus(), "it does not take the focus")


func test_the_card_fits_its_width_with_its_words_wrapped() -> void:
	var set_up := _fight_set_up()
	_hover.on_hover_changed(set_up.c.theirs, Vector2(200, 200))
	await get_tree().process_frame
	await get_tree().process_frame
	var card := _hover.odds_card()
	assert_lte(card.size.x, OddsCard.CARD_W + 0.5, "the card is no wider than its width")
	for label: Node in card.find_children("*", "Label", true, false):
		var l := label as Label
		if l.visible:
			assert_lte(l.custom_minimum_size.x, OddsCard.WRAP_W + 0.5, "%s wraps at the card's width" % l.text)
