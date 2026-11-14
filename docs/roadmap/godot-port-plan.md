# The Godot port plan


> **Owner's decisions (2026-11-14), to be worked into a revised plan:** (1) the Godot game may play *somewhat
> differently* from Python: no exact season-by-season match, no own-dice/rounding work, checked by measured balance
> (battle, siege and war-pace numbers close to Python's) and by the owner's play; (2) **Europe only**: random worlds are
> not ported; (3) saves do not carry over, and bugs found during the port are fixed in Godot only (Python is frozen as
> v0.2.2); (4) builds are **Windows only**. Language: GDScript (web/mobile wanted later).
Technical director, 2026-11-14. **A plan on paper: nothing is built or approved yet.** Part A is for the owner, in
plain words. Part B is the technical appendix. Part C is the draft brief of the first release.

**What the owner decided on 2026-11-14** (against the advice of both studies,
`docs/architecture/2026-11-14-engine-and-language.md` and `docs/research/2026-11-14-engine-move-director-view.md`):

1. **Port to Godot now.** v0.2.2 (sieges, castle areas) is the last Python release with new features.
2. **Web and mobile versions are wanted**, so the language is **GDScript**. (C# cannot be exported to the web in
   Godot 4.)
3. **During the port the owner plays regular Godot builds** that match more and more of today's game, checked
   against the Python game on the same seeds. New features wait until the Godot game matches.

Only Age of Discovery is ported. Conquest, Colonisation and the old tile editor stay behind in the Python code.

---

## Part A. For the owner

### A1. The idea in five sentences

- The Python game becomes the **yardstick**: the Godot game is correct when it plays exactly the same games.
- To make that checkable, the Python game first gets one last release (0.3.0) that changes nothing you can see,
  but makes it possible for a second program to copy it exactly.
- Then the Godot game grows in playable steps: first the map, then the world turning, then armies and wars, then
  the AI, then your own turn, then every panel and screen, then random worlds.
- After each step a machine plays the same games in both programs and compares them, season by season.
- When everything matches, the Python game is retired and new features start again, in Godot.

### A2. The words used in this plan

| Word | What it means here |
|---|---|
| **Seed** | The number a game starts from. The same seed gives the same map and the same luck. |
| **Dice** (random numbers) | The game's luck: battle rolls, natives raiding, the AI breaking ties. Today the dice come from a part of Python that Godot does not have. We write our own small dice, the same in both programs, so both roll the same numbers from the same seed. |
| **Rounding and ordering rules** | Small habits of a language: is 2.5 rounded to 2 or to 3; which of two equal armies comes first in a list. Python and GDScript have different habits. We write our own rules for these, used by both. |
| **Fingerprint** (digest) | A short code worked out from the whole state of a game (every province, army, treasury, war). Two games with the same fingerprint are in exactly the same state. |
| **The referee** (the oracle) | A tool that plays the same fixed-seed games in Python and in Godot and compares the fingerprints after every season. If they differ, it names the first season and the first thing that differs. We already have one that compares two versions of the Python game; it is extended to compare Python with Godot. |
| **Data files** | The game's numbers (goods, prices, troops, buildings, the tech tree, place names) are written inside Python code today. They move into plain text files that both programs read. One copy, no retyping. Later, players can edit them (mods). |
| **Plain saves** | Today a save is in a format only Python can open ("pickle"). The new save is plain text that both programs can read and write. A Godot build can then open a game saved in Python. |
| **Baked art** | Today the game draws its tiles, trees, towns and units with code each time it starts. A tool runs that code once and writes the pictures into image files. **Atlas** is the name for one big image holding many small pictures. Godot loads the atlases. The look does not change. |
| **Headless** | Running the game with no window, so a machine can test it. |
| **CI** | The machines on GitHub that run all tests on every change. |
| **Export** | Godot's word for making a build for one platform: Windows, web, Android, iOS. |
| **Parity** | The Godot game matches the Python game. For rules that is exact and checked by the referee. For looks it means "the same to the eye", checked with screenshots side by side, by the art director and by you. |

### A3. What you will play, release by release

The port takes the **0.3.x** numbers ("New engine"). The roadmap phases that had 0.3.x onwards (the living world,
history and events, the sea, game feel) each move up one number. The war features that were next (the castles map
mode, the battle board, war goals and peace, the trade patch) become **0.4.x**, the first feature line in Godot.

Sizes: **L** means about as much work as the whole 0.2.2 sieges release; **XL** is about two of them. The weeks are
"engineer-weeks" as in the engine study (one full-time developer with AI help, plus or minus 30 percent). At the
studio's pace calendar time is much shorter, but the proportions hold.

| Release | Name | What you can do in it | Size | What proves it is done |
|---|---|---|---|---|
| **0.3.0** | The yardstick (Python) | Play the Python game as before. Nothing looks different. Your 0.2.2 saves open and are saved again in the new plain format. Fixed seeds play out differently from 0.2.2, once (new dice). | XL, 3 to 5 weeks | All Python tests pass. The referee's games are recorded as files. Saves go round trip with equal fingerprints. Balance is re-measured and inside today's targets. The art contact sheets look like the game. |
| **0.3.1** | The map | A Godot build for Windows and for the browser. It opens a real save, shows the Europe map with terrain and countries, pans and zooms smoothly, names the province under the mouse. No game yet. | L to XL, 3 to 4 weeks | Screenshot pairs at fixed places and zooms. Every province's owner and terrain equal the save. Frame time on the low-end PC and in the browser. The speed measurement (A5) is on the table. |
| **0.3.2** | The world turns | Press "End season": prices, production, trade, incomes, growth, research and debt run. The top bar and the map change. No armies move, no AI. The map gains rivers, roads, towns, castles and names. | XL, 4 to 5 weeks | The referee: 40 seasons with every country idle, on Europe and two random maps, equal fingerprints every season. A Godot save opens in Python and gives the same fingerprint. |
| **0.3.3** | War, played back | Watch a whole game the Python AI played, played back in Godot: armies march, battles, sieges, castle areas, peace. The map gains unit tokens, march animations, battle and siege marks. | XL, 4 to 6 weeks | The referee replays Python's recorded moves in Godot: all its suites, then one full game 1480 to 1650 on Europe and two random maps, equal every season. |
| **0.3.4** | The AI plays | Start a new Europe game in Godot and watch every country play by itself, to 1650. The close-up landscape (trees, hills, ridges, winter) and the fog are in. | L to XL, 3 to 4 weeks | Full all-AI games equal Python's every season, with the Godot AI making the moves. AI season time is inside the budget on PC and in the browser. |
| **0.3.5** | Your turn | Play a country: select and move armies with the path and the move messages, attack, besiege or storm, build, recruit, found colonies, end the season, save and load. Province and unit panels, top bar, log. | XL, 4 to 6 weeks | You play 20 seasons with no blocker. The panels' numbers are checked by machine against Python's. A game you played in Python 0.3.0 is replayed in Godot with equal fingerprints. |
| **0.3.6** | Every screen | The odds card, the battle screen, the siege panel, war and peace, the tech screen, the market and country panels, reminders and task flags, menus, settings, the moving "life" on the map. | XL, 5 to 7 weeks | A checklist of every screen, side by side with Python, signed off by the art director and by you. Screenshot tests exist for each screen. |
| **0.3.7** | Random worlds | New game on a random map from a seed, in Godot, with no Python involved. | L to XL, 3 to 4 weeks | For 20 seeds the Godot map equals the Python map hex by hex; full games on 3 of them match. |
| **0.3.8** | Switch-over | The complete game in Godot: Windows and web. You play it as you would a normal release. | L, 3 to 4 weeks | Your side-by-side playtest. Long unattended games, saves, speed and memory checks all pass. Python saves from 0.3.0 open. The Python game is retired. |

The total is about 32 to 45 engineer-weeks, the same range as the engine study. After 0.3.8: 0.4.x brings features
back. A phone version with a touch UI, and Steam, come later (A6).

**Two tracks run side by side** in 0.3.2 to 0.3.4: the rules (checked by the referee) and the map's look (checked by
eye). They share no files, so they do not slow each other, and every release has something new to see.

