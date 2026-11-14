# The Godot port plan

Technical director, 2026-11-14, third version. **A plan on paper: nothing is built yet.** Part A is for the
owner, in plain words. Part B is the technical appendix. The first release has its own brief:
`docs/roadmap/release-0.3.0-brief.md`.

> **The owner's last answers (2026-11-14).** This version is built on them.
>
> 5. The Europe map is **rebuilt in Godot**: the map builder is ported. The terrain will come out differently, and
>    the new Europe is reviewed like any map change.
> 6. The screens are **today's screens as they are**. Redesigns wait for 0.4.x.
> 7. *"Build the map first and we can start designing the game elements."* So 0.3.0 is the map and nothing else,
>    and while it is built the design team designs the next releases' game elements on paper.

> **The owner's answers (2026-11-14) to the four decisions of the first version.**
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
releases, not nine; about 25 to 34 engineer-weeks, not 32 to 45), and the Godot game is checked in a simpler way:
by measured behaviour, by tests, and by the owner playing.

**What the last answers change (third version).** The second version loaded a finished map written out by Python.
Now Godot builds Europe itself, from the same geography (coastlines, rivers, mountains, cities, countries, place
names). That adds about 3 weeks, all of them in 0.3.0, and it removes the Python map builder from the game's
future: after 0.3.0 a map change is made in Godot only. The new Europe is not checked hex by hex. It is checked by
counts and shares against the Python map, and by eye on a contact sheet (B5).

---

## Part A. For the owner

### A1. The idea in five sentences

- The Python game stops at v0.2.2. It is not changed again. It stays as the **model** we copy from.
- From it we take four things once: the game's numbers, the pictures, the geography of Europe (coastlines,
  rivers, mountains, cities, countries, place names), and a report of how the game behaves (how battles go, how
  long sieges take, how fast the AI makes war, how the economy grows).
- The Godot game is then built in six playable steps: the map, the world turning, armies and battles, the AI,
  your own turn, every screen. The first step builds Europe 1480 again, inside Godot.
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
| **Geography data** | What Europe is made from: the outlines of the land as lists of longitude and latitude points, the rivers, mountain ranges, passes, cities, countries, tribes and about 7,000 real place names. Today it is written inside Python code. A tool writes it out once as plain text files that Godot reads. |
| **The map builder** | The code that turns the geography data into the hex map: which hex is land or sea, the terrain, rivers, ridges and passes, provinces and their names, countries, towns, castles, roads, starting armies. It is rewritten in Godot. It uses luck for the terrain, so Godot's Europe has the same coasts and cities but not the same forest on the same hex. |
| **The map file** | The Europe that the Godot builder made and that you approved, saved as one file in the game. Every new game starts from it. It changes only when the builder is run again on purpose, and then it is reviewed again. |
| **Contact sheet** | One page of small pictures side by side: here the same twelve regions in the Python game and in the Godot game, so the two Europes can be compared at a glance. |
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
| **0.3.0** | The map | Open the Godot build. See Europe 1480, built by the Godot map builder: terrain, countries, rivers, roads, towns, castles, names. Pan and zoom smoothly, switch between the terrain and the countries view, see the province under the mouse. No game yet. | XL, 6 to 8 weeks (about 3 of them are the map builder) | The new Europe passes the map check (B5): coasts, cities, rivers and big castles on the same hexes as in Python; the terrain mix, provinces per country, towns, roads and population inside the Python ranges. The contact sheet is signed by the art director and by you. A steady 60 frames a second on the low-end PC. |
| **0.3.1** | The world turns | Press "End season": prices, production, trade, incomes, growth, research and debt run, with no armies and no AI. The top bar and a read-only province panel show the numbers. The map gains ground blends, coasts and ridges. | L, 4 to 5 weeks (one of them is the reference report, measured from the model) | The reference report exists. The economy bands for a world where nobody acts: totals per decade inside the model's ranges. The economy, trade, research and debt tests pass in Godot. |
| **0.3.2** | Armies and battles | Take any country's armies and move them, attack, besiege or storm (you play all sides; no AI yet). Battles, sieges, castle areas, supply and winter work. The map gains unit tokens, marches, battle and siege marks. | L to XL, 4 to 5 weeks | The battle bands (win rates, length and losses per scenario) and the siege table (seasons to take each castle). The movement, supply, battle and siege tests pass. |
| **0.3.3** | The AI plays | Start a new game and watch every country play by itself, to 1650. War, peace, colonies, the fog of war, a "thinking" marker while the AI works. | L, 3 to 4 weeks | The bands for whole games: wars, battles, provinces changing hands, the biggest country's share, the economy and research, each per decade. AI time per season inside the budget. Long unattended games with no error. |
| **0.3.4** | Your turn | Play a country properly: build, recruit, found colonies, pick research, send merchants, end the season, save and load. Province and unit panels, the odds card, the log, the task flag, the move messages. | XL, 4 to 6 weeks | You play 30 seasons with no blocker. The tests of every player action pass. Save, quit, load gives the same game. |
| **0.3.5** | Every screen | The rest: the battle screen, the siege panel, war and peace, the tech screen, market, country and ledger panels, menus and settings, the close-up landscape (trees, hills, winter) and the moving "life" on the map. The complete game. | XL, 4 to 6 weeks | A checklist of every screen next to Python, signed by the art director and by you. Your full playtest. All bands measured once more on the finished game. |

