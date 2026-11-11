# Triage of issues by kioba (GergoPeterSomodi/Hexa)

Checked 2026-11-11 against a fresh clone of master at `24f6089` (85 commits). Code is read, not run in the game, unless noted.
Unit tests on master: 114 tests, all OK (about 100 s, pygame 2.6.1, temp HEXA_HOME).
Open PRs checked: #60 to #66 (fix branches for #12 to #15, #20, #21, #28).

Counts (44 issues): FIXED and closed 7 (#5 to #11) | HAS OPEN PR 7 | FIXED but still open 2 | OUTDATED 1 | STILL OPEN 13 (3 of them partial) | testing/infra STILL OPEN 14.

## Bugs and features (#5 to #34)

| # | Title | Status | Severity | Priority | Note |
|---|---|---|---|---|---|
| 5 | Failed save crashes the game | FIXED (PR #42, merged) | crash | done | |
| 6 | Corrupt or outdated save crashes Continue/Load/F9 | FIXED (PR #41, merged) | crash | done | |
| 7 | Non-object JSON in save header / settings crashes start | FIXED (PR #36, merged) | crash | done | |
| 8 | Unreadable save silently starts a new game | FIXED (PR #39, merged) | wrong rules | done | |
| 9 | Pause menu click before first draw crashes | FIXED (PR #38, merged) | crash | done | |
| 10 | Unwritable settings.json crashes F11/Options | FIXED (PR #37, merged) | crash | done | |
| 11 | --nation with unknown or lowercase tag crashes | FIXED (PR #40, merged) | crash | done | |
| 12 | Cannons bombard their own stack on an enemy castle hex | HAS OPEN PR #63 | wrong rules | P1 | `world.py _targets` adds castles with the attacker's own units on them; `attack_options_group` offers "bombard" at distance 0. AI siege stacks shoot themselves. Bug present on master. |
| 13 | Player can forage an enemy army and freeze it | HAS OPEN PR #62 | wrong rules | P1 | `app.py` unit panel draws "Forage the land" before the owner check; `world.py forage_check` has no owner check. Still present on master. |
| 14 | Peace teleports armies that are fighting a third country | HAS OPEN PR #61 | wrong rules | P1 | `world.py peace()` moves every unit of a/b in any foreign province, with no check that the land owner is the other party. Still present. |
| 15 | White peace returns provinces held by a third country | HAS OPEN PR #60 | wrong rules | P2 | `world.py peace_offer` resets `controller = owner` on all provinces before `peace()`. Still present. |
| 16 | Right-click to close pause menu moves or attacks | STILL OPEN | UI | P2 | `gamemenu.py menu_handle` closes the menu on button-3 press; the button-3 release then reaches `app.py handle()` (line ~345) with `drag` None, and `right_click` runs. No PR. |
| 17 | Load game and F9 replace game with no confirmation | STILL OPEN (partial) | UI | P2 | F9 now asks first (`gamemenu.py quickload`, "Press F9 again"). The Load page slots still load at once (`menu_press` "load" branch). |
| 18 | End season overlaps Menu button on narrow windows | STILL OPEN | UI | P2 | `app.py` top bar: `end_w = max(64, ...)` ignores `menu_x`, so End and Menu overlap at 1024 px. Arithmetic in the issue checks out. End is added first and takes the click. |
| 19 | Esc doesn't deselect a stack, pause menu can't open | STILL OPEN | UI | P3 | `app.py handle()` Esc branch sets `ui.selected = None` but keeps `ui.group`; `refresh()` (lines 209-210) re-selects `group[0]`. |
| 20 | Boarding overfills a ship when two ships share a hex | HAS OPEN PR #66 | wrong rules | P2 | `world.py move_group` picks the first own ship on the hex with no capacity check. Still present on master. |
| 21 | Computer armies never forage at season end | HAS OPEN PR #64 | AI (wrong rules) | P2 | `world.py logistics` calls `forage()`, which needs `moves_left > 0` via `forage_check`. After a march that is usually 0. Still present. |
| 22 | Attack / improve / found / forage doesn't cancel a move order | STILL OPEN | wrong rules | P2 | `app.py right_click` attack branch keeps `unit.goal`; only the move branch clears it. |
| 23 | Changing tax reruns the economy mid-season, eats pending demand | STILL OPEN | wrong rules | P2 | `app.py press()` "tax" calls `world.economy()` directly. |
| 24 | Close (x) button doesn't close country and market panels | STILL OPEN | UI | P3 | `app.py draw_panel` sends `("panel", ui.panel)`, and `press()` re-opens "country" and "market". |
| 25 | AI pioneers use a stale occupancy map | OUTDATED | AI | - | Pioneers are retired: `data.py:312` says "Pioneers are retired (provinces invest from the panel now)". There is no `_pioneers` in `ai.py`. Close candidate. |
| 26 | Fog not redrawn for hexes revealed partway through a move | STILL OPEN | cosmetic | P3 | `world.py move_group`: intermediate `see_from(refresh=False)` calls run before `before = len(country.explored)` is taken, so their reveals never trigger `changed()`. |
| 27 | Moving units drawn twice during a move animation | FIXED on master (no PR link) | cosmetic | - | `mapview.py` draw (about lines 325-326) filters moving units out of the stationary stack. Looks fixed; visual check not run. Close candidate after a look. |
| 28 | Battle report counts total missing HP as losses | HAS OPEN PR #65 | UI (messages) | P2 | `world.py _battle` (lines ~2729 and ~2404) still uses `kind.hp - hp`. Still present on master. |
| 29 | World caches grow without limit | FIXED on master (40f9e5e, not linked) | perf | - | `world.py` `RANDOM_KEPT = 2`, eviction in `map_source` and `_remember_snapshot`. Closures in the geography were not checked. Close candidate. |
| 30 | move_group runs pathfinding 2-3 times per move | STILL OPEN (partial) | cosmetic (perf) | P3 | Pathfinding is now once in `move_group` (plan is passed to `reachable_group` and `route`). Per-step `self.cargo()` scans (`world.py cargo` is O(units)) remain. |
| 31 | Old World / New World special-cases map == 'random' | STILL OPEN | wrong rules (AI) | P3 | `ai.py _pick_site` still drops `lon > 20` for random worlds, and `_colonise` uses Europe's Africa box. |
| 32 | HEXA_HOME lookup duplicated in settings.py and saves.py | STILL OPEN | cosmetic (code) | P3 | `settings.py _path()` and `saves.py home()` both read HEXA_HOME and fall back to ~/.hexa. |
| 33 | MapView built twice on load; dead SCROLL; no-op conditional | STILL OPEN (partial) | cosmetic (code) | P3 | `app.py __init__` builds `MapView` (line ~88), then `load_world` builds it again (line ~106). `SCROLL = 18` (line 19) is unused. The no-op `font = ...` line is already gone. |
| 34 | Remove dead MapView._unit | STILL OPEN | cosmetic (code) | P3 | `mapview.py _unit` (line ~843) has no callers (`grep "_unit("` finds only the definition). |

## Testing and infrastructure (#44 to #57)

No CI exists on master (no `.github/` folder). Only `docs/testing/spec.md` and `plan.md` exist (PR #43, merged). Existing tests: `tests/` has 8 modules, and `test_continue.py`/`test_gamemenu.py` already run pygame headless with `SDL_VIDEODRIVER=dummy`. Nothing else in the list has been built.

| # | Title | Status | Severity | Priority | Note |
|---|---|---|---|---|---|
| 44 | Run unit tests on GitHub Actions | STILL OPEN | idea | P2 | No `.github/workflows`. Blocks #46, #57, #56. |
| 45 | Move shared fixtures into tests/support, fast mode | STILL OPEN | idea | P3 | No `tests/support`. |
| 46 | Report coverage with coverage.py | STILL OPEN | idea | P3 | No coverage config. Depends on #44. |
| 47 | Regression and fuzz tests for settings.json and saves | STILL OPEN | idea | P2 | Some corrupt-save tests exist in `test_saves.py`, but no fuzzing. |
| 48 | Move CLI parsing into pygame-free hexa/cli.py | STILL OPEN | idea | P3 | `hexa/cli.py` missing. Parsing is still in `play.py` (argparse, line ~250). |
| 49 | Determinism, save/load and invariant property tests | STILL OPEN | idea | P2 | No property-test library or determinism tests found. |
| 50 | Headless pygame harness and UI job in CI | STILL OPEN (partial) | idea | P2 | Dummy-driver tests exist; no shared harness and no CI job. |
| 51 | Start menu and launcher loop headless | STILL OPEN | idea | P3 | |
| 52 | Conquest and Colonisation windows headless | STILL OPEN | idea | P3 | |
| 53 | Age of Discovery window, pause menu, map geometry headless | STILL OPEN | idea | P3 | |
| 54 | Seeded monkey tests for each window | STILL OPEN | idea | P3 | |
| 55 | Golden screenshot tests with UPDATE_GOLDEN | STILL OPEN | idea | P3 | Depends on #50. |
| 56 | Nightly soak, performance and memory budgets | STILL OPEN | idea | P3 | Depends on #44. |
| 57 | Save compatibility job (previous commit saves still load) | STILL OPEN | idea | P2 | No `tools/save_compat.py`. Depends on #44 and #47. |

## Unpushed tech-tree work (local folder, read only)

Grep of the local `hexa/campaign/` files shows the tech-tree work does not fix any open bug above. It does change the same code, though: `world.py` (forage_check, logistics, move_group boarding, peace, _targets, _battle), `app.py` (Esc handling, tax button, panel close). Expect merge conflicts or re-fixes there when the work is pushed. The Esc, tax, close-button and F9/Load code is unchanged.

## What to do next

1. P1: Review and merge PRs #63 (#12), #62 (#13), #61 (#14). They are small and cover real rule bugs.
2. P2: Review and merge PRs #60 (#15), #64 (#21), #65 (#28), #66 (#20). Then fix #16 (right-click release in menu, no PR yet).
3. P2: Fix #18 (End and Menu overlap; irreversible season end), #22 (orders survive attacks), #23 (tax reruns economy), #17 (Load page confirm).
4. P2 testing: #44 (CI), then #47, #49, #50, #57.
5. P3: #19, #24, #26, #31, then the cleanups #30, #32, #33, #34, #48, and the rest of the testing items (#45, #46, #51-56).
6. Close candidates after a quick check: #25 (outdated), #27 and #29 (fixed on master).
