## Who writes what (docs/architecture/m3-build-spec.md 5.7, 9; m4-build-spec.md 5.3): the snapshot before and after every
## action and every phase differs only in the owners' fields and the door's (chronicle and action_log; events, version,
## view_cache and districts are not saved). The money is the purse (Treasury), the goods the stores (Stores), the tax and the
## shortage bits EconomySeason's, the people (M5 spec 5.3) People's: `people` (the hexes' people and the open flows), `people_close`
## (the start and end arrays and the closed flows, People.close, in the stats phase), `people_flows` (the open flows: People.move,
## and People.close zeroes them) and `food` (the need and the share fed).
## Planted faults: a phase that writes `turn` from Works, or `people` from the works phase, is reported.
extends GutTest

const DOOR: Array[String] = ["chronicle", "action_log"]
const ACTION_OWNERS := {
	"build": ["works", "next_work_id", "purse", "stores"],
	"upgrade": ["works", "next_work_id", "purse", "stores"],
	"clear": ["works", "next_work_id", "purse", "stores"],
	"cancel_work": ["works", "next_work_id", "purse", "stores"],
	"choose_country": ["countries", "player"],
	"set_tax": ["countries"],
}
const PHASE_OWNERS := {
	&"ai_orders": [],  # writes nothing itself: its acts go through Game.act, the mark through the door (M8 5.4)
	&"movement": ["armies", "countries", "battles"],  # the walks; explored along them (Vision.see_path, 5.0 R4); engage (M7)
	&"battles": ["armies", "battles", "wars", "occupier", "garrison", "unsupported", "people", "people_flows", "luck", "countries"],  # countries: a capture explores its taker's land (FG4, fog R9)
	&"sieges": ["sieges", "occupier", "garrison", "unsupported", "people", "people_flows", "countries"],  # countries: a capture explores (FG4, R9)
	&"war": ["wars", "occupier", "garrison", "unsupported", "owner", "armies", "countries"],  # a timer peace moves no owner (4.9); a peace explores the land it moves (FG4, R10, R17)
	&"supply": ["armies", "stores", "people", "people_flows"],  # hunger through Armies, food through Stores, foraging through People
	&"production": ["stores", "countries"],
	&"income": ["purse"],  # the upkeep_army line is Treasury's too (M6)
	&"works": ["main_use", "level", "works", "next_work_id"],
	&"people": ["people", "people_flows", "food", "main_use", "level"],
	# The End-turn leg (moves-build-spec.md R22a): the movement phase's walks, then the battles they open, fought as that phase.
	&"march_on": ["armies", "countries", "battles", "wars", "occupier", "garrison", "unsupported", "people", "people_flows", "luck"],
	&"stats": ["stats", "purse", "stores", "people_close", "people_flows"],  # People.close zeroes the open flows
	&"calendar": ["turn", "weather", "luck"],
	&"ready_units": ["armies", "people", "people_flows"],  # the refill: People.levy, then Armies.add_men
	&"vision": ["countries"],  # explored (the army part of the sight is no saved field)
}
const HOME := Vector2i(0, 2)
const FIELDS: Array[String] = ["turn", "weather", "player", "main_use", "level", "owner", "works", "next_work_id",
	"countries", "armies", "purse", "stores", "people", "people_flows", "people_close", "food", "stats", "chronicle", "luck", "action_log", "seed", "start_year", "scenario_id", "map_id",
	"wars", "battles", "sieges", "occupier", "garrison", "unsupported"]

var _fx: Dictionary = {}


func before_each() -> void:
	_fx = ScenarioFixture.build()


