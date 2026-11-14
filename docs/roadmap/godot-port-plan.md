# The Godot port plan


> **Owner's last two answers (2026-11-14):** the Europe map is **rebuilt in Godot** (the map builder is ported; the
> terrain will come out differently and the new Europe is reviewed like any map change), and the screens are **today's
> screens as they are** (redesigns wait for 0.4.x).
Technical director, 2026-11-14, second version. **A plan on paper: nothing is built or approved yet.** Part A is
for the owner, in plain words. Part B is the technical appendix. Part C is the draft brief of the first release.

> **The owner's answers (2026-11-14) to the four decisions of the first version.** This version is built on them.
>
> 1. On matching the Python game exactly: *"No issues, it can play somewhat different."*
> 2. On random worlds: *"Random world is not needed. Just the European gameplay."*
> 3. On saves and bugs: *"I don't need to match the save games. Don't care. Fix issues in Godot only."*
> 4. On builds: Windows only. The language stays GDScript, because web and mobile may come later.

Decided earlier the same day and unchanged: the game moves to Godot now; v0.2.2 (sieges, castle areas) is the last
Python release; only Age of Discovery is ported (Conquest, Colonisation and the old tile editor stay behind).

**What the answers change.** The first version spent about a third of its effort on making the two games play
*exactly* alike: own dice, own rounding rules, a referee comparing both games season by season, a shared save
format, and a random map builder that had to match hex by hex. All of that is gone. The plan is shorter (six
releases, not nine; about 22 to 30 engineer-weeks, not 32 to 45), and the Godot game is checked in a simpler way:
by measured behaviour, by tests, and by the owner playing.

---

## Part A. For the owner

### A1. The idea in five sentences

- The Python game stops at v0.2.2. It is not changed again. It stays as the **model** we copy from.
- From it we take four things once: the game's numbers, the pictures, the finished Europe map, and a report of
  how the game behaves (how battles go, how long sieges take, how fast the AI makes war, how the economy grows).
- The Godot game is then built in six playable steps: the map, the world turning, armies and battles, the AI,
  your own turn, every screen.
- It does not have to play the *same* games as Python. It has to play the same *kind* of game: its measured
  behaviour must sit close to Python's, its tests must pass, and you must like playing it.
- Bugs found on the way are fixed in Godot only. When the sixth step is done, features come back (0.4.x).

### A2. The words used in this plan

| Word | What it means here |
|---|---|
| **The model** | The Python game at v0.2.2. Frozen: no more releases, no fixes. We read it and measure it; we do not change it. |
| **Behaviour bands** | Measured ranges taken from the model. Example: "three regiments attacking three on plains win 45 to 55 times in 100", or "between 1500 and 1510 the AI countries start 4 to 9 wars". The Godot game is measured the same way. Inside the range: fine. Outside: we look for the reason. |
| **The reference report** | The document that lists all the bands, measured once from the model. |
| **Data files** | The game's numbers (goods, prices, troops, buildings, the tech tree, names). Today they are written inside Python code. A tool writes them out once as plain text files that Godot reads. Nothing is retyped by hand. Later, players can edit them (mods). |
| **The baked map** | The finished Europe of 1480 (terrain, rivers, provinces, countries, towns, castles, roads, starting armies), written out once by the Python map builder as one file. Godot loads it. Godot does not build the map itself. |
| **Baked art** | Today the game draws its tiles, trees, towns and units with code each time it starts. A tool runs that code once and writes the pictures into image files. An **atlas** is one big image holding many small pictures. Godot loads the atlases. The look does not change. |
| **Unit tests** (GUT) | Small automatic checks of one rule each ("a refused move changes nothing", "a tower holds land within 3 hexes"). GUT is the test tool for Godot. The Python game has about 1,500 such tests; they are the written description of the rules, and they are rewritten for Godot. |
| **Seed** | The number a game's luck starts from. In Godot the same seed and the same moves give the same game again, which makes a bug repeatable. It does *not* give the same game as in Python. |
| **Headless** | Running the game with no window, so a machine can test it. |
| **CI** | The machines on GitHub that run all tests on every change. |
| **Export** | Godot's word for making a build for one platform. For now: Windows only. |
| **Web-safe** | Written so that a browser or phone version stays possible later, without building one now. |

### A3. What you will play, release by release

The port takes the **0.3.x** numbers ("New engine"). The roadmap phases that had 0.3.x onwards (the living world,
history and events, the sea, game feel) each move up one number. The war features that were next (the castles map
mode first, then the battle board, war goals and peace, the trade patch) become **0.4.x**, the first feature line
in Godot.

Sizes: **L** means about as much work as the whole 0.2.2 sieges release; **XL** is about one and a half to two of
them. The weeks are "engineer-weeks" as in the engine study (one full-time developer with AI help, plus or minus 30
percent). At the studio's pace calendar time is much shorter, but the proportions hold. Every release is a Windows
zip on the GitHub release page, as today.

