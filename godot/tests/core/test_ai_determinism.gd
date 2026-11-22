## Determinism (docs/architecture/m8-build-spec.md 9, done-when 4): same seed, same game. Two AI-only runs of 40 seasons give equal
## digests and logs; a season cut into slices of one step with the event queue drained between them (the shell's flow) gives the digest
## and the log of the season run at once; a snapshot at season 10, restored with the AI attached, played to season 20 equals the
## straight run. P: a seat whose decision reads game.events.size() (emptied between slices, not within a whole turn) breaks the
## slice equality, which shows the comparison can fail.
extends GutTest


## A hook whose act depends on the size of the event queue: the planted fault of a turn that reads what a slice drains.
class EventsReader:
	extends OrdersHook
	var left := 0

	func begin(_game: Game) -> void:
		left = 2

	func step(game: Game) -> bool:
		left -= 1
		game.act("set_tax", {"tag": &"GEN", "level": game.events.size() % 3})
		return left <= 0

	func seats() -> int:
		return 1


func _watched(seed_value: int = EconomyFixture.SEED) -> Game:
	return AiFixture.watch(null, seed_value)


## A season as the shell's flow plays it: begin, one step at a time with a drain after each, then each phase with a drain.
func _sliced_season(g: Game) -> void:
	assert_true(bool(Season.end_check(g)["ok"]))
	Season.begin(g)
	Season.orders_begin(g)
	g.events.clear()
	while not Season.orders_step(g):
		g.events.clear()
	g.events.clear()
	Season.orders_end(g)
	g.events.clear()
	for phase: StringName in Season.PHASES:
		if phase != &"ai_orders":
			Season.run_phase(g, phase)
			g.events.clear()
	Season.finish(g)


func test_two_runs_of_forty_seasons_are_equal() -> void:
	var a := _watched()
	var b := _watched()
	for n: int in 40:
		Season.run(a)
		Season.run(b)
		if n % 10 == 9:
			assert_eq(b.digest(), a.digest(), "season %d" % (n + 1))
	assert_eq(a.turn, 41)
	assert_eq(JSON.stringify(b.action_log), JSON.stringify(a.action_log), "the same log")
	assert_gt(a.action_log.size(), 400, "a long log")


func test_another_seed_is_another_game() -> void:
	var a := _watched(1480)
	var b := _watched(1481)
	for n: int in 6:
		Season.run(a)
		Season.run(b)
	assert_ne(b.digest(), a.digest())
	assert_ne(JSON.stringify(b.action_log), JSON.stringify(a.action_log))


func test_one_step_slices_with_a_drain_equal_whole_turns() -> void:
	var whole := _watched()
	var cut := _watched()
	for n: int in 12:
		Season.run(whole)
		_sliced_season(cut)
		assert_eq(cut.digest(), whole.digest(), "season %d" % (n + 1))
	assert_eq(JSON.stringify(cut.action_log), JSON.stringify(whole.action_log))


func test_a_snapshot_at_season_10_played_to_20_equals_the_straight_run() -> void:
	var straight := _watched()
	for n: int in 9:
		Season.run(straight)
	assert_eq(straight.turn, 10)
	var body := bytes_to_var(var_to_bytes(Snapshot.of(straight))) as Dictionary
	var back := Snapshot.restore(body, straight.map, straight.defs)["game"] as Game
	assert_not_null(back)
	assert_true(back.ai_only, "a watched game restores watched")
	AiPlayers.attach(back)
	assert_eq(back.digest(), straight.digest())
	for n: int in 10:
		Season.run(straight)
		Season.run(back)
	assert_eq(back.turn, 20)
	assert_eq(back.digest(), straight.digest())
	assert_eq(JSON.stringify(back.action_log), JSON.stringify(straight.action_log))


func test_p_a_decision_that_reads_the_event_queue_breaks_the_slice_equality() -> void:
	var whole := _watched()
	var cut := _watched()
	whole.orders = EventsReader.new()
	cut.orders = EventsReader.new()
	for n: int in 3:
		Season.run(whole)
		_sliced_season(cut)
	assert_ne(cut.digest(), whole.digest(), "the planted seat acts differently when the queue is drained between slices")
