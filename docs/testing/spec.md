# Hexa testing spec

Status: draft for review · Date: 2026-11-11 · Scope: GergoPeterSomodi/Hexa at `13fdbde` (branch `docs/claude-md-readme`)

This spec covers how Hexa should be tested beyond today's rule tests: a CI pipeline, unit-test gaps and
speed, a headless pygame harness that drives the real apps, screenshot (golden image) tests, and
property, fuzz, save-compatibility and performance checks. Every claim marked **(measured)** comes from a
prototype run on one machine (macOS arm64, 2026-11-11). The prototype code was throwaway and is not part of the repository;
the tickets in the Testing foundation milestone rebuild it properly.

---

## 1. Where we are today

| Item | State |
|---|---|
| Framework | stdlib `unittest`, 5 modules, **79 tests**, all pass |
| Runtime | **119 s** full suite on Python 3.15, Apple Silicon (measured) |
| pygame in tests | none. No test imports pygame, so the menu, all three app windows, renderers, `MapView`, `art`, `gamemenu` and `play.py` are never executed by a test |
| CI | none: there is no `.github/` folder |
| Coverage measurement | none |
| Lint/format | none (out of scope here, listed under open questions) |
| Open crash bugs | #5 to #11 (milestone v0.1.1) are all in code the tests never reach: file I/O error paths, the start menu, the pause menu and CLI handling. Most UI bugs (#16 to #19, #22, #24, #26, #27) are also in untested window code |

**Where the time goes (measured, Python 3.12):** building the Europe map takes 2.4 s and is cached
per process in `_SNAPSHOTS`, so `fresh()` costs 0.08 s. A random world takes 2.9 s and its restore 0.09 s.
An all-AI season costs 0.12 s in 1480 and about 0.55 s on average over 100 seasons, as armies and colonies
grow. Conquest and colony worlds cost milliseconds. Two tests take **70 % of the run**:
`test_thirty_years_of_history` (55 s) and `test_survival_games_end_on_time` (32.5 s). The Europe build is not
the bottleneck. Section 10 has the per-test durations.

**pygame availability (measured):** this machine's default `python3` is 3.15 and has no pygame.
`pygame` 2.6.1 (the newest release allowed by `requirements.txt`, `pygame>=2.0,<3`) only ships wheels up to
CPython **3.13**. There are no 3.14 or 3.15 wheels, so `pip install -r requirements.txt` would have to build
from source. `pygame-ce` 2.5.8 does have 3.14 and 3.15 wheels. All pygame prototyping below used a 3.12 venv.

**Coverage today (measured with coverage.py 7.17, branch coverage, unit suite only): 58 % in total.** The rules,
worlds, map generation and AI are at 80 to 100 %. Every pygame module (`campaign/app.py`, `mapview.py`,
`art.py`, `gamemenu.py`, `menu.py`, `render.py`, `colony/app.py`, `colony/render.py`) and `play.py` are at
**0 %**. 4,011 of 9,689 statements are never run, 3,648 of them in those pygame modules. Adding only the prototype harness scenarios and a few short
monkey runs raises the total to **86 %** (§10).

---

## 2. Goals and non-goals

**Goals**
1. Every push and PR runs the tests on GitHub Actions and shows the result in under about 5 minutes.
2. The existing promise stays true: `python -m unittest discover -s tests -t .` passes **without pygame**.
   New pygame tests skip cleanly when pygame is missing, and fail loudly in the CI job that is meant to run them.
3. The real windows (menu, Conquest, Colonisation, Age of Discovery, pause menu) can be driven headless with
   synthetic input, and tests can assert on world state after that input.
4. Rendering regressions are caught by comparing frames against reviewed golden images, using only
   stdlib and pygame, with a one-command way to regenerate the goldens and a diff image when a test fails.
5. Crash classes like #5 to #11 are pinned by regression tests and found earlier by fuzzing and seeded
   random-input (monkey) runs.
6. Simulations stay deterministic for a given seed (replays, goldens and bug reports depend on that), and
   save/load never changes the course of a game.
7. Coverage and test duration are visible on every CI run, so gaps and slowdowns show up early.

**Non-goals**
- Switching to pytest, or adding numpy, PIL or Hypothesis. The suite stays stdlib `unittest`. The only new
  dev dependency is `coverage` (CI only, justified in §8 D3). Revisit under open questions.
- Testing the legacy map editor (`Hex.py`, `Game.py`, `Setting.py`, `Create_xml.py`, `Read_XML.py`, which
  need `pygame-gui`).
- Pixel-perfect goldens on every OS. Linux CI holds the reference images, and other platforms run them
  only when asked (§5).
- Testing balance ("is the AI fun?"). Invariants and smoke tests only.
- Fixing the open bugs. This work adds the tests that catch them. The bug fixes land under their own issues.

---

## 3. Test layers

```
                 ┌───────────────────────────┐
  nightly        │ L5 soak / perf / compat   │  long AI games, long monkey runs, map-build budget, save compat across commits
                 ├───────────────────────────┤
  PR (pygame)    │ L4 screenshot goldens     │  ~15 fixed-seed frames vs tests/golden/linux/*.png
                 │ L3 headless harness       │  real run() loops, synthetic events, short monkey runs
                 ├───────────────────────────┤
  PR (no pygame) │ L2 property / fuzz        │  invariants, determinism, check/action agreement, file fuzz
                 │ L1 unit                   │  existing 79 tests + gap tests (settings, saves, CLI, ...)
                 └───────────────────────────┘
```

