## Country state (core/state/country.gd; docs/architecture/m2-build-spec.md section 5.2, 5.9 and 10):
## defaults, JSON-safe round trip, schema validation and digest_text sensitivity.
extends GutTest

## sha256 of no bytes: the digest text of a country that has seen nothing.
const EMPTY := "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"


func test_defaults_and_create() -> void:
	var empty := Country.new()
	assert_eq(empty.id, 0)
	assert_eq(empty.tag, &"")
	assert_eq(empty.capital, Country.NO_HEX)
	assert_eq(empty.capital, Vector2i(-1, -1))
	assert_true(empty.alive)

	var gen := Country.create(7, &"GEN", Vector2i(8, 13))
	assert_eq(gen.id, 7)
	assert_eq(gen.tag, &"GEN")
	assert_eq(gen.capital, Vector2i(8, 13))
	assert_true(gen.alive)

	var fra := Country.create(1, &"FRA", Country.NO_HEX, false)
	assert_eq(fra.id, 1)
	assert_eq(fra.tag, &"FRA")
	assert_eq(fra.capital, Country.NO_HEX)
	assert_false(fra.alive)


func test_round_trip_through_json() -> void:
	var src := Country.create(7, &"GEN", Vector2i(8, 13), true)
	var d := src.to_dict()
	assert_eq(d["schema"], Country.SCHEMA)
	var parsed: Variant = _json(d)
	assert_true(parsed is Dictionary)
	var back := Country.from_dict(parsed as Dictionary)
	assert_not_null(back)
	assert_eq(back.id, src.id)
	assert_eq(back.tag, src.tag)
	assert_eq(back.capital, src.capital)
	assert_eq(back.alive, src.alive)
	assert_eq(back.digest_text(), src.digest_text())

	# Outside power with off-map capital and alive = false also survives JSON round trip.
	var off_map := Country.create(2, &"AUS", Country.NO_HEX, false)
	var off_parsed: Variant = _json(off_map.to_dict())
	assert_true(off_parsed is Dictionary)
	var off_back := Country.from_dict(off_parsed as Dictionary)
	assert_not_null(off_back)
	assert_eq(off_back.id, 2)
	assert_eq(off_back.tag, &"AUS")
	assert_eq(off_back.capital, Country.NO_HEX)
	assert_false(off_back.alive)
	assert_eq(off_back.digest_text(), off_map.digest_text())


func test_from_dict_refuses_wrong_schema_and_bad_capital() -> void:
	var d := Country.create(5, &"MLO", Vector2i(9, 9)).to_dict()
	d["schema"] = "hexa-godot/country/99"
	assert_null(Country.from_dict(d), "wrong schema version returns null")
	d["schema"] = "nope"
	assert_null(Country.from_dict(d), "unknown schema returns null")
	assert_null(Country.from_dict({}), "empty dict returns null")

	for bad_cap: Variant in [[9], [9, 9, 1], "9,9", 42]:
		var malformed := Country.create(5, &"MLO", Vector2i(9, 9)).to_dict()
		malformed["capital"] = bad_cap
		assert_null(Country.from_dict(malformed), "malformed capital returns null")

	# Direct Vector2i in an in-memory dictionary is also accepted.
	var direct := {"schema": Country.SCHEMA, "id": 5, "tag": &"MLO", "capital": Vector2i(9, 9), "alive": true}
	var from_direct := Country.from_dict(direct)
	assert_not_null(from_direct)
	assert_eq(from_direct.capital, Vector2i(9, 9))


func test_digest_text_format_and_changes_with_each_field() -> void:
	var gen := Country.create(7, &"GEN", Vector2i(8, 13), true)
	assert_eq(gen.digest_text(), "7|GEN|8,13|true|0|1|0|0|||||||||0|1000|" + EMPTY)
	var fra := Country.create(1, &"FRA", Country.NO_HEX, false)
	assert_eq(fra.digest_text(), "1|FRA|-1,-1|false|0|1|0|0|||||||||0|1000|" + EMPTY)

	var base := gen.digest_text()
	var seen: Dictionary = {base: true}
	var edits: Array[Callable] = [
		func(c: Country) -> void: c.id = 8,
		func(c: Country) -> void: c.tag = &"VEN",
		func(c: Country) -> void: c.capital = Vector2i(9, 13),
		func(c: Country) -> void: c.capital = Vector2i(8, 14),
		func(c: Country) -> void: c.alive = false,
	]
	for edit: Callable in edits:
		var c := Country.create(7, &"GEN", Vector2i(8, 13), true)
		edit.call(c)
		var text := c.digest_text()
		assert_false(seen.has(text), "edit must change digest_text: %s" % text)
		seen[text] = true


