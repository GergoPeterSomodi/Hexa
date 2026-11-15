# Hexa in Godot: the architecture of the whole game (draft for the owner, 2026-11-15)

Technical director. **Status: a plan for the owner to decide. Nothing in the code changes with this document.**

Since the restart in Godot we have designed the map and its art in depth, but never laid out how the whole game is
put together. This page does that. It replaces the technical appendix of `docs/roadmap/godot-port-plan.md` wherever the
two disagree (that plan was written for a port; we are restarting). It keeps the lessons of the Python review
(`review-2026-11-12.md`) and the layout rules in `godot/README.md`.

How to read it: section 1 is where we stand, section 2 is the target, section 3 is the eight big decisions with a
recommendation each, section 4 is the road to a first playable slice, section 5 is the five questions for you.

---

## 1. Where we are, honestly

### 1.1 What exists

| Thing | Where | State | Verdict |
|---|---|---|---|
| The Python game, v0.2.2 | `hexa/` | Frozen. Complete game, about 800 tests | **Reference only.** A source of rules, numbers and lessons |
| Game designs | `docs/design/` (battle, tech tree, sieges, war goals, castle areas, crown projects, prices, city states...) | Written for the Python game's map (57 km provinces, one sprite per level) | **Keep the ideas, re-fit each one** to the district map when its turn comes |
| Map design | `docs/design/map/` 00 to 06 | Decided: 28 km hexes, real heights, rivers on edges, one city one hex, 2D, the growing map | **The base of everything below** |
| Godot project skeleton | `godot/` on `master`: layers, lint (`tools/lint_godot.py`), GUT tests, CI (`.github/workflows/godot.yml`), seeded luck (`core/rng.gd`) | Working, enforced in CI | **Keep.** This is the best part of the 0.3.0 work |
| The 0.3.0 map builder | `godot/core/mapgen/`, `core/state/`, `core/views/`, `shell/map/`, `data/maps/europe_1480.json` | Builds all of Europe on the **old** map model: 203 x 150 hexes of 57 km, rivers through hexes, Kenney tiles | **Superseded** by the map decisions. See decision (c) |
| The new map core | branch `map-proto`, `godot/core/worldmap/` (grid, heights, relief, water, cover, places, roads, improvements), about 4,900 lines with about 2,500 lines of tests | Works for one region (north Italy, about 150 hexes on screen). Follows the core rules (no engine calls, seeded luck, check/action pairs) | **Keepable**, after a tidy-up |
| The playable map scene | `map-proto`, `godot/shell/worldmap/north_italy_map.gd` (956 lines) | Seasons, select, build, upgrade, clear. One file that loads data, runs the generator, draws, handles input and builds the panel | **Prototype.** It proved the idea; it is not the game's map view |
| The art | `map-proto`, `tools/worldmap/` in Python: `style_frame/`, `pieces/` (`kit.py` and 16 families), `godot_bake/`; about 12,700 lines | Owner-approved look. Baked to PNG atlases and JSON, 23 MB for the one region | **The look is keepable; the pipeline is not, as it stands.** See decision (a) |

### 1.2 The two Godot code lines

`master` holds the 0.3.0 port code. `map-proto` was branched from it and adds the new map beside the old one, so
today there are **two maps in one project**: two hex grids (`core/hexgrid.gd` and `core/worldmap/world_grid.gd`), two
generators, two views, two sets of baked art (`assets/baked/` with Kenney tiles and `assets/worldmap/`). Only one of
them matches your decisions. Nothing of the game itself exists in either: no countries that act, no economy, no
armies, no turns, no saves.

### 1.3 Technical debt and risks

1. **The baked map does not scale to Europe.** The bake stores the ground of the region as whole pictures
   (`base_<season>.png`, `ground_<season>.png`) and every wild tree and hill as a line in a list (`wild.json`: 3,268
   objects for 148 hexes). Europe at 28 km is about 122,000 hexes. At the same detail the ground alone would be a
   picture of about 42,000 x 23,000 pixels **per season** (several gigabytes in memory), and the object list would
   pass half a gigabyte. This cannot ship, least of all on web or mobile. The **pieces** (farms, towns, castles) are
   different: they are reusable, and all six season sets fit in six small atlases (about 4 MB). They scale fine.