### A4. What "the same game" means

- **Rules: exactly the same,** proved by machine. Same seed and same moves give the same fingerprint every season.
- **Looks: the same to the eye.** Same art, same information in the same place. Checked with screenshot pairs.
- **A short list of differences on purpose,** because Godot gives them for free: smooth zoom instead of six fixed
  steps, sharper text, a window that can be resized. Anything else that differs is a bug.
- **You can check it yourself:** both games show a small season code (the fingerprint, shortened) in a corner. A
  game you played in Python can be saved as a list of moves; Godot plays it back and shows the same codes.

### A5. The honest part: speed, web and phones

- **GDScript is not faster than Python.** It is in the same class, sometimes slower. Today an AI season takes
  0.13 to 0.25 seconds in Python. In GDScript, expect about the same on a PC, perhaps 2 to 3 times more in a
  browser, more again on a phone. For a turn-based game that is acceptable if the screen never freezes.
- **So the season is built to run in small slices** from the first day: one country at a time, a few milliseconds
  per frame, with a "thinking" marker. This is also needed because the simple web build cannot run work in the
  background.
- **We measure early, in 0.3.0 and again in 0.3.1,** with a small throw-away test (path finding and one season
  loop on the real map, in GDScript, on PC, in a browser, on a phone if one is at hand). The pass line: a late-game
  AI season under 1 second on the low-end PC and under 3 seconds in a browser.
