## TileBuildings (tile window spec R9, R19, R20; build plan TW5): groups and order, the states from real verdicts, state_of
## for the gate, the hammer iff the verdict is ok (checked against Works' checks over every row of three hexes), gains equal
## the works card, the summary equal to the sum of the built rows, {} on a foreign tile, the sandbox, and the door scan.
extends GutTest

func _game() -> Game:
	return EconomyFixture.game(&"GEN")


## Own land hexes of `tag` (the first `limit` of them, in index order).
func _own_hexes(g: Game, tag: StringName, limit: int) -> Array[Vector2i]:
	var c := Countries.by_tag(g, tag)
	var out: Array[Vector2i] = []
	for i: int in Territory.districts(g, c.id):
		out.append(g.map.hex_of(i))
		if out.size() >= limit:
			break
	return out


func _rows(tile: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for group: Dictionary in tile.get("groups", []):
		for row: Dictionary in group["rows"]:
			out.append(row)
	return out


func _with_built(g: Game, tag: StringName) -> Vector2i:
	for hex: Vector2i in _own_hexes(g, tag, 100000):
		if not Improve.piece_at(g, hex).is_empty():
			return hex
	return Vector2i(-1, -1)


func test_foreign_and_unowned_tiles_are_empty() -> void:
	var g := _game()
	var foreign := Vector2i(-1, -1)
	for c: Country in g.countries:
		if c.tag == &"GEN":
			continue
		var hexes := _own_hexes(g, c.tag, 1)
		if not hexes.is_empty():
			foreign = hexes[0]
			break
	assert_ne(foreign, Vector2i(-1, -1))
	assert_eq(TileBuildings.of(g, &"GEN", foreign), {}, "planted fault: own-only rows for a foreign tile")
	assert_eq(TileBuildings.of(g, &"GEN", foreign, true), {})


func test_groups_come_in_order_and_hold_the_options() -> void:
	var g := _game()
	var hex := _own_hexes(g, &"GEN", 1)[0]
	var tile := TileBuildings.of(g, &"GEN", hex)
	var order: Array[StringName] = [&"settlement", &"land", &"harbour", &"defence"]
	var last := -1
	for group: Dictionary in tile["groups"]:
		var at := order.find(group["id"])
		assert_gt(at, last, "groups in order")
		last = at
		assert_eq(group["slots"], {})
	var rows := _rows(tile)
	var offers := ImprovePreview.options_of(g, &"GEN", hex)
	var built := 0 if Improve.piece_at(g, hex).is_empty() else 1
	assert_eq(rows.size(), offers.size() + built)


func test_every_row_has_its_fields_and_a_known_state() -> void:
	var g := _game()
	for hex: Vector2i in _own_hexes(g, &"GEN", 6):
		for row: Dictionary in _rows(TileBuildings.of(g, &"GEN", hex, true)):
			for key: String in ["id", "group", "name", "icon", "option", "state", "state_text", "tone", "progress", "gain",
					"upkeep", "cost", "build_seasons", "payback", "hammer", "reason", "gate"]:
				assert_true(row.has(key), "field %s" % key)
			assert_true(TileBuildings.STATES.has(row["state"]))


func test_hammer_is_the_works_verdict_on_three_hexes() -> void:
	var g := _game()
	var seen := 0
	for hex: Vector2i in _own_hexes(g, &"GEN", 3):
		for row: Dictionary in _rows(TileBuildings.of(g, &"GEN", hex)):
			var option: Dictionary = row["option"]
			if option.is_empty():
				assert_false(row["hammer"], "a built or working row has no hammer")
				continue
			seen += 1
			var args := {"hex": hex, "tag": &"GEN"}
			var action := StringName(str(option["action"]))
			var check: Dictionary
			if action == Works.BUILD:
				args["family"] = int(option["family"])
				check = Works.build_check(g, args)
			elif action == Works.UPGRADE:
				check = Works.upgrade_check(g, args)
			else:
				check = Works.clear_check(g, args)
			assert_eq(bool(row["hammer"]), bool(check["ok"]), "hammer iff ok (planted fault)")
			assert_eq(row["state"] == &"ready", bool(check["ok"]))
	assert_gt(seen, 0)


func test_short_when_the_treasury_is_below_the_cost() -> void:
	var g := _game()
	var c := Countries.by_tag(g, &"GEN")
	c.treasury = 0
	g.version += 1
	var hex := _own_hexes(g, &"GEN", 1)[0]
	var found := false
	for row: Dictionary in _rows(TileBuildings.of(g, &"GEN", hex)):
		if row["state"] == &"short":
			found = true
			assert_string_contains(row["state_text"], "you have 0")
			assert_eq(row["tone"], &"bad")
			assert_false(row["hammer"])
	assert_true(found or _rows(TileBuildings.of(g, &"GEN", hex)).is_empty(), "a dear row reads short")


func test_state_of_is_pure_over_each_verdict() -> void:
	assert_eq(TileBuildings.state_of({"ok": true}, &""), &"ready")
	assert_eq(TileBuildings.state_of({"ok": false, "reason": "x"}, &"ducats"), &"short")
	assert_eq(TileBuildings.state_of({"ok": false, "reason": "x"}, &"goods"), &"short")
	assert_eq(TileBuildings.state_of({"ok": false, "reason": "x"}, &"gate"), &"locked")
	assert_eq(TileBuildings.state_of({"ok": false, "reason": "x"}, &"slot"), &"refused")
	assert_eq(TileBuildings.state_of({"ok": false, "reason": "x"}, &"rule"), &"refused")
	assert_eq(TileBuildings.blocked_by({"ok": false, "reason": "not enough ducats: 3 needed"}), &"ducats")
	assert_eq(TileBuildings.blocked_by({"ok": false, "reason": "no free work slot: 1 of 1 in use"}), &"slot")
	assert_eq(TileBuildings.blocked_by({"ok": false, "reason": "not enough timber"}), &"goods")


func test_gate_placeholder_is_not_gated_and_words_are_fixed() -> void:
	var g := _game()
	assert_eq(TileBuildings.gate_of(g, &"GEN", {"action": Works.BUILD, "family": 7}), {})
	assert_eq(TileBuildings.gate_text({"year": 1495}), "opens in 1495")
	assert_eq(TileBuildings.gate_text({"tech": "Guilds"}), "needs Guilds")
	assert_eq(TileBuildings.gate_text({}), "")


func test_gains_equal_the_works_card_year_gain() -> void:
	var g := _game()
	var checked := 0
	for hex: Vector2i in _own_hexes(g, &"GEN", 4):
		for row: Dictionary in _rows(TileBuildings.of(g, &"GEN", hex, true)):
			var option: Dictionary = row["option"]
			if option.is_empty() or row["gain"] == null:
				continue
			var card := ImprovePreview.of(g, &"GEN", hex, option)
			assert_eq(int(row["gain"]), int((card["year"] as Dictionary)["gain"]))
			assert_eq(TileBuildings.gain(g, &"GEN", hex, option), int((card["year"] as Dictionary)["gain"]))
			checked += 1
	assert_gt(checked, 0)


func test_light_rows_carry_no_gains_and_summary_is_empty() -> void:
	var g := _game()
	var hex := _own_hexes(g, &"GEN", 1)[0]
	var tile := TileBuildings.of(g, &"GEN", hex)
	assert_eq(tile["summary"]["make"], null)
	assert_eq(tile["summary"]["upkeep"], null)
	for row: Dictionary in _rows(tile):
		assert_eq(row["gain"], null)


func test_summary_is_the_sum_of_the_built_rows() -> void:
	var g := _game()
	var hex := _with_built(g, &"GEN")
	if hex == Vector2i(-1, -1):
		pending("no built piece on the fixture")
		return
	var tile := TileBuildings.of(g, &"GEN", hex, true)
	var make := 0
	var upkeep := 0
	for row: Dictionary in _rows(tile):
		if row["state"] == &"built":
			make += int(row["gain"]) if row["gain"] != null else 0
			upkeep += int(row["upkeep"]) if row["upkeep"] != null else 0
	assert_eq(int(tile["summary"]["make"]), make, "summary make equals the built rows (planted fault)")
	assert_eq(int(tile["summary"]["upkeep"]), upkeep)


func test_a_built_row_is_working() -> void:
	var g := _game()
	var hex := _with_built(g, &"GEN")
	if hex == Vector2i(-1, -1):
		pending("no built piece on the fixture")
		return
	var built := []
	for row: Dictionary in _rows(TileBuildings.of(g, &"GEN", hex)):
		if row["state"] == &"built":
			built.append(row)
	assert_eq(built.size(), 1)
	assert_eq(built[0]["option"], {})
	assert_true(str(built[0]["state_text"]).begins_with("working"))


func test_a_work_under_way_is_a_building_row_with_progress() -> void:
	var g := _game()
	g.dev_money(&"GEN", 5000)
	g.dev_goods(&"GEN", 11, 200)
	g.dev_goods(&"GEN", 12, 200)
	var hex := Vector2i(-1, -1)
	for h: Vector2i in _own_hexes(g, &"GEN", 400):
		if Improve.piece_at(g, h).is_empty() and not ImprovePreview.options_of(g, &"GEN", h).is_empty():
			if g.act("build", {"hex": h, "family": int(ImprovePreview.options_of(g, &"GEN", h)[0]["family"]), "tag": &"GEN"})["ok"]:
				hex = h
				break
	if hex == Vector2i(-1, -1):
		pending("no build could begin on the fixture")
		return
	var building := []
	for row: Dictionary in _rows(TileBuildings.of(g, &"GEN", hex)):
		if row["state"] == &"building":
			building.append(row)
	assert_eq(building.size(), 1)
	assert_gt(float(building[0]["progress"]), 0.0)
	assert_lte(float(building[0]["progress"]), 1.0)
	assert_string_contains(building[0]["state_text"], "of")
	assert_false(building[0]["hammer"])


func test_a_refused_row_says_the_rules_words_and_has_no_hammer() -> void:
	var g := _game()
	var refused := 0
	for hex: Vector2i in _own_hexes(g, &"GEN", 60):
		for row: Dictionary in _rows(TileBuildings.of(g, &"GEN", hex)):
			if row["state"] == &"refused":
				refused += 1
				assert_false(row["hammer"])
				assert_ne(str(row["state_text"]), "")
				assert_eq(row["tone"], &"bad")
	assert_gt(refused, 0, "some own hex refuses a row with the rule's words")


func test_sandbox_has_rows_for_any_land_and_no_gains() -> void:
	var g := Game.new_game(EconomyFixture.map(), 5, EconomyFixture.defs())
	var hex := Vector2i(-1, -1)
	for i: int in g.map.hex_count():
		if g.map.land[i] != 0 and g.state.main_use[i] == 0:
			hex = g.map.hex_of(i)
			break
	if hex == Vector2i(-1, -1):
		pending("no wild hex")
		return
	var tile := TileBuildings.of(g, &"", hex, true)
	assert_false(tile.is_empty())
	assert_eq(tile["summary"]["make"], 0, "no built piece: the sum is 0")
	assert_false(TileBuildings.of(g, &"", hex).is_empty())


## Starts one build on an own wild hex with money and goods to spare; returns the hex, or (-1, -1) when none began.
func _started(g: Game) -> Vector2i:
	g.dev_money(&"GEN", 5000)
	g.dev_goods(&"GEN", 11, 200)
	g.dev_goods(&"GEN", 12, 200)
	for h: Vector2i in _own_hexes(g, &"GEN", 400):
		var offers := ImprovePreview.options_of(g, &"GEN", h)
		if Improve.piece_at(g, h).is_empty() and not offers.is_empty():
			if bool(g.act("build", {"hex": h, "family": int(offers[0]["family"]), "tag": &"GEN"})["ok"]):
				return h
	return Vector2i(-1, -1)


func test_a_work_row_takes_the_works_family_and_icon() -> void:
	var g := _game()
	var hex := _started(g)
	if hex == Vector2i(-1, -1):
		pending("no build could begin on the fixture")
		return
	var family := int(WorksView.at(g, hex, &"GEN")["family"])
	assert_gt(family, 0, "the work view names the family of a fresh build")
	for row: Dictionary in _rows(TileBuildings.of(g, &"GEN", hex)):
		if row["state"] == &"building":
			assert_eq(row["icon"], FamilyIds.NAMES[family])
			assert_eq(row["group"], TileBuildings._group_of(family), "grouped by its own family, not Land by default")


func test_a_busy_hex_lists_the_other_rows_refused_with_the_reason_and_hammers_return() -> void:
	var g := _game()
	var hex := _started(g)
	if hex == Vector2i(-1, -1):
		pending("no build could begin on the fixture")
		return
	var building := 0
	var refused := 0
	for row: Dictionary in _rows(TileBuildings.of(g, &"GEN", hex)):
		if row["state"] == &"building":
			building += 1
			continue
		if (row["option"] as Dictionary).is_empty():
			continue
		refused += 1
		assert_eq(row["state"], &"refused")
		assert_false(row["hammer"], "a hammer is greyed while a work runs")
		assert_true(str(row["reason"]).begins_with("one job at a time: "), "the busy reason")
		assert_true(str(row["reason"]).ends_with("is under way"))
	assert_eq(building, 1)
	assert_gt(refused, 0, "the other buildable rows stay listed")
	assert_true(g.act("cancel_work", {"hex": hex, "tag": &"GEN"})["ok"])
	var ready := 0
	for row: Dictionary in _rows(TileBuildings.of(g, &"GEN", hex)):
		if not (row["option"] as Dictionary).is_empty() and row["hammer"]:
			ready += 1
	assert_gt(ready, 0, "the hammer comes back once the work is gone")


func test_a_built_row_gain_is_the_negated_clearing_card() -> void:
	var g := _game()
	var hex := _with_built(g, &"GEN")
	if hex == Vector2i(-1, -1):
		pending("no built piece on the fixture")
		return
	var family := int(Improve.piece_at(g, hex)["family_id"])
	var year: Dictionary = ImprovePreview.of(g, &"GEN", hex, {"action": Works.CLEAR, "family": family}).get("year", {})
	for row: Dictionary in _rows(TileBuildings.of(g, &"GEN", hex, true)):
		if row["state"] == &"built":
			if year.is_empty():
				assert_eq(row["gain"], null)
			else:
				assert_eq(int(row["gain"]), -int(year["gain"]), "approximation: built gain is the negated clear card")