2. **The game state is fed by the art.** `WorldImprove.build()` reads its hex table from the bake's `meta.json`. So
   the rules depend on a picture file made by Python. It must be the other way round: the map data comes first and
   both the rules and the art read it.
3. **Python is still needed to make art.** Two languages, and any art change needs a 40 second bake and a commit of
   binary files. The one-language goal is not met yet.
4. **Rule tables live in code.** Which family may stand where, the pair rules and the weights are constants in
   `world_improve.gd`. The Python review's lesson was: numbers in data files.
5. **Two files are over our own size limit** (1,200 lines): `world_water.gd` (1,370) and `world_improve.gd` (1,272,
   which mixes the puzzle solver, the rules and the player's build actions). And the prototype scene repeats the
   Python game's biggest fault, "the app does everything".
6. **Unmeasured at Europe size:** drawing 122,000 hexes at every zoom, and one AI season of path searches. The hex
   size is only confirmed for Europe after both are measured (your decision of 2026-11-14).
7. **The game designs assume the old map.** Castle areas, sieges, prices and the tech tree speak of provinces,
   works and buildings. The district model (one main use, levels) changes their inputs. This is design work, not
   code, but it sits on the critical path.

---

## 2. The target architecture

### 2.1 The picture

```
        tools (offline, headless)                     the game (runtime)
  geography facts + elevation data            +-----------------------------------+
            |                                 |  shell/   Godot nodes             |
            v                                 |   app  screens  hud  panels  ui   |
   map builder (core/mapgen) ---> map file -->|   mapview  input                  |
                                 (committed)  +-----------------^-----------------+
  art source ---> piece atlases (committed) ->|     reads state | sends actions,  |
                                              |     hears events| never writes    |
                                              +-----------------|-----------------+
                                              |  core/   plain GDScript, no nodes |
                                              |   views   what to draw (lists)    |
                                              |   ai      picks actions           |
                                              |   game    Game, season, events,   |
                                              |           saves                   |
                                              |   systems rules: one per topic    |
                                              |   state   the map and the world   |
                                              |   data    numbers from JSON       |
                                              +-----------------------------------+
```

**The one-way rule:** a file may use files of its own layer or a lower one, never a higher one. Order, bottom to
top: `data`, `state`, `systems`, `game`, `ai`, `views`, then `shell`. `mapgen` sits beside `systems` and is used by
tools and by "new random world" only. The lint already checks this on every pull request.

### 2.2 What each layer owns

| Layer | Owns | Must never |
|---|---|---|
| **data** (`core/data/`, `godot/data/*.json`) | Every number and table: goods, improvement families and levels, costs, build times, terrain rules, units, countries, AI temperaments. Loaded once, checked against a schema, read-only afterwards | Hold a number in code that a designer may want to change |
| **state** (`core/state/`) | The facts of one game, as plain objects with `to_dict` / `from_dict`. No rules | Compute, draw, or read files |
| **systems** (`core/systems/`) | The rules, one file per topic: `improve`, `economy`, `growth`, `movement`, `battle`, `siege`, `diplomacy`, `research`... Each is a set of functions that take the game as a parameter | Use another system's private parts, the shell, or luck outside `rng.gd` |
| **game** (`core/game/`) | `Game` (the one object that holds the state), the **season phase table**, the event bus, saves, the digest | Contain rules of its own |
| **ai** (`core/ai/`) | Choosing actions for a country, inside a time budget | Change state except through actions |
| **views** (`core/views/`) | "What should be drawn": for a chunk of map or a panel, a plain list of sprites, lines and texts. Testable without a window | Touch nodes or textures |
| **mapgen** (`core/mapgen/`) | Building a map from facts: heights, water, cover (WFC), places, roads, the 1480 improvements (WFC), checks | Run during play |
| **shell** (`godot/shell/`) | Everything with nodes: the window, the map view, the UI kit and theme, panels, screens, input, sound, file reads and writes | Change state directly, or hold game rules |

### 2.3 The map is the heart of the game state

The growing map makes each hex a district, so the map is not scenery: it **is** the save game. Two parts:

- **The fixed map (`MapBase`).** Never changes in play; comes from the map file. Per hex: land or sea, height,
  ground cover at the start, climate, fertility, ore, shelter. Per **edge** (stored once, both hexes read it): river,
  coast type, crest, pass. Per place: name, the river-city facts.
- **The living map (`MapState`).** Changes in play; goes into the save. Per hex: owner, controller, `main_use`
  (family), `level`, settlement level, castle level, harbour level, the one-step cover change (woods thinned, marsh
  drained), damage, people. Per edge: road level and crossing (ford, bridge). Plus the works in progress.

Around it: `Country` (treasury, research, relations), `Army`, `War`, `Market`, the calendar (year, season) and the rng
state. **Storage:** packed arrays indexed by hex number, not dictionaries of objects. At 122,000 hexes this is the
difference between a few megabytes and hundreds, and between fast and slow saves.

**One owner per attribute** (kept from the Python rules): each system file lists the state fields it writes in
`OWNS`; a test fails if two systems write the same field or a field has no owner.

### 2.4 How a change happens

1. **Check/action pairs.** Every thing a player can do is two functions in its system: `build_check(game, ...)`
   returns yes or a reason; `build(game, ...)` does it. The UI shows the reason on a greyed button. The AI and the
   tests call the very same pair. (`WorldImprove` already works this way.)
2. **Events, not polling.** A system that changes something the player should notice emits an event
   (`hex_changed`, `work_finished`, `war_declared`, `battle_fought`). The map view redraws only the hexes named (a hex
   and its ring of six; a city and its second ring). The log, the floating texts and the sounds listen to the same
   events. Event handlers never change the state, and events are never saved.
3. **The season pipeline.** "End season" runs one table, in one place (`core/game/season.gd`, `PHASES`): for example
   AI orders, movement and battles, sieges, works progress, people's growth, production and trade, prices, income
   and upkeep, research, weather and the new season, autosave. The order is data you can read in one screen, and
   nothing else may run the season (the Python game had three copies).
4. **Determinism.** All luck comes from one seeded `Rng`, with separate streams for the world, the AI and pure
   decoration, so a cosmetic change never alters a battle. Same seed and same actions give the same game, on every
   PC. A short **digest** (a fingerprint of the whole state) proves it in tests.

### 2.5 Map generation: offline and at runtime

- **Offline, committed:** the Europe 1480 map is built by a headless tool from the geography facts and the
  elevation data, checked (every river reaches the sea, every road a town), and written to one map file. CI rebuilds
  it and fails if it differs. Players never wait for it and never get a different Europe.
- **At runtime:** only "new random world" runs the generator, with a progress bar. In play nothing is re-solved:
  the neighbour rules are used as a checklist for build actions (as `06-growing-map.md` says).

### 2.6 View, UI and input

- **Map view:** the map is cut into **chunks** (blocks of about 16 x 16 hexes). `core/views` says what is in a
  chunk; the shell draws it once and keeps it until an event marks it changed. Three detail levels by zoom (far,
  normal, close) from the same data.
- **UI:** one kit (`shell/ui/`: button, panel, row, tooltip, modal) and one Theme. Panels are scenes laid out with
  containers, never hand-placed pixels, so they fit a phone later. A panel reads the game, shows it, and calls actions.
- **Input:** one controller turns mouse, keys and later touch into intents ("select hex", "order build"). Panels
  and the map never read the mouse for game meaning themselves.
- **Size limits** (kept): a file over 800 lines needs a reason, over 1,200 it is split; a function over 60 lines
  needs a reason, over 100 it is split. Checked by a test.

---

## 3. The big decisions

### (a) The art pipeline

| Option | What | For | Against | Cost |
|---|---|---|---|---|
| A. Keep as is | Python draws everything; whole-map pictures and object lists are baked | Nothing to build; the look is exact | **Cannot reach Europe** (1.3 point 1); every change needs Python and a bake | None now, a dead end later |
| B. Port everything to Godot now | Rewrite the kit, 16 families and the style frame (12,700 lines) in GDScript; draw at runtime or bake in Godot | One language; small download | Months of re-drawing art you already approved; every piece must be re-approved; drawing all pieces at start is slow on web and phones | Very high |
| **C. Hybrid (recommended)** | **Pieces stay baked** from Python into atlases (they are reusable and small). **The ground is composed in Godot** from the map data: ground textures by cover, relief shading from the heights, rivers, coasts and roads as drawn lines, wild trees and hills placed by a fixed rule per hex instead of a list. The far zoom is one small prepared picture per season | Reaches Europe; small download (tens of MB, not gigabytes); local redraw when a hex grows; art you approved is kept as it is | The ground look must be rebuilt in Godot and matched to the style frame (art director signs off side by side); Python stays for pieces for now | Medium: one focused piece of work |

**Recommendation: C.** Python becomes a pure piece factory with a frozen contract (`pieces/index.json`); it never
again sees a map. Porting the piece kit to Godot (to reach one language) is a later, separate decision, taken when
the piece list has settled.

### (b) The world map at Europe scale

Europe at 28 km is a grid of about 406 x 300, **about 122,000 hexes**, perhaps 40,000 to 50,000 of them land (to be
counted by the builder).

- **Committed, built offline:** heights per hex (derived from the elevation data; the raw data stays outside the
  repo), the map file (hexes, edges, places, roads, the 1480 improvements, owners). Estimated 1 to 2 MB packed.
- **Computed at start (under a second):** neighbour tables, the movement graph, distance-to-town fields.
- **Computed when first seen, then cached:** the chunk pictures. About 6 to 12 chunks are on screen at the play
  zoom; a bounded cache keeps a few dozen and drops the oldest.
- **Levels of detail:** *far* = one prepared picture per season plus country colours and names; *normal* = chunks
  with ground, lines and pieces; *close* = the same chunks with the extra detail pieces, only for what is on screen.

**Options:** build for Europe from day one (slow start, nothing to play for months); build only for one region and
scale later (fast, but the Python game showed that scaling late hurts); **recommended: play on one region, but
measure on a full-size fake Europe early** (a generated 122,000-hex map, phase 2). Budgets to prove: a frame under
16 ms at every zoom; textures under about 300 MB (the web limit decides); an AI season within its budget. If a
budget fails we know before the game is built on it, and the fallback (about 40 km hexes) changes numbers, not code.

### (c) The 0.3.0 port code and the map-proto core

| Option | What | For | Against |
|---|---|---|---|
| Keep both | Leave the two maps side by side | No work now | Two grids, two generators; every worker must ask "which one?" |
| Adapt the 0.3.0 builder | Teach `core/mapgen` the new model | Keeps the all-Europe data flow | It is built round 57 km provinces and rivers through hexes; more work than replacing it |
| **Replace (recommended)** | Merge `map-proto` into `master`. `core/worldmap` becomes the map generator and model. Retire the 0.3.0 builder, its Europe file, `shell/map` and the Kenney bake, each in a small step with the tests green | One map, one grid, one truth | The all-Europe 28 km map must be built anew (it is needed anyway) |

**Kept from the 0.3.0 work:** the project skeleton and rules, the lint, CI, GUT, `rng.gd`, the geography data
(coasts, rivers, cities, countries), the projection, the game data exports (goods, units, countries as starting
values), the "map file that rebuilds byte for byte" idea, the speed and start-up probes, the contact sheet tool.

### (d) Save format and versioning

- **Recommended: a snapshot.** Line 1 is a small header (country, year, format number, the map's id and hash) that
  the load screen reads. The body is compressed data from each state class's `to_dict`: the living map as packed
  arrays, countries, armies, wars, the rng state. The fixed map is not saved; it is named by id and hash.
- **Versioning:** one format number; each bump adds one small upgrade function; a missing field gets its default.
  A test saves, loads and saves again (equal files), and plays on from a load (equal digest).
- **Promise:** saves may break until the first public Godot release; from then on old saves keep loading, with a
  check in CI against saves kept from each release.
- **Alternative:** a replay (start, seed and the list of actions). Tiny and perfect for bug reports, but any rule
  change breaks every save. Recommended only as an **optional action log** beside the snapshot, for debugging.

### (e) The AI's place

- **The AI is a player.** It reads the state through the same queries as the panels and acts only through the
  same check/action pairs, at the same costs. No cheats in code; any handicap is a number in data.
- **Its own thinking budget.** AI work is cut into small slices run over several frames with a "thinking" marker,
  not on a second thread (threads are limited on the web). A budget per season is part of the performance tests.
- **Its own luck stream**, so changing how the AI thinks never changes battle dice.
- **Temperaments in data** (trading republic, border duchy), as the growing-map design asks.
- **AI-only games without a window are our main test rig**: hundreds of seasons in CI find crashes and runaway
  snowballing long before a player does.

### (f) Testing and CI

| Check | What it proves | When |
|---|---|---|
| Lint, import with warnings as errors, script load | Layers, no engine calls in core, typed code | Every pull request (exists) |
| GUT unit tests | Each rule does what its design says | Every pull request (exists) |
| Rule properties | Things that must always hold: every check/action pair agrees, no negative treasury without debt, every river reaches the sea, one owner per attribute | Every pull request |
| Determinism digest | Same seed, same actions, same game; refactors change no behaviour | Every pull request |
| Map rebuild | The committed map file is what the builder makes | Pull requests touching the map (exists) |
| Save round trip and old saves | Saves work and keep working | Every pull request, once saves exist |
| Golden screenshots | The look did not change by accident (compared with a small tolerance, on one fixed CI machine) | Pull requests touching art or views |
| Performance budget | Frame time per zoom, AI season time, start-up, memory, on the full-size test map | Nightly, and before each release |
| Soak and bands | Long AI-only games: no crash, and wars, wealth and growth stay inside expected ranges | Nightly |

A refactor never rides with a behaviour change: refactor pull requests must keep the digest and the goldens identical.

### (g) Folders and names

```
godot/
  core/     rng.gd  hexgrid.gd
            data/  state/  systems/  game/  ai/  views/  mapgen/
  shell/    app/  screens/  mapview/  hud/  panels/  ui/  input/
  data/     rules/ (families, costs, goods, units, ai)   geography/   maps/
  assets/   pieces/ (baked atlases)   ground/ (small textures)   ui/   fonts/
  tests/    core/  shell/  fixtures/  goldens/
  tools/    build_map.gd  perf probes  contact sheets
tools/      Python: the piece factory only (worldmap/pieces, the bake), lint
docs/       architecture/  design/  roadmap/  testing/
```

Names: files `snake_case.gd`, one class per file with the same name in `PascalCase`; a system file is named for its
topic (`economy.gd`); actions are `verb_check` / `verb`; events are past tense (`work_finished`); data keys are the
same words the design docs use (`main_use`, `level`). The region name never appears in a class name
(`NorthItalyMap` becomes the map view plus a map file).

### (h) Keeping design docs, data and code in step

1. **A number lives in exactly one place: a data file.** Design docs give starting values and name the file and key.
2. **Tables in docs are printed from the data** by a tool (the player's rules page included), so they cannot drift.
3. **Every data file has a schema test**: a typo or a missing key fails CI, with the file and line.
4. **Every feature has a build spec** written from its design: the state fields and their owner, the actions, the
   events, the data keys, the tests, and "done when". Workers build from the spec, reviewers check against it.
5. **A design change after approval** edits the design doc first, then the data or the spec, then the code, in one
   pull request where possible. The structure rules live in `CLAUDE.md` and `godot/README.md` and change only with a
   technical director review.

---

## 4. The road to a first playable slice

**The slice:** north Italy, two or three countries (for example Milan, Venice and Genoa), seasons, build and
upgrade districts, basic money, armies that move, one war with a simple end. Small, but every layer of section 2
exists in it, so everything after is "more of the same", not new structure.

| Phase | What | Done when |
|---|---|---|
| **0. One code line** | Merge `map-proto`; retire the 0.3.0 builder, its map file, `shell/map` and the Kenney bake; one hex grid; lint and size test cover everything | `master` has one map; lint, GUT and CI green; the prototype scene still shows the same picture (golden) |
| **1. The map model and file** | `MapBase` and `MapState`; a headless builder writes the region's map file from geography and heights (not from the art bake); `world_improve.gd` split into solver (mapgen), rule tables (data) and actions (systems); `Game`, digest | The game state builds with no art files present; rebuild is byte-identical; digest test in CI |
| **2. The map view at scale** | Chunked map view; ground composed in Godot; pieces from atlases; seasons; local redraw on events; the full-size fake Europe for measuring | Art director signs the side-by-side with the style frame; frame under 16 ms at every zoom and textures under budget on the 122,000-hex test map. **This is the measurement that confirms 28 km for Europe** |
| **3. The turn** | Calendar, season phase table, event bus, countries and ownership, treasury, works that cost money and take seasons, income and upkeep from districts, save and load | 40 seasons played by hand; save, quit, load gives the same digest |
| **4. The UI kit and HUD** | Theme, kit, top bar, district panel with build options and reasons, end-season button, log fed by events | Every action reachable by mouse; no panel reads the mouse or writes state itself (lint) |
| **5. Armies and one war** | Armies, movement costs (river edges, passes, winter), a simple battle and siege, occupation, declare war and make peace | A war can be started, fought and ended by hand; rule tests and properties green |
| **6. The AI plays** | AI countries build, move and fight through the same actions, inside the thinking budget | 100 AI-only games of 80 seasons with no crash; AI season time inside budget |
| **7. The slice release** | Windows build, your playtest, fixes | You play 40 seasons against the AI with no blocker |

**What runs in parallel.** Phases 1 and 2 run side by side once the view's input (the "what to draw" lists) is
agreed. Phases 3 and 4 run side by side. Design runs ahead of code the whole time: the district economy (how
levels become goods and money), the slice's army and war rules, and the UI mockups must be approved before phases
3, 4 and 5 start. The all-Europe 28 km map build can start after phase 2, beside the game work.

**Who does what.** Fable and Opus design: this architecture, each feature's design and its build spec, the
interfaces between layers, and the reviews. Sonnet and Haiku workers build: one task per brief, with the files they
may touch, the tests to add and the "done when" line. The lint, the size limits, the digest and the goldens are
what make this safe: a worker cannot quietly cross a layer or change behaviour. Good worker tasks: one system file
with its tests, one panel from a mockup, one data table with its schema, one family's rules. Kept with the senior
models: `Game`, the season table, the save format, the chunk view's design, and anything that changes an interface.

---

## 5. Questions for the owner

1. **How do we make the art reach all of Europe?** *Recommended: the hybrid* (pieces stay drawn in Python and baked;
   the ground is composed in Godot from the map data). Or keep everything baked (cannot reach Europe), or port all
   drawing to Godot now (months, and every piece re-approved).
2. **May we retire the 0.3.0 map (the 57 km Europe and its builder) and make the map-proto core the one map?**
   *Recommended: yes*, keeping the project skeleton, the checks and the geography data. Or keep both for now.
3. **Is the first playable slice right?** *Recommended: north Italy, two or three countries, seasons, build and
   upgrade, basic money, armies, one war, an AI that plays*, with Europe measured on a fake full-size map in phase 2
   and built afterwards. Or all of Europe first (nothing to play for much longer).
4. **Do we design for the web and phones from the start?** *Recommended: yes for the budgets* (memory under about
   300 MB of textures, no threads in the rules, panels that reflow), *Windows only for the builds* until the slice
   is fun. Or Windows only in everything (cheaper now, a costly retrofit later).
5. **May saves break between builds until the first public Godot release?** *Recommended: yes.* The state will
   grow with every phase; from the first public release old saves keep loading and CI checks it.

## 6. Risks and what is not settled

- **The ground look in Godot** (decision a) is the riskiest single item: the approved style frame must be matched
  by a new compositor. Guard: phase 2 starts with one chunk, side by side, before anything else is built on it.
- **Europe at 28 km is still unmeasured.** Phase 2 measures it; the fallback is a larger hex, which changes data.
- **The older game designs need re-fitting** to districts (economy first). This is the likeliest thing to hold up
  phase 3, so it should start now.
- **Numbers in this page** (chunk size, memory budget, land hex count, file sizes) are estimates until measured.
- Not covered here: sound, localisation, Steam integration, random worlds beyond the generator's place. Each gets
  a short note when it nears.
