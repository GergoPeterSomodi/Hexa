# Hexa in Godot

The Godot version of Age of Discovery. The standard is `docs/architecture/godot-architecture.md` (decided 2026-11-15);
this page is its short form for the folder. Windows builds only. The Python game in `hexa/` is frozen at v0.2.2 and is
the gameplay reference, not something to edit. The game itself arrives milestone by milestone (section 9 of the
standard). Today the project opens on the **north Italy map** (`shell/map/map_scene.tscn`, the main scene):
the 28 km district map on stacked hex `TileMapLayer`s with its pieces, crossings, place names, far picture, the four
seasons, and select, build, upgrade and clear through `Session.act`. The 0.3.0 Europe map, its builder, the Kenney bake
and the whole-map prototype scene are retired.

## Engine

- Godot **4.7.2-stable**, standard build (not .NET), Compatibility renderer, GDScript. Pinned here, in CI and in
  `project.godot`. Upgrade only between releases, with the tests green before and after.
- Set the `GODOT` environment variable to the engine executable. Nothing in the repository holds a local path.
  - PowerShell: `$env:GODOT = "C:\path\to\Godot_v4.7.2-stable_win64_console.exe"`
  - Git Bash: `export GODOT=/c/path/to/Godot_v4.7.2-stable_win64_console.exe`

## Layout

```
project.godot           engine pin, warning levels, main scene, autoloads (Session, Events), GUT plugin
core/                   plain GDScript, extends RefCounted (or Resource in defs/), no Node, no scene tree, runs headless
  rng.gd  hexgrid.gd  geo.gd   luck (the only source), the one hex grid (HexGrid), the Mercator projection
  defs/                 definitions (Resource classes): map_data.gd (MapData)
  state/                changing state: map_state.gd (MapState), plus WorldRegion, WorldHeights, ReliefLevels
  systems/              the rules: improve.gd (Improve: build/upgrade/clear actions and checks) with WorldImprove,
                        ImproveRules and ImproveSolver (the wave function collapse search)
  game/                 game.gd (Game), actions.gd (the action table)
  ai/                   empty until its milestone
  views/                pure "what to draw" helpers: map_tiles.gd, map_cells.gd, edge_lines.gd, crossings.gd,
                        far_picture.gd
  mapgen/               generators, run in tools and tests only: WorldRelief, WorldWater (with WaterCurves and
                        WaterSearch), WorldCover, WorldPlaces, WorldRoads, climate.gd, fake_map.gd
shell/                  everything with Nodes
  autoload/             session.gd (Session) and events.gd (Events)
  map/                  map_scene.tscn + map_scene.gd (the map scene), hex_panel_contract.gd
  mapview/              tile_map_view.gd, tileset_builder.gd, edge_line_layer.gd, far_map.gd, map_labels.gd,
                        shadow_cover.gdshader
  panels/               hex_panel.tscn + hex_panel.gd
  ui/                   theme.tres, panel_kit.gd
  input/                map_input.gd
  app/ hud/ screens/ editor/   empty until their milestones
tests/core/ tests/shell/     GUT tests (test_*.gd) and perf_budget.json
tools/                  GDScript tools: check_scripts.gd, build_map.gd, build_tileset.gd, perf_map.gd,
                        mapview/probe_ysort.gd, worldmap/improve_report.gd
data/                   data: maps/north_italy.tres, geography/ (JSON from Python), worldmap/ (the north Italy region
                        and heights), the exported goods, units, buildings, countries and terrain. See data/README.md
assets/tiles/           the six baked tile sets (spring, summer, autumn, winter_snow, winter_frost, winter_mild) and the
                        committed TileSets tiles_spring.tres ... tiles_winter.tres
addons/gut/             GUT 9.7.1, copied unchanged from its release (MIT, see addons/gut/LICENSE.md)
```

## Rules

- **Layers, one way:** bottom to top `defs`, `state`, `systems`, `game`, `ai`, `views`, `shell`. A file may use its own
  layer or a lower one, never a higher one. `mapgen` sits beside `systems` and runs only in tools and tests.
  `tools/lint_godot.py` checks the `res://` paths; class names are not checked by it.
- **`core/` has no engine calls:** no Node, no scene tree (`get_tree`, `get_node`, `$`), no `Input`, `OS`, `Time`,
  `Engine`, `DisplayServer`, no `await`, no `Thread`, `Mutex` or `WorkerThreadPool`. Files only under `res://` and
  `user://`.
