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

Importing the `tests` package changes two defaults of `hexa.settings` for the whole test process (`tests/__init__.py`):
`movement` is `"off"` (no movement replay) and `reminders` is `False` (no end-of-turn reminders), so the many tests that
press End season get the next season at once. The game ships `"normal"` and `True` (`tests.SHIPPED_DEFAULTS`). A test of
those features sets `app.settings[...]` itself; the monkey plays odd seeds with the replay on, seeds 1, 5, 9... with the
reminders too.

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

Use `python3` where `python` isn't on PATH. Tests do not need pygame installed, except `tests/ui/` and fourteen game
modules that import it at the top (`tests/test_landscape.py`, `test_passes.py`, `test_playtest.py`,
`test_techscreen.py`, `test_uifixes.py`, `test_wfctiles.py`, `test_goodsobjects.py`, `test_mapview_polish.py`,
`test_town_labels.py`, `test_review_fixes.py`, `test_playtest2.py`, `test_ridge_art.py`, `test_sprite_hashes.py`, `test_render_cache.py`, which the CI `ui` job runs too): they skip without it (errors under `HEXA_REQUIRE_PYGAME=1`).
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
  `CampaignApp.end_turn(key, confirmed)` first lets a running movement replay block it (a key skips the replay) and the
  reminder list ask (see Screens), then draws its busy frame and delegates to it; tests play seasons through it
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
  `world.py` and `systems/worldgen.py` read geography only through `world.geo`, so any new attribute must exist on both sources, or be
  read with a `getattr` default as `COLONIAL` and `FORCE_SEA` are. Distances in `data.py` scale with
  `geo.SCALE`.
