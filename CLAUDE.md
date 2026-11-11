# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Hexa is a turn-based hex strategy game in plain Python + pygame with three modes (Conquest, Colonisation,
Age of Discovery) behind one launcher. `README.md` is the player-facing rules reference: its tables mirror the
balance numbers in the rules/data modules, so update it when you change rules, numbers or controls.

## Commands

```bash
pip install -r requirements.txt                      # pygame; pygame-gui is only for the legacy editor
python play.py                                       # start menu
python play.py --mode conquest --seed 42             # skip the menu; --seed replays a map
python play.py --mode colony --start land --goal independence
python play.py --mode campaign --nation POR          # Age of Discovery as a given country tag
python play.py --mode campaign --map random --seed 7
python Hex.py                                        # legacy tile-painting map editor
```

Tests use stdlib `unittest` (no pytest, linter or formatter is configured):

```bash
python -m unittest discover -s tests -t .                                 # everything, ~2.5 min
HEXA_FAST=1 python -m unittest discover -s tests -t .                     # skips the @slow tests, ~30 s
python -m unittest tests.test_game                                        # one module
python -m unittest tests.test_campaign.WarTest                            # one class
python -m unittest tests.test_game.HexGridTest.test_pixel_round_trip      # one test
HEXA_FUZZ_CASES=3000 python -m unittest tests.test_fuzz_files             # more settings/save-file fuzz cases (default 300)
HEXA_FUZZ_SEED=20260110 HEXA_FUZZ_CASES=1 python -m unittest tests.test_fuzz_files   # replay one case; failures print this line
HEXA_PROP_GAMES=100 python -m unittest tests.test_properties              # more random games per mode (default 20)
HEXA_PROP_SEED=7 HEXA_PROP_GAMES=1 python -m unittest tests.test_properties.ColonyGamesTest   # replay one game; failures print this line
PYTHONHASHSEED=0 python -m tests.support.digest_run colony 5 --turns 30   # digest of a fixed-seed all-AI game (determinism test)

pip install -r requirements-dev.txt                                       # coverage.py (CI only; config in .coveragerc)
coverage run -m unittest discover -s tests -t . && coverage report        # branch coverage; slow before Python 3.14

# Window tests (tests/ui) need pygame, which has no wheels for 3.14+: use a 3.12/3.13 venv
python3.12 -m venv .venv && .venv/bin/pip install pygame==2.6.1 -r requirements-dev.txt
.venv/bin/python -m unittest discover -s tests/ui -t .                    # headless window tests only, about 90 s (test_monkey ~45 s: its default sessions ~30 s)
HEXA_REQUIRE_PYGAME=1 python -m unittest discover -s tests/ui -t .        # error instead of skip without pygame (CI ui job)
HEXA_COVERAGE_BRANCH=0 COVERAGE_CORE=sysmon .venv/bin/coverage run -m unittest discover -s tests/ui -t .   # line coverage, as the ui job
HEXA_MONKEY_SEEDS=30 HEXA_MONKEY_FRAMES=3000 HEXA_MONKEY_BURST=0.5 .venv/bin/python -m unittest tests.ui.test_monkey.MonkeyTest   # longer monkey runs (default seeds 1-2, 800 frames / campaign 300, burst 0.3)
.venv/bin/python -m tools.monkey colony 7 800 --burst 0.5                 # replay one monkey session; a failure prints this line ("1-30" seeds: a batch)
```

Shared helpers live in `tests/support/` (`europe()` is one read-only world, `fresh(player)` a mutable one,
`play_seasons`, `random_world`, `TempHome`, `@slow`). A test that mutates a shared world fails the module's
`tearDownModule` pristine guard, so use `fresh()` for anything you change. `tests/support/invariants.py`
(`check_conquest`, `check_colony`, `check_campaign`) states what must hold after any action; `agents.py` has the
seeded random players and the `Judge` that enforces the `*_check` contract below; `digests.py` digests a whole
world (`world_digest` compares across processes, `quick_digest` within one); `games.py` plays all-AI games;
`monkey.py` is the seeded random-input engine of `tests/ui/test_monkey.py` and `tools/monkey.py` (its `KNOWN_ISSUES`
table withholds input that would hit a known open crash; keep it narrow and pin each crash as an expected failure).

