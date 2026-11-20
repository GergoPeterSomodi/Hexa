## Works: a build, an upgrade or a clearing takes seasons (docs/architecture/m3-build-spec.md 4.3, 5.3).
## The actions begin a work; the works phase (`season`) counts it down, halts it in a snow winter and, when it is done,
## puts the piece through Improve. Writes `state.works` and `state.next_work_id` and nothing else.
class_name Works
extends RefCounted

const OWNS: Array[String] = ["works", "next_work_id"]
const BUILD := &"build"
const UPGRADE := &"upgrade"
const CLEAR := &"clear"
## The longest a ready date is searched for (seasons); a work never takes anywhere near it.
const HORIZON := 1024


# ----- the checks ------------------------------------------------------------------------------------------------


static func build_check(game: Game, args: Dictionary) -> Dictionary:
	var hex: Variant = args.get("hex", null)
	if typeof(hex) != TYPE_VECTOR2I:
		return _refusal("no hex given")
	if typeof(args.get("family", null)) != TYPE_INT:
		return _refusal("no piece given")
	return _begin_check(game, BUILD, hex as Vector2i, _tag_of(args), int(args["family"]), args)


static func upgrade_check(game: Game, args: Dictionary) -> Dictionary:
	var hex: Variant = args.get("hex", null)
	if typeof(hex) != TYPE_VECTOR2I:
		return _refusal("no hex given")
	return _begin_check(game, UPGRADE, hex as Vector2i, _tag_of(args), 0, args)


static func clear_check(game: Game, args: Dictionary) -> Dictionary:
	var hex: Variant = args.get("hex", null)
	if typeof(hex) != TYPE_VECTOR2I:
		return _refusal("no hex given")
	return _begin_check(game, CLEAR, hex as Vector2i, _tag_of(args), 0, args)


## Rows 2 to 8 of the check table (4.3); `args` is passed on to Improve's own check (row 5).
static func _begin_check(game: Game, action: StringName, hex: Vector2i, tag: StringName, family: int,
		args: Dictionary) -> Dictionary:
	if game.defs == null:
		return _refusal("no work data: this game has no definitions")
	var home := Territory.at_home_check(game, tag, hex)
	if not bool(home["ok"]):
		return home
	var under_way := game.state.work_at(hex)
	if under_way != null:
		return _refusal("a work is under way here: %s, ready %s" % [
			_label(under_way), Calendar.date_text(ready_turn(game, under_way), game.start_year)])
	var piece: Dictionary
	match action:
		BUILD:
			piece = Improve.build_check(game, args)
		UPGRADE:
			piece = Improve.upgrade_check(game, args)
		_:
			piece = Improve.clear_check(game, args)
	if not bool(piece["ok"]):
		return piece
	var target_family := 0
	var target_level := 0
	if action == BUILD:
		target_family = family
		target_level = 1
	elif action == UPGRADE:
		var i := game.map.index_of(hex)
		target_family = int(game.state.main_use[i])
		target_level = int(game.state.level[i]) + 1
	var clash := pending_conflict(game, hex, target_family, target_level)
	if clash != "":
		return _refusal(clash)
	if game.has_countries():
		var total := slots(game, tag)
		if total >= 0 and in_use(game, tag) >= total:
			return _refusal("no free work slot: %d of %d in use" % [in_use(game, tag), total])
	return {"ok": true, "reason": ""}


static func cancel_work_check(game: Game, args: Dictionary) -> Dictionary:
	var hex: Variant = args.get("hex", null)
	if typeof(hex) != TYPE_VECTOR2I:
		return _refusal("no hex given")
	var work := game.state.work_at(hex as Vector2i)
	if work == null:
		return _refusal("no work is under way here")
	if work.tag != _tag_of(args):
		return _refusal("not your work: the %s ordered it" % _long_name(game, work.tag))
	return {"ok": true, "reason": ""}


# ----- the actions -----------------------------------------------------------------------------------------------


static func build(game: Game, args: Dictionary) -> Dictionary:
	var verdict := build_check(game, args)
	if bool(verdict["ok"]):
		_begin(game, BUILD, args["hex"] as Vector2i, _tag_of(args), int(args["family"]), 1)
	return verdict


