# Hexa in Godot

The Godot version of Age of Discovery. The standard is `docs/architecture/godot-architecture.md` (decided 2026-11-15);
this page is its short form for the folder. Windows builds only. The Python game in `hexa/` is frozen at v0.2.2 and is
the gameplay reference, not something to edit. The game itself arrives milestone by milestone (section 9 of the
standard).

At M1.5 / M1.5b (Studiolo UI foundation + Mac half-res atlases) with **M2 Countries in progress (`C1`–`C19` merged; `C20` remaining)**, the project opens on the `App` root (`shell/app/app.tscn`, the main scene),
booting to the Studiolo main menu: **New game** starts the scenario "Italy, 1480" (you choose your country on the map: the
pick, then Play as), and `Map sandbox` launches the plain **north Italy map** with no countries (`shell/map/map_scene.tscn`):
the 28 km district map on stacked hex `TileMapLayer`s with its pieces, crossings, place names, far picture, borders,
map-mode overlay (`Terrain`, `Owner`, `Relief`), country labels, capital pennants, and select, build, upgrade and clear
through `Session.act`. Pass `-- --new-game [--scenario=north_italy_1480] [--country=GEN] [--seed=N]` to start the scenario
at once (with `--country` there is no pick), `-- --sandbox [--seed=N]` to boot straight into the map, or `-- --plain-ui` to
run with the flat high-contrast/low-memory theme. The 0.3.0 Europe map, its builder, the Kenney bake and the whole-map
prototype scene are retired.

