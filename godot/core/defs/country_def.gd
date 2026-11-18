## A country's fixed identity and arms (docs/architecture/m2-build-spec.md section 4.7 and 5.1).
## Stored one file per country in data/defs/countries/<tag>.tres and listed by GameDefs.
class_name CountryDef
extends Resource

## Allowed heraldic shield divisions for CountryArms.
const DIVISIONS: Array[StringName] = [
	&"plain", &"per_pale", &"per_fess", &"per_bend", &"quarterly", &"cross",
	&"saltire", &"chief", &"fess", &"pale", &"bend", &"bordure",
]

@export var tag: StringName = &""
@export var name: String = ""
@export var long_name: String = ""
@export var adjective: String = ""
@export var colour: Color = Color()
@export var capital_name: String = ""
@export var arms_division: StringName = &""
@export var arms_field: StringName = &""
@export var arms_charge: StringName = &""
@export_multiline var tip: String = ""


## Problems found, empty when valid: tag form (3 capital ASCII letters), non-empty names, known division, and
## both arms tinctures present in `tinctures`.
func validate(tinctures: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var label := _label()
	if not _is_valid_tag(tag):
		errors.append("%s: tag '%s' must be three capital letters" % [label, String(tag)])
	if name.strip_edges().is_empty():
		errors.append("%s: name is empty" % [label])
	if long_name.strip_edges().is_empty():
		errors.append("%s: long_name is empty" % [label])
	if adjective.strip_edges().is_empty():
		errors.append("%s: adjective is empty" % [label])
	if not DIVISIONS.has(arms_division):
		errors.append("%s: unknown arms_division '%s'" % [label, String(arms_division)])
	if not _has_tincture(tinctures, arms_field):
		errors.append("%s: unknown arms_field tincture '%s'" % [label, String(arms_field)])
	if not _has_tincture(tinctures, arms_charge):
		errors.append("%s: unknown arms_charge tincture '%s'" % [label, String(arms_charge)])
	return errors


func _label() -> String:
	if tag != &"":
		return String(tag)
	if not name.strip_edges().is_empty():
		return name
	return "CountryDef"


static func _is_valid_tag(p_tag: StringName) -> bool:
	var s := String(p_tag)
	if s.length() != 3:
		return false
	for i: int in 3:
		var code := s.unicode_at(i)
		if code < 65 or code > 90:
			return false
	return true


static func _has_tincture(tinctures: Dictionary, key: StringName) -> bool:
	if key == &"":
		return false
	return tinctures.has(key)
