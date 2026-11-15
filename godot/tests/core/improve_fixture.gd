## Test helper: small MapData fixtures for the improvement tests, built from a list of hex specs, so the tests need no
## map file. A spec is {cover (WorldCover number, default farmland), height (metres, 100), climate (0 snow, 1 frost,
## 2 mild; default frost), road (a road of quality 2 on the hex's east edge), track (quality 1), river (a river on the
## east edge), pass, place {level, port, port_mode, landmark, name}}. A hex that has no spec is sea.
class_name ImproveFixture
extends RefCounted


## A map of cols x rows hexes: land where `specs` has the hex, sea elsewhere.
static func map_of(cols: int, rows: int, specs: Dictionary) -> MapData:
	var m := MapData.new()
	m.id = "fixture"
	m.hex_w_km = 28.0
	m.ref_lat = 45.0
	m.allocate(cols, rows)
	for key: Variant in specs.keys():
		var hex: Vector2i = key
		var spec: Dictionary = specs[key]
		var i := m.index_of(hex)
		m.land[i] = 1
		m.cover[i] = int(spec.get("cover", WorldCover.FARMLAND))
		m.height_m[i] = int(spec.get("height", 100))
		m.climate[i] = int(spec.get("climate", 1))
		m.depth[i] = 0
		if bool(spec.get("pass", false)):
			m.pass_id[i] = 0
		if bool(spec.get("road", false)):
			m.road[m.edge_index(hex, 0)] = 2
		if bool(spec.get("track", false)):
			m.road[m.edge_index(hex, 0)] = 1
		if bool(spec.get("river", false)):
			m.river[m.edge_index(hex, 0)] = 1
		var place: Variant = spec.get("place", null)
		if typeof(place) == TYPE_DICTIONARY:
			var entry: Dictionary = (place as Dictionary).duplicate()
			entry["hex"] = hex
			m.place_id[i] = m.places.size()
			m.places.append(entry)
	return m


## Every hex of a cols x rows block is land with `base`; `over` (hex -> spec keys) is laid on top of single hexes.
static func block(cols: int, rows: int, base: Dictionary, over: Dictionary = {}) -> MapData:
	var specs: Dictionary = {}
	for r: int in rows:
		for c: int in cols:
			var spec := base.duplicate()
			var hex := Vector2i(c, r)
			if over.has(hex):
				var more: Dictionary = over[hex]
				for key: Variant in more.keys():
					spec[key] = more[key]
			specs[hex] = spec
	return map_of(cols, rows, specs)


static func place(level: int, port: bool = false, mode: String = "seaside") -> Dictionary:
	return {"name": "Place", "level": level, "port": port, "port_mode": mode if port else "", "landmark": ""}
