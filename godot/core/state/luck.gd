## The three luck streams of a game (docs/architecture/m3-build-spec.md 5.2, standard 5.4). Nothing draws in M3.
class_name Luck
extends RefCounted

const SCHEMA := "hexa-godot/luck/1"

## Rules: weather from M4, battles from M7.
var world := Rng.new()
## The AI (M8).
var ai := Rng.new()
## Looks only.
var decor := Rng.new()


static func seeded(seed_value: int) -> Luck:
	var out := Luck.new()
	out.world.seed_with(seed_value)
	out.ai.seed_with(seed_value ^ 0x5bd1e995)
	out.decor.seed_with(seed_value ^ 0x27d4eb2f)
	return out


func to_dict() -> Dictionary:
	return {"schema": SCHEMA, "world": world.get_state(), "ai": ai.get_state(), "decor": decor.get_state()}


## A missing or mistyped stream, or a wrong schema, gives seeded(seed_value).
static func from_dict(d: Dictionary, seed_value: int) -> Luck:
	if str(d.get("schema", "")) != SCHEMA:
		return seeded(seed_value)
	for key: String in ["world", "ai", "decor"]:
		if not (d.get(key) is int):
			return seeded(seed_value)
	var out := Luck.new()
	out.world.set_state(int(d["world"]))
	out.ai.set_state(int(d["ai"]))
	out.decor.set_state(int(d["decor"]))
	return out


func digest_text() -> String:
	return "%d|%d|%d" % [world.get_state(), ai.get_state(), decor.get_state()]
