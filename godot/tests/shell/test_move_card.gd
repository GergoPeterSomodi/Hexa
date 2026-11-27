## The move card (docs/architecture/m6-build-spec.md 6.7; L20, #210): a hover card that shows MovePreview.to's words of a march to
## the hex under the pointer (or at the order cursor) while an army of yours is selected, in place of the hex card. It follows the
## hover, hides with no army, off the map, the army's own hex, a released army; a right click or O orders at once; a refusal
## shows its reason in the card and as the refused toast; the card never takes the mouse or the focus. The lines keep the
## preview's order and tones, this season's walk and its risks after the war line (moves-build-spec.md R47), and a line said
## twice shows once in the stronger tone.
extends GutTest

var _game: Game = null
var _scene: MapScene = null
var _hover: MapHover = null
var _reasons: Array[String] = []


func before_each() -> void:
	_game = ArmyFixture.game()
	Session.start_game(_game)
	_scene = (load("res://shell/map/map_scene.tscn") as PackedScene).instantiate() as MapScene
	_scene.preload_next_season = false
	add_child_autofree(_scene)
	_scene.finish_loading()
	_hover = MapHover.new()
	add_child_autofree(_hover)
	_reasons.clear()
	_scene.refused.connect(func(reason: String) -> void: _reasons.append(reason))


func after_each() -> void:
	Session.end_game()


func _armies() -> MapArmies:
	return _scene.get_node("MapArmies") as MapArmies


func _card() -> MoveCard:
	return _hover.move_card()


func _army(hex: Vector2i) -> int:
	var a := ArmyFixture.army(_game, ArmyFixture.TAG, hex, 0, 2)
	_game.version += 1
	_armies().sync()
	return a.id


## The first hex within four steps of `origin` (the box) whose MovePreview.to satisfies `want`; NO_HEX when none.
func _goal_where(origin: Vector2i, army_id: int, want: Callable) -> Vector2i:
	for dq: int in range(-4, 5):
		for dr: int in range(-4, 5):
			var h := origin + Vector2i(dq, dr)
			if h == origin or not _game.map.has(h):
				continue
			if bool(want.call(MovePreview.to(_game, ArmyFixture.TAG, army_id, h))):
				return h
	return ArmyFixture.NO_HEX


func _refused(p: Dictionary) -> bool:
	return p["kind"] == &"refusal"


func _long(p: Dictionary) -> bool:
	return bool(p["verdict"]["ok"]) and int(p["seasons"]) > 1


func _plain(p: Dictionary) -> bool:
	return bool(p["verdict"]["ok"]) and p["kind"] == &"go" and int(p["seasons"]) == 1


## An army of the player's, selected, and a goal the predicate asks for (the test fails when there is none).
func _selected_with_goal(want: Callable) -> Array:
	var origin := ArmyFixture.find_town(_game)
	var id := _army(origin)
	assert_true(_armies().select_army(id))
	var goal := _goal_where(origin, id, want)
	assert_ne(goal, ArmyFixture.NO_HEX, "a goal of this kind exists near the army")
	return [id, goal]


## The preview's line texts, each once, in order (a risk that is also the supply line is one line on the card).
func _lines_of(preview: Dictionary) -> Array[String]:
	var texts: Array[String] = []
	for line: Variant in preview["lines"] as Array:
		var text := str((line as Array)[0])
		if not texts.has(text):
			texts.append(text)
	return texts


## The theme variation of the card's line with this text, &"" when there is none.
func _variation_of(card: MoveCard, text: String) -> StringName:
	for node: Node in card.find_children("*", "Label", true, false):
		if str((node as Label).get_meta(MoveCard.RAW, "")) == text:
			return (node as Label).theme_type_variation
	return &""


func test_no_army_means_no_move_card() -> void:
	var origin := ArmyFixture.find_town(_game)
	_hover.on_hover_changed(origin + Vector2i(1, 0), Vector2(200, 200))
	assert_false(_card().is_open(), "with no army selected the hover card is the hex card")


func test_hovering_another_hex_with_an_army_selected_shows_the_preview_words() -> void:
	var picked := _selected_with_goal(_long)
	_hover.on_hover_changed(picked[1], Vector2(200, 200))
	assert_true(_card().is_open(), "the card shows over another hex")
	var preview := MovePreview.to(_game, ArmyFixture.TAG, picked[0], picked[1])
	assert_eq(_card().title_text(), str(preview["title"]), "the title is the place")
	assert_eq(_card().line_texts(), _lines_of(preview), "the lines are the preview's, in order")
	assert_eq(_card().way_text(), str(preview["way_out"]), "and the way out")
	assert_false(_card().has_focus(), "the card takes no focus")