- **State classes** (`hexa/campaign/state.py`): `Province`, `Market`, `Route`, `Country`, `Unit`, `Garrison`, `War` and
  `fill_defaults` (what `_migrate` uses to give an old save's objects the fields they lack). `world.py` re-exports the
  names, so `from hexa.campaign.world import Province` still works. Saves pickle these classes by module and name, so
  state.py pins each class's `__module__` to `hexa.campaign.world` (decision D5): a save made now still opens in a build
  from before the split, and an old save opens now. Never drop that loop, and never rename a class (that needs a
  `VERSION` bump); `tools/save_compat.py` checks both directions.
- **World generation** (`hexa/campaign/systems/worldgen.py`, the first module of the `systems/` package): everything
  that only runs while a world is built, as functions taking `world`: `build_map`, `build_countries`, `build_roads`,
  `starting_units` and their helpers (`terrain_prior`, `good_for`, `trace`, `crest_edges`, `build_edges`,
  `join_pockets`...). `CampaignWorld.__init__` calls them in order, with the start techs and the markets between
  (those are research and trade). The module never imports world.py; it reaches the running world only through
  public methods (`passes`, `edge_blocked`, `add_unit`, `land_spot`, `provinces_of`, `total_pop`, `units_at`, `ridge_edges`,
  `is_land`, `is_sea`). `world.py` keeps
  a facade only where something else calls: `_cross`, `_unit_point`, `_unit_centre` (tests),
  and `_pass_data`, which calls `worldgen.build_edges`. `OWNS` lists the world attributes the module sets.
- **Colonies** (`systems/colonies.py`): `found_check`/`found` (facades on `CampaignWorld`) and the colonial part of the
  season's `grow()` loop: `settlers` (the growth bonus and arriving settlers), `natives` (natives settling and raiding)
  and `graduate` (a colony becomes a province). `grow()` calls them where that code used to sit, so the order of
  changes and random draws is unchanged.
- **Building** (`systems/building.py`): `build_check`/`build` and `invest_check`/`invest` with their helpers (`build_cost`,
  `build_goods`, `invest_cost`, `invest_goods`, `building_name`, `works_name`, `slots_used`, `goods_price`) and `job_check`
  (a province does one job a season; the military module shares it). `BUILDING_TECH` lives there. `CampaignWorld` keeps a
  facade for each one called from outside; a `*_check` and its action stay a pair, and the facade is the same pair.
- **Military** (`systems/military.py`): `unit_cost`, `raise_options`, `stack_limit`, `can_stand`, `recruit_check`/`recruit`,
  `refit_check`/`refit` and `upgrade_cost`/`upgrade_check`/`upgrade`, all with facades. `land_spot` stays on `CampaignWorld`
  (it reads the pass walls, which move with step 3.10); the module calls it as `world.land_spot`.
- **Debt** (`systems/debt.py`): `debt_limit`, `troop_order` (who deserts first), `disband`, `seize_one` and `unpaid` (the
  season's step: desertion, then seizures, then the credit cap). The facades are `debt_limit`, `disband` and `_unpaid`.
  The module reaches the world's private parts only through two public names added for it: `world.kill` (the old
  `_kill`) and `world.forget_castles()` (drops the `castles()` cache). The bankruptcy feature builds on these functions.
- **Research** (`systems/research.py`): techs, ideas, ages and the start techs: `grant_tech`, `pick_idea`, `fund_check`/
  `fund_research`, `next_era`, `research_rate`, `tech_cost`, `set_research`, `unqueue`, the season step `research_season`
  (with `finish_research`, `advance`, `new_age`) and the build-time `start_techs`/`legacy_techs`. `has`, `bonus`,
  `_effects` and `tech_changed` stay plain methods on `CampaignWorld` on purpose: they own the `_bonus_cache` and are
  called thousands of times a season, so no extra call layer. Never write `world._bonus_cache` from a system module.
- **Trade** (`systems/trade.py`): the markets (`build_markets`, `rebuild_markets`, `ensure_markets`), the routes between them
  (`build_routes`, `route_capacity`, `route_cost`), the merchants' orders (`merchants`, `merchant_options`, `send_merchant_check`/
  `send_merchant`, `recall_merchant`) and the goods that move along a route each season (`merchants_trade`, `trade_route`, which
  the economy step calls). Facades on `CampaignWorld` for everything the UI, AI and tests call. The two caches stay owned by
  world.py behind public methods: `take_markets_dirty()` (reads and clears `_markets_dirty`, which `refresh_markets` raises;
  `trade.ensure_markets` rebuilds when it says so) and `sea_distances(start)` (the `_sea_cache`; `trade.sea_walk` is the walk).
  `move_cost` is the public name of the old `_move_cost` (step cost without the ridge walls).
- **Terrain** comes from `wfc.collapse` (wave function collapse): per-hex priors from `worldgen.terrain_prior`
  plus the `FORBIDDEN` adjacency pairs at the top of `systems/worldgen.py` (`world.FORBIDDEN` is the same list).
