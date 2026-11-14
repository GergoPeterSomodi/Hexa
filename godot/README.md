# Hexa in Godot (0.3.x)

The Godot port of Age of Discovery (`docs/roadmap/godot-port-plan.md`, Part B2 and B3). Europe only, Windows builds.
The Python game in `hexa/` is frozen at v0.2.2 and is the reference, not something to edit.

## Engine

- Godot **4.7.2-stable**, standard build (not .NET), Compatibility renderer, GDScript. Pinned here, in CI and in
  `project.godot`. Upgrade only between releases, with the tests green before and after.
- Set the `GODOT` environment variable to the engine executable. Nothing in the repository holds a local path.
  - PowerShell: `$env:GODOT = "C:\path\to\Godot_v4.7.2-stable_win64_console.exe"`
  - Git Bash: `export GODOT=/c/path/to/Godot_v4.7.2-stable_win64_console.exe`

## Layout

```
project.godot           engine pin, warning levels (B3), main scene, GUT plugin
core/                   pure GDScript, extends RefCounted, no Node, no scene tree, runs headless
  rng.gd                the only source of luck in core/ (wraps one seeded RandomNumberGenerator)
  data/ state/ systems/ mapgen/ views/ ai/    empty until their releases; the layers are listed below
shell/                  everything with Nodes
  app/                  main scene (main.tscn) and the window
  map/ hud/ panels/ screens/ ui/              empty until their releases
tests/core/ tests/shell/ tests/fixtures/     GUT tests (test_*.gd); fixtures for the map check later
tools/                  headless GDScript tools (check_scripts.gd; build_map.gd and others come with the map)
data/                   data exported once from Python (geography/, maps/)
assets/atlases/         art baked by the Python tool (png and json, committed)
addons/gut/             GUT 9.7.1, copied unchanged from its release (MIT, see addons/gut/LICENSE.md)
```

## Rules (B3)

- **Layers:** data, then state, systems, world, game, views, shell. A file may use files of its own layer or a lower
  one, never a higher one. `tools/lint_godot.py` checks the `res://` paths; class names are not checked by it.
- **`core/` has no engine calls:** no Node, no scene tree (`get_tree`, `get_node`, `$`), no `Input`, `OS`, `Time`,
  `Engine`, `DisplayServer`, no `await`, no `Thread`, `Mutex` or `WorkerThreadPool`. Files only under `res://` and
  `user://`.
- **Luck through `rng.gd` only:** no `randi`, `randf`, `randomize`, `shuffle`, `pick_random` or `RandomNumberGenerator`
  in `core/` outside `rng.gd`.
- **Godot 4 only:** no `yield`, `export var`, `onready var`, `setget`, string `connect(...)`, `.instance()`, `tool`
  (use `@tool`) or the old `TileMap` node.
- **Actions are pairs:** `x_check(world, ...)` and `x(world, ...)`. The shell changes state only through actions.
- **Typed GDScript:** the warnings for untyped declarations, unsafe property and method access, integer division and
  narrowing conversions are errors (`project.godot`). Write `int(a / b)` only with a comment, and `7 / 2` is 3 here.
- **Scenes are text** (`.tscn`), laid out with containers and the one Theme. No hand-placed pixel positions.
- **Autoloads:** none in 0.3.0. `core/` never reads an autoload. A new autoload needs a line in this file and a reason
  reviewed by the technical director; the shell owns the game through the main scene.

## Commands

Run from the repository root (the folder that holds `godot/`), with `GODOT` set.

```bash
# Import the project (creates .godot/; fails on any script error or warning)
"$GODOT" --headless --path godot --import

# Load every script: parse errors and warnings show here
"$GODOT" --headless --path godot --script res://tools/check_scripts.gd

# Architecture and Godot 3 lint (text scan, plain Python, no pip packages)
python tools/lint_godot.py godot

# Open the main scene and quit at once (the window opens and closes)
"$GODOT" --headless --path godot --quit

# GUT tests, headless, with a JUnit report
"$GODOT" --headless --path godot -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit -gjunit_xml_file=gut-junit.xml

# Windows build (needs the export templates of the same version installed)
"$GODOT" --headless --path godot --export-release "Windows Desktop" build/Hexa.exe

# Build Europe 1480 and print every count beside the Python reference (exit 1 when a checked count is out of range);
# add -- --seed=N after the script to build another seed; -- --out=PATH writes the map file (see "The map file")
"$GODOT" --headless --path godot -s res://tools/build_map.gd -- --out=res://data/maps/europe_1480.json

# The map check report (markdown, every count OK / OPEN / OUT, the owners against Python, the speed rows)
"$GODOT" --headless --path godot -s res://tools/map_report.gd -- --out=<absolute path of the .md>

# The speed probe: builder stages, road search against AStar2D, map file load (writes docs/reports/0.3.0-speed.json)
"$GODOT" --headless --path godot -s res://tools/speed_probe.gd -- --out=<absolute path of the .json>

# Windowed (not headless: nothing is drawn headless). Contact sheet frames: the twelve regions and the whole map, both
# views, 1280 x 720 PNGs; the Python frames come from tools/contact_sheet_python.py (see the map check report)
"$GODOT" --path godot -s res://tools/contact_sheet.gd -- --out=<absolute folder>
# Start-up probe: time from the script's start to the map view on screen (windowed)
"$GODOT" --path godot -s res://tools/startup_probe.gd
```

