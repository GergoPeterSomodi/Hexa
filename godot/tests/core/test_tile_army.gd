## TileArmy (docs/architecture/tilewin-build-spec.md R7, R9, R21, R22; TW6): the armies here for any viewer (own rows with an id
## and an open flag, foreign rows read-only with no id), the raise rows on the viewer's own settlement only, the row fields,
## the state and the rule's own words, and can_raise (n passes, n + 1 refused) on three towns. North Italy: Genoa (TAG) is
## the viewer, Savoy (SAV) the foreign country. Planted faults: a foreign id; can_raise off by one; a foreign tile with raise
## rows; a refusal in other words; the door scan of R8 for this file.
extends GutTest

const TAG := &"GEN"
const SAV := &"SAV"

var _g: Game


func before_each() -> void:
	_g = ArmyFixture.game()
	ArmyFixture.rich(_g)


func _kind(key: String) -> int:
	for ud: UnitDef in _g.defs.units:
		if String(ud.key) == key:
			return ud.id
	return -1


## The first `count` land hexes of `tag` that are not occupied (a test's search, not a rule).
func _owned_land(tag: StringName, count: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i: int in _g.map.hex_count():
		if out.size() >= count:
			break
		var hex := _g.map.hex_of(i)
		if _g.map.is_land(hex) and Territory.owner_tag(_g, hex) == tag and not Occupation.is_occupied(_g, hex):
			out.append(hex)
	return out


## A land hex TAG does not see (Knowledge), or NO_HEX.
func _unseen_land() -> Vector2i:
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		if _g.map.is_land(hex) and not Knowledge.sees(_g, TAG, hex):
			return hex
	return ArmyFixture.NO_HEX


func _ok(hex: Vector2i, kind: int, count: int) -> bool:
	return bool(Military.raise_check(_g, {"hex": hex, "kind": kind, "count": count, "tag": TAG}).get("ok", false))


func _row(view: Dictionary, kind: int) -> Dictionary:
	for r: Dictionary in (view.raise.rows as Array):
		if int(r.kind) == kind:
			return r
	return {}


## Three towns of TAG at levels 2, 3 and 5 with their people (the raise caps 1, 2 and 4).
func _three_towns() -> Array[Vector2i]:
	var hexes := _owned_land(TAG, 3)
	var levels := [2, 3, 5]
	for k: int in hexes.size():
		ArmyFixture.town(_g, hexes[k], levels[k], 20000)
	return hexes


# --- armies here -----------------------------------------------------------------------------------------------------

func test_own_army_is_a_row_with_its_id_and_an_open_flag() -> void:
	var hex := _owned_land(TAG, 1)[0]
	ArmyFixture.town(_g, hex, 3, 20000)
	var a := ArmyFixture.army(_g, TAG, hex, _kind("pikemen"), 2)
	var view := TileArmy.of(_g, TAG, hex)
	var rows := view.armies as Array
	assert_eq(rows.size(), 1, "one own army here")
	var r := rows[0] as Dictionary
	assert_true(bool(r.own))
	assert_true(bool(r.open), "an own army opens")
	assert_eq(int(r.id), a.id, "the own row carries its id")
	assert_eq(int(r.men), a.men())
	assert_eq(str(r.name), "Army of test")
	assert_false(str(r.state_text).is_empty(), "the state line is shown")


func test_foreign_army_in_sight_is_read_only_and_has_no_id() -> void:
	var hex := _owned_land(TAG, 1)[0]
	ArmyFixture.town(_g, hex, 3, 20000)
	ArmyFixture.army(_g, TAG, hex, _kind("pikemen"), 1)
	var foreign := ArmyFixture.army(_g, SAV, hex, _kind("pikemen"), 2)
	var rows := TileArmy.of(_g, TAG, hex).armies as Array
	assert_eq(rows.size(), 2, "the own army and the one in sight")
	var f: Dictionary = {}
	for r: Dictionary in rows:
		if not bool(r.own):
			f = r
	assert_false(f.is_empty(), "a foreign row")
	assert_false(bool(f.open), "a foreign row does not open")
	assert_eq(StringName(f.tag), SAV)
	assert_eq(int(f.men), foreign.men(), "men exact")
	assert_false(f.has("id"), "P: a foreign army has no id")
	assert_eq(str(f.state_text), "", "P: no order of another country is shown")


func test_unseen_foreign_army_has_no_row() -> void:
	var hex := _unseen_land()
	assert_ne(hex, ArmyFixture.NO_HEX, "the 1480 map has a land hex Genoa does not see")
	ArmyFixture.army(_g, SAV, hex, _kind("pikemen"), 2)
	var view := TileArmy.of(_g, TAG, hex)
	assert_true((view.armies as Array).is_empty(), "P: an unseen army is not shown")
	assert_true((view.raise as Dictionary).is_empty())


func test_the_viewer_sees_its_own_armies_on_another_country_tile() -> void:
	var sav_hex := _owned_land(SAV, 1)
	if sav_hex.is_empty():
		pending("no land of Savoy on the map")
		return
	ArmyFixture.army(_g, TAG, sav_hex[0], _kind("pikemen"), 1)
	var view := TileArmy.of(_g, TAG, sav_hex[0])
	assert_eq((view.armies as Array).size(), 1, "own armies show on any tile")
	assert_true((view.raise as Dictionary).is_empty(), "P: no raise rows on another country's tile")


# --- raise rows ------------------------------------------------------------------------------------------------------

func test_raise_rows_only_on_the_viewers_own_settlement() -> void:
	var town := _three_towns()[1]
	var raise := TileArmy.of(_g, TAG, town).raise as Dictionary
	assert_false(raise.is_empty(), "own settlement has raise rows")
	assert_eq((raise.rows as Array).size(), _g.defs.units.size(), "one row per kind")
	assert_eq(raise.arms, {}, "the arms banner is empty until M9.5")
	var theirs := TileArmy.of(_g, SAV, town)
	var their_raise := theirs.raise as Dictionary
	assert_true(their_raise.is_empty(), "P: Savoy sees no raise rows on Genoa's town")


func test_head_line_counts_men_and_companies() -> void:
	var town := _three_towns()[1]
	var head := str((TileArmy.of(_g, TAG, town).raise as Dictionary).head)
	var men := Words.number(Military.men_at_hand(_g, TAG, town))
	assert_eq(head, "Men to levy %s · 0 of 2 raised this season" % men)
	assert_true(Military.raise_check(_g, {"hex": town, "kind": _kind("pikemen"), "count": 1, "tag": TAG}).ok)
	assert_true(Military.raise(_g, {"hex": town, "kind": _kind("pikemen"), "count": 1, "tag": TAG}).ok)
	var after := str((TileArmy.of(_g, TAG, town).raise as Dictionary).head)
	assert_true(after.ends_with("1 of 2 raised this season"), "the head counts the raised companies")


func test_row_fields_and_cost_parts_of_pikemen() -> void:
	var town := _three_towns()[1]
	var r := _row(TileArmy.of(_g, TAG, town), _kind("pikemen"))
	assert_eq(str(r.name), "Pikemen")
	assert_eq(StringName(r.figure), &"fig_infantry")
	assert_eq(int(r.era), 1)
	assert_eq(str(r.era_text), "I")
	assert_eq(int(r.men), 500)
	assert_eq(int(r.upkeep), 6)
	assert_eq(str(r.cost_text), "25 ducats + 1 iron")
	var parts := r.parts as Array
	assert_eq(parts.size(), 2)
	assert_eq(str((parts[0] as Dictionary).key), "ducats")
	assert_eq(int((parts[0] as Dictionary).amount), 25)
	assert_eq(str((parts[1] as Dictionary).name), "iron")
	assert_eq(int((parts[1] as Dictionary).amount), 1)
	assert_eq(StringName(r.state), &"ready")
	assert_eq(str(r.reason), "")


func test_era_badge_follows_the_unit_era() -> void:
	var town := _three_towns()[1]
	var kind := _kind("pikemen")
	var ud := Military.unit_def(_g, kind)
	ud.era = 2
	assert_eq(str(_row(TileArmy.of(_g, TAG, town), kind).era_text), "II")
	ud.era = 3
	assert_eq(str(_row(TileArmy.of(_g, TAG, town), kind).era_text), "III")


# --- can_raise -------------------------------------------------------------------------------------------------------

func test_can_raise_is_exact_on_three_towns() -> void:
	var kind := _kind("pikemen")
	for town: Vector2i in _three_towns():
		var n := TileArmy.can_raise(_g, TAG, town, kind)
		assert_gte(n, 1, "pikemen can be raised in a settlement of Genoa")
		assert_true(_ok(town, kind, n), "P: n companies pass the check")
		assert_false(_ok(town, kind, n + 1), "P: n + 1 companies are refused (off by one)")
		assert_eq(TileArmy.can_raise(_g, TAG, town, kind), n, "can_raise is the same on every call")
		assert_eq(int(_row(TileArmy.of(_g, TAG, town), kind).can_raise), n, "the row shows the same number")


func test_can_raise_is_limited_by_the_ducats() -> void:
	var town := _three_towns()[2]
	var kind := _kind("pikemen")
	var c := Countries.by_tag(_g, TAG)
	c.treasury = 60
	assert_eq(TileArmy.can_raise(_g, TAG, town, kind), 2, "60 ducats pay two companies at 25")
	assert_false(_ok(town, kind, 3), "P: a third company is refused")


func test_can_raise_is_zero_on_foreign_land() -> void:
	var hex := _unseen_land()
	assert_eq(TileArmy.can_raise(_g, TAG, hex, _kind("pikemen")), 0)
	var sav := _owned_land(SAV, 1)
	if not sav.is_empty():
		assert_eq(TileArmy.can_raise(_g, TAG, sav[0], _kind("pikemen")), 0)


# --- states and words ------------------------------------------------------------------------------------------------

func test_a_kind_above_the_settlement_level_is_locked_in_the_rules_words() -> void:
	var village := _owned_land(TAG, 1)[0]
	ArmyFixture.town(_g, village, 1, 20000)
	var kind := _kind("knights")
	var verdict := Military.raise_check(_g, {"hex": village, "kind": kind, "count": 1, "tag": TAG})
	var r := _row(TileArmy.of(_g, TAG, village), kind)
	assert_eq(StringName(r.state), &"locked")
	assert_eq(str(r.reason), str(verdict.reason), "the rule's own words")
	assert_true(str(r.reason).contains("village or larger"))


func test_short_horses_are_refused_in_the_rules_words() -> void:
	var town := _three_towns()[1]
	var kind := _kind("knights")
	var horses := -1
	for gid: int in _g.defs.goods.size():
		if String(_g.defs.good(gid).key) == "horses":
			horses = gid
	Countries.by_tag(_g, TAG).stock[horses] = 1
	var verdict := Military.raise_check(_g, {"hex": town, "kind": kind, "count": 1, "tag": TAG})
	var r := _row(TileArmy.of(_g, TAG, town), kind)
	assert_eq(StringName(r.state), &"short")
	assert_eq(str(r.reason), str(verdict.reason))
	assert_true(str(r.reason).begins_with("not enough horses"), "the words of the store check")


func test_short_ducats_are_short_with_the_check_words() -> void:
	var town := _three_towns()[1]
	Countries.by_tag(_g, TAG).treasury = 10
	var verdict := Military.raise_check(_g, {"hex": town, "kind": _kind("pikemen"), "count": 1, "tag": TAG})
	var r := _row(TileArmy.of(_g, TAG, town), _kind("pikemen"))
	assert_eq(StringName(r.state), &"short")
	assert_eq(str(r.reason), str(verdict.reason))
	assert_eq(int(r.can_raise), 0)


func test_a_refusal_of_the_cap_keeps_its_words_and_state() -> void:
	var town := _three_towns()[0]
	var kind := _kind("pikemen")
	assert_true(Military.raise(_g, {"hex": town, "kind": kind, "count": 1, "tag": TAG}).ok)
	var verdict := Military.raise_check(_g, {"hex": town, "kind": kind, "count": 1, "tag": TAG})
	var r := _row(TileArmy.of(_g, TAG, town), kind)
	assert_eq(StringName(r.state), &"refused", "a rule refusal that is not short or locked")
	assert_eq(str(r.reason), str(verdict.reason))
	assert_eq(int(r.can_raise), 0)


func test_state_of_maps_the_verdict_words() -> void:
	assert_eq(TileArmy.state_of({"ok": true, "reason": ""}), &"ready")
	assert_eq(TileArmy.state_of({"ok": false, "reason": "not enough ducats: 25 needed, 10 in the treasury"}), &"short")
	assert_eq(TileArmy.state_of({"ok": false, "reason": "only 0 men can be raised here this season: 500 are needed"}), &"short")
	assert_eq(TileArmy.state_of({"ok": false, "reason": "Knights are raised in a village or larger"}), &"locked")
	assert_eq(TileArmy.state_of({"ok": false, "reason": "no room at (3, 4): 6 of 6 companies"}), &"refused")


# --- fog and the door ------------------------------------------------------------------------------------------------

func test_the_model_has_no_direct_reads_of_state_or_the_player() -> void:
	var text := FileAccess.get_file_as_string("res://core/views/tile_army.gd")
	assert_false(text.is_empty(), "the file is read")
	for bad: String in ["game.state.", "Armies.", "Occupation.garrison_of", "Sight.", "Session", "Events", "game.player"]:
		assert_false(text.contains(bad), "P: tile_army.gd names %s" % bad)