func test_the_card_follows_the_hover_and_hides_off_the_map_and_on_the_army_hex() -> void:
	var picked := _selected_with_goal(_long)
	var other := _goal_where(picked[1], picked[0], _plain)
	_hover.on_hover_changed(picked[1], Vector2(200, 200))
	assert_true(_card().is_open())
	if other != ArmyFixture.NO_HEX:
		_hover.on_hover_changed(other, Vector2(220, 220))
		assert_eq(_card().title_text(), str(MovePreview.to(_game, ArmyFixture.TAG, picked[0], other)["title"]), "it moves to the new hex")
	_hover.on_hover_changed(MapInput.NO_HEX)
	assert_false(_card().is_open(), "off the map the card hides")
	_hover.on_hover_changed(picked[1], Vector2(200, 200))
	var own := ArmyView.panel(_game, ArmyFixture.TAG, picked[0])["hex"] as Vector2i
	_hover.on_hover_changed(own, Vector2(200, 200))
	assert_false(_card().is_open(), "the army's own hex keeps the hex card")


func test_a_released_army_hides_the_card() -> void:
	var picked := _selected_with_goal(_long)
	_hover.on_hover_changed(picked[1], Vector2(200, 200))
	assert_true(_card().is_open())
	_armies().clear_army()
	assert_false(_card().is_open(), "clearing the army hides it")
	_armies().select_army(picked[0])
	_hover.on_hover_changed(picked[1], Vector2(200, 200))
	assert_true(_card().is_open(), "selecting again shows it again")


func test_the_order_cursor_moves_the_card_and_the_pointer_takes_it_back() -> void:
	var origin := ArmyFixture.find_town(_game)
	var id := _army(origin)
	assert_true(_armies().select_army(id))
	_hover.on_hover_changed(MapInput.NO_HEX)
	var step := -1
	for dir: int in [MapInput.CURSOR_RIGHT, MapInput.CURSOR_LEFT, MapInput.CURSOR_UP, MapInput.CURSOR_DOWN]:
		var hex := MapInput.cursor_step(origin, dir)
		if _game.map.has(hex) and _plain(MovePreview.to(_game, ArmyFixture.TAG, id, hex)):
			step = dir
			break
	assert_ne(step, -1, "a neighbour the army marches to in a season")
	_armies().move_cursor(step)
	var cursor := _armies().cursor_hex()
	assert_true(_card().is_open(), "the keyboard cursor brings the card")
	assert_eq(_card().title_text(), str(MovePreview.to(_game, ArmyFixture.TAG, id, cursor)["title"]), "for the cursor's hex")
	_hover.on_hover_changed(origin, Vector2(10, 10))
	assert_false(_card().is_open(), "the pointer over the army's own hex: the hex card, not the move card")


func test_a_plain_right_click_orders_at_once_and_a_multi_season_one_too() -> void:
	var picked := _selected_with_goal(_long)
	var before := Session.unsaved_actions
	_armies().command(picked[1])
	assert_eq(Session.unsaved_actions, before + 1, "a long march is ordered at once, the card is only a hover")
	var order := ArmyView.panel(_game, ArmyFixture.TAG, picked[0])["order"] as Dictionary
	assert_eq(order["goal"], picked[1], "to the clicked hex")


func test_a_refused_order_shows_the_reason_in_the_card_and_as_the_toast() -> void:
	var picked := _selected_with_goal(_refused)
	var preview := MovePreview.to(_game, ArmyFixture.TAG, picked[0], picked[1])
	var reason := str(preview["verdict"]["reason"])
	_hover.on_hover_changed(picked[1], Vector2(200, 200))
	assert_true(_card().line_texts().has(reason), "the card shows the reason")
	var before := Session.unsaved_actions
	_armies().command(picked[1])
	assert_eq(Session.unsaved_actions, before, "a refusal orders nothing")
	assert_eq(_reasons.back(), reason, "and the refused toast says the same words")


func test_keyboard_o_orders_at_the_cursor_and_the_card_never_takes_focus() -> void:
	var origin := ArmyFixture.find_town(_game)
	var id := _army(origin)
	assert_true(_armies().select_army(id))
	var step := -1
	for dir: int in [MapInput.CURSOR_RIGHT, MapInput.CURSOR_LEFT, MapInput.CURSOR_UP, MapInput.CURSOR_DOWN]:
		var hex := MapInput.cursor_step(origin, dir)
		if _game.map.has(hex) and _plain(MovePreview.to(_game, ArmyFixture.TAG, id, hex)):
			step = dir
			break
	assert_ne(step, -1)
	_armies().move_cursor(step)
	var cursor := _armies().cursor_hex()
	# moves in the month: a march one step away is walked in the act and its goal cleared on arrival; the army has spent its
	# points, so the order stands and the test still reads the goal O ordered
	Armies.set_points(_game, Armies.by_id(_game, id), 0)
	var before := Session.unsaved_actions
	_armies()._on_command_key()
	assert_eq(Session.unsaved_actions, before + 1, "O orders the march at the cursor")
	var order := ArmyView.panel(_game, ArmyFixture.TAG, id)["order"] as Dictionary
	assert_eq(order["goal"], cursor)
	assert_false(_card().has_focus())
	assert_eq(_card().focus_mode, Control.FOCUS_NONE, "no focus mode")
	assert_eq(_card().mouse_filter, Control.MOUSE_FILTER_IGNORE, "the mouse goes through it")