**M4 Economy (the shell is wired; the owner's playtest is next).** A country now has **money and goods**. The top bar shows the
**Ducats** and **Stores** chips (hover for the closed ledger and the stores; a click opens the study), a **study button**
and the date with End turn. Every work costs ducats (and, from the second stage, goods): the hex panel lists the works of
the selected hex with their cost and a few chips; hovering a row, its (i) button, or `U` opens the **works card** beside the
panel (what the work brings season by season, where it lands, its cost, its payback) and draws its ghost and labels on the
map. The option **Confirm works** (Off, Expensive only, Always) decides whether a click, or `U`, begins a work at once or
opens the card first; **Preview on the map** turns the ghost off. `Ctrl+Z` / `Cmd+Z` gives the ducats of a work begun this
season back. The season report has a Treasury and a Goods section, and **the Statesman's Study** (`I`, or `L` for its
Economy page; the chips, the country panel and the report's "Open the study" open it too) shows This season: money in,
money out, your spending, the expected change, the **tax level** (Low, Normal, High) and the last twelve seasons. The map
sandbox has no treasury: no chips, and `I` says so. The developer console takes `money N [TAG]`, `goods KEY N [TAG]` and
`tax low|normal|high`.

**M4.5 Insights (the App is wired; the owner's playtest is next).** The study grows three pages. **Economy** has four tabs:
*This season*, *Districts* (your land ranked by what it earns a year, with Look there and Show on the map), *Goods* (what
runs short, and when) and *History* (the treasury, season by season, with a ledger that adds up). **Rankings** sets you
against the countries you know (land, income and more; others are shown as bands such as "about 58"). **History** is the
chronicle of what you may know, on a timeline of seasons with filters. Key `4` is the **Yields** map mode: your land in
greens, darker where it earns more, others' land under a veil, with a legend top left. In a map-only game `4` says "No
countries on this map", and while you are still picking a country it asks you to choose one first. In a game with countries,
the headers of older seasons in the action log open History at that season. The study warms its pages in the background
after each season (`shell/app/study_warm.gd`), and F3 shows the page last built and the warm queue.

**M5 People (the App is wired; the owner's playtest is next).** The land now has **people**. The top bar gains the **People**
and **Food** chips beside Ducats and Stores (hover for the season's change and what was eaten; a click opens the study at its
**People page**, which the study's `[` `]` and `I` reach too) and a fifth map mode: key `5` is **Food**, your land coloured by
the food it makes less the food it eats a year, with a legend top left. In a map-only game `5` says "No countries on this
map", and while you are picking a country it asks you to choose one first; the sandbox has no chips and no People page. The
**People page** lists your towns with their room and outlook, the countryside, the food line and two charts, with Look there
and Show on the map (which switches to Food). Towns grow a level when they are full and fed, and fall when they are not; the
hex panel, the hover card, the report, the task flag and the log tell of it. The developer console takes `people c r N`
(sets the people of a hex, for tests of growth and hunger), and F3 shows a people line (the phase time, the levels that grew
and fell last season, the countries that went hungry).

**M6 Armies (the App is wired; the owner's playtest is next).** Armies walk the map. The **Raise** tab of an own settlement's hex
panel (its Works | Raise segment) raises companies, and the **Army chip** (men under arms) appears with the first one. A token
on the map is an army: a click selects it (or, on a hex with several, the next one), and its **army panel** opens in the dock:
Hold, Continue march, Split off, Join and Disband, Raise here, its supply and its upkeep. A right click on a hex (or `O` at
the cursor) orders a march, which walks at once (below); with an army selected a right click on its own hex halts it, and with
none it opens the hex menu. `Tab` selects the next army that needs orders, `R` continues a halted march, Alt+arrows move the
cursor (the route follows, and the move card says what the way costs). Key `6` is **Supply**: where your armies are fed, your land striped where it starves;
the Layers popover's **Sight** switch shades what you cannot see. The Army chip opens the **Military** page (`[` `]` reach it
too), the report has an **Armies** section, and `Esc` clears a selected army before anything else. The developer console takes
`raise c r kind [n]`, `march ID c r`, `hold ID`, `armies` and `as TAG action ...`; F3 shows an armies line. The movement replay
(`game/movement`) plays your own walk as you order it and the computer's walks after the season; Space skips it.

**M7 War (the App is wired; the owner's playtest is next).** A neighbour's country panel has **Declare war** (it asks first);
at war it shows the score and three peace buttons, **Take what you hold**, **White peace** and **Yield**, each asking first. A war
declared on you shows a **War!** alert at once on the map, or after the moves and before the report in a season. Armies enter
enemy land and fight: a right click on an enemy army or a fortress orders an attack or a siege, and the odds card (in place of the
move card) names the odds and the way: Favourable, Even or Poor. **Ctrl+right click** (or **Shift+O** at the cursor) storms a
fortress with the selected army. The army panel's **If attacked** segment sets Hold or Withdraw. A battle fought last season has a
badge on the map; a click, a report or log line, a notification's Go, the Military page's Battles table, the army panel's last
battle, the hex menu or **B** (the last battle you fought) opens the **battle dock** on the left, day by day (Left, Right, Home,
End, Enter plays); `Esc` closes it before anything else on the map. A siege shows a dial on its fortress. With an army selected and
a war on, the Layers popover's **Castle areas** switch (also in Options, Map) draws the land each enemy castle holds. The
developer console takes `declare TAG`, `peace TAG take|white|yield`, `storm ID c r`, `standing ID hold|withdraw` and `wars`
(with `as TAG` before an action: `as MLO declare SAV` gives the player a war); the sandbox has no war. F3 shows a war line (wars,
battles, sieges, occupied hexes, phase times, area hexes). The war UI answers only from milestone 7
(`Bindings.SHELL_MILESTONE`).

**Moves in the month (issue 432; built, the owner's playtest next).** An order to march **walks the army in the same click**,
as far as its move points of the season reach (the slowest company's: knights 16, pikemen and crossbowmen 12, bombards 8), and
the move is final. An army may be ordered again until its points are spent (the mark on its token and the panel show them). A
longer route stays as a standing march, one leg at the end of each later season. A walk stops when an unseen enemy army comes
into sight (points kept, `R` goes on) and beside an enemy (the season is over); unmapped land takes a whole season a step. An
attack is fought at once (automatically until the battle board) and the dock opens after the walk. A move that opens a battle,
enters enemy land or ends out of supply asks once (`game/confirm_moves`, "Confirm risky moves"). Paths: **Shift+right click** or
`V` orders at once (a march; each further click adds a point to its end; on the last point it removes it, the only one halts;
at most 6 points before the goal), a plain right click replaces the path, and holding `Shift` previews the longer path. In the
season a country declares a war its armies may not enter that enemy's land (the player's too). The computer moves by the same rules at the end of the season. Design `docs/design/moves-in-the-month.md`, rules
`docs/architecture/moves-build-spec.md`; save format 8 (older saves are refused as an older test build).

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
  defs/                 definitions (Resource classes): map_data.gd (MapData), country_def.gd (CountryDef),
                        colour_contrast.gd (ColourContrast), scenario_def.gd (ScenarioDef),
                        game_defs.gd (GameDefs), scenario_growth.gd (ScenarioGrowth)
  state/                changing state: map_state.gd (MapState schema 2), country.gd (Country),
                        plus WorldRegion, WorldHeights, ReliefLevels
  systems/              the rules: improve.gd (Improve: build/upgrade/clear actions, home rule,
                        WorldImprove, ImproveRules, ImproveSolver), territory.gd (Territory),
                        countries.gd (Countries)
  game/                 game.gd (Game), actions.gd (the action table)
  views/                pure "what to draw" helpers: map_tiles.gd, map_cells.gd, edge_lines.gd, crossings.gd,
                        far_picture.gd, hex_card.gd, border_lines.gd, map_modes.gd, country_names.gd,
                        country_card.gd, place_search.gd
  ai/                   the computer's turn (M8): AiKnow (the one door to what a seat may know), AiBrief, AiTurn and its step
                        modules (AiEconomy, AiForces, AiWar, AiPeace), AiTrace, AiPlayers; it reads what the panels read
  mapgen/               generators, run in tools and tests only: WorldRelief, WorldWater (with WaterCurves and
                        WaterSearch), WorldCover, WorldPlaces, WorldRoads, climate.gd, fake_map.gd
shell/                  everything with Nodes (Studiolo UI architecture)
  autoload/             session.gd (Session) and events.gd (Events)
  app/                  app.tscn + app.gd (main scene root), settings.gd (user://settings.cfg),
                        settings_io.gd, display.gd, shell_context.gd, app_routes.gd (map and HUD requests),
                        game_requests.gd (the M3 handlers: the season flow and report, F5/F9, Save and Load,
                        Continue, bookmarks, undo, the running lock and recovery, the toasts of works with their
                        ducats), works_flow.gd (WorksFlow, M4: the works card and its map marks, Begin and Cancel,
                        the study, the tax toast), study_warm.gd (StudyWarm: warms the study's views), season_flow.gd (SeasonFlow),
                        bookmarks.gd, thumbnail.gd, run_lock.gd
  input/                bindings.gd (InputMap & gestures), zoom_model.gd, esc_ladder.gd,
                        app_input.gd, camera_rig.gd, map_input.gd
  ui/                   tokens.gd, theme.tres, theme_high_contrast.tres, kit_theme.gd (1x/2x/plain),
                        motion.gd, screen.gd, screen_stack.gd, country_arms.gd (CountryArms),
                        kit controls & frames (KitButton, PanelFrame, ModalFrame, VellumSheet, HoverCard,
                        ToastHost, OptionRow, KeyCap, Segmented, NavList, Cartouche, Ribbon, PanelKit,
                        Medallion, DeltaChip, SeasonStrip, PreviewCard, InkChart, StudyTable,
                        RelationMatrix, ResourceChip)
  hud/                  hud.tscn + hud.gd, top_bar (arms, country name, mode switch, the chips and the study
                        button, date and End turn), chips (Ducats, Stores), date_end, action_log (bottom left), the TopRight column (task_flag, notifications),
                        layers_popover (no season buttons: F3's Look previews seasons),
                        zoom_control, scale_bar, minimap, map_hover, key_hints, debug_overlay (F3)
  screens/              screen_ids.gd, main_menu, new_game, country_pick, find_place, sandbox, pause_menu,
                        options (+ options_keys), about, credits, confirm, loading, help_overlay, season_report,
                        works_preview (the works card), study (+ study/page_economy, page_rankings, page_history)
  map/                  map_scene.tscn + map_scene.gd (the map scene), mode_overlay.gd (.gdshader),
                        capital_marks.gd, preview_marks.gd (the card's ghost, tint and labels), hex_panel_contract.gd
  mapview/              tile_map_view.gd, tileset_builder.gd, edge_line_layer.gd, far_map.gd, map_labels.gd,
                        country_labels.gd, shadow_cover.gdshader
  panels/               hex_panel.tscn + hex_panel.gd, country_panel.tscn + country_panel.gd (the dock shows
                        one panel at a time)
  editor/               scenario_editor.tscn + scenario_editor.gd (@tool scenario editor, helpers & UI)
tests/core/ tests/shell/     GUT tests (test_*.gd, scenario_fixture.gd, ui_harness.gd, test_ui_monkey.gd),
                             perf_budget.json, perf_ui_budget.json
tools/                  GDScript tools: check_scripts.gd, build_map.gd, build_scenario.gd, build_tileset.gd,
                        build_theme.gd, perf_map.gd, map/probe_mode_overlay.gd, mapview/probe_ysort.gd,
                        worldmap/improve_report.gd, ui/{shot_ui.gd,perf_ui.gd,shot_menu_map.gd,
                        probe_display.gd,probe_input.gd}, probes/{probe_ui_fonts.gd,probe_textures.gd}
data/                   data: maps/north_italy.tres, defs/{game_defs.tres,countries/*.tres},
                        scenarios/north_italy_1480.tres, geography/ (JSON from Python), worldmap/ (the north Italy region
                        and heights), the exported goods, units, buildings, countries and terrain. See data/README.md
assets/fonts/           static OFL fonts (Cinzel, Alegreya, Alegreya SC, Alegreya Sans, Noto Sans fallback)
assets/ui/              baked Studiolo kit textures (kit/ui_kit.json, kit/1x/, kit/2x/) and menu/ art
assets/tiles/           the six baked tile sets (spring, summer, autumn, winter_snow, winter_frost, winter_mild),
                        half/ (0.5x atlases for Mac/Low quality), and the committed TileSets
                        tiles_<season>.tres and tiles_<season>_half.tres
addons/gut/             GUT 9.7.1, copied unchanged from its release (MIT, see addons/gut/LICENSE.md)
```

## Rules

- **Layers, one way:** bottom to top `defs`, `state`, `systems`, `game`, `views`, `ai`, `shell`. A file may use its own
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
- **Scenes are text** (`.tscn`), laid out with containers and the generated Studiolo Theme. No hand-placed pixel positions,
  no `theme_override_` in `shell/**/*.tscn`, and no raw `Color(`, `StyleBoxFlat.new`, `StyleBoxTexture.new`, or
  `assets/ui/kit` paths in `shell/{ui,hud,screens,panels,app}/` outside `tokens.gd` and `kit_theme.gd` (`tools/lint_godot.py`).
- **A refactor never rides with a behaviour change.**

## Fog (two levels)

- **Deep fog** is a hex the country has never discovered: nothing of it is shown, and the hex card says "Unexplored".
- **Light fog** is a discovered hex not in sight: its land is shown exact and live; armies, their orders and routes, and
  battles the country did not witness are hidden.
- **In sight** is a hex the country's land or armies see now (the control of the hex and its ring, `Sight`).
- One rule for every view, the map modes, the minimap, the logs and the AI: `Knowledge.discovered`, `Knowledge.sees` and
  `Knowledge.garrison_known` in `core/views/knowledge.gd`; the AI reads other countries only through `AiKnow`. The discovered
  set is `Country.explored`; its five writers are listed in `tests/core/test_no_other_writers.gd` (R11). The deep-fog fill is `MapModes.discovered_bytes`.
- The thin test fixture `FogFixture.thin(g, tag, radius)` (`tests/core/fog_fixture.gd`) makes a thin start on purpose:
  north Italy starts with every hex discovered, so deep fog shows in play only on a thin start or on the Europe map.
- Pictures of the fog: `docs/design/ui/fog/` (made by `tools/ui/shot_ui_fog.gd`).

## Commands

Run from the repository root (the folder that holds `godot/`), with `GODOT` set.

```bash
# Import the project (creates .godot/; fails on any script error or warning)
"$GODOT" --headless --path godot --import

# Load every script: parse errors and warnings show here
"$GODOT" --headless --path godot --script res://tools/check_scripts.gd

# Layers, size limits, core/ rules, luck, Godot 3 spellings, UI style rules (text scan, plain Python)
python tools/lint_godot.py godot

# Open the main scene (shell/app/app.tscn) and quit at once
"$GODOT" --headless --path godot --quit

# Start the scenario at once as Genoa (leave out --country to see the pick), the North Italy sandbox, or flat high-contrast UI
"$GODOT" --path godot -- --new-game --country=GEN --seed=1480
"$GODOT" --path godot -- --sandbox --seed=1480
"$GODOT" --path godot -- --plain-ui

# Check or rebuild the Studiolo UI bake (needs Python 3.12 + tools/requirements-bake.txt) and generated Themes
python tools/bake_ui.py --check
python tools/bake_ui.py
python -m unittest tests/test_bake_ui.py
"$GODOT" --headless --path godot -s res://tools/build_theme.gd -- --check
"$GODOT" --headless --path godot -s res://tools/build_theme.gd

# Check or rebuild the committed TileSets (full and half), map (data/maps/north_italy.tres), and scenarios
"$GODOT" --headless --path godot -s res://tools/build_tileset.gd -- --check
"$GODOT" --headless --path godot -s res://tools/build_tileset.gd -- --half
"$GODOT" --headless --path godot -s res://tools/build_map.gd -- --check
"$GODOT" --headless --path godot -s res://tools/build_scenario.gd -- --check
# Rebuild the committed scenario files (pins, owner bytes, map digest); --scenario=<id> picks one
"$GODOT" --headless --path godot -s res://tools/build_scenario.gd

# GUT tests, headless, with a JUnit report (includes tests/shell/test_ui_monkey.gd)
"$GODOT" --headless --path godot -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit -gjunit_xml_file=gut-junit.xml

# Windows build (needs the export templates of the same version installed)
"$GODOT" --headless --path godot --export-release "Windows Desktop" build/Hexa.exe

# The improvement step in numbers per seed: search time, backtracks, pieces by family and level, rule breaks
"$GODOT" --headless --path godot -s res://tools/worldmap/improve_report.gd -- --seeds=1480,1481

# Speed measurement on the 494 x 247 fake Europe map against tests/perf_budget.json (windowed)
"$GODOT" --path godot -s res://tools/perf_map.gd

# UI screenshots (1x and 2x), UI perf/memory probe, and display/input/texture probes
"$GODOT" --path godot -s res://tools/ui/shot_ui.gd -- --out=/tmp/hexa_ui_shots
"$GODOT" --path godot -s res://tools/ui/perf_ui.gd
"$GODOT" --path godot -s res://tools/ui/probe_display.gd
"$GODOT" --path godot -s res://tools/ui/probe_input.gd
"$GODOT" --path godot -s res://tools/probes/probe_textures.gd
```

The editor: open `godot/project.godot` with the same engine. GUT shows in the editor's plugin list.

**The scenario editor** (`shell/editor/scenario_editor.tscn`, `@tool`): open the scene in the Godot editor. It shows the
scenario on the game's own layers (tiles, Owner overlay, borders, seeds). Select the `Pins` layer and paint pins with
Godot's TileMap tools (a painted cell is a pin, an erased cell no pin); territory regrows as you paint. The inspector
buttons are **Regrow**, **Write the scenario** (pins, owner and map digest go into `data/scenarios/<id>.tres`, then a
check) and **Check** (the deep validation; its lines go to `facts` and the Output panel). Run
`build_scenario.gd --check` afterwards to see that the committed file is current.

## App, Controls & Map Scene

- **Main scene:** `shell/app/app.tscn` (`App`) owns `AppInput`, `World` (`MapScene`, created on game start and freed on
  exit), `Hud` (`CanvasLayer 10`), and `Screens/Stack` (`ScreenStack` on `CanvasLayer 20`). Settings persist in
  `user://settings.cfg` (`Settings`), with a 10 s `Confirm` revert for display/window/UI-scale changes.
- **Default bindings** (`shell/input/bindings.gd`, `Bindings.DEFAULTS`):
  - **Camera:** `WASD` / arrows (pan; hold `Shift` for fast pan), `=` / `+` / `Kp+` (zoom in), `-` / `Kp-` (zoom out), `F` / `Home` (fit whole map).
  - **Map & View:** left click (select hex; a click on one of your unit tokens selects that unit instead, and each further click on a stack takes its next army; a hex with a unit on it still selects the hex), right click (clear selection), `1`–`6` (map modes Terrain / Owner / Relief / Yields / Food / Supply; Owner, Yields, Food and Supply are refused with a toast in a map-only game, and Yields, Food and Supply while picking), `G` (hex grid), `N` (place names), `C` (your country's panel; while picking, focus to the country list), `Ctrl+F` / `Cmd+F` (find a place or country), `H` (hide HUD / photo mode), `U` (the works card for the selected hex's upgrade, or its first build on wild land; with Confirm works Off, or Expensive only for a cheap work, it begins the work at once).
  - **The pick:** click a country's land or choose it in the list (`Up` / `Down`, `Enter` shows it, `Enter` again plays it), or `Play as` in its panel; `Esc` closes the panel, then asks for the pause menu (the pick cannot be skipped).
  - **Time & saves (M3):** `Space` / `Enter` (end the season; a second one inside 400 ms of the report closing is refused), `J` (the last season report), `F5` / `Ctrl+S` / `Cmd+S` (quicksave), `F9` / `Ctrl+L` / `Cmd+L` (quickload; asks first when actions are unsaved), `Ctrl+Z` / `Cmd+Z` (cancel the work begun last this season), `Ctrl+Shift+1..9` (set camera bookmark), `Ctrl+1..9` (go to it), `F2` (the developer console at the foot of F3, developer tools on).
  - **Economy (M4):** `I` (the Statesman's Study on its last page), `L` (the study's Economy page), `[` `]` (study pages: Economy, Rankings, History), `Ctrl+[` `Ctrl+]` (`Cmd` on a Mac: the tabs of the page, as Economy's four), `Enter` or `U` on a works card (begin the work), `Esc` (close the card or the study), `Shift` (keep a hovered card while the pointer is away).
  - **Saves:** `user://saves/` holds `quick`, `1` to `8` and `auto1` to `auto3` (`.sav`, `.png`); the program writes `user://running.lock` while a game runs and asks to load the newest autosave when it finds one left behind. Continue on the main menu loads the newest save and falls back to older ones when its body is damaged. The shell's key milestone is `Bindings.SHELL_MILESTONE` (`"8"`); the Options screen shows the rows up to `Options.TARGET_MILESTONE` (7).
  - **Armies (M6, M7, moves):** with an army selected, right click or `O` / `Shift+F10` (march at the cursor; on its own hex, halt), `Ctrl+right click` or `Shift+O` (storm), `Shift+right click` or `V` (add a path point, or remove the last), `Tab` (next army), `R` (continue a halted march), Alt+arrows (move the order cursor), `B` (the last battle you fought). While your own walk is shown, `Space`, `Enter` or `Esc` skip it and do nothing more; a click or an order skips it and then acts.
  - **App & Dev:** `Esc` (Esc ladder: console field → popover → top screen → army selection, country panel or hex selection → pause menu), `M` (pause menu), `F1` / `?` (help overlay), `F3` / `` ` `` (debug panel), `Ctrl+R` / `Cmd+R` (new seed), `F11` / `Alt+Enter` / `Ctrl+Cmd+F` (fullscreen), `F12` (screenshot to `user://screenshots/`).
- **Pointer & trackpad gestures** (`shell/input/camera_rig.gd`):
  - With an army of yours selected: right click orders its march, `Shift+right click` orders its path (a point added to the end; on the last point it removes it), `Ctrl+right click` storms (with no army selected both act as a plain right click does); `Shift+left click` selects the hex.
  - Mouse wheel (or `Ctrl+wheel` pinch on Windows/Linux) zooms about the pointer (`Shift+wheel` or tilt wheel pans sideways).
  - Mac trackpad two-finger scroll (`InputEventPanGesture`) pans at `GESTURE_PAN_PX` (20 px per delta unit); trackpad pinch (`InputEventMagnifyGesture`) zooms directly about the fingers; left/middle/right drag past `CLICK_SLOP` (6 px) pans 1:1.
- **Tiles & Map:** tiles are baked by `tools/worldmap/tileset_bake/bake.py` and assembled into `assets/tiles/tiles_<season>.tres` (full) and `assets/tiles/tiles_<season>_half.tres` (0.5× atlases in `assets/tiles/half/`, default on macOS `gl_compatibility` and in the Low preset to avoid `BPTC_RGBA -> RGBA8` 4× VRAM expansion; `import_etc2_astc` is also enabled in `project.godot`) by `tools/build_tileset.gd`; `data/maps/north_italy.tres` is built by `tools/build_map.gd`; the rules are `core/systems/improve.gd`.

## The computer's turn (M8)

- **The AI:** every country but the player's plays each season through `Session` (`begin_season`, `step_orders(budget_ms)`,
  `finish_season`). The App runs the turn in slices of a few milliseconds, so the map and the panels stay live; the busy pill
  (top centre of the map, `shell/hud/busy_pill.gd`) says "Countries are moving 3 / 12", then "The moves of Summer 1480" while the
  replay plays. While the computer moves or its moves replay, the map takes no orders (a click toasts why); panning, zooming and
  the Layers stay free, and a camera move makes the slices shorter. The replay shows the walks in view (the view grown by two
  hexes). `AiTurnUI` (`shell/app/ai_turn_ui.gd`) holds this wiring; `GameRequests` owns it.
- **Watching:** the console's `watch` (during the country pick) makes every country computer-played: the pick ends and the top
  bar shows an "S" seal with "Watching". `ai off` and `ai on` play every seat passively or back; `ai TAG` prints that seat's
  last turn; `ai pass TAG` and `ai play TAG` play one seat. The console is `F2` with developer tools on.
- **The soak** (nightly): all-AI games with invariants checked every season, its tables and ranges in JSON and a summary:
  `"$GODOT" --headless --path godot -s res://tools/soak.gd -- --suite=ai --seeds=1-25 --seasons=80 --out=soak.json`
  (`--quick` for a short run; a failure prints its replay line and exits 1).
- **Alerts:** a war on the player and a peace that ends one are queued as Confirms: shown at once when no season runs, else in
  the season's decisions, before its report.

## Checks in CI

`.github/workflows/godot.yml`:
- `checks`: on pull requests (and pushes) touching `godot/` or `tools/`, runs Python 3.12 UI bake verification (`tools/bake_ui.py --check`, `tests/test_bake_ui.py`), Godot `--import`, `tools/lint_godot.py`, `tools/check_scripts.gd`, main-scene headless start (`--quit`), `build_theme.gd --check`, `build_tileset.gd --check`, `build_map.gd --check`, `build_scenario.gd --check`, and the full GUT suite.
- `ui-shots`: on pull requests touching `shell/{app,ui,hud,screens,input}/` (or manual dispatch), renders 1x/2x UI screenshots (`shot_ui.gd`) and checks UI budgets (`perf_ui.gd`) under `xvfb-run` + Mesa.
- `perf`: nightly (and manual dispatch), `tools/perf_map.gd` on the fake Europe map.
- `export-windows` / `smoke-windows`: on a tag `v0.3.*` (or manual dispatch), builds the Windows zip and runs a smoke start on a Windows runner.
- `frozen-python`: fails any pull request that changes a file under `hexa/` (frozen since v0.2.2).