Use `python3` where `python` isn't on PATH. Tests do not need pygame installed, except `tests/ui/` and nine game
modules that import it at the top (`tests/test_landscape.py`, `test_passes.py`, `test_playtest.py`,
`test_techscreen.py`, `test_uifixes.py`, `test_wfctiles.py`, `test_goodsobjects.py`, `test_mapview_polish.py`,
`test_town_labels.py`, which the CI `ui` job runs too): they skip without it (errors under `HEXA_REQUIRE_PYGAME=1`).
Window tests subclass `tests/support/harness.py:UITestCase`
(SDL dummy drivers, fake `Clock`/`get_ticks`, pinned fonts, temp `HEXA_HOME`), script input with
`self.driver.at(frame, key(...)/click(...))` and `self.driver.run_for(frames, until=...)`, call the window's real
`run()`, then assert on `app.world`/`app.ui`. They import pygame and window modules inside the test, never at
module top. A failing one saves its last frame to `test-artifacts/` (`HEXA_TEST_ARTIFACTS`).

`test_campaign` is the slowest (~1 min) because building the Europe map takes seconds; `test_properties` (~50 s:
20 random games per mode, determinism subprocesses) comes next; `test_game` runs in ~10 s.

## Architecture

### One launcher, three modes

`play.py:main()` loops: `hexa/menu.py:Menu` returns settings, the chosen app's `run()` returns `"menu"` or
`"quit"`. The Conquest app class lives in `play.py` itself. Command-line parsing lives in the pygame-free
`hexa/cli.py` (`build_parser()`, `parse(argv)`), so `tests/test_cli.py` can test it.

| Mode | State and rules | AI | Balance numbers | UI |
|---|---|---|---|---|
| Conquest | `hexa/world.py` `World` | `hexa/ai.py` | `hexa/rules.py` | `play.py` `App`, `hexa/render.py` |
| Colonisation | `hexa/colony/world.py` `ColonyWorld` | `hexa/colony/ai.py` | `hexa/colony/rules.py` | `hexa/colony/app.py`, `render.py` |
| Age of Discovery | `hexa/campaign/world.py` `CampaignWorld` | `hexa/campaign/ai.py` | `hexa/campaign/data.py` | `hexa/campaign/app.py`, `mapview.py`, `art.py` |

Colonisation builds on Conquest code: `colony/rules.py` imports `Terrain` from `hexa/rules.py`,
`colony/render.py` subclasses `hexa.render.Renderer`, and `colony/mapgen.py` reuses `hexa.mapgen._noise`.
The campaign is self-contained apart from `hexa/hexgrid.py`.

### Conventions shared by all modes

- **No pygame in game state.** World, rules, AI, mapgen, geo, WFC and saves modules never import pygame. Tests
  rely on this; keep drawing and input in the `app`/`render`/`mapview`/`art`/`menu` modules.
- **`*_check` / action pairs.** A world exposes `x_check(...) -> (ok, reason)` next to `x(...)`, which checks
  again and then acts (`train_check`/`train`, `build_check`/`build`, `found_check`/`found`, ...). The UI uses
  the check to enable buttons and shows `reason` as the hover hint. New player actions should follow this.
  `tests/test_properties.py` enforces it: when the check says no, `x` returns something falsy and changes
  nothing; when it says yes, `x` succeeds. Add new pairs to the random players in `tests/support/agents.py`.
- **Hex coordinates** (`hexa/hexgrid.py`) are pointy-top, "odd-r" offset `(col, row)` tuples (odd rows shift
  half a hex right). `hex_center`/`pixel_to_hex` assume the fixed 60x70 Kenney sprite and serve Conquest and
  Colonisation; the campaign's `MapView` has its own zoomable geometry (`ZOOMS`) and uses only `neighbors`.

