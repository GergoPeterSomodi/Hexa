# Engine and language study: should Hexa move to Godot?

Technical director, 2026-11-14. A paper study: no code was changed. It answers the owner's questions: "How can
this be translated to the Godot engine? Is it better in GDScript? What would be the best language to write this
in?" A producer-level study (business, team, Steam, schedule) is written separately; this one covers the
architecture and the language.

Part A is for the owner. Part B is the technical appendix with the evidence.

---

## Part A. The short answer

### A1. Recommendation

1. **Do not port now.** The part of Hexa that is hard to build, the rules, the AI, the map builder and their
   tests, is not what is slow or weak today. A whole AI season takes 0.13 to 0.25 seconds. A new language would
   not make the game feel better to a player.
2. **What Godot would really buy is the window, not the rules:** a map drawn by the graphics card, a real UI
   toolkit (scaling, fonts, other languages, controller), sound, and one-click Steam builds. Those are real
   gaps in pygame, and they matter for Steam.
3. **If Hexa does move to Godot, the best language is C# for the rules, with Godot as the shell.** Not GDScript
   for the rules, not Python inside Godot, and Rust or C++ only for a small hot spot that measurements prove.
4. **A port is a "before Early Access or never" decision.** The worst time is between Early Access and 1.0:
   the game would be about twice as big, and paying players' saves would break. So the choice should be made
   once, on purpose, with measurements, and before the big UI of Phases 2 to 5 is built.
5. **Start the cheap preparation now.** Five small steps (section A5) make the Python game better today and
   make any later port much cheaper. They are worth doing even if Hexa stays in Python forever.

### A2. Why not just port: where the value sits

