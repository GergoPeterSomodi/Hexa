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
```

The editor: open `godot/project.godot` with the same engine. GUT shows in the editor's plugin list.

## Checks in CI

`.github/workflows/godot.yml`: on pull requests (and pushes) that touch `godot/`, the lint, the import, the script load,
the GUT tests and the main-scene start. On a tag `v0.3.*`, the Windows zip and a smoke start on a Windows runner.
A guard job fails any pull request that changes a file under `hexa/` (frozen since v0.2.2).

Still to come with their releases (not in 0.3.0 step 1): the map rebuild and map check, the goldens (screenshot tests
per scene), the bands and soak jobs, and the speed probe.
