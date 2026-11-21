## GUT tests for StudyWarm (docs/architecture/m4-5-build-spec.md 6.8 and 4.12): the queue of read-only view calls made after a
## season ends, one run a frame, cleared by a newer game version, filled again by the next season or game; it leaves the game
## as it found it.
extends GutTest

const GEN := &"GEN"
const VIEWS := 9  # this_season, districts, goods, history, rankings, timeline, chronicle, people, military (M6)

var _prev_game: Game = null
var _game: Game = null
var _warm: StudyWarm = null
var _settings: Settings = null


func before_each() -> void:
	_prev_game = Session.game
	_game = InsightsFixture.genoa_1483()
	Session.start_game(_game)
	_settings = Settings.new("macOS", true)
	_warm = StudyWarm.new()
	_warm.setup(_settings)
	add_child_autofree(_warm)


func after_each() -> void:
	_warm = null
	Session.game = _prev_game


func _cached(key: Array) -> bool:
	var marker := "not cached"
	return _game.view_cache.get_or_make(key, func() -> String: return marker) is not String


func test_queue_views_lists_the_views_and_yields_only_while_the_map_is_in_yields() -> void:
	assert_eq(_warm.pending(), 0, "nothing queued before a season ends")
	_warm.queue_views()
	assert_eq(_warm.pending(), VIEWS)
	_warm.yields_active = func() -> bool: return true
	_warm.queue_views()
	assert_eq(_warm.pending(), VIEWS + 1, "the Yields bytes too while the map is in Yields")
	_warm.yields_active = Callable()
	_warm.food_active = func() -> bool: return true
	_warm.queue_views()
	assert_eq(_warm.pending(), VIEWS + 1, "the Food bytes too while the map is in Food")
	_warm.yields_active = func() -> bool: return true
	_warm.queue_views()
	assert_eq(_warm.pending(), VIEWS + 2, "both when both are asked for")
	_warm.yields_active = Callable()
	_warm.food_active = Callable()
	_warm.supply_active = func() -> bool: return true
	_warm.queue_views()
	assert_eq(_warm.pending(), VIEWS + 1, "the Supply bytes too while the map is in Supply (M6)")
	_warm.supply_active = Callable()


func test_warm_now_fills_the_view_cache_keys_the_pages_read() -> void:
	var span := 12
	var keys: Array = [
		[&"study_districts", _game.version, GEN],
		[&"study_goods", _game.version, GEN, span],
		[&"study_history", _game.version, GEN, span],
		[&"study_people", _game.version, GEN, span],
	]
	for key: Array in keys:
		assert_false(_cached(key), "cold: %s" % str(key))
	_game.view_cache.clear()
	_warm.queue_views()
	_warm.warm_now()
	assert_eq(_warm.pending(), 0)
	for key: Array in keys:
		assert_true(_cached(key), "warm: %s" % str(key))


func test_the_span_is_read_from_the_setting() -> void:
	_settings.set_value("state/study_span", 40)
	_game.view_cache.clear()
	_warm.queue_views()
	_warm.warm_now()
	assert_true(_cached([&"study_goods", _game.version, GEN, 40]), "goods for 40 seasons")
	assert_false(_cached([&"study_goods", _game.version, GEN, 12]), "and not for 12")


func test_one_view_runs_a_frame() -> void:
	_warm.queue_views()
	var left := _warm.pending()
	for _i: int in 3:
		await get_tree().process_frame
		assert_eq(_warm.pending(), left - 1, "one view a frame")
		left -= 1
	while _warm.pending() > 0:
		await get_tree().process_frame
	assert_eq(_warm.pending(), 0)


func test_a_newer_game_version_clears_the_queue() -> void:
	_warm.queue_views()
	assert_eq(_warm.pending(), VIEWS)
	var verdict := _game.act("set_tax", {"level": 2, "tag": GEN})
	assert_true(bool(verdict["ok"]), str(verdict))
	assert_eq(_warm.pending(), 0, "the views of the old version are not worth running")
	_warm.warm_now()  # nothing to run
	_warm.queue_views()
	assert_eq(_warm.pending(), VIEWS, "and the next queue is for the new version")


func test_a_season_ended_and_a_new_game_queue_the_views_once_the_signals_are_done() -> void:
	Events.season_ended.emit(_game.turn)
	assert_eq(_warm.pending(), 0, "queued at the end of the frame")
	await get_tree().process_frame
	assert_gte(_warm.pending(), VIEWS - 1, "the season's views are queued (one may have run)")
	while _warm.pending() > 0:
		await get_tree().process_frame
	Events.game_started.emit()
	await get_tree().process_frame
	assert_gte(_warm.pending(), VIEWS - 1, "a started game queues them too")


func test_no_country_and_no_pick_queue_nothing() -> void:
	Session.new_game(MapScene.MAP_ID, 1480)
	_warm.queue_views()
	assert_eq(_warm.pending(), 0, "the sandbox has no study")
	Session.new_scenario("north_italy_1480", 1480)
	_warm.queue_views()
	assert_eq(_warm.pending(), 0, "no player yet: nothing to warm")
	Session.game = null
	_warm.queue_views()
	assert_eq(_warm.pending(), 0)


func test_warming_leaves_the_game_as_it_was() -> void:
	var digest := _game.digest()
	var version := _game.version
	var bytes := var_to_bytes(Snapshot.of(_game))
	_warm.yields_active = func() -> bool: return true
	_warm.food_active = func() -> bool: return true
	_warm.queue_views()
	_warm.warm_now()
	assert_eq(_game.digest(), digest)
	assert_eq(_game.version, version)
	assert_eq(var_to_bytes(Snapshot.of(_game)), bytes, "the snapshot is the same bytes")


## The warmer never keeps a finished game (and its view cache) alive: after the game ends and two frames, nothing holds it.
func test_a_finished_game_is_not_kept_alive() -> void:
	_warm.queue_views()
	assert_gt(_warm.pending(), 0)
	var ref: WeakRef = weakref(_game)
	_game = null
	Session.end_game()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(_warm.pending(), 0, "the queue is gone")
	assert_null(ref.get_ref(), "nothing holds the finished game")


func test_the_food_bytes_are_warm_after_warming_in_food_mode() -> void:
	_game.view_cache.clear()
	_warm.food_active = func() -> bool: return true
	_warm.queue_views()
	_warm.warm_now()
	var made := 0
	var key: Array = [&"food", _game.version, GEN]
	var bytes := _game.view_cache.get_or_make(key, func() -> PackedByteArray:
		made += 1
		return PackedByteArray()) as PackedByteArray
	assert_eq(made, 0, "the Food bytes were already in the view cache")
	assert_eq(bytes.size(), _game.map.hex_count())