**Total: about 25 to 34 engineer-weeks** (the second version: 22 to 30; the first: 32 to 45). After 0.3.5, 0.4.0 is
the castles map mode.

**Why 0.3.0 is not split in two.** A smaller first release was possible: first a viewer of a temporary map written
out by Python, then the builder. It was not chosen, for three reasons. The owner's direction is "build the map
first". The temporary map and its reader would be thrown away one release later (about a week of work for nothing).
And everything after 0.3.0 (the economy, the armies, the AI, the behaviour bands) is measured on the Europe that
ships, so that Europe must be settled before the rules are ported onto it. The price is a first release of 6 to 8
weeks. It stays showable throughout by internal builds, in this order: an empty window; the coast and the countries
in flat colours; then terrain, roads, names and the tile art.

**Design runs beside 0.3.0.** While the map is built, the design team designs the game elements of the next
releases on paper (designs, mockups, briefs for 0.3.1 onwards), as the studio process allows: the next release is
planned while the current one is built, and its brief is locked after the owner has played the current one.

In each release the rules and the map's look move forward together. They share no files, so they do not slow each
other, and every release has something new to see.

### A4. What "close enough" means

- **Rules: the same rules, not the same games.** The Godot code is written from the Python code, rule by rule, and
  the Python tests are rewritten for Godot. The luck differs, so single games differ.
- **Behaviour: inside the bands.** Battles, sieges, war pace, the economy and AI speed are measured in both games.
  Where Godot is outside a band, the systems designer finds out why. It is then either a bug (fixed) or a
  difference you are told about in the release notes.