## A country with every M4 field set, for the round-trip tests.
func _rich() -> Country:
	var c := Country.create(3, &"GEN", Vector2i(8, 13))
	c.treasury = 1234
	c.tax = 2
	c.short_mask = 5
	c.ledger_from = 1000
	c.ledger_open = [
		{"why": &"tax_people", "hex": Vector2i(-1, -1), "amount": 300, "count": 1},
		{"why": &"port_dues", "hex": Vector2i(4, 5), "amount": 20, "count": 2},
	]
	c.ledger_closed = {"turn": 4, "opening": 900, "closing": 1000, "lines": [
		{"why": &"work", "hex": Vector2i(2, 2), "amount": -50, "count": 1},
	]}
	c.stock.resize(16)
	c.stock[0] = 12
	c.stock[12] = 40
	c.stock_from = c.stock.duplicate()
	c.flows_open.resize(16 * Country.FLOW_COUNT)
	c.flows_open[0 * 16 + 3] = 7
	c.flows_open[5 * 16 + 12] = -2
	c.goods_closed = {"turn": 4, "opening": c.stock.duplicate(), "closing": c.stock.duplicate(),
		"flows": c.flows_open.duplicate()}
	return c


func test_country_2_round_trip_every_field() -> void:
	var src := _rich()
	assert_eq(Country.SCHEMA, "hexa-godot/country/4")
	var d := src.to_dict()
	assert_eq(d["flows_shape"], [16, Country.FLOW_COUNT])
	var parsed: Variant = _json(d)
	assert_true(parsed is Dictionary)
	var back := Country.from_dict(parsed as Dictionary)
	assert_not_null(back)
	assert_eq(back.treasury, 1234)
	assert_eq(back.tax, 2)
	assert_eq(back.short_mask, 5)
	assert_eq(back.ledger_from, 1000)
	assert_eq(back.ledger_open, src.ledger_open)
	assert_eq(typeof(back.ledger_open[1]["why"]), TYPE_STRING_NAME)
	assert_eq(back.ledger_open[1]["hex"], Vector2i(4, 5))
	assert_eq(back.ledger_closed["turn"], 4)
	assert_eq(back.ledger_closed["lines"], src.ledger_closed["lines"])
	assert_eq(back.stock, src.stock)
	assert_eq(back.flows_open, src.flows_open)
	assert_eq(back.stock_from, src.stock_from)
	assert_eq(back.goods_closed["turn"], 4)
	assert_eq(back.goods_closed["flows"], src.goods_closed["flows"])
	assert_eq(back.digest_text(), src.digest_text())
	var again := Country.from_dict(back.to_dict())
	assert_eq(again.digest_text(), src.digest_text())