| Release | Name | What you can do in it | Size | What proves it is done |
|---|---|---|---|---|
| **0.3.0** | The map | Open the Godot build. See Europe 1480: terrain, countries, rivers, roads, towns, castles, names. Pan and zoom smoothly, switch between the terrain and the countries view, see the province under the mouse. No game yet. | L to XL, 4 to 5 weeks (about 2 of them are the one-time preparation in Python) | Screenshot pairs with the Python game at fixed places and zooms, judged by the art director and by you. Counts equal the model (provinces, countries, towns, castles). A steady 60 frames a second on the low-end PC. The reference report exists. |
| **0.3.1** | The world turns | Press "End season": prices, production, trade, incomes, growth, research and debt run, with no armies and no AI. The top bar and a read-only province panel show the numbers. The map gains ground blends, coasts and ridges. | L, 3 to 4 weeks | The economy bands for a world where nobody acts: totals per decade inside the model's ranges. The economy, trade, research and debt tests pass in Godot. |
| **0.3.2** | Armies and battles | Take any country's armies and move them, attack, besiege or storm (you play all sides; no AI yet). Battles, sieges, castle areas, supply and winter work. The map gains unit tokens, marches, battle and siege marks. | L to XL, 4 to 5 weeks | The battle bands (win rates, length and losses per scenario) and the siege table (seasons to take each castle). The movement, supply, battle and siege tests pass. |
| **0.3.3** | The AI plays | Start a new game and watch every country play by itself, to 1650. War, peace, colonies, the fog of war, a "thinking" marker while the AI works. | L, 3 to 4 weeks | The bands for whole games: wars, battles, provinces changing hands, the biggest country's share, the economy and research, each per decade. AI time per season inside the budget. Long unattended games with no error. |
| **0.3.4** | Your turn | Play a country properly: build, recruit, found colonies, pick research, send merchants, end the season, save and load. Province and unit panels, the odds card, the log, the task flag, the move messages. | XL, 4 to 6 weeks | You play 30 seasons with no blocker. The tests of every player action pass. Save, quit, load gives the same game. |
| **0.3.5** | Every screen | The rest: the battle screen, the siege panel, war and peace, the tech screen, market, country and ledger panels, menus and settings, the close-up landscape (trees, hills, winter) and the moving "life" on the map. The complete game. | XL, 4 to 6 weeks | A checklist of every screen next to Python, signed by the art director and by you. Your full playtest. All bands measured once more on the finished game. |

**Total: about 22 to 30 engineer-weeks** (the first version: 32 to 45). After 0.3.5, 0.4.0 is the castles map mode.

In each release the rules and the map's look move forward together. They share no files, so they do not slow each
other, and every release has something new to see.

### A4. What "close enough" means

- **Rules: the same rules, not the same games.** The Godot code is written from the Python code, rule by rule, and
  the Python tests are rewritten for Godot. The luck differs, so single games differ.
- **Behaviour: inside the bands.** Battles, sieges, war pace, the economy and AI speed are measured in both games.
  Where Godot is outside a band, the systems designer finds out why. It is then either a bug (fixed) or a
  difference you are told about in the release notes.
- **Looks: the same to the eye.** Same art, same information in the same place, checked with screenshot pairs.
- **Differences on purpose,** because Godot gives them for free: smooth zoom instead of six fixed steps, sharper
  text, a window you can resize.
- **Bugs are not copied.** A bug found in the Python rules is fixed in the Godot rules and noted in the changelog.
- **The last word is yours:** you play each release.

### A5. The honest part: speed, and what "web-safe" costs

- **GDScript is not faster than Python.** It is in the same class. Today an AI season takes 0.13 to 0.25 seconds
  in Python; expect about the same on your PC. That is fine for a turn-based game.
- **One thing got easier.** Because the games need not match move for move, Godot may use its own built-in path
  finder, which is fast. In the first version that was forbidden (it breaks ties its own way).
- **We still measure early:** in 0.3.0, path finding on the real map; in 0.3.3, the whole AI season. The pass
  line: a late-game AI season under half a second on the low-end PC.
- **Web-safe, cheaply.** Three habits keep a browser or phone version possible later, and cost almost nothing
  now: the game never *needs* background threads; the season can run in small slices (one country at a time) so
  the window never freezes; no add-on in another language. Nothing is built or tested for the web during the port.