- **If it is too slow,** in this order: (1) smarter code (remember paths within a season, flat number arrays);
  (2) Godot's own built-in path finder, which is fast and works on every platform; (3) only as a last step, a small
  fast module in another language (a "GDExtension"). I looked for a strong reason to plan that module now and did
  not find one. It would work on Windows, Android and iOS, but on the web it needs a special build and special
  server settings, and every platform needs its own compiled copy. The plan keeps the path finder behind one door
  so it can be swapped later, and does not build the module.
- **Web limits to know:** saves live in the browser's storage and are lost if the player clears it (we add "save
  to file" and "load from file"); the first load downloads tens of megabytes; sound starts only after the first
  click; no Steam features; phone browsers are weaker and less reliable than PC browsers.
- **Phones need a new UI, not just a build.** Today's game leans on hover cards and right-click. A phone has
  neither. A touch UI is design work for after parity. Android builds need Google's tools; iOS builds need a Mac
  and a paid Apple developer account. During the port, "web" means a PC browser.

### A6. What pauses, and what does not

- **Pauses until 0.3.8:** every new feature, starting with the castles map mode, the battle board, war goals and
  peace, the trade patch; the rest of the Python refactor; balance changes.
- **Continues on paper:** designs, mockups and briefs for 0.4.x, as the studio process already allows.
- **Continues in code:** crash fixes in the Python game (see decision 3).
- **Later, each its own decision:** touch UI and phone builds; Steam (store page, Steam features, Steam Deck).

### A7. Risks, in plain words

1. **The fun question waits.** Your v0.2.0 verdict was that war "wasn't really engaging". The port adds nothing
   to that for many weeks. This is the price you chose; it should stay visible.
2. **The two games drift apart in tiny ways** (a rounding, an order) and the referee keeps failing. The fix is
   the 0.3.0 work; without it the port cannot be checked at all.
3. **The map's look.** Some of today's art is put together per hex while the game runs (ground blends, ridges,
   coasts). It must be split into pieces Godot can layer. How well that splits is not known until the art
   inventory in 0.3.0.
4. **The UI takes longer than planned.** It always does in ports. 0.3.5 and 0.3.6 are the likely overruns.
5. **The team is new to Godot.** The agents know Python best; they can mix up Godot 3 and Godot 4, and they cannot
   see Godot's visual editor. Automatic checks and screenshot tests are the guard (B3, B10).
6. **Speed on web and phones** (A5).
7. **Two code lines.** Any rule changed during the port must be changed twice. So rules are frozen.

**The last cheap exit is after 0.3.1.** Until then little is lost: 0.3.0 is still a complete Python game, and
better than before (plain saves, data files). If the map in Godot disappoints or the speed test fails with no way
out, that is the moment to say stop.

### A8. Four decisions before 0.3.0 starts

**Decision 1. The Python game changes once, so it can be the yardstick.**
In 0.3.0 the dice and the rounding rule are replaced. The rules stay the same, but a given seed plays out
differently from 0.2.2 (other battle rolls, other AI tie-breaks), and the balance numbers are measured again.
Your 0.2.2 saves still open and are re-saved in the new format.
- **(Recommended) Yes.** Without this, nothing can check the Godot game against the Python game.
- No: keep today's dice. Then the port is checked only by playing and by eye; rule bugs stay hidden for a long time.

**Decision 2. How much must match before features come back.**
- **(Recommended) Everything in Age of Discovery, random worlds included (through 0.3.8).** One finish line, no
  half-game left in Python.
- Europe only (stop after 0.3.6, random worlds come during 0.4.x): features return about 3 to 4 weeks sooner, but
  the Python game must be kept alive longer as the yardstick for the map builder.

**Decision 3. Bugs found in the Python game during the port.**
The studio rule is "fix issues first". During the port every rule fix must be made twice and the referee's
recorded games made again.
- **(Recommended) Crashes and broken saves are fixed at once, in both games. Other rule bugs are written down and
  fixed in the first release after parity,** unless the fix is tiny. The Godot game copies the Python game,
  known bugs included, so the referee stays strict.
- Fix every bug at once in both: the rule is kept to the letter, the port is slower and the referee is re-based often.
- Fix bugs only in Godot: the two games differ on purpose and exact checking ends there.

**Decision 4. Where you play the builds.**
- **(Recommended) A Windows zip on each GitHub release, as today, plus a private web page for the browser build**
  (for example an unlisted itch.io page: only people with the link can open it; you create the account). It proves
  the web version every release, and you can open the link on a phone to see how far it is.
- Windows only until parity; the web build is made and tested by CI but not published. Simpler, but web problems
  surface late.