## The map file

`godot/data/maps/europe_1480.json` is the Europe 1480 map as text (a JSON object, about 2.8 MB, one line per province,
country, unit, crest edge and terrain row; schema `hexa-godot/map/1`). It is the map every game starts on (0.3.0
decision 1): `shell/app/main.gd` reads it, and falls back to the staged builder when the file is missing or does not
read. `-- --build-map` (after the user arguments) forces the builder: the dev path.

- Written by `tools/build_map.gd -- --out=res://data/maps/europe_1480.json` (the committed seed, 1480). Reads back to
  the same text, byte for byte (the tool checks it, and so does a GUT test).
- Format: a hex is `[column, row]`; an edge is `[a, b, c, d]` (`HexGrid.edge_key`); `terrain` is one array per grid row
  (index = column); a province is an array of `[column, row, terrain, good, coastal, city, name, region, owner,
  controller, tribe, peasants, burghers, nobles, natives, works, settlement, castle, port]`. `MapFile` (core/mapgen)
  reads and writes the text; the file reads and writes are in the shell and the tools.
- Changing the builder or the geography changes the file: rebuild with `--out`, review the diff. CI rebuilds the map
  and fails when the rebuilt file differs from the committed one (the `map` job of `.github/workflows/godot.yml`).
- Start-up: reading and parsing the file takes about 0.15 s on the build PC; the map view is on screen about 0.9 s
  after the script starts (speed probe and `tools/startup_probe.gd`).

The editor: open `godot/project.godot` with the same engine. GUT shows in the editor's plugin list.

## MapData fields

`MapData` (`core/mapgen/map_data.gd`) is what `MapBuilder.build_europe(EuropeData.load_europe())` returns. The map view
reads these fields; their names are stable, and a change of name or meaning is written here first. Hexes are
`Vector2i(column, row)`; edges are `HexGrid.edge_key` (`Vector4i`).

| Field | Type | Meaning |
|---|---|---|
| `cols`, `rows` | int | the grid, 203 by 150 |
| `terrain` | `Dictionary[Vector2i, String]` | every grid hex: a land kind of `terrain.json`, or `MapData.OCEAN` / `MapData.LAKE` |
| `rivers`, `river_at` | Dictionary | river name to its hexes (3 or more); hex to the first river through it |
| `sea_body` | `Dictionary[Vector2i, int]` | ocean hex to the number of its sea |
| `city_names`, `city_sizes` | Dictionary | land hex to the city's name and size |
| `ridge_edges` | `Dictionary[Vector4i, bool]` | crest edges no army crosses |
| `pass_names`, `pass_ids`, `pass_hexes` | Dictionary | open crest edges to a pass name and id; hex at a pass end to the pass name |
| `provinces` | `Dictionary[Vector2i, Province]` | every land hex, in (column, row) order |
| `landmass` | `Dictionary[Vector2i, int]` | land hex to its landmass number |
| `countries` | `Dictionary[String, Country]` | country tag to its country |
| `country_order` | `Array[String]` | the tags in `geo.COUNTRIES` order |
| `roads` | `Dictionary[Vector2i, bool]` | every hex on a road |
| `road_paths` | `Array[Array]` | each road: an `Array` of `Vector2i`, from its town to the network it joined |
| `units` | `Array[Unit]` | the starting units (not drawn in 0.3.0) |

`Province` (`core/state/province.gd`): `pos`, `terrain`, `good` (`""` for none), `coastal`, `city`, `name`, `region`,
`owner` (a country tag, `""` for none), `controller`, `tribe` (unowned hexes), `peasants`, `burghers`, `nobles`,
`natives`, `works` (0 to 2), `settlement` (0 none, 1 village, 2 town, 3 city), `castle` (0 none, 1 tower, 2 small
castle, 3 large castle), `port` (bool). `pop()` is peasants plus burghers plus nobles.

`Country` (`core/state/country.gd`): `tag`, `name`, `colour` (`Color`), `capital` (`Vector2i`), `colonial_start`
(999 when none). `Unit` (`core/state/unit.gd`): `id`, `kind` (the `units.json` key), `owner`, `pos`, `hp`, `moves`.

Helpers on `MapData`: `is_land(pos)`, `land_hexes()`, `province(pos)`, `provinces_of(tag)`, `total_pop(tag)`,
`units_at(pos)`, `is_ridge_step(a, b)`.

Not built in 0.3.0 (later releases): the buildings other than ports and works, garrisons, treasuries, the general's
trait, markets, start techs, random worlds.

## Checks in CI

`.github/workflows/godot.yml`: on pull requests (and pushes) that touch `godot/`, the lint, the import, the script load,
the GUT tests and the main-scene start. On a tag `v0.3.*`, the Windows zip and a smoke start on a Windows runner.
A guard job fails any pull request that changes a file under `hexa/` (frozen since v0.2.2).

The `map` job (0.3.0 item 4) rebuilds the map file, compares it byte for byte with the committed one, and puts the map
check report in the job summary. Still to come with their releases: the goldens (screenshot tests per scene), the bands
and soak jobs.