static func upgrade(game: Game, args: Dictionary) -> Dictionary:
	var verdict := upgrade_check(game, args)
	if bool(verdict["ok"]):
		var hex: Vector2i = args["hex"]
		var i := game.map.index_of(hex)
		_begin(game, UPGRADE, hex, _tag_of(args), int(game.state.main_use[i]), int(game.state.level[i]) + 1)
	return verdict


static func clear(game: Game, args: Dictionary) -> Dictionary:
	var verdict := clear_check(game, args)
	if bool(verdict["ok"]):
		var hex: Vector2i = args["hex"]
		_begin(game, CLEAR, hex, _tag_of(args), int(game.state.main_use[game.map.index_of(hex)]), 0)
	return verdict


## Appends the work (id next_work_id) and emits work_started. Nothing on the map changes.
static func _begin(game: Game, action: StringName, hex: Vector2i, tag: StringName, family: int, level_to: int) -> void:
	var work := Work.new()
	work.id = game.state.next_work_id
	game.state.next_work_id += 1
	work.tag = tag
	work.hex = hex
	work.action = action
	work.family = family
	work.level_to = level_to
	work.started_turn = game.turn
	work.seasons = seasons_for(game, action, family, level_to)
	work.seasons_left = work.seasons
	work.paid = 0
	game.state.works.append(work)
	game.emit({"kind": "work_started", "tag": tag, "hex": hex, "work": work.to_dict()})


## Ends the work under way on the hex by order; emits work_cancelled (why order, refund).
static func cancel_work(game: Game, args: Dictionary) -> Dictionary:
	var verdict := cancel_work_check(game, args)
	if bool(verdict["ok"]):
		var work := game.state.work_at(args["hex"] as Vector2i)
		game.state.works.erase(work)
		# M4: Treasury.move(game, work.tag, refund(game, work), &"refund", work.hex) goes here.
		_cancelled(game, work, &"order", "")
	return verdict


# ----- the phase -------------------------------------------------------------------------------------------------


## The works phase (4.3): every work in id order is lost, halted or advanced; a finished one puts its piece.
static func season(game: Game) -> void:
	var under_way: Array[Work] = game.state.works.duplicate()
	for work: Work in under_way:
		if game.has_countries():
			var home := Territory.at_home_check(game, work.tag, work.hex)
			if not bool(home["ok"]):
				game.state.works.erase(work)
				_cancelled(game, work, &"lost", str(home["reason"]))
				continue
		if halted(game, work, game.turn):
			continue
		work.seasons_left -= 1
		if work.seasons_left > 0:
			continue
		var put := _put_piece(game, work)
		game.state.works.erase(work)
		if bool(put["ok"]):
			game.emit({"kind": "work_finished", "tag": work.tag, "hex": work.hex, "work": work.to_dict()})
		else:
			_cancelled(game, work, &"blocked", str(put["reason"]))


static func _put_piece(game: Game, work: Work) -> Dictionary:
	var args := {"hex": work.hex, "tag": work.tag}
	match work.action:
		BUILD:
			args["family"] = work.family
			return Improve.build(game, args)
		UPGRADE:
			return Improve.upgrade(game, args)
	return Improve.clear(game, args)


static func _cancelled(game: Game, work: Work, why: StringName, reason: String) -> void:
	game.emit({"kind": "work_cancelled", "tag": work.tag, "hex": work.hex, "work": work.to_dict(), "why": why,
		"reason": reason, "refund": refund(game, work)})


# ----- facts -----------------------------------------------------------------------------------------------------


## Seasons a work takes: FamilyDef.work_seasons[level_to], or clear_seasons for a clearing. 1 for an unknown family.
static func seasons_for(game: Game, action: StringName, family: int, level_to: int) -> int:
	var def: FamilyDef = game.defs.family(family) if game.defs != null else null
	if def == null:
		return 1
	if action == CLEAR:
		return def.clear_seasons
	if level_to < 1 or level_to >= def.work_seasons.size():
		return 1
	return def.work_seasons[level_to]