func test_digest_text_with_the_m4_fields() -> void:
	var c := Country.create(3, &"GEN", Vector2i(8, 13))
	assert_eq(c.digest_text(), "3|GEN|8,13|true|0|1|0|0|||||||||0|1000|%s" % EMPTY)
	c.treasury = 50
	c.tax = 0
	c.short_mask = 3
	c.ledger_from = 40
	c.ledger_open = [{"why": &"port_dues", "hex": Vector2i(4, 5), "amount": 20, "count": 2}]
	c.ledger_closed = {"turn": 4, "opening": 9, "closing": 40, "lines": [
		{"why": &"work", "hex": Vector2i(2, 2), "amount": -5, "count": 1}]}
	c.stock = PackedInt32Array([1, 2])
	c.stock_from = PackedInt32Array([1, 1])
	c.flows_open = PackedInt32Array([3, 4])
	c.goods_closed = {"turn": 4, "opening": PackedInt32Array([1]), "closing": PackedInt32Array([2]),
		"flows": PackedInt32Array([1, 0])}
	assert_eq(c.digest_text(), "3|GEN|8,13|true|50|0|3|40|port_dues:4,5:20:2|4:9:40;work:2,2:-5:1|1,2|3,4|1,1|4:1:2:1,0|||0|1000|%s" % EMPTY)
	# Every M4 field moves the digest.
	var base := _rich().digest_text()
	var edits: Array[Callable] = [
		func(x: Country) -> void: x.treasury += 1,
		func(x: Country) -> void: x.tax = 0,
		func(x: Country) -> void: x.short_mask = 0,
		func(x: Country) -> void: x.ledger_from += 1,
		func(x: Country) -> void: x.ledger_open[0]["amount"] = 301,
		func(x: Country) -> void: x.ledger_closed["closing"] = 1,
		func(x: Country) -> void: x.stock[0] += 1,
		func(x: Country) -> void: x.flows_open[1] += 1,
		func(x: Country) -> void: x.stock_from[2] += 1,
		func(x: Country) -> void: x.goods_closed["turn"] = 9,
	]
	for edit: Callable in edits:
		var x := _rich()
		edit.call(x)
		assert_ne(x.digest_text(), base)


func test_country_1_is_refused_and_bad_types_too() -> void:
	var d := _rich().to_dict()
	d["schema"] = "hexa-godot/country/1"
	assert_null(Country.from_dict(d), "a country/1 dict is refused")
	for key: String in ["treasury", "tax", "short_mask", "ledger_from"]:
		var bad := _rich().to_dict()
		bad[key] = "12"
		assert_null(Country.from_dict(bad), "a string for %s is refused" % key)
	var bad_lines := _rich().to_dict()
	bad_lines["ledger_open"] = [{"why": 5, "hex": [1, 1], "amount": 1, "count": 1}]
	assert_null(Country.from_dict(bad_lines))
	var bad_stock := _rich().to_dict()
	bad_stock["stock"] = ["a"]
	assert_null(Country.from_dict(bad_stock))
	var bad_shape := _rich().to_dict()
	bad_shape["flows_shape"] = [3, 6]
	assert_null(Country.from_dict(bad_shape), "a shape that does not match the list")


func test_an_older_flows_shape_is_relaid() -> void:
	# Saved with 14 goods and 4 flows, flow-major: flow * 14 + good.
	var d := _rich().to_dict()
	var old := PackedInt32Array()
	old.resize(14 * 4)
	old[0 * 14 + 3] = 7
	old[2 * 14 + 12] = -9
	old[3 * 14 + 13] = 4
	d["flows_shape"] = [14, 4]
	d["flows_open"] = old
	var c := Country.from_dict(d)
	assert_not_null(c)
	assert_eq(c.flows_open.size(), 16 * Country.FLOW_COUNT)
	assert_eq(c.flows_open[0 * 16 + 3], 7)
	assert_eq(c.flows_open[2 * 16 + 12], -9)
	assert_eq(c.flows_open[3 * 16 + 13], 4)
	assert_eq(c.flows_open[5 * 16 + 12], 0, "a missing cell is 0")
	var total := 0
	for v: int in c.flows_open:
		total += v
	assert_eq(total, 2, "nothing else appears")
	# goods_closed.flows is re-laid the same way.
	var gc := _rich().to_dict()
	var closed := gc["goods_closed"] as Dictionary
	closed["flows"] = old
	closed["flows_shape"] = [14, 4]
	var c2 := Country.from_dict(gc)
	assert_not_null(c2)
	assert_eq((c2.goods_closed["flows"] as PackedInt32Array)[2 * 16 + 12], -9)
	assert_eq((c2.goods_closed["flows"] as PackedInt32Array).size(), 16 * Country.FLOW_COUNT)


