# M8 build spec: the AI

Technical director (Fable) for the AI frame, with the game and systems designer (Opus) for the temperaments, 2026-11-17.
**Status: a proposal, design only; it waits for the owner's go.** Builds milestone M8 of
`docs/architecture/godot-architecture.md` (the standard) on the M1 build spec (`m1-build-spec.md`), the M1.5 UI foundation
(`ui-and-controls-spec.md`, `ui-style-and-feedback-spec.md`), and the M2, M3, M4, M4.5, M5, M6 and M7 specs and plans
(`m2-build-*.md` to `m7-build-*.md`). Where this page is more exact it wins for M8; section 1.2 lists every place where it
refines an earlier page. The tasks are in `m8-build-plan.md`. This page carries the M8 row of the standard's 9.1 (the AI-turn
pill; the AI's moves replayed) and of `ui-style-and-feedback-plan.md` S5 (the AI reads `Knowledge`; the soak checks the
`stats` budget).

**What M8 is.** Every country the player does not play is played by the computer, through the same actions and the same checks
as the player, seeing only what its country may know. Each season, when the player presses End season, the countries take
their turns one after another: they set their taxes, begin works, raise and disband companies, give their armies orders, set
their standing orders, declare war, storm, and make peace. Their thinking runs in short slices over several frames, so the
map stays smooth; a pill says "Countries are moving 3 / 12" and the map takes only camera moves meanwhile. Then the season's
phases run as before and the replay plays the walks you saw, the AI's among them. Each country has a **temperament** from data
(a builder, a cautious state, a steadfast one, an aggressive one, an opportunist), chosen for its rulers in 1480. The AI keeps
no memory of its own: it decides from the saved game, its country's knowledge and the AI's own luck, so a game is the same from
its seed and its actions, and a save made at any season plays on to the same game. A headless **soak** plays 100 AI-only games
of 80 seasons every night and checks the game's invariants every season.

