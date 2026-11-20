## Reusable 9x7 scenario fixture for M2 core tests (docs/architecture/m2-build-plan.md C8):
## builds a 9x7 map (54 land hexes, 9 sea hexes on row 6), 3 countries (AAA, BBB playable; OUT outside power),
## 2 unowned land pins, GameDefs, and a deep-valid ScenarioDef in code.
class_name ScenarioFixture
extends RefCounted

const COLS := 9
const ROWS := 7
const SEA_ROW := 6
const ALPHA_CAPITAL := Vector2i(1, 2)
const BETA_CAPITAL := Vector2i(5, 2)
const OUTLAND_ANCHOR := Vector2i(7, 2)
const UNOWNED_HEXES: Array[Vector2i] = [Vector2i(3, 5), Vector2i(4, 5)]
const SEA_HEX := Vector2i(2, 6)
const ALL_ACTORS: Array[StringName] = [&"AAA", &"BBB", &"OUT", &"", &"ZZZ"]


## The 14 committed works families, loaded from data/defs/families (M3 spec 4.3).
static func families() -> Array[FamilyDef]:
	var out: Array[FamilyDef] = []
	for key: String in FAMILY_KEYS:
		out.append(ResourceLoader.load(
			"res://data/defs/families/%s.tres" % key, "", ResourceLoader.CACHE_MODE_IGNORE
		) as FamilyDef)
	return out


const FAMILY_KEYS: Array[String] = [
	"settlements", "castles", "wheat", "hemp", "silk", "dyes", "vineyard", "olives",
	"grazing", "timber", "mines", "quarry", "salt", "harbour",
]


static func make_country(
	p_tag: StringName,
	p_name: String,
	p_long: String,
	p_adj: String,
	p_colour: Color,
	p_cap_name: String = "",
) -> CountryDef:
	var c := CountryDef.new()
	c.tag = p_tag
	c.name = p_name
	c.long_name = p_long
	c.adjective = p_adj
	c.colour = p_colour
	c.capital_name = p_cap_name
	c.ruler = "the Ruler of %s" % p_name
	c.arms_division = &"cross"
	c.arms_field = &"gules"
	c.arms_charge = &"argent"
	c.tip = "%s tip." % p_name
	return c


## Builds {map: MapData, defs: GameDefs, scenario: ScenarioDef} for a 9x7 world with 3 countries.
static func build() -> Dictionary:
	var m := MapData.new()
	m.id = "scenario_fixture"
	m.hex_w_km = 28.0
	m.ref_lat = 45.0
	m.allocate(COLS, ROWS)
	for r: int in SEA_ROW:
		for c: int in COLS:
			var i := r * COLS + c
			m.land[i] = 1
			m.depth[i] = 0
			m.height_m[i] = 120
			m.relief[i] = 1
			m.climate[i] = 2
			if (c + r) % 7 == 0:
				m.cover[i] = WorldCover.WOODS
			elif (c + r) % 5 == 0:
				m.cover[i] = WorldCover.GRASSLAND
			else:
				m.cover[i] = WorldCover.FARMLAND
	m.places = [
		{"name": "Alpha", "hex": ALPHA_CAPITAL, "level": 2, "castle": 0, "port": false, "port_mode": "", "landmark": ""},
		{"name": "Beta", "hex": BETA_CAPITAL, "level": 2, "castle": 0, "port": false, "port_mode": "", "landmark": ""},
	]
	m.place_id[m.index_of(ALPHA_CAPITAL)] = 0
	m.place_id[m.index_of(BETA_CAPITAL)] = 1

	var defs := GameDefs.new()
	defs.tinctures = GameDefs.default_tinctures()
	defs.cb_palette = GameDefs.default_cb_palette()
	defs.families = families()
	FakeScenario.economy_into(defs)
	defs.weather_odds = PackedInt32Array([100, 0, 0])  # calm: the weather is Calendar's and Snapshot's, not these tests'
	defs.countries = [
		make_country(&"AAA", "Alpha", "Republic of Alpha", "Alphan", Color("#b3261e")),
		make_country(&"BBB", "Beta", "Duchy of Beta", "Betan", Color("#2b5aa8")),
		make_country(&"OUT", "Outland", "Kingdom of Outland", "Outlander", Color("#2e7d3c"), "Farburg"),
	]

	var s := ScenarioDef.new()
	s.id = "fixture_scenario"
	s.name = "Fixture Scenario"
	s.blurb = "A 9x7 test scenario with three countries."
	s.map_id = m.id
	s.map_digest = m.digest()
	s.year = 1480
	s.countries = [&"AAA", &"BBB", &"OUT"]
	s.capitals = [ALPHA_CAPITAL, BETA_CAPITAL, ScenarioDef.NO_HEX]
	s.cb_colours = PackedByteArray([0, 4, 6])
	s.seeds = [
		{"hex": ALPHA_CAPITAL, "tag": &"AAA", "kind": &"town", "note": "Alpha"},
		{"hex": BETA_CAPITAL, "tag": &"BBB", "kind": &"town", "note": "Beta"},
		{"hex": OUTLAND_ANCHOR, "tag": &"OUT", "kind": &"anchor", "note": "Outland"},
	]
	s.pins = [
		{"hex": UNOWNED_HEXES[0], "tag": &"", "note": "Unowned west"},
		{"hex": UNOWNED_HEXES[1], "tag": &"", "note": "Unowned east"},
	]
	s.owner = ScenarioGrowth.grow(m, s)
	defs.scenarios = [s]
	return {"map": m, "defs": defs, "scenario": s}


## Builds a fresh Game.new_scenario over the 9x7 fixture.
static func game(seed_value: int = 1480) -> Game:
	var f := build()
	return Game.new_scenario(f["map"] as MapData, f["defs"] as GameDefs, f["scenario"] as ScenarioDef, seed_value)
