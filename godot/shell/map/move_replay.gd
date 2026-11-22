## The movement replay (docs/architecture/m6-build-spec.md 6.4; task L15): the walks of the season that just ran (Events.unit_moved)
## are kept, and once the season flow asks, played on the map: the walking armies glide hex to hex on a ReplayPlan's clock
## (ArmyTokens.show_poses draws them; the core already holds their final hexes, so it is never changed here). It holds no
## rule: it only reads the records, and its finish, skip and cancel never touch the game. A walk the viewer cannot see at all
## is never recorded (the core sends `seen` for each hex). A new game or load cancels a replay without finishing it.
class_name MoveReplay
extends Node

## Emitted once when a started replay ends, by its clock or by skip(). Not by cancel().
signal finished

const INSTANT := &"instant"

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


func _init() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_process(false)


func _enter_tree() -> void:
	Events.unit_moved.connect(_on_unit_moved)
	Events.season_ended.connect(_on_season_ended)
	Events.battle_started.connect(_on_battle_started)
	Events.battle_joined.connect(_on_battle_joined)
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
	if Events.game_started.is_connected(cancel):
		Events.game_started.disconnect(cancel)
	if Events.game_ended.is_connected(cancel):
		Events.game_ended.disconnect(cancel)


## The map's army tokens the walkers are drawn by, and the camera's follow (a hex to glide to, or nothing).
func bind(tokens: ArmyTokens, follow: Callable) -> void:
	_tokens = tokens
	_follow = follow


## Keeps one walk of the season (an Events.unit_moved): `seen` must show at least one hex to the viewer, else nothing is kept.
func record(tag: StringName, army: int, path: Array[Vector2i], seen: PackedByteArray, ticks: PackedInt32Array) -> void:
	if path.size() < 2 or not seen.has(1):
		return
	_records.append({"tag": tag, "army": army, "path": path.duplicate(), "seen": seen.duplicate(),
		"ticks": ticks.duplicate()})


## Starts the replay of the season that just ended at `speed` (&"normal" or &"slow"). False when `speed` is instant (the
## walks are dropped), when nothing was seen, when a replay already runs or when nothing would show. True: the clock runs.
func start(speed: StringName) -> bool:
	var walks := _pending
	var battles := _pending_battles
	_pending = []
	_pending_battles = []
	if speed == INSTANT or walks.is_empty() or _plan != null:
		return false
	var plan := ReplayPlan.new()
	for b: Dictionary in ReplayMarks.battles(walks, battles, Session.game, Session.player_tag()):
		plan.record_battle(b["hex"] as Vector2i, int(b["tick"]), bool(b["shown"]))
	plan.setup(walks, speed)
	if plan.duration() <= 0.0:
		return false
	_plan = plan
	_lead_from = Vector2i(-1, -1)
	set_process(true)
	_show()
	return true


## Ends the replay now: every walker is put where the core has it, and `finished` is emitted once. False with none running.
func skip() -> bool:
	if _plan == null:
		return false
	_plan.skip()
	_end(true)
	return true


## Whether a replay is running (the clock is on; input waits for it).
func active() -> bool:
	return _plan != null


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


## Drops the replay and the walks kept: a new game or a load. `finished` is not emitted.
func cancel() -> void:
	_records = []
	_pending = []
	_battle_events = []
	_pending_battles = []
	if _plan != null:
		_plan = null
		set_process(false)
		_set_poses([])


func _process(delta: float) -> void:
	if _plan == null:
		return
	_plan.advance(delta)
	_show()
	if _plan.finished():
		_end(true)


func _on_unit_moved(tag: StringName, army: int, path: Array[Vector2i], seen: PackedByteArray,
		ticks: PackedInt32Array) -> void:
	record(tag, army, path, seen, ticks)


## The season's walks are complete: they become the ones start() plays (a run of seasons plays its last one).
func _on_season_ended(_turn: int) -> void:
	_pending = []
	_pending.assign(_records)
	_records = []
	_pending_battles = _battle_events
	_battle_events = []


## A battle began at `hex` (the attacker's walk ends there): its tick is found from the walks at start().
func _on_battle_started(hex: Vector2i, attacker: StringName, _defender: StringName) -> void:
	_battle_events.append({"hex": hex, "tag": attacker})


func _on_battle_joined(hex: Vector2i, tag: StringName) -> void:
	_battle_events.append({"hex": hex, "tag": tag})


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
	_plan = null
	set_process(false)
	_set_poses([])
	if emit:
		finished.emit()


func _set_poses(poses: Array[Dictionary]) -> void:
	if _tokens != null and is_instance_valid(_tokens):
		_tokens.show_poses(poses)