func test_short_stock_arrays_are_padded() -> void:
	var d := _rich().to_dict()
	d["stock"] = PackedInt32Array([5, 6, 7])
	d["stock_from"] = [1, 2]
	var closed := d["goods_closed"] as Dictionary
	closed["opening"] = PackedInt32Array([4])
	var c := Country.from_dict(d)
	assert_not_null(c)
	assert_eq(c.stock.size(), 16)
	assert_eq(c.stock[2], 7)
	assert_eq(c.stock[3], 0)
	assert_eq(c.stock_from.size(), 16)
	assert_eq(c.stock_from[1], 2)
	assert_eq((c.goods_closed["opening"] as PackedInt32Array).size(), 16)
	# An empty stock (no goods in the defs) stays empty.
	var empty := Country.from_dict(Country.create(1, &"AAA").to_dict())
	assert_eq(empty.stock.size(), 0)
	assert_eq(empty.flows_open.size(), 0)


func test_a_damaged_purse_is_refused() -> void:
	var long_stock := _rich().to_dict()
	long_stock["stock"] = PackedInt32Array(range(20))
	long_stock["stock_from"] = PackedInt32Array(range(20))
	assert_null(Country.from_dict(long_stock), "a stock of 20 entries")
	var uneven := _rich().to_dict()
	uneven["stock_from"] = PackedInt32Array([1, 2, 3])
	assert_not_null(Country.from_dict(uneven), "3 pads to 16, the same size as the stock")
	var half := _rich().to_dict()
	half["stock_from"] = PackedInt32Array()
	assert_null(Country.from_dict(half), "stock_from empty beside a full stock")
	for tax: int in [77, -1, 3]:
		var bad := _rich().to_dict()
		bad["tax"] = tax
		assert_null(Country.from_dict(bad), "tax %d" % tax)
	var neg := _rich().to_dict()
	neg["short_mask"] = -1
	assert_null(Country.from_dict(neg), "a negative short_mask")
	var closed := _rich().to_dict()
	(closed["goods_closed"] as Dictionary)["closing"] = PackedInt32Array(range(20))
	assert_null(Country.from_dict(closed), "a closed stock of 20 entries")
	for tax: int in [0, 1, 2]:
		var ok := _rich().to_dict()
		ok["tax"] = tax
		assert_not_null(Country.from_dict(ok))


func _with_people() -> Country:
	var c := _rich()
	c.people_flows = PackedInt32Array([120, -30, -5, 0, 0, 7])
	c.people_closed = {"turn": 4, "flows": PackedInt32Array([100, -20, -3, 0, 0, 0])}
	c.food_need = 9
	c.food_fed = 750
	return c


func test_country_3_round_trip_every_people_field() -> void:
	var src := _with_people()
	var d := src.to_dict()
	assert_eq(d["schema"], "hexa-godot/country/4")
	for form: int in 2:
		var back: Country = null
		if form == 0:
			back = Country.from_dict(_json(d) as Dictionary)
		else:
			back = Country.from_dict(bytes_to_var(var_to_bytes(d)) as Dictionary)
		assert_not_null(back, "form %d" % form)
		assert_eq(back.people_flows, src.people_flows)
		assert_eq(back.people_closed["turn"], 4)
		assert_eq(back.people_closed["flows"], src.people_closed["flows"])
		assert_eq(back.food_need, 9)
		assert_eq(back.food_fed, 750)
		assert_eq(back.digest_text(), src.digest_text())
		assert_eq(var_to_bytes(back.to_dict()), var_to_bytes(d), "save, load, save equal")
	assert_eq(src.digest_text().split("|").slice(-5, -1),
			PackedStringArray(["120,-30,-5,0,0,7", "4:100,-20,-3,0,0,0", "9", "750"]))


func test_the_digest_moves_with_one_flow_and_one_field_and_only_then() -> void:
	var base := _with_people().digest_text()
	assert_eq(_with_people().digest_text(), base, "the same country, the same text")
	var seen: Dictionary = {base: true}
	var edits: Array[Callable] = [
		func(x: Country) -> void: x.people_flows[0] += 1,
		func(x: Country) -> void: x.people_flows[5] -= 1,
		func(x: Country) -> void: x.people_closed["turn"] = 5,
		func(x: Country) -> void: x.people_closed["flows"][2] -= 1,
		func(x: Country) -> void: x.food_need += 1,
		func(x: Country) -> void: x.food_fed = 1000,
	]
	for edit: Callable in edits:
		var x := _with_people()
		edit.call(x)
		assert_false(seen.has(x.digest_text()), "one change moves the digest")
		seen[x.digest_text()] = true