- **Looks: the same to the eye.** Same art, same information in the same place, checked with screenshot pairs.
- **The map: the same Europe, not the same hexes.** Coasts, rivers, cities, countries and the big castles are
  where they are today. Forests, hills, small towns, towers and roads fall a little differently, as they do
  between two seeds of the Python builder. You approve the new Europe on a contact sheet before it is frozen.
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
- **Continues on paper, starting during 0.3.0:** the design of the game elements for 0.3.1 onwards (how each
  rule and screen is laid out in Godot; the screens stay today's) and the designs, mockups and briefs for 0.4.x.
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
6. **The new Europe is a new map.** It has the same coasts, cities and countries, but its terrain is rolled
   again, so a place you know may have lost its forest or gained a hill. The counts guard the whole; your look at
   the contact sheet guards the places you care about. Expect one or two rounds before you sign.
7. **The first release is the largest.** The map builder is about 1,500 lines of rules and 8,000 lines of
   geography, and it now sits in the first release. The brief has a cut list (province contents and starting
   armies can move to the release that first uses them).

**The last cheap exit is after 0.3.0.** Until then the Python game is untouched and complete. If the map in Godot
disappoints, or the speed test fails with no way out, that is the moment to say stop.

### A8. Decisions

The two decisions of the second version are answered (answers 5 and 6 at the top). What is left is small and
belongs to the first release; it is asked in `docs/roadmap/release-0.3.0-brief.md`.

Everything else in this plan is a technical default; the owner may overrule any of it.

---

## Part B. Technical appendix

### B1. Evidence (measured in the repo, 2026-11-14, at v0.2.2)

- `hexa/campaign/` and `hexa/ui/`: about 39,800 lines. Rules (`systems/`, 19 modules), `world.py` 782, `ai.py` 806,
  `state.py` 270, `data.py` 503, `tech.py` 530. Tests: 1,488 test functions, 323 of them window tests.
- **Not ported:** `randomgeo.py` 1,286 (random worlds).
- **The map builder, ported in 0.3.0** (about 1,550 lines of code and 8,000 lines of data): `geo.py` 550 (the
  projection, point-in-polygon, line distances, `land_cells`, the desert, steppe and marsh tests: about 125 lines
  of code, the rest is data), `systems/worldgen.py` 642, `wfc.py` 85, `naming.py` 270, and the data of
  `regions.py` 739 (684 named regions) and `placenames.py` 6,952 (GeoNames, CC BY 4.0: the credit travels with
  the file and into the game's credits). The builder also reads a few tables of `data.py` (`TERRAIN`, `AREA`,
  `SETTLEMENT_POP`, `WORKS`, `GARRISON_HP`, `TERRITORY_RADIUS`, the unit kinds) and `specialgoods.py`.
- **What the Python builder's luck touches** (measured: Europe at seeds 1480 and 1 to 7). The same in all eight:
  land and sea per hex, cities, river hexes, ridge and pass edges, passes, castles of level 2 and 3, towns of size
  2 and 3, coastal provinces, markets. Different: terrain per land hex (two seeds agree on 62 percent of the
  hexes), and what follows from terrain: owners (99.5 percent of hexes agree), descriptive province names (61
  percent), roads, towers, small towns, goods, population, where starting units stand. The figures are in B5.
- **Geography the running game reads** (ported as plain maths and data in 0.3.0): the projection (`lonlat`,
  `hex_of`, `merc`, `inv_merc` and their constants: used by the AI, trade, colonies, research, the season and the
  map view), and the tables `KNOWN_WORLD` (a Python lambda today: it becomes a few numbers and a Godot function),
  `START`, `MARKETS`, `COUNTRIES`, `CITIES`, `TRIBES`, `MOUNTAINS`, `FERTILE_RIVERS`, `COASTAL_KNOWLEDGE`,
  `COLONIAL`.
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
    geography/             exported once: projection, land outlines, rivers, mountains, passes, cities,
                           countries, tribes, regions, place names (with their licence note)
    maps/europe_1480.json.gz   the map file: made by the Godot builder, reviewed, committed (B5)
  assets/atlases/          baked by the Python tool: png + a json index; committed
  core/                    pure GDScript, no Node, no scene, no engine singletons; runs headless
    hexgrid.gd  rng.gd     rng.gd wraps one seeded RandomNumberGenerator; the only source of luck in core/
    data/                  loaders, with a schema that says which numbers are whole numbers
    state/                 Province, Market, Route, Country, Unit, Garrison, War, Battle (typed, to_dict/from_dict)
    geo.gd                 the projection and the polygon maths
    mapgen/                the map builder: land, terrain (wfc.gd), rivers, ridges and passes, provinces and
                           names, countries, towns and castles, roads, starting units; one file per step
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
  tests/core/  tests/shell/  tests/fixtures/     fixtures: europe_reference.json, bands.json, worked examples
  tools/                   build_map.gd, map_report.gd, bands.gd, soak.gd, perf.gd (headless scripts)
  addons/gut/
hexa/                      the Python game at v0.2.2: frozen; the model and the art baker
tools/                     Python: the exporters (B5, B7, B4) next to today's tools
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
  time, once. The 20 model games run on the Python Europe of seed 1480 and vary only the luck. The Godot games
  run on Godot's Europe, which is a different map of the same geography. That is why the map check of B5 includes
  the things the economy stands on (population, the goods mix, towns, provinces per country): a band missed
  because the two maps differ is a map question, and B5 is where it is caught first.

**2. Unit tests as specs (GUT).** B10.

**3. Worked-example tables** for rules with no luck in them: costs, prices from a given stock, supply limits,
step costs, castle areas, the siege meter per season, the odds word. The two games no longer share a map, so the
examples are asked on small **fixture worlds**: a Python tool cuts patches out of the model's Europe (terrain,
rivers, ridges, owners, castles, units) and writes them, with the inputs and results of the model's functions, to
JSON fixtures; a GUT test loads each patch into the Godot state classes and asks the Godot functions the same
questions (whole numbers equal; fractions within a small tolerance). This is cheap and exact where exactness costs nothing,
and it is the main guard for risk A7.2. It is made per system, in the release that ports the system.