**When it starts.** After M7 is closed (its plan's definition of done, and the owner has played it). M8 edits `Game`, the
season table, `Replay`, `Snapshot`, `SaveFile`, `ScenarioDef`, `GameDefs`, `Countries`, `Military`, `Sieges`, `Movement`, `Knowledge`, `OddsView`, the
report's view, the log lines, the reminders, the replay's plan, `Session`, the season flow, the map input, the decision queue,
the HUD, the console, F3, the App and the lint, and adds the `core/ai/` layer, the AI's data and the soak tool.

**M8 is done when:**

1. **Every country plays.** On "Italy, 1480", seed 1480, in an AI-only game (`Game.watch`): every one of the 13 countries raises
   at least one company by the end of Summer 1480, and each of the 10 countries with 12 districts or more (all but Mantua, Siena
   and Lucca) begins at least one work by the end of Winter 1481 (`tests/core/test_ai_play.gd`).
2. **Through the same doors.** In 12 AI-only seasons every AI act passes its check first, carries its own country's tag and
   succeeds, and no check changes `Game.digest()` (`AiJudge`, `tests/core/test_ai_judge.gd`); the action log of 40 AI-only
   seasons, replayed with no AI, gives the same digest (`test_ai_determinism.gd`); the `ai_orders` phase changes only what its
   logged acts change (`test_owns.gd`). M8 adds no action and changes no game rule: the AI plays by M2 to M7's.
3. **No omniscience.** `tests/core/test_ai_fog.gd`: a country's whole turn (its acts, in order, and its luck state after) is
   the same when the facts it may not know are changed (armies of others it does not see moved and re-ordered, unseen
   garrisons, others' stores, works and standing orders, the world's luck); a planted cheat that reads an unseen garrison is
   caught.
4. **Determinism.** Same seed, same game: two AI-only runs of 40 seasons give equal digests and equal action logs; a turn cut
   into slices of one step gives the digest of the turn run at once; a save after season 10, loaded and played to season 20,
   gives the digest of the game played straight (`test_ai_determinism.gd`).
5. **The AI fights and ends its wars.** In the nightly soak of 100 AI-only games of 80 seasons: at least 80 games see a war
   declared; at least half of the wars that ended were ended by a peace an AI made (take, white or yield), not by the
   40-season timer; and a scripted duel (Milan's AI against a passive Genoa) declares, takes land and makes a take peace
   within 40 seasons (`tests/core/test_ai_owner.gd`).
6. **The owner loses a war.** The duel of item 5 passes; in the nightly passive suite (20 games of 80 seasons, a passive seat
   standing for the owner, the seat rotating over the 10 playable countries) a war is declared on the seat in at least 15
   games and the seat loses a war (a take peace against it moving at least one district) in at least 5; and the owner, playing
   the checklist of the plan, loses a war at least once.
7. **The soak.** `godot/tools/soak.gd`, nightly: 100 AI-only games of 80 seasons on north Italy end with no crash (no script
   error, no engine error), no broken invariant (section 4.17) and no broken check contract, and every expected range of 4.17
   holds.
8. **Time.** In the nightly `perf_core.gd`: an AI season on north Italy (12 seats) under 200 ms; on the made-up Europe (60
   countries, 600 armies, 30 wars) under 3,000 ms mean; no AI step over 8 ms; and in the windowed `perf_ui.gd` on north Italy
   no frame over 16 ms while the AI runs, the whole AI turn under 1 s from End season to the phases (section 8).
9. Every M8 UI row of the standard's 9.1 is in the game, built from the M1.5 kit, each with its GUT test: the AI-turn pill
   ("Countries are moving 3 / 12", "The season ends", the replay's line); the map taking only camera moves while the countries
   move and while the replay plays; the AI's moves in the replay, timed only where you look; what others did in the report
   (one line per country), the log (others capped) and the notifications (others' raises only near you); the peace alert in
   `DECISIONS`; the `peace_risk` reminder; the console's `ai`, `watch` commands and the F3 line. No stand-in is left.
10. Lint, import, check_scripts and GUT are green, with both UI `--check`s, `build_map --check` and `build_scenario.gd
    --check`; the art director has signed the pictures of section 9; the owner has played the build through the plan's
    checklist.

---

## 1. What is there, and where this page refines earlier pages

### 1.1 Read in the code (master `846c87f`), the specs and v0.2.2

| Finding | Where | What it means for M8 |
|---|---|---|
| `core/ai/` holds only `.gitkeep` | `godot/core/ai/` | Every AI file is new |
| The lint ranks `ai/` 5 and `views/` 6, and checks only `res://` paths (class names are not followed) | `tools/lint_godot.py` `CORE_RANK` | With `ai` below `views` the AI could not read `Knowledge`, `ImprovePreview`, `EconomyPreview`, `OddsView`, `SiegeView`, `Reminders`, which every hand-off of M3 to M7 names as the AI's inputs: the order is swapped (D2) |
| `Rng`: `seed_with`, `randi_range`, `randf`, `get_state`, `set_state`; M3's `Luck` holds `world`, `ai`, `decor` streams | `core/rng.gd`; `m3-build-spec.md` 5.2 | The AI draws only `game.luck.ai`, by `randi_range` |
| `Actions.pair_of` is a `match`; `register_test_action` lets a test register a stub pair | `core/game/actions.gd` | M8 adds no action; the planted faults use test pairs |
| `Game.act` / `check` run the pair; from M3 `act` logs every accepted action and bumps `version` | `core/game/game.gd`, `m3-build-spec.md` 4.5 | The AI's acts are logged like the player's (D33) |
| `Session`: `new_game`, `new_scenario`, `check`, `act` (fills the player's tag), `drain`; from M3 `end_season` runs the phases in one call | `shell/autoload/session.gd`; `m3-build-spec.md` 5.5 | M8 cuts `end_season` into begin, steps and finish for the slices (5.6) |
| `MapInput.enabled`; `MapScene.set_input_enabled`; the camera rig's own `enabled`; `MapScene._hexes_on_screen()` is private | `shell/input/map_input.gd`, `shell/map/map_scene.gd` | M8 adds a "camera only" block to `MapInput` and a public `view_hexes()` |
| No pill exists in `shell/`; the mockup's pill is a `card` at the top centre, 48 px down ("Changing season 40 %") | `godot/shell/`, `docs/design/ui/studiolo/hexa-ui-mockup.html` 114 | `BusyPill` is new, in that place and look |
| CI greps tool logs for `SCRIPT ERROR\|Parse Error` (`perf_ui` step) | `.github/workflows/godot.yml` | The soak uses the same net under its own error counter (section 10) |
| M3 D22: "M8 owns the action log's size: if the save passes 8 MB, keep the log from the last autosave"; D48: Save refused while the flow runs, "the rule for M8's sliced AI" | `m3-build-spec.md` 2 | Settled in D5 and D33 |
| M3 4.2: `Season.end_check` refuses "choose your country first" when a game with countries has no player | `m3-build-spec.md` 4.2 | AI-only games need `Game.ai_only` (D31) |
| M3 4.9: "Your orders" are read from the action log of the turn | `m3-build-spec.md` 4.9 | With the AI's acts in the log they must be filtered by the viewer's tag (1.2) |
| M6 D35: no starting armies, "M8 seeds armies with the AI"; M6 12: `ScenarioDef.start_armies` arrives with M8 | `m6-build-spec.md` | D30 |
| M6 8: `route_ms` 2 mean, 8 worst; `cost_field_ms` 120 ("M8's march") | `m6-build-spec.md` 8 | A step holds at most one route; `cost_field` is too slow for a slice and is not used (D48) |
| M7 D30: the passive enemy accepts a peace by v0.2.2's rule inside `make_peace_check` | `m7-build-spec.md` 4.9 | That rule is the loser's acceptance, whoever makes the peace (D27, D28) |
| M7 `Sieges.forecast(game, hex, tag, men, guns, progress, seasons)` reads the real garrison; M7 4.15: an unseen garrison is only "a garrison" | `m7-build-spec.md` 5.3, 4.15 | A forecast for an unseen fortress would leak its garrison: `forecast_for` and `Knowledge.garrison_estimate` (D49) |
| v0.2.2's AI: one country at a time in turn order; tax high in distress, low over 600 ducats; builds by gain over cost; an army goal of people / 300; stacks campaign (shaken home, join, relieve, storm at half, attack at 1.1, besiege the nearest place that falls in 4 seasons, open land with claims); declares on a neighbour 1.8 times weaker, a 12 % chance every 8 seasons, at most 3 wars; a memory dict per country; "AIs know only the map they have explored" but `army_strength` read exactly | `hexa/campaign/ai.py`, `data.py` 404 to 500 | Section 3 |
| v0.2.2's soak: suites, invariants every turn, known open bugs, a replay line per failure, a summary table to `$GITHUB_STEP_SUMMARY`; the `Judge` of `tests/support/agents.py` | `tools/soak.py`, `tests/support/invariants.py`, `tests/support/agents.py` | `soak.gd`, `Invariants`, `AiJudge` (4.17, 9) |
| Built by M1.5 to M7 and named "(M2)" to "(M7)" below: `Territory`, `Countries`, `Works`, `Calendar`, `Season`, `Stats`, `StatsSystem`, `Chronicle`, `Luck`, `ViewCache`, `Snapshot`, `SaveFile`, `Replay`, `Knowledge`, `Words`, `LogLines`, `Reminders`, `SeasonSummary`, `Economy`, `EconomySeason`, `Treasury`, `Stores`, `EconomyPreview`, `ImprovePreview`, `People`, `UnitDef`, `Army`, `Unit`, `Armies`, `Military`, `Movement`, `PathSearch`, `Supply`, `Vision`, `ArmyView`, `MovePreview`, `ReplayPlan`, `MoveReplay`, `Wars`, `War`, `Occupation`, `Battles`, `Sieges`, `OddsView`, `SiegeView`, `BattleView`, `SeasonFlow`, `DecisionQueue`, `GameRequests`, `DevCommands`, `PerfFixture`, `perf_core.gd`, `RandomPlayer`, `WarFixture`, `FakeScenario` | their specs | M8 starts after they exist |

### 1.2 Refinements (decided here)

| Earlier page | M8 | Why |
|---|---|---|
| Standard 2 and 7, `CLAUDE.md`, `godot/README.md`: layers bottom to top `defs, state, systems, game, ai, views, shell` | **`defs, state, systems, game, views, ai, shell`**: the AI may read views; views never read the AI (D2) | The standard's own 5.6 ("the same queries as the panels") and every hand-off of M3 to M7 make views the AI's inputs; nothing in `views` needs the AI |
| M3 4.2 and every later season table: row 1 `ai_orders`, "through `Game.act` only" | `ai_orders` joins `PHASES` first; `Season` (game layer) runs it through an **orders hook** (`OrdersHook`, a game-layer class the AI subclasses), so `game` never names `ai`; the shell runs the same hook in slices (4.2) | One table runs the season; the layers point down |
| M3 6.3: `RUNNING` runs `Session.end_season()` in one call | `RUNNING` begins the season, steps the AI a slice a frame, then finishes the season in one call (5.6, 6.3) | The frame stays under budget while the AI thinks |
| M3 D22: keep the log from the last autosave | The AI's acts are logged; a save keeps **the last 40 seasons** of the log (`log_from`); in memory the log is whole (D33) | A bounded save whatever the autosave setting; the replay test runs in memory |
| M3 4.9: "Your orders" from the action log of the turn | From the records whose `args.tag` is the viewer (D38) | The AI's acts share the log |
| M3 4.2: "choose your country first" for a game with countries and no player | Unless `Game.ai_only` (D31) | AI-only games for the soak, the tests and the developer's Watch |
| M3 4.5: `Replay.run` plays `end_season` through `Season.run` | It plays the AI's records of that season through a `LogOrders` hook, up to the season's `orders_done` mark (D33) | A logged game replays without the AI |
| M3 D48: Save refused while `RUNNING` | Also every player action, the quickload, the report key and the console's acting commands while the season runs (D40) | A player act between two AI steps would break the replay's order |
| M6 6.4: in `REPLAY` "a click on the map pans and zooms but neither selects nor orders" | The mechanism is `MapInput.block_orders(reason)`, used in `RUNNING` and `REPLAY` (D36) | One rule, one place |
| M6 D42: the replay times every seen step | A seen step is timed only when one of its hexes is in view (the camera's hexes grown by 2) at the replay's start; other seen steps are instant (D37) | Twelve countries' walks fit the 6 s cap |
| M6 D35, M6 12: `ScenarioDef.start_armies` arrives with M8 | The field arrives; **1480 has none** (D30) | Every pinned M4 to M7 number holds; every AI raises in its first season |
| M6 4.11: others' `army_raised` notifies | Only when the raiser is at war with the viewer or the hex is within 2 of the viewer's land (D39) | Twelve AIs raising every season would fill the four cards |
| M6 12, M8 row: the AI reads `PathSearch.cost_field` | Not used: one field is 120 ms on Europe, over a slice; the AI uses `Movement.plan`, one route a step (D48) | The step bound |
| M7 5.3: `Sieges.forecast` | Gains `forecast_for(..., garrison, ...)`; `OddsView` and the AI pass `Knowledge.garrison_estimate` (own exact, seen rounded to 100, unseen full) (D49) | The odds card and the AI must not read an unseen garrison |
| M7 D30, D44: the passive enemy accepts by the check; the war alert in `DECISIONS` | The same check is the acceptance when an AI makes peace with the player; the player hears it as a **peace alert** in `DECISIONS` and is warned by `peace_risk` (D28) | "The same actions, the same checks"; the owner must be able to lose a war |
| M7 6.6: "M8's AI never at idle" | Confirmed: the AI acts only in `ai_orders` | |
| M7 4.2: a war opens both lands at once | Unchanged; the **AI** gives no order into a country it declared war on in the same turn (D23) | The player hears of it only after the season; the AI defender already gets a turn before the movement |
| M4.5 12, M8 row: the AI fills the chronicle | `Chronicle.KEEP` stays 3,000; the soak measures the seasons it covers and doubles it when the median falls under 24 (D51) | Measured, not guessed |
| `ui-and-controls-plan.md` 4, M8: `shell/hud/busy_pill.*` | Kept; the pill also names the season's end and the replay (D35) | One pill for the season's busy states |
| M4 to M7 12, M8 rows: the views offered to the AI | Used: `EconomyPreview` (net, taxes), `ImprovePreview.of` (the works card), `Reminders` (`hunger`, `goods_running_out`, `town_full`), `Military.raise_options` and `men_at_hand`, `Supply.is_depot`, `Movement.plan` (inside the `march` check), `OddsView.of`, `SiegeView.at`, `Occupation.area_state`, `Wars.score`, `Wars.of_country`, `Knowledge` (`knows`, `men_of`, `armies_seen`, `garrison_estimate`). Not used: `PeopleView`, `StudyPeople`, `MapModes.food_bytes` (the reminders carry the need), `ArmyView`, `MovePreview`, `SupplyView` (the AI reads its own armies), `BattleView` (battles are over before the AI's turn), `PathSearch.cost_field` (D48), `cancel_work`, `continue_march`, `split_army` (D10) | One reading of each need; nothing the step bound cannot afford |

---

## 2. Decisions taken

Each is decided. "Reverse" is the cost to change it later (S half a day, M a day, L two or three days). Data changes are a
`.tres` edit plus the test that pins the value.

| # | Question | Decision | Why | Reverse |
|---|---|---|---|---|
| D1 | Where the AI runs | In the season's first phase, **`ai_orders`**, before `movement`; every AI country acts there and nowhere else | The standard's row 1; orders given before the walks, as the player's | S |
| D2 | The layers | `defs, state, systems, game, views, ai, shell` (1.2); `core/ai/` may use `views` and below | The AI reads what the panels read | S (lint and three lines) |
| D3 | How `Season` (game) runs the AI (ai) | Through **`Game.orders`**, an `OrdersHook` (core/game) that the AI's `AiTurn` extends; `Session`, the tools and the tests attach it; `Game.new_scenario` attaches none, so every M2 to M7 test plays passive countries as before | No upward reference; the passive world stays the default of every earlier test | M |
| D4 | The executor | **A step queue**, not a coroutine (`await` is forbidden in `core/`): `begin` lists the seats; each `step` does one bounded piece of one seat's turn (at most one route search or one works card); a step may add steps to its seat | Resumable between frames, the same result however it is cut | M |
| D5 | Saves during the AI's turn | **Atomic at the season boundary**: no save, load or player act while the season runs (D40); the queue is never saved; a quit loses the season in progress like any unsaved play | Nothing transient needs a format; M3 D48 already refuses saves while running | none |
| D6 | The AI's memory | **None of its own.** It decides from the saved game (its armies' orders and goals persist there), its knowledge (D7) and `Luck.ai` | A save needs nothing new; save, load, play on is the same game by construction | L (a saved memory) |
| D7 | What an AI may know | Its own country exactly; the map and every public fact (owners, occupiers, pieces, wars, truces, scores, war records); other countries only as `Knowledge` gives them to its country: totals banded and only when known, armies only on hexes it sees now and banded, battles and sieges by their views' access, garrisons by `garrison_estimate`; never others' stores, works, orders, routes or standing orders, never the world's luck (4.3) | The owner's rule: no cheat beyond the fog; the player's own rule | S per fact |
| D8 | The door | **`AiKnow`** (`core/ai/ai_know.gd`) is the only AI file that reads the game or acts; the others read only what it returns; a text test enforces it (`test_ai_door.gd`) | One place to audit; the fog test needs one door | S |
| D9 | Order and luck | Seats in id order, the first seat rotating by turn (`(turn − 1) mod n`); every list in id or hex-index order; the AI draws only `Luck.ai`, in step order; all numbers integers and permille | Same seed, same game (standard 5.4); no seat always moves first | S |
| D10 | Which actions | `set_tax`, `build`, `upgrade`, `raise`, `disband`, `merge_armies`, `march`, `halt`, `storm`, `set_standing`, `declare_war`, `make_peace`. Never `clear`, `cancel_work`, `continue_march` (it re-orders with `march`), `split_army`, `choose_country` | The smallest set that plays the game; every one through its check | S an action |
| D11 | The player's country | Never played by the AI; **treated as any other country** by every AI (no bonus, no malus, no ganging up) | The AI is a player | none |
| D12 | Outside powers | France, Austria and the Papal States are AI countries like the rest (their capital off the map; their posts at their most populous town) | The brief; their land is real on the map | none |
| D13 | Temperaments | **Five**, one `AiTemperDef` file each: `builder`, `cautious`, `steadfast`, `aggressive`, `opportunist` (4.4); a country's temperament is set **per scenario** (`ScenarioDef.tempers`) | The standard 4.1 names `AiTemperDef`; a ruler is of an era, a `CountryDef` is of every era | Data (S) |
| D14 | Who has which | Table 4.4: builder Genoa, Florence, Lucca; cautious Mantua, Siena; steadfast Savoy, Ferrara; aggressive the Swiss, Venice, Austria; opportunist Milan, France, the Papal States | The rulers of 1480 (4.4) | Data (S) |
| D15 | Numbers | Every AI number in `AiDef` (`data/defs/ai.tres`) or an `AiTemperDef`; none in code | Standard 4.1 and 5.6 ("any handicap is a number in a .tres") | Data (S) |
| D16 | Taxes | High in need (empty treasury; at war under the reserve; a falling treasury under twice it), Low when the money has no better use (no work it wants but cannot pay, twice the reserve, a surplus at Low, at peace, fed), Normal else (4.6) | v0.2.2's distress rule and "low when rich", tied to the AI's own spending | Data (S) |
| D17 | Works | Rank the seat's options by a **prior** from data (the year's goods at price less the wild yield and upkeep, over the cost); open the works card (`ImprovePreview.of`) for the best 4; begin the one with the shortest payback within the temperament's limit, at most 2 a season, keeping the reserve (4.7) | The card is exact but costly; the prior keeps four cards a seat | Data (S) |
| D18 | Priorities | Food works (wheat, harbour) count their payback a third when the seat's towns are hungry or food runs out within 2 seasons; a walled town or city a half when a town is full; a steadfast seat fortifies a threatened pass (4.7) | M5's hand-over: "it builds food when hungry and walls when full" | Data (S) |
| D19 | Raising | A goal of men from its people by temperament (more under threat or at war), capped by a share of its money left for armies, the first company always allowed; kinds by the temperament's mix, the most wanting first; at its settlements nearest the front (4.8) | v0.2.2's goal by people and mix by branch, re-fitted to 500-man companies | Data (S) |
| D20 | Armies at peace | Held at **posts**: one facing each threatening neighbour (its nearest depot to that border), and the capital; armies to posts in turn, largest first; armies on one hex merged (4.8) | v0.2.2 gathered at the capital; the front matters on a small map | S |
| D21 | Disbanding | One company a season when the treasury is below zero and even High taxes leave a deficit, or at peace with no threat and twice the goal (4.8) | v0.2.2's distress disband | Data (S) |
| D22 | Declaring war | Thought every 4 seasons per seat (staggered by id); only when its wars, rest since the last peace, war chest and army allow; a neighbour whose banded men it outnumbers by the temperament's ratio (less for an opportunist against a country already at war); the target with the best prize (its open land and walled towns near); then a roll against the temperament's chance (4.9) | v0.2.2's `_diplomacy` with knowledge instead of exact strength and with temperaments | Data (S) |
| D23 | Fair warning | In the season a seat declares a war, its armies take no order into that enemy's land; those with no other aim keep to their posts | The player hears of the war after the season; the AI defender already has its turn before the walks | S |
| D24 | Armies at war | Per army: a shaken army goes to the nearest depot; a besieger keeps its siege or storms it; otherwise the best of retake, relieve, attack, besiege, walk in and approach by score, keeping its march unless a new aim scores 30 % more (4.10) | v0.2.2's `_campaign` tiers, with scores and a hysteresis instead of a memory | Data (S) |
| D25 | Standing orders | Withdraw when a seen enemy army within 3 hexes outnumbers it by the temperament's ratio and it is not on its own fortress or besieging; else Hold (4.10) | M7 D41: the decision before contact; v0.2.2's withdraw ratio 0.6 | Data (S) |
| D26 | Storms | A besieger storms when the meter has reached the temperament's share of the need, after 2 seasons, at a storm odds ratio over the temperament's (4.10) | v0.2.2 `AI_STORM_SHARE` 0.5 | Data (S) |
| D27 | Peace | Each season per live war: take when the check allows and the score reaches the temperament's, or when tired with any lead; white when tired, outnumbered or broke and not ahead; yield when far behind for long and heavily outnumbered (4.11). **Accepting** a peace is M7's rule inside `make_peace_check`, the same for every country; temperaments change it from M9 | M7's simple peace, with the AI as the one who offers; M9 owns offers and answers | Data (S) |
| D28 | A peace on the player | An AI may make peace with the player through the same check (it stands for the loser's acceptance, as when the player makes it); the player gets a **peace alert** in `DECISIONS`, and the reminder **`peace_risk`** warns when an enemy holds enough of the player's land to impose one | Same actions, same checks; the owner can lose a war and sees it coming | S (a data flag that spares the player, if the playtest asks) |
| D29 | Difficulty | **None in M8**; one AI for everyone. A difficulty would be an `AiDef` scale chosen on the New game page (M12) | Measure the plain AI first | M |
| D30 | Starting armies | `ScenarioDef.start_armies` (a list of `{tag, hex, kind, count}`) exists; **1480's is empty**; every AI raises its first company in its first season | M4 to M7's pinned numbers hold; a Europe scenario may fill it | Data (S) |
| D31 | AI-only games | `Game.ai_only` (saved, in the digest), set by `Game.watch()` during the pick (logged): every living country is an AI and End season needs no player; the viewer is `&""` (sees all) | The soak, the tests, and the developer's Watch | S |
| D32 | Passive seats | `AiTurn.passive` (a list of tags the AI does not play): the developer's `ai pass TAG` and `ai off`, and the tests; not saved | The duel test, the playtest's passive enemy | S |
| D33 | The action log | Every AI act is logged by `Game.act`; the `ai_orders` phase ends with a mark `{turn, action: "orders_done"}`; `Replay` plays a season's AI records through `LogOrders`; a save keeps the last 40 seasons of records (`log_from`), memory keeps all | A logged game replays without the AI; a save stays small on Europe | S |
| D34 | Saves | `SaveFile.FORMAT` **6**, `OLDEST_FORMAT` 6: the digest gains `ai_only` and the scenario digest gains `tempers`, so an M7 save reads "Made by an older test build" | M3 D31 | S |
| D35 | The pill | `BusyPill` at the top centre under the bar: "Countries are moving 3 / 12" while the AI thinks, "The season ends" for the phases, "The moves of Summer 1480 · Space skips them" in the replay; hidden otherwise | UI plan M8 row; the mockup's pill | S |
| D36 | The map while the countries move | **Camera only**: pan, zoom, fit, bookmarks, place search, map modes and the hover card work; select, orders, works, the hex menu, J, B, Ctrl+Z, F5 and F9 do not (a toast says why, at most once a second); the pause menu opens (the AI goes on under it; Save is refused) | UI spec 2: "input on the map blocked except the camera" | S |
| D37 | The AI's moves replayed | M6's replay plays every seen walk, the AI's included; a seen step is **timed only in view** (1.2, 6.3); unseen steps stay instant, fully unseen walks unrecorded (M6) | The cap of 6 s with twelve countries walking | S |
| D38 | What others did, in the report | "What befell" gives **one line per other country** for its witnessed doings (works, raises, disbands, taxes, towns), ranked by how much it did; wars, peaces, battles, sieges and captures keep their own lines and rank above; "Your orders" lists only the viewer's records | Twelve AIs would bury the six lines shown | S |
| D39 | The log and notifications | Per season the viewer's lines first and at most 24 of others', then "and 31 more about other countries"; others' raises notify only near you or from an enemy | Readable with twelve AIs | S |
| D40 | Acting while the season runs | `Session.check` and `act` refuse with "wait for the season to end" between `begin_season` and `finish_season` | The log's order and the replay depend on it | none |
| D41 | The soak | `godot/tools/soak.gd`: suites `ai` (100 games × 80 seasons), `passive` (20 × 80), `europe` (4 × 40 on the made-up Europe); invariants every season; a failed game prints the line that replays it; nightly in four shards plus the two suites; a quick GUT soak on every pull request (4.17) | v0.2.2's soak; the standard 6: "soak from M8" | S |
| D42 | "The owner loses a war" | Measured three ways: the duel test (GUT), the passive suite's rates (nightly), the owner's checklist (D41, done-when 6) | A statistical rate cannot be one GUT test; a single scripted duel can | none |
| D43 | Speed | Budget rows of section 8 (`perf_core`, `perf_ui`); a step is at most one route or one card | The standard 5.6: "a time budget per season that the performance test checks" | Data (S) |
| D44 | Europe (E3) | M8 builds the measurement (`perf_core.gd --ai-map=... --ai-scenario=...`) and writes the switch criteria (8.3); the switch itself is the owner's later decision (standard 9) | The brief; E2's map file may not exist yet | none |
| D45 | Developer tools | Console `ai TAG` (the seat's last turn), `ai off`, `ai on`, `ai pass TAG`, `ai play TAG`, `watch`; an F3 line | Tuning and the playtest need to see why | S |
| D46 | The trace | `AiTrace`: a few lines per seat per turn (what it chose and why, its rolls), kept until the next turn, never saved, never in the digest | Read by the console and the soak's report only | S |
| D47 | Earlier shell tests | `tests/shell/ui_harness.gd` turns the AI off (`Session.ai_enabled = false`); M8's shell tests turn it on | M3 to M7's end-to-end tests pin a passive world | S |
| D48 | `cost_field` | Not used by the AI (1.2) | A slice holds one route | S |
| D49 | Garrisons the AI cannot see | `Knowledge.garrison_estimate`: own exact; seen rounded to 100; unseen the full garrison of its level; `Sieges.forecast_for` takes it; `OddsView` uses both | Closes the leak for the player's odds card too | S |
| D50 | Routes planned twice | `Movement.plan` is cached in `game.view_cache` by version, army, goal and winter, so a check and its act search once | The AI's hot path (`route_ms`) | S |
| D51 | The chronicle's size | `Chronicle.KEEP` 3,000 kept; if the soak's median coverage at season 80 falls under 24 seasons, it becomes 6,000 in the tuning task with `save_mb` measured | The history page and the log read it | Data-free (S) |
| D52 | The seat order | Rotating start (D9) | A fixed first mover would always see least | S |

---

## 3. The v0.2.2 reference

| v0.2.2 | Where | Kept | Changed for the district map, and why |
|---|---|---|---|
| `ai.run(world, tag)` once a season per non-player country in turn order, inside `GameManager.end_season` before `end_round` | `campaign/ai.py` 29, `game.py` | One country at a time, before the season's rules; money before armies | A phase with a hook (D1, D3); sliced (D4); rotating first seat (D9) |
| `_distressed`: in debt, or a deficit 2 seasons running: high taxes, no new spending, disband | `ai.py` 57 to 79 | The idea | Stateless: High when the treasury is under zero or the season falls short under twice the reserve; disband when even High is short (D16, D21) |
| Taxes: high in distress, low over 600 ducats, else normal | `ai.py` 37 | Three levels by need | The reserve is seasons of upkeep by temperament; Low only when no wanted work is short of money (D16) |
| `_build`: reserve `80 + 3 × balance`; the best `gain / cost` of the 14 most populous provinces; `_invest` the fastest payback | `ai.py` 227 to 270 | Rank by gain over cost; keep a reserve | The prior from data and the works card's payback (D17); food and walls priorities (D18) |
| `_army`: goal `max(2, pop / 300 × 1.4 at war)`; raise when the treasury is over 70 and the balance positive; mix: cavalry under 30 %, artillery under 15 % from 4 troops; at the capital or the most populous town | `ai.py` 273 to 315 | A goal from people, more at war; a mix by branch | Per-mille goals by temperament, an upkeep share cap, the front's towns first (D19) |
| `_gather`: idle stacks walk to the capital | `ai.py` 317 | Idle armies go home | Posts facing threats (D20) |
| `_campaign`: shaken home; join a battle; keep a siege, storm at half the need after 2 seasons; relieve own castles (gather at a rally hex, attack at 0.8 of the besiegers, or 0.6 when it falls next season, give up after 2 seasons); attack at power × morale 1.1 times the defence; besiege the nearest place that falls in 4 seasons (6 with guns), own land first; open land with claims so stacks fan out | `ai.py` 402 to 637, `data.py` 404 to 500 | All of it, as starting values in permille: attack 1,100, storm share 500, relief 800 and 600, siege 4 and 6 seasons | Battles never outlive their phase (M7), so no join; the relief's wait is read from the siege (stateless); scores with a hysteresis (D24) |
| `_battles`, `_stance`: Withdraw under 0.6 of the enemy's strength, Attack over 1.2, else Hold | `ai.py` 352 to 391 | The decision by strength | Standing orders before contact (M7 D41): Withdraw when outnumbered by the temperament's ratio (D25) |
| `_diplomacy`: every 8 seasons by a seed, a 12 % chance, a neighbour 1.8 times weaker, at most 3 wars, 100 ducats | `ai.py` 640 | A rare, staggered thought; a weaker neighbour | Every 4 seasons; temperament ratios and chances; banded knowledge; the prize (D22) |
| Peace by `war_timeouts` (16 seasons between AIs, score 5) | `systems/season.py` 34 | Wars end | The AI makes peace by M7's terms (D27); the 40-season timer stays M7's |
| `country.memory` (claims, relief, deficit, distress, seed) | `ai.py` | | No memory (D6): claims last one turn, the relief reads the siege |
| "AI countries know only the map they have explored", yet `army_strength` of neighbours is read exactly | `ai.py` docstring, 88, 646 | The intent | Kept strictly: `Knowledge` only (D7) |
| Research, ideas, merchants, ships, colonies | `ai.py` 110 to 200, 654 on | | M10, M11, after M12 (section 12) |
| `tools/soak.py`: all-AI games, invariants after every turn, a failure ends the game and prints its replay line, a summary table | `tools/soak.py` | All of it | GDScript, headless; an error counter for script errors (4.17) |
| `tests/support/agents.py` `Judge`: a refused check must change nothing, an allowed one must succeed | `tests/support/agents.py` 29 | The contract | `AiJudge` on every AI act (9) |

---

## 4. Design content

### 4.1 The model in one picture

```
 End season (the flow's RUNNING)
   Session.begin_season     end_check; Season.begin (the end_season record); Season.orders_begin -> AiTurn.begin: the seats
   every frame              Session.step_orders(5 or 10 ms): AiTurn.step, one bounded step at a time, then drain
     a seat's turn          brief -> peace -> war -> works scan (2) -> works cards (up to 4) -> works -> forces
                            -> one step per army (order, standing) -> tax -> done        (acts through AiKnow.act only)
   Session.finish_season    Season.orders_end (the orders_done record); movement ... vision as M7; season_ended
 then REPLAY (the walks you saw, timed in view), DECISIONS (war and peace alerts), REPORT
 the pill: "Countries are moving 3 / 12" -> "The season ends" -> "The moves of Summer 1480 · Space skips them"
```

### 4.2 Where the AI runs: the phase, the hook, the slices

**The table.** `Season.PHASES` after M8: **`ai_orders`, `movement`, `battles`, `supply`, `sieges`, `war`, `production`,
`income`, `works`, `people`, `stats`, `calendar`, `ready_units`, `vision`** (14; `test_season.gd` pins it).

**The hook.** `Game.orders` holds an `OrdersHook` or null. `Season` drives it in three calls, which the atomic and the sliced
paths share:

| Call | Does |
|---|---|
| `Season.orders_begin(game)` | `game.orders.begin(game)` when a hook is attached |
| `Season.orders_step(game) -> bool` | one `game.orders.step(game)`; true when the turn is over (always true with no hook) |
| `Season.orders_end(game)` | appends `{turn, action: "orders_done", args: {}}` to the action log (every game, every season) |
| `Season.run_phase(game, &"ai_orders")` | `orders_begin`, `orders_step` until true, `orders_end` (tools, tests, the replay) |

`Session` runs the same three calls, the steps in slices (5.6). An attached hook is not state: it is not saved, not in the
digest, and set again when a game starts or loads (`Session.start_game`, the tools and tests). `Game.new_scenario` attaches
none.

**The steps.** `AiTurn.begin` makes the seat list (4.12) and resets the trace. A seat's turn is a list of steps, made when its
first step runs; a step may append steps for the same seat:

| # | Step | Does | Bound |
|---|---|---|---|
| 1 | `brief` | builds the seat's `AiBrief` from `AiKnow` (4.5) | one pass over its land and the hexes it sees |
| 2 | `peace` | per live war, 4.11 | the checks of its wars |
| 3 | `war` | on a think turn, 4.9 | one check per neighbour |
| 4 | `works_scan` ×2 | the prior of 24 candidate hexes each (48 a season) | `Improve.build_options` and the static upgrade rules |
| 5 | `works_card` ×k | one `ImprovePreview.of` for one of the best `works_cards` (4) | one card |
| 6 | `works_act` | begins up to 2 works (4.7) | the chosen cards' acts |
| 7 | `forces` | raises, disbands, merges (4.8); appends one `army` step per army of the seat, id order | the raise options of its settlements |
| 8 | `army` ×n | one army: at war its standing order and its aim (4.10, `AiWar.war_army`), at peace Hold and its post (4.8, `AiForces.peace_army`); a refused march appends one more `army` step for the next aim, at most `order_tries` (2) a season | one route (a `march` or `storm` check and its act share one plan, D50) |
| 9 | `tax` | 4.6 | up to three one-season previews |
| 10 | `done` | the seat counts as done | |

**The slices** (the shell; 5.6, 6.3). Each frame the flow calls `Session.step_orders(budget)`, which runs steps while the time
since its start is under the budget and drains after every step: `AI_SLICE_MS` 5 ms while the camera moved in the last 500 ms,
`AI_SLICE_IDLE_MS` 10 ms otherwise. A step always finishes once started; a step costs at most one route (`route_ms` 8 ms worst
on Europe, M6) or one works card (2 ms, M4). The result does not depend on where the slices fall: nothing but the AI's own acts
changes the game while it runs (D40), every step is a pure function of the game and `Luck.ai`, and the queue's order is fixed.

### 4.3 What an AI may know (the fog rule)

For the AI of country `t` (and the same for the player, through the same views):

| Fact | `t`'s AI knows | Through |
|---|---|---|
| Its own country: treasury, ledgers, stores, works, people, armies (units, men, morale, orders, goals, routes), sieges it lays, its fortresses' garrisons, its stats, its reminders | everything, exact | the systems and its own views (`EconomyPreview`, `ImprovePreview`, `Reminders`, `Military.raise_options`, `Supply.is_depot`, `SiegeView`) |
| The fixed map | everything | `MapData` |
| Owners, occupiers, pieces (main use, level), fortresses and their levels, castle areas and their states | everything (drawn on everyone's map) | `Territory`, `Occupation.area_state`, `Improve.piece_at` |
| Wars, peaces, truces, war scores, war records | everything (public, M7 D49) | `Wars` |
| Another country's land, income, people, men under arms | only when `Knowledge.knows(t, other)`, banded (two figures), last season's values | `Knowledge.men_of`, `Knowledge.band` of `Stats` |
| Another country's armies | only those on hexes `t` sees now, their men banded; no kind, no order, no route, no standing order | `Knowledge.armies_seen` |
| Battles | the records `t` witnessed, at their access | `BattleView` |
| Sieges | as a side exact; else while it sees the hex | `SiegeView.at` |
| A fortress's garrison | own exact; seen: rounded to 100; unseen: the full garrison of its level (400 × level) | `Knowledge.garrison_estimate` (D49) |
| The odds of an attack or storm | the odds card's numbers | `OddsView.of` |
| Others' stores, treasuries beyond the band, works under way, orders, routes, standing orders, the world's luck | nothing | |
| Whether a hex holds another country's army it cannot see | only what a refused check says, exactly as the player hears it ("another country's army stands at ...") | `game.check` |

The last row is the player's rule too: a check's refusal is public knowledge to whoever asks.

**The door.** Every read of the game and every act in `core/ai/` is a function of `AiKnow`; the other AI files read only
what `AiKnow` returns, the definitions (`game.defs`, the seat's `AiTemperDef`) and plain values. `test_ai_door.gd`
scans `core/ai/*.gd` and fails on any of these tokens outside `ai_know.gd`: `.act(`, `.check(`, `game.state`, `game.armies`,
`game.countries`, `game.wars`, `game.sieges`, `game.battles`, `game.battle_records`, `game.luck`, `game.stats`,
`game.chronicle`, `Armies.`, `Stats.`, `Sieges.`, `Occupation.`, `Treasury.`, `Stores.`, `People.`, `Wars.men_under_arms`; and
on `game.player` outside `ai_turn.gd` (which skips the player's seat).

### 4.4 The temperaments (data) and who has which

`data/defs/tempers/<key>.tres` (`AiTemperDef`, 5.1). All ratios and shares in permille, all spans in seasons.
`godot/tools/ai_tables.gd` prints this table from the files.

| Field | What it sets | builder | cautious | steadfast | aggressive | opportunist |
|---|---|---|---|---|---|---|
| `reserve_seasons` | money kept back: seasons of upkeep (4.6) | 6 | 12 | 8 | 4 | 6 |
| `payback_max` | the longest payback it begins (4.7) | 40 | 28 | 32 | 20 | 28 |
| `works_at_war` | begins works while at war (food always) | yes | yes | yes | no | no |
| `army_permille` | men kept at peace, per 1,000 people | 3 | 5 | 6 | 9 | 6 |
| `war_army_permille` | the same at war or under threat | 8 | 10 | 14 | 18 | 14 |
| `army_upkeep_share` | of the money left before armies, the most its armies may cost | 200 | 250 | 350 | 500 | 400 |
| `mix` (pikemen, crossbowmen, knights, bombards) | the companies it wants, permille | 600, 400, 0, 0 | 550, 350, 100, 0 | 500, 400, 50, 50 | 600, 150, 200, 50 | 500, 250, 200, 50 |
| `max_wars` | live wars at once | 1 | 1 | 1 | 2 | 2 |
| `rest_seasons` | after a peace, before it declares again | 16 | 16 | 12 | 6 | 8 |
| `war_chest_seasons` | treasury it needs to declare: seasons of upkeep | 12 | 12 | 10 | 6 | 8 |
| `declare_ratio` | its men over the target's (banded), at least | 2,500 | 2,000 | 2,000 | 1,200 | 1,500 |
| `busy_bonus` | taken off the ratio when the target is at war with another | 0 | 0 | 0 | 0 | 400 |
| `declare_chance` | the roll (of 1,000) that lets it declare | 100 | 150 | 100 | 600 | 450 |
| `attack_ratio` | the odds ratio over the ground factor to attack an army | 1,500 | 1,600 | 1,300 | 1,100 | 1,300 |
| `siege_max` | the longest forecast siege it lays (+2 with bombards) | 4 | 4 | 5 | 6 | 4 |
| `storm_share` | the meter's share of the need before it storms | 600 | 700 | 500 | 400 | 500 |
| `storm_ratio` | the storm odds ratio it needs | 1,300 | 1,500 | 1,200 | 1,000 | 1,200 |
| `relief_ratio` | its force over the besiegers' to relieve a fortress | 900 | 1,000 | 700 | 800 | 900 |
| `withdraw_ratio` | a seen enemy over its men above which it stands on Withdraw | 1,100 | 1,000 | 1,500 | 1,800 | 1,300 |
| `take_score` | the war score at which it takes what it holds | 2 | 2 | 3 | 4 | 3 |
| `tired_seasons` | the war's age at which it takes any lead or sues | 8 | 8 | 16 | 24 | 12 |
| `sue_ratio` | the enemy's men over its own above which it sues | 1,300 | 1,200 | 2,000 | 2,500 | 1,500 |
| `yield_after` | the war's age from which it may yield when far behind | 8 | 6 | 16 | 20 | 10 |
| `fortify` | builds and raises castles at threatened passes | no | no | yes | no | no |

Read: a builder grows and keeps a small army, fights only the much weaker, and sues early; a cautious state hoards, defends
and sues earliest; a steadfast one fortifies its passes, holds its ground and does not give up; an aggressive one spends on
its army, declares on near-equals and fights long; an opportunist pounces on the weak and on those busy elsewhere.

**Who has which** (`data/scenarios/north_italy_1480.tres` `tempers`, in the scenario's country order):

| Id | Tag | Temperament | Why, in 1480 |
|---|---|---|---|
| 1 | FRA | opportunist | Louis XI, the "universal spider", who gathered lands by craft; his son's claims on Milan and Naples began the Italian Wars in 1494 |
| 2 | AUS | aggressive | Sigismund of Tyrol, who marched on Venice in 1487 (the War of Rovereto) |
| 3 | SWI | aggressive | fresh from the Burgundian Wars and the victory over Milan at Giornico (1478); the Ticino valleys to win |
| 4 | SAV | steadfast | a child duke, Philibert I, under French influence; a house that kept its passes |
| 5 | MLO | opportunist | Ludovico Sforza, who seized the regency in 1480: the master of shifting leagues |
| 6 | VEN | aggressive | the Serenissima's mainland empire; the War of Ferrara (1482 to 1484) to win the Polesine |
| 7 | GEN | builder | the bank of San Giorgio and its harbours, between Milan and France |
| 8 | TUS | builder | Lorenzo de' Medici, "the needle of the Italian scales": banking and balance |
| 9 | PAP | opportunist | Sixtus IV: the Pazzi conspiracy (1478) and the War of Ferrara for his nephew |
| 10 | MAN | cautious | the Gonzaga, condottieri for hire between Milan and Venice |
| 11 | FER | steadfast | Ercole d'Este, who held out against Venice in 1482 to 1484 |
| 12 | SIE | cautious | a hill republic watched by Florence |
| 13 | LUC | builder | the silk republic that "must stay friends with everyone" (M2's tip) |

The made-up scenario of the perf runs (`FakeScenario`, M2) gives country `id` the temperament `[builder, cautious,
steadfast, aggressive, opportunist][id mod 5]`.

**`AiDef`** (`data/defs/ai.tres`, one file, every number the temperaments share):

| Field | Value | Used in |
|---|---|---|
| `think_every` | 4 | a seat thinks of war when `(turn + id) mod 4 == 0` (4.9) |
| `min_upkeep` | 10 | the floor of the upkeep in the reserve (4.6) |
| `min_army_men` | 500 | the smallest goal of men; the first company is always allowed (4.8) |
| `min_war_men` | 1,000 | the men a seat needs to declare (4.9) |
| `threat_permille` | 1,500 | a neighbour is a threat when its banded men exceed this share of the seat's (4.5) |
| `threat_range` | 3 | hexes within which a seen enemy army sets the standing order (4.10) |
| `prize_range` | 3 | hexes from the seat's land within which a target's land counts as prize (4.9) |
| `attack_range`, `relief_range`, `target_range` | 6, 8, 12 | hexes within which an army weighs attacks, reliefs, sieges and walk-ins (4.10) |
| `relief_last` | 600 | the force share at which it still relieves a fortress that falls next season |
| `rest_morale` | 600 | under it an army goes to recover (M7's attack needs 500) |
| `switch_permille` | 1,300 | a new aim must score this much of the current march's to replace it |
| `scan_hexes`, `scan_per_step` | 48, 24 | candidate hexes a season, and a step (4.7) |
| `works_cards` | 4 | works cards opened a season (4.7) |
| `works_per_season` | 2 | works begun a season |
| `raises_peace`, `raises_war` | 2, 4 | companies raised a season |
| `merges_per_season` | 4 | merges a season |
| `order_tries` | 2 | march checks an army may ask a season |
| `food_priority`, `walls_priority`, `fortify_priority` | 3,000, 2,000, 2,000 | payback divided by these (4.7) |
| `jitter_permille` | 50 | a card's payback times a draw of 950 to 1,050 |
| `disband_surplus` | 2,000 | at peace, disband above this share of the goal |
| `peace_order_every` | 1 | an army at peace takes its step every this many seasons (`(turn + army id) mod n == 0`; 8.1's fallback 2) |
| `yield_ratio` | 2,000 | the enemy's men over its own above which it may yield |

`AiDef.validate` and `AiTemperDef.validate` check every field (5.1); `test_ai_defs.gd` pins every value of these two tables.

### 4.5 A seat's brief

`AiBrief.make(game, tag)` (through `AiKnow`), once a turn, for the seat `t`:

| Field | Value |
|---|---|
| `temper` | `game.defs.temper(scenario.tempers[id − 1])` |
| `treasury` `T` | exact |
| `net` `N` | `EconomyPreview.expected(game, t).net`: this season's money at its tax level |
| `upkeep` `U` | the sum of the negative lines of that preview (districts, walls, army), as a positive number |
| `reserve` `R` | `reserve_seasons × max(U, min_upkeep)` |
| `army_room` | `max(0, (N + Military.upkeep_country(t)) × army_upkeep_share / 1000)`: what its armies may cost a season |
| `men` `M`, `people` `P` | exact |
| `enemies` | `Wars.enemies(t)`, id order |
| `threats` | the enemies, and each neighbour `n` with `Knowledge.men_of(t, n) × 1000 > max(M, min_army_men) × threat_permille` (id order) |
| `goal_men` `G` | `max(min_army_men, P × (war_army_permille if enemies or threats else army_permille) / 1000)` |
| `front` | own controlled hexes with a land neighbour owned or controlled by a threat (hex index order) |
| `posts` | per threat in order of its banded men (most first, then id): the seat's depot (`Supply.is_depot`) nearest by hex distance to that threat's land (ties: lower index); then the capital (on the map) or else its most populous settlement; no duplicates |
| `seen` | `Knowledge.armies_seen(game, t)` of enemies: `{army, tag, hex, men}` (banded) |
| `hungry`, `food_soon`, `town_full` | its reminders: `hunger` present; `goods_running_out` for food within 2 seasons; the hexes of `town_full` |
| `think` | `(game.turn + id) mod think_every == 0` |
| `declared_now` | the enemies it declared war on in this turn (filled by the `war` step) |
| `claims` | open land claimed by its armies this turn: hex index → army id |
| `wanted_cost` `W` | the ducats of the best card refused for money only this turn (filled by the works steps; 0 none) |

### 4.6 Money: taxes (the `tax` step, last)

With `T`, `R`, the current level and the season's previews `N_low`, `N_normal` (`EconomyPreview.with(game, t, {tax}, 1)`), in
order, the first that applies:

| # | Case | Level |
|---|---|---|
| 1 | `T < 0` | High |
| 2 | at war and `T < R` | High |
| 3 | `N_normal < 0` and `T < 2R` | High |
| 4 | the level is High and not (`T ≥ 1.5 R` and `N_normal ≥ 0`) | High (stays) |
| 5 | at peace, not `hungry`, not `food_soon`, `W == 0`, `T ≥ 2R`, `N_low ≥ 0` | Low |
| 6 | the level is Low, at peace, `W == 0` and `T ≥ 1.5 R` | Low (stays) |
| 7 | otherwise | Normal |

The seat acts `set_tax {level}` only when the level differs (its check refuses "taxes are already ..." otherwise, which the AI
never asks).

### 4.7 Works (the `works_scan`, `works_card` and `works_act` steps)

**Candidates.** The seat's controlled, owned, unbesieged hexes with no work under way, in hex index order: its settlements
(an upgrade), its goods districts and castles under their top level (an upgrade), and wild hexes within 2 hexes of one of its
settlements (a build, each family `Improve.build_options` allows). Each season the scan looks at `scan_hexes` (48) of them,
from the offset `(turn × 48) mod count`, 24 a step. No clear is ever a candidate. While at war a seat with `works_at_war` no
takes only food families (wheat, harbour). The works steps run only when the seat has a free work slot; with none they end at
once and `W` stays 0.

**The prior** (permille a year of the cost; all integers, divisions floored), for a hex of winter slot `w` (`3 + climate`):

```
loads(f, L)  = FamilyDef.base[L] × extra / 1000 × (pct[0] + pct[1] + pct[2] + pct[w]) / 100     # a year at full staffing
goods family (build or upgrade from L0 to L):
  value = (loads(f, L) − loads(f, L0)) × price(good) / 1000
          − wild_year(cover) × price(wild good) × (keep_wild[L0] − keep_wild[L]) / 100 / 1000   # L0 = 0 is a wild hex: keep 100
          − 4 × (upkeep[L] − upkeep[L0])
settlement to level L:
  value = 4 × ((room[L] − room[L0]) × town_tax_milli / 1,000,000 + port_dues[L] − port_dues[L0])    # port dues only on a port
          − 4 × (upkeep[L] + walls[L] − upkeep[L0] − walls[L0])
castle:                value = 0      (a fortify candidate only, below)
cost  = ducats + Σ goods × price / 1000
prior = value × 1000 / max(1, cost)
```

**Priorities** divide the payback (so they raise the rank): food families (wheat, harbour) by `food_priority` when `hungry` or
`food_soon`; a settlement's upgrade to walled town or city by `walls_priority` when its hex is in `town_full`. A **fortify**
candidate (steadfast only, `fortify` yes): a wild pass hex of the seat's land beside a threat's land, or a castle there below
level 3, while a threat exists; it is taken first, one a season, when `T − cost ≥ R`, without a payback test.

**Cards.** The best `works_cards` (4) by prior × priority (ties: lower hex index; a prior of 0 or less is never carded) each get
`ImprovePreview.of(game, t, hex,
option)`: its `verdict` (the check) and its payback in seasons from now (realm measure, M4 D31; never is a refusal). Each
payback is multiplied by `luck.ai.randi_range(1000 − jitter, 1000 + jitter) / 1000` in card order, then divided by the
priority.

**Acting.** In ascending adjusted payback: the card is taken when its verdict is ok, its payback is at most `payback_max`, and
`T − ducats ≥ R`; then `build {hex, family}` or `upgrade {hex}` through `AiKnow.act`; up to `works_per_season` (2) a season,
the slots and the money re-read after each. A card refused only for money (`blocked_by` ducats or goods) sets `W` to its ducats
when `W` is 0.

### 4.8 Armies at peace: raising, posts, disbanding (the `forces` step)

**Raising.** While `M < G` and fewer than `raises_peace` (2; `raises_war` 4 at war) companies this turn:

1. The kind: for each kind with `mix > 0` (bombards only while at war), `want = mix × (companies + 1) − 1000 × companies of
   that kind`; the largest want first, ties by kind id.
2. The place: the seat's settlements by hex distance to the nearest `front` hex (or the capital when there is no front), then
   `Military.men_at_hand` descending, then hex index; the first whose `raise {hex, kind, count: 1}` check is ok.
3. The money: allowed when the seat has no company yet, or when the armies' upkeep after it is at most `army_room`; and `T −
   cost ≥ R` (at peace) or `≥ R / 2` (at war).
4. A refusal of the check moves to the next place, then the next kind; when none passes, the step stops raising.

**Disbanding** (one company a season, own land only): when `T < 0` and `N_high < 0` (even High taxes leave a deficit), or at
peace with no threat and `M × 1000 > G × disband_surplus`: from the army farthest from the `front` (or the capital), its unit
with the fewest men (ties: highest id), `disband {army, unit}`.

**Merging.** Two armies of the seat on one hex, both not marching (or marching to the same goal), merge, the higher id into
the lower (`merge_armies {army, into}`), up to `merges_per_season` (4).

**Posts** (the order of an army at peace, in its `army` step): the seat's armies by men descending (ties: id) take
`posts[i mod len(posts)]`; an army on its post holds (`halt` when it is marching elsewhere; nothing when it holds); else it
marches to its post. Posts are depots, so armies at peace stand in supply.

### 4.9 War: when to declare (the `war` step)

On a think turn, the seat declares when **all** hold:

| # | Condition |
|---|---|
| 1 | its live wars are fewer than `max_wars` |
| 2 | no war of it ended within the last `rest_seasons` (`Wars.of_country`) |
| 3 | `T ≥ war_chest_seasons × max(U, min_upkeep)` |
| 4 | `M ≥ min_war_men` |
| 5 | not `hungry` |
| 6 | a target exists (below), and `luck.ai.randi_range(1, 1000) ≤ declare_chance` (one draw a think turn, only when 1 to 5 and a target hold) |

**Targets**: each neighbour `n` whose `declare_war {target: n}` check is ok (it refuses truces, wars, non-neighbours), with
`men_n = Knowledge.men_of(t, n)` (a neighbour is always known):

```
ratio  = M × 1000 / max(1, men_n)                       capped at 4,000
need   = declare_ratio − (busy_bonus when n has a live war with a third country)
prize  = n's districts within prize_range of t's land whose area state is open or fallen, not occupied by t
         + 2 × n's fortresses of level 2 or more within prize_range
score  = prize × ratio / 1000                           candidates: ratio ≥ need and prize ≥ 1
```

The best score (ties: lower id) is the target; `declare_war {target}`; the target joins `declared_now`.

### 4.10 War: what each army does (the `army` step)

**The standing order** (first; at peace always Hold, `AiForces.peace_army`): with `s` the largest banded men of an enemy army
the seat sees within `threat_range` (3) hexes of the army: Withdraw when `s × 1000 > men × withdraw_ratio` and the army neither
stands on a fortress of its own nor besieges; else Hold. `set_standing` only when it differs.

**Its order.** At peace, the post (4.8). At war (`AiWar.war_army`), in order (every read below goes through `AiKnow`: `morale_of`,
`own_siege`, `odds`, `forecast`, `seen_enemies`, 5.5):

1. **Shaken**: the army's morale (`AiKnow.morale_of`) is under `rest_morale` (600): march to the nearest own depot by hex distance (hold when there).
   **Hungry**: `army.supply` was 2 (hungry) in the last supply phase: the same, unless it besieges a place whose
   `SiegeView.falls_in` is 2 or less (then it keeps the siege).
2. **Besieging** (a siege of `t` on its hex, `SiegeView.at(game, t, hex)`): storm (`storm {army, goal: hex}`) when `progress ×
   1000 ≥ storm_share × need`, `seasons ≥ siege_min_seasons` (2) and the storm odds (`OddsView.of(..., storm = true)`) ratio ×
   1000 / factor ≥ `storm_ratio`; else nothing (the siege goes on).
3. **The best aim by score** among the candidates below (ties: lower hex index), `d` the hex distance from the army:

| Aim | Candidates | Score |
|---|---|---|
| retake | own districts an enemy occupies within `target_range`, no seen enemy army there with banded men over the army's | 1,000 − 10 d |
| relieve: attack | an own fortress besieged by an enemy within `relief_range`, when `F` (the army's men plus those of its own armies on the rally hex) reaches `relief_ratio` of the besiegers' banded men `B`, or `relief_last` of them when the siege falls next season (`SiegeView.falls_in` 1) | 900 − 10 d |
| relieve: rally | the same fortress when `F` is below that, unless the siege falls next season and `F` is under `relief_last` of `B` (then no relief aim: the place is given up): the rally hex (an own controlled neighbour of it with no enemy army, nearest the army, ties index) | 850 − 10 d |
| attack | a seen enemy army within `attack_range` whose `OddsView.of(game, t, army, hex)` ratio × 1000 / factor ≥ `attack_ratio` | 700 + min(2,000, that − `attack_ratio`) / 10 − 10 d |
| besiege | an enemy-controlled fortress within `target_range` with a garrison estimate over 0, besieged by no other army of `t`, whose `Sieges.forecast_for(hex, estimate, men, guns, 0, 0)` is 1 to `siege_max` (+2 with bombards) and, with the war's age, under the timer (40) less 2 | 650 − 25 × forecast − 10 d (+100 for the enemy's capital) |
| walk in | an enemy district within `target_range`, area state open or fallen, not a garrisoned fortress, no seen enemy army on it, unclaimed this turn, the army's men at least `militia_men` (250) | 500 − 10 d |
| approach | the nearest hex of an enemy's land open to the army | 100 − d |

   **Fair warning** (D23): an enemy in `declared_now` gives no candidate in its land this turn; an army with no other aim marches
   to its post (`brief.post_of`; the enemies head the posts, 4.5).

   **Keeping a march**: when the army marches to a goal that is still a candidate with score `c`, it keeps it unless the best
   score exceeds `c × switch_permille / 1000`.

4. **Acting**: `march {army, goal}` (an attack, a siege, a walk-in, a rally or an approach are all marches, M6 and M7), or the
   storm; a walk-in claims its hex. A refused check appends one more `army` step for the next aim (at most `order_tries` checks a
   season); with none left the army holds (`halt` when it marches).

### 4.11 Peace (the `peace` step)

For each live war of the seat against `e`, with `s = Wars.score(t, e)`, `age = turn − start_turn`, `men_e =
Knowledge.men_of(t, e)` (banded), first that applies:

| Terms | When (its check must be ok) |
|---|---|
| take | `s ≥ take_score`, or `age ≥ tired_seasons` and `s ≥ 1` |
| white | `s ≤ 0` and (`age ≥ tired_seasons`, or `men_e × 1000 > M × sue_ratio`, or `T < 0`) |
| yield | `s ≤ −3`, `age ≥ yield_after` and `men_e × 1000 > M × yield_ratio` |

M7's check is the other side's acceptance (D27): a take needs score 3, or 1 with the target's men not above the actor's; a
white needs 4 seasons of war and a score of −1 or more; a yield always passes. The AI asks only the first terms that its rule
picks; a refusal ends the step for that war.

### 4.12 The player's seat, passive seats, watching

The seats of a turn: every living country in id order, starting at index `(turn − 1) mod count`, except `game.player`, the
tags in `AiTurn.passive`, and all of them when `AiTurn.enabled` is false. In an AI-only game (`game.ai_only`, `player` `&""`)
every living country is a seat. `Game.watch()` makes a game AI-only: only during the pick (`player` `&""`), in a game with
countries; it logs `{turn, action: "watch", args: {}}` and returns false otherwise. The shell's viewer in a watched game is
`&""` (it sees everything, as the sandbox).

### 4.13 The season table after M8

| # | Name | Arrives | Reads | Writes (through the owner) |
|---|---|---|---|---|
| 1 | **`ai_orders`** | **M8** | through `AiKnow` only: each seat's own state, public facts and `Knowledge` (4.3); `luck.ai` | only through `Game.act` (the seats' actions); the `orders_done` record; draws `luck.ai` |
| 2 to 17 | `movement` to `vision`, and the planned rows of M9 to M12 | M4 to M7 | as M7 4.13 | as M7 4.13 |

M8's `PHASES` are M7's thirteen with `ai_orders` first (4.2). M9 to M12 add their rows where M7 4.13 places them.

### 4.14 Events, the log, the report, notifications: what others did

M8 adds **no event kind**: the AI's acts emit their actions' events (M3 to M7), with their witnesses. What changes is how
the shell shows twelve countries acting:

**The report** (`SeasonSummary.of`, M3 to M7):

- **`orders`** ("Your orders"): only action log records whose `args.tag` is the viewer (the sandbox's records have `&""`).
- **`befell`**: per other country with witnessed doings this season, one line, the hex link of its first event, the parts
  joined by `Words.list`: "Milan began 2 works, raised about 1,000 men at Novara (7, 8) and set taxes to Low." The doings:
  `work_started` and `work_finished` (counted: "began 2 works", "finished 1"), `army_raised` and `army_disbanded` (banded
  men: "raised about 1,000 men", "disbanded about 500"), `tax_set` ("set taxes to Low"), `town_grew` ("1 town grew"),
  `district_declined`, `army_starved` and `unit_lost` (banded men: "lost about 200 men to hunger"). Rank: its count of
  events. War, peace, battle, siege and capture lines stay their own (M7's sentences) with ranks war or peace 1,000, a
  battle its total killed and wounded (at least 100), a siege's start, fall or lift 50, a capture or owner change 20. Six
  lines show, `more` counts the rest (M3).
- **The lede** of a watched game (viewer `&""` in a scenario): "A watched game of Italy, 1480. Summer 1480 begins."

**The log** (`LogLines.entries`): a season keeps every line of the viewer (up to `PER_SEASON` 60) and at most
`OTHERS_PER_SEASON` (24) of others' (the newest), then one muted line without a link: "and 31 more about other countries".

**Notifications** (`LogLines.line_of`'s `notify`): an other's `army_raised` notifies only when that country is at war with the
viewer or the hex is within `NOTIFY_RANGE` (2) hexes of the viewer's land. Everything else as M3 to M7.

**The peace alert** (`DecisionQueue`, M7): a `peace_made` chronicle entry whose `target` is the player and whose `tag` is not
pushes a decision `{kind: &"peace_made", tag, target, terms, moved, turn}`, shown in `DECISIONS` after the war alerts:
title "Peace", tone bad for take, plain otherwise; lines: take "The Duchy of Milan has made peace with you: Asti (8, 10) and
Alba (6, 11) become theirs." / white "The Duchy of Milan has made peace with you: every district returns to its owner." /
yield "The Duchy of Milan has made peace with you: Domodossola (7, 6) becomes yours." and "A truce holds until Spring 1483.";
choices **Show the Duchy of Milan** and **To the report** (primary, Esc).

**The reminder `peace_risk`** (`Reminders.RULES` after `occupied`): for each live war of the player, with `s =
Wars.score(enemy, player)`:

| When | Severity | Text | Action |
|---|---|---|---|
| `s ≥ take_score` (3) | 2 | "The Duchy of Milan holds 3 of your districts: it can make peace now and keep them. Retake land, or make peace first." | `[&"country", tag]`, "Show Milan" |
| `take_score_weak ≤ s < take_score` (1 or 2) | 1 | "The Duchy of Milan holds 1 of your districts: if its armies outnumber yours, it can make peace and keep it." | the same |

### 4.15 Saves, the action log and the digest

| Body key | M8 adds | In `Game.digest()` |
|---|---|---|
| `format` | 6 (`SaveFile.FORMAT`; `OLDEST_FORMAT` 6) | no |
| `game` | `ai_only` (bool, default false) | yes: M7's string with `|ai_only` (`0` or `1`) after `player` |
| `action_log` | only records with `turn ≥ game.turn − 39` (the last 40 seasons); the AI's records; the `orders_done` and `watch` records | no |
| `log_from` (**new**) | the turn of the first record kept (1 when whole) | no |
| (not saved) | `game.orders` (the hook), `AiTurn`'s queue and trace | no |

The scenario's digest (header `scenario_digest`) gains `tempers` and `start_armies` (`ScenarioDef.digest`), so M7 saves read
"Made by an older test build" (format) and their scenario would read "Made by another build" anyway. Sizes: on north Italy after 80
AI seasons the log holds about 6,000 records, of which a save keeps the last 40 seasons' 3,000 (0.3 MB before compression); on
the made-up Europe after 40 seasons a save keeps about 36,000 (3 MB before compression); `save_mb` stays 8 (M3).

`Replay.run` plays an `end_season` record as `Season.run` with `game.orders` a `LogOrders` over the records after it: the
records up to the first `orders_done` are the AI's, played through `Game.act`, and the replay resumes after the mark (a log
from before M8 has no mark before the next `end_season`: no AI records); a `watch` record through `Game.watch`. It needs a
whole log (`log_from` 1): a test's memory, never a trimmed save.

### 4.16 Worked examples

All on "Italy, 1480", **seed 1480**, Normal taxes at the start, calm weather (`weather_odds = [100, 0, 0]` in the tests' defs
copy, as M4 to M7). The numbers come from M4's tables and its worked example 4.15 (a), and from M7's areas; `tests/core/test_ai_economy.gd` and
`test_ai_war.gd` pin them (`tests/core/ai_fixture.gd`).

**(a) Genoa's first turn (builder), Spring 1480.** `T` 610; the preview's upkeep `U` = 12 (districts) + 4 (walls) = 16; `R` =
6 × 16 = 96; `N_normal` +86; slots 2, none in use; people 82,700.

- **Works.** Candidates include the vineyard (7, 12) stage 2 → 3, timber (9, 13) stage 2 → 3, Genoa walled town → city, and
  timber stage 1 on the wild woods (8, 11), (8, 12), (9, 12) (frost) and (10, 13) (mild). Priors: a timber first stage on frost
  woods: `loads` = 6 × (50 + 50 + 50 + 150) / 100 = 18 a year, less the wild timber of frost woods (2 a year, keep 0 % of it)
  and 4 a year of upkeep: value 12, cost 40, **prior 300**; the vineyard's third stage: 40 − 24 = 16 wine × 2.5 = 40, less 1
  of wild grain (6 a year, keep 25 % → 0 %), upkeep 2 → 4: value 31, cost 250 + 20 timber + 20 stone = 290, prior 106; the
  city: room 45,000 → 100,000 gives 55 ducats a season of people's taxes and dues 30 → 45: 4 × (55 + 15) − 4 × (5 + 6 − 2 −
  4) = 260, cost 1,060, prior 245. The four cards go to the four timber woods (prior 300; ties by index: (8, 11), (8, 12),
  (9, 12), (10, 13)); each card's payback is about 18 seasons from now (+12 a year from its ready turn, four seasons on), under
  the builder's 40; the jitter orders them; the two best are begun (80 ducats). The city is not carded this season, so `W` is 0.
- **Forces.** `G` = max(500, 82,700 × 3 / 1000 = 248) = 500: one company of pikemen at Genoa (8, 13) (the capital, as there is
  no front; a walled town, its men at hand 3,000): 25 ducats, 1 iron; the first company needs no upkeep room.
- **Tax.** `T` = 610 − 80 − 25 = 505 ≥ 2 R = 192; at peace; salt runs out in Winter (not food), so neither `hungry` nor
  `food_soon`; `W` 0; `N_low` ≈ +58 (people's taxes 45, goods 5, dues 30, upkeep and walls −16, the new company −6) ≥ 0:
  **Low** (`set_tax {level: 0}`).

**(b) Milan declares on a passive Genoa** (the duel fixture, `AiFixture.duel`: every seat passive but Milan's; Genoa the
player, never acting; each other neighbour of Milan given 4 companies through `WarFixture.army_at`, so Milan's ratio over
them stays under its 1,500). Milan's think turns are those with `(turn + 5) mod 4 == 0`: turn 3 (Autumn 1480), 7, 11 ... By
Autumn 1480 Milan has raised 2 companies a season toward `G` = 341,700 × 6 / 1000 = 2,050: `M` 2,000 ≥ `min_war_men`; its
treasury, about 2,000, is over its war chest of 8 × `U`. Against a neighbour with 2,000 men the ratio is 1,000, under 1,500.
Genoa's banded men are 0: `ratio` = 2,000 × 1000 / 1, capped at 4,000. Genoa's prize: its districts within 3 hexes of Milan's
land that are open (of the two its walls do not hold, M7 4.3) plus 2 for Genoa's walls (8, 13), 3 hexes from Milan's (11, 13):
at least 2. Genoa is the only candidate; the roll is drawn (`declare_chance` 450); on a failed roll Milan thinks again at turn
7. The test pins the turn the seed gives.

**(c) Milan's army before Genoa.** Milan's army of 4 companies (2,000 men) at war with Genoa: Genoa's walls (8, 13) are
unseen (beyond Milan's sight), so the garrison estimate is the full 800; `forecast_for` with 2,000 men and no guns: need 4 + 3
× 2 = 10 (plus the hex's elevation), crowd 2 a season, stores 3 seasons, hunger from the fourth: 2, 4, 6, 10: **4 seasons**,
inside the opportunist's `siege_max` 4: score 650 − 100 + 100 (Genoa is the capital) − 10 d = 650 − 10 d beats a walk-in
(500 − 10 d) unless the walk-in's hex is 15 hexes nearer: the army marches to besiege Genoa. In the duel Genoa falls in its
fourth season of siege; Milan's armies walk into the open land; at score 3 Milan takes (`take` check: score ≥ 3), and
Genoa's occupied districts but its capital and its last district become Milan's (M7 D33).

### 4.17 The soak

`godot/tools/soak.gd` (headless, `extends SceneTree`):

```
"$GODOT" --headless --path godot -s res://tools/soak.gd -- --suite=ai --seeds=1-25 --seasons=80 --out=soak.json --summary=FILE
"$GODOT" --headless --path godot -s res://tools/soak.gd -- --quick                 # every suite, short (about 60 s)
"$GODOT" --headless --path godot -s res://tools/soak.gd -- --suite=ai --seed=17   # replay one game (a failure prints this)
"$GODOT" --headless --path godot -s res://tools/soak.gd -- --suite=ai --seed=17 --digest
```

| Suite | Games | Seasons | What | Quick |
|---|---|---|---|---|
| `ai` | seeds 1 to 100 | 80 | north Italy, AI-only (`Game.watch`) | seeds 1 to 3 × 12 |
| `passive` | seeds 1 to 20 | 80 | north Italy; the seat `playable[(seed − 1) mod 10]` (the playable countries in id order: SWI, SAV, MLO, VEN, GEN, TUS, MAN, FER, SIE, LUC) chosen (`choose_country`) and never acting; the AI plays the other 12 | seeds 1, 2 × 12 |
| `europe` | seeds 1 to 4 | 40 | the made-up Europe (`FakeMap` 494 × 247, `FakeScenario` 60), AI-only | seed 1 × 2 |

Each game: `Game.new_scenario`, the suite's start, `AiPlayers.attach` with the soak's counting judge (a `Callable` of its own
with `AiJudge`'s contract rules and no digests), then per season
`Invariants.before`, `Season.run`, `Invariants.check`; the first broken invariant ends the game and prints its report and the
line that replays it. **A crash** is any engine or script error during the game: `SoakLogger` (an engine `Logger` added with
`OS.add_logger`) counts them; the CI step also fails on `SCRIPT ERROR` or `Parse Error` in the tool's log (the net of
`perf_ui`). A game prints its seed before it starts, so a hard crash names it.

**Invariants** (`tests/core/invariants.gd`, `Invariants.before(game) -> Dictionary`, `Invariants.check(game, before) ->
PackedStringArray`, one line a broken one, named first):

| Name | Holds after every season |
|---|---|
| `turn` | `turn` is one more |
| `money` | per country: its closed ledger's closing − opening equals the sum of its lines; every line's reason is in `Treasury.WHY` (M4) |
| `goods` | per country and good: the closed stock's change equals the sum of its flows; no stock below 0 (M4) |
| `people` | no hex below 0 people; sea 0 (M5) |
| `men` | per country, M7 4.14's identity: Δ people + Δ men under arms + Δ garrison men = its flows less its losses |
| `districts` | the land count is constant; every land district has an owner; an occupier is 0 or a living country at war with the owner (M7) |
| `armies` | every army on land, at least one unit, every unit 1 to its full men; at most 8 companies of a country on a hex; no two countries' armies on a hex; every army on land open to it (M6, M7) |
| `battles` | `game.battles` is empty |
| `garrisons` | every garrison 0 to its full; an occupied fortress 0 |
| `morale` | every unit 0 to 1,000 |
| `wars` | one live war a pair at most; none during a truce; none older than 40 seasons |
| `chronicle` | at most `Chronicle.KEEP` entries, turns never going down |
| `stats` | `stats.count` equals the seasons played |
| `contract` | the judge counted no broken contract (an AI act whose check said yes and that did not succeed, or an act without an ok check, or with another seat's tag) |
| `errors` | `SoakLogger` counted no error |

**Expected ranges** (the summary table, over a suite's games at its last season; a range outside fails the suite; starting
values that the tuning task measures and keeps, or changes with Opus's word in its pull request):

| Measure | Suite | Range |
|---|---|---|
| games with at least one war declared | ai | ≥ 80 of 100 |
| wars declared a game | ai | median 2 to 12 |
| ended wars ended by an AI's peace (not the timer) | ai | ≥ 50 % |
| battles a game | ai | median ≥ 2 |
| the largest country's share of the land | ai | median ≤ 30 %, every game ≤ 60 % (M9 replaces it: `m9-build-spec.md` 4.23, the invariant `runaway` and 24 % / 33 %) |
| countries with a treasury under 0 | ai | ≤ 20 % of country-games |
| the largest treasury | ai | ≤ 30,000 in every game |
| all people | ai | 90 % to 200 % of the start (1,564,100) |
| men under arms, all countries | ai | 0.5 % to 6 % of the people |
| works begun a country a year | ai | median ≥ 0.5 |
| refused checks a seat a season | ai | median ≤ 3 |
| order changes an army a season | ai | median ≤ 0.5 |
| a war declared on the passive seat | passive | ≥ 15 of 20 games |
| the passive seat loses a war (a take peace against it moving ≥ 1 district) | passive | ≥ 5 of 20 games |
| the AI season, worst | ai | ≤ 400 ms (the runner; perf_core's 200 is on a quiet machine) |
| the `stats` phase, worst | ai | ≤ 60 ms (M3's row: the stats budget) |
| the save at the last season | ai | ≤ 2 MB |
| seasons the chronicle covers | ai | median ≥ 24 (D51) |
| the AI season, mean | europe | ≤ 3,000 ms |

The summary also prints, per country over the `ai` games, the medians the tuning reads: land at seasons 20, 40 and 80, wars
declared, won (a take or a yield in its favour) and lost, treasury, men under arms, works begun, the share of seasons at each
tax level, and the AI's milliseconds a seat. It is written to `--out` (JSON) and appended to `$GITHUB_STEP_SUMMARY`.

**CI** (`.github/workflows/godot.yml`): a nightly job `soak` (the schedule and manual dispatch) with a matrix of six runs:
`ai` seeds 1-25, 26-50, 51-75, 76-100, `passive` 1-20, `europe` 1-4, each 80 (europe 40) seasons, each uploading its JSON
report; a following job `soak-ranges` (`needs: soak`) downloads the four `ai` reports and judges the `ai` suite's ranges over
the 100 games (`soak.gd -- --merge=a.json,b.json,c.json,d.json`; the passive and europe ranges are judged in their own run).
On every pull request the GUT test `test_ai_soak_quick.gd` plays 2 games of 12 seasons with the invariants (about 10 s).

---

## 5. Interfaces

Layers after M8: `defs`, `state`, `systems`, `game`, `views`, `ai`, `shell` (D2). `core/` makes no engine calls; the AI's only
luck is `Luck.ai` through `Rng`. New files are marked **new**; "(M2)" to "(M7)" name pieces those milestones build. Every
amount is an `int`, every rate a permille.

### 5.1 Definitions (`core/defs/`)

```gdscript
# core/defs/ai_temper_def.gd  (new)
class_name AiTemperDef extends Resource
@export var key: StringName                 # &"builder"
@export var name: String                    # "Builder" (the console and the soak's report)
@export var reserve_seasons := 6
@export var payback_max := 40
@export var works_at_war := true
@export var army_permille := 3
@export var war_army_permille := 8
@export var army_upkeep_share := 200
@export var mix: PackedInt32Array           # 4, by UnitDef id: pikemen, crossbowmen, knights, bombards; sums to 1,000 (from M11 by
	# branch: infantry, missile, cavalry, artillery, the same values; m11-build-spec.md 1.2)
@export var max_wars := 1
@export var rest_seasons := 16
@export var war_chest_seasons := 12
@export var declare_ratio := 2500
@export var busy_bonus := 0
@export var declare_chance := 100
@export var attack_ratio := 1500
@export var siege_max := 4
@export var storm_share := 600
@export var storm_ratio := 1300
@export var relief_ratio := 900
@export var withdraw_ratio := 1100
@export var take_score := 2
@export var tired_seasons := 8
@export var sue_ratio := 1300
@export var yield_after := 8
@export var fortify := false
func validate(defs: GameDefs) -> Array[String]
	# key form; mix sized defs.units.size() (4), each 0..1000, summing to 1000; reserve_seasons 0..40; payback_max 1..400;
	# the two army permilles 0..100 with war >= peace; shares 0..1000; max_wars 0..5; rest, chest, tired, yield 0..80;
	# ratios 100..10000; declare_chance 0..1000; busy_bonus 0..declare_ratio; siege_max 1..20; take_score 1..20

# core/defs/ai_def.gd  (new): the numbers every temperament shares (4.4)
class_name AiDef extends Resource
@export var think_every := 4
@export var min_upkeep := 10
@export var min_army_men := 500
@export var min_war_men := 1000
@export var threat_permille := 1500
@export var threat_range := 3
@export var prize_range := 3
@export var attack_range := 6
@export var relief_range := 8
@export var target_range := 12
@export var relief_last := 600
@export var rest_morale := 600
@export var switch_permille := 1300
@export var scan_hexes := 48
@export var scan_per_step := 24
@export var works_cards := 4
@export var works_per_season := 2
@export var raises_peace := 2
@export var raises_war := 4
@export var merges_per_season := 4
@export var order_tries := 2
@export var food_priority := 3000
@export var walls_priority := 2000
@export var fortify_priority := 2000
@export var jitter_permille := 50
@export var disband_surplus := 2000
@export var peace_order_every := 1
@export var yield_ratio := 2000
func validate() -> Array[String]   # think_every 1..20; peace_order_every 1..4; ranges 1..40; scan_per_step 1..scan_hexes; counts 0..20;
	# permilles 0..10000; rest_morale 0..1000; jitter 0..500

# core/defs/game_defs.gd  (M2 to M7, edit)
@export var ai: AiDef = null                         # external: data/defs/ai.tres
@export var tempers: Array[AiTemperDef] = []         # 5, external: data/defs/tempers/*.tres
func temper(key: StringName) -> AiTemperDef          # null when unknown
# validate() adds: ai set and valid; 5 tempers, unique keys, each valid

# core/defs/scenario_def.gd  (M2, edit)
@export var tempers: Array[StringName] = []          # per country (the countries' order): a GameDefs.tempers key
@export var start_armies: Array[Dictionary] = []     # {tag: StringName, hex: Vector2i, kind: int, count: int}; 1480: []
# validate() adds: tempers sized like countries, each known; each start army on land its tag owns, kind known, count 1..8
# digest() adds both, after `owner`
```

### 5.2 State (`core/state/`)

None. M8 adds no state class and no field to the state classes. `Game` gains two fields (5.4).

### 5.3 Systems (`core/systems/`, edits)

```gdscript
# core/systems/sieges.gd  (M7, edit)
static func forecast_for(game: Game, hex: Vector2i, garrison: int, men: int, guns: int, progress: int, seasons: int) -> int
	# Sieges.forecast's arithmetic with the garrison given; forecast(...) = forecast_for(..., MapState.garrison[hex], ...)

# core/systems/movement.gd  (M6, M7, edit)
# plan(game, army, goal) is cached in game.view_cache by [&"plan", game.version, army.id, goal, winter]; march_check, march,
#   storm_check and storm call it, so a check and its act search once (D50)

# core/systems/countries.gd  (M2, edit): choose_check gains, after "this map has no countries", the row "this game is
#   watched: every country is played by the computer" when game.ai_only (the console's choose after a watch)

# core/systems/military.gd  (M6, M7, edit)
static func setup_start_armies(game: Game, scenario: ScenarioDef) -> void   # the scenario's start_armies through the Armies
	# door (units at full men, raised_turn 0, paid 0, the men levied from their hex by People.levy why &"raised"); called by
	# Game.new_scenario after Occupation.setup; nothing for 1480
```

### 5.4 Game, the hook, the season, the replay, saves (`core/game/`)

```gdscript
# core/game/orders_hook.gd  (new): who gives the other countries' orders in the ai_orders phase
class_name OrdersHook extends RefCounted
func begin(game: Game) -> void        # the turn's seats; base: nothing
func step(game: Game) -> bool         # one step; true when the turn is over; base: true
func seats() -> int                   # base 0
func seats_done() -> int              # base 0
func clear() -> void                  # drop the turn (the game ended mid-turn)

# core/game/log_orders.gd  (new): the replay's hook
class_name LogOrders extends OrdersHook
static func over(log: Array[Dictionary], from_index: int) -> LogOrders
	# begin: finds the first "orders_done" after from_index; when an "end_season" or the log's end comes first, there are no
	# AI records. step: plays the next AI record through Game.act; true after the last. index() is the record after the mark
	# (or from_index when there was none): where the replay resumes
func index() -> int

# core/game/game.gd  (M1 to M7, edit)
var orders: OrdersHook = null          # not saved, not in the digest; set by Session, the tools and the tests
var ai_only := false                   # saved (body game.ai_only), in the digest; written only by watch()
func watch() -> bool                   # 4.12: false unless the game has countries and player is &""; logs {turn, "watch"}
func digest() -> String                # M7's string with "|" + ("1" if ai_only else "0") after player
# new_scenario: after Occupation.setup, Military.setup_start_armies (M8)

# core/game/season.gd  (M3 to M7, edit)
const PHASES: Array[StringName] = [&"ai_orders", &"movement", &"battles", &"supply", &"sieges", &"war", &"production",
	&"income", &"works", &"people", &"stats", &"calendar", &"ready_units", &"vision"]
static func orders_begin(game: Game) -> void
static func orders_step(game: Game) -> bool
static func orders_end(game: Game) -> void
# run_phase(ai_orders): orders_begin; orders_step until true; orders_end
# end_check (M3 4.2): "choose your country first" only when has_countries(), player is &"" and not ai_only

# core/game/replay.gd  (M3 to M7, edit): end_season records through Season.run with a LogOrders over the records that
#   follow, resuming at its index(); watch records through Game.watch; dev records as before
# core/game/snapshot.gd  (M3 to M7, edit): const LOG_SEASONS := 40; body game.ai_only; action_log trimmed to the records of
#   the last LOG_SEASONS seasons with log_from; restore reads both (defaults false and 1) and type-checks them
# core/game/save_file.gd  (M3 to M7, edit): FORMAT := 6; OLDEST_FORMAT := 6
```

**OWNS after M8.** M7's table, plus: `ai_only` is written by `Game.watch()` (a logged developer and tool call, never an
action or a phase); the `ai_orders` phase writes nothing itself (its actions' owners write), and `test_owns.gd` checks it by
replaying the phase's logged acts on a copy taken before it and comparing digests.

### 5.5 The AI (`core/ai/`, all **new**)

```gdscript
# core/ai/ai_know.gd: THE DOOR (4.3). Every read of the game and every act of the AI.
class_name AiKnow extends RefCounted
# own country
static func treasury(game: Game, tag: StringName) -> int
static func preview_net(game: Game, tag: StringName, tax: int = -1) -> int          # EconomyPreview.with(..., {tax}, 1)
static func upkeep(game: Game, tag: StringName) -> int                              # the negative lines of the preview
static func army_upkeep(game: Game, tag: StringName) -> int                         # Military.upkeep_country
static func men(game: Game, tag: StringName) -> int
static func people(game: Game, tag: StringName) -> int
static func tax_level(game: Game, tag: StringName) -> int
static func own_armies(game: Game, tag: StringName) -> Array[Army]                  # read only, id order
static func morale_of(army: Army) -> int
static func slots_free(game: Game, tag: StringName) -> int
static func alarms(game: Game, tag: StringName) -> Dictionary                       # {hungry, food_soon, town_full: Array[Vector2i]}
static func settlements(game: Game, tag: StringName) -> Array[Vector2i]             # controlled, hex index order
static func work_candidates(game: Game, tag: StringName) -> Array[Vector2i]         # 4.7's list
static func build_options(game: Game, hex: Vector2i) -> Array[Dictionary]           # Improve.build_options
static func card(game: Game, tag: StringName, hex: Vector2i, option: Dictionary) -> Dictionary
	# {verdict, blocked_by, payback (seasons from now; -1 never), ducats, goods}: from ImprovePreview.of
static func raise_options(game: Game, tag: StringName, hex: Vector2i) -> Array[Dictionary]   # Military.raise_options
static func men_at_hand(game: Game, tag: StringName, hex: Vector2i) -> int
static func depots(game: Game, tag: StringName) -> Array[Vector2i]                  # Supply.is_depot over its land
static func own_siege(game: Game, tag: StringName, hex: Vector2i) -> Dictionary     # SiegeView.at (exact as a side)
# public
static func turn(game: Game) -> int
static func owner_of(game: Game, hex: Vector2i) -> StringName
static func controller_of(game: Game, hex: Vector2i) -> StringName
static func area_state(game: Game, hex: Vector2i) -> StringName
static func fortresses_of(game: Game, tag: StringName) -> Array[Vector2i]           # by controller, hex index order
static func fortress_level(game: Game, hex: Vector2i) -> int
static func capital_of(game: Game, tag: StringName) -> Vector2i                     # Army.NO_HEX off the map
static func land_of(game: Game, tag: StringName) -> PackedInt32Array               # owned hex indices
static func neighbours(game: Game, tag: StringName) -> Array[StringName]
static func enemies(game: Game, tag: StringName) -> Array[StringName]
static func wars_of(game: Game, tag: StringName) -> Array[Dictionary]              # {enemy, start_turn, end_turn, terms}
static func score(game: Game, a: StringName, b: StringName) -> int
static func at_war_with_other(game: Game, tag: StringName, other: StringName) -> bool   # other has a live war with a third
static func hex_distance(a: Vector2i, b: Vector2i) -> int
# others, through Knowledge
static func men_of(game: Game, tag: StringName, other: StringName) -> int           # Knowledge.men_of: banded, -1 unknown
static func seen_enemies(game: Game, tag: StringName) -> Array[Dictionary]          # Knowledge.armies_seen of enemies
static func garrison_estimate(game: Game, tag: StringName, hex: Vector2i) -> int    # Knowledge.garrison_estimate.men
static func forecast(game: Game, tag: StringName, hex: Vector2i, men: int, guns: int) -> int   # Sieges.forecast_for with the estimate
static func odds(game: Game, tag: StringName, army: Army, hex: Vector2i, storm: bool) -> Dictionary  # OddsView.of
# acts and luck
static func check(game: Game, tag: StringName, action: String, args: Dictionary) -> Dictionary  # args + tag; game.check
static func act(turn: AiTurn, game: Game, tag: StringName, action: String, args: Dictionary) -> Dictionary
	# check; on a refusal: turn.refused(tag, action, args, verdict), returns it; else game.act, then
	# turn.judged(tag, action, args, verdict, result); the trace line
static func roll(game: Game) -> int                                                 # luck.ai.randi_range(1, 1000)
static func jitter(game: Game, permille: int) -> int                                # luck.ai.randi_range(1000 - p, 1000 + p)

# core/ai/ai_brief.gd: a seat's picture for its turn (4.5)
class_name AiBrief extends RefCounted
var tag: StringName; var id: int; var temper: AiTemperDef; var ai: AiDef
var treasury: int; var net: int; var upkeep: int; var reserve: int; var army_room: int
var men: int; var people: int; var goal_men: int
var enemies: Array[StringName]; var threats: Array[StringName]
var front: PackedInt32Array; var posts: Array[Vector2i]; var seen: Array[Dictionary]
var hungry: bool; var food_soon: bool; var town_full: Array[Vector2i]
var think: bool; var declared_now: Array[StringName] = []
var claims: Dictionary = {}               # hex index -> army id, this turn
var wanted_cost: int = 0
var cards: Array[Dictionary] = []         # the works step's chosen candidates and their cards
static func make(game: Game, tag: StringName) -> AiBrief
func post_of(army_id: int) -> Vector2i    # 4.8's assignment: the seat's armies by men descending (ties: id) take
	# posts[i mod len(posts)]; read by AiForces (peace) and AiWar (fair warning)

# core/ai/ai_turn.gd: the hook (4.2, 4.12)
class_name AiTurn extends OrdersHook
var enabled := true
var passive: Array[StringName] = []
var judge: Callable = Callable()          # (tag, action, args, verdict, result) -> void; tests and the soak
func begin(game: Game) -> void
func step(game: Game) -> bool
func seats() -> int
func seats_done() -> int
func steps_done() -> int
func refusals() -> int                    # refused checks this turn (F3, the soak)
func refused(tag: StringName, action: String, args: Dictionary, verdict: Dictionary) -> void
func judged(tag: StringName, action: String, args: Dictionary, verdict: Dictionary, result: Dictionary) -> void
func brief_of(tag: StringName) -> AiBrief
func trace_of(tag: StringName) -> PackedStringArray
func clear() -> void

# core/ai/ai_players.gd
class_name AiPlayers extends RefCounted
static func attach(game: Game, passive: Array[StringName] = []) -> AiTurn   # game.orders = a new AiTurn; returns it
static func temper_of(game: Game, tag: StringName) -> AiTemperDef

# core/ai/ai_trace.gd
class_name AiTrace extends RefCounted
func line(tag: StringName, text: String) -> void
func of(tag: StringName) -> PackedStringArray
func clear() -> void

# the four step modules: each step is static func <step>(turn: AiTurn, game: Game, brief: AiBrief, arg: int) -> void
# core/ai/ai_economy.gd   AiEconomy: works_scan, works_card, works_act, tax; prior(game, brief, hex, option) -> int (4.7)
# core/ai/ai_forces.gd    AiForces: forces (raise, disband, merge, the army steps appended); peace_army (an army's step while
#                         the seat is at peace: Hold, then its post's march or halt)
# core/ai/ai_war.gd       AiWar: war (4.9); war_army (an army's step while the seat is at war: 4.10's standing order and aims);
#                         aims(game, brief, army) -> Array[Dictionary]
# AiTurn dispatches each army step to AiWar.war_army when the seat has a live war, else to AiForces.peace_army
# core/ai/ai_peace.gd     AiPeace: peace (4.11)
```

Each AI file stays under 800 lines (`ai_war.gd` is the largest, about 600).

### 5.6 Events and Session (`shell/autoload/`)

No new signal in `Events`. `Session` (edit):

```gdscript
var ai_enabled := true                    # false: every seat passive (the console's ai off; tests/shell/ui_harness.gd)
var ai_worst_step_ms: float = 0.0         # the worst AI step of the last season (F3, perf_ui)
func ai() -> AiTurn                       # game.orders as AiTurn, or null
func begin_season() -> Dictionary         # end_season_check; Season.begin; Season.orders_begin; drain; {ok, reason}
func step_orders(budget_ms: float) -> bool   # Season.orders_step while the time since the call is under budget_ms (one
	# step at least), drain() after each; true when the turn is over; last_phase_ms["ai_orders"] sums the steps;
	# ai_worst_step_ms the worst step
func orders_progress() -> Vector2i        # (seats done, seats)
func finish_season() -> void              # Season.orders_end; each phase from movement on with drain(); Season.finish;
	# season_ended(turn); unsaved_actions += 1
func end_season() -> Dictionary           # M3's: begin_season, step_orders(INF), finish_season (the console's tests)
func in_season() -> bool                  # between begin_season and finish_season
func watch() -> bool                      # Game.watch (developer: the console during the pick)
func set_seat_passive(tag: StringName, on: bool) -> void
# start_game(game): game.orders = AiPlayers.attach(game) when has_countries(); enabled = ai_enabled; passive kept
# check(), act(): refuse {ok: false, reason: "wait for the season to end"} while in_season()
```

### 5.7 Views (`core/views/`, edits)

```gdscript
# core/views/knowledge.gd  (M3, M6, M7, edit)
static func men_of(game: Game, viewer: StringName, other: StringName) -> int
	# viewer &"" or other == viewer: exact Stats army_men of the last season; known: Knowledge.band of it; else -1
static func garrison_estimate(game: Game, viewer: StringName, hex: Vector2i) -> Dictionary
	# {men, access}: own (the fortress's owner or controller is viewer, or viewer &""): exact, &"exact"; Vision.sees: rounded
	# to 100, &"seen"; else garrison_per_level x level, &"assumed"; 0 and &"none" for no fortress or an occupied one
# core/views/odds_view.gd  (M7, edit): a fortress's garrison and the besiege seasons from garrison_estimate and
#   Sieges.forecast_for (an unseen garrison is the full one)
# core/views/words.gd  (M3 to M7, edit)
static func orders_progress(done: int, total: int) -> String   # "Countries are moving 3 / 12" (min(done + 1, total))
# core/views/season_summary.gd, log_lines.gd, reminders.gd  (M3 to M7, edits): 4.14
#   LogLines: const OTHERS_PER_SEASON := 24; const NOTIFY_RANGE := 2
#   Reminders.RULES: ..., occupied, peace_risk, war_timer, ...
# core/views/replay_plan.gd  (M6, M7, edit)
func set_focus(rect: Rect2i) -> void      # an empty rect: every seen step timed (M6); else a seen step is timed only when
	# one of its hexes lies in rect; the others play instantly at their tick
```

---

## 6. The UI of M8

Built from the M1.5 kit and the M3 to M7 pieces. Colours and fonts from the Theme; HUD controls take no focus. The App's
milestone value becomes `"8"`. M8 adds no key binding and no setting.

### 6.1 The busy pill (`shell/hud/busy_pill.tscn/.gd`, new)

```gdscript
class_name BusyPill extends PanelContainer   # variation PanelCard; mouse ignored; focus none; in the Hud's TopCentre slot
func show_orders(done: int, total: int) -> void   # Words.orders_progress
func show_text(text: String) -> void
func hide_pill() -> void
```

| Part | Content |
|---|---|
| Place | top centre of `MapArea`, 8 px under the top bar (the mockup's pill: 48 px from the window's top at 1x) |
| Icon | the Kit's `hourglass` (24 px), still |
| Text | a `Label` of variation `Body`: "Countries are moving 3 / 12" / "The season ends" / "The moves of Summer 1480 · Space skips them" |
| Shown | the flow's `RUNNING` (orders, then the season's end) and `REPLAY`; hidden in `IDLE`, `DECISIONS`, `REPORT`; stays under the pause menu's shade |

No animation (reduce motion needs no case). In a turn with no seat (`ai off`, the sandbox) it shows only "The season ends".

### 6.2 The flow, and the map limited to the camera (`shell/app/season_flow.gd`, `shell/input/map_input.gd`, edits)

```gdscript
# SeasonFlow (M3, M6, M7, edit)
const AI_SLICE_MS := 5.0
const AI_SLICE_IDLE_MS := 10.0
const CAMERA_QUIET_MS := 500
signal progressed(done: int, total: int)
var begin_season: Callable                # () -> Dictionary: Session.begin_season (tests inject)
var step_orders: Callable                 # (budget_ms: float) -> bool: Session.step_orders
var finish_season: Callable               # () -> void: Session.finish_season
var orders_progress: Callable             # () -> Vector2i
func camera_moved() -> void               # the App connects CameraRig.view_changed
func abort() -> void                      # the game ended while RUNNING: clears the hook's turn, back to IDLE
func running_stage() -> StringName        # &"orders", &"phases", &"" outside RUNNING
```

- **RUNNING**: `state_changed`; one frame awaited; `begin_season()` (a refusal toasts and returns to IDLE); then each
  `_process` calls `step_orders(AI_SLICE_MS if the camera moved within CAMERA_QUIET_MS else AI_SLICE_IDLE_MS)` and emits
  `progressed`; when it returns true the stage is `phases`, one frame is awaited (the pill reads "The season ends"), then
  `finish_season()`, then on as M6 and M7 (`REPLAY`, `DECISIONS`, `REPORT`). With `count > 1` (the console's `end n`) each
  season runs this way, the report after the last.
- **The map limited to the camera**: in `RUNNING` and `REPLAY` the App calls `MapInput.block_orders(reason)` ("Countries are
  moving: the map takes orders when they are done." / M6's "The moves are still playing: Space skips them."), and
  `block_orders("")` when the flow leaves them.

```gdscript
# MapInput (M1 to M7, edit)
signal blocked(reason: String)            # at most once a second; the App toasts it
func block_orders(reason: String) -> void # "" lifts it
```

While blocked: select, command, the command key, upgrade, Tab, R, Ctrl+Z, Shift+O, Shift+right click, B, J and the hex menu
emit `blocked` instead; pan, zoom, fit, bookmarks (go), place search, map modes, the grid and names keys, the hover card, H,
F1, F3 and the pause menu work. `AppInput`'s F5 and F9 toast "Wait for the season to end" while `Session.in_season()` (F5
already did, M3 D48).

### 6.3 The replay of the AI's moves (`shell/map/replay.gd`, `core/views/replay_plan.gd`, edits)

`MoveReplay.start(speed: StringName, focus: Rect2i = Rect2i()) -> bool` passes `focus` to `ReplayPlan.set_focus` before it
plans the pace; the App gives `MapScene.view_hexes().grow(2)` (the hexes on screen at the replay's start). M6's rules stand:
seen steps only, ticks together, 180 ms a step (320 slow), 6 s at most (9 slow), never under 40 ms, Space skips, Instant and
reduce motion skip it. The pill's line names the season of the walks.

### 6.4 The report, the log, notifications, the peace alert, the reminder

- **The report screen** (`shell/screens/season_report.gd`, M3 to M7): no change; it draws `SeasonSummary`'s new `befell`
  lines and their links as any line.
- **The log, notifications, the task flag**: no shell change; they read `LogLines` and `Reminders` (4.14).
- **The peace alert** (`shell/app/decision_queue.gd`, M7, edit): the kind `peace_made` (4.14) as a `Confirm`; its lines are
  made in the queue with `Words.place`, `Words.list` and the countries' long names; "Show the Duchy of Milan" closes it and asks
  `ctx.request(&"country", {tag})`.

### 6.5 The console and F3

**Console** (`shell/hud/dev_commands.gd`, M3 to M7, edit), developer tools only:

| Command | Does |
|---|---|
| `ai TAG` | prints that seat's last turn's trace (`Session.ai().trace_of`) |
| `ai off`, `ai on` | `Session.ai_enabled`: every seat passive, or back |
| `ai pass TAG`, `ai play TAG` | one seat passive, or back (`Session.set_seat_passive`) |
| `watch` | `Session.watch()` during the pick; the App ends the pick as a choice of nobody |

Problems printed (each a planted fault in its test): "no country TAG", "no AI in this game", "only during the pick", and
"wait for the season to end" for any acting command while the season runs.

**F3** (`shell/hud/debug_overlay.gd`, edit): a line "ai 12 seats · 143 steps · 61.2 ms · worst step 2.1 ms · refused 3 ·
passive 0" from `Session.last_phase_ms`, `Session.ai_worst_step_ms` and `Session.ai()`.

### 6.6 The App (`shell/app/game_requests.gd`, `app.gd`, edits)

| Request or event | The App |
|---|---|
| `SeasonFlow.progressed(done, total)` | `BusyPill.show_orders` |
| `SeasonFlow.state_changed`, `running_stage` | the pill's text or `hide_pill`; `MapInput.block_orders` (6.2) |
| `MapInput.blocked(reason)` | the toast |
| `CameraRig.view_changed` | `SeasonFlow.camera_moved` |
| the flow's `replay_start` callable | `MoveReplay.start(speed, MapScene.view_hexes().grow(2))` |
| `Events.chronicled` of `peace_made` with the player the target and another the actor | `DecisionQueue.push` (4.14) |
| `Session.end_game` while `RUNNING` (Main menu, quit) | `SeasonFlow.abort()` first |
| the console's `watch` | the pick ends: the ribbon goes, the mode returns, the top bar's arms show the sandbox seal "S" with "Watching" |
| game start (new, load) | `Session.start_game` attaches the AI (5.6) |

`Hud` gains the `TopCentre` slot with the `BusyPill`. `MapScene` gains `func view_hexes() -> Rect2i` (the public form of
`_hexes_on_screen`). `StudyWarm` (M4.5) is unchanged: it warms the study after `season_ended`, after the AI's season.

---

## 7. Data and the editor

| File | Holds | Made by | Checked by |
|---|---|---|---|
| `godot/data/defs/ai.tres` (**new**) | `AiDef` (4.4) | by hand in the inspector (task K11) | `tests/core/test_ai_defs.gd`: loads, validates, equals 4.4 |
| `godot/data/defs/tempers/{builder,cautious,steadfast,aggressive,opportunist}.tres` (**new**) | `AiTemperDef` (4.4) | by hand (K11; tuned by K24) | `test_ai_defs.gd` |
| `godot/data/defs/game_defs.tres` (edit) | `ai`, `tempers` (external) | by hand (K11) | `GameDefs.validate()` in `test_economy_defs.gd` (M4) and `test_ai_defs.gd` |
| `godot/data/scenarios/north_italy_1480.tres` (edit) | `tempers` (4.4), `start_armies` `[]` | by hand (K11); `build_scenario.gd` keeps both when it regrows `owner` | `build_scenario.gd --check` in CI; `test_scenario_defs.gd` (M2) |
| `godot/tools/ai_tables.gd` (**new**, headless) | prints the two tables of 4.4 as Markdown from the files | K11 | `test_ai_defs.gd` runs it and compares one row of each |
| `godot/data/README.md` (edit) | `ai.tres`, `tempers/`, the scenario's two fields | K11 | |

No generated data. The map file is unchanged (`build_map --check`). The AI's tables in this page are printed by
`ai_tables.gd`; a tuned number changes the file and this page in the same pull request (K24).

---

## 8. Speed

### 8.1 The budget rows

`godot/tools/perf_core.gd` (M3 to M7) gains, in `godot/tests/perf_core_budget.json`, nightly, never in GUT:

| Row | Limit | What |
|---|---|---|
| `ai_season_ni_ms` | 200 | the `ai_orders` phase on north Italy, seed 1480, AI-only, seasons 9 to 24, worst |
| `ai_season_ms` | 3,000 mean, 5,000 worst | the `ai_orders` phase on the made-up Europe (`PerfFixture.europe_ai`: M7's `europe_war` made with `Game.watch()` before its first season, 60 AI seats), 8 seasons after 8 |
| `ai_seat_ms` | 50 mean, 150 worst | one seat's turn on the made-up Europe |
| `ai_step_worst_ms` | 8 | the worst single step on the made-up Europe |
| `ai_brief_ms` | 8 | `AiBrief.make` for the largest seat on the made-up Europe |
| `season_ms` | 380 (M7) | the thirteen other phases, unchanged |
| `route_ms` | 2 mean, 8 worst (M6) | with the plan cache (D50) |
| `save_mb` | 8 (M3) | after 40 AI seasons on the made-up Europe, the trimmed log |

`godot/tools/ui/perf_ui.gd` gains in `perf_ui_budget.json`: `ai_frame_ms` 16 (the worst frame while the AI runs, north Italy,
End season with the camera still and panning), `ai_turn_wall_ms` 1,000 (End season to the phases, north Italy),
`busy_pill_ms` 1 (a frame's pill update).

**How it stays in budget.** A seat's turn is about twenty steps: one brief, two scans of 24 hexes on the cheap rules, at most
four works cards, the raise options of its settlements, an army step each (most armies keep their march: no route), three
one-season previews. Routes and cards are cached by version, so a check and its act search once. If `ai_season_ms` fails, the
fallbacks in order, each a data edit of `ai.tres`: `works_cards` 2; `peace_order_every` 2 (an army at peace takes its step only
when `(turn + army id) mod 2 == 0`); then `target_range` 8.

### 8.2 E3: measuring an AI season on the real Europe

`perf_core.gd -- --ai-map=<map id> --ai-scenario=<scenario id>` runs the AI rows on any map and scenario present in `data/`:
AI-only from turn 1, 16 seasons of warm-up, 8 measured, the soak's invariants each season; `perf_ui.gd` takes the same two
options for the windowed rows (the AI turn's wall time, the frame while the AI runs). In M8 both run on the made-up Europe; they
run on the real one when E2's map file and a scenario on it exist.

### 8.3 The switch criteria (for the owner's later decision, standard 9 E3)

| Row (on the real Europe map) | Limit |
|---|---|
| `ai_season_ms` | 3,000 mean, 5,000 worst |
| `ai_step_worst_ms` | 8 |
| `season_ms` | 380 |
| the AI turn's wall time at 60 frames a second (windowed) | 10 s |
| a frame while the AI runs (windowed) | mean 16 ms, worst 24 ms |
| `save_mb`, `load_ms` after 40 AI seasons | 8, 2,000 |
| the soak's `europe` suite on it | 4 games × 40 seasons, no crash, no broken invariant |
| a frame at every zoom (M1) | 16 ms |

When every row holds, the play area may switch. A row that fails names its fallback: the AI fallbacks of 8.1, then a larger
hex (data, the standard 9).

---

## 9. Tests

GUT unless said. Every new check has a planted-fault case (P).

| File | Cases |
|---|---|
| `tests/core/ai_fixture.gd` (**new**) | `AiFixture.watch(defs, seed)`: the 1480 scenario AI-only, calm weather, the AI attached; `duel(defs)`: Milan's seat alone, Genoa the passive player, every other neighbour of Milan with 4 companies (`WarFixture.army_at`); `seat(game, tag)`: one seat's turn run alone, returning its acts |
| `tests/core/test_ai_defs.gd` (**new**) | the six files load, validate and equal 4.4; the scenario's 13 tempers; `ai_tables.gd`'s rows; P: a mix summing to 900, an unknown temper key in the scenario, 12 tempers for 13 countries, `declare_ratio` 0, `scan_per_step` over `scan_hexes`, a start army on another's land |
| `tests/core/test_scenario_defs.gd`, `test_fake_scenario.gd`, `test_military.gd` (M2, M6, edits) | the scenario's `tempers` and `start_armies` validated and in its digest (P: an unknown temper key); `FakeScenario` tempers by id mod 5; `setup_start_armies`: a fixture list raises its armies through the `Armies` door with their men levied, 1480's empty list changes nothing |
| `tests/core/test_orders_hook.gd` (**new**) | the base hook does nothing and is done; `LogOrders` plays the records between an `end_season` and the first `orders_done` after it; with another `end_season` or the log's end first it plays none; `index()` is the record after the mark, or the start |
| `tests/core/test_season.gd` (M3 to M7, edit) | **`PHASES` is the fourteen of 4.2** (the pin); `run_phase(ai_orders)` calls begin, steps until done and end, and logs `orders_done` (a recorder hook); with no hook (a map-only game, a game before the AI attaches) only the mark; `end_check` with `ai_only` (P: a game with countries, no player, not AI-only, refused) |
| `tests/core/test_game_core.gd`, `test_snapshot.gd`, `test_save_file.gd`, `test_owns.gd`, `test_countries.gd` (edits) | `watch()` only during the pick (P: after a choice it is refused and nothing changes); `choose_country` refused in a watched game (P); `ai_only` in the digest and the body; the log trimmed to 40 seasons with `log_from`, save, load, save byte-equal after 60 AI seasons; `FORMAT` 6 (P: a format-5 header reads `older`); the `ai_orders` phase's diff equals its logged acts replayed (P: a test hook that writes the treasury directly is reported) |
| `tests/core/test_replay.gd` (M3 to M7, edit) | 40 AI-only seasons replayed from the log with no AI give the same digest; a watched game replays its `watch` record; P: one changed AI record gives another digest |
| `tests/core/test_sieges.gd`, `test_knowledge.gd`, `test_odds_view.gd`, `test_movement.gd` (M6, M7, edits) | `forecast_for` equals `forecast` with the real garrison, and differs with another; `garrison_estimate` exact, seen (rounded to 100), assumed (full), none; `men_of` exact, banded, −1; the odds card for an unseen fortress uses the full garrison (P: a reduced unseen garrison does not change the card); a `march` check and its act plan once (a counter on `PathSearch.route`), the result unchanged |
| `tests/core/test_ai_know.gd` (**new**) | every function's filter: `seen_enemies` only seen and banded (P: an unseen army absent), `men_of` −1 for an unknown country, `garrison_estimate` per access, `forecast` with the estimate; `act` checks first and never acts on a refusal (P: a test pair whose check refuses: its do is not called), calls the judge, adds the seat's tag; `roll` and `jitter` draw only `luck.ai` (P: `luck.world` unchanged) |
| `tests/core/test_ai_door.gd` (**new**) | the text rule of 4.3 over `core/ai/*.gd`; P: a fixture text with `game.armies` in a step module is reported; `game.player` outside `ai_turn.gd` is reported |
| `tests/core/test_ai_turn.gd` (**new**) | seats in id order from the rotating start, the player and passive seats out, all in an AI-only game, none with `enabled` false; the step order of 4.2; works cards ≤ 4, army steps one an army plus one per refusal up to `order_tries`; progress counts; `clear()`; **a turn run a step at a time equals the turn run at once** (digest and log) |
| `tests/core/test_ai_economy.gd` (**new**) | every row of the tax table (P each: a High kept when `T ≥ 1.5 R`, a Low taken at war); the prior of 4.16 (a) for the four kinds of candidate; the scan's window and offset; the cards' order, the jitter's draws, the payback limit, the reserve, two works a season, `W`; the priorities (P: a hungry seat that begins a vineyard before an equal wheat); `works_at_war` no: only food at war; fortify for steadfast only; Genoa's first turn of 4.16 (a) exactly |
| `tests/core/test_ai_forces.gd` (**new**) | `G` per temperament and threat; the upkeep room and the first company; the mix's want and the kind order (P: knights refused for want of horses falls to the next kind); the place order; raises a season; disbanding both ways (P: no disband with a positive High preview); posts (threat posts, the capital, round-robin); merges |
| `tests/core/test_ai_war.gd` (**new**) | every condition of 4.9's table (P each); the busy bonus; the ratio cap; the prize; one roll a think turn and none without a target; 4.16 (b) and (c); the standing order rule; each aim of 4.10 on `WarFixture` scenes: shaken home, a storm at the share (P: no storm before 2 seasons), retake first, relief attack and rally, attack by the odds, a siege by `forecast_for` (an unseen garrison counted full), walk-ins fanned out by claims (two armies, two hexes), approach; fair warning (P: an army ordered into a country declared on this turn); keeping a march under the switch |
| `tests/core/test_ai_peace.gd` (**new**) | each terms' rule with its check (P each); a refusal ends that war's step; the AI never asks two terms of one war a turn |
| `tests/core/ai_judge.gd` (**new**) | `AiJudge`: `on_act(tag, action, args, verdict, result)`: problems when the verdict was not ok, the result not ok, or `args.tag` not the seat; with `digests = true` the digest around each check (unchanged) and each act |
| `tests/core/test_ai_judge.gd` (**new**) | **done-when 2**: 12 AI-only seasons with the judge in digest mode: no problem; P: a test seat that acts on a refused check is caught |
| `tests/core/test_ai_fog.gd` (**new**) | **done-when 3**: at Autumn 1481 of a fixture where Milan is at war with Venice with armies on both sides, Milan's turn run alone on two copies: one as is, one with, for facts Milan may not know, Venice's armies on hexes Milan does not see moved to other unseen hexes of Venice's land and given other orders and standing orders, every garrison of a fortress Milan does not see lowered by 200 (not under 0), Venice's stores and works under way edited, `luck.world` re-seeded: the same acts in the same order and the same `luck.ai` state; P: a test-only AI step that reads `Sieges.forecast` instead of `AiKnow.forecast` gives different acts |
| `tests/core/test_ai_determinism.gd` (**new**) | **done-when 4**: two AI-only runs of 40 seasons equal (digests and logs); one-step slices with a drain between them against whole turns equal; a snapshot at season 10, restored with the AI attached, played to 20 equals the straight run; P: a test seat whose decision reads `game.events.size()` (emptied between slices, not within a whole turn) breaks the slice equality |
| `tests/core/test_ai_play.gd` (**new**) | **done-when 1**: the 13 raise by Summer 1480; the 10 begin a work by Winter 1481 |
| `tests/core/test_ai_owner.gd` (**new**) | **done-when 5's and 6's duel**: within 40 seasons Milan declares on Genoa, takes at least one Genoese district, and makes a take peace moving at least one; the seasons pinned as the build gives them |
| `tests/core/invariants.gd` (**new**), `test_invariants.gd` (**new**) | each invariant of 4.17 on a fixture, and a planted break of each (P each: a treasury edited outside a ledger, a stock below 0, a unit at 0 men, two countries on a hex, a live battle at idle, a garrison over full, a war past 40) |
| `tests/core/test_ai_soak_quick.gd` (**new**) | 2 AI-only games of 12 seasons, `Invariants` every season, the judge counting: no problem |
| `tests/core/test_season_summary.gd`, `test_log_lines.gd`, `test_reminders.gd`, `test_replay_plan.gd`, `test_words.gd` (edits) | "Your orders" only the viewer's (P: an AI's march is not in Milan-the-player's orders); `befell`'s one line a country with its parts, counts and banded men, the ranks, six and `more`; the watched lede; the log's 24 others and the "more" line; others' raises notify only near or at war (P: a far raise at peace does not notify); `peace_risk` at score 3 and at 1 (P: score 0 makes no line); `orders_progress`; the focus: a seen step outside the rect is instant, inside timed |
| `tests/shell/ui_harness.gd` (edit) | `Session.ai_enabled = false` at setup |
| `tests/shell/test_session.gd` (edit) | `begin_season`, `step_orders`, `finish_season` equal `end_season` (digest); a drain after each step (a recorder); `in_season`; `check` and `act` refused while in season (P: an act between two steps is refused and nothing changes); `orders_progress`; `ai_enabled` false: no seat; load attaches the AI; `watch` |
| `tests/shell/test_season_flow.gd` (edit) | RUNNING with injected callables: steps over several frames, `progressed` each frame, the budget switching with `camera_moved`, the phases after, then REPLAY; a refused begin toasts; `abort`; `count` 3 plays three sliced seasons and one report |
| `tests/shell/test_busy_pill.gd` (**new**) | the three texts; hidden at IDLE; `mouse_filter` ignore; the Theme variation |
| `tests/shell/test_map_input.gd`, `test_app_input.gd` (edits) | `block_orders`: each blocked intent emits `blocked` once a second at most, each camera intent still works; `""` lifts it; F5 and F9 toast "Wait for the season to end" while `Session.in_season()` (P: a quickload mid-season loads nothing) |
| `tests/shell/test_move_replay.gd`, `test_decision_queue.gd` (edits) | `start` with a focus; the `peace_made` decision's title, lines per terms and choices, after the war alerts |
| `tests/shell/test_dev_commands.gd`, `test_debug_overlay.gd` (edits) | the five commands and their planted faults; the F3 line |
| `tests/shell/test_app_flow.gd`, `test_hud.gd`, `test_map_scene.gd` (edits) | the top bar's "Watching" in a watched game; end to end with the AI on: New game as Genoa, End season: the pill counts 1 / 12 to 12 / 12, a click on the map toasts the block, a pan works, the replay plays seen AI walks, the report's befell has one line a country; `ai MLO` prints a trace; `ai off`, End season: no AI act in the log; `watch` from the pick; the pill's slot; `view_hexes` |
| `tests/shell/test_ui_monkey.gd` (edit) | the AI on; invariants: no player act accepted while the season runs; the digest changes only at an accepted act or a season |
| Pictures (`godot/tools/ui/shot_ui.gd`, edit) | the pill over the map at 1280 x 720 scale 1 and 2560 x 1440 scale 2 (its three texts); the report with the grouped "What befell" of a seed 1480 season; the peace alert; signed by the art director, then goldens `godot/tests/goldens/m8_*.png` (0.5 %) |
| `godot/tools/probes/probe_logger.gd` (**new**, headless) | an engine `Logger` added with `OS.add_logger` counts a deliberate script error and a `push_error` in 4.7.2; prints PASS or FAIL |

**Determinism:** `test_ai_determinism`, `test_ai_turn` (slices), `test_replay`, `test_ai_fog`. **Save round trip:**
`test_snapshot`, `test_save_file`, `test_ai_determinism` (a save at season 10).

---

## 10. Risks and probes

| Risk | Probe and when | Fallback |
|---|---|---|
| The AI is too slow on Europe (a seat, a step) | `perf_core`'s AI rows on the made-up Europe in K23, with a first scratch run of K14's frame on `PerfFixture.europe_war` on K14's last day | 8.1's fallbacks in order |
| The AI fights too little or too much, or one country runs away | the soak's ranges (K22) and its per-country table, read by Opus in K24 | temperament numbers (data); M9 adds the brakes |
| The passive seat rarely loses a war (done-when 6) | the passive suite in K22, K24 | `declare_chance` and `take_score` of the aggressive and opportunist temperaments (data) |
| `OS.add_logger` does not catch script errors in 4.7.2 headless | `probe_logger.gd` on K22's first day | the CI step's grep for `SCRIPT ERROR` and `Parse Error` (already the `perf_ui` net), and the invariant `errors` reads 0 |
| The fog test finds a real leak in a view or a check | `test_ai_fog.gd` in K21 | the leak is closed in its system or view (as `forecast_for`), in K21's pull request, with a planted fault |
| Stateless armies dither between aims | the soak's "order changes an army a season" | `switch_permille` higher (data) |
| Imposed peaces feel unfair to the owner | the playtest (steps 8 and 9) | a new `AiDef` field `spare_player` (true: no take peace on the player until M9), added only on the owner's word (data, S) |
| Twelve countries' walks make the replay unreadable | the playtest, `ai_turn_wall_ms` | `game/movement` Instant (M6); the focus rule (D37) |
| Saves grow with the log | `save_mb` in the soak and `perf_core` | `Snapshot.LOG_SEASONS` 20 (a constant) |
| The chronicle covers too few seasons | the soak's coverage | `Chronicle.KEEP` 6,000 (D51) |
| M3 to M7's shell tests break with the AI on | the harness default (D47) in K16 | none needed |
| A step longer than a frame on slow machines | `ai_frame_ms` and `ai_step_worst_ms` | the step split further (a scan of 12 hexes) |
| A Dictionary walked in engine order breaks determinism | `test_ai_determinism`, `test_ai_turn` | lists in id or hex-index order only (D9) |

---

## 11. Changes to other pages

Made in this change:

| Page | Edit |
|---|---|
| `docs/architecture/godot-architecture.md` | 2: the layer order `defs, state, systems, game, views, ai, shell` (from M8) and the diagram; 5.3, row 1: "AI orders (M8): through the orders hook, sliced by the shell"; 5.6: the step queue, the slices, no memory of its own, `AiKnow`; 6: the soak row points at `godot/tools/soak.gd`; 9.2: the M8 row points at this spec and its plan, status "specified and planned, waits for the owner's go; starts after M7 closes"; the last row reads M9 to M12 |
| `docs/architecture/m2-build-spec.md` | 13, row M8: points here (`ScenarioDef.tempers`, `start_armies`) |
| `docs/architecture/m3-build-spec.md` | D22: settled by M8 (the save keeps the last 40 seasons of the log); 12, row M8: points here |
| `docs/architecture/m4-build-spec.md`, `m4-5-build-spec.md`, `m5-build-spec.md` | 12, row M8: points here |
| `docs/architecture/m6-build-spec.md` | D35: 1480 has no starting armies (`ScenarioDef.start_armies` empty, M8 D30); 6.4: the block is `MapInput.block_orders` (M8); 12, row M8: points here (`cost_field` not used) |
| `docs/architecture/m7-build-spec.md` | 12, row M8: points here (`Sieges.forecast_for`, `Knowledge.garrison_estimate` in the odds card; the peace alert) |
| `docs/architecture/m4-build-plan.md`, `m4-5-build-plan.md`, `m5-build-plan.md`, `m6-build-plan.md`, `m7-build-plan.md` | Section 7 (what each hands on), the M8 bullet: points here |
| `docs/architecture/ui-and-controls-plan.md` | Section 4, row M8: the tasks are those of `m8-build-plan.md` |
| `docs/architecture/ui-and-controls-spec.md` | 7: a row for the AI-turn pill (M8) |
| `docs/architecture/ui-style-and-feedback-plan.md` | S5, row M8: folded into `m8-build-plan.md` (K22, K25) |
| `docs/design/ui/game-feedback-screens.md` | A.1: the busy pill's words in M8 ("Countries are moving 3 / 12") |
| `docs/README.md` | Links to this spec and its plan |

Made by the tasks (listed in the plan): `CLAUDE.md` (the layer order, K10; the soak command, K22), `godot/README.md` (the layers,
K10; the AI, the soak, the console, K28), `tools/lint_godot.py` (the ranks, K10), `godot/data/README.md` (K11),
`.github/workflows/godot.yml` (the nightly soak job, K22). No new autoload: still `Session` and `Events`.

---

## 12. What M8 hands to later milestones

| M | Takes from M8 | M8 leaves for it |
|---|---|---|
| M9 | `AiPeace` grows an answer to peace offers (`AiPeace.answer(game, brief, offer) -> bool`) by temperament, replacing M7's fixed acceptance for AI countries; the AI sends its offers as M9's actions in the `war` phase's offers, which reach the player as `DECISIONS` (the peace alert's slot); `AiWar.war` picks a war goal and a casus belli for `declare_war`; `AiTemperDef` gains the relation numbers (trust, grudge); `AiKnow` gains `Relations`; the soak's runaway range becomes "no runaway winner" (its done-when); **taken up in `m9-build-spec.md` 4.14**: no `AiPeace.answer` (every country accepts by the score rule; only the player receives offers, through `offer_peace`, made in `ai_orders` and lapsing in the `war` phase), `AiPeace` rewritten, the `diplomacy` step, `AiTemperDef`'s peace fields replaced, the door's new tokens | Diplomacy and peace |
| M10 | `AiEconomy` gains merchants (`send_merchant`, `recall_merchant`) and the market's prices in its prior (`Economy.market_prices`); road works as candidates; the soak's trade ranges; **taken up in `m10-build-spec.md`** 4.16 and 4.17 (the trade step, road candidates in the works scan, the soak's trade invariants and ranges) | Trade |
| M11 | `AiEconomy` gains research and ideas (`set_research`, `pick_idea`) by temperament branch weights (`AiTemperDef.branch_weights`); `AiForces` raises generals and refits later kinds; **taken up in `m11-build-spec.md`** 4.17 (a `research` step, `AiResearch`; generals and refits in `AiForces`; `mix` by branch) | Research |
| M12 | Debt and bankruptcy in the AI's money (loans, desertion as M12's rules); seats that fall (a dead country is no seat); a difficulty as an `AiDef` scale on the New game page; the full-length soak to 1650 (680 seasons) and the old-saves check (taken up in `m12-build-spec.md` section 12: the `whole` suite of 684 seasons; no difficulty, the owner's decision) | A whole game |
| **E2, E3** | **The measurement of 8.2 and the criteria of 8.3; the soak's `europe` suite runs on the real map once its files exist. The switch is the owner's decision.** | |