## Snapshot.of cut into the named fields of 5.7.
func _fields(game: Game) -> Dictionary:
	var body := Snapshot.of(game)
	var meta := body["game"] as Dictionary
	var state := body["map_state"] as Dictionary
	var countries: Array = []
	var purse: Array = []
	var stores: Array = []
	var people_flows: Array = []
	var closes: Array = [var_to_bytes([state["people_start"], state["people_end"]])]
	var food: Array = []
	for c: Dictionary in body["countries"] as Array:
		var own := c.duplicate()
		purse.append(var_to_bytes([own.get("treasury"), own.get("ledger_open"), own.get("ledger_from"), own.get("ledger_closed")]))  # bytes: a packed array in a dictionary is shared, not copied
		stores.append(var_to_bytes([own.get("stock"), own.get("flows_open"), own.get("stock_from"), own.get("goods_closed")]))
		people_flows.append(var_to_bytes(own.get("people_flows")))
		closes.append(var_to_bytes(own.get("people_closed")))
		food.append([own.get("food_need"), own.get("food_fed")])
		for key: String in ["people_flows", "people_closed", "food_need", "food_fed", "treasury", "ledger_open", "ledger_from", "ledger_closed", "stock", "flows_open", "stock_from",
				"goods_closed", "flows_shape"]:
			own.erase(key)
		countries.append(own)
	var war := body["war"] as Dictionary
	return {
		"wars": var_to_bytes([war["wars"], war["next_war_id"]]),
		"battles": var_to_bytes([war["battles"], war["battle_records"], war["next_record_id"], war["battle_names"]]),
		"sieges": var_to_bytes([war["sieges"], war["siege_names"]]),
		"occupier": state["occupier"], "garrison": state["garrison"], "unsupported": state["unsupported"],
		"weather": game.weather, "purse": purse, "stores": stores, "food": food,
		"people": var_to_bytes(state["people"]), "people_flows": people_flows, "people_close": closes,
		"turn": meta["turn"], "player": meta["player"], "main_use": state["main_use"], "level": state["level"],
		"owner": state["owner"], "works": state["works"], "next_work_id": state["next_work_id"],
		"countries": countries, "armies": body["armies"], "stats": body["stats"], "chronicle": body["chronicle"], "luck": body["luck"],
		"action_log": body["action_log"], "seed": meta["seed"], "start_year": meta["start_year"],
		"scenario_id": meta["scenario_id"], "map_id": meta["map_id"],
	}


