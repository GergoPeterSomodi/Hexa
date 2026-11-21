## One kind of company (docs/architecture/m6-build-spec.md sections 4.2 and 5.1): its branch, men, raising cost and goods,
## upkeep, move points, sight, the level that may raise it and the men it regains a season. Stored one file per kind in
## data/defs/units/<key>.tres and listed by GameDefs in id order (append-only). Combat numbers are M7's fields.
@tool
class_name UnitDef
extends Resource

const BRANCHES: Array[StringName] = [&"infantry", &"missile", &"cavalry", &"artillery"]
## The Kit icons of the token figures (ui_kit.json), one a branch.
const FIGURE_NAMES: Array[StringName] = [&"fig_infantry", &"fig_missile", &"fig_cavalry", &"fig_artillery"]
## Eras of the tech tree (3) and the largest numbers a kind may carry (Stats' army series are 32-bit).
const ERA_MAX := 3
const MEN_MAX := 100000
const MONEY_MAX := 1000000
const MP_MAX := 1000

@export var id: int = 0
@export var key: StringName = &""
@export var name: String = ""
## "company of pikemen".
@export var one: String = ""
## "companies of pikemen".
@export var many: String = ""
## One of BRANCHES.
@export var branch: StringName = &""
@export var era: int = 1
## Men at full strength.
@export var men: int = 0
## Ducats to raise one.
@export var cost: int = 0
## Good key -> loads per unit.
@export var cost_goods: Dictionary[String, int] = {}
## Ducats a season at full strength.
@export var upkeep: int = 0
## Move points a season.
@export var mp: int = 0
@export var sight: int = 1
## The settlement level that may raise it.
@export var min_level: int = 1
## Men regained a season in supply at home.
@export var refill: int = 0
## The Kit icon of its token figure, for example &"fig_infantry".
@export var figure: StringName = &""


## Problems found, empty when valid: a key of lowercase letters and underscores, a known branch, men, cost, upkeep and mp
## above 0, sight 1 to 3, min_level 1 to 5, refill 1 to men, cost_goods naming known goods with loads above 0, a figure.
## `defs` is a GameDefs, typed Resource here and read by call: GameDefs lists UnitDefs, and a typed use either way makes the
## two scripts need each other to parse (as M6 A14 says of Game and the systems).
func validate(defs: Resource = null) -> Array[String]:
	var errors: Array[String] = []
	var label := _label()
	if not _key_is_well_formed():
		errors.append("%s: key '%s' should be lowercase letters and underscores" % [label, String(key)])
	if not BRANCHES.has(branch):
		errors.append("%s: branch '%s' is not one of infantry, missile, cavalry, artillery" % [label, String(branch)])
	if name.strip_edges().is_empty():
		errors.append("%s: name is empty" % label)
	if one.strip_edges().is_empty() or many.strip_edges().is_empty():
		errors.append("%s: one and many must not be empty" % label)
	if era < 1 or era > ERA_MAX:
		errors.append("%s: era is %d, expected 1 to %d" % [label, era, ERA_MAX])
	if men <= 0 or men > MEN_MAX:
		errors.append("%s: men is %d, expected 1 to %d" % [label, men, MEN_MAX])
	if cost <= 0 or cost > MONEY_MAX:
		errors.append("%s: cost is %d, expected 1 to %d" % [label, cost, MONEY_MAX])
	if upkeep <= 0 or upkeep > MONEY_MAX:
		errors.append("%s: upkeep is %d, expected 1 to %d" % [label, upkeep, MONEY_MAX])
	if mp <= 0 or mp > MP_MAX:
		errors.append("%s: mp is %d, expected 1 to %d" % [label, mp, MP_MAX])
	if sight < 1 or sight > 3:
		errors.append("%s: sight is %d, expected 1 to 3" % [label, sight])
	if min_level < 1 or min_level > 5:
		errors.append("%s: min_level is %d, expected 1 to 5" % [label, min_level])
	if refill < 1 or refill > men:
		errors.append("%s: refill is %d, expected 1 to men %d" % [label, refill, men])
	for good_key: String in cost_goods:
		var known := GoodDef.KEYS.has(StringName(good_key)) if defs == null else int(defs.call(&"good_id", StringName(good_key))) >= 0
		if not known:
			errors.append("%s: cost_goods names unknown good '%s'" % [label, good_key])
		if int(cost_goods[good_key]) < 1:
			errors.append("%s: cost_goods %s is %d, expected 1 or more" % [label, good_key, int(cost_goods[good_key])])
	if figure == &"":
		errors.append("%s: figure is empty" % label)
	elif not FIGURE_NAMES.has(figure):
		errors.append("%s: figure '%s' is not one of the four figure icons" % [label, String(figure)])
	return errors


func _key_is_well_formed() -> bool:
	if key == &"":
		return false
	for c: String in String(key):
		if not ((c >= "a" and c <= "z") or c == "_"):
			return false
	return true


func _label() -> String:
	if key != &"":
		return "unit %s" % String(key)
	return "unit %d" % id
