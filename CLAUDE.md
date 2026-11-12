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
python -m unittest discover -s tests -t .                                 # everything, ~4 min
HEXA_FAST=1 python -m unittest discover -s tests -t .                     # skips the @slow tests, ~45 s
python -m unittest tests.test_game                                        # one module
python -m unittest tests.test_campaign.WarTest                            # one class
python -m unittest tests.test_game.HexGridTest.test_pixel_round_trip      # one test
HEXA_FUZZ_CASES=3000 python -m unittest tests.test_fuzz_files             # more settings/save-file fuzz cases (default 300)
HEXA_FUZZ_SEED=20260110 HEXA_FUZZ_CASES=1 python -m unittest tests.test_fuzz_files   # replay one case; failures print this line
HEXA_PROP_GAMES=100 python -m unittest tests.test_properties              # more random games per mode (default 20)
HEXA_PROP_SEED=7 HEXA_PROP_GAMES=1 python -m unittest tests.test_properties.ColonyGamesTest   # replay one game; failures print this line
PYTHONHASHSEED=0 python -m tests.support.digest_run colony 5 --turns 30   # digest of a fixed-seed all-AI game (determinism test)

# Nightly tools (.github/workflows/nightly.yml, 03:17 UTC or by hand); both append their table to $GITHUB_STEP_SUMMARY
python -m tools.soak --quick                                              # all-AI games, invariants every turn (~15 s; no flag: the nightly ~8 min)
python -m tools.soak conquest 17                                          # replay one soak game (suites: conquest, colony, europe, random); failures print this line
python -m tools.perf                                                      # CPU-time medians vs tests/perf_budget.json (fails past "hard") + #29 memory row
python -m tools.perf --only ai_season --runs 5                            # some metrics; MapView ones need the pygame venv (HEXA_REQUIRE_PYGAME=1: error, not skip)

# Save compatibility (tests.yml's save-compat job, on pull requests that touch hexa/campaign/)
git worktree add --detach /tmp/hexa-base master                           # the code whose saves must still load (CI: the merge base)
python tools/save_compat.py write /tmp/hexa-base /tmp/hexa-compat         # 3 games saved by /tmp/hexa-base's own hexa (~6 s; prints which hexa it imported)
python tools/save_compat.py check /tmp/hexa-compat                        # load + play a season with this checkout; exit 1: a save broke (the log says which, why and how to fix it)
git worktree remove --force /tmp/hexa-base

# Behaviour oracle (.github/workflows/same-behaviour.yml, on pull requests labelled "refactor"): same fixed-seed games as the base?
git worktree add --detach /tmp/hexa-base master                           # the base: master, or the merge base
python tools/same_behaviour.py /tmp/hexa-base                             # 7 suites, ~21 s (below); a digest of the whole state every season; exit 1: BEHAVIOUR CHANGED (names suite and step) or ORACLE FAILED (a crash)
python tools/same_behaviour.py /tmp/hexa-base --only conquest             # one suite (a name substring; repeatable); --quick: one season per suite
git worktree remove --force /tmp/hexa-base

pip install -r requirements-dev.txt                                       # coverage.py (CI only; config in .coveragerc)
coverage run -m unittest discover -s tests -t . && coverage report        # branch coverage; slow before Python 3.14