- **Build caching.** Building a world takes seconds, so `CampaignWorld.__init__` stores a pickled snapshot of
  each fresh `(map, seed)` world in the module-level `_SNAPSHOTS` and restores later constructions from it.
  `map_source` caches random geographies in `_RANDOM_GEOS`. `_SNAPSHOTS`, `_RANDOM_GEOS` and the
  snapshot logic stay in world.py (the `systems/worldgen.py` functions only build; they never touch the caches). Tests share one module-level `WORLD` for read-only
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
- **Screens** (`hexa/campaign/screens/`, a window package). `CampaignApp` is no longer built from mixins. What covers
  or dims the map is a `Screen` (`screens/__init__.py`: `draw(ctx)`, `handle_event(ctx, event)` -> consumed,
  `update(ctx, dt)`, `opaque` = hides the map, `on_enter/on_exit`) on `app.screens`, a `ScreenStack` (push, pop, remove,
  replace, clear, top, `hides_map`). The stack belongs to the window, not to `GameManager`: a screen is drawn with pygame
  and answers to the window's mouse, fonts and size, and the manager stays pygame-free and is played without a window (the
  review's "the manager's stack" became the app's stack). `draw()` skips the map and the HUD while an opaque screen is up
  and then draws the stack bottom to top; `handle()` offers every event to the top screen first (F5, F9 and F11 go before
  it). A screen gets the app as `ctx` and uses only its public attributes and methods, listed in the `screens/__init__.py`
  docstring (`screen`, `ui`, fonts, `game`, `world`, `player`, `settings`, `toast`, `load_world`, `open_country`,
  `apply_display`, `running`/`result`, `screens`, `pause`); it never imports `hexa.campaign.app`
  (`tests/test_architecture.py` checks it, so the old app-gamemenu cycle cannot come back).
  - `screens/gamemenu.py`: `PauseMenu` (Esc or M; `page` is None, "main", "save", "load", "options" or "question",
    plus `confirm`, `question`, `buttons`, `rect`; not opaque, the map shows under a shade) and the functions the menu and
    the keys share, taking the app as ctx: `save_to`, `load_from`, `quickload`, `autosave`, `autosave_toast`,
    `toggle_grid`, `toggle_fullscreen`, `save_options`. Saving, loading and the autosave go through `ctx.game`, the
    `GameManager` (`game.save(slot)`, `GameManager.load(slot)`, `game.autosave()`); `app.world` is `app.game.world`. The
    screen mode lives in `CampaignApp.apply_display` (`campaign/display.py` opens the window).
  - `screens/reminders.py`: `ReminderScreen` and `ask(ctx)`, the end-of-turn list. `CampaignApp.end_turn(key, confirmed)`
    calls `ask` after the replay check: with the "End-of-turn reminders" option on (`settings["reminders"]`) and something
    unfinished it pushes the screen (not opaque, a shade over the map) and the season waits. The lines come from
    `campaign/reminders.py` (pygame-free: one function per rule, `unfinished(world, tag)` returns `Reminder(kind, text,
    hint, action)`; an `action` is a tuple `CampaignApp.press` understands: `("tech",)`, `("market", market)`,
    `("province", prov)`, `("log", "goto", hex)`). A line click takes the screen off and presses its action; "End season
    anyway" (Enter) takes it off and calls `end_turn(confirmed=True)`; Back (Esc, right-click, click outside) only takes it
    off; Space is used up. Buttons are `ui/kit.menu_button`s, colours `ui/theme` tokens.
  - `screens/techscreen.py`: `TechScreen` (T; one instance for the life of the window, so the selected tech is kept):
    the grid is opaque, the idea modal is the same screen with the grid closed. It is on the stack while the grid is open
    or idea cards are pending: the idea cards are game state, not a click, so `app.tech.sync(app)` runs in `handle()`,
    `draw()` and the war-alert check. `techlayout.py` (geometry, node rects, state of a tech: no drawing) and
    `techdraw.py` (all the drawing) are its parts. `campaign/gamemenu.py` and `campaign/techscreen.py` only re-export
    the new names.
  - The app keeps read-only views of the screens' state for tests and tools: `app.menu` (the page), `menu_confirm`,
    `menu_question`, `menu_buttons`, `menu_rect`, `tech_open`, `tech_selected`, `tech_buttons`; `open_menu()`,
    `close_menu()` and `open_tech()` open and close them. Change a screen through its own methods
    (`app.pause.press(app, action)`, `app.tech.close(app)`), not by assigning to these views.
