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
            views    "what to draw" as plain lists
            ai       picks actions for a country
            game     Game, the action table, the season table, events, saves
            systems  the rules, one file per topic
            state    the facts of one game
            defs     the definitions (Resource classes)
```

**The one-way rule:** a file may use its own layer or a lower one, never a higher one. Bottom to top: `defs`,
`state`, `systems`, `game`, `ai`, `views`, `shell`. `mapgen` sits beside `systems` and runs only in tools. The lint
checks this on every pull request.

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
  the hex behind it and is hidden by the trees in front. Army tokens are small scenes in the same group, so they
  sort with the trees.
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
| 1 | AI orders | M8 |
| 2 | Movement, then battles | M6, M7 |
| 3 | Supply and attrition | M6 |
| 4 | Sieges and occupation | M7 |
| 5 | War timeouts, peace offers | M9 |
| 6 | Works progress (building, upgrades) | M3 |
| 7 | Production, trade, prices | M4, M10 |
| 8 | Income and upkeep, debt | M4, M12 |
| 9 | People and growth | M5 |
| 10 | Research | M11 |
| 11 | Countries that are gone, scores | M12 |
| 12 | Calendar: next season, weather | M3 |
| 13 | Ready units, vision | M6 |
| 14 | Autosave | M3 |

A test pins the names in order. To change the order, change the table and the test in one pull request.

### 5.4 Luck and determinism

All luck comes from `core/rng.gd`, with three separate streams: the world, the AI, decoration. A cosmetic change
never alters a battle. The streams' states are saved. Stored amounts (money, people, goods) are whole numbers.
Lists are walked in a fixed order (by id), never by memory address. **Same seed and same actions give the same
game**, and a short digest (a fingerprint of the whole state) proves it in tests.

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
| Soak | Long AI-only games: no crash; wealth, wars and growth stay in expected ranges | Nightly, from M8 |

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
| **M2** | **Countries.** Owners, borders, colours, names, pick your country, country panel, the editor's data layers | `worldgen.build_countries`, `state.Country`: keep tags and starts. Improve: owner per hex, not per province | Three or more countries on the map; borders follow ownership; you can only build at home | Opus (who owns what in 1480) / Sonnet, Haiku (panel, data) |
| **M3** | **Time.** Calendar, end season, the phase table, events and log, works take seasons, save and load, autosave | `game.py` `end_season`, `systems/season.py` `PHASES`, `saves.py`, `events.py`: keep one table, one bus. Improve: snapshot instead of pickle | 40 seasons by hand; save, quit, load gives the same digest | Fable / Sonnet |
| **M4** | **Economy.** Goods from districts, treasury, taxes, upkeep, build costs, top bar and ledger | `systems/economy.py`, `building.py`: keep the income preview and "one job a season". Improve: district levels replace building slots; numbers in `.tres` | Building choices change your income; the ledger explains every ducat; no money from nowhere (property test) | Opus (district economy) / Sonnet (system), Haiku (ledger, data) |
| **M5** | **People.** Population per district, food, growth and decline, towns that grow a level | `economy.grow`, `split_food`: keep food drives growth. Improve: growth shows on the map as pieces level up | A fed region grows over 40 seasons and a starved one shrinks, inside set ranges | Opus / Sonnet, Haiku |
| **M6** | **Armies.** Recruit, upkeep, movement (river edges, passes, winter), supply, the army panel, move animation | `military.py`, `movement.py`, `supply.py`, `terrain.py`, `replay.py`: keep the path search, stack limit, supply. Improve: rivers are edges, so crossings are clear rules | Raise an army, march it across the Po and a pass; it starves out of supply; season time in budget | Opus (re-fit) / Sonnet (movement, supply), Haiku (panel) |
| **M7** | **War.** Declare war, battles, sieges, occupation, a simple peace | `war.py`, `battle.py`, `combat.py`, `battleview.py`: keep lanes and days (battle slice 1) and the read-only battle view. Improve: castles are districts with levels | A war can be started, fought and ended by hand against a passive enemy | Opus (re-fit battle and siege docs) / Sonnet, Haiku (battle panel) |
| **M8** | **AI.** Countries build, grow, raise armies and fight, through the same actions | `campaign/ai.py`: keep "the AI is a player". Improve: time slices, temperaments in data, soak from day one | 100 AI-only games of 80 seasons with no crash; the owner loses a war at least once | Fable (AI frame) + Opus (temperaments) / Sonnet |
| **M9** | **Diplomacy and peace.** War goals, war score, peace terms, relations, anti-steamrolling | `war.py` `war_score`, `peace`; `war-goals-and-peace.md`, `stop-steamrolling.md`: keep the approved designs | Wars end by terms, not exhaustion; soak shows no runaway winner | Opus / Sonnet, Haiku (peace screen) |
| **M10** | **Trade.** Markets, routes, merchants, reactive prices | `systems/trade.py`, `reactive-prices.md`: keep markets and routes. Improve: per the owner's trade decisions of 2026-11-13 | Prices move with supply; a trade route changes a town's income | Opus / Sonnet, Haiku |
| **M11** | **Research.** The four-branch, three-era tree, era gates, idea cards | `systems/research.py`, `tech-tree.md`: keep the approved tree | Techs change rules through definitions only; an era passes in play | Opus / Sonnet (system), Haiku (tech screen) |
| **M12** | **A whole game.** Debt and bankruptcy, countries that fall, score and end, menus, options, sound | `debt.py`, `season.py` scores, `screens/`: keep | Start to 1650 with no blocker: **the first public Godot release on Windows** | Fable + Opus / Sonnet, Haiku |

**The Europe track, beside the milestones.** E1 (inside M1): measure on a fake full-size map. E2 (after M3): build
the real 28 km Europe map file from the geography and heights. E3 (after M8): measure an AI season on it, then
switch the play area. If a budget fails, the fallback is a larger hex, which changes data, not code.

**After M12, in an order the owner picks:** ships and sea war, exploration and fog of discovery, colonies, random
worlds, city states, crown projects, achievements.

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
- Not covered: sound, localisation, Steam integration. Each gets a short note when it nears.

## Owner's answers (2026-11-15)

- **v0.2.2 rules and the district map:** the district map is the game's map (one hex, one district with its use and level); the
  systems of v0.2.2 (economy, people, armies, war, sieges, AI, research...) are rebuilt on it. The tiles drawn in Python are
  reused through the tileset bake.
- **North Italy until when:** until the owner is happy with the features; then Europe.
- **First public Godot release:** land game only (no ships, exploration or colonies).
- **Coastline:** the hex-edge coast with a drawn wobble is accepted.