- A public web page (GitHub Pages): anyone can play unfinished builds.

Everything else in this plan is a technical default; the owner may overrule any of it.

---

## Part B. Technical appendix

### B1. Evidence (measured in the repo, 2026-11-14, at v0.2.2)

- `hexa/campaign/` and `hexa/ui/`: about 39,800 lines. Rules (`systems/`, 19 modules), `world.py` 782, `ai.py` 806,
  `state.py` 270, `data.py` 503, `tech.py` 530, `placenames.py` 6,952, map building (`geo`, `regions`, `randomgeo`,
  `wfc`, `naming`, `systems/worldgen.py`) about 3,570. Tests: 1,488 test functions.
- Determinism-sensitive constructs in the rules, AI, world and read models: about 115 random draws through 8 methods
  (`random` 38, `randint` 21, `uniform` 19, `choice` 17, `sample` 10, `shuffle` 6, `randrange` 3, `choices` 2);
  `round(` 36; `sorted(` 57; `heapq` 15; `set(` 59 and `frozenset` 29; `min(`/`max(` 152; `//` 12; `int(` 23.
  Library maths in the rules: `math.ceil` 2, `math.floor` 1, nothing else, no `**`. Map building has 24 uses of
  `sin`/`cos`/`sqrt`-class functions.
- The AI assigns to state directly in 3 places (`country.tax`, two `country.memory[...]`); all else goes through actions.
- The existing oracle (`tools/same_behaviour.py`) pins `PYTHONHASHSEED=0`: set order still leaks into behaviour somewhere.
- Speed (`tests/perf_budget.json`): AI season 0.125 s, late 0.251 s; battle phase 0.020 s; Europe build 2.08 s.
- Grid: `hexa/hexgrid.py`, pointy-top, odd-r offset `(col, row)`, sprite 60 x 70 at 1x, row step = 1.5 x radius.
  Map view zooms: hex radius 3, 5, 8, 13, 21, 34 px; landscape art from radius 21.
- Season order: `systems/season.py` `PHASES`, 16 phases.

### B2. End state: the project layout

Same repository, a `godot/` folder next to `hexa/`. One repo lets one CI job run both games for the referee.

```
godot/
  project.godot            Godot 4.x, pinned (B12); Compatibility renderer (the only one the web supports)
  data/                    the shared data files; the Python game reads these same files (one copy)
  assets/atlases/          baked by the Python tool: png + a json index; committed
  core/                    pure GDScript, no Node, no scene, no engine singletons; runs headless
    det/                   rng.gd, num.gd (rounding, floor division), order.gd (stable sort, heap, first-min)
    hexgrid.gd
    data/                  loaders, with a schema that says which numbers are whole numbers
    state/                 Province, Market, Route, Country, Unit, Garrison, War, Battle (typed, to_dict/from_dict)
    systems/               one file per Python system, same names; season.gd holds PHASES
    world.gd               the facade
    game.gd                the game manager; the season as resumable steps
    ai/
    bus.gd                 the event bus: queued, with history
    views/                 read models: battle view, resources, reminders, feed, odds, province and unit views
    saves/                 the canonical reader and writer, and the digest
    mapgen/                (0.3.7)
  shell/                   everything with Nodes
    app/                   main scene; owns the Game; drains the bus once a frame and re-emits as signals
    map/                   map view and its layers
    hud/  panels/  screens/
    ui/                    one Theme (from theme.py's tokens) and the kit scenes
  tests/core/  tests/shell/  tests/fixtures/
  tools/                   oracle_runner.gd, soak.gd, perf.gd (headless scripts)
  addons/gut/
hexa/                      the Python game: the reference until 0.3.8
tools/                     Python tools: bake_art, the cross-language oracle, save tools
```

### B3. GDScript style rules (CLAUDE.md's structure rules, carried over)

- **Layers, references point down only:** data -> state -> systems -> world -> game -> views -> shell. Files in
  `core/` extend `RefCounted`, never `Node`; they use no scene tree, no autoload, no `Input`, `OS`, `Time`,
  `await`, and none of Godot's random functions. A lint script (text scan, run in CI) enforces it, as
  `tests/test_architecture.py` does today.
- **Actions are pairs:** `x_check(world, ...)` and `x(world, ...)` in the system's file, with a facade on the
  world. The shell and the AI change state only through actions. Every action call can be recorded (name and
  arguments); that record is what the referee replays.
- **Events:** systems call `world.bus.emit(kind, data)`. Inside `core/` the bus stays a queue with history, so
  headless tests and the referee can read events and no handler runs in the middle of a rule. The shell drains it
  once a frame and re-emits each event as a Godot **signal**; scenes connect to signals only. Handlers never change
  the world.