## moves in the month: this season's walk comes first, before the arrival; a long march says where it stops.
func test_the_walk_of_this_season_leads_the_card() -> void:
	var picked := _selected_with_goal(_long)
	_hover.on_hover_changed(picked[1], Vector2(200, 200))
	var lines := _card().line_texts()
	var leg := MovePreview.leg_of(_game, ArmyFixture.TAG, picked[0], picked[1])
	assert_eq(StringName(leg["why"]), MovePreview.WHY_POINTS)
	assert_gt(lines.size(), 2)
	assert_true(lines[0].begins_with("Walks %d hex" % (leg["hexes"] as Array).size()), "the walk first: %s" % str(lines))
	assert_true(lines[1].begins_with("Stops at %s this season" % Words.place(_game, leg["end"])), "then where it stops")
	assert_true(lines[2].begins_with("There in "), "then the arrival")
	assert_eq(_variation_of(_card(), lines[0]), &"Label")


## The war line, then the walk, then the risks in the warning tone; a risk that is the supply line too shows once, in its
## first place, in the stronger (bad) tone. Planted faults: a risk in the plain tone; a line shown twice.
func test_the_leg_lines_keep_their_order_and_tones_and_a_repeat_shows_once() -> void:
	var card := (load("res://shell/hud/move_card.tscn") as PackedScene).instantiate() as MoveCard
	add_child_autofree(card)
	var hungry := "Out of supply: the land feeds no one; 100 men lost a season."
	card.show_move({"title": "x", "way_out": "", "lines": [
		["Takes it at the end of the season.", &"plain"],
		["Walks 1 hex now: 9 of 12 move points, 3 left.", &"plain"],
		["Enters land held by the Duchy of Milan, a country at war with you.", &"warn"],
		[hungry, &"warn"],
		["There in Spring 1480 (1 season)", &"plain"],
		[hungry, &"bad"]]})
	assert_eq(card.line_texts(), ["Takes it at the end of the season.", "Walks 1 hex now: 9 of 12 move points, 3 left.",
		"Enters land held by the Duchy of Milan, a country at war with you.", hungry, "There in Spring 1480 (1 season)"]
		as Array[String])
	assert_eq(_variation_of(card, "Enters land held by the Duchy of Milan, a country at war with you."), &"NumberWarn")
	assert_eq(_variation_of(card, hungry), &"NumberBad", "the stronger tone")
	assert_eq(MoveCard.distinct_lines([["a", &"bad"], ["a", &"warn"], ["b"]]), [["a", &"bad"]] as Array[Array],
		"the stronger tone whichever comes first; a line with no tone is left out")


## The card's size: a three-line sample is as tall as its words (under 160 px), and the card stays inside the viewport.
func _sample_card() -> MoveCard:
	var card := (load("res://shell/hud/move_card.tscn") as PackedScene).instantiate() as MoveCard
	add_child_autofree(card)
	card.show_move({
		"title": "near Cuneo (6, 14)",
		"verdict": {"ok": true, "reason": ""},
		"lines": [["There in Summer 1480 (2 seasons)", &"plain"],
			["Musters first: marches from Summer 1480.", &"muted"],
			["In supply.", &"good"]],
		"way_out": "",
	})
	return card


func test_the_card_is_as_tall_as_its_three_line_sample_and_no_taller() -> void:
	var card := _sample_card()
	await get_tree().process_frame
	await get_tree().process_frame
	card.place(Vector2(300.0, 200.0), Rect2(0.0, 0.0, 1280.0, 720.0))
	assert_eq(card.size.x, MoveCard.CARD_W, "300 px wide")
	assert_lt(card.size.y, 160.0, "as tall as its words, not the window (%s)" % card.size.y)
	assert_gt(card.size.y, 40.0, "and it does hold its words")


func test_the_card_sits_by_the_anchor_and_stays_inside_the_viewport() -> void:
	var card := _sample_card()
	card.place(Vector2(400.0, 300.0), Rect2(0.0, 0.0, 1280.0, 720.0))
	assert_eq(card.position, Vector2(400.0 + MapHover.CURSOR_OFFSET.x, 300.0 + MapHover.CURSOR_OFFSET.y), "a small offset from the pointer")
	card.place(Vector2(1275.0, 715.0), Rect2(0.0, 0.0, 1280.0, 720.0))
	assert_lte(card.position.x + card.size.x, 1280.0, "clamped inside the right edge")
	assert_lte(card.position.y + card.size.y, 720.0, "clamped inside the bottom edge")
	assert_gte(card.position.x, 0.0)
	assert_gte(card.position.y, 0.0)

