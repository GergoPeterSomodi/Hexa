## The movement replay (docs/architecture/m6-build-spec.md 6.4; task L15): the walks of the season that just ended (Events.unit_moved)
## are kept, and once the season flow asks, played on the map: the walking armies glide hex to hex on a ReplayPlan's clock
## (ArmyTokens.show_poses draws them; the core already holds their final hexes, so it is never changed here). It holds no
## rule: it only reads the records, and its finish, skip and cancel never touch the game. A walk the viewer cannot see at all
## is never recorded (the core sends `seen` for each hex). A new game or load cancels a replay without finishing it.
## Two modes (moves-build-spec.md R49, R50). The season replay: the walks that arrive while a season runs are played after it,
## the at-once walks of the computer one after another (ReplayPlan.chain) and then the phase's together. The live walk: the
## walks (and battle events) that arrive while no season runs are the player's own act; they are one batch, played from the
## next frame on their own plan at the movement speed (instant plays nothing) and ended by their clock or skip_live(); an army
## order given from a panel while one plays (army_changed, army_disbanded) ends it too. The game already holds the end of a live
## walk; the player's live walks are never in the season replay.
class_name MoveReplay
extends Node

## Emitted once when a started replay ends, by its clock or by skip(). Not by cancel().
signal finished
## Emitted once when a live walk ends, by its clock or by skip_live(): the record id of the battle of the batch, -1 for none.
## Not by cancel(), and not for a walk that was never played (instant, reduce motion).
signal live_finished(record: int)

const INSTANT := &"instant"
## The group the map's war marks find the replay by (MapWars reads marks() while it runs; M7 6.3).
const GROUP := &"move_replay"

## The walks of the season that is running (filled by unit_moved, moved to _pending at season_ended).
var _records: Array[Dictionary] = []
## The walks of the season that just ended: what start() plays.
var _pending: Array[Dictionary] = []
var _plan: ReplayPlan = null
var _tokens: ArmyTokens = null
## (hex) -> void: asked when the lead walker steps somewhere the camera should follow (the game requests' glide).
var _follow: Callable = Callable()
var _lead_from := Vector2i(-1, -1)
## The battles heard this season ({hex, tag}: battle_started's attacker, battle_joined's joiner); moved to _pending_battles
## at season_ended and matched to the walks in start() (ReplayMarks).
var _battle_events: Array[Dictionary] = []
var _pending_battles: Array[Dictionary] = []
## The hexes of the battles of the running replay (set at start, cleared at its end): their site badges wait (M7 B25).
var _battle_hexes: Array[Vector2i] = []
## () -> StringName, set by GameRequests: the speed a live walk plays at (instant under reduce motion). Unset: normal.
var live_speed: Callable = Callable()
## The live batch (an act's walks and battle events, kept while no season runs) and its battle record; played from the next frame.
var _live: Array[Dictionary] = []
var _live_battles: Array[Dictionary] = []
var _live_record := -1
var _live_pending := false
## The process frame the newest live battle event was heard in: one that no walk claimed by the next frame is dropped.
var _live_battle_frame := -1
## True while the running plan is a live walk's; the battle record it reports when it ends.
var _live_mode := false
var _live_run := -1


func _init() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_process(false)


func _enter_tree() -> void:
	add_to_group(GROUP)
	Events.unit_moved.connect(_on_unit_moved)
	Events.season_ended.connect(_on_season_ended)
	Events.battle_started.connect(_on_battle_started)
	Events.battle_joined.connect(_on_battle_joined)
	Events.battle_ended.connect(_on_battle_ended)
	Events.army_changed.connect(_on_army_changed)
	Events.army_disbanded.connect(_on_army_disbanded)
	Events.game_started.connect(cancel)
	Events.game_ended.connect(cancel)


func _exit_tree() -> void:
	if Events.unit_moved.is_connected(_on_unit_moved):
		Events.unit_moved.disconnect(_on_unit_moved)
	if Events.season_ended.is_connected(_on_season_ended):
		Events.season_ended.disconnect(_on_season_ended)
	if Events.battle_started.is_connected(_on_battle_started):
		Events.battle_started.disconnect(_on_battle_started)
	if Events.battle_joined.is_connected(_on_battle_joined):
		Events.battle_joined.disconnect(_on_battle_joined)
	if Events.battle_ended.is_connected(_on_battle_ended):
		Events.battle_ended.disconnect(_on_battle_ended)
	if Events.army_changed.is_connected(_on_army_changed):
		Events.army_changed.disconnect(_on_army_changed)
	if Events.army_disbanded.is_connected(_on_army_disbanded):
		Events.army_disbanded.disconnect(_on_army_disbanded)
	if Events.game_started.is_connected(cancel):
		Events.game_started.disconnect(cancel)
	if Events.game_ended.is_connected(cancel):
		Events.game_ended.disconnect(cancel)


