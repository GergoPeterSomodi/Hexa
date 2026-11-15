# Hexa in Godot

The Godot version of Age of Discovery. The standard is `docs/architecture/godot-architecture.md` (decided 2026-11-15);
this page is its short form for the folder. Windows builds only. The Python game in `hexa/` is frozen at v0.2.2 and is
the gameplay reference, not something to edit. The game itself arrives milestone by milestone (section 9 of the
standard). Today the project opens on the **north Italy map** (`shell/worldmap/north_italy_map.tscn`, the main scene):
the 28 km district map with its pieces, the four seasons, select, build, upgrade and clear. The 0.3.0 Europe map, its
builder and the Kenney bake are retired.

## Engine

- Godot **4.7.2-stable**, standard build (not .NET), Compatibility renderer, GDScript. Pinned here, in CI and in
  `project.godot`. Upgrade only between releases, with the tests green before and after.
- Set the `GODOT` environment variable to the engine executable. Nothing in the repository holds a local path.
  - PowerShell: `$env:GODOT = "C:\path\to\Godot_v4.7.2-stable_win64_console.exe"`
  - Git Bash: `export GODOT=/c/path/to/Godot_v4.7.2-stable_win64_console.exe`

## Layout

```
project.godot           engine pin, warning levels, main scene, GUT plugin
core/                   plain GDScript, extends RefCounted, no Node, no scene tree, runs headless
  rng.gd  hexgrid.gd  geo.gd   luck (the only source), the one hex grid (HexGrid), the Mercator projection
  defs/                 definitions (Resource classes)                 empty until M1
  state/                the facts: WorldRegion, WorldHeights, ReliefLevels (the fixed map data)
  systems/              the rules: WorldImprove (the improvement of each hex) with ImproveRules (tables and cell and
                        pair rules) and ImproveSolver (the wave function collapse search)
  game/ ai/ views/      Game, the action table, the season table, AI, "what to draw" lists   empty until their milestones
  mapgen/               generators, run in tools and tests only: WorldRelief, WorldWater (with WaterCurves and
                        WaterSearch), WorldCover, WorldPlaces, WorldRoads
shell/                  everything with Nodes
  worldmap/             the north Italy map scene and its layers (replaced by shell/map in M1)
  app/ map/ hud/ panels/ screens/ ui/ input/ editor/ autoload/   empty until their milestones
tests/core/ tests/shell/ tests/fixtures/     GUT tests (test_*.gd)
tools/                  headless GDScript tools (check_scripts.gd; worldmap/ for the map: improve_report.gd,
                        shot_north_italy.gd, render_region.gd, compose_side_by_side.gd)
data/                   data: geography/ (JSON from Python), worldmap/ (the north Italy region and heights), the
                        exported goods, units, buildings, countries and terrain. See data/README.md
assets/worldmap/        the baked map art (see assets/worldmap/README.md)
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
- **Actions are pairs:** `x_check(...)` and `x(...)`; later they are registered in `core/game/actions.gd` and go through
  `Game.act`. The shell changes state only through actions.
- **Autoloads:** exactly two, both in the shell, both arriving with the milestone that needs them: `Session` (holds the
  current `Game`; the only door from the shell to the rules) and `Events` (the bus, one signal per event kind). None
  exists yet. `core/` never reads an autoload. Any other autoload needs a line here and a reason reviewed by the
  technical director.
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

# GUT tests, headless, with a JUnit report
"$GODOT" --headless --path godot -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit -gjunit_xml_file=gut-junit.xml

# Windows build (needs the export templates of the same version installed)
"$GODOT" --headless --path godot --export-release "Windows Desktop" build/Hexa.exe

# The improvement step in numbers per seed: search time, backtracks, pieces by family and level, rule breaks
"$GODOT" --headless --path godot -s res://tools/worldmap/improve_report.gd -- --seeds=1480,1481

# Pictures of the north Italy scene and its frame rate (windowed: nothing is drawn headless)
"$GODOT" --path godot -s res://tools/worldmap/shot_north_italy.gd -- --out=<absolute folder>
```

The editor: open `godot/project.godot` with the same engine. GUT shows in the editor's plugin list.

## The map scene

Keys: 1 to 4 the season, R a new seed, V the unnamed villages on or off, G the hex grid, F the whole map, H the panel;
drag or WASD to move, the wheel to zoom. A left click selects a hex; the panel builds, upgrades (U) and clears it; a
right click or Esc clears the selection. The art is baked by `tools/worldmap/bake_map_art.py` and
`tools/worldmap/godot_bake/` (Python); the rules are `core/systems/world_improve.gd`.

## Checks in CI

`.github/workflows/godot.yml`: on pull requests (and pushes) that touch `godot/` or `tools/`, the lint, the import, the
script load, the main-scene start and the GUT tests. On a tag `v0.3.*` (or by hand), the Windows zip and a smoke start
on a Windows runner. A guard job fails any pull request that changes a file under `hexa/` (frozen since v0.2.2). Still to
come with their milestones: the map rebuild check (the committed map file is what the builder makes), the goldens, the
performance and soak jobs.
