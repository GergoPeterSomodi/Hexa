# Hexa testing: implementation plan

Companion to [`spec.md`](spec.md). Fourteen tasks, each one PR, in dependency order. The IDs (T1 to T14) match
the titles of the issues in the Testing foundation milestone. Sizes: **S** is up to half a day, **M** is 1 to 2 days, **L** is about 3 days. The total is
roughly 20 engineer-days. Phases 1 and 2 can run in parallel once Phase 0 has landed.

```
Phase 0  foundations        T1 CI unit ─┬─ T3 coverage
                            T2 support ─┤
Phase 1  pygame-free gaps   T4 files ◄──┤ (T2)      T5 cli        T6 properties ◄─ (T2)
Phase 2  headless harness   T7 harness + UI job ◄─ (T1, T2)
                              ├─ T8 menu + launcher
                              ├─ T9 conquest + colony windows
                              ├─ T10 campaign window + pause menu + MapView geometry
                              └─ T11 monkey ◄─ (T6 invariants)
Phase 3  screenshots        T12 goldens ◄─ (T7)
Phase 4  scheduled          T13 nightly soak/perf ◄─ (T6, T11)     T14 save compatibility ◄─ (T1, T4)
```

## Ground rules for every task

- `python -m unittest discover -s tests -t .` must pass **without pygame** after every PR. CI's `unit`
  job checks this.
- No pygame imports at module top in anything under `tests/` that isn't `tests/ui/` or `tests/support/harness.py`.
- Every test that touches files uses a temporary `HEXA_HOME` (`tests/support/home.py`).
- Generated inputs come from seeded `random.Random`, and failure messages include the seed and a one-line
  repro command.
- A test for a bug that is still open goes in as `@unittest.expectedFailure`, with the issue number in its
  docstring. The PR that fixes the bug removes the decorator.
- Each PR updates `README.md` (Development section) and `CLAUDE.md` (Commands) when it adds a command or an
  environment variable.