func test_country_2_and_3_are_refused() -> void:
	for old: String in ["hexa-godot/country/2", "hexa-godot/country/3"]:
		var d := _rich().to_dict()
		d["schema"] = old
		assert_null(Country.from_dict(d), "P: %s is refused (D40)" % old)
	var fresh := _rich().to_dict()
	for key: String in ["people_flows", "people_closed", "food_need", "food_fed", "explored"]:
		fresh.erase(key)
	var back := Country.from_dict(fresh)
	assert_not_null(back, "a country/4 dict without the later keys takes their defaults")
	assert_true(back.explored.is_empty())
	assert_eq(back.food_fed, 1000)


func _with_explored() -> Country:
	var c := _with_people()
	c.explored = PackedByteArray([1, 0, 255, 16])
	return c


func test_country_4_explored_round_trips_and_moves_the_digest() -> void:
	var src := _with_explored()
	var d := src.to_dict()
	assert_true(d["explored"] is PackedByteArray, "kept packed")
	assert_eq(d["schema"], "hexa-godot/country/4")
	var back := Country.from_dict(bytes_to_var(var_to_bytes(d)) as Dictionary)
	assert_not_null(back)
	assert_eq(back.explored, src.explored)
	assert_eq(back.digest_text(), src.digest_text())
	assert_ne(src.digest_text(), _with_people().digest_text(), "explored is in the digest")
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(src.explored)
	assert_true(src.digest_text().ends_with("|" + ctx.finish().hex_encode()))
	var x := _with_explored()
	x.explored[3] = 17
	assert_ne(x.digest_text(), src.digest_text(), "one bit moves it")
	var copy := Country.from_dict(d)
	copy.explored[0] = 9
	assert_eq(src.explored[0], 1, "the dict holds its own copy")


func test_country_4_refuses_a_mistyped_explored() -> void:
	for bad: Variant in ["abc", [1, 2], 5, PackedInt32Array([1])]:
		var d := _with_explored().to_dict()
		d["explored"] = bad
		assert_null(Country.from_dict(d), "P: explored must be a PackedByteArray")


func test_a_short_flows_array_is_padded_and_a_long_one_refused() -> void:
	var d := _with_people().to_dict()
	d["people_flows"] = PackedInt32Array([4, 5, 6])
	var back := Country.from_dict(d)
	assert_not_null(back)
	assert_eq(back.people_flows, PackedInt32Array([4, 5, 6, 0, 0, 0]))
	d["people_closed"] = {"turn": 2, "flows": PackedInt32Array([1])}
	assert_eq(Country.from_dict(d).people_closed["flows"], PackedInt32Array([1, 0, 0, 0, 0, 0]))
	d["people_flows"] = PackedInt32Array([1, 2, 3, 4, 5, 6, 7])
	assert_null(Country.from_dict(d), "P: more flows than People knows")
	assert_eq(Country.PEOPLE_FLOW_COUNT, 6)


func test_country_3_refuses_mistyped_people_fields() -> void:
	var cases: Array = [
		["food_need", "9"], ["food_need", -1], ["food_need", 9.5], ["food_fed", "750"], ["food_fed", 1001],
		["food_fed", -1], ["people_flows", "1,2"], ["people_flows", ["a"]], ["people_flows", {"a": 1}],
		["people_closed", "x"], ["people_closed", {"turn": "4", "flows": [1]}], ["people_closed", {"turn": 4}],
		["people_closed", {"turn": 4, "flows": "1"}], ["people_closed", {"turn": 4, "flows": [1, 2, 3, 4, 5, 6, 7]}],
		["people_closed", [4]],
	]
	for item: Array in cases:
		var bad := _with_people().to_dict()
		bad[str(item[0])] = item[1]
		assert_null(Country.from_dict(bad), "P: %s = %s" % [item[0], str(item[1])])


## d through JSON; JSON writes bytes as text, so explored (kept packed, saved with var_to_bytes) is put back as it was.
func _json(d: Dictionary) -> Variant:
	var parsed: Variant = JSON.parse_string(JSON.stringify(d))
	if parsed is Dictionary:
		(parsed as Dictionary)["explored"] = d["explored"]
	return parsed
