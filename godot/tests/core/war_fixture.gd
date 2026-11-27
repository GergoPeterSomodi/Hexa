## The games and helpers of the war tests (docs/architecture/m7-build-spec.md 9; M7 plan B5). Every game comes from
## ArmyFixture.game(): the 1480 scenario on seed 1480, calm weather, Genoa (ArmyFixture.TAG) chosen, with copied definitions,
## so a planted number never reaches the committed war.
##   game():                 a fresh game as above.
##   at_war(g, a, b):        a live War between a and b made in the test (the id as the door would give it), begun the season
##                           before this one: fair warning (moves-build-spec.md R73) shuts the declared enemy's land to the
##                           declarer in the season the war began, so a fixture war leaves both lands open. In a game's first
##                           season that start_turn is 0, which a save refuses (War.from_dict): a test that saves or reads
##                           back such a game sets g.turn to 2 or later first, or uses declared_now (else a case that expects
##                           a refusal passes for the wrong reason).
##   declared_now(g, a, b):  at_war with the war begun this season, as the door declares it (a closes b's land to a until the
##                           next season; a save takes it in any season).
##   ended(g, a, b, end, terms): an ended War between a and b (begun this season), for the truce.
##   army_at(g, tag, hex, count): an army of `count` pikemen made through the armies' door (ArmyFixture.army).
##   neighbour_of(g, tag):   a country that shares a border with tag (&"" when none).
##   stranger_of(g, tag):    a country that shares no border with tag and is not tag (&"" when none).
##   set_occupier(g, hex, by): the occupier byte of a land hex (a test's state, as the occupation door would leave it).
class_name WarFixture
extends RefCounted


static func game() -> Game:
	return ArmyFixture.game()


static func at_war(g: Game, a: StringName, b: StringName) -> War:
	var w := War.new()
	w.id = g.next_war_id
	w.a = a
	w.b = b
	w.start_turn = maxi(g.turn - 1, 0)  # fair warning: war declared a season earlier
	g.next_war_id += 1
	g.wars.append(w)
	return w


static func declared_now(g: Game, a: StringName, b: StringName) -> War:
	var w := at_war(g, a, b)
	w.start_turn = g.turn
	return w


static func ended(g: Game, a: StringName, b: StringName, end: int, terms: StringName = &"white") -> War:
	var w := declared_now(g, a, b)
	w.end_turn = end
	w.terms = terms
	return w


static func army_at(g: Game, tag: StringName, hex: Vector2i, count: int) -> Army:
	return ArmyFixture.army(g, tag, hex, 0, count)


static func neighbour_of(g: Game, tag: StringName) -> StringName:
	var c := Countries.by_tag(g, tag)
	if c == null:
		return &""
	for id: int in Territory.neighbours(g, c.id):
		var other := Countries.by_id(g, id)
		if other != null:
			return other.tag
	return &""


static func stranger_of(g: Game, tag: StringName) -> StringName:
	var c := Countries.by_tag(g, tag)
	if c == null:
		return &""
	var near := Territory.neighbours(g, c.id)
	for other: Country in g.countries:
		if other.id != c.id and not near.has(other.id):
			return other.tag
	return &""


static func set_occupier(g: Game, hex: Vector2i, by: StringName) -> void:
	var occupant := Countries.by_tag(g, by)
	g.state.occupier[g.map.index_of(hex)] = occupant.id if occupant != null else 0