## Work slots of a country: defs.work_slots_base plus its settlements of level work_slots_city_level or more.
## -1 (no limit) in a game without countries or definitions.
static func slots(game: Game, tag: StringName) -> int:
	if game.defs == null or not game.has_countries():
		return -1
	var total := game.defs.work_slots_base
	var c := Countries.by_tag(game, tag)
	if c == null:
		return total
	for i: int in Territory.districts(game, c.id):
		if int(game.state.main_use[i]) == ImproveRules.SETTLEMENT \
				and int(game.state.level[i]) >= game.defs.work_slots_city_level:
			total += 1
	return total


## Works of `tag` under way.
static func in_use(game: Game, tag: StringName) -> int:
	var n := 0
	for w: Work in game.state.works:
		if w.tag == tag:
			n += 1
	return n


## The winter rule: the season `turn` is Winter, the hex's climate is snow, and the rule is on.
static func halted(game: Game, work: Work, turn: int) -> bool:
	if game.defs == null or not game.defs.works_halt_in_snow_winter or not Calendar.is_winter(turn):
		return false
	var i := game.map.index_of(work.hex)
	return i >= 0 and int(game.map.climate[i]) == 0


## "" or the words of the first pair rule the target (family, level_value) breaks against a work under way within two
## hexes of `hex` (other than the work on `hex`). A clear work has no target and never clashes.
static func pending_conflict(game: Game, hex: Vector2i, family: int, level_value: int) -> String:
	if family <= 0:
		return ""
	for w: Work in game.state.works:
		if w.hex == hex or w.action == CLEAR:
			continue
		var distance := ImproveRules.hex_distance(hex, w.hex)
		if distance < 1 or distance > 2:
			continue
		var why := ImproveRules.pair_reason(family, level_value, w.family, w.level_to, distance)
		if why != "":
			return "a work under way at (%d, %d) would break it: %s" % [w.hex.x, w.hex.y, why]
	return ""


## What a cancelled work gives back: its payment when cancelled in the season it began, else 0 (always 0 until M4).
static func refund(game: Game, work: Work) -> int:
	return work.paid if work.started_turn == game.turn else 0


## The season from which the work stands: walks the seasons from game.turn, skipping the halted ones.
static func ready_turn(game: Game, work: Work) -> int:
	var left := work.seasons_left
	var t := game.turn
	for n: int in HORIZON:
		if not halted(game, work, t):
			left -= 1
			if left <= 0:
				return t + 1
		t += 1
	return t


# ----- words -----------------------------------------------------------------------------------------------------


## "vineyard, first stage"; "walled town to city"; "vineyard, first to second stage"; "clearing the vineyard".
static func _label(work: Work) -> String:
	var piece := FamilyIds.NAMES[clampi(work.family, 0, FamilyIds.COUNT - 1)]
	if work.action == CLEAR:
		return "clearing the %s" % piece
	var words: Variant = FamilyIds.LEVEL_WORDS.get(piece, null)
	if words == null:
		if work.action == BUILD:
			return "%s, first stage" % piece
		return "%s, %s to %s stage" % [piece, _stage(work.level_to - 1), _stage(work.level_to)]
	var list: Array = words
	if work.action == BUILD:
		return str(list[clampi(work.level_to, 0, list.size() - 1)])
	return "%s to %s" % [list[clampi(work.level_to - 1, 0, list.size() - 1)],
		list[clampi(work.level_to, 0, list.size() - 1)]]


## "first" for a stage level (the shared tables say "first stage").
static func _stage(level: int) -> String:
	return FamilyIds.STAGE_WORDS[clampi(level, 0, 3)].trim_suffix(" stage")


static func _long_name(game: Game, tag: StringName) -> String:
	var def := Countries.def_of(game, tag)
	if def != null and not def.long_name.is_empty():
		return def.long_name
	return String(tag)


static func _tag_of(args: Dictionary) -> StringName:
	var raw: Variant = args.get("tag", &"")
	if raw is StringName:
		return raw
	if raw is String:
		return StringName(raw as String)
	return &""


static func _refusal(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