# Window tests (tests/ui) need pygame, which has no wheels for 3.14+: use a 3.12/3.13 venv
python3.12 -m venv .venv && .venv/bin/pip install pygame==2.6.1 -r requirements-dev.txt
.venv/bin/python -m unittest discover -s tests/ui -t .                    # headless window tests only, about 90 s (test_monkey ~45 s: its default sessions ~30 s)
HEXA_REQUIRE_PYGAME=1 python -m unittest discover -s tests/ui -t .        # error instead of skip without pygame (CI ui job)
HEXA_COVERAGE_BRANCH=0 COVERAGE_CORE=sysmon .venv/bin/coverage run -m unittest discover -s tests/ui -t .   # line coverage, as the ui job
HEXA_MONKEY_SEEDS=30 HEXA_MONKEY_FRAMES=3000 HEXA_MONKEY_BURST=0.5 .venv/bin/python -m unittest tests.ui.test_monkey.MonkeyTest   # longer monkey runs (default seeds 1-2, 800 frames / campaign 300, burst 0.3)
.venv/bin/python -m tools.monkey colony 7 800 --burst 0.5                 # replay one monkey session; a failure prints this line ("1-30" seeds: a batch)
.venv/bin/python -m unittest tests.ui.test_screenshots                    # golden screenshots: skipped unless the environment matches tests/golden/linux/MANIFEST.json
HEXA_GOLDEN_ANY_OS=1 .venv/bin/python -m unittest tests.ui.test_screenshots   # compare on macOS anyway, allowing 0.5 % of the pixels to differ
# make the goldens as CI does (Linux only; leave out UPDATE_GOLDEN=1 to compare, HEXA_GOLDEN_STRICT=1 fails instead of skipping)
docker run --rm --platform linux/arm64 --user "$(id -u):$(id -g)" -e HOME=/tmp -e UPDATE_GOLDEN=1 -v "$PWD":/work -w /work python:3.12-slim sh -c 'pip install -q pygame==2.6.1 && HEXA_HOME=$(mktemp -d) python -m unittest tests.ui.test_screenshots'
```

Shared helpers live in `tests/support/` (`europe()` is one read-only world, `fresh(player)` a mutable one,
`play_seasons`, `random_world`, `TempHome`, `@slow`). A test that mutates a shared world fails the module's
`tearDownModule` pristine guard, so use `fresh()` for anything you change. `tests/support/invariants.py`
(`check_conquest`, `check_colony`, `check_campaign`) states what must hold after any action; `agents.py` has the
seeded random players and the `Judge` that enforces the `*_check` contract below; `digests.py` digests a whole
world (`world_digest` compares across processes, `quick_digest` within one); `games.py` plays all-AI games;
`monkey.py` is the seeded random-input engine of `tests/ui/test_monkey.py` and `tools/monkey.py` (its `KNOWN_ISSUES`
table withholds input that would hit a known open crash; keep it narrow and pin each crash as an expected failure).
`tools/soak.py` reuses `games.py` and the checkers and reports a broken invariant that `invariants.KNOWN_OPEN`
explains as "known open" instead of failing; `tools/perf.py` is the only place anything is timed (never assert on time
in a unit test; `tests/test_perf.py` uses fake metrics). Change `tests/perf_budget.json` (`soft`/`hard` CPU seconds,
`measured`) in the PR that knowingly makes something slower. `tools/save_compat.py` must keep working against older
revisions: `write` imports only the base checkout's `hexa` (never `tests/`) and uses its public API (`CampaignWorld`,
`ai.run`, `end_round`, `declare_war`, `saves.save`), and must run in a fresh interpreter; `tests/test_save_compat.py`
drives it against temporary copies of `hexa/` (a renamed class with and without a `VERSION` bump, a new attribute
without a default, a header `meta()` refuses, a bump alone) and calls it in-process only for usage errors, which must
leave `HEXA_HOME` as it was.

`tools/same_behaviour.py` (the behaviour oracle for refactor PRs; `tools/oracle_runner.py` plays the games, importing
nothing from `tests/` or `tools/` and using only the public API of the checkout's `hexa/`, so a base checkout needs
nothing but its `hexa/` folder and a refactor of `tests/support` cannot change what it plays) digests the whole game state after every
step in a fresh interpreter per suite and checkout, and the generated map (roads, rivers, cities, landmass, ...) at
the first and last step. Suites: Europe 1480 and random seeds 7 and 11 (12 AI seasons each), Colonisation (30
rounds), Conquest (to the end), a prepared turn-160 Europe (every country gets its age's techs: new age, ideas,
cartography; forced wars, peace on all terms, drilling, refits, disbanding) and a debt state (desertion, disbanding,
seizure). It does not cover drawing and input (goldens, ui tests), saves (save-compat), paths only a human move
triggers, private `_caches`, or speed (`tools/perf.py`). Add a prepared state to `oracle_runner.py` when a refactor
touches something none of them reaches. `tests/test_same_behaviour.py` plants a rule change, a lost road and a changed
seizure order in copies of `hexa/` and a crash, and checks that each is caught (a crash reports ORACLE FAILED).

Use `python3` where `python` isn't on PATH. Tests do not need pygame installed, except `tests/ui/` and twelve game
modules that import it at the top (`tests/test_landscape.py`, `test_passes.py`, `test_playtest.py`,
`test_techscreen.py`, `test_uifixes.py`, `test_wfctiles.py`, `test_goodsobjects.py`, `test_mapview_polish.py`,
`test_town_labels.py`, `test_review_fixes.py`, `test_playtest2.py`, `test_ridge_art.py`, which the CI `ui` job runs too): they skip without it (errors under `HEXA_REQUIRE_PYGAME=1`).
Window tests subclass `tests/support/harness.py:UITestCase`
(SDL dummy drivers, fake `Clock`/`get_ticks`, pinned fonts, temp `HEXA_HOME`), script input with
`self.driver.at(frame, key(...)/click(...))` and `self.driver.run_for(frames, until=...)`, call the window's real
`run()`, then assert on `app.world`/`app.ui`. They import pygame and window modules inside the test, never at
module top. A failing one saves its last frame to `test-artifacts/` (`HEXA_TEST_ARTIFACTS`).
`tests/ui/test_screenshots.py` compares 15 fixed-seed frames with `tests/golden/linux/*.png` through
`tests/support/golden.py` (sha256 first, then at most `max_pixels` pixels off by 8 or more in a channel; a failure
writes `<scene>.actual/.golden/.diff.png` to `test-artifacts/`). The goldens are made on Linux only (`UPDATE_GOLDEN=1`,
the docker line above or the `goldens` workflow, which uploads them and never commits); a change that alters a
window's look ships with its regenerated, reviewed goldens.

`test_tech_ai` is the slowest (~1 min: AI runs of 60 and 40 seasons, both `@slow`); `test_properties` (~50 s:
20 random games per mode, determinism subprocesses) and `test_campaign` (~35 s: building the Europe map takes
seconds) come next; `test_game` runs in ~10 s.

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
- **Campaign:** one turn is one season, played by `GameManager.end_season()` (`campaign/game.py`, pygame-free).
  `CampaignApp.end_turn()` draws its busy frame and delegates to it; tests play seasons through it
  (`tests/support/worlds.play_seasons`). The fixed order: `world.settle_preview()`, `ai.run(world, tag)` for every
  non-player country, `world.end_round()` (logistics, sieges, war timeouts, economy, debt, growth, research, turn
  counter), the caller's `orders` hook (the app's march reminders for `unit.goal` orders), the autosave if due,
  `world.ensure_markets()`, and a `season_ended` event. Campaign AIs only know what their country has explored
  (`country.explored`). `world.player = None` makes everything visible, as in most tests.
  `tools/oracle_runner.py` and `tools/save_compat.py` keep their own season loops on purpose: they must run against
  base checkouts that have no manager.

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
  `__dict__` minus `geo`, which is rebuilt from `map` + `seed` on load). Files from a newer `VERSION` are
  ignored; older ones load, and `CampaignWorld._migrate` fills in what they lack (`WORLD_DEFAULTS`, dataclass
  field defaults). Renaming or adding attributes and dataclass fields changes what saves contain. Lazily added
  attributes use `getattr`/`__dict__.setdefault` (`_known_world`, `_explored_from`) so older saves still load;
  bump `VERSION` when compatibility breaks. A bump alone doesn't refuse older saves (`saves.load` reads every
  version from 1 to `VERSION`): either `_migrate` fills in what they lack, or `saves.py` must refuse the old version
  too. The `save-compat` job of `tests.yml` enforces this `VERSION` policy on pull requests that touch
  `hexa/campaign/` (`tools/save_compat.py`): games saved by the merge base's code must load and play a season with
  the pull request's while `VERSION` is unchanged; after a bump each must be refused quietly (`saves.load` returns
  `None`) or still play.
- Saves and options (`hexa/settings.py`) live in `~/.hexa/`; the `HEXA_HOME` environment variable overrides
  this, and `tests/test_saves.py` uses it with a temporary folder.
- `gamemenu.GameMenu` is a mixin base class of `CampaignApp`: the Esc menu, save/load, options, and the screen
  mode (window size, fullscreen). Saving, loading and the autosave go through `app.game`, the `GameManager`
  (`game.save(slot)`, `GameManager.load(slot)`, `game.autosave()`); `app.world` is `app.game.world`.
- **UI kit and panels** (`hexa/ui/`, `hexa/campaign/panels/`). `ui/theme.py` holds the colour tokens (the map window and
  pause menu's plain names, the technology screen's `TECH_*`, the start menu's `MENU_BG`) and the font loader
  (`new_font`, cached `font`); windows import from it and never call `pygame.font.SysFont` themselves. `ui/kit.py` has
  the immediate-mode helpers in today's look: `button` (registers a hit box on `ctx.ui.buttons`), `menu_button`,
  `flat_button`, `fit`, `wrap`, `text`, `shade`, `heading`, `tip`, `hover_card`, `panel_frame`. A `ctx` is the
  drawing window (`CampaignApp`: `screen`, `ui`, fonts, `panel_rect()`, `view_rect()`). Each side panel is a
  module of `campaign/panels/` with `draw(ctx, world, ui, subject)` (province, unit, country, market, raise_,
  ledger; `panels.draw()` picks by `ui.panel`); `panels/cards.py` builds the hover cards from the world. Panels lay
  out from `kit.panel_frame(ctx)` (never the app's `WIDTH`), read the world and register buttons; they never
  change it. `CampaignApp.press(action)` looks `action[0]` up in the `PRESS` table (one `_do_<kind>` method each).
- **Event bus** (`hexa/events.py`, pygame-free). `world.bus` is a transient `EventBus`: the rules call
  `world.bus.emit(kind, tag, pos, **data)` where state changes (capture, war, peace, raise, kills, desertion,
  seizure, passes, research, ages, colonies, buildings, sieges, battles; `world.message()` emits `message`), which
  only queues an `Event` and records it in a bounded `bus.history`. The app drains the queue once a frame
  (`process_events()`) and after each season; tests read `bus.history`. The kinds and their fields are listed in
  the `hexa/events.py` docstring (`CAMPAIGN_KINDS`). The bus is left out of `save_state()` and rebuilt in
  `_restore`, so saves and snapshots never contain it. Handlers must not change the game (the one exception is the
  "declared war on you" log line, kept for its text and place in the log). The war alert subscribes to
  `war_declared`; it replaced the old before/after diff of the war list.
- **Markets** are rebuilt lazily (`world.refresh_markets()` marks them, `ensure_markets()` rebuilds). `draw()` no
  longer calls it: `refresh()`, `process_events()` and `end_season()` do, so drawing never changes the game.
- `art.py` draws extra tiles, decorations, unit figures and tokens in code, in the Kenney style at 120x140.
  `MapView` switches from flat colours to tile art at zoom index `TILE_FROM`.

### Legacy map editor

`Hex.py`, `Game.py`, `Setting.py`, `Create_xml.py` and `Read_XML.py` at the repo root are the original
pygame-gui tile editor (it loads `map3.xml`). They don't touch the `hexa` package, and the `map*.xml` / `.tmx`
files are their data. `pygame-gui==0.5.7` is in `requirements.txt` only for this editor.

### Assets

`hexagon-pack/` is the Kenney Hexagon Pack (CC0). Every app gets `TILES_DIR` (`hexagon-pack/PNG/Tiles`) from
`play.py`; the campaign's `art.py` finds object sprites in the sibling `Objects` folder.

## Structure rules (adopted 2026-11-12, see docs/architecture/review-2026-11-12.md)

The target structure: files and folders named here appear as the refactor phases land (`ui/` and `campaign/panels/` have). Until then, new code follows
the rules as far as the current layout allows, and never makes an allowlisted offender bigger.
- **Layers, imports point down only:** data -> state -> systems -> world (facade) -> game manager -> screens/panels
  -> app. Systems take `world` as a parameter and never import world.py, ui, render or pygame. Render and
  panels read the world through public methods only and never assign to world or state objects.
- **Player actions:** a new action is `x_check(world, ...)`/`x(world, ...)` in its system module, with a facade
  on CampaignWorld and a pair in tests/support/agents.py. The UI and the AI change state only through actions.
- **One owner per attribute:** each system module lists the world attributes it writes in `OWNS`;
  tests/test_architecture.py enforces it. A new attribute goes in `WORLD_DEFAULTS` (or a dataclass default) in
  the same PR. Derived caches are listed in `WORLD_CACHES` and are not saved.
- **Events, not polling:** a system that changes something the player should notice calls
  `world.bus.emit(kind, ...)`. Event handlers never change the world. The bus is never saved.
- **Season order** lives in campaign/systems/season.py `PHASES` and nowhere else; the game manager runs it.
- **Size limits:** a module over 800 lines needs a reason in its docstring; over 1,200 it is split. A function
  over 60 lines needs a reason; over 100 it is split (art recipes and map generation: 150). Today's offenders
  are allowlisted in tests/test_architecture.py and may not grow.
- **No cross-module `_private` use** outside tests. Tests prefer public functions of system modules.
- **UI:** buttons, panels, rows, tooltips and modals come from hexa/ui/kit.py, colours and fonts from
  hexa/ui/theme.py. No new hand-drawn button.
- **Render caches** are `render.cache.BoundedCache` instances, registered by name. No new module-level dict
  cache. Time-sliced work uses `render.budget.FrameBudget`.
- **Refactor PRs** change no behaviour: label them `refactor`; they must pass tools/same_behaviour.py,
  save-compat and sha-identical goldens. Never mix a refactor and a gameplay change in one commit.
- **Where new features go:** rules -> campaign/systems/<name>.py (+ numbers in data.py, + README table);
  panel -> campaign/panels/; screen -> campaign/screens/; art -> its art module using render/draw.py.
