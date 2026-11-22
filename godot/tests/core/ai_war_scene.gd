## The scenes and helpers of the AI's war tests (docs/architecture/m8-build-spec.md 9; test_ai_war.gd, test_ai_war_aims.gd). Every
## game is AiFixture.duel's, so it has its own copies of the definitions; a planted number is set on a duplicate of a temperament
## or of the shared AiDef (`temper`, `ai`), never on a committed one.
##   duel():            the duel at Autumn 1480 (a think turn of Milan's) with the army the fixture gives Genoa taken off.
##   at_war(enemy):     the duel with a live war Milan against `enemy`.
##   ready_duel(chance): Milan with 4 companies, every neighbour at 2,000 men but Genoa at 0, the roll's chance `chance`.
##   stats(g, others, named): the last closed season's men (every country `others`, Genoa 0, `named` tag -> men).
##   brief(g), hook(g), step(g, brief, army), declares(g, brief): the seat's brief, a hook that records the acts (`acts`), one
##                      army step, one war step (true when it declared).
##   near_scene(enemy_comps, enemy_hex): Milan's 4 companies at (10, 5) at war with Venice, a Venetian army beside them.
class_name AiWarScene
extends RefCounted

const M := AiFixture.MILAN
const GEN := AiFixture.GENOA
const VEN := AiFixture.VENICE
const WALLS := Vector2i(8, 13)
const FORT := Vector2i(10, 9)
const STAND := Vector2i(11, 13)

static var acts: Array[Dictionary] = []


static func duel() -> Game:
	var g := AiFixture.duel()
	for a: Army in Armies.of_country(g, GEN):
		Armies.remove(g, a)
	g.turn = 3
	return g


static func at_war(enemy: StringName) -> Game:
	var g := duel()
	WarFixture.at_war(g, M, enemy)
	return g


static func ready_duel(chance: int = 1000) -> Game:
	var g := duel()
	temper(g, {"declare_chance": chance})
	WarFixture.army_at(g, M, Vector2i(9, 9), 4)
	stats(g, 2000)
	return g


## The temperament Milan has, copied with `changes`, put in the game's own list of definitions.
static func temper(g: Game, changes: Dictionary) -> void:
	var t := g.defs.temper(&"opportunist").duplicate() as AiTemperDef
	for field: String in changes:
		t.set(field, changes[field])
	var list: Array[AiTemperDef] = []
	for old: AiTemperDef in g.defs.tempers:
		list.append(t if old.key == t.key else old)
	g.defs.tempers = list


## The shared numbers, copied with `changes`.
static func ai(g: Game, changes: Dictionary) -> void:
	var d := g.defs.ai.duplicate() as AiDef
	for field: String in changes:
		d.set(field, changes[field])
	g.defs.ai = d


static func stats(g: Game, others: int, named: Dictionary = {}) -> void:
	var col := Stats.column("army_men")
	for c: Country in g.countries:
		var row := PackedInt32Array()
		row.resize(Stats.SERIES.size())
		row[col] = int(named.get(c.tag, others if c.tag != GEN else 0))
		g.stats.set_row(g.stats.index_of(c.tag), 1, row)
	g.stats.commit(1)


static func brief(g: Game) -> AiBrief:
	Sight.refresh(g)
	g.version += 1
	return AiBrief.make(g, M)


static func hook(g: Game) -> AiTurn:
	var turn_hook := AiFixture.solo(g, M)
	acts = []
	turn_hook.judge = func(_t: StringName, action: String, args: Dictionary, _v: Dictionary, _r: Dictionary) -> void:
		acts.append({"action": action, "args": args})
	return turn_hook


static func declares(g: Game, b: AiBrief = null) -> bool:
	var seat := b if b != null else brief(g)
	AiWar.war(hook(g), g, seat, 0)
	return not seat.declared_now.is_empty()


static func step(g: Game, b: AiBrief, army: Army) -> void:
	AiWar.war_army(hook(g), g, b, army.id)


static func luck(g: Game) -> int:
	return g.luck.ai.get_state()


static func siege(g: Game, hex: Vector2i, by: StringName, progress: int, seasons: int) -> void:
	var s := Siege.new()
	s.hex = hex
	s.besieger = by
	s.progress = progress
	s.seasons = seasons
	g.sieges.append(s)
	g.version += 1


static func morale(g: Game, army: Army, value: int) -> void:
	for u: Unit in army.units:
		Armies.set_morale(g, army, u.id, value)
	g.version += 1


static func kinds(list: Array[Dictionary]) -> Array[StringName]:
	var out: Array[StringName] = []
	for aim: Dictionary in list:
		out.append(aim["kind"] as StringName)
	return out


static func aim_of(list: Array[Dictionary], kind: StringName) -> Dictionary:
	for aim: Dictionary in list:
		if aim["kind"] == kind:
			return aim
	return {}


static func near_scene(enemy_comps: int, enemy_hex: Vector2i = Vector2i(11, 5)) -> Dictionary:
	var g := at_war(VEN)
	var mine := WarFixture.army_at(g, M, Vector2i(10, 5), 4)
	var theirs := WarFixture.army_at(g, VEN, enemy_hex, enemy_comps)
	return {"g": g, "mine": mine, "theirs": theirs}