- **Read models:** scenes get plain view objects from `core/views/` and never touch `core/state` or
  `core/systems` (lint). The Python read models (`battleview.py`, `resources.py`, `reminders.py`, `feed.py`) are
  the templates; each ported panel gets its view first.
- **One owner per attribute** (`OWNS` per system), **season order only in `PHASES`**, **no cross-file private
  use**, and the **size limits** (module 800/1,200 lines, function 60/100) all carry over.
- **Typed GDScript everywhere,** with these warnings turned into errors: untyped declaration, unsafe access,
  integer division, narrowing conversion. Bare `round()`, `sort()`, `sort_custom()`, `%` on possibly negative
  numbers, `randi`/`randf`, and iterating a Dictionary used as a set without `order.gd` are banned in `core/` (lint).
- **Godot 4 only.** The lint also rejects Godot 3 spellings (`yield`, `export var`, `onready var`, string
  `connect`, `instance()`, the old `TileMap` node). CI loads the project with warnings as errors.
- **Scenes are text** (`.tscn`), small, laid out with containers and the one Theme. No hand-placed pixel positions.
  Every scene has a screenshot test, because the agents cannot see the editor.
- **UI:** buttons, rows, tooltips, modals come from `shell/ui/` kit scenes; colours and fonts from the Theme.

### B4. Determinism across Python and GDScript

Everything here lands in Python first (0.3.0), in one helper package, so the Python game becomes the reference.
The GDScript helpers are then line-by-line copies, tested against shared vectors (a JSON file of inputs and
expected outputs that both test suites read).

| Trap | Python today | GDScript | The rule for both |
|---|---|---|---|
| Random numbers | Mersenne Twister and its own `shuffle`, `sample`, `choice` | different generator | Our own generator: xoshiro128**, state of four 32-bit numbers, every step masked to 32 bits so it is exact in GDScript's 64-bit signed integers (32 x 32 multiplies done in 16-bit halves). `random()` from 24 bits (exact in a double). Whole-number ranges by rejection. `shuffle`, `sample`, `choice`, `choices` written by us. State saved in the save. |
| Rounding | `round()` goes to the even neighbour | half away from zero | One function, round half up (`floor(x + 0.5)`), used at all 36 sites. A deliberate, one-time change. |
| Division | `/` always gives a fraction, `//` floors, `%` follows the divisor | whole / whole truncates, `%` truncates | `fdiv`, `floordiv`, `posmod` helpers; integer-division warning is an error. |
| Number types from data | whole numbers stay whole | Godot's JSON reads every number as a fraction | The data loader casts by schema. |
| Sorting | stable | `sort_custom` is not stable | `order.sorted_by(list, key)`: our own stable merge sort; every key ends in a unique id. |
| `min`/`max` ties | first wins | not defined by us | `order.first_min`/`first_max`. |
| Priority queue | `heapq` on tuples | none | Our own binary heap with an explicit total order (cost, then a sequence number). |
| Sets | hash order, changes per run | no set type; Dictionary keeps insertion order | No rule iterates a set in hash order: sort first, or use an insertion-ordered dict. Proof in Python: equal digests under three `PYTHONHASHSEED` values; the pin in the oracle is then removed. |
| Fractions | IEEE doubles | IEEE doubles | Same operations in the same order give the same bits. Sums are written as loops. No library maths in rules beyond floor and ceil. |
| Text of numbers | `repr`, f-strings | different formatting | Digests never hash number text: fractions enter as their 8 raw bytes. Log text is compared separately from state (event kind and data are compared; wording is not). |
| Whole-number size | unlimited | 64-bit | An assert in Python on the few large products. |

**The referee, cross-language.** `tools/same_behaviour.py` grows a second mode:

1. Python plays each suite and writes a **trace**: per season the digest of each state section (countries, provinces,
   units, wars and battles, markets, random state, events), plus the recorded actions.
2. Godot, headless, plays the same suite and writes the same trace.
3. A Python differ compares. On a mismatch it loads both canonical states of that season and prints the first path
   that differs (`countries.POR.treasury`), so a failure names its cause.

Three kinds of suite, so blame is always narrow:
- **idle:** no country acts; proves the season phases (0.3.2).
- **replay:** Godot applies Python's recorded actions; proves movement, war, combat, sieges, peace (0.3.3).
- **ai:** Godot's AI acts; proves the AI, by action list first and by state second (0.3.4).

Suites: five of today's seven (Europe 1480, random 7 and 11, midgame, debt; the Conquest and Colonisation suites are not ported), extended to
40 seasons on pull requests and to full games (680 seasons) nightly. The canonical state is the same writer as the
save (B6), so there is one serialiser to keep right. The read models get the same treatment from 0.3.5 (same state
in, same view out).