### Turn flow and AI

- **Conquest / Colonisation:** `ai.take_turn(world, side)` is a generator that yields after every unit action.
  The app's `update()` drains it and pauses `AI_STEP_MS` only when the acting unit is visible to the player.
  These AIs see the whole map.
- **Campaign:** one turn is one season. `CampaignApp.end_turn()` runs `ai.run(world, tag)` synchronously for
  every non-player country, then `world.end_round()` (logistics, sieges, war timeouts, economy, growth,
  research, turn counter), then moves units along multi-season orders (`unit.goal`). Campaign AIs only know
  what their country has explored (`country.explored`). `world.player = None` makes everything visible, as in
  most tests.

### Campaign internals

- **Geography sources.** A world is built from either the `hexa/campaign/geo.py` module (real 1480 map:
  lon/lat polygons rasterised onto the hex grid with a Mercator projection, `SCALE = 2`) or
  `randomgeo.generate(seed)`, which returns a `SimpleNamespace` that copies geo's interface and projection.
  `world.py` reads geography only through `self.geo`, so any new attribute must exist on both sources, or be
  read with a `getattr` default as `COLONIAL` and `FORCE_SEA` are. Distances in `data.py` scale with
  `geo.SCALE`.
- **Terrain** comes from `wfc.collapse` (wave function collapse): per-hex priors from `CampaignWorld._prior`
  plus the `FORBIDDEN` adjacency pairs at the top of `campaign/world.py`.
- **Build caching.** Building a world takes seconds, so `CampaignWorld.__init__` stores a pickled snapshot of
  each fresh `(map, seed)` world in the module-level `_SNAPSHOTS` and restores later constructions from it.
  `map_source` caches random geographies in `_RANDOM_GEOS`. Tests share one module-level `WORLD` for read-only
  checks and call `fresh()` when they mutate.
- **Redraw invalidation.** `MapView` and the minimap cache surfaces keyed on `(zoom, mode, world.version,
  player)`. Call `world.changed()` after any mutation that affects the map, and `world.changed(ownership=True)`
  when province owners change: that also clears the `provinces_of` cache (`_owned`) and `_castle_list`.
- **Saves** (`campaign/saves.py`): one JSON header line, then a pickle of `world.save_state()` (the world's
  `__dict__` minus `geo`, which is rebuilt from `map` + `seed` on load). Files with a different `VERSION` are
  ignored. Renaming or adding attributes and dataclass fields changes what saves contain. Lazily added
  attributes use `getattr`/`__dict__.setdefault` (`_known_world`, `_explored_from`) so older saves still load;
  bump `VERSION` when compatibility breaks.
- Saves and options (`hexa/settings.py`) live in `~/.hexa/`; the `HEXA_HOME` environment variable overrides
  this, and `tests/test_saves.py` uses it with a temporary folder.
- `gamemenu.GameMenu` is a mixin base class of `CampaignApp`: the Esc menu, save/load, options, and the screen
  mode (window size, fullscreen).
- `art.py` draws extra tiles, decorations, unit figures and tokens in code, in the Kenney style at 120x140.
  `MapView` switches from flat colours to tile art at zoom index `TILE_FROM`.

### Legacy map editor

`Hex.py`, `Game.py`, `Setting.py`, `Create_xml.py` and `Read_XML.py` at the repo root are the original
pygame-gui tile editor (it loads `map3.xml`). They don't touch the `hexa` package, and the `map*.xml` / `.tmx`
files are their data. `pygame-gui==0.5.7` is in `requirements.txt` only for this editor.

### Assets

`hexagon-pack/` is the Kenney Hexagon Pack (CC0). Every app gets `TILES_DIR` (`hexagon-pack/PNG/Tiles`) from
`play.py`; the campaign's `art.py` finds object sprites in the sibling `Objects` folder.