- **Luck through `rng.gd` only:** no `randi`, `randf`, `randomize`, `shuffle`, `pick_random` or `RandomNumberGenerator`
  in `core/` outside `rng.gd`.
- **Node, RefCounted or Resource:** designed ahead and read-only in play is a Resource (`core/defs/`, files in `data/`);
  changing during a game is a RefCounted or a packed array; seen or clicked is a Node (`shell/`). Nodes hold no facts.
- **Actions are pairs:** `x_check(...)` and `x(...)`, registered in `core/game/actions.gd` and called through
  `Session.act` / `Game.act`. The shell changes state only through actions.
- **Autoloads:** exactly two, both in the shell: `Session` (holds the current `Game`; the only door from the shell to the
  rules) and `Events` (the bus, one signal per event kind). `core/` never reads an autoload. Any other autoload needs a
  line here and a reason reviewed by the technical director.
- **Size limits:** a script over 800 lines needs a reason (an entry in `SIZE_REASONS` of `tools/lint_godot.py`), over
  1,200 it is split; a function over 100 lines is split. The lint checks both.
- **Godot 4 only:** no `yield`, `export var`, `onready var`, `setget`, string `connect(...)`, `.instance()`, `tool`
  (use `@tool`) or the old `TileMap` node.
- **Typed GDScript:** the warnings for untyped declarations, unsafe property and method access, integer division and
  narrowing conversions are errors (`project.godot`). Write `int(a / b)` only with a comment, and `7 / 2` is 3 here.
- **Scenes are text** (`.tscn`), laid out with containers and the one Theme. No hand-placed pixel positions.
- **A refactor never rides with a behaviour change.**

## Commands

Run from the repository root (the folder that holds `godot/`), with `GODOT` set.

```bash
# Import the project (creates .godot/; fails on any script error or warning)
"$GODOT" --headless --path godot --import

# Load every script: parse errors and warnings show here
"$GODOT" --headless --path godot --script res://tools/check_scripts.gd

# Layers, size limits, core/ rules, luck, Godot 3 spellings (text scan, plain Python, no pip packages)
python tools/lint_godot.py godot

# Open the main scene (the north Italy map) and quit at once
"$GODOT" --headless --path godot --quit

# Check or rebuild the committed TileSets (assets/tiles/tiles_<season>.tres) and map (data/maps/north_italy.tres)
"$GODOT" --headless --path godot -s res://tools/build_tileset.gd -- --check
"$GODOT" --headless --path godot -s res://tools/build_map.gd -- --check

# GUT tests, headless, with a JUnit report
"$GODOT" --headless --path godot -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit -gjunit_xml_file=gut-junit.xml

# Windows build (needs the export templates of the same version installed)
"$GODOT" --headless --path godot --export-release "Windows Desktop" build/Hexa.exe

# The improvement step in numbers per seed: search time, backtracks, pieces by family and level, rule breaks
"$GODOT" --headless --path godot -s res://tools/worldmap/improve_report.gd -- --seeds=1480,1481

# Speed measurement on the 494 x 247 fake Europe map against tests/perf_budget.json (windowed)
"$GODOT" --path godot -s res://tools/perf_map.gd
```

The editor: open `godot/project.godot` with the same engine. GUT shows in the editor's plugin list.

## The map scene

Keys: 1 to 4 the season, R a new seed, G the hex grid, N the place names, F the whole map, H the panel; drag or WASD
to move, the wheel to zoom. A left click selects a hex; the panel builds, upgrades (U) and clears it through
`Session.act`; a right click or Esc clears the selection. The tiles are baked by `tools/worldmap/tileset_bake/bake.py`
(Python) and assembled into `assets/tiles/tiles_<season>.tres` by `tools/build_tileset.gd`; the map resource
`data/maps/north_italy.tres` is built by `tools/build_map.gd`; the rules are `core/systems/improve.gd`.

## Checks in CI

`.github/workflows/godot.yml`: on pull requests (and pushes) that touch `godot/` or `tools/`, the lint, the import, the
script load, the main-scene start, the `build_tileset --check` and `build_map --check` guards, and the GUT tests.
Nightly (and by hand), `tools/perf_map.gd` on the fake Europe map. On a tag `v0.3.*` (or by hand), the Windows zip and a
smoke start on a Windows runner. A guard job fails any pull request that changes a file under `hexa/` (frozen since
v0.2.2).