L1 and L2 import no pygame and run on every supported Python version. L3 and L4 need pygame and run on one
pinned Linux configuration. L5 runs on a schedule and on demand.

### 3.1 L1: unit tests (stdlib, no pygame)

Keep the current style: behaviour-named tests, real worlds rather than mocks, the shared Europe world
for read-only checks and `fresh()` for anything that mutates. Additions:

**Gap tests (pygame-free code)**

| Area | What to add |
|---|---|
| `hexa/settings.py` | non-object JSON (`[]`, `null`, `1`: #7), unknown keys ignored, wrong types (`{"fullscreen": 0}` is accepted today because `0 == False`, found by the fuzz prototype), unwritable folder on `save()` (#10), `window_size` parsing, `HEXA_HOME` override |
| `hexa/campaign/saves.py` | header that is not an object (#7); header with the right `version` but missing `saved` (**new crash found by fuzzing**: `latest()` raises `KeyError: 'saved'`, so the start menu would crash at launch); `describe()` with a bad `saved` value (`TypeError`, `OverflowError`); unwritable folder (#5); a well-formed pickle of an incomplete state (#6: `KeyError` from `from_state`, outside the `try`); `.tmp` file left behind when pickling fails; `VERSION` mismatch rejected quietly |
| CLI (`play.py main`) | argument parsing is currently inline in `main()` after `import pygame`, so it can't be tested without pygame. Move it into a pygame-free `hexa/cli.py` (`build_parser()`, `parse(argv)`) and test the defaults, choices, `--seed` type and `--nation` normalisation (#11) |
| `hexa/hexgrid.py` | odd-r neighbour symmetry, `distance` metric properties, `within(r)` size `3r(r+1)+1` |
| AI | world-level scenario tests for open AI bugs (#21 foraging, #25 pioneer occupancy) next to their fixes |

**Speed and fixtures**
- Move the shared helpers into `tests/support/` (not test modules, so discovery skips them):
  `worlds.py` (`europe()` shared read-only, `fresh(player)`, `random_world(seed)` cached, `play_seasons(world, n)`),
  `home.py` (the `TempHome` mixin that `test_saves` has today), and `slow.py` (an `@slow` decorator).
- Add a **pristine guard**: `tearDownModule` in each module that shares `WORLD`/`EUROPE` checks that its turn,
  version and a cheap digest are unchanged, so a test that mutates the shared world by mistake fails at once
  instead of making later tests order-dependent.
- Add `@slow` to the seven tests that take about 114 s of the 125 s (measured): the 100-season history (55 s), colony
  survival games (32.5 s), 20-seed Conquest AI games (7.8 s), the cavalry test (6.2 s) and the three
  random-world tests (2.7 to 5.6 s). `HEXA_FAST=1` skips them for a local loop of an estimated 10 to 15 s (from the
  durations). CI always runs everything.
- Report the slowest tests on every CI run with `--durations 15` (stdlib `unittest`, Python 3.12+).
- Don't add a parallel runner yet. The Europe build is only 2.4 s per process, so if wall time becomes a
  problem, shard CI by test module across jobs (each job pays the 2.4 s once). That is cheaper than adding a
  dependency. An on-disk snapshot cache keyed on a hash of `hexa/campaign/*.py` would save about 2.4 s per
  process but adds cache-invalidation risk, so it is deferred.

### 3.2 L2: property, determinism and fuzz tests (stdlib, no pygame)

Generated inputs come from seeded `random.Random`, and each failure message prints the seed. No Hypothesis.

1. **Determinism across processes.** Run a short fixed-seed game in a subprocess under two different
   `PYTHONHASHSEED` values and compare a digest of the outcome. *(Measured: Conquest AI-vs-AI to the end,
   Colonisation 30 turns, and Age of Discovery 8 all-AI seasons give identical digests under hash seeds 0, 1
   and 4242, so no outcome depends on set or str hash order today. This test keeps it that way.)*
2. **Save/load continuation.** Play N seasons, save, load, then play M more seasons on both the original and
   the loaded copy. The outcome must be identical: owners, treasuries and units. *(Measured: identical after
   4+4 seasons, about 6 s. The RNG state survives pickling.)*
3. **Check/action agreement.** For every `x_check` / `x` pair in all three worlds: when the check says no, the
   action must not change the world (compare `pickle.dumps(world.save_state())` digests, or a field digest for
   Conquest and Colonisation), and when the check says yes, the action succeeds. A seeded random agent picks
   among the legal and illegal actions each turn. This turns the CLAUDE.md convention into an enforced
   contract and is the natural net for bugs like #13 (foraging an army) or #20 (overfilled ship).
4. **World invariants after random play** (any seed, any turn):
   - Conquest: units stand on passable land, one unit per hex, no negative stock, HP within `(0, max]`, the
     winner is set at the turn limit.
   - Colonisation: ship cargo ≤ 4, colonies have population ≥ 1, tensions stay within range, no units of
     dead sides.
   - Age of Discovery: one country per hex, `can_stand` for every land stack, naval units at sea, province
     owners are living countries or `None`, prices stay within 0.3× to 3.5× of base, `visible` ⊆ `terrain`, and
     `world.version` never goes down.
5. **File fuzzing.** Generate JSON values (null, bool, int incl. 2**70, NaN, strings, lists, nested dicts with
   real keys) for `settings.json` and save headers, plus damaged save bodies (truncated, bit-flipped,
   trailing junk, well-formed pickles of the wrong shape). Properties: `settings.load()` never raises and
   returns only known keys with legal values *of the right type*; `saves.meta/listing/latest/describe` never
   raise; `saves.load()` returns a world or `None`.
   *(Measured, 400+400+60 cases in 7 s: 333 header cases and 304 settings cases raise `AttributeError` (#7);
   37 raise `KeyError: 'saved'` (new); `describe()` raises `TypeError`/`OverflowError` (new); 1 settings case
   accepts `fullscreen: 0` (new, minor). The 60 damaged-body cases raised nothing, so the existing `except`
   covers truncation and bit flips. #6 needs the "well-formed pickle, wrong shape" case to show up.)*

   The fuzz cases that fail today go in as `@unittest.expectedFailure` tests that name the issue (#5, #6, #7,
   #10). The fix PR removes the decorator, and `unittest` reports an "unexpected success" if a fix lands
   without that.

### 3.3 L3: headless harness (pygame)

**Feasibility: proven (measured).** The prototype drives the **unmodified** `Menu.run()`, `play.App.run()`,
`ColonyApp.run()` and `CampaignApp.run()` loops with SDL's dummy video and audio drivers and synthetic events.
All checks passed:

| Scenario | Result | Wall time |
|---|---|---|
| Menu: click "Conquest", press Enter → `run()` returns `mode="conquest"`; budget exhausted → `None` | pass | 0.1 s |
| Conquest seed 42: Space → AI turn runs with its 350 ms visible-move pauses on fake time → back to player, turn 2 | pass | 0.6 s |
| Colonisation seed 5 "land": Space → rivals and natives play → turn 2 | pass | 3.3 s (1,500 frames) |
| Age of Discovery as POR: Space ends a season (turn 1 → 2); F5 writes `quick.sav` into the temp `HEXA_HOME` | pass | 2.9 s incl. Europe build |
| #9 reproduced: M + click outside the menu in the same frame → `AttributeError: menu_rect` | reproduced | 0.1 s |
| #7 reproduced: `saves/1.sav` containing `1` → `Menu(...)` raises | reproduced | 0 s |

**Design (`tests/support/harness.py`)**

- *Environment*, set before `pygame.init()`: `SDL_VIDEODRIVER=dummy`, `SDL_AUDIODRIVER=dummy` (both
  `setdefault`, so `SDL_VIDEODRIVER=cocoa` or `x11` can still be set by hand to *watch* a scripted run),
  `PYGAME_HIDE_SUPPORT_PROMPT=1`, `HEXA_HOME` = a fresh temp folder for each test class (never `~/.hexa`), `TZ=UTC`.
- *Fake time*: replace `pygame.time.Clock` with a fake whose `tick()` advances a fake millisecond counter by
  16 ms, and patch `pygame.time.get_ticks` to read that counter. AI step pauses, toasts, hover-card delays
  and move animations then run deterministically, with no sleeping.
- *Driving the real loop*: `Driver.at(frame, *events)` schedules events, and `Driver.run_for(n)` sets a frame
  budget. The fake `tick()` posts the events due on the next frame and, when the budget is spent, posts
  **one** `QUIT`. Tests call the app's real `run()` and then assert on `app.world` and `app.ui`. For one-off
  steps, tests can also call `app.handle(event)` and `app.draw()` directly.
- *Isolation*: the SDL event queue and the patched pygame functions are process-global. `Driver.reset()`
  (called in `setUp`) clears scheduled events and runs `pygame.event.clear()`. The driver posts `QUIT`
  only once.
- *Event helpers*: `key(k)`, `click(pos, button)`, `drag(start, end, button)`, `wheel(dy)`, `hover(pos)`.
  Helpers find button rects from the app's own state (`app.ui.buttons`, `menu._layout()`,
  `app.menu_buttons`) instead of hard-coding pixels, so tests survive layout changes.
- *Skipping*: `tests/support/pg.py` exposes `HAVE_PYGAME = importlib.util.find_spec("pygame") is not None`
  and `requires_pygame = unittest.skipUnless(HAVE_PYGAME or HEXA_REQUIRE_PYGAME, ...)`. Pygame-only modules
  live in `tests/ui/` and import pygame and app modules **inside** `setUpClass` or the test, never at module
  top. Verified: without pygame the prototype reports `OK (skipped=1)`; with `HEXA_REQUIRE_PYGAME=1` and no
  pygame it **errors**, so the UI job can't pass by skipping everything.

**Known limits (measured)**
- Posted `KEYDOWN` events do **not** change `pygame.key.get_pressed()`, so held-key scrolling (arrows/WASD in
  `scroll()`) can't be driven with events. Patch `pygame.key.get_pressed` in the few tests that need it.
- The dummy driver reports a 1024x768 desktop. `CampaignApp.apply_display()` clamps the window to the desktop
  minus 60 px, so without a patch the campaign opens at **1024x708** instead of 1280x720. The harness patches
  `pygame.display.get_desktop_sizes` to `[(1920, 1080)]`. Fullscreen on dummy gives 1024x768.
- `CampaignApp.end_turn()` calls `draw()` and `display.flip()` on its own, outside `run()`. That's harmless
  but means frame counts don't map 1:1 onto `tick()` calls.
- Monkey-patching is the price of changing no product code. A later, optional refactor can add a `frame()`
  method to each app (one loop iteration) and a `clock`/`time` seam, so the harness needs fewer patches.

**Scripted playthroughs and monkey (smoke) tests**
- *Scripted*: short, readable scenarios per mode. For example: select a unit with Tab, move it by clicking a
  highlighted hex, train in a town with "1", end the turn, and assert the unit moved, stock was paid and the
  turn advanced. For the campaign: open the country panel, change the tax, raise a unit, save to a slot,
  load it, open the options page.
- *Monkey*: for a seed, generate random clicks, right-clicks, mouse moves and whitelisted keys (never QUIT;
  Esc/M are allowed and the loop is restarted), and run the real loop for N frames. Assert no exception, then
  check the L2 invariants on `app.world`. **Burst mode** packs extra events into frames that already have
  some, which reproduces event-ordering races.
  *(Measured: plain monkey found nothing in 6x1,500 Conquest frames (about 2 s each), 4x1,500 Colonisation
  frames (4 to 7 s) or 6x600 campaign frames (10 to 20 s). With `BURST=0.5` it independently found **#9** on
  1 of 6 campaign seeds within 178 frames.)* On failure the test prints a one-line repro command with mode,
  seed, frame budget and burst.
- Budgets: PR CI runs 2 seeds per mode, with short budgets, in under about 60 s total. Nightly runs 50+
  seeds per mode with long budgets.

### 3.4 L4: screenshot (golden image) tests

**Determinism: proven (measured).** With the harness's fake time, pinned fonts, patched desktop size and fixed
seeds, 10 frames (menu x2, Conquest x2, Colonisation x1, campaign x5, including frames after an AI turn) gave
**byte-identical** RGB hashes across 4 separate processes on macOS, including `PYTHONHASHSEED` = random, 0
and 12345. Across platforms, in `python:3.12-slim` containers:
- linux/arm64 and linux/amd64 frames are byte-identical once the smoothscale backend is forced to GENERIC;
- macOS differs from Linux in text rasterisation only (§5).
So **one Linux golden set serves every CI runner, and a developer on Apple Silicon can regenerate it natively
in a linux/arm64 container.**

**Approach**
- *Capture*: render with the app's own draw call (`menu.draw(...)`, `renderer.draw(...)`, `app.draw()`),
  then read `pygame.image.tobytes(screen, "RGB")`.
- *Compare*: first an exact check (sha256 of the RGB bytes). On a mismatch, run a tolerance diff with
  `pygame.mask.from_threshold(actual, …, threshold=(t,t,t,255), othersurface=golden)`, which runs in C:
  **5 to 12 ms per frame** (measured), against 0.16 s for the equivalent pure-Python loop on 960x748. The test
  passes if the number of pixels off by more than `t` per channel is at most `max_pixels`. Defaults:
  `t = 8`, `max_pixels = 0` on the reference platform, configurable per golden.
  *(Measured: a uniform +3 brightness change passes at t=8 and fails at t=2; switching the menu from
  campaign to colony flags 8.5 % of pixels.)*
- *Never compare PNG bytes*: zlib/libpng versions change the encoding. Decode the golden with
  `pygame.image.load` and compare pixels. *(Measured: the PNG round trip is lossless.)*
- *Diff output*: on failure, write `<name>.actual.png`, `<name>.golden.png` and `<name>.diff.png` (the actual
  frame darkened, with differing pixels in magenta) to `$HEXA_TEST_ARTIFACTS` (default `test-artifacts/`,
  git-ignored). CI uploads that folder.
- *Regeneration*: `UPDATE_GOLDEN=1 python -m unittest tests.ui.test_screenshots` rewrites the goldens that
  differ and leaves a summary. Because only Linux goldens are authoritative, regeneration runs (a) in CI via
  a `workflow_dispatch` job that uploads the new PNGs as an artifact to review and commit, or (b) locally
  through a documented `docker run --platform linux/arm64 python:3.12-slim …` one-liner (native and fast on
  Apple Silicon; measured byte-identical to linux/amd64 with GENERIC smoothscale).
- *Storage*: `tests/golden/linux/<scene>.png` plus `tests/golden/linux/MANIFEST.json`, which records the
  pygame, SDL and Python versions and the smoothscale backend the goldens were made with. If the running
  environment doesn't match the manifest, the test **skips** with a clear reason (or fails if
  `HEXA_GOLDEN_STRICT=1`, which CI sets). Ten frames come to 1.1 MB of PNG (measured: 23 KB for the menu,
  65 to 72 KB for Conquest and Colonisation, 130 to 204 KB for campaign frames). Cap the set at about 15
  frames (about 2 MB), and crop to a region where a full frame adds nothing.
- *Scene list (first cut)*: menu (campaign / conquest / colony rows; with the Continue button from a fake
  save); Conquest seed 42 (start, a unit selected with reach shown, a town with train buttons, after one AI
  turn); Colonisation seed 5 (land start, sea start, colony panel); campaign Europe (country chooser at zoom 1,
  POR at zoom 4 with the country panel, terrain mode, goods mode, overview at zoom 0, pause menu, options
  page); random world seed 7 overview.
- *Avoid unstable content*: `saves.describe()` prints the local time of the save (`time.localtime`), so
  save/load pages need `TZ=UTC` and a fixed `saved` value. Toasts and hover cards depend on fake time, so set
  them on purpose or clear them (`ui.toast_until = 0`).

### 3.5 L5: soak, performance and save compatibility (scheduled)

- **AI soak**: Conquest AI vs AI for 200 seeds, Colonisation 50 seeds x 40 turns, campaign 3 random-world
  seeds plus Europe x 100 seasons. Check the L2 invariants every turn. Long monkey runs as in §3.3.
- **Performance budget**: time `CampaignWorld()` (Europe), `CampaignWorld(seed, map="random")`, the snapshot
  restore, one all-AI season, and `MapView` first render at zoom 1 and 4. Use `time.process_time()`, the
  median of 3 runs, and compare against `tests/perf_budget.json` with generous limits (2 to 3x the CI baseline).
  Nightly writes the numbers to the job summary and fails only past the hard limit. PRs never gate on time:
  shared runners are too noisy. Add a memory check with `tracemalloc` on the snapshot caches, which ties in
  with #29 (unbounded `_SNAPSHOTS`, about 8 MB per random world; measured: Europe snapshot 8.1 MB, random-world
  save 8.4 MB) and #30 (pathfinding cost per move).
- **Save compatibility across commits**: a CI job checks out the PR's merge base into a `git worktree` and
  uses *that* code to write saves (Europe POR after 3 seasons, random seed 7, a quicksave mid-war). It then
  loads them with the PR's code. If `saves.VERSION` is unchanged, every save must load and play one more
  season. If `VERSION` was bumped, every old save must be rejected quietly (`meta()` and `load()` return
  `None`, the menu shows no Continue, nothing crashes). No binary fixtures go into the repo (a save is about
  8 MB). There are no git tags yet, so the merge base is the reference. Once releases are tagged, add "latest
  tag" as a second reference.

---

## 4. Directory layout

```
tests/
  __init__.py
  support/                    # helpers, not tests (discovery only collects test_*.py)
    __init__.py
    worlds.py                 # europe(), fresh(), random_world(), play_seasons(), pristine guard
    home.py                   # TempHome mixin (moved from test_saves.py)
    slow.py                   # @slow, HEXA_FAST
    pg.py                     # HAVE_PYGAME, requires_pygame, HEXA_REQUIRE_PYGAME
    harness.py                # Driver, fake clock/ticks, pinned fonts, desktop size, event helpers (imports pygame lazily)
    golden.py                 # capture, compare, diff images, UPDATE_GOLDEN, manifest check
    invariants.py             # per-mode invariant checks shared by L2, L3 monkey and L5 soak
  test_game.py  test_colony.py  test_campaign.py  test_mapgen.py  test_saves.py   # existing
  test_settings.py            # settings gaps (split from test_saves)
  test_cli.py                 # hexa/cli.py
  test_properties.py          # determinism, save/load continuation, check/action agreement, invariants
  test_fuzz_files.py          # settings.json / save header / damaged save fuzzing
  ui/                         # every module here skips without pygame
    __init__.py
    test_menu.py  test_launcher.py  test_conquest_app.py  test_colony_app.py
    test_campaign_app.py  test_gamemenu.py  test_mapview_geometry.py
    test_monkey.py            # HEXA_MONKEY_SEEDS / HEXA_MONKEY_FRAMES / HEXA_MONKEY_BURST scale it
    test_screenshots.py
  golden/linux/*.png, MANIFEST.json
  perf_budget.json
tools/
  soak.py                     # long runs for nightly and local bug hunting (prints repro commands)
  perf.py                     # timing report
  save_compat.py              # write saves with one checkout, load them with another
requirements-dev.txt          # coverage (and the pinned pygame for the UI job)
.coveragerc
.github/workflows/tests.yml   # unit + ui + coverage on push / PR
.github/workflows/nightly.yml # soak, long monkey, perf, save compatibility; workflow_dispatch
.github/workflows/goldens.yml # workflow_dispatch: regenerate goldens and upload them as an artifact
```

`python -m unittest discover -s tests -t .` still finds everything, `tests/ui/` included. Without pygame
those tests show as skipped.

---

## 5. Determinism strategy

| Source of variation | Handling | Evidence |
|---|---|---|
| Map and AI randomness | Fixed seeds everywhere. All three worlds use `random.Random(seed)`, and string seeds in `randomgeo` hash with SHA-512, which is stable | Determinism prototype (§3.2) |
| `PYTHONHASHSEED` (set/str order) | Not pinned. A test in L2 asserts outcomes don't depend on it | Identical outcomes and frames under 3 to 4 hash seeds |
| Wall-clock time | Fake `Clock` and `get_ticks`. `TZ=UTC` for the save-slot pages | Toasts and animation stable across runs |
| Fonts (`SysFont("segoeui,arial")`) | **Pin to pygame's bundled font** by patching `pygame.font.SysFont` to `Font(None, size)` plus `set_bold`/`set_italic`. Tolerance can't hide font differences | Measured: macOS Arial vs the bundled font changes **3.65 %** of the menu's pixels at t=8 and still 2.3 % at t=64 |
| Desktop size on the dummy driver | Patch `get_desktop_sizes` to `[(1920,1080)]`. `HEXA_HOME` is a temp folder, so the default 1280x720 settings apply | Without the patch: 1024x708 window |
| SIMD in `smoothscale` | Call `pygame.transform.set_smoothscale_backend("GENERIC")` in the harness. x86_64 Linux defaults to **SSE**, arm64 to GENERIC | Measured: without it, linux/amd64 differs from linux/arm64 by 1,800 to 8,000 px per sprite-heavy frame (all within t=8). **With GENERIC forced, all 10 frames are byte-identical across linux/arm64 and linux/amd64** |
| Font rasteriser in the macOS vs manylinux wheels | Can't be pinned from Python. Glyph runs shift by a pixel inside some words. Linux is the golden authority; macOS runs skip on a manifest mismatch, or compare with a loose budget under `HEXA_GOLDEN_ANY_OS=1` | Measured: macOS vs Linux differ by 195 to 1,680 px per frame (0.03 to 0.23 %), still 187 to 1,558 px at t=8 |
| pygame/SDL/freetype/libpng versions | Pin `pygame==2.6.1` (bundles SDL 2.28.4) in the UI job. `MANIFEST.json` records the versions. A mismatch skips locally and fails in CI | — |
| Event queue leaking between tests | `Driver.reset()` in `setUp` and a single `QUIT` per budget | Before the fix, a leaked `QUIT` ended the next app at once and a leaked Space ran two seasons |
| OS differences that remain | Linux CI is the authority. Other platforms compare only if the manifest matches, or under `HEXA_GOLDEN_ANY_OS=1` with a loose pixel budget (about 0.5 %) | Cross-platform results in §10 |

---

## 6. CI design (GitHub Actions)

**`tests.yml`** runs on `push` and `pull_request` (`concurrency` cancels superseded runs on the same ref).

| Job | Runner / Python | Installs | Runs | Artifacts |
|---|---|---|---|---|
| `unit` | ubuntu-latest, matrix **3.10** (floor: dataclass fields use `int \| None` at runtime), **3.13**, **3.x** (newest, catches 3.14/3.15 breaks the author would hit locally) | nothing (proves no pygame is needed) | `python -m unittest discover -s tests -t . -v` (+ `--durations 15` on ≥3.12) | — |
| `ui` | ubuntu-latest, Python 3.12 | `pygame==2.6.1` | `SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy HEXA_REQUIRE_PYGAME=1 HEXA_GOLDEN_STRICT=1 TZ=UTC python -m unittest discover -s tests/ui -t . -v` | `test-artifacts/` (diff, actual and golden PNGs, monkey repro lines) `if: failure()` |
| `coverage` | ubuntu-latest, Python **3.14** | `coverage` | `coverage run --branch -m unittest discover -s tests -t .` (pygame-free suite) then `coverage report --format=markdown` into `$GITHUB_STEP_SUMMARY` and `coverage html` | `htmlcov/` |

Why Python 3.14 for coverage (measured on `tests.test_colony`): on 3.12, branch coverage took **167 s against
34 s** without it (4.9x). On 3.14, where coverage.py uses `sys.monitoring`, it took **32 s against 32 s** (no
measurable overhead). pygame has no 3.14 wheel, so the UI tests' coverage is measured in the `ui` job on 3.12
as line-only (`COVERAGE_CORE=sysmon`, cheap) and reported as a separate table. Branch and line data can't be
combined. A full combined branch report (slow on 3.12) runs in the nightly job. No `fail_under` at first: once
the harness tests land, set it a few points below the measured total and ratchet it up.

**`nightly.yml`** (`schedule: cron "0 3 * * *"` plus `workflow_dispatch` with inputs for seeds and frames):
`tools/soak.py`, long monkey runs (`HEXA_MONKEY_SEEDS=50 HEXA_MONKEY_FRAMES=3000 HEXA_MONKEY_BURST=0.5`),
`tools/perf.py` against `perf_budget.json`, and `tools/save_compat.py` against `origin/master`. A failure opens
or updates a single "Nightly failure" issue (optional, `gh issue` step) with the repro commands.

**`goldens.yml`** (`workflow_dispatch`, input `ref`): runs the screenshot tests with `UPDATE_GOLDEN=1` on the
same pinned image and uploads `tests/golden/linux/` as an artifact for the author to commit. It never
auto-commits.

**Save compatibility** runs in `tests.yml` on PRs that touch `hexa/campaign/**` (`paths` filter):
`git worktree add ../base $(git merge-base origin/master HEAD)`, then `python tools/save_compat.py write ../base out/`
and `python tools/save_compat.py check out/`.

None of the jobs need apt packages: the manylinux pygame wheel bundles SDL, and the dummy drivers need no
X server (confirmed in `python:3.12-slim` containers, §10).

---

## 7. How the pieces map to open issues

| Issue | Caught by |
|---|---|
| #5 failed save crashes | L1 saves gap test (read-only `HEXA_HOME`, `~/.hexa` is a file); L3 F5 and autosave-in-`end_turn` test |
| #6 corrupt/outdated save | L2 fuzz "wrong-shape pickle", L5 save compatibility |
| #7 non-object JSON | L2 fuzz (found today); L3 `Menu()` with a bad header (reproduced) |
| #8 unreadable save starts a new game | L3 `CampaignApp(load=...)` with a damaged body, asserting a message and no new world |
| #9 `menu_rect` before first draw | L3 scripted (reproduced) plus burst monkey (found independently) |
| #10 unwritable settings | L1 settings test; L3 F11 and options page |
| #11 `--nation` | L1 `test_cli` plus L3 launcher test |
| #16 to #19, #24 (pause menu, top bar, Esc, close buttons) | L3 campaign app tests; L4 golden for the narrow-window top bar (#18) |
| #22 orders not cancelled; #26 and #27 drawing | L3 (order state after attack); L4 golden frame mid-move |
| #13, #20 (forage army, overfilled ship) | L2 check/action agreement |
| #29, #30 caches and pathfinding | L5 perf and memory budget |

---

## 8. Decisions and trade-offs

| # | Decision | Alternatives | Why |
|---|---|---|---|
| D1 | Stay on stdlib `unittest` | pytest (+xdist, fixtures, markers) | Matches the existing 79 tests and CLAUDE.md. The few things pytest would add (markers, parallel runs) are covered by `@slow`, env vars and CI sharding. Revisit if fixtures get hard to manage |
| D2 | Monkey-patch pygame in the harness instead of changing app code | Add `frame()`, clock and font seams to the apps first | Zero product changes, proven to work. An optional follow-up refactor can remove patches later |
| D3 | `coverage.py` as the only new dev dependency (CI only, `requirements-dev.txt`) | stdlib `trace` | `trace` has no branch coverage, no HTML or combined reports, and is much slower. Coverage never becomes a runtime dependency |
| D4 | Compare goldens with `pygame.mask.from_threshold` | pure-Python loop; numpy/PIL | Runs in C (5 to 12 ms per frame), needs no new dependency, and also makes the diff image |
| D5 | Linux CI is the golden authority, with fonts pinned to pygame's bundled font and GENERIC smoothscale | per-OS golden sets; bundle a TTF in the repo; avoid text in frames | One reference set and one review. Pinning removes the biggest cross-OS difference (3.65 % of pixels for OS fonts). GENERIC makes arm64 and amd64 Linux identical. macOS still differs by 0.03 to 0.23 % (FreeType), so it is advisory only. Bundling a TTF would change the game's look. Text-free frames would miss real layout bugs (#18) |
| D6 | No binary save fixtures. Compatibility is checked by building saves from the merge base | commit gzipped fixtures | A save is about 8 MB. Building from a commit tests real old code and adds nothing to the repo |
| D7 | Known bugs go in as `expectedFailure` tests | skip; leave untested until fixed | Documents the bug, keeps CI green, and turns into an "unexpected success" when a fix lands without updating the test |
| D8 | Performance measured nightly, never gating PRs | per-PR timing asserts | Shared runners vary by ±30 % or more. A soft budget with trends avoids flaky PRs |

---

## 9. Open questions for the maintainer

1. **Python and pygame support.** `pygame` has no wheels for 3.14/3.15, and the author's default `python3` is
   3.15. Should the project (a) pin a supported Python for playing (3.12/3.13), (b) move to `pygame-ce`
   (wheels for 3.14/3.15; mostly API-compatible, but the bundled font and drawing may differ, so goldens would
   have to be regenerated), or (c) wait for pygame? The UI CI job assumes (a) for now.
2. Which Python versions count as supported for the unit matrix (proposed: 3.10, 3.13, newest)?
3. Are about 2 MB of golden PNGs in git acceptable, or do you prefer Git LFS, or cropped and smaller frames?
4. Should the nightly job open or update a GitHub issue on failure, or just leave a red run?
5. Should the harness seams (`frame()`, a clock seam, one `fonts.get()` helper used by the ~15 `SysFont` call
   sites) become product refactors after the harness proves itself?
6. Is a linter (ruff or pyflakes) wanted in CI? It is out of scope here but cheap to add to the same workflow.
7. Coverage gate: no gate, report-only, or a `fail_under` ratchet once the UI tests land?

---

## 10. Prototype findings (measured on 2026-11-11)

Environment: macOS arm64, Python 3.12.16 venv, pygame 2.6.1 (SDL 2.28.4), coverage 7.17.2 (plus a Python 3.14
venv for the coverage-overhead check; the baseline run used the system Python 3.15 with no pygame); Linux checks in
`python:3.12-slim` containers (linux/arm64 native and linux/amd64 emulated).

**What worked**
- `harness.py` + `scenarios.py`: every scenario in §3.3 passes against unmodified repo code; frames are
  byte-identical across 4 processes and 3 hash seeds.
- `compare_demo.py`: lossless PNG round trip; 0 differing pixels between runs; real changes flagged with a
  diff image (`diff_menu.png`); tolerance behaves as expected; 5 to 12 ms per compare.
- `monkey.py`: stable for Conquest and Colonisation; burst mode found #9.
- `fuzz_files.py`: reproduces #7 and found new crash classes (`KeyError: 'saved'` in `latest()`;
  `TypeError`/`OverflowError` in `describe()`; `fullscreen: 0` accepted).
- `determinism.py`: all three simulations deterministic across hash seeds; save/load continuation identical.
- `tests_proto/test_ui_skip.py`: skip without pygame, run with pygame, error under `HEXA_REQUIRE_PYGAME=1`.
- `xplat.py`, `xplat2.py`: cross-platform frame comparison (macOS vs linux/arm64 vs linux/amd64), with diff images `xdiff_*.png`.
- `font_demo.py`: OS font vs pinned bundled font (`menu_pin0.png` vs `menu_pin1.png`).

**What did not work, or needed fixing**
- First harness version: after the frame budget, `run()` processed `QUIT` but `tick()` ran once more and
  posted a *second* `QUIT` plus pending scripted events. They leaked into the next app: Colonisation exited
  at once (turn 1 → 1) and the campaign got two Space presses (turn 1 → 3). Fixed with a single `QUIT` and
  `reset()`. This is the reason for the isolation rules in §3.3.
- `pygame.mask.from_threshold` rejects an alpha threshold of 256 (`TypeError`); use 255.
- Posted key events don't update `key.get_pressed()`, so held-key scrolling can't be scripted by events alone.
- The dummy driver's 1024x768 desktop shrinks the campaign window unless patched.
- Plain (non-burst) monkey runs found no crashes in the budgets tried. They are a cheap safety net, not a
  bug finder on their own.
- The 60 damaged-body save cases (truncate, bit-flip, junk) all loaded as `None` or as a world. #6 needs
  structured "wrong shape" pickles to show up.
- pygame can't be installed for this machine's default Python 3.15 (no wheel).

**Cross-platform golden check** (`xplat.py`, `xplat2.py`). Same scenarios, pygame 2.6.1 / SDL 2.28.4
everywhere. Cells give differing pixels at per-channel threshold t=1 / t=8.

| Frame | macOS vs linux/arm64 | linux/arm64 vs linux/amd64 (SSE) | linux/arm64 vs linux/amd64 (GENERIC forced) |
|---|---|---|---|
| menu_default | 965 / 894 | 0 / 0 | identical |
| menu_colony | 1,680 / 1,558 | 0 / 0 | identical |
| conquest_seed42_start | 456 / 407 | 8,064 / 0 | identical |
| conquest_seed42_turn2 | 427 / 380 | 6,356 / 0 | identical |
| colony_seed5_land_start | 510 / 472 | 3,609 / 0 | identical |
| campaign_por_start | 195 / 187 | 3,617 / 0 | identical |
| campaign_por_turn2 | 229 / 218 | 3,617 / 0 | identical |
| campaign_por_turn2_terrain | 229 / 218 | 1,825 / 0 | identical |
| campaign_por_turn2_goods | 229 / 218 | 2,589 / 0 | identical |
| campaign_por_overview | 254 / 236 | 0 / 0 | identical |

The macOS-vs-Linux diff image (`xdiff_menu_mac_vs_linarm.png`) shows the differences sitting in a few
words where a glyph run is shifted by one pixel. That points to a different FreeType build in the macOS
wheel, not to game code. In the containers, every functional check from §3.3 passed too, and the amd64 run
(emulated) took about 2x the wall time.

Docker side effect: the prototype pulled `python:3.12-slim` (arm64 and amd64 variants) onto this machine.
`docker image rm python:3.12-slim` removes it.

**Coverage** (coverage.py 7.17.2, `--branch`, Python 3.12; stmts / missed / cover):

| Module | Unit suite only | + prototype harness and short monkey runs |
|---|---|---|
| hexa/world.py, ai.py, rules.py, mapgen.py, hexgrid.py | 95 to 100 % | 95 to 100 % |
| hexa/settings.py | 100 % (but no error-path tests; the fuzz found crashes) | 100 % |
| hexa/campaign/world.py | 2,090 / 124 / 93 % | 94 % |
| hexa/campaign/ai.py | 91 % | 91 % |
| hexa/campaign/saves.py | 89 % | 91 % |
| hexa/campaign/randomgeo.py, wfc.py, geo.py, data.py | 95 to 100 % | same |
| hexa/colony/world.py | 88 % | 88 % |
| hexa/colony/ai.py | 80 % | 80 % |
| hexa/campaign/app.py | 1,172 / 1,172 / **0 %** | **61 %** |
| hexa/campaign/mapview.py | 778 / 778 / **0 %** | **79 %** |
| hexa/campaign/art.py | 494 / 494 / **0 %** | **82 %** |
| hexa/campaign/gamemenu.py | 180 / 180 / **0 %** | **55 %** |
| hexa/menu.py | 107 / 107 / **0 %** | **90 %** |
| hexa/render.py | 238 / 238 / **0 %** | **89 %** |
| hexa/colony/app.py | 331 / 331 / **0 %** | **74 %** |
| hexa/colony/render.py | 348 / 348 / **0 %** | **86 %** |
| **Total** | 9,689 / 4,011 / **58 %** | **86 %** |

(`play.py` was given as a source file but coverage did not report it, so use `include =` in `.coveragerc`.)
Coverage cost: the full branch-coverage unit run took 520 s CPU on Python 3.12, against 124 s without
coverage. A cleaner A/B on `tests.test_colony`: 3.12 took 34 s plain and 167 s with branch coverage; 3.14 took
32 s plain and 32 s with branch coverage. Hence the coverage job runs on 3.14 (§6).

**Per-test durations** (`--durations 20`, Python 3.12, total 124.8 s):

| Test | Time |
|---|---|
| test_campaign.AITest.test_thirty_years_of_history | 55.1 s |
| test_colony.AITest.test_survival_games_end_on_time | 32.5 s |
| test_game.AITest.test_ai_games_finish_without_errors | 7.8 s |
| test_campaign.WarTest.test_cavalry_wins_in_the_open_but_not_in_forests | 6.2 s |
| test_mapgen.RandomWorldTest.test_the_same_seed_gives_the_same_world_and_others_differ | 5.6 s |
| test_mapgen.RandomWorldTest.test_ai_runs_on_a_random_world | 4.6 s |
| test_saves.SaveTest.test_random_worlds_save_too | 2.9 s |
| test_mapgen.RandomWorldTest.test_a_random_world_is_playable | 2.7 s |
| test_colony.AITest.test_companies_settle_and_grow | 2.1 s |
| all other 70 tests | < 1 s each |

Other timings (Python 3.12): Europe build 2.40 s; snapshot restore (`fresh()`) 0.08 s; random world (seed 9)
build 2.89 s and restore 0.09 s; 40 Conquest worlds 0.04 s; one Colonisation world 0.01 s; Europe snapshot
8.1 MB pickled; random-world save 8.4 MB.