- **A phone version would still need a new UI** (today's game leans on hover and right-click). That is design
  work for after the port, and its own decision.

### A6. What pauses, and what does not

- **Pauses until 0.3.5:** every new feature (the castles map mode, the battle board, war goals and peace, the
  trade patch) and all balance changes.
- **Stops for good:** Python releases, random worlds, Conquest and Colonisation.
- **Continues on paper:** designs, mockups and briefs for 0.4.x, as the studio process already allows.
- **Open bug issues** stay open and are fixed in Godot, in the release that builds the part they are about.
- **Later, each its own decision:** web, touch UI and phone builds; Steam (unchanged on the roadmap).

### A7. Risks, in plain words

1. **The fun question waits.** Your v0.2.0 verdict was that war "wasn't really engaging". The port adds nothing
   to that for many weeks. This is the price you chose; it should stay visible.
2. **A rule is copied wrongly and nobody notices.** Without the exact comparison, a small mistake (a wrong bonus,
   a missed special case) can hide inside a band. The guards are the rewritten tests, tables of worked examples
   taken from the model (B4), and your play. This risk is larger than in the first version; it is what the
   saved weeks cost.
3. **The map's look.** Some of today's art is put together per hex while the game runs (ground blends, ridges,
   coasts). It must be split into pieces Godot can layer. How well that splits is known only after the art
   inventory in 0.3.0.
4. **The UI takes longer than planned.** It always does in ports. 0.3.4 and 0.3.5 are the likely overruns.
5. **The team is new to Godot.** The agents know Python best; they can mix up Godot 3 and Godot 4, and they cannot
   see Godot's visual editor. Automatic checks and screenshot tests are the guard (B3, B10).
6. **The map is fixed.** Changing Europe later (fewer towns, new province names, another coastline) means running
   the Python map builder again, or editing the map file. See decision 1.

**The last cheap exit is after 0.3.0.** Until then the Python game is untouched and complete. If the map in Godot
disappoints, or the speed test fails with no way out, that is the moment to say stop.

### A8. Two decisions left

**Decision 1. Where the Europe map comes from.**
- **(Recommended) A baked map file.** The Python map builder writes today's Europe once; Godot loads it. You get
  exactly the map you know. It saves 3 to 4 weeks (about 2,300 lines of map-building code are not ported). The
  price: the Python builder stays in the repository as a tool, and a later change to the map goes through it or
  through hand edits of the file.
- Build the map in Godot. With different dice the terrain would come out differently, so this would be a *new*
  Europe that only resembles today's, and it would need its own review. Only worth it if random worlds return.

**Decision 2. Which screens are rebuilt.**
All screens and panels are built again in 0.3.4 and 0.3.5.
- **(Recommended) Today's screens, as they are.** One thing changes at a time; a screen that differs is a bug,
  which keeps the checklist simple. Redesigns follow in 0.4.x.
- Where you already approved a new design (`docs/design/ui/`), build the new one directly. It avoids building a
  screen twice, but it mixes design questions into the two releases most likely to overrun. If you choose this,
  each release brief lists the screens that change, for your sign-off.

Everything else in this plan is a technical default; the owner may overrule any of it.

---

## Part B. Technical appendix

### B1. Evidence (measured in the repo, 2026-11-14, at v0.2.2)

- `hexa/campaign/` and `hexa/ui/`: about 39,800 lines. Rules (`systems/`, 19 modules), `world.py` 782, `ai.py` 806,
  `state.py` 270, `data.py` 503, `tech.py` 530. Tests: 1,488 test functions, 323 of them window tests.
- **Not ported any more:** `randomgeo.py` 1,286; `geo.py` 550, `regions.py` 739, `wfc.py` 85, `naming.py` 270,
  `systems/worldgen.py` 642 (the Europe builder, about 2,290 lines, stays a Python tool); `placenames.py` 6,952
  (the names are in the baked map; only the colony-name rule of `naming.colony_name` is needed at run time).
- **Geography the running game reads** (so it must be in the baked map or ported as plain maths): the projection
  (`lonlat`, `hex_of`, `merc`, `inv_merc` and their constants: used by the AI, trade, colonies, research, the
  season and the map view), and the tables `KNOWN_WORLD`, `START`, `MARKETS`, `COUNTRIES`, `CITIES`, `TRIBES`,
  `MOUNTAINS`, `FERTILE_RIVERS`, `COASTAL_KNOWLEDGE`.
- Speed (`tests/perf_budget.json`): AI season 0.125 s, late 0.251 s; battle phase 0.020 s.
- Existing measuring tools: `tools/battle_stats.py` (scenario win rates, length, losses; all-AI war counts and the
  snowball share), `tools/siege_stats.py` (seasons to take open land and castles 1 to 3 for six besiegers),
  `tools/soak.py` (invariants every season), `tools/perf.py`.
- Grid: `hexa/hexgrid.py`, pointy-top, odd-r offset `(col, row)`, sprite 60 x 70 at 1x, row step = 1.5 x radius.
  Map view zooms: hex radius 3, 5, 8, 13, 21, 34 px; landscape art from radius 21.
- Season order: `systems/season.py` `PHASES`, 16 phases.

### B2. End state: the project layout

Same repository, a `godot/` folder next to `hexa/`.

```
godot/
  project.godot            Godot 4.x, pinned (B12); Compatibility renderer (runs on old PCs; the only one for web)
  data/                    exported once from Python, then owned by Godot: numbers, tech tree, names
    europe_1480.json.gz    the baked map and the turn-0 state
  assets/atlases/          baked by the Python tool: png + a json index; committed
  core/                    pure GDScript, no Node, no scene, no engine singletons; runs headless
    hexgrid.gd  rng.gd     rng.gd wraps one seeded RandomNumberGenerator; the only source of luck in core/
    data/                  loaders, with a schema that says which numbers are whole numbers
    state/                 Province, Market, Route, Country, Unit, Garrison, War, Battle (typed, to_dict/from_dict)
    systems/               one file per Python system, same names; season.gd holds PHASES
    world.gd               the facade
    game.gd                the game manager; the season as resumable steps
    ai/
    bus.gd                 the event bus: queued, with history
    views/                 read models: battle view, resources, reminders, feed, odds, province and unit views
    saves.gd
  shell/                   everything with Nodes
    app/                   main scene; owns the Game; drains the bus once a frame and re-emits as signals
    map/                   map view and its layers
    hud/  panels/  screens/
    ui/                    one Theme (from theme.py's tokens) and the kit scenes
  tests/core/  tests/shell/  tests/fixtures/     fixtures: bands.json, worked-example tables
  tools/                   bands.gd, soak.gd, perf.gd (headless scripts)
  addons/gut/
hexa/                      the Python game at v0.2.2: frozen; the model, the map builder and the art baker
tools/                     Python: the four exporters (B5, B7, B4) next to today's tools
```

### B3. GDScript style rules (CLAUDE.md's structure rules, carried over)

- **Layers, references point down only:** data -> state -> systems -> world -> game -> views -> shell. Files in
  `core/` extend `RefCounted`, never `Node`; they use no scene tree, no autoload, no `Input`, `OS`, `Time`, and
  no `await`. A lint script (text scan, run in CI) enforces it, as `tests/test_architecture.py` does today.
- **Actions are pairs:** `x_check(world, ...)` and `x(world, ...)` in the system's file, with a facade on the
  world. The shell and the AI change state only through actions. (The three places where the Python AI writes
  state directly, `country.tax` and two `country.memory[...]`, become actions in the port.)
- **Events:** systems call `world.bus.emit(kind, data)`. Inside `core/` the bus stays a queue with history, so
  headless tests can read events and no handler runs in the middle of a rule. The shell drains it once a frame
  and re-emits each event as a Godot **signal**; scenes connect to signals only. Handlers never change the world.
- **Read models:** scenes get plain view objects from `core/views/` and never touch `core/state` or
  `core/systems` (lint). The Python read models (`battleview.py`, `resources.py`, `reminders.py`, `feed.py`) are
  the templates; each ported panel gets its view first.
- **One owner per attribute** (`OWNS` per system), **season order only in `PHASES`**, **no cross-file private
  use**, and the **size limits** (module 800/1,200 lines, function 60/100) all carry over.
- **Luck from one place.** All random draws in `core/` go through `world.rng` (`rng.gd`); Godot's global
  `randi`/`randf`/`shuffle`/`pick_random` are banned there (lint). The rng's state is saved. So in Godot the same
  seed and the same actions give the same game: a test plays one game twice and compares a digest of the state.
  This is for repeatable bugs and tests, not for matching Python.
- **Typed GDScript everywhere,** with these warnings turned into errors: untyped declaration, unsafe access,
  integer division, narrowing conversion. They catch real porting mistakes (`7 / 2` is 3 in GDScript, 3.5 in
  Python; `round` and `%` on negative numbers also differ: each use is ported on purpose, with a comment where
  the Python result is kept).
- **Web-safe rules:** no `Thread`, `Mutex` or `WorkerThreadPool` required anywhere (allowed only as an optional
  speed-up behind a switch); no GDExtension; no blocking file dialogs in `core/`; files only under `user://` and
  `res://`.
- **Godot 4 only.** The lint also rejects Godot 3 spellings (`yield`, `export var`, `onready var`, string
  `connect`, `instance()`, the old `TileMap` node). CI loads the project with warnings as errors.
- **Scenes are text** (`.tscn`), small, laid out with containers and the one Theme. No hand-placed pixel positions.
  Every scene has a screenshot test, because the agents cannot see the editor.
- **UI:** buttons, rows, tooltips, modals come from `shell/ui/` kit scenes; colours and fonts from the Theme.

### B4. How the Godot game is checked (replaces "determinism across two languages")

Dropped from the first version: the own generator (xoshiro), the rounding and ordering helpers, the set-order
audit, the cross-language referee with its traces and its idle, replay and ai suites, and the action recorder.
The Python oracle (`tools/same_behaviour.py`) keeps its old job only: nothing uses it for the port.

Three checks replace them.

**1. Behaviour bands.** A Python tool, `tools/behaviour_bands.py`, measures the model once and writes the
reference report (`docs/roadmap/behaviour-bands.md`) and the same numbers as `godot/tests/fixtures/bands.json`.
`godot/tools/bands.gd` measures the Godot game with the same definitions and prints a table: measure, the model's
band, Godot's value, inside or outside.

| Band | Measured how (in the model) | First needed | Proposed pass rule |
|---|---|---|---|
| **Battle scenarios** | The fixed fights of `tools/battle_stats.py` (3 v 3, 4 v 3, 6 v 4, 6 v 6, the mixed ones; plains and hills), re-run at 200 seeds each: attacker win rate, days (median, p90), share at the day cap, loser's share of men lost | 0.3.2 | Win rate within 10 points of the model's; median days within 1; loser's loss within 10 points |
| **Siege table** | `tools/siege_stats.py`: seasons to take open land and castles 1 to 3 for the six besiegers | 0.3.2 | Each cell within one season of the model's (the rule `tests/test_sieges.py` already uses against the design) |
| **Idle economy** | 20 Europe games, 1480 to 1650, no country acting: per decade, total population, income, treasury, debt, a price index of the key goods, trade volume, techs known | 0.3.1 | See below |
| **War pace** | 20 all-AI Europe games, 1480 to 1650: per decade, wars started and ended, battles, castles fallen, provinces that changed hands, countries alive, the biggest country's share of the land | 0.3.3 | See below |
| **Economy and research with the AI** | The same 20 games: per decade, the idle measures plus colonies founded, regiments standing, the years eras II and III begin | 0.3.3 | See below |
| **AI time per season** | `tools/perf.py`: `ai_season`, `ai_season_late`, `battle_season` | 0.3.3 | Budgets of B9 (a budget, not a comparison) |

- **The band of a per-decade measure** is the model's 10th to 90th percentile over its 20 games, never narrower
  than 15 percent either side of the median (so a measure with little spread cannot make an impossible band).
  Godot plays 20 games and passes a measure when its median is inside the band in at least 15 of the 17 decades.
  The systems designer sets the final rules with the reference report in hand; these are the starting proposal.
- **A miss is a question, not a failed build.** The systems designer traces it to a cause and rules: a porting
  bug (fixed), a Python bug that Godot does not copy (noted), or luck (more games are played). Accepted
  differences are listed in the release notes for the owner.
- A full Python game is about 680 seasons, 2 to 3 minutes; the whole reference run is about two hours of machine
  time, once. Check before the run: which seed the Europe map is baked from, and that the 20 model games vary
  only what a new game in Godot also varies (the luck), not the map.

**2. Unit tests as specs (GUT).** B10.

**3. Worked-example tables** for rules with no luck in them: costs, prices from a given stock, supply limits,
step costs, castle areas, the siege meter per season, the odds word. A Python tool writes inputs and results of
the model's functions on the baked map to JSON fixtures; a GUT test asks the Godot functions the same questions
(whole numbers equal; fractions within a small tolerance). This is cheap and exact where exactness costs nothing,
and it is the main guard for risk A7.2. It is made per system, in the release that ports the system.

Plus, as today: a **soak** (full games with the invariants of `tests/support/invariants.py` checked every season)
and the **owner's playtest checklist** in each brief.

### B5. Data and the baked map

- **Numbers.** `tools/export_data.py` writes `data.py`, `tech.py` and `specialgoods.py` as JSON into
  `godot/data/`. The Python modules are not changed (the model is frozen). After the export the JSON files are
  the source of truth for the Godot game: balance changes in 0.4.x edit them directly. The export is run again
  only if it had a mistake. Proof: a Python test that the files read back equal to the modules' tables; a GUT
  test that loads every file through its schema.
- **The baked map.** `tools/export_europe.py` builds the Europe world of v0.2.2 once and writes
  `godot/data/europe_1480.json.gz`:
  - *the map:* size, terrain, rivers and `river_at`, sea bodies, landmasses, ridge and pass edges with their
    names, roads and road paths, the per-hex art variant numbers the landscape uses;
  - *the turn-0 state:* provinces (name, owner, population, good, castle, buildings, garrison, tribe), countries
    (treasury, start techs, what they have explored), starting units, markets and routes, the random seed;
  - *the geography tables* of B1 and the projection constants.
- Godot ports the projection (a few lines of maths), the markets rebuild (`systems/trade.py`, a running rule)
  and `naming.colony_name`. A GUT test rebuilds the markets on the baked map and compares them with the baked
  ones. Nothing else of the builder is ported.
- A new game in Godot loads the file, sets the player's country and the luck seed. Check in the export: that the
  Python world does not depend on the chosen country beyond what `_set_player` sets.
- Proof of the export: a summary file of counts and hashes written next to it; a Python test that a world
  restored from the file has the same `world_digest` as the built one for the map sections; screenshot pairs in
  0.3.0.
- **Later map changes** run the Python builder and the export again (the builder stays in the repo as a tool),
  or edit the file. A map tool inside Godot is a possible later feature, not part of the port.
- Text shown to players stays in the data files in English, keyed, ready for Godot's translation system later.

### B6. Saves

- No conversion and no shared format. Python saves are not read by Godot.
- **Godot's format:** line 1 is a JSON header (what the load screen shows, and a format number starting at 1).
  The body is gzip-compressed JSON from each state class's `to_dict`: the state only; the fixed map is read from
  the map file, named by id and hash in the header. Whole numbers are cast by schema on load (Godot's JSON reads
  every number as a fraction). The rng state is a 64-bit number and is stored as text (JSON numbers lose
  precision above 2^53).
- **Proof:** save, load, save again gives equal files; load and play gives the same digest as playing on without
  saving; a fuzz run on the loader (a broken file is refused quietly, as today).
- **Promise:** saves may break between 0.3.x builds (the state grows every release). From 0.4.0 the policy of
  today returns: older saves keep loading unless a release says otherwise, with a save-compat check in CI.
- Saves live under `user://`, which also works in a browser later.

### B7. The art pipeline

- `tools/bake_art.py` runs the Python art modules once and writes atlases (png) plus an index (json: name, rect,
  anchor point, sort offset). The art modules stay in the repo as the baker; the sprite-hash test keeps guarding
  them. The bake is made on Linux in CI (as the goldens are) and its hashes are kept in a manifest.
- **Bake size:** hex radius 60 px (tile 104 x 120), about twice the closest zoom of today, with 2 px extruded
  borders and mipmaps so far zooms and odd zoom factors show no seams.
- **The art inventory** (a 0.3.0 deliverable) sorts everything drawn today into three groups:
  1. *Baked as it is:* terrain and goods tiles, objects (trees, peaks, farms), towns, castles, landmarks, unit
     tokens, icons, badges.
  2. *Baked as pieces, layered in Godot:* what is composed per hex at run time today: ground blend bands by pair of
     ground kinds and edge, ridge crests by edge, the coast, river and road tiles by edge mask, winter variants.
  3. *Redone in Godot:* borders, fog, map-mode tints, labels, selection and path marks, the "life" animations,
     floating text. These become shaders, lines, tweens.
- Which variant sits where (today a hash of the position) is baked into the map file, so Godot shows the same
  trees on the same hexes without copying the hash.
- **Look parity** is judged on screenshot pairs by the art director before the owner sees a release.

### B8. The hex map

- **Default: `TileMapLayer`s.** Verified in the Godot source (`TileSet::map_to_local`, 4.6): tile shape Hexagon,
  offset axis Horizontal, layout **Stacked** shifts rows with odd `y` right by half a tile and steps rows by 0.75
  of the tile height. That is exactly our pointy-top odd-r grid, with cell `(x, y)` = our `(col, row)`.
  (Layout Stacked Offset shifts the even rows instead: the wrong one.)
- `tile_size` is whole pixels, so a regular hex cannot be exact: 104 x 120 is off by 0.08 px in width, which
  cannot be seen. The tile grid is the one source of pixel positions in the shell (`map_to_local`,
  `local_to_map`); `core/hexgrid.gd` is the one source for neighbours and distance. A test checks both against a
  table written by the Python `hexgrid.py` (neighbours, centres, and pixel-to-hex for a few thousand points).
- **Layers:** ground; ground blends; rivers, roads and coasts; ridges; a y-sorted object layer; borders and war
  areas (custom drawing); units; fog (a shader over a small texture, one texel per hex); labels.
- **Far zooms** (political and other map modes when hexes are a few pixels): one small texture per mode, coloured
  per hex, drawn by a shader. No tiles.
- **Fallback: custom drawing** in chunks (one `Node2D` or `MultiMeshInstance2D` per 32 x 32 hexes) if the tile
  layers show seams, cannot take our edge art, or update too slowly when ownership changes. The choice is made in
  0.3.0 from measurements; the layers sit behind one map-view interface so the rest of the shell does not care.
- A `Camera2D` with smooth zoom replaces the six steps; the old steps remain as snap points for map-mode switches.

### B9. Performance

- **Budgets (the owner's Windows PC and the low-end PC):** frame 16 ms while panning at any zoom; AI season under
  0.5 s late game; no frame longer than 50 ms while the AI thinks.
- **The season in slices, where cheap.** `game.gd` runs the season as a list of steps (one country's AI turn, or
  one phase of `PHASES`); the shell calls "next step" until about 8 ms of a frame are used. Slicing between steps
  costs nothing and never changes the result. Slicing *inside* a step (a long path search) is not done unless a
  measurement asks for it.
- **The speed probe** (in 0.3.0, on real code and the baked map): the path finder and one flood (castle areas) in
  typed GDScript, against Godot's `AStar2D` and against the same functions in Python. Reported as ratios.
- **Fallbacks, in order:** (1) algorithmic: flat `PackedInt32Array` state for the grid, cell ids instead of
  vector keys, neighbour tables, paths remembered within a season; (2) Godot's built-in `AStar2D` for path
  searches (C++ inside the engine, works on every platform; it breaks ties its own way, which is now allowed);
  (3) optional worker threads behind a switch on desktop. A GDExtension is not planned: it would end "web-safe"
  cheaply kept, and nothing measured asks for it.
- `tools/perf.py`'s table is rebuilt as `godot/tools/perf.gd` with the same metric names.

### B10. Testing in Godot

- **Framework: GUT** (pure GDScript, runs headless from the command line, writes JUnit XML; its branch is pinned
  to the Godot version). One framework for `core/` and the shell.
- **The Python tests are the spec, ported system by system.** With no referee, the rule tests carry more weight
  than in the first version, and more of them are rewritten:
  - *Rule examples* (`test_campaign`, `test_battle`, `test_sieges`, `test_tech*`, the economy and trade tests...):
    rewritten in GUT in the release that ports the system. A test that pins an exact dice result is rewritten to
    pin the rule (a prepared roll, or a range). A system is not "ported" until its specs pass.
  - *Properties and invariants* (`x_check` true means `x` succeeds; a refused action changes nothing; totals
    conserved; the invariants of `tests/support/invariants.py`): rewritten once, run on random Godot games and in
    the soak.
  - *Architecture tests:* the lint script (B3).
  - *Saves:* B6.
  - *Window tests (323):* rewritten against scenes with scripted input, in 0.3.4 and 0.3.5.
  - *Not ported:* tests of Conquest, Colonisation, random worlds, the map builder, the Python oracle, pickle
    saves and save-compat, the sprite hashes (they stay with the baker).
- Each release brief names the Python test modules it ports, so the count is visible: ported, replaced by a
  worked-example table, or dropped with a reason.
- **Goldens:** screenshots of fixed scenes, made in CI on Linux under a virtual display with software rendering
  (true headless mode draws nothing), compared with a pixel tolerance as today. They change only with a reviewed
  art or layout change.
- **Soak and monkey:** headless scripts (full games with invariants each season; random input on the shell).
- **CI on GitHub Actions:** Godot downloaded at a pinned version with a checksum, export templates cached.
  On pull requests: lint and project load; GUT tests; goldens. On tags: the Windows export and a smoke start.
  Nightly: soak, perf, and the bands table (a report, not a gate). The Python test job runs only when `hexa/` or
  the Python `tools/` change.

### B11. Exports

- **Windows:** every release from 0.3.0, a zip on the GitHub release. The only build the owner gets.
- **Web, Linux, Steam Deck, Android, iOS:** not built during the port. Kept possible by the web-safe rules (B3),
  the Compatibility renderer and the sliced season. Each is its own later decision. One cheap guard: at 0.3.3
  and at 0.3.5 a web export is made once and started, to see that nothing has closed the door; its result is a
  line in the release notes, not a deliverable.
- **Steam:** unchanged on the roadmap (0.9.x Early Access).

### B12. Engine version

Pin the newest stable Godot 4 at the start of 0.3.0 (a web check on 2026-11-14 found 4.7.x stable and 4.8 in
beta; confirm on the day). Upgrade only between releases, never inside one, and only with the tests and goldens
green before and after.

### B13. The Python line, frozen

- `v0.2.2` is the last Python release. There is no Python 0.3.0.
- `hexa/` is not edited again: no fixes, no refactors, no balance changes. The Python `tools/` folder gains the
  exporters (`export_data.py`, `export_europe.py`, `bake_art.py`, `behaviour_bands.py`, the worked-example
  writers); they import `hexa` and use its public API, as `tools/battle_stats.py` does. A CI check fails a pull
  request that changes a file under `hexa/`.
- The rest of the Python refactor (architecture plan, phases still open) is closed as "not continued".
- At 0.3.5: Conquest, Colonisation, the legacy editor, the pygame window code and their tests leave the main
  branch (the tag `v0.2.2` keeps them). What stays is what the tools need: the world builder, the rules the
  measuring tools run, and the art modules, labelled as build tools, not as the game.

### B14. Follow-up edits in other documents (listed, not made)

- **`docs/roadmap/roadmap.md`**
  - "Next up": the 0.3.x "New engine" line with the six releases; the castles map mode moves to 0.4.0; the
    battle board, the trade patch, field forts, battle cards, the battle mini-map and war goals and peace follow
    in 0.4.x.
  - Section 3 "What exists today": Python frozen at v0.2.2; Age of Discovery on Europe is the game; Conquest,
    Colonisation and random worlds are retired.
  - Backlog and M5: remove "the random-world start country" and any other random-world item; mark map fixes
    (fewer towns, province names, coastlines) as "through the map builder tool".
  - Record the four answers of 2026-11-14 in the "Answers so far" section; point to this plan.
- **`docs/roadmap/long-term-roadmap.md`**: shift each phase after war by one MINOR number; add the port line;
  note web and mobile as "kept possible, not scheduled".
- **`CHANGELOG.md` header**: 0.3.x is "New engine" (the Godot port, Europe only, Windows); later phases take
  0.4.x onwards, starting with the paused war features; v0.2.2 is the last Python release; Python saves do not
  open in 0.3.x; the save format number starts again at 1 in Godot and saves may break between 0.3.x builds.
- **`CLAUDE.md`**
  - At 0.3.0, a "Port rules" section: `hexa/` is frozen (no edits; exporters go in `tools/`); the `godot/`
    layout and the rules of B3; the Godot commands (run, GUT, lint, bands, export); new work goes to `godot/`.
  - The first paragraph: no longer "three modes"; the Python sections are marked "reference only".
  - At 0.3.5: rewritten for Godot; the Python sections shrink to "build tools".
- **`README.md`**: at 0.3.5, the player rules for the Godot game (controls change with smooth zoom; the random
  map and the other modes are removed). Not before: until then it describes v0.2.2.
- **New file when the brief is locked:** `docs/roadmap/release-0.3.0-brief.md`, from Part C.

### B15. Technical risks and their guards

| Risk | Guard |
|---|---|
| A rule is ported wrongly and hides inside a band | Specs per system before it counts as ported; worked-example tables; invariants in the soak; the owner's play |
| A band is too wide or too narrow to be useful | The systems designer sets the pass rules from the reference report; a miss is investigated, not auto-failed |
| The model has a bug that shapes a band | Found while porting: fixed in Godot, the band noted as "differs on purpose" |
| GDScript speed | Probe in 0.3.0; `AStar2D` allowed; the season as steps from the start |
| Run-time art does not split into pieces | Art inventory in 0.3.0; in 0.3.0 only, baked chunk images of Europe are allowed as a stand-in |
| UI overrun | Views tested by machine first, so only layout is left to the eye; 0.3.5 has a cut order (life animations, then menu polish) |
| Agents write Godot 3 code, or break scenes they cannot see | Lint, project load with warnings as errors, a screenshot test per scene, small text scenes |
| Godot's JSON and number handling | Cast by schema; the rng state as text; the save round-trip test |
| Goldens differ between graphics cards | Goldens only on CI's software renderer; local runs compare with a tolerance or skip |
| The baked map needs a change after the builder has rotted | The builder and its tests stay in CI as build tools; the export is one command |
| Web is closed off by accident | The web-safe lint rules; the two trial web exports |

---

## Part C. Release 0.3.0 brief: DRAFT

**Not locked.** It is locked after the owner has answered the two decisions in A8.

**Why the preparation is folded into this release, not a release of its own.** The first version had a Python
release 0.3.0 for the preparation. Now Python is frozen and the preparation changes no game code: it is four
export tools. A release that only contains tools would give the owner nothing to play, and exports are only
proved right when something reads them. So 0.3.0 is the first Godot build, and the exports are its first items.

### Theme

**The map.** Europe 1480 on screen in the new engine, drawn from the baked map and the baked art, with the
game's numbers and the reference report ready for the releases that follow. Fun principles: none served directly;
this release is the cost of the engine decision and is checked for one thing: does the map look and feel at
least as good as today's.

### Scope

| # | Item | Size | Proof |
|---|---|---|---|
| 1 | **Godot project.** Pinned engine, the layout of B2, the lint of B3, GUT, CI (lint, tests, goldens, Windows export on a tag). | M | CI green; a tagged build starts on Windows |
| 2 | **Game numbers as data files.** `tools/export_data.py`; the Godot loaders with their schema. | S to M | Python: files equal the modules' tables. GUT: every file loads; spot values equal README tables |
| 3 | **The baked Europe map.** `tools/export_europe.py`; the Godot map and state classes that read it (`from_dict`); the projection. | M | Counts and hashes summary; Python round-trip digest; GUT: counts of provinces, countries, towns, castles, units equal the summary |
| 4 | **The art baker and the art inventory.** `tools/bake_art.py` at hex radius 60; the inventory document (baked / pieces / redone); contact sheets. For 0.3.0: terrain tiles, rivers, roads and coast pieces, towns, castles, landmarks. | L | Sprite hashes unchanged; the art director signs the contact sheets |
| 5 | **The map view.** Tile layers (ground; rivers, roads, coasts; towns and castles; borders; labels), the far-zoom countries texture, camera pan and smooth zoom, the terrain and countries views, the province name under the mouse. | L | Screenshot pairs with Python at 6 places x 3 zooms; `hexgrid` table test; frame time on the low-end PC; goldens |
| 6 | **The reference report.** `tools/behaviour_bands.py`; `docs/roadmap/behaviour-bands.md`; `bands.json`. Runs beside the other items (it shares no files with them). | M | The report read and its pass rules set by the systems designer; a second run reproduces it |
| 7 | **Speed probe** on real code (B9). | S | The ratio table in the release notes |
| 8 | **Freeze paperwork.** The edits of B14 for roadmap, CHANGELOG header and CLAUDE.md; the CI guard on `hexa/`. | S | In the release |

**Size:** L to XL, 4 to 5 engineer-weeks; items 2, 3, 4 and 6 are the Python-side preparation (about 2 weeks).

**Order of work:** 1 first. Then 2 and 3 (small, and item 5 needs 3), with 4 and 6 in parallel from the start.
Then 5 and 7. Then 8.

**Cut list, in order:** the war-pace and AI-economy bands of item 6 (needed only by 0.3.3; the battle, siege and
idle-economy bands stay); the "pieces" for ground blends and ridges in item 4 (they are 0.3.1's map work anyway);
landmarks; the smooth-zoom snap points. Never cut: items 1, 2, 3, the idle-economy and battle bands, and the
screenshot pairs.

**Not in 0.3.0:** any rule or season in Godot; units on the map; fog; panels; saves; any change under `hexa/`;
any web or phone build; the castles map mode.

### Done when

- The Windows build starts on the owner's PC and shows the Europe map at 60 frames a second while panning.
- The screenshot pairs are signed by the art director; the counts equal the model's.
- The data files, the map file and the atlases are in the repo, each with its proof test green.
- The reference report exists and the systems designer has set the pass rules.
- The speed probe's table says "go", or names the fallback that 0.3.2 must plan in.
- The Python tests still pass and no file under `hexa/` has changed since v0.2.2.

### Playtest checklist (ten minutes)

1. Start the build. Does the map look like the game you know? Open Python 0.2.2 next to it.
2. Pan across Europe and zoom from the whole map down to one town. Is it smooth? Any seams, gaps or flicker?
3. Switch between the terrain view and the countries view. Are the borders and colours right?
4. Hover Lisbon, Paris, Venice and Constantinople. Are the province names right?
5. Find three castles and three rivers you know. Are they where they should be?
6. Read the speed table and one page of the reference report: do the bands describe the game you played in 0.2.2?
