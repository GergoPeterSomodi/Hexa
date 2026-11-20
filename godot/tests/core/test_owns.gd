## Who writes what (docs/architecture/m3-build-spec.md 5.7, 9): the snapshot before and after every action and every
## phase differs only in the owners' fields and the door's (chronicle and action_log; events, version and view_cache are
## not saved). Planted fault: a phase that writes `turn` from Works is reported.
extends GutTest

const DOOR: Array[String] = ["chronicle", "action_log"]
const ACTION_OWNERS := {
	"build": ["works", "next_work_id"],
	"upgrade": ["works", "next_work_id"],
	"clear": ["works", "next_work_id"],
	"cancel_work": ["works", "next_work_id"],
	"choose_country": ["countries", "player"],
}
const PHASE_OWNERS := {
	&"works": ["main_use", "level", "works", "next_work_id"],
	&"stats": ["stats"],
	&"calendar": ["turn"],
}
const HOME := Vector2i(0, 2)
const FIELDS: Array[String] = ["turn", "player", "main_use", "level", "owner", "works", "next_work_id", "countries",
	"stats", "chronicle", "luck", "action_log", "seed", "start_year", "scenario_id", "map_id"]

var _fx: Dictionary = {}


func before_each() -> void:
	_fx = ScenarioFixture.build()


## Snapshot.of cut into the named fields of 5.7.
func _fields(game: Game) -> Dictionary:
	var body := Snapshot.of(game)
	var meta := body["game"] as Dictionary
	var state := body["map_state"] as Dictionary
	return {
		"turn": meta["turn"], "player": meta["player"], "main_use": state["main_use"], "level": state["level"],
		"owner": state["owner"], "works": state["works"], "next_work_id": state["next_work_id"],
		"countries": body["countries"], "stats": body["stats"], "chronicle": body["chronicle"], "luck": body["luck"],
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
	changed = _act(g, "cancel_work", {"hex": HOME, "tag": &"AAA"})
	assert_true(changed.has("works"))
	_act(g, "build", args)
	_run_out(g)
	assert_eq(int(g.state.level[g.map.index_of(HOME)]), 1, "the wheat stands")
	changed = _act(g, "upgrade", {"hex": HOME, "tag": &"AAA"})
	assert_true(changed.has("works"), str(changed))
	_run_out(g)
	changed = _act(g, "clear", {"hex": HOME, "tag": &"AAA"})
	assert_true(changed.has("works"), str(changed))
	assert_false(changed.has("luck"), "no action draws luck in M3")


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
	for key: String in ["main_use", "level", "works", "stats", "turn", "chronicle"]:
		assert_true(seen.has(key), "a phase wrote " + key)
	assert_false(seen.has("luck"), "no phase draws luck in M3")
	assert_false(seen.has("owner"))
	assert_false(seen.has("countries"))
	assert_false(seen.has("player"))


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
	assert_eq(_violations(changed, ["owner"]), [] as Array[String])
	assert_true(changed.has("owner"))


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
