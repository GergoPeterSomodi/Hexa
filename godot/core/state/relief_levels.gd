## Thread 1's seven relief levels (docs/design/map/01-terrain-and-relief.md section 2.1), read from the metres of a land
## hex: 0 sea (the coastline decides it, never the height), 1 lowland below 100 m, 2 plain 100 to 400 m, 3 hills
## 400 to 900 m, 4 highland 900 to 1700 m, 5 mountains 1700 to 2800 m, 6 high peaks from 2800 m.
class_name ReliefLevels
extends RefCounted

const SEA := 0
const NAMES: Array[String] = ["Sea", "Lowland", "Plain", "Hills", "Highland", "Mountains", "High peaks"]
## Lower bounds in metres of levels 2 to 6 (level 1 is every land height below the first bound).
const LOWER_BOUNDS: Array[float] = [100.0, 400.0, 900.0, 1700.0, 2800.0]


## The level of a land hex from its height in metres (1 to 6). Use SEA for water, not this.
static func level_of(metres: float) -> int:
	var level := 1
	for i: int in LOWER_BOUNDS.size():
		if metres >= LOWER_BOUNDS[i]:
			level = i + 2
	return level


static func name_of(level: int) -> String:
	return NAMES[clampi(level, 0, NAMES.size() - 1)]