- Coordinate with the v0.1.1 crash fixes (#5 to #11), which are being worked on in parallel. If a fix lands
  first, its test is a plain test. If not, use `expectedFailure`.

## Phase 0: foundations (no pygame)

### T1: Run the unit suite on GitHub Actions (S)
1. Add `.github/workflows/tests.yml` with a `unit` job on `push` and `pull_request` and
   `concurrency: {group: tests-${{ github.ref }}, cancel-in-progress: true}`.
2. Matrix `python-version: ["3.10", "3.13", "3.x"]` on `ubuntu-latest`. Do **not** install requirements, so
   the job proves the suite needs no pygame.
3. `env: HEXA_HOME: ${{ runner.temp }}/hexa-home`. Run
   `python -m unittest discover -s tests -t . -v`, and add `--durations 15` when the version is ≥ 3.12.
4. If 3.10 fails, raise the floor to the lowest passing version and write it down in README Setup.
5. Add a status badge to the README.

### T2: Shared fixtures, `@slow` and the pristine guard (S)
1. Create `tests/support/{__init__,worlds,home,slow}.py`. Move `TempHome` out of `test_saves.py`. Add
   `europe()`, `fresh(player)`, `random_world(seed)` (cached) and `play_seasons(world, n, player_ai=True)`.
2. Switch the existing modules over without changing what they assert. The test count stays at 79.
3. Mark as `@slow`, skipped when `HEXA_FAST=1`: `test_thirty_years_of_history` (55 s),
   `test_survival_games_end_on_time` (32.5 s), `test_ai_games_finish_without_errors` (7.8 s),
   `test_cavalry_wins_in_the_open_but_not_in_forests` (6.2 s) and the three `RandomWorldTest` cases (2.7 to 5.6 s).
   Goal: a `HEXA_FAST=1` run in under about 25 s, against 125 s for the full suite.
4. Add `tearDownModule` pristine guards for the shared `WORLD` (`test_campaign`) and `EUROPE` (`test_mapgen`).

### T3: Coverage in CI (S, after T1)
1. Add `requirements-dev.txt` (`coverage>=7.6,<8`) and `.coveragerc` (`branch = True`, `source = hexa`,
   `include = play.py` too, omit the legacy editor files).
2. Add a `coverage` job that runs the pygame-free suite on **Python 3.14**. Measured on `tests.test_colony`:
   branch coverage costs 4.9x on 3.12 (167 s against 34 s) and nothing measurable on 3.14 (32 s against 32 s).
   Once T7 lands, the `ui` job adds a line-only (`COVERAGE_CORE=sysmon`) report for `tests/ui` on 3.12 as a
   second table. Branch and line data can't be combined, so the combined branch report runs nightly.
3. Write `coverage report --format=markdown` to `$GITHUB_STEP_SUMMARY` and upload `htmlcov/`. No
   `fail_under` yet. Today's baseline is 58 % (unit suite); the prototype harness and monkey runs alone reach 86 %.

## Phase 1: pygame-free gaps

### T4: Settings and save-file regression and fuzz tests (M, after T2)
1. `tests/test_settings.py`: non-object JSON (#7), unknown keys, wrong types (`fullscreen: 0`), `save()` into
   an unwritable folder (#10), and `window_size`.
2. Extend `tests/test_saves.py` with: non-object header (#7); header with the right version but **no `saved`
   key** (new: `latest()` raises `KeyError`); `describe()` with a bad `saved` (new: `TypeError`/`OverflowError`);
   unwritable folder and `~/.hexa` being a file (#5); a good header with a wrong-shape pickle (#6); version
   mismatch; no `.tmp` left behind after a failed save.
3. `tests/test_fuzz_files.py`: port the prototype `fuzz_files.py` (default 300 cases, `HEXA_FUZZ_CASES`
   scales it, `HEXA_FUZZ_SEED` replays a run).
4. Ask the coordinator to file an issue for the new crash class (missing `saved` and bad `saved` types)
   unless it is folded into #7.

### T5: Move CLI parsing into a pygame-free `hexa/cli.py` (S)
1. Move the parser from `play.main()` into `hexa/cli.py`: `build_parser()` and
   `parse(argv) -> (settings, skip_menu, nation, seed)`. `play.main()` calls it. `--help` output stays the same.
2. `tests/test_cli.py`: defaults, every choice, an invalid choice (`SystemExit` 2), the `--seed` type, and
   `--nation` passthrough (plus normalisation once #11 is fixed). A subprocess check confirms that importing
   `hexa.cli` does not import pygame.

### T6: Property, determinism and invariant tests (M, after T2)
1. Add `tests/support/invariants.py` with `check_conquest`, `check_colony` and `check_campaign` (spec §3.2.4).
2. `tests/test_properties.py`:
   - Determinism: run the same seeded game in two subprocesses with `PYTHONHASHSEED` 0 and 1 and compare
     digests (Conquest to the end, Colonisation 30 turns; campaign 4 seasons under `@slow`).
   - Save/load continuation: Europe 3 seasons, save state, load, then 3 more seasons on both copies, which must
     match.
   - Check/action agreement: a seeded random agent for Conquest and Colonisation (every `*_check` pair) and a
     campaign subset (`improve`, `recruit`, `build`, `found`, `forage`, `war`). A refused action must leave the
     state digest unchanged.
   - Invariants after every turn of 20 seeded random-agent games per mode.
3. Known violations become `expectedFailure` tests (likely #13, #20), or new issues if unknown.

## Phase 2: headless harness (pygame)

### T7: Harness and UI CI job (M, after T1 and T2)
1. Add `tests/support/pg.py` (`HAVE_PYGAME`, `requires_pygame`, `HEXA_REQUIRE_PYGAME`).
2. Add `tests/support/harness.py`, ported from the prototype `harness.py`:
   - environment defaults set before `pygame.init()`;
   - fake `Clock` and `get_ticks`;
   - `SysFont` pinned to the bundled font;
   - `get_desktop_sizes` patched to `[(1920, 1080)]`;
   - `set_smoothscale_backend("GENERIC")`;
   - `Driver` (`at`, `run_for`, `reset`, single `QUIT`);
   - event helpers `key`, `click`, `drag`, `wheel`, `hover`;
   - helpers that find button rects from app state.
   Install the patches once per process (idempotent) and keep the originals so a test can restore them.
3. Add `tests/ui/__init__.py` and `tests/ui/test_smoke.py`, one test per app (menu returns the chosen mode;
   Conquest, Colonisation and campaign Space → turn 2, asserted on world state).
4. Add a `ui` job to `tests.yml`: ubuntu-latest, Python 3.12, `pip install pygame==2.6.1`,
   `HEXA_REQUIRE_PYGAME=1`, `TZ=UTC`, runs `tests/ui`, and uploads `test-artifacts/` on failure.
5. Check by hand that without pygame the smoke tests show as *skipped*, and that with
   `HEXA_REQUIRE_PYGAME=1` they *error*.

### T8: Start menu and launcher loop (M, after T7)
1. Menu: the rows shown for each mode, option clicks, Enter/Space/Esc/QUIT, and a Continue button that shows
   only with a valid save and returns `load=slot`.
2. A bad save header must not crash `Menu()` (#7; `expectedFailure` until fixed).
3. Launcher: patch `sys.argv` and run `play.main()` with `--mode conquest --seed 42`. M returns to the menu
   and Esc quits, so `main()` returns. `--nation XYZ` covers #11 (`expectedFailure` until fixed).

### T9: Conquest and Colonisation windows (M, after T7)
Scripted tests that assert on world and UI state:
- Conquest: Tab selection, click-to-move, attack, train with 1 to 4, build with B, Space with the AI turn on
  fake time, R, M and Esc.
- Colonisation: ship movement and landing, found/join, colony jobs 1 to 7, homeland trade at the east edge,
  village gift and trade, right-drag scrolling, held-key scrolling (patch `key.get_pressed`), and minimap clicks.

### T10: Age of Discovery window, pause menu and MapView geometry (L, after T7; can be split into two PRs)
1. Country chooser click, Space and the End-season button, F5/F9, autosave cadence, map modes 1 to 4 and goods
   view cycling, zoom keeping the hovered hex fixed, panel open and close, multi-season orders advancing.
2. Pause menu: open with Esc/M; navigate the main, save, load and options pages; overwrite needs a second
   click; options persist to `settings.json`; F11 flips `fullscreen`.
3. MapView geometry (no harness needed, just pygame): `hex_at(*center(p)) == p` for every zoom and sampled
   `p`, points within 0.8r map to the same hex, and `size()` covers every centre.
4. Regression tests (`expectedFailure` until fixed): #9, #16, #17, #18 (a 1024-wide window), #19, #22, #24.

### T11: Seeded monkey tests (M, after T7 and T6)
1. `tests/ui/test_monkey.py` takes its seeds, frame budgets and burst ratio from `HEXA_MONKEY_SEEDS`,
   `HEXA_MONKEY_FRAMES` and `HEXA_MONKEY_BURST`. PR defaults: 2 seeds per mode; 800 frames for Conquest and
   Colonisation, 300 for the campaign; burst 0.3. Total under about 60 s.
2. A key whitelist with no QUIT. When Esc or M ends the loop, restart it. Assert that nothing raised, then run
   the T6 invariants.
3. A failure prints `python -m tools.monkey <mode> <seed> <frames> --burst <b>`. Add `tools/monkey.py` for
   local bug hunting.

## Phase 3: screenshots

### T12: Golden screenshot tests (L, after T7)
1. `tests/support/golden.py`:
   - an exact sha256 check first, then a `pygame.mask.from_threshold` tolerance diff (t=8, `max_pixels` set
     per scene, default 0);
   - on failure, write `actual`, `golden` and `diff` PNGs to `$HEXA_TEST_ARTIFACTS`;
   - `UPDATE_GOLDEN=1` rewrites the goldens;
   - check the environment against `MANIFEST.json`: skip on a mismatch, fail under `HEXA_GOLDEN_STRICT=1`.
2. `tests/ui/test_screenshots.py` with about 12 to 15 scenes (spec §3.4).
3. Generate the first goldens in Linux. Locally that means `docker run --platform linux/arm64 python:3.12-slim …`.
   Measured: with GENERIC smoothscale, linux/arm64 and linux/amd64 frames are byte-identical, so Apple Silicon
   developers can produce CI-valid goldens natively.
4. Add `.github/workflows/goldens.yml` (`workflow_dispatch` that regenerates the goldens and uploads them as an
   artifact; it never commits). Add `test-artifacts/` to `.gitignore`. Document the update flow in README.
5. Keep the goldens at 2.5 MB or less.

## Phase 4: scheduled jobs

### T13: Nightly soak and performance/memory budgets (M, after T6 and T11)
1. `tools/soak.py`: Conquest AI vs AI over 200 seeds; Colonisation 50 seeds x 40 turns; Europe 100 seasons;
   3 random worlds x 40 seasons. Check invariants every turn and print repro commands.
2. `tools/perf.py`: Europe build, random build, snapshot restore, an all-AI season, and `MapView` first draw.
   Take the median of 3 with `process_time`, compare against `tests/perf_budget.json`, and write a markdown
   table to the step summary. Fail only past the hard limits. Add a `tracemalloc` check on `_SNAPSHOTS` and
   `_RANDOM_GEOS` growth (#29; `expectedFailure` until fixed).
3. `.github/workflows/nightly.yml`: a cron schedule plus `workflow_dispatch` inputs; long monkey runs
   (`HEXA_MONKEY_SEEDS=50`, burst 0.5). Optionally open or update a "Nightly failure" issue.

### T14: Save-compatibility job (M, after T1 and T4)
1. `tools/save_compat.py write <checkout> <out>` imports `hexa` from the given checkout and writes three
   saves: Europe POR after 3 seasons, random seed 7 after 2 seasons, and a quicksave mid-war.
   `tools/save_compat.py check <out>` loads them with HEAD: if `VERSION` is unchanged they must load and play a
   season; if it was bumped they must be rejected quietly.
2. In `tests.yml`, add a job on PRs that touch `hexa/campaign/**` that runs
   `git worktree add` for the merge base, then `write` and then `check`.
3. Add a CLAUDE.md note (Saves bullet): the job enforces the `VERSION` bump policy.

## Risks and how the plan handles them

| Risk | Mitigation |
|---|---|
| UI tests are flaky because of shared global pygame state | `Driver.reset()` in `setUp`, a single `QUIT`, a temp `HEXA_HOME` per class, and patches installed once (spec §3.3) |
| Goldens churn on every visual tweak | Keep the set small (about 15) and run regeneration as one dispatch job. Goldens only fail in the `ui` job, so pure-logic PRs aren't blocked |
| macOS developers can't reproduce golden failures natively | Measured: macOS and Linux text rendering differ by 200 to 1,700 px per frame. The documented docker one-liner reproduces CI exactly |
| pygame drops out (3.14+ has no wheels) | The `ui` job pins 3.12. Open question in spec §9 about `pygame-ce` |
| CI time grows | `--durations` on every run, `@slow`/`HEXA_FAST` locally, shard by module if needed, coverage on 3.14 with sysmon |
| Tests written against buggy behaviour | Open bugs use `expectedFailure`, never assertions of the wrong behaviour |

## Definition of done for the whole effort
- On every PR: `unit` (3 Python versions), `ui` and `coverage` are green, with the summary showing coverage
  and the slowest tests.
- Every v0.1.1 crash issue (#5 to #11) has a test that fails without its fix.
- The goldens cover the menu and all three modes. A visual change produces a reviewable diff artifact.
- Nightly soak, perf and save-compat have run green for a week.