## The map's army tokens the walkers are drawn by, and the camera's follow (a hex to glide to, or nothing).
func bind(tokens: ArmyTokens, follow: Callable) -> void:
	_tokens = tokens
	_follow = follow


## Keeps one walk of the season (an Events.unit_moved): `seen` must show at least one hex to the viewer, else nothing is kept.
## `now` is the event's flag: an at-once walk (the computer's order) is laid after the walks before it (ReplayPlan.chain).
func record(tag: StringName, army: int, path: Array[Vector2i], seen: PackedByteArray, ticks: PackedInt32Array,
		now: bool = false) -> void:
	if path.size() < 2 or not seen.has(1):
		return
	_records.append(_walk(tag, army, path, seen, ticks, now))


static func _walk(tag: StringName, army: int, path: Array[Vector2i], seen: PackedByteArray, ticks: PackedInt32Array,
		now: bool) -> Dictionary:
	return {"tag": tag, "army": army, "path": path.duplicate(), "seen": seen.duplicate(), "ticks": ticks.duplicate(),
		"now": now}


## Starts the replay of the season that just ended at `speed` (&"normal" or &"slow"). `focus` is the hexes in view (D37):
## a seen step with neither hex in it is instant; the default (no area) times every seen step. False when `speed` is instant
## (the walks are dropped), when nothing was seen, when a replay already runs or when nothing would show. True: the clock runs.
func start(speed: StringName, focus: Rect2i = Rect2i()) -> bool:
	var walks := _pending
	var battles := _pending_battles
	_pending = []
	_pending_battles = []
	if speed == INSTANT or walks.is_empty() or _plan != null:
		return false
	var plan := _make_plan(walks, battles, speed, focus)
	if plan == null:
		return false
	_plan = plan
	_live_mode = false
	_lead_from = Vector2i(-1, -1)
	set_process(true)
	_show()
	return true


## The plan of some walks: chained (R50), the battle marks of the walks they end on, laid at `speed`. Null when it shows
## nothing. Sets _battle_hexes for the plan it returns.
func _make_plan(walks: Array[Dictionary], battles: Array[Dictionary], speed: StringName, focus: Rect2i) -> ReplayPlan:
	var chained := ReplayPlan.chain(walks)
	var plan := ReplayPlan.new()
	plan.set_focus(focus)
	var hexes: Array[Vector2i] = []
	for b: Dictionary in ReplayMarks.battles(chained, battles, Session.game, Session.player_tag()):
		plan.record_battle(b["hex"] as Vector2i, int(b["tick"]), bool(b["shown"]))
		hexes.append(b["hex"] as Vector2i)
	plan.setup(chained, speed)
	if plan.duration() <= 0.0:
		return null
	_battle_hexes = hexes
	return plan


## Ends the replay now: every walker is put where the core has it, and `finished` is emitted once. False with none running.
## A live walk is not a season replay: skip_live() ends that.
func skip() -> bool:
	if _plan == null or _live_mode:
		return false
	_plan.skip()
	_end(true)
	return true


## Whether a season replay is running (the clock is on; orders wait for it). A live walk is not one: it never refuses an order.
func active() -> bool:
	return _plan != null and not _live_mode


## Whether a live walk is waiting for its first frame or running.
func live_active() -> bool:
	return _live_pending or (_plan != null and _live_mode)


## Ends a live walk now (R49): the walkers are put where the core has them and `live_finished` is emitted once; a batch that has
## not begun yet is dropped the same way. False with none.
func skip_live() -> bool:
	if _plan != null and _live_mode:
		_plan.skip()
		_end(true)
		return true
	if _live_pending:
		var record := _live_record
		_clear_live()
		_idle()
		live_finished.emit(record)
		return true
	return false


## The hexes of the battles of the running replay, from its start: a battle's site badge is held until it ends (M7 B25).
func battle_hexes() -> Array[Vector2i]:
	return _battle_hexes.duplicate()


## The walkers of the running replay (ReplayPlan.poses); none with no replay.
func poses() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _plan != null:
		out = _plan.poses()
	return out


## The battle marks of the running replay (ReplayPlan.marks): {hex, shown} for each battle whose tick has begun; none without a
## replay. The map draws the shown ones (M7 6.5's badge; the draw is not in MoveReplay).
func marks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _plan != null:
		out = _plan.marks()
	return out


## Drops the replay and the walks kept: a new game or a load. Neither `finished` nor `live_finished` is emitted.
func cancel() -> void:
	_records = []
	_pending = []
	_battle_events = []
	_pending_battles = []
	_clear_live()
	if _plan != null:
		_plan = null
		_live_mode = false
		_live_run = -1
		_battle_hexes = []
		_set_poses([])
	_idle()


func _process(delta: float) -> void:
	if _plan == null:
		if _live_pending:
			_begin_live()
		elif not _live_battles.is_empty() and Engine.get_process_frames() > _live_battle_frame:
			_live_battles = []  # a fight that came with no walk of the player's
		_idle()
		return
	_plan.advance(SimClock.delta(delta))
	_show()
	if _plan.finished():
		_end(true)