| Part of Age of Discovery | Size today | In a port |
|---|---:|---|
| Rules, AI, map builder, data, read models (no pygame) | about 21,700 lines (7,000 of them place names) | Translated line by line into the new language |
| Window: map view, screens, HUD, panels, UI kit | about 6,000 lines | Rewritten from scratch (Godot's UI works differently) |
| Code-drawn art (tiles, goods, units, landscape) | about 12,400 lines | Kept in Python as an offline "sprite baker"; the live parts are redone |
| Tests and tools | about 28,000 lines, 1,490 tests | Rewritten; the ideas and the fixed-seed games are reused |

The tests and tools are bigger than the rules they protect. They are why changes to Hexa are safe today. A port
throws that net away and has to rebuild it. That is the main cost, and the main risk.

### A3. The options, compared for this game

Scores are relative: ++ very good, + good, 0 neutral, - weak, -- bad.

| | Stay Python + pygame | Godot + GDScript | Godot + C# (rules as a plain C# library) | Godot + Rust/C++ core | Python inside Godot |
|---|---|---|---|---|---|
| Cost to get there | ++ (none) | -- | -- | --- | - |
| Risk | + | - | - | -- | -- (beta tools) |
| Rules speed (AI, paths) | 0 (enough today) | 0 (same class as Python) | ++ | ++ | 0 |
| Map drawing, 14,000 hexes | - (CPU, many caches) | ++ | ++ | ++ | ++ |
| UI quality for Steam | - (all hand-made) | ++ | ++ | ++ | ++ |
| Tests without the engine | ++ (today's net) | - (tests run inside Godot) | ++ | + | - |
| Modding | + (data files) | ++ | + | 0 | + |
| AI-assisted coding, hiring | ++ / - | + / + | ++ / ++ | 0 / - | - / -- |
| Steam builds | 0 (works, hand-made) | ++ | + (desktop yes, web no) | + | -- |

In words:

- **GDScript** is pleasant for screens and buttons. For 15,000 lines of rules it is the wrong tool: it is not
  faster than Python in any way that matters, its tests only run inside the engine, and it ties the rules to
  Godot for good.
- **C#** is the best fit if we port: fast, strict (the compiler catches mistakes), a large pool of developers,
  very well known to AI coding tools, and the rules can live in a plain library that is tested without Godot
  at all, as today. Its limit: Godot 4 still cannot export C# games to the web. Desktop and Steam Deck are fine.
- **Rust or C++** is the fastest and the most expensive. Hexa does not need it. Keep it as a tool for one
  measured hot spot (path finding), never for the whole game.
- **Python inside Godot** sounds ideal (keep the rules, get the engine), but the tools are not ready: the older
  project has not reached Godot 4, and the newer ones are in beta and desktop-only. Not for a game we sell.
- **Staying with Python** is cheap and safe, but then we must build ourselves what Godot gives for free:
  a faster map layer, UI scaling, packaging, Steam hooks. I estimate 8 to 14 weeks of such work before 1.0,
  against 32 to 50 weeks for a port (section B5).

### A4. When

- **Now to the gate:** keep building in Python. Do the five steps of A5. Run two small, time-boxed experiments
  (one to two weeks each, throw-away code, outside the repo):
  1. *Godot spike:* the real Europe map with our baked sprites in Godot, pan and zoom, one side panel.
  2. *Python spike:* the same map drawn by the graphics card from Python.
- **The gate:** before the first big UI of Phase 2 (diplomacy) is built, the owner decides with both results on
  the table: port now, or stay in Python to 1.0 and beyond.
- **Not after Early Access starts.** From then on, a port is a sequel, not an update.

### A5. What to do now in the Python code (cheap, useful either way)

1. **Keep the rules free of pygame** (already a rule, already tested). Nothing new, just never break it.
2. **Move the numbers from `data.py` and `tech.py` into data files** (JSON or similar) that the game loads.
   This is also the roadmap's "data files the community can edit". Any engine can read them.
3. **Move saves away from pickle** to a plain, versioned format. Pickle only works in Python, and opening a
   pickle from a stranger can run their code, which matters once players share saves on Steam.
4. **Our own small random-number helper** instead of Python's built-in one, so another language can replay the
   same game from the same seed. Without this, a port can never be checked against the Python game.
5. **More read models** like `battleview.py`: the window asks for a plain "view" and never reads the rules'
   objects directly. Each view is a ready-made contract for a future UI, in any engine.

### A6. Decisions for the owner

- **D1. Direction.** (a) Stay with Python and pygame to 1.0, prepare but do not port [recommended for now];
  (b) decide at the gate after the two spikes [recommended as the plan]; (c) commit to a Godot port now.
- **D2. Platforms.** Is a web or mobile version ever wanted? If no (PC, Steam, Steam Deck only), C# is the port
  language. If yes, C# is out for web today, and the choice becomes GDScript or staying in Python.
- **D3. The preparation steps.** Approve A5 steps 2 to 4 as roadmap items? Steps 3 and 4 each need one
  release that changes saves (step 3) or changes fixed-seed games (step 4) on purpose.

---

## Part B. Technical appendix

### B1. Evidence from the code (measured 2026-11-14)

- `hexa/` is 44,137 lines; `hexa/campaign/` 39,100; `campaign/systems/` 5,289; tests 25,800; tools 2,354.
- In the campaign, `hexa/ui`, `events.py` and `hexgrid.py`: files that import pygame hold 18,414 lines; files
  that do not hold 21,713 (of which `placenames.py` is 6,952 lines of data).
- The pygame-free core by role: systems 5,289; `world.py` 782 (115 methods and 89 one-line facades); `ai.py`
  806; `state.py` 270; data and tech 1,033; map building (`geo`, `regions`, `randomgeo`, `wfc`, `naming`)
  about 2,930; read models and feeds (`battleview`, `feed`, `reminders`, `resources`, `replay`, `game`) about
  1,775.
- Art modules (`art`, `goodsart`, `goodsobjects`, `wfctiles`, `landscape`, `life`, `nature`, `landmarks`,
  `render/`, `ui/`): about 12,450 lines, 577 `pygame.draw`/`blit` calls across the window code, and 1,743
  generated sprites pinned by hash.
- Tests: 1,490 test methods, 323 of them window tests. Tools: soak, perf, oracle, save-compat, monkey, goldens.
- Speed (from `tests/perf_budget.json`, CPU seconds): AI season 0.125, late game 0.251; battle phase 0.020;
  Europe build 2.08; map view redraw 0.103 (zoom 1) and 0.375 (zoom 4). The map view is the only number that
  is far from a 16 ms frame, and it is why `BoundedCache`, `FrameBudget` and the prefetch code exist.
- Random numbers in the rules, AI and map building: 114 call sites of 8 methods (`random`, `uniform`,
  `randint`, `randrange`, `choice`, `choices`, `sample`, `shuffle`), all on Python's Mersenne Twister.
- Saves: a JSON header plus a pickle of the world's `__dict__`; state classes are pinned to a module name so
  old pickles load.

Conclusion from the numbers: the rules layer has headroom; the drawing layer is the pressure point.

### B2. What maps onto Godot, what does not

| Hexa today | Godot | Fit |
|---|---|---|
| Hex grid, pointy-top odd-r `(col, row)` | `TileMapLayer` with a hexagonal `TileSet` (stacked offset layout) | Good. 14,000 cells is small for it. Confirm the offset convention in the spike. |
| Map view: terrain, blends, ridges on edges, rivers, roads, borders, fog, map modes, labels | Several `TileMapLayer`s plus custom-drawn layers and shaders | Medium. The tiles map; the edge art, borders and fog are new work. GPU drawing removes most cache code. |
| Screen stack (`screens/`) | Scenes on a `CanvasLayer` stack | Good, one to one. |
| UI kit (`ui/kit.py`, immediate mode: redraw and re-register buttons each frame) | `Control` nodes (retained mode), containers, `Theme` | The result is better, but nothing translates: panels are rewritten. `theme.py` tokens become a `Theme`. |
| Event bus (queued, drained once a frame, history kept, handlers may not change the game) | Signals (called at once, no history) | Partial. Keep our bus in the core; the shell turns bus events into signals. |
| `data.py`, `tech.py` tables | Godot `Resource` files, or plain JSON | Use plain JSON, so the core and the tests need no engine and modders need no editor. |
| Read models (`battleview.py`, `resources.snapshot`, `reminders`) | Plain objects the scenes bind to | Very good. This is the seam the port cuts along. |
| Movement replay (`replay.py`), floating text | Tweens, `AnimationPlayer` | Good, and cheaper than today. |
| Code-drawn art at 120x140 | Texture atlases | Does not map. Keep the Python art code as an offline baker that writes atlases; the sprite-hash test stays. Anything drawn per world at run time (landscape variants, zoom levels) must be listed and redone. |
| Pickle saves | No equivalent | Does not map. Needs a plain format first (A5 step 3). |
| Pure rules + unittest + soak + oracle + save-compat | GDScript tests run inside the engine (GUT, gdUnit4) | Does not map to GDScript. Maps well to a plain C# library with a normal test runner. |
| `tools/perf.py`, goldens, monkey | Godot headless runs, own screenshot tests | Rebuilt. Pixel goldens across GPUs are harder than today's software renderer. |

Engine-independent, and should stay so in any future: the rules (`systems/`), the world facade, the game
manager, the AI, the map builder, the data tables, the read models, the event kinds, the season `PHASES`
table, the save schema, the design docs, and the fixed-seed games of the oracle and the soak.

### B3. Language notes

- **GDScript.** Dynamic, optional types, interpreted. I have not benchmarked it on our code; publicly it is in
  the same broad class as Python, so no meaningful gain for the AI or Dijkstra should be assumed (the spike
  should measure). Unit tests need the engine process. Good for scene glue. Exports everywhere, including web.
- **C# (.NET in Godot 4).** Desktop exports are solid; Android and iOS are supported but newer; **web export
  of C# projects is still not officially available** (a prototype was shown in 2025; no release date found).
  A rules library with no Godot reference runs under a standard test runner in seconds, in CI, and could later
  run a multiplayer server. For loops like path finding, expect a large speed-up over Python (commonly ten
  times or more; to be measured, not promised).
- **Rust or C++ through GDExtension.** Best speed, strongest determinism control. Highest cost per feature,
  slowest iteration on balance changes, smallest hiring pool. Sensible only as a small native module for a
  measured hot spot. The same idea works without Godot: a native path-finder called from Python.
- **Python in Godot.** `godot-python` (the original): no Godot 4 release found; its maintainer reports slow
  progress. `py4godot` and `godot-python-extension`: active, described as beta, desktop 64-bit only, docs
  incomplete. I did not test them. Status could change; today they are a research toy, not a release path.
- **Not porting.** Options inside Python: move to `pygame-ce` (maintained, wheels for new Python versions),
  draw the map through the GPU (SDL2 renderer textures or an OpenGL layer; the UI stays as it is and is
  composited on top), package with Nuitka or PyInstaller, and call Steamworks through a Python wrapper
  (unverified: needs its own check before 0.9). Python games do ship on Steam. Moving to Arcade or pyglet has
  most of a port's UI cost with few of Godot's gains; I do not recommend it.

Conditions that would change the recommendation:
- The Python GPU spike cannot hold the frame budget on the agreed low-end PC: port (C#).
- Web or mobile becomes a goal: C# is out for web; GDScript shell with the rules question reopened.
- Translation into languages with complex scripts, or full controller support, becomes a 1.0 requirement:
  Godot's text and input systems weigh much more; lean to port.
- An experienced Godot developer joins: the port's risk and cost drop.
- The AI needs deep look-ahead search, or the map grows several times: C# or a native core gains weight.
- Python-in-Godot tools reach a stable, exportable release: a hybrid (keep the rules, new shell) becomes the
  cheapest path and should be re-studied.

### B4. Migration architecture (if the gate says "port")

Principle: the same rule as the refactor. Small steps, each proved, behaviour unchanged, Python stays the
reference until the new game matches it.

- **Phase 0, prepare in Python** (A5): data files, plain saves, portable random numbers, read models for every
  panel, and a "trace export": the oracle's fixed-seed games written out as one canonical record per season
  (state plus the events of the bus).
- **Phase 1, spike and skeleton:** Godot project, a C# rules library with no Godot reference, CI running its
  tests headless.
- **Phase 2, port the rules core behind the same interfaces:** state, data loading, then systems in the
  order of `PHASES`, the world facade, the game manager, the AI. After each system, the **cross-language
  oracle** (the `tools/same_behaviour.py` idea) replays the Python traces in C# and names the first season and
  field that differ. The Europe map is not rebuilt in C# at first: Python bakes it to a file (this skips
  `geo`, `regions` and most of world generation for the fixed map); random worlds port later.
- **Phase 3, tests as specs:** the property tests (`*_check` pairs), invariants and soak are rewritten in C#;
  many example tests are replaced by the traces.
- **Phase 4, art:** the Python art modules become the offline atlas baker; landscape blends, ridges, fog and
  the "life" animations are rebuilt with layers and shaders.
- **Phase 5, the window:** map view, HUD, panels, screens, tech screen and menus as Godot scenes on the read
  models; new screenshot and monkey tests.
- **Phase 6, release work:** saves, settings, Steam hooks, builds, a side-by-side playtest against the Python
  game, performance on the low-end PC.

A staged hybrid that ships half-ported builds to players is not available, because there is no supported way
to run our Python rules inside a Godot build. So the port is a second code line next to the first until
Phase 5 is done; the Python game only gets bug fixes meanwhile.

### B5. Rough sizes

Assumption: one "engineer-week" is one full-time developer working with AI assistance at the studio's current
pace, including review. These are estimates from line counts and the list above, not measurements; treat them
as plus or minus 30 percent.

| Phase | Weeks | Notes |
|---|---:|---|
| 0. Prepare in Python | 3 to 5 | Useful without a port; fits between features |
| 1. Spikes and skeleton | 1 to 2 | Throw-away |
| 2. Rules core with oracle parity | 8 to 12 | About 14,000 lines of logic |
| 3. Tests and tools | 6 to 10 | Partly alongside phase 2 |
| 4. Art baker and live map art | 5 to 8 | |
| 5. Window and UI, with UI tests | 11 to 16 | Grows with every panel built before the port |
| 6. Release work and parity playtest | 3 to 4 | |
| **Port total (phases 1 to 6)** | **about 32 to 50** | Feature work mostly stops |
| *Stay in Python instead* | *8 to 14* | GPU map layer 3 to 6, packaging and Steam 2 to 3, UI scaling and fonts 3 to 5 |

Reused: data tables, place names, the baked Europe map, baked sprites, design docs and mockups, the README
rules, the oracle's suites, the invariants, the season order, the event kinds, the read-model shapes.
Thrown away: all window code (about 6,000 lines), the run-time drawing and cache code, the pygame test harness
and goldens, pickle saves and their migration code, Conquest, Colonisation and the legacy editor (not ported).

### B6. Risks

- **Determinism across languages.** Three traps, each with a fix that belongs in Phase 0:
  1. *Random numbers:* Python's generator and its `shuffle`/`sample`/`choice` methods are Python-specific. Fix:
     a small own generator class (about 100 lines) with those methods written by us; one deliberate release
     where fixed-seed games change, then the oracle is re-based.
  2. *Number and order rules:* Python's `round()` rounds halves to even (19 uses in `systems/`), integers never
     overflow, `sorted` is stable (45 uses in systems and AI), dicts keep insertion order, and library maths
     (`exp`, `pow`) may differ in the last digit between languages. Fix: one helper module for rounding and
     ordering that both sides copy exactly; avoid library maths in rules where a table will do.
  3. *Comparing:* compare traces field by field (exact for whole numbers and order, a tiny tolerance for
     fractions while porting, exact at the end), not one hash, so a difference names its cause.
- **Saves break.** A port cannot read pickles. With plain saves (A5 step 3) shipped first, the new game can
  read the old game's saves; without it, every player save is lost at the switch.
- **Art.** Baking is safe (hashes prove it). The risk is the art that depends on the world at run time, and
  keeping the look identical on a GPU (filtering, pixel snapping, ink outlines at zoom). The spike must show
  one zoomed screenshot next to today's.
- **Losing the safety net.** For some weeks the new code has fewer tests than the old. The oracle traces are
  the bridge; no system counts as ported until its traces match.
- **Two code lines.** Every rule changed in Python during the port must be changed twice. Freeze rules during
  Phase 2, or the oracle never settles.
- **Estimates.** The UI is where ports overrun. Its size also grows with every feature built before the gate,
  which is the argument for deciding early.

### B7. What to measure, and how to prove each step safe

- Spikes: frame time while panning the full Europe map at the closest and farthest zoom on the low-end target
  PC; memory; start-up time; one screenshot pair for the look. For the Godot spike also: the same Dijkstra in
  GDScript and C# against `tools/perf.py`'s Python numbers.
- A5 step 2 (data files): `tools/same_behaviour.py` unchanged, plus a test that the loaded tables equal
  today's.
- A5 step 3 (plain saves): save-compat in both directions, a round-trip digest test (save, load, digests
  equal), a fuzz run on the new loader, save size and time in `tools/perf.py`.
- A5 step 4 (own random numbers): the only step that changes behaviour on purpose. One PR, nothing else in it;
  soak and balance runs before and after; oracle re-based once.
- A5 step 5 (read models): goldens stay sha-identical; an architecture test that panels import no state class.

### B8. Sources for the outside facts

Checked by web search on 2026-11-14; secondary sources are marked. Verify before a final decision.

- Godot docs, "Exporting for the Web" (C# projects cannot be exported to the web in Godot 4):
  https://docs.godotengine.org/en/4.4/tutorials/export/exporting_for_web.html
- Godot blog, platform state of C# in 4.2 (mobile support, the web blocker):
  https://godotengine.org/article/platform-state-in-csharp-for-godot-4-2/
- Godot forum, update on C# web export (still in progress; secondary):
  https://forum.godotengine.org/t/is-there-an-update-on-exporting-c-projects-to-web/128821
- godot-python, "Is this project still supported?":
  https://github.com/touilleMan/godot-python/discussions/400
- py4godot listing (beta, desktop 64-bit only): https://godotengine.org/asset-library/asset/3234
- godot-python-extension: https://github.com/maiself/godot-python-extension
- Godot 4.6 release page: https://godotengine.org/releases/4.6/
- pygame-ce: https://pypi.org/project/pygame-ce/

Not verified in this study: GDScript's speed on our code, a Python Steamworks wrapper, the exact hexagon offset
setting in `TileMapLayer`, and the current state of C# on mobile. Each is a spike or a pre-0.9 check.
