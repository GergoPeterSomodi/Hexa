# Hexa in Godot: the architecture (decided, 2026-11-15)

Technical director. **Status: the standard.** This page replaces the options draft of the same name and the technical
appendix of `docs/roadmap/godot-port-plan.md` (Parts B2 and B3). Where an older page disagrees, this one wins.
Nothing in the code changes with this document; the changes arrive milestone by milestone (section 9).

The engineering questions are answered here, not asked. Each section says **what we do**, **why it is the Godot
way**, and **what it means in practice**. Only three questions are left for the owner, all about the game (section 10).

**What the owner decided (2026-11-15):**

- **Windows only.** Web and phones are not requirements. We only avoid things that would block them later.
- **The 0.3.0 Godot map is retired** (the 57 km Europe, the Kenney tiles, its builder). The new map from the
  `map-proto` branch (28 km districts, the pieces) is the map.
- **The Python game v0.2.2 (`hexa/`) is the gameplay reference.** It was the last working game. We rebuild what it
  did in Godot, system by system. It is a guide to what each system must do, not code to copy line by line.
- **Step by step.** No big first slice. A row of small milestones, each adding one system, each playable and tested
  before the next starts.

---

## 1. Where we are

| Thing | Where | Verdict |
|---|---|---|
| Python game v0.2.2 | `hexa/` | Frozen. **The reference** for rules, numbers and lessons |
| Game designs | `docs/design/` | Ideas kept. Each is re-fitted to districts when its milestone comes |
| Map design | `docs/design/map/` 00 to 06 | **The base:** 28 km hexes, real heights, rivers on edges, one city one hex, 2D, the growing map |
| Project skeleton | `godot/` on `master`: layers, lint, GUT, CI, seeded luck | **Kept.** The best part of the 0.3.0 work |
| 0.3.0 map and builder | `core/mapgen`, `core/state`, `core/views`, `shell/map`, `data/maps/europe_1480.json`, `assets/baked` | **Retired** (section 8) |
| New map core | `map-proto`: `core/worldmap/` (about 4,900 lines, 2,500 of tests) | **Kept**, tidied and moved into the layers below |
| Prototype scene | `map-proto`: `shell/worldmap/north_italy_map.gd` (956 lines, does everything) | **Replaced** in M1 by the map view of section 3 |
| The art | `map-proto`: `tools/worldmap/` in Python (kit, 16 families, style frame, bake) | **Look kept. Bake changed** from whole-map pictures to a tileset (section 3.4) |

The game itself does not exist in Godot yet: no countries that act, no economy, no armies, no turns, no saves.

**The three faults this standard removes:**

1. **The bake cannot reach Europe.** It stores the ground as one picture per season and every wild tree as a line
   in a list (3,268 objects for 148 hexes). Europe is about 122,000 hexes: a picture of about 42,000 x 23,000 pixels
   per season. Reusable tiles fix this.
2. **The rules are fed by the art.** The build rules read their hex table from a file the art bake wrote. It must
   be the other way round: map data first; rules and art both read it.
3. **The scene does everything.** One script loads, generates, draws, handles input and builds the panel. That is
   the Python game's old fault. Layers fix this.

---

## 2. The shape of the game

```
   shell/   Godot nodes: what you see and click
            map view, HUD, panels, screens, input, the two autoloads
              | reads state, sends actions, hears events       (never writes state)
   ---------------------------------------------------------------------------
   core/    plain GDScript, no nodes, runs without a window
            ai       picks actions for a country (reads views, acts through Game.act)
            views    "what to draw" and "what a country may know" as plain lists
            game     Game, the action table, the season table, events, saves
            systems  the rules, one file per topic
            state    the facts of one game
            defs     the definitions (Resource classes)
```

**The one-way rule:** a file may use its own layer or a lower one, never a higher one. Bottom to top: `defs`,
`state`, `systems`, `game`, `views`, `ai`, `shell` (from M8: the AI reads the views the panels read, and no view needs the
AI; `m8-build-spec.md` D2. Before M8 the order named `ai` below `views`, while `core/ai/` was empty). `mapgen` sits beside
`systems` and runs only in tools. The lint checks this on every pull request. The season (game) runs the AI (ai) through
an orders hook that the AI subclasses, so no game file names an AI one (`m8-build-spec.md` 4.2).

**Node, RefCounted or Resource?** One rule for every new class:

| It is... | Use | Examples | Lives in |
|---|---|---|---|
| Designed ahead, the same in every game | **Resource** (`.tres`), read-only in play | A family and its levels, a good, a unit type, a country's start, the fixed map, the TileSets, the Theme | `core/defs/` (classes), `data/` (files) |
| Changing during a game | **RefCounted** (plain object) or a packed array | `Game`, the living map, `Country`, `Army`, `War` | `core/state/`, `core/game/` |
| Seen or clicked | **Node** (a scene) | Map layers, army tokens, panels, buttons | `shell/` |

The test for a Node: **delete every node, rebuild the screen from `Game`, and nothing is lost.** Nodes hold no
facts. This is what makes the game testable without a window and saves simple.

---

## 3. The map, the Godot way

### 3.1 The backbone: TileMapLayer

**Decision:** the map is a stack of `TileMapLayer` nodes that share one hex grid. The TileSet has tile shape
*hexagon*, layout *stacked*, offset axis *horizontal*: pointy-top hexes with odd rows shifted half a hex right. That
is our own odd-r grid, so a hex `(col, row)` in the rules is cell `(col, row)` on screen with no conversion. A test
pins that Godot's `map_to_local` / `local_to_map` and `core`'s grid agree for every hex.

**Why:** this is the engine's own tool for grids. It draws tiles in batches ("rendering quadrants" of 16 x 16
cells), draws only what the camera sees, sorts tall things by depth, and finds the hex under the mouse. We write
none of that. A cell costs a few bytes, so **the map's size costs almost nothing; memory is the atlas**, and the
atlas is the same size for north Italy and for Europe.