func _on_unit_moved(tag: StringName, army: int, path: Array[Vector2i], seen: PackedByteArray,
		ticks: PackedInt32Array, now: bool) -> void:
	if Session.in_season():
		record(tag, army, path, seen, ticks, now)
	else:
		_record_live(tag, army, path, seen, ticks)


## A walk of an act (no season runs): kept in the live batch, which plays from the next frame. A walk that shows nothing, and
## every walk at the instant speed, is not kept (the tokens are where the game has them). A walk still playing from an earlier
## act lands first.
func _record_live(tag: StringName, army: int, path: Array[Vector2i], seen: PackedByteArray, ticks: PackedInt32Array) -> void:
	if path.size() < 2 or not seen.has(1) or _live_speed() == INSTANT:
		return
	if _plan != null and _live_mode:
		skip_live()
	_live.append(_walk(tag, army, path, seen, ticks, true))
	_live_pending = true
	set_process(true)


## The season's walks are complete: they become the ones start() plays (a run of seasons plays its last one).
func _on_season_ended(_turn: int) -> void:
	_pending = []
	_pending.assign(_records)
	_records = []
	_pending_battles = _battle_events
	_battle_events = []


## A battle began at `hex` (the attacker's walk ends there): its tick is found from the walks at start().
func _on_battle_started(hex: Vector2i, attacker: StringName, _defender: StringName) -> void:
	_hear(hex, attacker)


func _on_battle_joined(hex: Vector2i, tag: StringName) -> void:
	_hear(hex, tag)


## A battle event goes to the season's list while a season runs, else to the live batch (it can come before its walk's event).
func _hear(hex: Vector2i, tag: StringName) -> void:
	if Session.in_season():
		_battle_events.append({"hex": hex, "tag": tag})
		return
	if _live_speed() == INSTANT:
		return
	_live_battles.append({"hex": hex, "tag": tag})
	_live_battle_frame = Engine.get_process_frames()
	set_process(true)


## A battle of the live batch ended: its record is what live_finished reports.
func _on_battle_ended(_hex: Vector2i, record: int, _winner: StringName) -> void:
	if _live_pending and not Session.in_season():
		_live_record = record


## An act on an army while a live walk plays (an order from a panel, which no key or map click came before): the walk lands. The
## walk's own act sends these in the same drain as its walk, before the plan begins, so a waiting batch is left alone.
func _on_army_changed(_tag: StringName, _army: int) -> void:
	_skip_running_live()


func _on_army_disbanded(_tag: StringName, _hex: Vector2i, _army: int) -> void:
	_skip_running_live()


func _skip_running_live() -> void:
	if _plan != null and _live_mode and not Session.in_season():
		skip_live()


## Plays the live batch on its own plan; one that shows nothing ends at once.
func _begin_live() -> void:
	var walks := _live
	var battles := _live_battles
	var record := _live_record
	_clear_live()
	var plan := _make_plan(walks, battles, _live_speed(), Rect2i())
	if plan == null:
		live_finished.emit(record)
		return
	_plan = plan
	_live_mode = true
	_live_run = record
	_lead_from = Vector2i(-1, -1)
	_show()


func _live_speed() -> StringName:
	return StringName(live_speed.call()) if live_speed.is_valid() else &"normal"


func _clear_live() -> void:
	_live = []
	_live_battles = []
	_live_record = -1
	_live_pending = false


## The clock is needed only while a plan runs, a live batch waits or a live battle event waits to be claimed.
func _idle() -> void:
	set_process(_plan != null or _live_pending or not _live_battles.is_empty())


## Puts the walkers on the map and asks the camera to follow the first shown walker's step when it has changed.
func _show() -> void:
	var poses := _plan.poses()
	_set_poses(poses)
	var lead := _first_shown(poses)
	if lead.is_empty():
		return
	# A shown pose stands on its `to` hex, which the viewer sees (ReplayPlan's strict fog): only that hex is followed.
	var at := lead["to"] as Vector2i
	if at != _lead_from:
		_lead_from = at
		if _follow.is_valid():
			_follow.call(at)


static func _first_shown(poses: Array[Dictionary]) -> Dictionary:
	for pose: Dictionary in poses:
		if bool(pose["shown"]):
			return pose
	return {}


func _end(emit: bool) -> void:
	var live := _live_mode
	var record := _live_run
	_plan = null
	_live_mode = false
	_live_run = -1
	_battle_hexes = []
	_idle()
	_set_poses([])
	if emit:
		if live:
			live_finished.emit(record)
		else:
			finished.emit()


func _set_poses(poses: Array[Dictionary]) -> void:
	if _tokens != null and is_instance_valid(_tokens):
		_tokens.show_poses(poses)
