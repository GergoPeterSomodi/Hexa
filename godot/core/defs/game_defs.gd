## Central catalog of fixed game definitions (docs/architecture/m2-build-spec.md section 4.6, 4.7, 5.1, and 8.2).
## Loaded once from res://data/defs/game_defs.tres and read-only in play.
@tool
class_name GameDefs
extends Resource

@export var countries: Array[CountryDef] = []
## The works numbers of the 14 families (M3 spec 5.1); external files under data/defs/families/.
@export var families: Array[FamilyDef] = []
@export var work_slots_base: int = 1
@export var work_slots_city_level: int = 4
@export var works_halt_in_snow_winter: bool = true
@export var scenarios: Array[ScenarioDef] = []
@export var tinctures: Dictionary[StringName, Color] = {}
@export var cb_palette: PackedColorArray = PackedColorArray()
@export var unowned_colour: Color = Color("#d8ccb0")
@export var min_contrast: float = 30.0
@export var min_contrast_cb: float = 20.0

var _country_cache: Dictionary[StringName, CountryDef] = {}
var _country_cache_size: int = -1
var _scenario_cache: Dictionary[String, ScenarioDef] = {}
var _scenario_cache_size: int = -1


## Default heraldic tinctures from m2-build-spec section 4.7.
static func default_tinctures() -> Dictionary[StringName, Color]:
	return {
		&"or": Color("#d4a82c"),
		&"argent": Color("#efeadf"),
		&"gules": Color("#b3261e"),
		&"azure": Color("#2b5aa8"),
		&"sable": Color("#241f1c"),
		&"vert": Color("#2e7d3c"),
		&"purpure": Color("#6b3a7a"),
	}


## Default 8-colour Okabe-Ito colour-blind safe palette from m2-build-spec section 4.6.
static func default_cb_palette() -> PackedColorArray:
	return PackedColorArray([
		Color("#e69f00"),
		Color("#56b4e9"),
		Color("#009e73"),
		Color("#f0e442"),
		Color("#0072b2"),
		Color("#d55e00"),
		Color("#cc79a7"),
		Color("#ebebeb"),
	])


## Looks up a country definition by tag, or null when unknown (cache built on first use).
func country(tag: StringName) -> CountryDef:
	if _country_cache_size != countries.size():
		_rebuild_country_cache()
	return _country_cache.get(tag, null)


## Looks up a family definition by id (1 to 14), or null when unknown.
func family(id: int) -> FamilyDef:
	for f: FamilyDef in families:
		if f != null and f.id == id:
			return f
	return null


## Looks up a scenario definition by id, or null when unknown (cache built on first use).
func scenario(id: String) -> ScenarioDef:
	if _scenario_cache_size != scenarios.size():
		_rebuild_scenario_cache()
	return _scenario_cache.get(id, null)


## Problems found, empty when valid: unique country tags, each CountryDef valid, 8 CB colours, unique scenario ids,
## 14 families (each valid, ids 1 to 14 once each), work_slots_base 1 or more, work_slots_city_level 1 to 5.
func validate() -> Array[String]:
	var errors: Array[String] = []
	var seen_tags: Dictionary = {}
	for i: int in countries.size():
		var c := countries[i]
		if c == null:
			errors.append("countries[%d]: entry is null" % i)
			continue
		for err: String in c.validate(tinctures):
			errors.append(err)
		if c.tag != &"":
			if seen_tags.has(c.tag):
				errors.append("countries[%d]: duplicate tag '%s'" % [i, String(c.tag)])
			else:
				seen_tags[c.tag] = true
	if cb_palette.size() != 8:
		errors.append("cb_palette has %d colours, expected 8" % cb_palette.size())
	var family_count := FamilyIds.COUNT - 1
	if families.size() != family_count:
		errors.append("families has %d entries, expected %d" % [families.size(), family_count])
	var seen_families: Dictionary = {}
	for i: int in families.size():
		var f := families[i]
		if f == null:
			errors.append("families[%d]: entry is null" % i)
			continue
		for err: String in f.validate():
			errors.append(err)
		if seen_families.has(f.id):
			errors.append("families[%d]: duplicate family id %d" % [i, f.id])
		else:
			seen_families[f.id] = true
	if work_slots_base < 1:
		errors.append("work_slots_base is %d, expected 1 or more" % work_slots_base)
	if work_slots_city_level < 1 or work_slots_city_level > 5:
		errors.append("work_slots_city_level is %d, expected 1 to 5" % work_slots_city_level)
	var seen_ids: Dictionary = {}
	for i: int in scenarios.size():
		var s := scenarios[i]
		if s == null:
			errors.append("scenarios[%d]: entry is null" % i)
			continue
		if s.id.strip_edges().is_empty():
			errors.append("scenarios[%d]: id is empty" % i)
		elif seen_ids.has(s.id):
			errors.append("scenarios[%d]: duplicate scenario id '%s'" % [i, s.id])
		else:
			seen_ids[s.id] = true
	return errors