- **UI kit and panels** (`hexa/ui/`, `hexa/campaign/panels/`). `ui/theme.py` holds the colour tokens (the map window and
  pause menu's plain names, the technology screen's `TECH_*`, the start menu's `MENU_BG`) and the font loader
  (`new_font`, cached `font`); windows import from it and never call `pygame.font.SysFont` themselves. `ui/kit.py` has
  the immediate-mode helpers in today's look: `button` (registers a hit box on `ctx.ui.buttons`), `menu_button`,
  `flat_button`, `icon_button`, `chip`, `fit`, `wrap`, `text`, `shade`, `heading`, `tip`, `hover_card`, `panel_frame`. A `ctx` is the
  drawing window (`CampaignApp`: `screen`, `ui`, fonts, `panel_rect()`, `view_rect()`); the screens below take it the same way. Each side panel is a
  module of `campaign/panels/` with `draw(ctx, world, ui, subject)` (province, unit, country, market, raise_,
  ledger; `panels.draw()` picks by `ui.panel`); `panels/cards.py` builds the hover cards from the world. Panels lay
  out from `kit.panel_frame(ctx)` (never the app's `WIDTH`), read the world and register buttons; they never
  change it. `CampaignApp.press(action)` looks `action[0]` up in the `PRESS` table (one `_do_<kind>` method each).
- **HUD** (`hexa/campaign/hud/`, a window package). What is drawn over the map besides the side panels: `topbar.py` (the
  resource chips of `resources.snapshot`: icon, value, change, a hover card per chip and a click that opens its panel; the
  chips are buttons named "Ledger", "Research", "Provinces", "Army", "Market", "Prestige", so tests click them by label;
  `plan()` drops key goods, changes, "End season" and chips as the window narrows), `floating.py` (ribbon tags rising from
  hexes, fed by `feed.take_floating()`; `Floaters.add` keeps only what the camera sees: in view, not under the panel, not
  fogged, 3 per hex, 16 in all), `actionlog.py` (the collapsible log of `feed.entries()`: filters, season groups, place
  links) and `style.py` (the colour and icon of the six kinds). `Hud` (`hud/__init__.py`) holds their state and is made with
  each game by `CampaignApp._set_game`; the window calls `hud.draw_world/draw_log/draw_top` from `draw()`, `hud.press` from
  `PRESS["log"]` and `hud.wheel` from its wheel handler. `hud.covers(ctx, pixel)` is true over the top bar, the minimap
  and the log's box: `hex_under`, a drag start and so a right-click or pan never reach the map there, and `left_click`
  lets the open side panel win over a button that pokes into it. While a screen is up (`Hud.hidden(ctx)`: the window's
  stack is not empty: tech screen, idea modal, pause menu) the HUD draws nothing and leaves the feed's floating queue
  alone (`take_floating(max_age)` drops what is too old). HUD modules
  read the world and register buttons; they hold their own fonts (`new_font`, not the cached `theme.font`, which can
  outlive pygame; both are emptied by a `pygame.register_quit` hook) and never change the game. `ui/icons.py` draws the
  icons into a `BoundedCache` (`campaign/render/cache.py`, re-exported by `ui/cache.py`; registered by name, emptied on quit; `icon()` hands out copies); `ui/kit.py` has `chip`, `icon_button` and a `hover_card` whose lines may have a right-aligned amount
  (text with a tab) and rules (`("", None)`).
- **Lines for the action log.** Most log lines come from bus events (`feed.py` handlers). A `world.message()` that has no
  event of its own must name a notice, `world.message(text, tag, "idea", pos)` (`feed.NOTICES`: start, lead, treasury,
  credit, merchant, idea, growth, supply, extinct, march, research); `tests/test_hud_data.py` reads the source and fails
  on a message that names none and is not one an event already tells. Notices are log lines only (the Money filter takes
  treasury, credit and merchant).
- **Event bus** (`hexa/events.py`, pygame-free). `world.bus` is a transient `EventBus`: the rules call
  `world.bus.emit(kind, tag, pos, **data)` where state changes (capture, war, peace, raise, kills, desertion,
  seizure, passes, research, ages, colonies, buildings, sieges, battles; `world.message()` emits `message`), which
  only queues an `Event` and records it in a bounded `bus.history`. The app drains the queue once a frame
  (`process_events()`) and after each season; tests read `bus.history`. The kinds and their fields are listed in
  the `hexa/events.py` docstring (`CAMPAIGN_KINDS`). The bus is left out of `save_state()` and rebuilt in
  `_restore`, so saves and snapshots never contain it. Handlers must not change the game (the one exception is the
  "declared war on you" log line, kept for its text and place in the log). The war alert subscribes to
  `war_declared`; it replaced the old before/after diff of the war list. A tap that raises is logged once per (tap, kind)
  (`logging.getLogger("hexa")`), counted every time in `bus.tap_errors`; with `HEXA_DEBUG=1` it is raised, so a developer sees the bug.
- **Movement replay** (`campaign/replay.py`, pygame-free). The world moves a stack at once and `move_group` emits
  `unit_moved` (tag, end hex, `ids`, `path`, `naval`, and `seen`: per hex of the path, whether the player could see it
  when the stack moved; the player's own walks are all seen). The window records those events in `ui.replay` (a
  subscriber made in `_set_game`; the "Movement speed" option `settings["movement"]`: off, normal or slow) and plays
  them as a picture: `MapView._draw_units` draws a walking stack where `replay.poses()` says (waiting on its first hex,
  or between two hexes) instead of at its world position. A step is played when either end was seen; fogged steps are
  instant and a fully fogged walk is not recorded. Countries play in turn order, the stacks of one country together;
  about 0.18 s a hex, the whole replay capped at about 6 s (countries then play two, three... at a time, then the pace
  rises, never below 40 ms a hex). `Replay.advance(dt)` runs from `CampaignApp.run()` (not while a screen is up);
  nothing it does touches the world, so the oracle, saves and `world.version` are unaffected. While `replay.active`,
  `end_turn()` is blocked (a click toasts, Space or Enter skips: `end_turn(key=True)`); `Hud._timed` holds the floating
  ribbons until `replay.ready_at(pos)`. Tests turn the option off (see below).
- **Markets** are rebuilt lazily (`world.refresh_markets()` marks them, `ensure_markets()` rebuilds). `draw()` no
  longer calls it: `refresh()`, `process_events()` and `end_season()` do, so drawing never changes the game.
- **Drawing primitives** (`campaign/render/draw.py`): `Pen` (tile coordinates at 2x), `Canvas` (ground layer, object layer,
  `stamp` with the ink outline, `shadow`, `finish` to the hex), `ell`, `lerp`, `mix`, `in_poly`, `hex_mask`, `shadow_at`. The
  art modules import them from there (goodsart's `Tile` and landmarks' canvas are `Canvas`es); a new art module does the same.
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
- **Render caches** are `campaign/render/cache.py` `BoundedCache` instances, registered by name (`cache.stats()`; hits, misses
  and bytes with `detail=True`). No module-level dict cache or `lru_cache` in the art modules (`tests/test_render_cache.py` checks);
  `@BoundedCache(name, n).memo` caches a function of positional arguments. Landscape's per-MapView caches use the same
  class (the registry is weak and adds up caches of one name). Sizes come from measurement (`python -m tools.perf`
  prints entries, MB, hits and misses per cache): a cache is bounded above what a full tour of the map needs, so it
  evicts only when worlds change. Time-sliced work uses `campaign/render/budget.py` `FrameBudget` (MapView's `LAND_*_MS` and `PREFETCH_*` constants stay in
  mapview.py and are read when a slice starts, so a test can lift them).
- **Refactor PRs** change no behaviour: label them `refactor`; they must pass tools/same_behaviour.py,
  save-compat and sha-identical goldens. A change to an art module also keeps `tests/test_sprite_hashes.py` green (sha256
  of 1,743 generated sprites against `tests/fixtures/sprite_hashes/<platform>.json`, one fixture per OS, Python, pygame and SDL).
  CI's `ui` job compares only on a platform that has a fixture and skips otherwise; the Linux fixture is made by the goldens
  workflow, and `UPDATE_SPRITES=1` rewrites this platform's fixture only for a change of art on purpose. Never mix a
  refactor and a gameplay change in one commit.
- **Where new features go:** rules -> campaign/systems/<name>.py (+ numbers in data.py, + README table);
  panel -> campaign/panels/; screen -> campaign/screens/; art -> its art module using render/draw.py.