### B5. Data in shared files

- `data.py`, `tech.py`, `specialgoods.py` and `placenames.py` become JSON files in `godot/data/`; the Python modules
  become loaders that expose the same names, so no other Python file changes.
- Proof: a test that the loaded tables equal a snapshot of today's constants; the oracle unchanged by that step.
- `geo.py` (the Europe polygons) is not ported. The built Europe world is written once as a **start file** (a
  turn-0 plain save); Godot starts Europe games from it. Random worlds need the map builder in GDScript (0.3.7);
  until then their start files also come from Python.
- Text shown to players stays in the data files in English, keyed, ready for Godot's translation system later.

### B6. Saves in a plain format

- **Format v3:** line 1 is the JSON header of today (what the load screen shows). The body is gzip-compressed
  canonical JSON: keys in schema order, sets as sorted lists, positions as `[col, row]`, objects as dicts by
  schema, the random state as four numbers. Two sections: `map` (fixed after world building) and `state`.
- **Fractions must survive exactly.** Our own writer and reader handle them (shortest round-trip text, checked);
  a test proves every fraction in the oracle games survives Python -> file -> Godot -> file -> Python bit for bit.
  If Godot's JSON cannot do it, fractions are stored as exact text and parsed by us.
- **Old saves:** Python 0.3.0 still opens v2 pickles and re-saves them as v3. Godot reads v3 only. Pickle loading
  is not ported (it can run a stranger's code, which matters once saves are shared).
- **Proof:** round-trip digest equality in each language and across both; a fuzz run on each loader; the
  save-compat tool extended to v3; save size and time in the perf table.
- **Web:** saves go to the browser's storage through `user://`; "export save" and "import save" as files are added
  in 0.3.5.

### B7. The art pipeline

- `tools/bake_art.py` runs the Python art modules once and writes atlases (png) plus an index (json: name, rect,
  anchor point, sort offset). The art modules stay in the repo as the baker; they are no longer run by the game.
  The sprite-hash test keeps guarding them; the bake itself is made on Linux in CI (as the goldens are) and its
  hashes are kept in a manifest.
- **Bake size:** hex radius 60 px (tile 104 x 120), about twice the closest zoom of today, with 2 px extruded
  borders and mipmaps so far zooms and odd zoom factors show no seams.
- **The art inventory** (a 0.3.0 deliverable) sorts everything drawn today into three groups:
  1. *Baked as it is:* terrain and goods tiles, objects (trees, peaks, farms), towns, castles, landmarks, unit
     tokens, icons, badges.
  2. *Baked as pieces, layered in Godot:* what is composed per hex at run time today: ground blend bands by pair of
     ground kinds and edge, ridge crests by edge, the coast, river and road tiles by edge mask, winter variants.
  3. *Redone in Godot:* borders, fog, map-mode tints, labels, selection and path marks, the "life" animations,
     floating text. These become shaders, lines, tweens.
- Which variant sits where (today a hash of the position) uses the shared `det` helpers, so both games choose alike.
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
  0.3.1 from measurements; the layers sit behind one map-view interface so the rest of the shell does not care.
- A `Camera2D` with smooth zoom replaces the six steps; the old steps remain as snap points for map-mode switches.

### B9. Performance

- **Budgets:** frame 16 ms while panning at any zoom on the low-end PC; AI season under 1 s late game on that PC,
  under 3 s in a desktop browser; no frame longer than 50 ms while the AI thinks (the season runs in slices of
  about 8 ms: one country's turn or one phase per step; slicing never changes the result).
- **The speed probe** (throw-away, outside the repo; first in 0.3.0, repeated on real code in 0.3.1): typed
  GDScript versions of the hex grid, the heap, the path finder and one flood (castle areas) on the Europe start
  file, against the same functions in Python; on a Windows export, a web export in two browsers, and a phone
  browser if available. Reported as a ratio to Python.
- **Reading the result:** up to 2x Python: go. 2x to 5x: go, with fallback 1 planned into 0.3.3. Over 5x: stop and
  decide before 0.3.2.
- **Fallbacks, in order:** (1) algorithmic: flat `PackedInt32Array` state for the grid, cell ids instead of
  vector keys, neighbour tables, paths remembered within a season; (2) Godot's built-in `AStar2D`, which is C++
  inside the engine and exports everywhere, but breaks ties its own way, so it is only allowed after parity or for
  questions where ties cannot matter (reachability, distance fields); (3) a GDExtension for the path finder and
  floods.
- **GDExtension, honestly:** it runs on Windows, Linux, macOS, Android and iOS, with one compiled copy per platform
  and processor type (iOS as a static library, built on a Mac). On the web, per the Godot docs read on
  2026-11-14, it needs the "Extension Support" export option, a build made with the matching toolchain, and
  cross-origin isolation headers on the server, which simple hosts do not all allow. It adds a second language, a
  build matrix and code the referee cannot see into. No measured reason justifies that today; the path finder and
  the floods sit behind one interface so the door stays open.
- `tools/perf.py`'s table is rebuilt as `godot/tools/perf.gd` with the same metric names, run nightly.

### B10. Testing in Godot

- **Framework: GUT** (pure GDScript, runs headless from the command line, writes JUnit XML; its branch is pinned
  to the Godot version). gdUnit4 has a stronger scene runner; it is looked at again in 0.3.5 for the window tests,
  and its headless mode has had reported limits. One framework for `core/` either way.
- **The suite is ported as specs, not line by line.** The 1,488 tests fall into:
  - *Covered by the referee* (most example tests of rules the all-AI games reach): not rewritten.
  - *Properties and invariants* (`x_check` true means `x` succeeds; a refused action changes nothing; totals
    conserved): rewritten in GUT, run on random games.
  - *Player-only paths and prepared states* the AI never reaches: rewritten as specs, system by system, in the
    release that ports the system. A system is not "ported" until its specs and its suites pass.
  - *Architecture tests:* the lint script (B3).
  - *Saves:* B6.
  - *Window tests (323):* rewritten against scenes with scripted input, in 0.3.5 and 0.3.6.
- **Goldens:** screenshots of fixed scenes, made in CI on Linux under a virtual display with software rendering
  (true headless mode draws nothing), compared with a pixel tolerance as today. They change only with a reviewed
  art or layout change.
- **Soak and monkey:** headless scripts (full games with invariants each season; random input on the shell).
- **CI on GitHub Actions:** Godot downloaded at a pinned version with a checksum, export templates cached.
  On pull requests: lint and project load; GUT core tests; the referee's quick suites (when `godot/core`, `hexa/` or
  `godot/data` change); goldens. On tags: Windows and web exports, plus a smoke test that opens the web build in a
  headless browser and reaches the main menu with a clean console. Nightly: full-game referee, soak, perf.
  The Python jobs stay alive until 0.3.8.

### B11. Exports

- **Windows:** every release from 0.3.1, a zip on the GitHub release.
- **Web:** every release from 0.3.1. Single-threaded export (no special server settings), Compatibility renderer
  (WebGL 2). Known limits: no background threads (hence the sliced season), saves in browser storage, sound after
  the first click, download size, weaker phone browsers.
- **Linux and Steam Deck:** cheap to add at 0.3.8; needed for Steam.
- **Android, then iOS:** after parity, with the touch UI design. Needs the Android SDK and a signing key; iOS
  needs a Mac, Xcode and an Apple developer account.
- **Steam:** unchanged on the roadmap (0.9.x Early Access). Steam features come through a community plugin
  (GodotSteam), which is itself a GDExtension and is desktop-only: it is left out of web and phone builds.

### B12. Engine version

Pin the newest stable Godot 4 at the start of 0.3.1 (a web check on 2026-11-14 found 4.7.x stable and 4.8 in
beta; confirm on the day). Upgrade only between releases, never inside one, and only with the goldens and the
referee green before and after.

### B13. How the Python line is frozen

- `v0.2.2` is the last Python feature release. `v0.3.0` is the Python reference release.
- After 0.3.0, `hexa/` changes only for: the bug fixes of decision 3 (each with its GDScript twin and re-made
  traces in the same pull request), and referee tooling. No refactors, no balance changes. A CI check fails a pull
  request that touches `hexa/campaign/systems`, `ai.py`, `world.py` or the data files without the label that
  re-makes the traces.
- At 0.3.8 the Python game, its tests and tools are removed from the main branch and kept under the tag
  `python-final`; the art modules and the baker stay.
- CHANGELOG header: 0.3.x becomes "New engine"; later phases shift by one; `saves.VERSION` 3 is noted in 0.3.0.
- CLAUDE.md gets a "Port rules" section at 0.3.0 and is rewritten for Godot at 0.3.8.

### B14. Technical risks and their guards

| Risk | Guard |
|---|---|
| A determinism leak found late | The three suite kinds; per-section digests; the path differ; shared helper vectors; the set-order proof in 0.3.0 |
| GDScript speed on web and phones | Probe in 0.3.0 and 0.3.1; sliced season from the start; the three fallbacks |
| Run-time art does not split into pieces | Art inventory in 0.3.0; in 0.3.1 only, baked chunk images of Europe are allowed as a stand-in |
| UI overrun | Views checked by machine first, so only layout is left to the eye; 0.3.6 has a cut order (life animations, then menu polish) |
| Agents write Godot 3 code, or break scenes they cannot see | Lint, project load with warnings as errors, a screenshot test per scene, small text scenes |
| Godot's JSON and number handling | Our own canonical writer; cast by schema; the bit-exact round-trip test |
| Goldens differ between graphics cards | Goldens only on CI's software renderer; local runs compare with a tolerance or skip |
| The safety net is thin for some weeks | No system counts as ported without its suites and specs; the Python tests keep running on the reference |
| Our own dice are slower in Python than the built-in ones | Measured in 0.3.0; the perf budgets are raised on purpose if needed |
| Trace files are large | Quick traces committed as fixtures; long ones made in CI and kept as artifacts |

---

## Part C. Release 0.3.0 brief: DRAFT

**Not locked.** It is locked after the owner has played 0.2.2 and answered the four decisions in A8.

### Theme

**The yardstick.** The Python game is made exactly copyable. Nothing changes on screen. It is the last release of
the Python game and the first of the port line. Fun principles: none served directly; this release is the cost of
decision 1 of 2026-11-14 and is checked for harm only (the balance must not move).

### Scope

| # | Item | Size | Proof |
|---|---|---|---|
| 1 | **Our own dice.** A small generator with our own `random`, `uniform`, `randint`, `randrange`, `choice`, `choices`, `sample`, `shuffle`; used by the rules, the AI and the map builder (about 115 call sites). The art modules keep Python's (they become the baker). | M | Vector tests; determinism tests; the three direct AI writes become actions |
| 2 | **Rounding and ordering helpers.** Round half up; floor-division helpers; stable sort with explicit keys; first-min and first-max; our own heap. A set-order audit (88 sites). | M | Equal digests under three `PYTHONHASHSEED` values; the pin is removed from the oracle |
| 3 | **Data files.** `data.py`, `tech.py`, `specialgoods.py`, `placenames.py` to JSON in `godot/data/`; the modules become loaders. | M | Loaded tables equal a snapshot of today's; README tables unchanged |
| 4 | **Plain saves (format 3).** Canonical writer and reader; 0.2.2 saves open and convert; start files for Europe 1480 and random seeds 7 and 11. | M to L | Round-trip digests; loader fuzz; save-compat for v2 to v3; size and time in perf |
| 5 | **The referee, ready for two languages.** Per-season, per-section digests from the canonical state; the action recorder; event records; idle, replay and ai suites; a move list of a played game can be exported; the trace format written down. | M to L | The planted-change tests of `tests/test_same_behaviour.py` still catch each planted change; a trace replayed in Python equals itself |
| 6 | **The art baker and the art inventory.** `tools/bake_art.py` writes the atlases and index at hex radius 60; a document sorts all art into baked / pieces / redone; contact sheets. | L | Sprite hashes unchanged; the art director signs the contact sheets |
| 7 | **Balance re-measure and new baselines.** Soak, battle and siege statistics and the economy targets before and after; perf budgets; the oracle re-based once. | S to M | Every target of the 0.2.x briefs still inside its band, or the owner is told which moved |
| 8 | **Speed probe** (throw-away, outside the repo). | S | The ratio table of B9 |
| 9 | **Freeze paperwork.** CHANGELOG header, CLAUDE.md port rules, the CI guard on rule files. | S | In the release |

**Size:** XL, about two 0.2.2 releases. Items 1 and 2 are one pull request each with nothing else in them (they
change fixed-seed games on purpose); 3, 4, 6 and 8 share no files with them and run in parallel.

**Order of work:** 2, 1, then 7's "before and after"; in parallel 3 and 6 and 8; then 4; then 5; then 9.

**Cut list, in order:** the exported move list of a played game (moves to 0.3.5); the "pieces" atlases of item 6
(the terrain, object and unit atlases stay; the rest moves to 0.3.1); the full-game nightly suites (move to 0.3.2).
Never cut: items 1, 2, 4 and the per-section digests.

**Not in 0.3.0:** any Godot code in the repo; any rule, balance or UI change; the castles map mode; new read models.

### Done when

- The whole Python test suite, soak, save-compat and goldens pass; the goldens are sha-identical to 0.2.2 except
  frames that show dice results, which are regenerated and reviewed.
- A 0.2.2 save opens, is saved as format 3, and opens again with an equal digest.
- The traces of every suite are written and are equal across two runs and three hash seeds.
- The atlases and the inventory exist; the art director has compared the contact sheets with the game.
- The balance report shows the targets held; the speed probe's table is in the release notes.

### Playtest checklist (ten minutes)

1. Start a new Europe game and play five seasons. It should look and feel like 0.2.2.
2. Load a save made in 0.2.2. Save it again. Quit, start, load it.
3. Fight one battle and run one siege. The odds words and the results should feel as before.
4. Open the art contact sheets: are these the game's pictures?
5. Read the speed table: is the answer "go"?