func _changed(before: Dictionary, after: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for key: String in FIELDS:
		if var_to_bytes(before[key]) != var_to_bytes(after[key]):
			out.append(key)
	return out


## The changed fields that neither the owners nor the door may write.
func _violations(changed: Array[String], owners: Array) -> Array[String]:
	var out: Array[String] = []
	for key: String in changed:
		if not owners.has(key) and not DOOR.has(key):
			out.append(key)
	return out


func _game() -> Game:
	var g := Game.new_scenario(_fx["map"] as MapData, _fx["defs"] as GameDefs, _fx["scenario"] as ScenarioDef, 1480)
	g.improvement.clear(HOME)
	return g


func _act(g: Game, action: String, args: Dictionary) -> Array[String]:
	var before := _fields(g)
	var verdict := g.act(action, args)
	var changed := _changed(before, _fields(g))
	if bool(verdict["ok"]):
		var bad := _violations(changed, ACTION_OWNERS[action] as Array)
		assert_eq(bad, [] as Array[String], "%s wrote only its owners' fields" % action)
	else:
		assert_eq(changed, [] as Array[String], "a refused %s changes nothing: %s" % [action, verdict["reason"]])
	return changed


func _run_out(g: Game) -> void:
	var n := 0
	while not g.state.works.is_empty() and n < 40:
		Season.run(g)
		n += 1


func test_every_action_changes_only_its_owners_and_the_door() -> void:
	var g := _game()
	var changed := _act(g, "choose_country", {"tag": &"AAA"})
	assert_true(changed.has("player"))
	assert_true(changed.has("chronicle"), "the door chronicles the pick")
	var args := {"hex": HOME, "family": ImproveRules.WHEAT, "tag": &"AAA"}
	changed = _act(g, "build", args)
	assert_true(changed.has("works") and changed.has("next_work_id") and changed.has("action_log"), str(changed))
	assert_false(changed.has("main_use"), "an action writes no piece")
	assert_true(changed.has("purse"), "the work is paid through Treasury")
	changed = _act(g, "cancel_work", {"hex": HOME, "tag": &"AAA"})
	assert_true(changed.has("works") and changed.has("purse"), "and given back through it")
	_act(g, "build", args)
	_run_out(g)
	assert_eq(int(g.state.level[g.map.index_of(HOME)]), 1, "the wheat stands")
	changed = _act(g, "upgrade", {"hex": HOME, "tag": &"AAA"})
	assert_true(changed.has("works"), str(changed))
	_run_out(g)
	changed = _act(g, "clear", {"hex": HOME, "tag": &"AAA"})
	assert_true(changed.has("works"), str(changed))
	assert_false(changed.has("luck"), "no action draws luck")


func test_refused_actions_change_nothing() -> void:
	var g := _game()
	_act(g, "build", {"hex": HOME, "family": ImproveRules.WHEAT, "tag": &"AAA"})  # no country chosen yet
	_act(g, "choose_country", {"tag": &"ZZZ"})
	_act(g, "nonsense", {})


func test_every_phase_changes_only_its_owners() -> void:
	var g := _game()
	g.act("choose_country", {"tag": &"AAA"})
	g.act("build", {"hex": HOME, "family": ImproveRules.WHEAT, "tag": &"AAA"})
	var seen := {}
	for n: int in 8:
		for phase: StringName in Season.PHASES:
			var before := _fields(g)
			Season.run_phase(g, phase)
			var changed := _changed(before, _fields(g))
			assert_eq(_violations(changed, PHASE_OWNERS[phase] as Array), [] as Array[String], "phase %s" % phase)
			for key: String in changed:
				seen[key] = true
		Season.finish(g)
	for key: String in ["main_use", "level", "works", "stats", "turn", "chronicle", "countries", "people", "people_flows", "people_close"]:
		assert_true(seen.has(key), "a phase wrote " + key)
	assert_true(seen.has("purse") and seen.has("stores"), "the doors were used")
	assert_true(seen.has("luck"), "the calendar draws the weather")
	assert_false(seen.has("owner"))
	assert_false(seen.has("player"))


func test_only_the_ready_units_phase_gives_points_back() -> void:
	# MV2 (moves-build R13): an army that has spent points keeps them through every phase but ready_units, which refills.
	var g := _game()
	g.act("choose_country", {"tag": &"AAA"})
	var a := ArmyFixture.army(g, &"AAA", HOME, 0, 1)
	ArmyFixture.spent(g, a, 4)
	for phase: StringName in Season.PHASES:
		var before := a.points
		Season.run_phase(g, phase)
		if phase == &"ready_units":
			assert_eq(a.points, Allowance.full(g, a), "ready_units refills")
		else:
			assert_eq(a.points, before, "phase %s leaves the points" % phase)


func test_a_test_only_write_to_occupier_is_reported() -> void:
	# The planted fault of 5.3: a phase that writes the occupation directly is outside its owners (stats owns no occupier).
	var g := _game()
	var before := _fields(g)
	g.state.occupier[g.map.index_of(HOME)] = 1
	assert_eq(_violations(_changed(before, _fields(g)), PHASE_OWNERS[&"stats"] as Array), ["occupier"] as Array[String])


func test_season_begin_writes_only_the_door() -> void:
	var g := _game()
	var before := _fields(g)
	Season.begin(g)
	assert_eq(_changed(before, _fields(g)), ["action_log"] as Array[String])


func test_dev_transfer_changes_owner_and_the_door() -> void:
	var g := _game()
	var before := _fields(g)
	var moved: Array[Vector2i] = [ScenarioFixture.UNOWNED_HEXES[0]]
	assert_eq(g.dev_transfer(moved, 1), 1)
	var changed := _changed(before, _fields(g))
	# FG4 (fog R10): the new owner's hex and its ring are explored at once, so the countries' explored set changes too.
	assert_eq(_violations(changed, ["owner", "countries"]), [] as Array[String])
	assert_true(changed.has("owner"))
	assert_true(changed.has("countries"), "the explored set of the new owner grows at once")


func test_dev_people_writes_people_through_the_door() -> void:
	var g := _game()
	var before := _fields(g)
	var hex := Vector2i(0, 2)
	var i := g.map.index_of(hex)
	assert_true(g.dev_people(hex, int(g.state.people[i]) + 25))
	var changed := _changed(before, _fields(g))
	assert_eq(_violations(changed, ["people", "people_flows"]), [] as Array[String])
	assert_true(changed.has("people") and changed.has("people_flows") and changed.has("action_log"))
	assert_false(changed.has("people_close") or changed.has("food"))


func test_p_a_phase_that_writes_people_outside_the_people_phase_is_reported() -> void:
	var g := _game()
	var before := _fields(g)
	g.state.people[g.map.index_of(HOME)] += 1  # the planted fault: the works phase writes a person
	assert_eq(_violations(_changed(before, _fields(g)), PHASE_OWNERS[&"works"] as Array), ["people"] as Array[String])


func test_p_a_phase_that_writes_turn_from_works_is_reported() -> void:
	var g := _game()
	var before := _fields(g)
	g.turn += 1  # the planted fault: the works phase writes the calendar's field
	var bad := _violations(_changed(before, _fields(g)), PHASE_OWNERS[&"works"] as Array)
	assert_eq(bad, ["turn"] as Array[String])
	var before_state := _fields(g)
	g.state.owner[0] = 200  # and the works phase writes owner
	assert_eq(_violations(_changed(before_state, _fields(g)), PHASE_OWNERS[&"works"] as Array), ["owner"] as Array[String])


func test_p_no_phase_or_action_may_write_the_fixed_game_fields() -> void:
	var g := _game()
	for key: String in ["seed_value", "start_year"]:
		var before := _fields(g)
		g.set(key, int(g.get(key)) + 1)
		var bad := _violations(_changed(before, _fields(g)), PHASE_OWNERS[&"works"] as Array)
		assert_eq(bad, [key.trim_suffix("_value")] as Array[String], key)
	var before_scenario := _fields(g)
	g.scenario.id = "other"
	assert_eq(_violations(_changed(before_scenario, _fields(g)), ["works"]), ["scenario_id"] as Array[String])
	var before_map := _fields(g)
	g.map.id = "other_map"
	assert_eq(_violations(_changed(before_map, _fields(g)), ["works"]), ["map_id"] as Array[String])


func test_set_tax_writes_only_the_tax_and_the_door() -> void:
	var g := _game()
	g.act("choose_country", {"tag": &"AAA"})
	var before := _fields(g)
	assert_true(bool(g.act("set_tax", {"level": 2, "tag": &"AAA"})["ok"]))
	var changed := _changed(before, _fields(g))
	assert_eq(_violations(changed, ["countries"]), [] as Array[String])
	assert_true(changed.has("countries") and changed.has("action_log"))
	assert_false(changed.has("purse") or changed.has("stores"))
	before = _fields(g)
	assert_false(bool(g.act("set_tax", {"level": 2, "tag": &"AAA"})["ok"]), "already High")
	assert_eq(_changed(before, _fields(g)), [] as Array[String], "a refusal changes nothing")


func test_the_developer_transfers_write_through_the_doors() -> void:
	var g := _game()
	var before := _fields(g)
	assert_true(g.dev_money(&"AAA", 500))
	var changed := _changed(before, _fields(g))
	assert_eq(_violations(changed, ["purse"]), [] as Array[String], "dev_money: the purse and the log")
	assert_true(changed.has("purse"))
	before = _fields(g)
	assert_true(g.dev_goods(&"AAA", 12, 40))
	changed = _changed(before, _fields(g))
	assert_eq(_violations(changed, ["stores"]), [] as Array[String], "dev_goods: the stores and the log")
	assert_true(changed.has("stores"))
	assert_eq(g.action_log[g.action_log.size() - 2]["action"], "dev_money")
	assert_eq(g.action_log[g.action_log.size() - 1]["action"], "dev_goods")


# ----- M8: the ai_orders phase (m8-build-spec.md 5.4) -------------------------------------------------------------------------


## The phase's diff is its logged acts replayed on a copy taken before it: the digests agree, or the phase wrote something
## outside Game.act.
func _acts_equal_the_phase(g: Game) -> bool:
	var copy := Snapshot.restore(Snapshot.of(g), g.map, g.defs)["game"] as Game
	var from := g.action_log.size()
	Season.run_phase(g, &"ai_orders")
	for i: int in range(from, g.action_log.size()):
		var r := g.action_log[i]
		if r["action"] != "orders_done":
			copy.act(str(r["action"]), r["args"] as Dictionary)
	copy.luck.ai.set_state(g.luck.ai.get_state())  # the AI's own stream: its draws are not acts (the log cannot carry them)
	return copy.digest() == g.digest()


func test_the_ai_orders_phase_writes_only_through_game_act() -> void:
	var g := OrdersFixture.watched()
	var wrote := false
	for n: int in 3:
		Season.begin(g)
		var before := _fields(g)
		assert_true(_acts_equal_the_phase(g))
		wrote = wrote or _changed(before, _fields(g)).has("countries")
		Season.finish(g)
		for phase: StringName in Season.PHASES.slice(1):
			Season.run_phase(g, phase)
	assert_true(wrote, "the stub's acts changed something")


func test_p_a_stub_that_writes_a_treasury_directly_is_reported() -> void:
	var g := OrdersFixture.watched()
	g.orders = OrdersFixture.Cheat.new()
	Season.begin(g)
	assert_false(_acts_equal_the_phase(g), "the diff is not its logged acts")


## The real AI attached to the same sort of game: its phase writes only through Game.act.
func test_the_real_ai_phase_writes_only_through_game_act() -> void:
	var g := AiFixture.watch()
	var wrote := false
	var acts := 0
	for n: int in 6:
		Season.begin(g)
		var before := _fields(g)
		var from := g.action_log.size()
		assert_true(_acts_equal_the_phase(g))
		acts += g.action_log.size() - from - 1
		wrote = wrote or _changed(before, _fields(g)).has("countries")
		Season.finish(g)
		for phase: StringName in Season.PHASES.slice(1):
			Season.run_phase(g, phase)
	assert_true(wrote)
	assert_gt(acts, 30, "the countries acted")


## The planted fault: the real AI and then a hook that writes a treasury directly.
class AiThenCheat:
	extends OrdersHook
	var inner: AiTurn

	func begin(game: Game) -> void:
		inner.begin(game)

	func step(game: Game) -> bool:
		var done := inner.step(game)
		if done:
			game.countries[1].treasury += 5
		return done


func test_p_the_real_ai_plus_a_direct_write_is_reported() -> void:
	var g := AiFixture.watch()
	var hook := AiThenCheat.new()
	hook.inner = g.orders as AiTurn
	g.orders = hook
	Season.begin(g)
	assert_false(_acts_equal_the_phase(g), "the diff is not its logged acts")
