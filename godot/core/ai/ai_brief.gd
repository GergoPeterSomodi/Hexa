## A seat's picture of the game for its turn (docs/architecture/m8-build-spec.md 4.5, 5.5): made once a turn, through AiKnow only,
## so what is in it is what the seat's country may know. The step modules read the brief and AiKnow, nothing else.
@warning_ignore_start("integer_division")
class_name AiBrief
extends RefCounted

var tag: StringName = &""
var id := 0
var temper: AiTemperDef = null
var ai: AiDef = null
var treasury := 0
var net := 0
var upkeep := 0
var reserve := 0
var army_room := 0
var men := 0
var people := 0
var goal_men := 0
var enemies: Array[StringName] = []
var threats: Array[StringName] = []
var front: PackedInt32Array = PackedInt32Array()
var posts: Array[Vector2i] = []
var seen: Array[Dictionary] = []
var hungry := false
var food_soon := false
var town_full: Array[Vector2i] = []
var think := false
var declared_now: Array[StringName] = []
## Open land claimed by the seat's armies this turn: hex index -> army id.
var claims: Dictionary = {}
## The goals an army's march was refused this turn (army id -> Array of Vector2i): its next step tries the next aim (4.10).
var refused: Dictionary = {}
## The near-land field of the seat (AiKnow.land_field within the shared prize range), kept for the game version it was made on.
var _near: Dictionary = {}
var _near_version := -1
## The ducats of the best works card refused for money only this turn (0: none).
var wanted_cost := 0
## The works step's chosen candidates and their cards.
var cards: Array[Dictionary] = []

var _game: Game = null


static func make(game: Game, seat: StringName) -> AiBrief:
	var b := AiBrief.new()
	b._game = game
	b._fill(seat)
	return b


## Reads the seat's picture through AiKnow. (Instance methods, not a writer's `b.field =`: tests/core/test_no_other_writers.gd
## guards the field names `treasury` and `people` wherever they are assigned through a receiver.)
func _fill(seat: StringName) -> void:
	var game := _game
	tag = seat
	id = AiKnow.id_of(game, seat)
	ai = game.defs.ai
	temper = AiPlayers.temper_of(game, seat)
	treasury = AiKnow.treasury(game, seat)
	net = AiKnow.preview_net(game, seat)
	upkeep = AiKnow.upkeep(game, seat)
	var seasons := temper.reserve_seasons if temper != null else 0
	reserve = seasons * maxi(upkeep, ai.min_upkeep)
	var share := temper.army_upkeep_share if temper != null else 0
	army_room = maxi(0, (net + AiKnow.army_upkeep(game, seat)) * share / 1000)
	men = AiKnow.men(game, seat)
	people = AiKnow.people(game, seat)
	enemies = AiKnow.enemies(game, seat)
	threats = _threats()
	var permille := temper.army_permille if temper != null else 0
	if temper != null and (not enemies.is_empty() or not threats.is_empty()):
		permille = temper.war_army_permille
	goal_men = maxi(ai.min_army_men, people * permille / 1000)
	front = _front()
	posts = _posts()
	seen = AiKnow.seen_enemies(game, seat)
	var alarms := AiKnow.alarms(game, seat)
	hungry = bool(alarms["hungry"])
	food_soon = bool(alarms["food_soon"])
	town_full.assign(alarms["town_full"])
	think = posmod(AiKnow.turn(game) + id, ai.think_every) == 0


## 4.8's assignment: the seat's armies by men, most first (ties: id), take posts[i mod count]. Army.NO_HEX with no post.
func post_of(army_id: int) -> Vector2i:
	if posts.is_empty() or _game == null:
		return Army.NO_HEX
	var ranked := AiKnow.own_armies(_game, tag)
	ranked.sort_custom(func(a: Army, b: Army) -> bool:
		return a.id < b.id if a.men() == b.men() else a.men() > b.men())
	for i: int in ranked.size():
		if ranked[i].id == army_id:
			return posts[i % posts.size()]
	return Army.NO_HEX


## The hexes within prize_range of the seat's land, as keys (AiKnow.land_field). Built on first use and again once the game's
## version has moved, so a read never sees a field from before a change.
func near_land() -> Dictionary:
	if _game == null:
		return {}
	if _near_version != _game.version:
		_near = AiKnow.land_field(_game, tag, ai.prize_range)
		_near_version = _game.version
	return _near


## The enemies, and each neighbour whose banded men exceed the seat's own by the threat share (id order).
func _threats() -> Array[StringName]:
	var found := {}
	for e: StringName in enemies:
		found[AiKnow.id_of(_game, e)] = e
	var floor_men := maxi(men, ai.min_army_men) * ai.threat_permille
	for n: StringName in AiKnow.neighbours(_game, tag):
		var id := AiKnow.id_of(_game, n)
		if not found.has(id) and AiKnow.men_of(_game, tag, n) * 1000 > floor_men:
			found[id] = n
	var ids := found.keys()
	ids.sort()
	var out: Array[StringName] = []
	for id: int in ids:
		out.append(found[id])
	return out


## Own controlled hexes with a land neighbour owned or controlled by a threat (hex index order).
func _front() -> PackedInt32Array:
	var out := PackedInt32Array()
	if threats.is_empty():
		return out
	for i: int in AiKnow.controlled(_game, tag):
		for beside: Vector2i in AiKnow.land_neighbours(_game, AiKnow.hex_of(_game, i)):
			if threats.has(AiKnow.owner_of(_game, beside)) or threats.has(AiKnow.controller_of(_game, beside)):
				out.append(i)
				break
	return out


## Per threat (most banded men first, then id) the seat's depot nearest to the threat's land (ties: lower index); then the
## capital, else the most populous settlement; no duplicates.
func _posts() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var depots := AiKnow.depots(_game, tag)
	var order := threats.duplicate()
	order.sort_custom(func(x: StringName, y: StringName) -> bool:
		var mx := AiKnow.men_of(_game, tag, x)
		var my := AiKnow.men_of(_game, tag, y)
		return AiKnow.id_of(_game, x) < AiKnow.id_of(_game, y) if mx == my else mx > my)
	for t: StringName in order:
		var best := Army.NO_HEX
		var best_d := 1 << 30
		var land := AiKnow.land_of(_game, t)
		for depot: Vector2i in depots:
			var d := _nearest(depot, land, best_d)
			if d < best_d:
				best_d = d
				best = depot
		if best != Army.NO_HEX and not out.has(best):
			out.append(best)
	var home := AiKnow.capital_of(_game, tag)
	if home == Army.NO_HEX:
		var most := -1
		for hex: Vector2i in AiKnow.settlements(_game, tag):
			if AiKnow.people_at(_game, hex) > most:
				most = AiKnow.people_at(_game, hex)
				home = hex
	if home != Army.NO_HEX and not out.has(home):
		out.append(home)
	return out


## The least distance from `from` to a hex of `land`, or `below` when none is nearer.
func _nearest(from: Vector2i, land: PackedInt32Array, below: int) -> int:
	var least := below
	for i: int in land:
		var d := AiKnow.hex_distance(from, AiKnow.hex_of(_game, i))
		if d < least:
			least = d
	return least