Plus, as today: a **soak** (full games with the invariants of `tests/support/invariants.py` checked every season)
and the **owner's playtest checklist** in each brief.

### B5. Data, the geography and the map builder

**Numbers.** `tools/export_data.py` writes `data.py`, `tech.py` and `specialgoods.py` as JSON into `godot/data/`.
The Python modules are not changed (the model is frozen). After the export the JSON files are the source of truth
for the Godot game: balance changes in 0.4.x edit them directly. The export is run again only if it had a mistake.
Proof: a Python test that the files read back equal to the modules' tables; a GUT test that loads every file
through its schema. The export is made in 0.3.0, because the map builder reads some of the tables.

**Geography data.** `tools/export_geography.py` writes the tables of `geo.py`, `regions.py`, `placenames.py` and
the word lists of `naming.py` once, as JSON under `godot/data/geography/`:
- the projection constants (the corner of the map, degrees per column and row, `SCALE`);
- outlines as lists of longitude and latitude points: the land (Europe and Asia, Scandinavia, Britain, Ireland,
  Africa, the Americas, the islands), lakes, seas, forced sea and land points, deserts, steppes, the Maghreb,
  marsh boxes;
- lines and points: 35 rivers, the fertile rivers, 18 mountain ranges with their heights, hills, 24 passes;
- 102 cities, 49 countries, 41 markets, 56 tribes, the known world, coastal knowledge, colonial start years;
- 684 named regions, the place names (three per hex at most, biggest first), exonyms and the naming words.

Nothing is retyped by hand. Proof: a Python test that the files read back equal to the modules' tables; a GUT test
that loads every file and checks the counts above. After the export these files are the source of truth: a later
change to a coastline or a city is an edit of a data file, followed by a rebuild and a review of the map.

**The map builder** (`godot/core/mapgen/`, pure GDScript, no Node, luck only through `rng.gd`). It is ported step
by step from `geo.py`, `systems/worldgen.py`, `wfc.py` and `naming.py`, in the model's order:
1. *Land and sea:* each hex centre is turned into longitude and latitude (Mercator) and tested against the
   outlines; lakes, forced points, sea bodies and landmasses follow.
2. *Rivers, ridges and passes:* rivers traced along the hexes, crest edges from the mountain lines, passes and
   their names, pockets joined.