## SHA-256 (hex text) of every field in a fixed order.
func digest() -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	_feed_int(ctx, countries.size())
	for c: CountryDef in countries:
		_feed_country(ctx, c)
	_feed_int(ctx, scenarios.size())
	for s: ScenarioDef in scenarios:
		if s == null:
			_feed_str(ctx, "<null>")
		else:
			_feed_str(ctx, s.digest())
	var t_keys: Array = tinctures.keys()
	t_keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	_feed_int(ctx, t_keys.size())
	for k: Variant in t_keys:
		var key := StringName(k)
		_feed_str(ctx, String(key))
		_feed_color(ctx, tinctures[key])
	_feed_int(ctx, cb_palette.size())
	for col: Color in cb_palette:
		_feed_color(ctx, col)
	_feed_color(ctx, unowned_colour)
	_feed_bytes(ctx, PackedFloat64Array([min_contrast, min_contrast_cb]).to_byte_array())
	_feed_int(ctx, families.size())
	for f: FamilyDef in families:
		_feed_family(ctx, f)
	_feed_int(ctx, work_slots_base)
	_feed_int(ctx, work_slots_city_level)
	_feed_int(ctx, 1 if works_halt_in_snow_winter else 0)
	return ctx.finish().hex_encode()


func _rebuild_country_cache() -> void:
	_country_cache.clear()
	for c: CountryDef in countries:
		if c != null and c.tag != &"" and not _country_cache.has(c.tag):
			_country_cache[c.tag] = c
	_country_cache_size = countries.size()


func _rebuild_scenario_cache() -> void:
	_scenario_cache.clear()
	for s: ScenarioDef in scenarios:
		if s != null and not s.id.is_empty() and not _scenario_cache.has(s.id):
			_scenario_cache[s.id] = s
	_scenario_cache_size = scenarios.size()


static func _feed_bytes(ctx: HashingContext, bytes: PackedByteArray) -> void:
	if not bytes.is_empty():
		ctx.update(bytes)


static func _feed_int(ctx: HashingContext, value: int) -> void:
	ctx.update(PackedInt32Array([value]).to_byte_array())


static func _feed_str(ctx: HashingContext, text: String) -> void:
	var buf := text.to_utf8_buffer()
	_feed_int(ctx, buf.size())
	_feed_bytes(ctx, buf)


static func _feed_color(ctx: HashingContext, col: Color) -> void:
	ctx.update(PackedFloat32Array([col.r, col.g, col.b, col.a]).to_byte_array())


static func _feed_family(ctx: HashingContext, f: FamilyDef) -> void:
	if f == null:
		_feed_int(ctx, 0)
		return
	_feed_int(ctx, 1)
	_feed_int(ctx, f.id)
	_feed_str(ctx, String(f.key))
	_feed_int(ctx, f.work_seasons.size())
	_feed_bytes(ctx, f.work_seasons.to_byte_array())
	_feed_int(ctx, f.clear_seasons)


static func _feed_country(ctx: HashingContext, c: CountryDef) -> void:
	if c == null:
		_feed_int(ctx, 0)
		return
	_feed_int(ctx, 1)
	_feed_str(ctx, String(c.tag))
	_feed_str(ctx, c.name)
	_feed_str(ctx, c.long_name)
	_feed_str(ctx, c.adjective)
	_feed_color(ctx, c.colour)
	_feed_str(ctx, c.capital_name)
	_feed_str(ctx, String(c.arms_division))
	_feed_str(ctx, String(c.arms_field))
	_feed_str(ctx, String(c.arms_charge))
	_feed_str(ctx, c.tip)
	_feed_str(ctx, c.ruler)