**In practice:** the cell size is fixed in whole pixels (about 104 x 102 at the play zoom, the present art's size
with its 0.85 tilt). The TileSet is the truth for sizes; the art bake follows it.

### 3.2 The stack, bottom to top

| # | Layer | Node | Filled from |
|---|---|---|---|
| 1 | Sea and coast | `TileMapLayer` | Sea tiles; on a land hex beside sea, a coast tile picked by which of its six sides are sea (63 shapes) |
| 2 | Ground cover | `TileMapLayer` | One tile per hex by cover (farmland, grass, woods, marsh, rock, snow, tundra, sand), a few variants each |
| 3 | Relief shading | `TileMapLayer`, multiply blend | One shade tile per hex by slope direction and steepness, from the heights |
| 4 | Piece ground | `TileMapLayer` | The flat part of a built piece: fields, yards, town ground |
| 5 | Rivers, roads, borders | One drawn node per chunk (32 x 32 hexes) | Lines from edge data (3.3) |
| 6 | Standing things | A **y-sorted group**: `TileMapLayer`s for wild decor (trees, hills, peaks) and for pieces (a back and a front band), plus the army tokens | Decor tile by cover and density; piece tile by family, level, variant |
| 7 | Country colour, fog | `TileMapLayer`s with one white hex tile, tinted per country | Owner per hex; what the player has seen |
| 8 | Highlights and selection | `TileMapLayer` and one cursor sprite | Move range, build targets, the selected hex |
| 9 | Names | Labels, only for what is on screen | Places, countries |

Notes on the Godot features used:

- **Ground blending (layer 2).** Ground tiles are drawn a little larger than the cell with a soft edge, and each
  cover has a rank (the tile's z-index), so woods spill softly onto grass, grass onto sand. We do **not** use
  TileSet terrain sets for cover: on hexes they need a tile for every mix of neighbours, and eight covers make
  thousands. Terrain-style matching is used only where the count is small: the coast (63 shapes).
- **Depth (layer 6).** The group and its layers have `y_sort_enabled`. Each tall tile carries its own
  `texture_origin` (where the picture sits on the hex) and `y_sort_origin` (where its foot is), so a tower overlaps
  the hex behind it and is hidden by the trees in front. Army tokens are small scenes in their own y-sorted node at z 88,
  above the mode overlay, so a tint never dims an army and a tree never hides one (`m6-build-spec.md` 1.2).
- **Seasons.** Every layer has four TileSets with the **same atlas layout**; a season change swaps the TileSet. No
  cell is touched. Winter differs by climate (snow, frost, mild): that is three atlas sources, and a hex's climate
  picks the source. Only the current season's textures are in memory.
- **A change in play** (a farm built, a town grown) is a few `set_cell` calls on the hex and its ring. Godot
  redraws only the quadrants touched.
- **Far zoom.** Past a set zoom the tile layers are hidden and one small picture is shown instead, made at runtime
  from the map data (a few pixels per hex: cover, relief, country colour). All of Europe is one draw.

### 3.3 Things on edges: rivers, roads, borders

Rivers run along hex edges, roads cross them, borders follow them. An edge is not a cell, so tiles do not fit.

**Decision:** `core/views` turns the edge data of a chunk into plain lists of lines (points, width, kind). One
`Node2D` per chunk draws them in `_draw()`. Godot keeps the drawn result until we ask for a redraw; a new road
redraws one chunk. We do not use one `Line2D` node per river: Europe would need tens of thousands of nodes.
Bridges, fords and pass marks are small tiles in the standing group.

### 3.4 What changes in the Python bake

The Python art code stays (kit, families, the approved look). **What it writes changes.**

| Today | The standard |
|---|---|
| Whole-map ground pictures per season | **Ground tiles:** per cover, per season, a few variants, hex-sized with a soft edge |
| Relief shading painted into the picture | **Shade tiles:** direction x steepness, about 20 tiles |
| Coast drawn along the real shoreline | **Coast tiles:** 63 shapes x season, with a hand-drawn wobble |
| A list of 3,268 placed trees and hills | **Decor tiles:** per cover x density (full, thinned, none) x variant x season; hill and peak tiles by relief level |
| Pieces in atlases with a JSON index | **Piece tiles:** per family x level x season/climate x variant x mirror, as ground + back band + front band. Almost the same as today |
| Rivers and roads painted into the picture | Not baked. Drawn at runtime from the data (3.3) |
| Bake reads the region and its layout | Bake never sees a map. Its output is a TileSet: reusable anywhere |

The bake writes the atlases and one index; a Godot tool builds the `.tres` TileSets from the index (origins, sort
points, custom data), so nobody sets a thousand tile properties by hand. A new region, or all of Europe, needs **no
new bake**. The tileset is expected to stay in the tens of megabytes; M1 measures it.

### 3.5 What TileMapLayer cannot do, and what we do instead

| Limit | Workaround | Cost |
|---|---|---|
| One tile per cell per layer | Pieces are cut into ground, back band and front band on three layers | Depth inside one hex is in two steps, not per tree. Fine at this size |
| No "hide the trees under this building" | **Thinning is a data step.** The decor tile of a hex is chosen from what stands there: wild hex = full, built hex = thinned or none (set per family). When you build, the rules' event changes the decor cell | Trees no longer vanish one by one under a footprint; they thin per hex |
| Tiles follow hexes, the old shoreline did not | Coast tiles follow the hex edges with a drawn wobble. A special harbour (Genoa's bay) is a piece variant | **A look change.** The art director signs it side by side with the style frame before M1 closes |
| No tile on an edge | Drawn chunk lines (3.3) | None |
| A mountain range crossing many hexes | Peak and ridge tiles per hex, oversized so neighbours join | The range is built from parts; needs art care |
| Shadows of overlapping tiles add up | Shadows go in their own layer drawn as one group with a fixed strength | None visible |
| No smooth per-cell animation | Things that move (armies, floating texts) are scenes, not tiles | None |

### 3.6 The map editor is the Godot editor

A `@tool` scene shows a map file on the same layers. The owner paints **data layers** (cover, owner, main use and
level, places) with Godot's normal tile tools and inspects any hex; a button writes the result back to the map
file and runs the checks. Heights, rivers and roads come from the map builder at first; an edge tool comes when
needed. The picture layers are never painted by hand: they always follow the data.

---

## 4. Data, the Godot way

### 4.1 Definitions: Resources you edit in the inspector

**Decision:** every table a designer may want to change is a custom `Resource` class in `core/defs/` with typed
`@export` fields, saved as `.tres` in `data/`: `FamilyDef` (levels, costs, build time, where it may stand, its
tiles), `GoodDef`, `UnitDef`, `CountryDef`, `TerrainDef`, `TechDef`, `AiTemperDef`. One `GameDefs.tres` lists them
all; it is loaded once and is read-only afterwards.

**Why:** the Godot inspector becomes the data editor for free: typed fields, drop-downs, pickers, undo. `.tres` is
text, so changes show in a review.

**In practice:** each class has `validate()`; a test loads every file and fails with the file and field on a bad
value. No number that a designer may change lives in code. The JSON exported from Python (goods, units, buildings,
countries) is turned into `.tres` when its milestone comes. Bulk geography (coast polygons, place names) stays JSON:
it is input for the map builder, not something to edit in an inspector.

### 4.2 The map file

The fixed map is one Resource, `MapData`: packed arrays indexed by hex number (land or sea, height, starting
cover, climate, fertility, ore), packed arrays per edge (river, coast, crest, pass), and the places. It is built by
a headless tool from the geography and the heights, checked (every river reaches the sea, every road a town) and
committed. CI rebuilds it and compares a digest.

### 4.3 The living game: plain objects

One `Game` object (RefCounted) owns everything that changes:

- `MapState`: packed arrays per hex (owner, controller, main use, level, settlement, castle and harbour level,
  cover change, damage, people) and per edge (road level, crossing), plus works in progress.
- `Country`, `Army`, `War`, `Market` objects, the calendar, the luck state.

Packed arrays, not a dictionary of hex objects: at 122,000 hexes it is the difference between a few megabytes and
hundreds, and between fast and slow saves.

**One owner per attribute** (kept from Python): each system file lists the state fields it writes in `OWNS`. A
test fails if two systems write one field or a field has no owner.

### 4.4 Two autoloads, both in the shell

| Autoload | Job |
|---|---|
| `Session` | Holds the current `Game`. New game, load, save, `act(...)`, `end_season()`. The only door from the shell to the rules |
| `Events` | The bus: one typed Godot signal per event kind (`hex_changed`, `work_finished`, `war_declared`, `battle_fought`...) |

`core/` never reads an autoload. Rules append events to a plain queue on `Game`; `Session` empties it after each
action and each season phase and emits the signals. So a handler never runs in the middle of a rule, and a game
without a window simply never drains to nodes.

### 4.5 UI

Panels and screens are scenes laid out with containers and one Theme, built from one kit (`shell/ui/`: button,
panel, row, tooltip, modal). A panel reads the game, shows it, and calls `Session.act`. One input controller turns
mouse and keys into intents ("select hex", "order build"); panels and the map never read the mouse for game meaning.

The look is the **Studiolo** style (`docs/design/ui/design.md`): the Theme is generated from tokens and baked 9-slice
textures, with no screen-space shaders. The kit and the frame are milestone M1.5; the content of each screen is built
by the milestone of its system (9.1). The specs are `ui-and-controls-spec.md` and `ui-style-and-feedback-spec.md`.

---

## 5. How the game runs

### 5.1 Actions: check and do

Everything a player can do is a pair in its system: `build_check(game, ...)` returns yes or a reason;
`build(game, ...)` checks again and does it. The UI shows the reason on a greyed button.

**Decision:** every pair is registered by name in one table (`core/game/actions.gd`), and everything goes through
`Game.act(name, args)`: the UI, the AI and the tests. One door means one place to log. The action log beside the
seed replays a whole game, which is how bugs are reported and how determinism is tested.

### 5.2 Events, not polling

A rule that changes something the player should notice adds an event. The map view changes only the cells named;
the log, floating texts and sounds hear the same events. Handlers never change the game. Events are never saved.

### 5.3 The season: one table

"End season" runs one ordered table in one file (`core/game/season.gd`, `PHASES`), and nothing else may run the
season. The table grows by one row or two per milestone. The full order, taken from v0.2.2 and adjusted:

| # | Phase | Arrives in |
|---|---|---|
| 1 | AI orders (`ai_orders`): run through `Game.orders`, the hook the AI attaches; the shell runs it in slices (`m8-build-spec.md` 4.2) | M8 |
| 2 | Movement, then battles | M6, M7 |
| 3 | Supply and attrition | M6 |
| 4 | Sieges and occupation | M7 |
| 5 | War (`war`): the 40-season safety peace (`m7-build-spec.md` 4.9); offers lapse, truces end, the score's bookkeeping (`m9-build-spec.md` 4.15) | M7, M9 |
| 6 | Relations (`relations`): memories fade, infamy, war weariness, leagues, unrest bands (`m9-build-spec.md` 4.15) | M9 |
| 7 | Production (`production`), then trade and prices (`trade`: markets, routes, merchants, next season's prices; `m10-build-spec.md` 4.6, 4.12) | M4, M10 |
| 8 | Income and upkeep (`income`), then debt (`debt`: interest, desertion, bankruptcy; `m12-build-spec.md` 4.2) | M4, M12 |
| 9 | Works progress (building, upgrades): after the money, so a work stands and produces from the season after it finishes (`m4-build-spec.md` 1.2) | M3 (moved here in M4) |
| 10 | People and growth | M5 |
| 11 | Research (`research`): points, techs learned, the era gate and idea offers (`m11-build-spec.md` 4.9) | M11 |
| 12 | Incidents (`incidents`): small events with choices, from the world's luck (`m12-build-spec.md` 4.8) | M12 |
| 13 | Countries that are gone (`extinction`), then scores and the end (`scores`) (`m12-build-spec.md` 4.5 to 4.7) | M12 |
| 14 | Stats: the season's rows (the ledger closes here from M4) | M3 |
| 15 | Calendar: next season; from M4 the weather of the season that begins, from the world's luck | M3, M4 |
| 16 | Ready units, vision | M6 |

A test pins the names in order. To change the order, change the table and the test in one pull request. The autosave
is not a phase: the shell saves after the season's report closes (it needs a thumbnail and the wall clock, and changes
nothing in the game; `m3-build-spec.md` 4.2 and 6.3).

### 5.4 Luck and determinism

All luck comes from `core/rng.gd`, with three separate streams: the world, the AI, decoration. A cosmetic change
never alters a battle. The streams' states are saved. Stored amounts (money, people, goods) are whole numbers.
Lists are walked in a fixed order (by id), never by memory address. **Same seed and same actions give the same
game**, and a short digest (a fingerprint of the whole state) proves it in tests.

Two rules of the moves in the month (`moves-build-spec.md` section 6):
- **A battle's days are drawn when it is fought, in the order of the acts.** A battle opened by an order is fought inside
  that action, from the world's luck, so the action log fixes the order of every draw and a replay gives the same dice.
- **A check, a view, a preview and a pause draw nothing.** Only an accepted action and the season's phases draw luck.

### 5.5 Saves

**Decision: our own snapshot, not Godot Resource saves.** A Resource file can carry a script that runs on load, so
a save passed between players could run code; and it ties the file to class names, which makes old saves fragile.

- Line 1: a small JSON header (country, year, format number, the map's id and digest) for the load screen.
- Body: one dictionary of plain values and packed arrays (each state class's `to_dict`), written with Godot's
  binary variant format with objects switched off, compressed.
- The fixed map is not saved; it is named by id and digest. A debug option writes the body as JSON for reading.
- One format number. Each bump adds one small upgrade function; a missing field gets its default.
- Tests: save, load, save again gives equal files; playing on from a load gives the same digest.
- Saves may break between builds until the first public Godot release. From then on old saves keep loading, and CI
  checks it against saves kept from each release.

### 5.6 The AI is a player

The AI reads the state through the same queries as the panels and acts only through `Game.act`, at the same costs.
No cheats in code; any handicap is a number in a `.tres`. Temperaments are data. Its thinking is cut into slices
over several frames on the main thread (no threads in `core/`, which also keeps the web possible later), with a
time budget per season that the performance test checks. **AI-only games without a window are the main test rig.**
From M8 (`m8-build-spec.md`): the slices are a step queue (each step at most one route or one works card), the AI keeps no
memory of its own, every read and act goes through one door (`AiKnow`) that sees only what `Knowledge` lets its country
know, and the AI's acts are logged like the player's.

---

## 6. Testing: how a change is proven safe

| Check | Proves | When |
|---|---|---|
| Lint, import with warnings as errors, script load | Layers, no engine calls in `core/`, typed code | Every pull request (exists) |
| GUT unit tests | Each rule does what its build spec says | Every pull request (exists) |
| Definition checks | Every `.tres` loads and passes `validate()` | Every pull request |
| Rule properties | Check and action always agree; one owner per attribute; every river reaches the sea | Every pull request |
| Determinism digest | Same seed and actions, same game; a refactor changed nothing | Every pull request |
| Map rebuild | The committed map is what the builder makes | Pull requests touching the map |
| Save round trip, old saves | Saves work and keep working | Every pull request, from M3 |
| Golden screenshots | The look did not change by accident (fixed machine, software renderer, small tolerance) | Pull requests touching art, tiles or views |
| Performance | Frame time per zoom, season time, start-up, memory, on a full-size test map | Nightly and before each release |
| Soak | Long AI-only games: no crash; wealth, wars and growth stay in expected ranges (`godot/tools/soak.gd`, `m8-build-spec.md` 4.17) | Nightly, from M8 |

**Budgets (Windows):** a frame under 16 ms at every zoom on the 122,000-hex test map; an AI season within its
budget. **A refactor never rides with a behaviour change:** a refactor pull request keeps the digest and the
goldens identical.

**Size limits (kept):** a file over 800 lines needs a reason, over 1,200 it is split; a function over 60 lines
needs a reason, over 100 it is split. A test checks it.

---

## 7. Folders and names

```
godot/
  core/     rng.gd  hexgrid.gd
            defs/  state/  systems/  game/  ai/  views/  mapgen/
  shell/    app/  autoload/ (session.gd, events.gd)  map/  hud/  panels/  screens/  ui/  input/  editor/
  data/     defs/ (*.tres)   geography/ (*.json)   maps/ (MapData)
  assets/   tiles/ (atlases and TileSets per season)   ui/   fonts/
  tests/    core/  shell/  fixtures/  goldens/
  tools/    build_map.gd  build_tileset.gd  perf probes
tools/      Python: the tile bake (the art kit and families), the lint
docs/       architecture/  design/  roadmap/  testing/
```

Files are `snake_case.gd`, one class per file with the same name in `PascalCase`. A system is named for its topic
(`economy.gd`). Actions are `verb_check` / `verb`. Events are past tense (`work_finished`). Data keys are the words
the design docs use (`main_use`, `level`). No region name in a class name: north Italy is a map file, not a class.

**Docs, data and code in step:** a number lives in one place, a `.tres`. Tables in docs (and the player's rules
page) are printed from the data by a tool. Every feature has a **build spec** written from its design: the state
fields and their owner, the actions, the events, the definitions, the tests, and "done when". Workers build from the
spec; reviewers check against it.

---

## 8. Retiring the 0.3.0 code and merging map-proto

Small steps, CI green after each, nothing lost (the planning session tags `master` before step 1).

| Step | What | Done when |
|---|---|---|
| R1 | Merge `map-proto` into `master` as it is. Two maps side by side for a moment | Lint, GUT, CI green |
| R2 | The main scene opens the new map. Delete `shell/map/`, the old `core/views/` files, `assets/baked/` (the Kenney bake) and their tests | The game starts on the new map; a golden of it is stored |
| R3 | Delete the 0.3.0 builder: `core/mapgen/*`, `core/state/` stubs, `data/maps/europe_1480.json`, `data/map_reference.json`, the builder rules file, the map count, report and probe tools | Nothing refers to them; CI green |
| R4 | One grid: `core/worldmap/world_grid.gd` becomes `core/hexgrid.gd`; the old one goes. Delete `prototypes/closeup3d/` (the map is 2D) | One hex grid in the project |
| R5 | Move `core/worldmap/` into the layers: generators to `core/mapgen/`, the model to `core/state/`. Split the two files over the limit (`world_water.gd`; `world_improve.gd` into solver, rule definitions and build actions) | Size test passes with no exceptions; digest unchanged |
| R6 | Update the lint to the layers of section 2, and `CLAUDE.md` and `godot/README.md` to this page (two autoloads, Resources). Mark the port plan's appendix as replaced | Docs and lint agree with this page |

**Kept from 0.3.0:** the skeleton, lint, CI, GUT, `rng.gd`, the projection (`geo.gd`), the geography JSON, the
exported goods, units, buildings and countries (starting values for M4, M6 and M2), the speed probe, the contact
sheet tool, and the rule "the committed map is what the builder makes". **`hexa/` stays in the repository, frozen,**
with its CI guard: it is the reference.

---

## 9. The roadmap: one system at a time

Every milestone ends with a Windows build the owner can play, its tests in CI, and a short owner playtest. The
next one does not start before that. Play area: north Italy until the Europe track switches it (below).

**Who does what, every milestone:** *Fable* writes the build spec and the interfaces (state fields, actions,
events, definitions) and reviews. *Opus* (game and systems designers) re-fits the design to districts and sets the
numbers. *Sonnet* workers build systems and anything touching `Game`, saves or the season table. *Haiku* workers
build panels from mockups, `.tres` data, and tests from a list. The "Build" column names the split per milestone.

| M | Adds | Reference in v0.2.2: keep / improve | Done when | Design / Build |
|---|---|---|---|---|
| **M0** | One code line (section 8, R1 to R6) | none | One map, one grid; all checks green; same picture as before | Fable plan / Sonnet |
| **M1** | **The map on the standard.** Tileset bake, the layer stack, far zoom, seasons as a look, select, build, upgrade, clear (today's prototype, rebuilt) | `mapview.py`: keep redraw-only-what-changed. Improve: the engine does the caching | Art director signs side by side with the style frame; under 16 ms at every zoom on a fake 122,000-hex map; build rules read `MapData`, not the bake | Fable + art director / Sonnet (view, bake), Haiku (family `.tres`, tests) |
| **M1.5** | **The UI foundation, in the Studiolo style** (added 2026-11-17). Tokens, the UI bake, the generated Theme (1x, 2x, flat), fonts, the component kit, the input map and zoom, the HUD frame, main and pause menus, options. Components only: the content of each screen arrives with its system (9.1) | none: the Python menus and options are the reference for behaviour only | The mockup's M1.5 scenes match side by side at 1x and 2x; both `--check`s (tokens and Theme) in CI; the owner plays it on the Mac and on Windows | Fable + art director / Sonnet (bake, Theme, input, App), Haiku (kit pieces, menus) |
| **M2** | **Countries.** Owners, borders, colours, names, pick your country, country panel, the editor's data layers; map modes, minimap, place search, New game | `worldgen.build_countries`, `state.Country`: keep tags and starts. Improve: owner per hex, not per province | Three or more countries on the map; borders follow ownership; you can only build at home | Opus (who owns what in 1480) / Sonnet, Haiku (panel, data) |
| **M3** | **Time.** Calendar, end season, the phase table, events and log, works take seasons (and `cancel_work`), save and load, autosave; `Stats` and the `stats` phase, `Knowledge`; the **season report** (a dialog at the end of every season: what happened, resources, actions) | `game.py` `end_season`, `systems/season.py` `PHASES`, `saves.py`, `events.py`: keep one table, one bus. Improve: snapshot instead of pickle | 40 seasons by hand; save, quit, load gives the same digest; Space, Space plays one season; save, load, J shows the same report | Fable / Sonnet, Haiku (report, Save and Load screens) |
| **M4** | **Economy.** Goods from districts, treasury (`Treasury.move`, the ledger), taxes, upkeep, build costs, top bar chips; the **works preview** (what an upgrade brings, gain per field, per season); the Statesman's Study with **Economy, This season** (the ledger, L) | `systems/economy.py`, `building.py`: keep the income preview and "one job a season". Improve: district levels replace building slots, and output varies by season (the preview needs it); numbers in `.tres` | Building choices change your income; every ducat of the report sums to the change; the preview equals the season for four calm seasons; no money from nowhere (property test) | Opus (district economy, seasonal output) / Sonnet (system), Haiku (chips, works card, study page, data) |
| **M4.5** | **Insights I** (added 2026-11-17). The chart and table kit complete; Economy's other tabs (Districts, Goods, History); the Rankings and History pages; the Yields map mode | `economy.py` incomes, `world.score`, `ranking`, the action log: keep the figures. Improve: the owner reads them as pages, not tooltips | The owner answers five questions from the study in under a minute each; a page opens in under 16 ms; others' numbers only for known countries | Opus (what to show) / Sonnet (views), Haiku (pages) |
| **M5** | **People.** Population per district, food, growth and decline, towns that grow a level | `economy.grow`, `split_food`: keep food drives growth. Improve: growth shows on the map as pieces level up | A fed region grows over 40 seasons and a starved one shrinks, inside set ranges | Opus / Sonnet, Haiku |
| **M6** | **Armies.** Recruit, upkeep, movement (river edges, passes, winter), supply, the army panel, move animation | `military.py`, `movement.py`, `supply.py`, `terrain.py`, `replay.py`: keep the path search, stack limit, supply. Improve: rivers are edges, so crossings are clear rules | Raise an army, march it across the Po and a pass; it starves out of supply; season time in budget | Opus (re-fit) / Sonnet (movement, supply), Haiku (panel) |
| **M7** | **War.** Declare war, battles, sieges, occupation, a simple peace | `war.py`, `battle.py`, `combat.py`, `battleview.py`: keep lanes and days (battle slice 1) and the read-only battle view. Improve: castles are districts with levels | A war can be started, fought and ended by hand against a passive enemy | Opus (re-fit battle and siege docs) / Sonnet, Haiku (battle panel) |
| **M8** | **AI.** Countries build, grow, raise armies and fight, through the same actions | `campaign/ai.py`: keep "the AI is a player". Improve: time slices, temperaments in data, soak from day one | 100 AI-only games of 80 seasons with no crash; the owner loses a war at least once | Fable (AI frame) + Opus (temperaments) / Sonnet |
| **Fog** | **Two fog levels** (issues 446 and 435; built 2026-11-24). Deep fog (never discovered) and light fog (discovered, not in sight), the same for every country and the AI | `docs/architecture/fog-build-spec.md`, `fog-build-plan.md` (FG1 to FG19) | built; pictures in `docs/design/ui/fog/`; the owner's playtest of plan section 5 pending | the owner's checklist; the M9 specs read `Knowledge` |
| **M9** | **Diplomacy and peace.** War goals, war score, peace terms, relations, anti-steamrolling | `war.py` `war_score`, `peace`; `war-goals-and-peace.md`, `stop-steamrolling.md`: keep the approved designs | Wars end by terms, not exhaustion; soak shows no runaway winner | Opus / Sonnet, Haiku (peace screen) |
| **M10** | **Trade.** Markets, routes, merchants, reactive prices | `systems/trade.py`, `reactive-prices.md`: keep markets and routes. Improve: per the owner's trade decisions of 2026-11-13 | Prices move with supply; a trade route changes a town's income | Opus / Sonnet, Haiku |
| **M11** | **Research.** The four-branch, three-era tree, era gates, idea cards | `systems/research.py`, `tech-tree.md`: keep the approved tree | Techs change rules through definitions only; an era passes in play | Opus / Sonnet (system), Haiku (tech screen) |
| **M12** | **A whole game.** Debt and bankruptcy, countries that fall, score and end, the Audio and Keys option pages, text size and high contrast, event pop-ups, tutorial hints, final credits, sound (the main and pause menus and the other options pages came with M1.5) | `debt.py`, `season.py` scores, `screens/`: keep | Start to 1650 with no blocker: **the first public Godot release on Windows** | Fable + Opus / Sonnet, Haiku |

### 9.1 The UI: components in M1.5, content with each system

M1.5 delivers the **frame and the components**: look (tokens, bake, Theme), kit (button, panel, row, tooltip, modal,
tabs, chips, `DeltaChip`, `SeasonStrip`, the chart and table pieces as they are needed), input, HUD frame, menus and
options. It builds no screen whose content belongs to a system. Each later milestone builds its own screens **out of
those components, as tasks in its own build spec**; a milestone is not done until its screens are in the game's final
UI, with no stand-in panel left. Sources: `docs/design/ui/design.md` (the look), `docs/design/ui/game-feedback-screens.md`
(report, works preview, study), `ui-and-controls-plan.md` section 4 and `ui-style-and-feedback-plan.md` (S2 to S5).

| M | The UI content this milestone builds | Study page / report section |
|---|---|---|
| M1.5 | Frame and kit only (above) | none |
| M2 | Country arms and name in the top bar; map modes (Terrain, Owner, Relief); country panel and country pick; New game; minimap; place search; colour-blind palette | none |
| M3 | Date and End season; the **season report**; action log, notifications, toasts, floating ribbons; Save and Load with thumbnails; Continue; autosave recovery; bookmarks; Game options page | the report's frame, "What befell", Your orders |
| M4 | Resource chips; the **works card** (upgrade preview); the **study** with Economy, This season (L); the icon set; costs on the hex panel; task flag rules | the report's money sections |
| M4.5 | Study: Economy tabs, Rankings, History; Yields mode; the chart and table kit complete | Economy, Rankings, History |
| M5 | People and food chips; growth ribbons; Food mode | People page; people section |
| M6 | Army tokens, orders and path preview; move card; army panel and raise tab; movement replay; Supply mode | Military page; real witnesses in the report |
| M7 | Battle and siege badges; odds card; battle dock; the war alert | losses and wars; battle lines |
| M8 | AI turn pill; the AI's moves replayed | none (the AI reads `Knowledge`) |
| M9 | Peace screen; war goals and relations in the country panel; Relations mode | Diplomacy page; relation matrix |
| M10 | Market panel; merchant orders; Trade mode | Trade page; price ring |
| M11 | Tech screen; idea pick | Research page |
| M12 | Event pop-ups; game-over and score; Audio and Keys pages; text size, high contrast; tutorial hints; credits | score in Rankings; the Debt tab |

### 9.2 Build specs and plans: where each milestone stands (2026-11-17)

A milestone's **build spec** (interfaces, tasks, tests, risks) is written before that milestone starts, from this
table, the design pages and the UI rows above. M2 to M12 (with M4.5) have their build spec and plan. The UI work is specified
and planned for every milestone at the level of the table.

**Tracking (from M3, decided 2026-11-19).** Each milestone from M3 on is a GitHub milestone titled `Godot M<N>: <Name>`;
each task row of its plan is one issue (`M<N> <ID>: <task>`, labels `godot`, `size:*`, `who:*`, `group:*`); each milestone
also has an `M<N>: owner's playtest` issue. A group's issues are blocked by the group before it, and a milestone's first
group by the previous milestone's playtest issue. The spec and plan stay the source of truth for design; the issues
track status. A milestone's plan is migrated to GitHub when its spec is committed. M3 to M12 are migrated (GitHub
milestones 14 to 24, 299 issues). M2 stays in its plan file (`m2-build-plan.md`, C1 to C20).

| M | Build spec | Plan and tasks | Status |
|---|---|---|---|
| M0 | this page, section 8 | R1 to R6 | done |
| M1 | `m1-build-spec.md` | its section 11 (T0 to T16) | done (T1 to T16 complete; the look decision is its section 14) |
| M1.5 | `ui-and-controls-spec.md` and `ui-style-and-feedback-spec.md` (sections 4, 5, 9) | `ui-style-and-feedback-plan.md` S0, S1 (with `ui-and-controls-plan.md`) | **done** (S0 + S1 implemented and verified headless; pending owner playtest) |
| M1.5b (Mac image format / `U17`) | `ui-and-controls-spec.md` section 6.3, `m1.5-texture-probe.md` | `ui-and-controls-plan.md` tasks **G1** & **U17** | **done** (`G1` probe documented; `import_etc2_astc=true` enabled + 0.5× half atlases/`tiles_*_half.tres`, `graphics/texture_quality` & `graphics/preset` shipped; macOS defaults to `"half"` at 264 MB winter+spring < 512 MB with zero `BPTC_RGBA` warnings) |
| M2 | `m2-build-spec.md` (who owns what in 1480, the home rule, modes, borders, the UI rows of `ui-and-controls-plan.md` section 4) | `m2-build-plan.md` (C1 to C20) | **in progress (`C1`–`C13` done through `956446f`; Groups A–D done, Group E in progress: `C14`–`C20` remaining)** |
| M3 | `m3-build-spec.md` (calendar, the season table, works that take seasons, events and the chronicle, `Stats`, `Knowledge`, saves, the report and every M3 screen; it is task R1 of the style plan) | `m3-build-plan.md` (Y1 to Y18 with S2's R2 to R11 folded in) | **built and committed (groups A to G, 2026-11-20); waits for the owner's playtest (issue #128, Windows and Mac) and the signed pictures as goldens** |
| M4 | `m4-build-spec.md` (the district economy: goods by family, level and season, stores, `Treasury.move` and `Stores.move`, taxes, upkeep, costs, weather, the previews, the study's Economy page, the chips; it is task W0 of the style plan) | `m4-build-plan.md` (N1 to N12 with S3's W1 to W12 folded in) | **built and committed (groups A to H, 2026-11-20); waits for the owner's playtest (issue #155, Windows and Mac) and the signed pictures as goldens; open: speed rows #408 and #409** |
| M4.5 | `m4-5-build-spec.md` (Economy's Districts, Goods and History tabs, Rankings, History, the Yields mode, the chart and table kit complete, the five questions as the playtest script; no new game rules) | `m4-5-build-plan.md` (I1 to I8 of S4 with Q1 to Q5) | **built and committed (groups A to E, 2026-11-21); waits for the owner's playtest (issue #171, Windows and Mac: the five questions, each under a minute) and the signed pictures as goldens; open: speed rows #410, shared cache arrays #411** |
| M5 | `m5-build-spec.md` (people per district: start, room, growth, hunger, crowding; towns that grow and fall a level; people in M4's economy; the People and Food chips, the Food mode on key 5, the People page, the report's People section, people in Rankings; the M6 seam for recruits) | `m5-build-plan.md` (P1 to P18, with S5's M5 row folded in) | **specified and planned, waits for the owner's go**; starts after M4.5 closes |
| M6 | `m6-build-spec.md` (companies and armies raised from the people, orders walked in the movement phase, river crossings, passes and winter, supply and hunger, sight and witnesses; tokens, orders, the route, the move card, the army panel, the Raise tab, the replay, the hex menu, the Supply mode on key 6, the Army chip, the Military page, the report's Armies section; the seams for M7 and M8) | `m6-build-plan.md` (L1 to L25, with S5's M6 row folded in) | **specified and planned, waits for the owner's go**; starts after M5 closes |
| M7 | `m7-build-spec.md` (war declared between neighbours, battles of lanes and days settled in their phase with records the battle dock plays back, fortresses as districts with garrisons and castle areas, sieges, occupation and its economy and people, a simple peace by hand with a truce and the 40-season timer; Declare war, the war alert in `DECISIONS`, the odds card, battle and siege badges, the castle areas, the dock, the report's War section, the Military page's wars and battles; the seams for M8 and M9) | `m7-build-plan.md` (B1 to B29, with S5's M7 row folded in) | **specified and planned, waits for the owner's go**; starts after M6 closes |
| M8 | `m8-build-spec.md` (every other country played through the same actions and checks, seeing only what `Knowledge` gives it; the `ai_orders` row run through an orders hook and in slices by the shell; five temperaments in data, set per scenario; taxes, works, raising, posts, declaring, the army's aims, standing orders, storms and peace written out; no AI memory; AI-only games; the soak with its invariants and ranges, nightly; the AI's perf rows and the E3 criteria; the AI-turn pill, the camera-only map, the replay timed in view, what others did in the report and the log, the peace alert, `peace_risk`; the layer order views below ai) | `m8-build-plan.md` (K10 to K29) | **specified and planned, waits for the owner's go**; starts after M7 closes |
| M9 | `m9-build-spec.md` (war goals and reasons, the war score by worth and battles, peace by terms with deals, white peace and surrender, offers to the player as decisions with imposing at 50, truces of 12 and 8, relations of memories and standing, gifts, infamy and soft leagues, war weariness, overextension by reach and the national part, unrest by region part on the map's new regions; the peace screen, the declare-war overlay with the goal on the map, the country panel's relations and war goals, the Relations mode on key 7, the Diplomacy page with the relation matrix, the report's Diplomacy section, the decisions; the AI's reasons, peace rules, leagues and gifts; the soak's runaway invariant and conqueror suite) | `m9-build-plan.md` (V1 to V33) | **specified and planned, waits for the owner's go**; starts after M8 closes |
| M10 | `m10-build-spec.md` (markets at the walled towns, cities and capitals, catchments by move cost, routes over land with their ways, costs, capacities and winter, prices from supply and appetite smoothed and bounded, the trade phase with free traders then merchants (T1), offers above the reserve and the reserve bought, tolls Low to High, trade agreements and embargoes on M9's relations, war, blockade and siege closing roads, road works on edges with fords and bridges and `StepCosts` on `Game`, the open-markets peace term; the Trade mode on key 8, the route lines, the market panel (E), the order card, the road card, the Trade page with the price ring, the report's Trade section, the Merchants chip; the AI's merchants, tolls, pacts and roads; the soak's trade invariants and ranges) | `m10-build-plan.md` (X1 to X31) | **specified and planned, waits for the owner's go**; starts after M9 closes |
| M11 | `m11-build-spec.md` (research points from towns and settlements, the 37-tech tree in four branches and three eras, the queue, funding, diffusion over M10's markets, the era gate of 1520 and 1575, idea cards, national techs, every effect a modifier row on a definition read through `Game.defs_of`, the 55-key registry and its probes, eight later kinds and refits, generals as traits on armies; the tech screen (T), the idea pick in `DECISIONS`, the Research chip, the Research page, the report's Research section; the AI's research, generals and refits; the `research` soak suite) | `m11-build-plan.md` (Z1 to Z25) | **specified and planned, waits for the owner's go**; starts after M10 closes |
| M12 | `m12-build-spec.md` (debt with credit, stages and three settlements; countries that fall; prestige and the end after Winter 1650, by conquest or ruin; eleven incidents; the event pop-up, the game-over screen, the Debt tab, the debt and Prestige chips, Audio and Keys pages, text size, high contrast, hints, sound, credits, developer tools off; the map look before the release; release engineering for Hexa 0.3.0 on Windows; the `whole` soak of 100 games to 1650; the hand-off ledger of everything deferred to M12; the after-M12 roadmap M13 to M27) | `m12-build-plan.md` (J1 to J38, with S5's M12 row folded in) | **specified and planned, waits for the owner's go**; starts after M11 closes |

**The Europe track, beside the milestones.** E1 (inside M1): measure on a fake full-size map. E2 (after M3): build
the real 28 km Europe map file from the geography and heights. E3 (after M8): measure an AI season on it, then
switch the play area. If a budget fails, the fallback is a larger hex, which changes data, not code. The first public release
(0.3.0, M12) ships on north Italy; E2, E3 and the switch are milestone M13 Europe, with the criteria of `m12-build-spec.md` 8.14.

**After M12, in an order the owner picks:** alliances and calls to arms, rebels and free states (`stop-steamrolling.md` Part C),
historical claims (`war-goals-and-peace.md` 3.9), ships and sea war, exploration and fog of discovery, colonies, random
worlds, city states, crown projects, achievements. `m12-build-spec.md` section 13 names them M13 to M27 (with Europe, the map
look II, the battle board, characters, Steam and localisation), with what each needs, its size and its Python reference.

---

## 10. Questions for the owner

Only game and scope. The recommendation is first.

1. **When a v0.2.2 rule and the new district map disagree, which wins?** Example: v0.2.2 has provinces with
   building slots; the new map has one district per hex with one main use and levels.
   *Recommended: the district map wins.* v0.2.2 gives the list of systems and the feel; each design is re-fitted.
   Or: keep v0.2.2's rules exactly and group hexes into provinces (less design work, but the growing map loses its point).
2. **How long do we play on north Italy before Europe?** *Recommended: through M8,* with the Europe map built
   beside (track E) and switched in once the AI's speed is measured on it. Or: Europe from M2 (everything is slower
   to build and test, but you see the whole map early).
3. **What is in the first public Godot release (M12)?** *Recommended: land game only:* no ships, no exploration,
   no colonies; they follow as their own milestones. Or: add ships and sea trade before release (v0.2.2 had them;
   about two more milestones).

## 11. Risks and what is not settled

- **The tile look must match the approved style frame** (ground blending, tile coast, thinned trees, ranges from
  parts). Riskiest item. Guard: M1 starts with one screen, side by side, signed by the art director before the rest.
- **Europe at 28 km is still unmeasured.** E1 measures drawing in M1; E3 measures the AI.
- **The district economy is design work on the critical path** for M4. It should start during M1.
- **Numbers here are estimates until measured:** tileset size, cell size, tile counts, chunk size.
- **Godot details to confirm in M1 with a test, not by reading:** that *stacked* layout shifts odd rows right as
  our grid does, and that y-sorting across several layers in one group orders tall tiles as needed.
- Sound and localisation are specified in `m12-build-spec.md` 6.9 and 6.13 (English only in 0.3.0); Steam integration comes
  with 0.9 (`m12-build-spec.md` section 13, M26).

## Owner's answers (2026-11-15)

- **v0.2.2 rules and the district map:** the district map is the game's map (one hex, one district with its use and level); the
  systems of v0.2.2 (economy, people, armies, war, sieges, AI, research...) are rebuilt on it. The tiles drawn in Python are
  reused through the tileset bake.
- **North Italy until when:** until the owner is happy with the features; then Europe.
- **First public Godot release:** land game only (no ships, exploration or colonies).
- **Coastline:** the hex-edge coast with a drawn wobble is accepted.