3. *Terrain:* a prior per hex (latitude, mountains, deserts, coast, river) and the wave function collapse with
   the forbidden neighbour pairs.
4. *Provinces and names:* one province per land hex, its region, its name (city, real place, or description).
5. *Countries:* territory around the cities, tribes, population, goods, towns, castles, buildings, garrisons.
6. *Roads,* then *starting units.* The markets and the start techs are running rules (trade, research) and come
   with 0.3.1.

Each step has its GUT tests, rewritten from `tests/test_campaign.py`'s map classes, `tests/test_passes.py` and
`tests/test_naming.py`, and a small hand-made geography (one island, one river, two countries) on which every step
can be checked by hand.

**The map file.** The builder is not run when a game starts. `godot/tools/build_map.gd` runs it headless from a
fixed seed and writes `godot/data/maps/europe_1480.json.gz` (the map and the turn-0 province, country and unit
state, through the state classes' `to_dict`). The file is committed; a new game loads it and sets the player's
country and the luck seed. Reasons: the owner approves one Europe, and that exact Europe ships; a change to the
builder shows up as a changed file in review instead of a silently different map; loading is instant; and the
behaviour bands are measured on a map that stands still. CI rebuilds the file and compares it with the committed
one (same seed, same data, same file). Building in the game with another seed stays possible later at no extra
cost; it is not offered in the port.

**How the new Europe is checked.** `tools/export_map_reference.py` builds the Python Europe at seeds 1480 and 1
to 7 and writes `godot/tests/fixtures/europe_reference.json`: the per-hex facts that no seed changes, and the
range of every count that luck moves. `godot/tools/map_report.gd` prints the same table for the Godot map, and a
GUT test holds the rules. Measured in the model at v0.2.2:

| What | Python (seed 1480; range over 8 seeds) | Rule for Godot's Europe |
|---|---|---|
| Grid | 203 x 150 = 30,450 hexes | Equal |
| Land, ocean, lake hexes | 14,411 / 15,956 / 83, the same in every seed | Equal per hex. A difference is listed and explained (a hex centre on an outline); more than 5 is a bug |
| Coastal provinces | 1,459 | Equal, given the land |
| Cities | 102, same hexes | Equal per hex, same names |
| Rivers | 35 rivers, 680 river hexes | Equal per hex |
| Ridges and passes | 441 ridge edges, 47 pass edges, 72 passes | Equal, same pass names |
| Countries | 49 | Equal, same capitals |
| Castles 2 and 3 | 42 and 7, same hexes | Equal per hex |
| Towns of size 2 and 3 | 73 and 33 | Equal |
| Terrain mix (land hexes) | jungle 2,548 (2,490 to 2,585), plains 2,228 (2,197 to 2,292), desert 2,002 (2,002 to 2,056), forest 1,971 (1,830 to 1,971), savanna 1,241 (1,199 to 1,321), taiga 1,233 (1,212 to 1,304), hills 883 (852 to 920), mountains 749 (749 to 787), steppe 640 (571 to 640), tundra 498 (460 to 528), marsh 287 (234 to 287), snow 82 (59 to 115), beach 49 (49 to 82) | Each kind inside the Python range widened by 10 percent of its median (at least 25 hexes) |
| Provinces per country | 4,311 owned in all (4,292 to 4,315); the largest spread is Tunis, 140 to 158; most countries do not move | Each country inside its Python range widened by 5 percent (at least 3 provinces); owner per hex equal to the Python map on at least 99 percent of the land |
| Towers (castle 1) | 18 (11 to 21) | 9 to 24 |
| Small towns (size 1) | 432 (392 to 447) | Inside the range widened by 10 percent |
| Roads | 623 road hexes (595 to 630), 349 road paths (348 to 350) | Road hexes inside the range widened by 10 percent; every pair of cities joined in Python is joined |
| Population | 31,721 (31,046 to 32,047) | Within 5 percent of 31,500; each country within 15 percent |
| Goods | 25 goods; provinces with none 1,963 (1,963 to 2,016) | Each good's count within 15 percent of the Python median (at least 10 provinces); every good present |
| Starting units | 133 (130 to 133): 83 pikemen, 28 knights, 10 bombards, 7 generals, 5 caravels | Same kinds per country; each on land (ships at sea) inside its country |
| Province names | 14,411, all different | All different; city and pass names equal; no empty name |

There is no per-hex comparison of terrain: two Python seeds agree on only 62 percent of the land hexes, so it
would prove nothing. The terrain is judged by its mix (above), by the rules the Python tests state (no mountain
beside plains, marsh, beach or steppe; deserts where the outlines say; the Alps a wall with its passes open), and
by eye.

**The review by eye.** A contact sheet: the same twelve regions (Iberia, France, the British Isles, the Low
Countries and the Rhine, the Alps and northern Italy, southern Italy, the Balkans, Anatolia, Poland and Lithuania,
Scandinavia, the Maghreb, the Caribbean coast) in the Python game and in the Godot game, in the terrain view and in
the countries view, plus the whole map in both views. The builder is run for a handful of seeds; those that pass
the counts go on the sheet. The art director reviews first (ugly spots, odd terrain, broken coasts, roads through
mountains) and proposes one; the owner signs it. Only then is the map file frozen. A later change to the builder
or the geography repeats the counts and, if anything on screen moved, the sheet.

**Speed.** The Python builder takes about 2 seconds. The Godot builder runs as a tool, so its budget is loose:
under 30 seconds headless. Its road search is the first real path finding in Godot and feeds the speed probe (B9).

**Later map changes** (fewer towns, province names, another coastline) are made in Godot: edit the geography data
or the builder, rebuild the map file, review. The Python builder is not used again after 0.3.0 except as the model
the bands are measured on.

Text shown to players stays in the data files in English, keyed, ready for Godot's translation system later.

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
  them. The bake is made on Linux in CI (as the goldens are) and its hashes are kept in a manifest. (The art is
  still baked from Python; only the map is built in Godot.)
- **Bake size:** hex radius 60 px (tile 104 x 120), about twice the closest zoom of today, with 2 px extruded
  borders and mipmaps so far zooms and odd zoom factors show no seams.
- **The art inventory** (a 0.3.0 deliverable) sorts everything drawn today into three groups:
  1. *Baked as it is:* terrain and goods tiles, objects (trees, peaks, farms), towns, castles, landmarks, unit
     tokens, icons, badges.
  2. *Baked as pieces, layered in Godot:* what is composed per hex at run time today: ground blend bands by pair of
     ground kinds and edge, ridge crests by edge, the coast, river and road tiles by edge mask, winter variants.
  3. *Redone in Godot:* borders, fog, map-mode tints, labels, selection and path marks, the "life" animations,
     floating text. These become shaders, lines, tweens.
- Which variant sits where (today a hash of the position) is chosen by the Godot builder and stored in the map
  file. The terrain differs from Python's anyway, so the Python hash is not copied.
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
- **The speed probe** (in 0.3.0, on real code and the built map): the map builder's own road search and
  territory flood in typed GDScript, against Godot's `AStar2D` and against the same functions in Python. Reported
  as ratios, with the builder's total time.
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
  - *The map builder's tests* (the map classes of `test_campaign`, `test_passes`, `test_naming`): rewritten in
    0.3.0 with the builder, plus the map check of B5.
  - *Not ported:* tests of Conquest, Colonisation, random worlds, the Python oracle, pickle saves and
    save-compat, the sprite hashes (they stay with the baker).
- Each release brief names the Python test modules it ports, so the count is visible: ported, replaced by a
  worked-example table, or dropped with a reason.
- **Goldens:** screenshots of fixed scenes, made in CI on Linux under a virtual display with software rendering
  (true headless mode draws nothing), compared with a pixel tolerance as today. They change only with a reviewed
  art or layout change.
- **Soak and monkey:** headless scripts (full games with invariants each season; random input on the shell).
- **CI on GitHub Actions:** Godot downloaded at a pinned version with a checksum, export templates cached.
  On pull requests: lint and project load; GUT tests; the map rebuild and its check; goldens. On tags: the
  Windows export and a smoke start.
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

Pin **Godot 4.7.2-stable** (released 18 August 2026; checked on godotengine.org and on the engine's GitHub
releases on 2026-11-14, where it is the latest stable). If a newer 4.x stable is out on the day 0.3.0 starts, take
that one and write it down in the brief. The same version is pinned on the build machine and in CI, with the
download's checksum. Upgrade only between releases, never inside one, and only with the tests and goldens green
before and after.

### B13. The Python line, frozen

- `v0.2.2` is the last Python release. There is no Python 0.3.0.
- `hexa/` is not edited again: no fixes, no refactors, no balance changes. The Python `tools/` folder gains the
  exporters (`export_data.py`, `export_geography.py`, `export_map_reference.py`, `bake_art.py`,
  `behaviour_bands.py`, the worked-example writers); they import `hexa` and use its public API, as `tools/battle_stats.py` does. A CI check fails a pull
  request that changes a file under `hexa/`.
- The rest of the Python refactor (architecture plan, phases still open) is closed as "not continued".
- At 0.3.5: Conquest, Colonisation, the legacy editor, the pygame window code and their tests leave the main
  branch (the tag `v0.2.2` keeps them). What stays is what the tools need: the rules and the world the measuring
  tools run (the model), and the art modules, labelled as build tools, not as the game. The Python map builder
  stays only as part of that model; the game's map is made by the Godot builder.

### B14. Follow-up edits in other documents (listed, not made)

- **`docs/roadmap/roadmap.md`**
  - "Next up": the 0.3.x "New engine" line with the six releases; the castles map mode moves to 0.4.0; the
    battle board, the trade patch, field forts, battle cards, the battle mini-map and war goals and peace follow
    in 0.4.x.
  - Section 3 "What exists today": Python frozen at v0.2.2; Age of Discovery on Europe is the game; Conquest,
    Colonisation and random worlds are retired.
  - Backlog and M5: remove "the random-world start country" and any other random-world item; mark map fixes
    (fewer towns, province names, coastlines) as "in the Godot map builder, with a map review".
  - Record the seven answers of 2026-11-14 in the "Answers so far" section; point to this plan.
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
- **The first brief:** `docs/roadmap/release-0.3.0-brief.md` (written; locked by the owner's go).
- **Credits:** the GeoNames credit (CC BY 4.0) moves with the place names into `godot/data/geography/` and the
  game's credits screen.

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
| The Godot builder has a porting mistake that the counts do not show | The per-hex facts must be equal (land, cities, rivers, ridges, big castles); the builder's own tests; the hand-made small geography; the contact sheet |
| The new Europe shifts the economy or the war pace | The map check includes population, goods, towns and provinces per country; the bands of 0.3.1 and 0.3.3 are read with the map report beside them |
| The map file differs between machines (maths in the last digit) | The file made in CI is the one that ships; other machines check counts, not the file's hash; the land test is exact because both games test the same points against the same outlines |
| The owner does not like the new Europe | Several seeds on the contact sheet; the art director's pick first; the map file is frozen only after the owner signs |
| 0.3.0 runs long | Its cut list: province contents (population, goods, buildings) and starting units move to 0.3.1 and 0.3.2; landmarks |
| Web is closed off by accident | The web-safe lint rules; the two trial web exports |

---

## Part C. The first release

The brief of 0.3.0 is its own file now: `docs/roadmap/release-0.3.0-brief.md`. It holds the theme, the scope with
sizes, the cut list, the defaults, the done-when list, the risks, the playtest checklist and the decisions left.
