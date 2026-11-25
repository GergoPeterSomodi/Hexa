# Battle board build spec: battles played day by day on a board (issue 437, with 438)

Technical director, 2026-11-25. **Status: a proposal; no task starts before the owner's go, and no build task before the
mockups of Appendix B are approved (gate BB0).** Builds section 4 of `docs/design/ui-family-audit.md` ("the audit") **as the
owner answered it** (2026-11-24: play my battles on the board with Auto one click away; the deeper orders; save anywhere;
decide issue 432 first), on top of the moves build of issue 432 (`docs/design/moves-in-the-month.md`, "the moves design";
its build spec `moves-build-spec.md` is written in parallel). Where the audit or the moves design say something else, this
page wins for the build. The tasks are in `battle-board-build-plan.md`. Appendix A lists the specs this page amends.

**What it is, in one paragraph.** A battle the player is a side of is no longer fought out of sight: it is fought on a
**board**, one day (a round) at a time. At each dawn the player sees both armies exactly, the lanes, the reserve, the
matchups of the unit triangle (pikes hold horse, horse rides down shot and guns, shot and guns wear down pikes from the
back), and gives the day's **orders**: a stance (Attack, Hold, Withdraw, each with its price), which reserve company fills
an open lane, and where each gun or crossbow company shoots. **Fight day** plays the day with the M7 rules unchanged; a
**round card** says what happened; **Auto to the end** is always one click away. A battle opened by the player's own move
(issue 432) is fought at once; a battle the computer starts at End turn is fought in the season's battles phase, which
pauses for it. The computer's side, and every battle nobody plays, use the default orders, which give **exactly** M7's
fight: the same frames and the same luck draws. A battle is a pure function of its input, its luck state before day 1 and
the orders, so it replays exactly and a save taken at any dawn (even inside End turn) reloads to the same dawn.

**The battle board build is done when:**

1. Every rule R1 to R46 holds, each with its GUT case and its planted fault (P) of section 7.
2. **Default orders are the identity:** over seeds 1 to 500 of the bands fixture, `Combat.fight` built on the split gives
   the same frames, end and luck state as the M7 code recorded before BB1 (`test_combat_split.gd`); `test_combat_bands.gd`,
   the soak's ranges and every AI test are unchanged.
3. A battle played with orders replays frame for frame from its record (`Combat.replay`), and a game with battle orders
   in its action log replays to the same digest (`test_replay.gd`).
4. Save at a dawn (at idle and inside the End-turn pause), load, and the board shows the same dawn; save, load, save is
   byte-equal; `SaveFile.FORMAT` is bumped and an older format is refused quietly.
5. The monkey's board invariants (7.4) hold on 3 seeds; the perf rows of section 8 are within their limits.
6. Lint, import, check_scripts, GUT, both UI `--check`s, `build_tile_tabs.gd --check` green; the pictures of 7.5 signed by
   the art director against the approved mockups; the owner has played the plan's checklist.

---

## 1. What is there (read in the code, master after the fog build and the tile window)

| Finding | Where | Meaning for the build |
|---|---|---|
| The whole fight is one pure loop: `Combat.fight(war, input, rng)` builds a `CombatState`, runs `_day` up to `battle_days` (8), returns one frame a day and the end | `core/systems/combat.gd` | The seam is a split of this loop (R1), not a new battle model |
| A day is begin, deploy, two dice, fire, back line, shock, flanks, morale, finish; **every hit draws one spread number** from the stream it was given | `combat_day.gd`, `combat_hit.gd` | Orders that change who stands where change how many draws a day takes: the luck of later battles depends on the orders, so orders must be logged (R7, R23) |
| Deploy fills each empty open lane from the reserve in `FILL_ORDER` (centre, left, right) by `_pick` (infantry centre, cavalry flanks, missile and artillery last, then defence, then lowest id); a company moved up after day 1 is shaken | `combat_day.gd` `deploy`, `_pick` | The player's "fill" choice replaces `_pick` for a lane (R3); with no choice the default is `_pick`, unchanged |
| Fire: every ranged company in the reserve shoots; bombards at the enemy centre, crossbowmen at `FILL_ORDER[k mod 3]`; fallback `target_at` (that lane, then 1, 0, 2) | `combat_hit.gd` `fire`, `target_at` | There is **no target order** today: the owner's "targets for guns" is a new rule whose default is today's rule (R4) |
| Stances: input `stance.att` is always `attack`; `stance.def` is `hold` or the defender's standing `withdraw`; fixed for the whole fight | `battles.gd` `input_of` | Per-day stance for the human side only (R5); the AI keeps M7's fixed stance (D9) |
| A Withdraw stance leaves **only at the end of day `withdraw_day` (2)**: `if st.day == war.withdraw_day` | `combat_day.gd` `finish` | Changed to "at the end of any day from `withdraw_day`" (R5, D10); for a fixed stance this gives the same result (proved by R1's test) |
| The withdraw price **sets** morale to `withdraw_morale` (250 permille); the flight sets it to 150 and kills 150 permille of men, guns lost | `combat_day.gd` `withdraw`, `flight`; `data/defs/war.tres` | The hover words say "morale falls to 25 %" (not "minus 25") (R29) |
| The battles phase fights every battle in hex index order from `game.luck.world`, then `Occupation.flush` and `Sight.refresh` once | `battles.gd` `season` | Split into begin, steps and end so the sliced season can pause at a human battle (R18 to R22) |
| `Battle` is saved in the body (`battles/1`, `battle/1`) but holds no fight progress; its header says "never saved at idle: game.battles is empty between seasons" | `core/state/battle.gd`, `battles.gd` `to_dict` | `battle/2` adds the input, the luck state, the orders and the day (R8); a live battle can now exist at idle |
| `BattleRecord` keeps `input`, `luck_before`, the frames and the end; `Combat.replay` re-fights from input and `luck_before` | `core/state/battle_record.gd` | Gains `orders` (R7) |
| Luck: three streams (`world`, `ai`, `decor`), each one `Rng` whose state a save keeps | `core/state/luck.gd`, `core/rng.gd` | One stream for battles stays (D2); the guard keeps a live battle's draws contiguous (R10, R12) |
| The season runs sliced in the shell: `Session.begin_season`, `step_orders` (the AI's slices), `finish_step` (one phase a frame); `act` and `check` refuse with "wait for the season to end" while in season | `shell/autoload/session.gd` | The wait is a new state of `finish_step`; the two battle actions are the only ones allowed in it (R20, R44) |
| `SeasonFlow` states IDLE, RUNNING, REPLAY, DECISIONS, REPORT; the movement replay plays after the whole season | `shell/app/season_flow.gd` | A BATTLE state; the walks seen so far play before the board (R44) |
| The AI's orders hook: `game.orders` (`OrdersHook`, `AiTurn`, the replay's `LogOrders` reading the AI's records up to the `orders_done` mark); not saved, not digested | `core/game/orders_hook.gd`, `log_orders.gd`, `replay.gd` | The battle orders hook copies this pattern (R19) |
| The dock (`BattleDock`, 638 lines, a 420 px left overlay) steps through a **finished** record: face-off, stats, tug bar, lanes board, ground chips, log, result, stepper (Earlier, Next, Skip, Play) | `shell/screens/battle_dock.gd`, `shell/screens/battle/` | Stays the review of a finished battle; its parts become shared widgets (BB8) |
| `BattleView.of(game, viewer, record_id, day)`: fog by `Knowledge.battle_access`: exact for a side and for `""`, "seen" for a witness, hidden otherwise | `core/views/battle_view.gd`, `knowledge.gd` | Reads records only; gains `of_live` (R28) |
| The army panel's war part shows "In battle: X" with "Open the battle", disabled "The battle is not fought yet." before the fight; the standing order Hold or Withdraw | `shell/panels/army_war.gd` | "Open the board" for a live battle (R42) |
| The tile window (built): Town tab's battle row asks `open_battle(record)`; Army tab lists the armies here | `shell/panels/tile_tabs/land_facts.gd`, `army_tab.gd`, `core/views/tile_view.gd` | A live battle's row opens the board; an army in a live battle says so (R42) |
| The unit triangle lives in the numbers: `fight_attack` (cavalry 1400 in the open, 700 rough, 500 at walls; artillery 2000 at walls), `fight_defence`, `pikes_vs_horse_permille` 1250 (both ways), `flank_permille` 1250, fire from the reserve for missile and artillery | `data/defs/war.tres`, `core/defs/war_def.gd`, the four unit defs | The board shows the triangle from these numbers, never from fixed words (R26) |

### 1.1 The Python reference (v0.2.2, frozen): what is ported and what is not

Read in `hexa/campaign/screens/battle.py`, `screens/battlelayout.py`, `panels/unit.py`, `panels/cards.py`, `hud/battles.py`
and `hud/odds.py`. Port the content and the interactions, never the code (the audit, section 2).

| Python | What it did | In the board |
|---|---|---|
| The battle panel's place | A window over a shade of the map, centred, up to 1240 x 880, closed by Esc or a click outside | Layout B of MK1 (D5); Esc asks instead of closing (D8) |
| The field | Enemy back line and reserve at the top, enemy lanes, a dashed front line with crossed swords, our lanes, our reserve at the foot; band labels ("left flank"); cards shrink when a reserve is long | **Ported** as is (R32), our side at the foot; the shrink is the body's scroll at R39's sizes |
| The morale bar | A tug of war of front morale, each country's name and percent on its own fill, ink chosen by the fill's lightness, a gold middle tick | **Ported** (the dock's tug bar already has it), plus the flee line |
| "Your orders this season" | Attack, Hold, Withdraw as three choices with the reason when refused; two lines of what the stance does; the Withdraw price in its hover | **Ported per day** (R33, R29): the choice is made at every dawn, not once a season |
| "When attacked, with no order given" | The standing order (Hold, Withdraw) set in the panel | **Not on the board**: it stays on the army panel (M7 B26); the board shows it as day 1's stance of a defender |
| "Last day's dice" | Each side's die face in its colour, "rolled 4, x1.1" | **Ported** in the round card (R27) |
| The battle log | The newest lines that fit, newest at the foot; a broken lane in the warning colour | **Ported** (R32), with the full log on a toggle as the dock |
| The panel closes by itself when the battle ends | | **Replaced** by the result card with Close and "Review in the dock" (R37) |
| The unit panel's battle lines | "In battle: X"; "If attacked with no order: Hold, stands and fights where it is" | Already in Godot's army panel; "Open the board" added for a live battle (R42) |
| The unit card | Men, attack and defence with drill, experience with "3 = Veteran, 7 = Elite", fed or hungry, moves | **Ported** as the regiment hover card (R38) without drill (M11) and moves (not a battle fact) |
| The odds card | Men, morale, ground, one word | Godot has it (`odds_card.gd`); the board's header shows the word now (R24) |
| The battle badge and tug bar on the map | Crossed swords, a bar from zoom 3, a click opens the panel | Godot has it (`war_mark.gd`); a live battle's badge opens the board (R42) |
| Refit and drill buttons, ship cargo, found colony, "Tick all / none" | | **Left**: M11, M19, M21; split and join are the army panel's |
| The 5-lane layout and the 18 battle cards (mockups `18_battle_panel_v3_*`) | | **Left** for M24 (the audit, section 2) |
| Immediate-mode drawing, the panel's geometry module | | **Left**: the board is built from the Godot kit and the dock's widgets |

### 1.2 The board's data model in one table

| Thing | Where it lives | Saved | Who writes it |
|---|---|---|---|
| A battle in progress: hex, sides, armies, flags, name (M7) | `Battle` in `game.battles` | yes (`battle/2`) | `Battles` (start), `BattleLive` (the live fields) |
| Its input (companies, ground, stances, retreat flags, garrison) | `Battle.input`, frozen at day 1 | yes | `BattleLive.play_day` on day 1 |
| Its luck state before day 1 | `Battle.luck_before` | yes | the same |
| The orders of each fought day: the human side's `{stance, fills, targets}` | `Battle.orders`, then `BattleRecord.orders` | yes | `BattleLive.play_day` |
| Days fought | `Battle.day` | yes | the same |
| The working state at today's dawn (lanes, reserve, morale, routed) | `CombatState`, rebuilt by re-fighting | **no** (a cache) | `BattleLive.state_of` |
| The pending orders the player is setting before Fight day | the board | no | the board; nothing reaches the game before Fight day |
| What the season waits for | `game.season_stage` (`&"battles"`) | yes | `BattleLive` (through `Battles.season_step`) |
| Who gives orders in the phase | `game.battle_orders` (a hook) | no | the shell (`BoardHook`), the replay (`LogBattleOrders`) |
| The finished battle | `BattleRecord` (frames, end, orders) | yes (kept 60) | `BattleEnd.apply` |

Each round the player chooses: one stance; for each open, empty lane of his side, which reserve company fills it (or the
usual pick); for each ranged company in his reserve, which enemy lane it shoots (or its usual target). Nothing else.

---

## 2. Decisions taken

Q1 to Q5 are the open owner questions of `battle-board-build-plan.md`, section 9; each decision that names one is its
recommended answer and changes if the owner answers otherwise.

| # | Question | Decision | Why |
|---|---|---|---|
| D1 | The orders of v1 | **Stance, fills and gun targets** per day, per human side. No rotation, width, back slots or cards (M24, `battle-size-and-frontage.md`) | Owner answer 5 (the deeper version, guns' targets named); the earlier ideas he will share may add more: Q1 |
| D2 | Luck | **One stream** (`game.luck.world`), as M7. No per-battle stream. A live battle's days are contiguous on it because nothing else may act while it is live (R10) | Keeps "default orders are the identity": M7's frames, the bands, the soak and the AI tests do not move. A per-battle stream would re-base all of them |
| D3 | What is saved of a battle in progress | Its **input, luck state before day 1, orders so far and day count**; the `CombatState` is never saved: it is re-fought on demand (R11) | The audit 4.4 and the owner's answer 7; a fight is a pure function of those |
| D4 | Board or dock | A new screen **`BattleBoard`** for a live battle; the dock stays the review of a finished one. Both build from shared widgets moved out of the dock (BB8) | One job per screen; the dock's tests stay; the board's size is the mockup's choice (D5) |
| D5 | The board's size and place | **Mockup choice (Q2).** Default: a board window over the shaded map like the Python panel (centred, at most 1100 x 680 logical, the battle hex glided into the visible strip); alternative: the dock in live mode (420 px left) | The owner asked to port the Python battle UI; fills, targets and the triangle need width |
| D6 | When a battle is fought | **Opened at idle by the player's own action:** at once, on the board, before anything else. **Opened during End turn** (the computer's at-once marches, standing marches in the movement phase, storms): in the battles phase, in hex index order, the season **pausing** at each one the player is a side of | Moves design 2.6 and the audit 4.3; hex order keeps the bands and the AI's battles as M7; the computer never waits for the player inside its turn |
| D7 | Saving during the End-turn pause | **Allowed.** The game is at a clean point (AI orders and movement done, earlier battles settled); `game.season_stage = &"battles"` is saved and a load resumes the pause | Owner answer 7 ("allowed anywhere") |
| D8 | Leaving a battle undecided | **Never.** Esc and Close ask "Fight the rest automatically?"; the only ways out are a battle's end or Auto | A battle at idle blocks every other action (R10); an undecided battle would block the game |
| D9 | The computer's orders | **Default orders**: its input stance all battle (attacker Attack; defender its standing Hold or Withdraw), `_pick` fills, today's fire targets | Owner rule "AI battles resolve with the same rules"; results and soak ranges stay measured. A per-day AI is Q3 |
| D10 | Withdraw | Offered every day when the side has a retreat; it **leaves at the end of the first day from `withdraw_day`** on which the side's stance is Withdraw | The 0.2.1 decision 3 (leave "after a couple of days") made a choice between days |
| D11 | Auto | Plays the remaining days with the **last stance given** (the input's before day 1) and default fills and targets | The audit 4.3; one rule for "Auto to the end", the Options' Auto and a missing order |
| D12 | A missing order | Means the default order. A day with no logged order replays with the default | The Options' Auto, the setting off and a trimmed log all replay right with no record |
| D13 | Who is human | `game.player` only (one player). With `game.player == &""` (AI-only, watch, sandbox) no battle is ever live and no phase ever waits | The soak, the AI tests and the oracle-style replays see M7's game |
| D14 | Witnesses | No live view for a country that is not a side; it sees the finished record as today | Fog rule unchanged (fog spec R22); a witness of a live battle cannot exist at idle in v1 |
| D15 | Per-round results | Derived in a view from consecutive frames (men per company) and the dawn lanes; **no new frame key** | The record stays M7's form apart from `orders` |
| D16 | The triangle on the board | A matchup word (Strong, Even, Weak) and its reasons for each facing pair and each fill candidate, computed from the same functions the hit uses (`attack_value`, `defence_value`, `extra_of`, `ground_mult`) with the dice and spread left out | Visible, honest and never out of date with the data |
| D17 | A battle the player cannot influence | A battle whose human side has nothing to choose (a lone garrison: no reserve, no retreat, no ranged company) is fought at once with defaults and named in the report | No board of eight Fight-day clicks with no choice |
| D18 | Several battles in one End turn | Each opens in hex order; the footer adds **"Auto this season's other battles"** when more wait | Fun principle 11 (light to run); Q4 |
| D19 | The Options entry | "Your battles": **Play on the board** (default) or **Auto** | The audit's option, in two values; Q5 |
| D20 | Format | `SaveFile.FORMAT` up by one with `OLDEST_FORMAT` the same (older refused quietly, as the fog build). If the moves build's FORMAT bump is merged but not released, the board rides it (one bump for the release) | One release at a time; no save from an unreleased format must load |
| D21 | Ownership of the seam with the moves build | Section 3.6: the moves build opens battles and owns movement points; this build owns the fight, the live state, the orders, the pause, the board and the saved battle | Group B of the moves design shares the saved battle; one owner per file avoids a collision |
| D22 | Task IDs | `BB0` to `BB14` | T, F, FG, K, TW, B, C, L are taken |

---

## 3. The rules

"P" names the planted fault the test must catch. "Human side" is the side whose tag is `game.player`. Paths are under
`godot/`.

### 3.1 The combat seam (core/systems)

- **R1** **The split.** `Combat.begin(war, input, rng) -> CombatState`, `Combat.play_day(st, orders) -> frame`,
  `Combat.finish(st) -> end`. `Combat.fight` is `begin`, then `play_day(st, [{}, {}])` until `st.over` or `battle_days`,
  then `finish`: the one code path. With all-default orders the frames, the end and the `Rng` state after the fight equal
  the M7 code's for seeds 1 to 500 of the bands fixture (digests recorded before the split, kept as a fixture). P: a split
  that draws once more a day; a frame key in another order.
- **R2** **Orders.** One side's orders for one day are `{}` (all default) or `{stance, fills, targets}`, each part
  optional: `stance` one of `attack`, `hold`, `withdraw` (absent: the side's stance of the day before, or the input's on
  day 1); `fills` a map lane (0 to 2) to a fighter key; `targets` a map fighter key to a lane. `play_day` takes `[attacker,
  defender]`. `CombatOrders.normal(orders)` gives the canonical form (int keys sorted, no empty parts) that the record and
  the digest keep. P: two equal orders whose normal forms differ.
- **R3** **Fills.** At deploy, a side's chosen fills are placed first, each only if the lane is open and empty at dawn and
  the key is in the side's reserve; then every lane still empty is filled by `_pick` in `FILL_ORDER` from what is left, as
  today. The shaken rule is unchanged (a company moved up after day 1 is shaken, chosen or not). With no fills the deploy is
  M7's. P: a default pick taken before a chosen fill; a chosen company not shaken on day 3.
- **R4** **Targets.** A ranged company still in the reserve after deploy that has a target lane shoots the enemy company in
  that lane; when the lane is empty it falls back to `target_at` from that lane (that lane, then 1, 0, 2). A company with no
  target shoots as today (bombards the centre, crossbowmen `FILL_ORDER[k mod 3]`, `k` counting only the crossbowmen with no
  target). A target names a lane, never a company. P: a target that moves the crossbowmen's `k` of the others; a bombard with
  no target that does not shoot the centre.
- **R5** **Stance.** The day's stance of each side is used for that day's hits (`stance_dealt`, `stance_taken`). A side
  whose stance is Withdraw and that has a retreat leaves at the end of the **first** day `>= withdraw_day` (today: `==`);
  both sides on Withdraw: the lower front morale, as today. The check refuses Withdraw for a side with no retreat ("no hex
  to fall back to from Cerano"); the input's silent "withdraw without retreat is hold" stays for the computer's input. The
  attacker may Hold or Withdraw. P: a Withdraw on day 3 that does not leave; a fixed day-1 Withdraw that leaves on another
  day than M7's.
- **R6** **`CombatOrders.check(st, side, orders) -> {ok, reason}`** is pure and names every refusal in words: an unknown
  stance; Withdraw with no retreat; a fill lane closed ("the right lane is shut on this narrow ground"), not empty, or out of
  range; a fill key not in the reserve, routed or dead; one key in two lanes; a target key that is not a ranged company of
  the side or that the fills put into a lane; a target lane closed. Keys of the other side are refused ("not your company").
  P: each refusal planted once.
- **R7** **The record.** `BattleRecord` gains `orders: Array` of `{day, side, orders}` (normal form), the human side's
  only, in play order; `battle-record/2`. `Combat.replay(war, record)` re-fights with them. A record with no orders
  replays as M7. P: a replay that drops a day's fills.

### 3.2 The live battle (core/state, core/systems)

- **R8** **`battle/2`.** `Battle` gains `input` (`{}` until day 1, then Combat's input frozen at day 1's dawn),
  `luck_before` (the world stream's state before day 1; 64 bits, saved as text), `orders` (the human side's day orders as in
  R7) and `day` (days fought, 0 to `battle_days`). Saved in `battles/2`; in `Battle.digest_text()`. `Battles.from_dict`
  refuses a live battle whose input fails `CombatInput.validate`, whose orders are more than its days or out of day order,
  or whose day passes `battle_days`. P: a load that drops the orders; a battle with day 3 and two days of orders that loads.
- **R9** **Live.** A battle is **live** when it is in `game.battles`, has a human side, and the season is not running
  (`game.season_stage == &""`). `BattleLive.live(game) -> Battle` returns it (at most one exists, by R10). P: two live
  battles at once.
- **R10** **The guard.** While a battle is live, `Game.check` refuses **every** action except `battle_day` and
  `battle_auto` with "Finish the Battle of Cerano, 1481 first" (Session refuses the developer console's commands too), and `Season.end_check` refuses End
  season with the same words. This is what keeps a battle's draws contiguous (D2). P: a `march` or `raise` accepted during a
  live battle; End season accepted.
- **R11** **Rebuild.** `BattleLive.state_of(game, b) -> CombatState` re-fights days 1 to `b.day` from `b.input`,
  `b.luck_before` and `b.orders` on a fresh `Rng`, cached in `game.view_cache` by `[&"battle_live", game.version, hex,
  b.day]` (never saved, never digested). After the rebuild the fresh `Rng`'s state must equal `game.luck.world`'s; when it
  does not (a damaged or hand-edited save), the battle is ended as a draw with a warning (`BattleEnd.peace`), never fought
  on a wrong stream. P: a rebuild that reads the world stream; a mismatch fought on.
- **R12** **Luck.** Day 1's `luck_before` is the world state at the moment day 1 is played. Each day draws from
  `game.luck.world` when it is played; the time between days draws nothing (a board up for an hour draws nothing); a played
  day draws exactly what `Combat.play_day` draws for those orders. P: a draw at board open.
- **R13** **The input** is built by `Battles.input_of` (unchanged) at day 1's dawn and frozen in `b.input`. In the battles
  phase that is the same moment M7 builds it; at idle it is the moment the player first presses Fight day.
- **R14** **The actions.** `battle_day {hex, stance, fills, targets, tag}` and `battle_auto {hex, tag}` join the table of
  `core/game/actions.gd` with their checks (`BattleLive.day_check`/`battle_day`, `auto_check`/`battle_auto`). `day_check`
  refuses: no battle on the hex; the tag not a side; the battle not the live one and not the one the season waits for; the
  battle over; any `CombatOrders.check` refusal. `battle_day` plays one day (R15); `battle_auto` plays every remaining day
  (D11). The pair rule holds: when the check says no, the action changes nothing; when yes, it succeeds. P: an act that
  plays a day its check refused.
- **R15** **One function plays a day:** `BattleLive.play_day(game, b, orders)`: on day 1 it freezes the input and
  `luck_before`; it rebuilds the state (R11), plays `Combat.play_day` with the human side's orders and the computer's `{}`,
  appends the order (normal form) and adds one to `b.day`; when the day ends the battle it calls `Combat.finish` and
  `BattleEnd.apply` (unchanged: men, retreat, surrender, storm, experience, books, events) with the record's orders, keeps
  the record as `Battles._fight` does, and removes the battle. The actions, the battles phase and Auto all call it. P: a
  second path that plays a day.
- **R16** **Events.** Each played day emits `battle_day {tag, hex, day, killed: [a, d], wounded: [a, d]}` (witnesses as
  `battle_fought`); `battle_fought` and `battle_ended` are emitted once, at the end, as today. The shell maps `battle_day` to
  `Events.battle_day_fought(hex, day)`. P: `battle_fought` once per day.
- **R17** **The computer's side** always plays `{}` (D9). In a battle with no human side every day is `{}` (the M7 fight).
  P: an AI side given the player's fills.

### 3.3 The season (core/game, core/systems)

- **R18** **The phase split.** `Battles.season_begin(game)` (the storm orders standing on their goal engage, as today),
  `Battles.season_step(game) -> StringName` (fights the remaining battle with the lowest hex index; `&"fought"`, `&"wait"`
  or `&"done"`), `Battles.season_end(game)` (`Occupation.flush`, `Sight.refresh` when a battle was fought). `Season.run_phase
  (&"battles")` is begin, steps until done, end: the digest after `Season.run` equals M7's on the season fixtures. P: a step
  that fights two battles; an end that runs before the last step.
- **R19** **The battle orders hook.** `game.battle_orders` (a `BattleOrders`, or null; not saved, not digested, like
  `game.orders`): `wants(game, b) -> bool` (base false), `orders(game, b, day) -> Dictionary` (base `{}`), `auto_from(game, b)
  -> int` (the first day played by Auto; base `battle_days + 1`). `LogBattleOrders.over(log, from_index)` reads the
  `battle_day` and `battle_auto` records of the season after the `orders_done` mark (the replay's hook); the shell's
  `BoardHook` wants the battles with a human side while the setting is "board" (D19) and the battle is not one of D17.
- **R20** **The wait.** A step that reaches a battle the hook wants sets `game.season_stage = &"battles"` and returns
  `&"wait"` with nothing drawn; while waiting, only `battle_day` and `battle_auto` on that battle are accepted (Session
  R44); when the battle has ended, the next step goes on. A step with no hook, or a hook that does not want the battle,
  plays it with the hook's orders day by day (`orders`, then defaults from `auto_from`) through `play_day`. P: a wait that
  draws; a wanted battle fought without its orders.
- **R21** **Order.** The battles are fought in hex index order, the waited ones in their place: a computer battle on a
  lower hex index is fought before the player's, one on a higher index after it. P: a waited battle moved to the end.
- **R22** **`game.season_stage`** is `&""` or `&"battles"` (owned by `BattleLive`, listed in its `OWNS`; in the body and the
  digest). `season_step` clears it when the phase is done. A game loaded with `&"battles"` is in season at the battles
  phase: `Session` resumes it (R44). P: a load that runs the battles phase's begin twice and engages a storm again.
- **R23** **Replay.** `Replay.run`'s `end_season` sets `game.battle_orders = LogBattleOrders.over(log, orders.index())`
  and continues after the last record it consumed; `battle_day` and `battle_auto` records at idle are played by
  `game.act` as any action. A game whose log holds battle orders at idle and inside a season replays to the same digest.
  A log that ends inside a season's wait replays the season to its end with defaults for the missing days (documented, not
  equal to the paused game). P: a replay that plays an in-season `battle_day` twice.

### 3.4 What the board reads (core/views)

- **R24** **`BattlePlan.of(game, viewer, hex) -> Dictionary`**, the board's model, cached by `[&"battle_plan", version,
  viewer, hex]`; `{}` unless the battle is live or waited for **and** the viewer is a side or `""`. Contents (section 4): the
  name, the day to play and the most days, the viewer's side; per side the men, morale and front morale, the odds word now
  (`Combat.odds_card` on the current men and morale); the stance options with their state, reason and price text; the dawn
  lanes of both sides (holding company, open, closed, broken); the **fill slots** (each open empty lane of the viewer's side
  with its candidates and the `_pick` default, computed by `CombatOrders.dawn` without changing the state); the **target
  rows** (each ranged company of the viewer's side that will stand in the reserve after the default deploy, its default
  lane and the lanes allowed); the last day's round (R27); the log so far; `more_waiting` (other wanted battles this
  season). P: a candidate that the check refuses; a default that differs from what Fight day with no choice deploys.
- **R25** **The coming day of the other side is never shown.** The plan holds the computer's stance of the days fought
  (from the frames' input stance; exact for a side, as M7) and nothing about its coming day. P: the computer's next stance
  or fills in the plan.
- **R26** **The triangle, visible.** `BattleMatchup.of(war, st, striker, target, flank)` gives `{permille, word, tone,
  reasons}` for one company against another from `attack_value`, `defence_value`, `extra_of` and `ground_mult` (no dice, no
  spread, no draw): the ratio against an even pair of the same men; `word` Strong (at least 1250), Even, Weak (at most 800);
  `reasons` the named factors that apply, each with its signed percent and tone ("Pikes against horse +25 %", "Horse in the
  open +40 %", "Horse in rough ground -30 %", "Guns against walls x2", "Veteran +10 %", "Uphill -5 %"). The plan gives it for
  each facing lane pair, for each fill candidate against the enemy in that lane, and for each target lane.
  `BattleMatchup.legend(war)` gives the triangle's three lines from the numbers. P: a word that disagrees with the hit's
  factors; a fixed reason text not read from `WarDef`.
- **R27** **The round.** `BattleRound.of(frames, input, day) -> Dictionary` (pure) gives for one fought day: per side the
  killed and wounded, the men lost per lane (from the frame's men against the day before, the input's men on day 1), the
  lanes broken, the companies routed and shaken, the dice and their multipliers, the front morale before and after, each
  side's stance, and one to three sentences (the day's log line and the triangle's part: "Your pikes held the Milanese
  knights in the centre"). Used by the board's round card and the dock. P: per-lane losses that do not add up to the day's
  killed plus wounded.
- **R28** **`BattleView.of_live(game, viewer, hex, day)`** shows a live battle's fought days in the dock's model form, from
  a transient record built from `b.input`, `b.luck_before`, the rebuilt frames and no end; same fog as `of` (exact for a
  side, `{}` otherwise). P: a witness given a live view.
- **R29** **Prices**, from `WarDef`, in the stance hover: Attack "deals +20 %, takes +10 %"; Hold "deals -10 %, takes -20
  %"; Withdraw "leaves at the end of this day (day 2 at the earliest): 5 % of your men (10 % as the attacker) are lost and
  morale falls to 25 %"; the flight line "Under 10 % front morale the army flees: 15 % of its men and its guns are lost and
  morale falls to 15 %". Numbers computed, never typed. P: a price that does not follow a changed `war.tres` value.
- **R30** **The door scan.** `core/views/battle_plan.gd`, `battle_matchup.gd`, `battle_round.gd` never name `game.state.`,
  `Session`, `Events` or `game.player`, and never call `play_day`, `Combat.fight` or a `Rng` method (`test_battle_door.gd`).
  P: one planted line of each kind.

### 3.5 The board (shell)

- **R31** **`BattleBoard`** (`shell/screens/battle_board.gd`, a `Screen`) opens on `Events.battle_waiting(hex)` (R44) and
  shows `BattlePlan.of(game, Session.player_tag(), hex)`. It never closes while the battle is undecided: Esc and its close
  button open a `Confirm` "Fight the rest of the Battle of Cerano automatically?" (Auto, Keep fighting) (D8). When the
  battle ends it shows the result card; Close pops it. P: an Esc that leaves the battle live with the board gone.
- **R32** **Parts**, in the approved mockup's places (Appendix B): the title and the place (a look-at button that glides the
  camera), the face-off (both countries' arms, men, morale), the tug bar (front morale, the flee line), the field (the
  enemy's reserve and lanes, the front line, ours, ours' reserve; our side at the foot as the Python panel), the ground chips
  (pass, river, uphill, walls), the triangle legend, the round card of the last day, the log (the newest lines, the full
  log on a toggle), and the footer. Regiments are the dock's `RegimentTile` (code-drawn figure, men, morale bar, rank
  pips).
- **R33** **The footer**: the stance as a `Segmented` (Attack, Hold, Withdraw; a refused one disabled with its reason as
  tooltip; the price in each hover, R29), **Fight day N** (primary), **Auto to the end**, and "Auto this season's other
  battles" when `more_waiting > 0` (D18). The stance is sticky from day to day. P: Fight day sending a stance the strip does
  not show.
- **R34** **Fills.** Each fill slot of the plan shows as an empty lane with a chooser (a small list under the lane, or the
  mockup's form): each candidate's figure, name, men of full, morale, rank, and its matchup word with the reasons in the
  hover; the default marked "(usual pick)" and pre-selected. Choosing changes only the board's pending orders. Day 1 shows a
  slot for every open lane: the opening line-up. P: a candidate not in the plan; a choice that acts on the game.
- **R35** **Targets.** Each target row shows on its reserve company a lane chip ("shoots: centre"); clicking it offers the
  allowed lanes with the matchup against the company there now; the default is marked. P: a closed lane offered.
- **R36** **Fight day** sends `Session.act("battle_day", {hex, stance, fills, targets})` with the pending orders (only the
  chosen parts). The day then plays as the dock plays a day (dice, hits, the tug bar), 0.6 s, instant under reduce motion;
  the round card shows; the new dawn appears with the stance kept and the fills and targets reset to the plan's defaults. A
  refused act toasts its reason and changes nothing. P: a second act before the day's draw is over.
- **R37** **The result card**: who won and how (broke, withdrew, fled, wiped out, held to the last day), killed and wounded
  each side, the retreat hex or the surrender, the storm and sack, and "Review in the dock" (opens the finished record).
  Close returns control to the flow (R44).
- **R38** **The hover rule** (tile window R37): every icon and every number on the board explains itself: a tooltip on each
  chip, die, morale bar, lane label, figure, rank pip, the odds word and each button (a disabled one keeps its reason); a
  hover card (`RegimentCard`: kind, men of full, attack and defence, rank and its bonus, morale, fed or hungry, what it is
  strong and weak against from `BattleMatchup.legend`) on every regiment. `test_board_tips.gd` walks day 1, a mid-battle
  dawn with a fill and a target, and the result, and fails on a control without one. P: a regiment with no card.
- **R39** **Sizes.** Every text on the board is 15 logical pixels or larger (the `Body` style and up). The board lies inside
  the viewport at 1280 x 720 scale 1, 2560 x 1440 scale 2 and 1920 x 1080 at UI scales 1.25 and 1.5, with a full battle (8
  companies a side, three lanes, a garrison); the body scrolls, the footer is pinned. P: a label under 15; a board taller
  than the viewport.
- **R40** **Style.** Studiolo tokens only, 2D code-drawn art (the dock's picture, figures and ink), no downloaded or baked
  file, no `Color(` literal, no `theme_override_` in `.tscn`. New widgets go to `shell/screens/battle/` with their own test.
- **R41** **Keys** (`shell/input/bindings.gd`, rebindable): Enter or Space Fight day; 1, 2, 3 the stance; Shift+A Auto to
  the end; Esc the confirm of R31; Left and Right move among a focused chooser's candidates, Enter picks. While the board is
  up, map keys that would act (End season, march, raise) do nothing (the guard refuses them anyway). P: Space reaching End
  season under the board.
- **R42** **Openers.** A live or waited battle opens the board from: the army panel's "In battle: X · Open the board"
  (`army_war.gd`), the Town tab's battle row, the map's war badge on that hex, the task flag line. A finished battle still
  opens the dock. P: a live battle's badge opening the dock with no record.
- **R43** **The Options entry** "Your battles" (`battles`: `board` default, `auto`). With `auto`, `BoardHook.wants` is
  false (the phase fights them with defaults: D12) and a battle that becomes live at idle is sent `battle_auto` at once
  (logged) and its result shown as a toast with "Review" (opens the dock).

### 3.6 The flow, the saves and the moves seam

- **R44** **Session and SeasonFlow.**
  - `Session.drain` emits `Events.battle_waiting(hex)` once when `BattleLive.live(game)` becomes non-null at idle (after
    the move that opened it, after a load); `Session.finish_step` returns false and emits it when `season_step` waits.
  - `Session.act` and `check` accept `battle_day` and `battle_auto` while the season waits (the only exception to "wait for
    the season to end"); everything else keeps that refusal.
  - `SeasonFlow` gains **BATTLE**. In End turn: RUNNING until the wait; then REPLAY of the walks recorded so far (the
    enemy's march onto the hex; skippable); then BATTLE (the board); when the battle ends, RUNNING resumes `finish_step`
    (more waits repeat REPLAY and BATTLE); after the last phase REPLAY of what is left (retreats), DECISIONS and REPORT as
    today. At idle: IDLE, BATTLE, IDLE. The report counts the battles played ("You fought 2 battles; 1 was fought
    automatically").
  - **Save** is allowed in BATTLE (idle or waiting); quitting to the menu asks as today. A game loaded with
    `season_stage == &"battles"` starts in BATTLE on the waited battle and goes on with the rest of the season; the walks
    before the save are not replayed. The autosave never runs in BATTLE.
  - P: a save refused in BATTLE; a load in the wait that runs the movement phase again.
- **R45** **The save.** `SaveFile.FORMAT` bumped by one, `OLDEST_FORMAT` equal (D20). The body carries `battles/2`
  (`battle/2`, `battle-record/2`) and `game.season_stage`. Save, load, save is byte-equal with a live battle at day 3 at idle
  and with the season waiting at a battle at day 0 and day 2. A file of the previous format reads "Made by an older test
  build". P: a file of the previous format that loads; a reload whose dawn differs.
- **R46** **The moves seam** (D21). What the moves build hands to the board, and what it gets back:

| | The moves build (issue 432) | This build |
|---|---|---|
| Opens a battle | The player's at-once walk steps onto an enemy army or storms: it calls `Battles.engage` (unchanged sides, ground, crossing, uphill, river) and stops the walk; the army's points left go to 0 | Finds the battle live (R9), blocks other actions (R10), opens the board (R44) |
| End turn | The computer's at-once marches and the standing marches call `Battles.engage` but **never fight**: every battle opened in End turn is fought in the battles phase (R18) | Pauses the phase at the player's battles (R20) |
| Until the board lands | A battle opened at idle is fought at once by `BattleLive.fight_at(game, hex)` (defaults to the end; added by whichever build lands first) | Turns `fight_at` into the board's Auto and the Options' Auto |
| Gets back | `Events.battle_ended(hex, record, winner)`, the record id, the armies' men and hexes after `BattleEnd.apply` (a retreat is a walk, `unit_moved`, replayed by the shell), the game idle and free again | |
| Saved | `army/3` (points left) | `battle/2`, `battles/2`, `battle-record/2`, `season_stage`; one FORMAT bump with the moves build when both are in one release |

  P: a battle fought inside the computer's orders phase (`test_battle_season_wait.gd` drives an AI march into the player's
  army and checks no record exists before the battles phase).

---

## 4. Interfaces

```gdscript
# core/systems/combat.gd (edit)
static func begin(war: WarDef, input: Dictionary, rng: Rng) -> CombatState
static func play_day(st: CombatState, orders: Array) -> Dictionary          # [attacker, defender] orders; the frame
static func finish(st: CombatState) -> Dictionary                             # the end (BattleRecord.END_KEYS)
static func fight(war: WarDef, input: Dictionary, rng: Rng) -> Dictionary     # begin + play_day([{}, {}])... + finish (R1)
static func replay(war: WarDef, record: BattleRecord) -> Dictionary           # applies record.orders (R7)

# core/systems/combat_orders.gd (new) class CombatOrders, pure
const STANCES: Array[String] = ["attack", "hold", "withdraw"]
static func check(st: CombatState, side: int, orders: Dictionary) -> Dictionary      # {ok, reason} (R6)
static func normal(orders: Dictionary) -> Dictionary                                   # canonical form (R2)
static func dawn(st: CombatState, side: int) -> Dictionary
# {open: Array[int] (empty open lanes), pool: Array[int] (reserve keys), defaults: {lane: key} (_pick in FILL_ORDER),
#  ranged: Array[{key, default_lane}] (in the reserve after the default deploy), closed: Array[int]}  no change, no draw

# core/state/battle.gd (edit): battle/2
var input: Dictionary = {}          # frozen at day 1 (R13)
var luck_before: int = 0
var orders: Array[Dictionary] = []  # {day, side, orders} normal form, play order (R7)
var day: int = 0

# core/systems/battle_live.gd (new) class BattleLive
const OWNS: Array[String] = ["season_stage"]
static func live(game: Game) -> Battle                                   # R9
static func waited(game: Game) -> Battle                                 # the battle the season waits for, or null
static func state_of(game: Game, b: Battle) -> CombatState               # R11
static func play_day(game: Game, b: Battle, orders: Dictionary) -> Dictionary   # {frame, ended: bool, record: int} (R15)
static func fight_at(game: Game, hex: Vector2i) -> int                   # defaults to the end; the record id (R46)
static func guard(game: Game, action: String) -> Dictionary              # {ok, reason} for Game.check (R10)
static func day_check(game: Game, args: Dictionary) -> Dictionary        # battle_day {hex, stance, fills, targets, tag}
static func battle_day(game: Game, args: Dictionary) -> Dictionary
static func auto_check(game: Game, args: Dictionary) -> Dictionary       # battle_auto {hex, tag}
static func battle_auto(game: Game, args: Dictionary) -> Dictionary

# core/systems/battles.gd (edit)
const STEP_FOUGHT := &"fought"
const STEP_WAIT := &"wait"
const STEP_DONE := &"done"
static func season_begin(game: Game) -> void
static func season_step(game: Game) -> StringName
static func season_end(game: Game) -> void

# core/game/battle_orders.gd (new) class BattleOrders extends RefCounted: not saved, not digested (R19)
func wants(game: Game, b: Battle) -> bool
func orders(game: Game, b: Battle, day: int) -> Dictionary
func auto_from(game: Game, b: Battle) -> int
# core/game/log_battle_orders.gd (new) extends BattleOrders
static func over(log: Array[Dictionary], from_index: int) -> LogBattleOrders
func index() -> int                                                       # the record after the last one consumed
# core/game/game.gd (edit): var battle_orders: BattleOrders = null; var season_stage: StringName = &""; check() asks BattleLive.guard

# core/views/battle_plan.gd (new)
static func of(game: Game, viewer: StringName, hex: Vector2i) -> Dictionary
# {hex, name, day, days_max, side: &"attacker"|&"defender", sides: {attacker: S, defender: S},   S = {tag, name, men, full,
#   morale, front, colour}, odds: {word, value}, stance: {current, options: Array[{id, label, ok, reason, price}]},
#  lanes: {ours: Array[L], theirs: Array[L]},   L = {lane, state: &"held"|&"open"|&"closed"|&"broken", company: {} | C,
#   matchup: {} | M},   C = {key, kind, name, figure, men, full, morale, rank, rank_name, shaken, hungry},
#  fills: Array[{lane, default_key, candidates: Array[C + {matchup: M}]}],
#  targets: Array[{key, name, figure, default_lane, lanes: Array[{lane, ok, reason, matchup: M}]}],
#  enemy_stances: Array[String] (days fought), round: {} | BattleRound, log: Array[{day, text, tone}],
#  legend: Array[String], more_waiting: int, ended: {} | {record, result}}
# core/views/battle_matchup.gd (new)
static func of(war: WarDef, st: CombatState, striker: int, target: int, flank: bool) -> Dictionary   # M = {permille, word, tone, reasons}
static func legend(war: WarDef) -> Array[String]
# core/views/battle_round.gd (new)
static func of(frames: Array, input: Dictionary, day: int) -> Dictionary
# core/views/battle_view.gd (edit)
static func of_live(game: Game, viewer: StringName, hex: Vector2i, day: int = -1) -> Dictionary

# shell/autoload/events.gd (edit)
signal battle_waiting(hex: Vector2i)
signal battle_day_fought(hex: Vector2i, day: int)
# shell/autoload/session.gd (edit)
const BATTLE_ACTIONS: Array[String] = ["battle_day", "battle_auto"]
func waiting_battle() -> Vector2i                                         # the waited hex, or Army.NO_HEX
# shell/app/season_flow.gd (edit): enum State { IDLE, RUNNING, REPLAY, BATTLE, DECISIONS, REPORT }
var open_board: Callable = Callable()                                     # (hex: Vector2i) -> bool
func battle_done() -> void
# shell/app/board_hook.gd (new) class BoardHook extends BattleOrders: wants() by the setting and D17; orders() {} (the
#   live days come as actions)

# shell/screens/battle_board.gd (new) class BattleBoard extends Screen
signal look_at_requested(hex: Vector2i)
signal finished(record: int)
func open_live(hex: Vector2i) -> bool
func pending_orders() -> Dictionary
func set_stance(id: StringName) -> void
func set_fill(lane: int, key: int) -> void
func set_target(key: int, lane: int) -> void
func fight_day() -> bool
func auto_rest() -> bool
func shown_day() -> int
# shell/screens/battle/ (new widgets; the first four moved out of the dock in BB8)
#   battle_field.gd, tug_bar.gd, day_log.gd, dice_row.gd, orders_strip.gd, fill_chooser.gd, target_chip.gd,
#   round_card.gd, result_card.gd, regiment_card.gd (the hover card)
```

---

## 5. Fog: what the board may show

The board is shown only to a side of the battle (R24). A side sees both armies exactly (M7, fog spec R22): the battle hex is
in its sight. What it may not see:

| Fact | Shown to a side | Why |
|---|---|---|
| Both sides' companies, men, morale, rank, lanes, reserve, hunger | exact | M7 rule; both stand on one hex in sight |
| The enemy's stance of a day already fought | exact, after the day | M7 shows the stances to a side |
| The enemy's stance, fills or targets for the coming day | **never** (R25) | Orders are given at the same dawn by both |
| Another army marching to join | no (not in the plan) | Joins happen in the movement phase, before day 1 |
| Witnesses, other battles waiting | the count `more_waiting` of the player's own | Own battles only |
| A battle you are not a side of | no board, no live view (D14) | Fog rule: battles you are not in are hidden in light fog |

---

## 6. Sketches

The approved mockups (Appendix B) fix look and spacing; this sketch fixes the order of parts (layout B, the default).

```
+--------------------------- Battle of Cerano, Spring 1481 ------------------------- [look] [x] +
| [Savoy arms] Savoy  4,000 of 4,500  morale 72%   ODDS: EVEN   Milan 3,200 of 3,500  [Milan]  |
| tug bar: front morale  ######|#####------------ flees under 10 %           Day 3 of 8         |
| ground: [farmland] [river crossed: -20 % day 1] [uphill -5 %]                                  |
+-----------------------------------------------------------------------+-----------------------+
|  MILAN reserve   [xb 480] [bm 100]                                    | Round 2               |
|  MILAN lanes     [ L: kn 230 ]  [ C: pk 410 ]  [ R: pk 380 ]          | Savoy lost 240 (L 90, |
|  --------------------------- front line ----------------------------- |   C 150), Milan 310   |
|  SAVOY lanes     [ L: open   ]  [ C: pk 470 ]  [ R: kn 240 ]          | Your left gave way.   |
|                   fill with:                                          | Your pikes held their |
|                   (o) Pikemen 500, morale 80  Even  (usual pick)      |   knights: +25 %      |
|                   ( ) Knights 250, morale 90  Weak: pikes +25 %       | dice 4 (x1.1) - 2     |
|  SAVOY reserve   [kn 250] [bm 100 shoots: centre v]                   | Log ...               |
|  TRIANGLE  pikes hold horse . horse rides down shot and guns . shot and guns wear pikes      |
+-----------------------------------------------------------------------+-----------------------+
| Stance [Attack][Hold][Withdraw]     [ Fight day 3 ]   [Auto to the end]   (Auto this season's 1 other battle) |
+-----------------------------------------------------------------------------------------------+
```

---

## 7. Tests

All under `godot/tests/`. Every edited test keeps its planted faults; a task may not delete a P without replacing it.

### 7.1 New tests

| Test | Cases | Planted faults |
|---|---|---|
| `core/test_combat_split.gd` | the digests of seeds 1 to 500 against the fixture recorded from the M7 code before BB1 (frames, end, luck state); `fight` = `begin` + `play_day` + `finish`; a record with orders replays equal | R1, R7 |
| `core/test_combat_orders.gd` | each refusal of R6; fills placed first then `_pick`; shaken after day 1; targets and the fallback; crossbowmen's `k` without targets; Withdraw leaving on day 2, 3 and 7; the attacker's Hold and Withdraw; `normal` | R2 to R6 |
| `core/test_battle_phase.gd` | the sliced battles phase equals the atomic one on the war rig's seasons; storms engage once; hex order; `LogBattleOrders` over a synthetic log | R18, R19, R21 |
| `core/test_battle_live.gd` | a battle at idle is live; the guard refuses each action of `Actions.NAMES` and End season; `play_day` freezes input and luck on day 1; rebuild equals; the rng mismatch ends a draw; the record keeps the orders; `fight_at` | R8 to R13, R15, R16 |
| `core/test_battle_actions.gd` | the check/act pair over 200 seeded random orders (legal and not) on 20 fixture battles: refused acts change nothing (digest), accepted ones play one day; `battle_auto` from each day equals `play_day` with `{}` and the last stance | R14, D11 |
| `core/test_battle_season_wait.gd` | the sliced battles phase on a fixture with three battles (computer, player, computer by hex index): the wait at the player's, the hex order, nothing drawn in the wait; `Season.run` equals the sliced run with no hook; `LogBattleOrders` replay equals the live run; an AI march into the player's army fights nothing before the phase (R46) | R18 to R22, R46 |
| `core/test_battle_save.gd` | `battle/2` round trip; save, load, save byte-equal at idle on day 3 and in the wait on days 0 and 2; the board's plan equal after load; the previous FORMAT refused; a damaged live battle refused | R8, R45 |
| `core/test_battle_plan.gd` | the plan of day 1 (a fill slot a lane), a mid-battle dawn, a narrow ground, an assault (garrison centre: no slot), a lone garrison (D17); every candidate passes `CombatOrders.check`; defaults equal the deploy with no choice; prices follow a changed `WarDef`; `{}` for a witness and a stranger; no coming enemy order | R24, R25, R29 |
| `core/test_battle_matchup.gd` | knights against pikes Weak, knights against crossbowmen in the open Strong, in woods not; bombards against walls; rank and uphill reasons; the word against the hit's factors over every branch pair, both fights | R26 |
| `core/test_battle_round.gd` | per-lane losses add up; broken lanes; routed; the sentences; day 1 from the input's men | R27 |
| `core/test_battle_door.gd` | the scan of R30 | one P per forbidden name |
| `shell/test_battle_board.gd` | opens on `battle_waiting`; parts in order; fill and target choices change only pending orders; Fight day sends exactly the chosen parts; the round card; the result card; Esc asks; reduce motion; keys of R41 | R31 to R37, R41 |
| `shell/test_board_tips.gd` | the hover walk of R38 on day 1, mid-battle and the result | R38 |
| `shell/test_board_sizes.gd` | R39 at the four sizes and scales, both themes, a full battle; every label 15 or more | R39 |
| `shell/test_orders_strip.gd`, `test_fill_chooser.gd`, `test_target_chip.gd`, `test_round_card.gd`, `test_result_card.gd`, `test_regiment_card.gd` | each widget alone | a disabled stance that sends; a chooser with a refused candidate |
| `shell/test_battle_wait.gd` | the flow with a fake board: the state walk of R44, act refused but for the battle actions, save in the wait and the resume, the Options' Auto | R43, R44 |
| `shell/test_battle_flow.gd` | headless app: a march into an enemy army (moves build) opens the board; three days and Auto; IDLE again. End season with a computer attack: REPLAY, BATTLE, RUNNING, REPORT; save in the wait and load resumes; the Options' Auto | R42 to R44 |

### 7.2 Tests that move or change

| Test | Change | Task |
|---|---|---|
| `core/test_combat.gd`, `test_combat_props.gd`, `test_combat_hostile.gd` | `fight` through the split; a hostile orders case per R6 refusal | BB1 |
| `core/test_combat_bands.gd` | **unchanged, must stay green** (the identity) | BB1 proves it |
| `core/test_battles.gd` | the phase through begin, steps and end; storms engage once | BB2 |
| `core/test_season.gd` | PHASES unchanged; the battles phase sliced equals atomic | BB2 |
| `core/test_replay.gd` | a log with `battle_day` at idle and inside a season | BB5 |
| `core/test_save_file.gd`, `test_war_save.gd` | FORMAT bump; `battles/2`; `season_stage` | BB5 |
| `core/test_battle_view.gd` | `of_live`; the round in the dock's model | BB6 |
| `core/test_owns.gd`, `test_no_other_writers.gd` | `season_stage`'s one writer; a Battle's live fields written only through `BattleLive` | BB4 |
| `core/test_invariants.gd`, `tests/core/invariants.gd` | at most one live battle; no live battle while in season unless waited; a battle's day 0 to 8; orders no more than days | BB4 |
| `shell/test_battle_dock.gd` | unchanged in what it asserts; the widgets moved (BB8) must keep it green | BB8 |
| `shell/test_season_flow.gd` | the BATTLE state; two replays; save allowed | BB7 |
| `shell/test_army_panel.gd`, `test_town_tab.gd`, `test_war_marks.gd`, `test_task_flag.gd` | "Open the board" for a live battle | BB10 |
| `shell/test_options.gd`, `test_settings.gd` | the `battles` entry | BB7 |

**Unchanged, must stay green:** every AI test, `test_ai_determinism.gd`, the soak's suites and ranges, `test_fog_views.gd`,
`test_tile_*.gd`, `test_snapshot.gd` (apart from the new body fields), `test_combat_bands.gd`.

### 7.3 Soak

A soak suite `orders` (`tools/soak.gd --suite=orders`): AI games where one country is given a seeded random
`BattleOrders` hook (legal random stance, fills and targets each day, Auto sometimes) in place of the player. Invariants
every season (the soak's own and section 7.4's core ones); the game's log replays to the same digest at the end; its war
ranges are reported, not gated. The `ai`, `passive` and `europe` suites are unchanged and must give the same digests as
before BB1 (identity).

### 7.4 Monkey

**Monkey** (`tests/shell/monkey_board.gd`, extends the fog monkey): on a fixture where the player's armies stand next to
enemy armies at war, it marches into them (a battle at idle), plays random legal and illegal orders (fills, targets,
stances), presses Fight day, Auto, Esc then both answers, saves and loads at random dawns, ends seasons so the computer
attacks (the wait), and switches the Options' entry. **Invariants each frame:** while a battle is live, every non-battle
action is refused and End season is refused; the board's pending orders pass `CombatOrders.check` or Fight day is
disabled; the board shows `BattlePlan.of`'s numbers; the rebuilt state's luck equals the world's; a battle has 0 to 8 days
and no more orders than days; after save and load the digest and the plan are equal; the board is inside the viewport; no
board is up without a live or waited battle. **Counters** above 0: `board_days`, `board_autos`, `board_saves`,
`season_waits`, `board_fills`, `board_targets`.

### 7.5 Pictures

`tools/ui/shot_ui_board.gd` (1280 x 720 scale 1, 2560 x 1440 scale 2, 1920 x 1080 at UI scale 1.5): day 1 with the
line-up chooser; a mid-battle dawn with an open lane, the chooser open and a gun target chip open; the Withdraw hover; a
round card; a result card (won, withdrew, fled); an assault; a narrow ground; the End-turn "battle awaits" moment; the Esc
confirm; the Options entry; the army panel's "Open the board". **The owner is asked before any windowed run.** The art
director signs them against the approved mockups. Goldens that show the army panel, the Town tab's battle row or the dock
are made again and reviewed side by side.

---

## 8. Performance

BB3 records the baseline of the rows marked "as today"; BB13 adds the new rows and measures all; both tables in its pull
request.

| Row | Class | Limit | Expected | Note |
|---|---|---|---|---|
| `fight_ms`, `battles_ms`, `battle_view_ms`, `season_ms` (`perf_core`) | cpu | as today | within 5 % of BB3's baseline | the split adds no work on the default path |
| **new** `play_day_ms` (`perf_core`) | cpu | 0.5 mean | about 0.2 | one `BattleLive.play_day` of 8 against 8 with orders, rebuild cached |
| **new** `battle_rebuild_ms` (`perf_core`) | cpu | 2.0 worst | about 1.3 | `state_of` from cold at day 7 (a load, a cache miss) |
| **new** `battle_plan_ms` (`perf_core`) | cpu | 2.0 mean | about 0.6 | `BattlePlan.of` uncached at a dawn with three fill candidates and two targets |
| **new** `board_open_ms` (`perf_ui`) | gpu | 16 | under 10 | the board from `battle_waiting` to its first full draw, 8 v 8, worst of 3 |
| **new** `board_day_ms` (`perf_ui`) | gpu | 16 | under 8 | Fight day to the next dawn drawn, reduce motion, worst frame |
| **new** `board_chooser_ms` (`perf_ui`) | gpu | 16 | under 6 | opening a fill chooser of four candidates |
| `save_ms`, `load_ms` | cpu | as today | within their limits | a live battle adds one input and up to 8 orders; the load's rebuild is lazy |
| `battle_dock_open_ms`, `dock_day_step_ms` (`perf_ui`) | gpu | as today | unchanged | the moved widgets (BB8) |

If `battle_rebuild_ms` passes its limit: keep the last rebuilt `CombatState` per battle in the cache across versions while
`b.day` and the world luck state are unchanged. If `board_open_ms` passes: the log and the legend fill on the frame after.

---

## 9. Risks

- **The split moves the luck (R1).** The digest fixture over 500 seeds is the first thing BB1 writes, from the M7 code,
  before any change; `fight` is built on the split so there is one path.
- **A live battle blocks the game.** A bug that leaves a battle live with no board is a soft lock. The guard's refusal words
  name the battle; the task flag line and the war badge open the board; the monkey checks "no live battle without a board".
- **The season pause is a new kind of save** (in season). Its tests save on days 0 and 2 of a wait; the load path is one
  function; a damaged `season_stage` is refused, not guessed.
- **The moves build is written in parallel.** Section 3.6 is the contract; if its spec fights computer battles at engage,
  R21 and the bands break. The planning session reads both specs side by side before either build starts (plan, review).
- **Orders change later luck.** Two players' choices in one battle change every later draw. Accepted (the log replays it);
  the owner accepted reloading for other dice (answer 7).
- **Ten clicks a battle tire the player.** Auto to the end, "Auto this season's other battles", the Options' Auto and D17
  keep it light; the playtest measures it.
- **The triangle words mislead.** They come from the hit's own factors and are tested against them over every pair.
- **Three lanes may feel thin.** It is v1 on purpose (audit R6); M24 adds width, back slots, rotation and cards on this seam.

---

## Appendix A. Amendments to earlier specs

| Spec | Section | Amendment |
|---|---|---|
| m7-build-spec.md | 4.6 (the day, stances fixed, withdraw on day 2), 5.3 (`Combat`), 5.2 (`Battle` never saved at idle), 6.5 (the dock opens only finished battles) | R1 to R7 (split, orders, `>=` withdraw); R8 (`battle/2`, live at idle); D4 (the board for live battles) |
| m3-build-spec.md | 4.10 (the body), 5.4 (the action log, the replay) | `season_stage`; `battle_day`, `battle_auto` records; `LogBattleOrders` (R23) |
| m8-build-spec.md | 4.2 (the season's slices), 4.15 (replay of AI orders) | the battles phase is sliced too (R18); the battle hook beside the orders hook (R19) |
| ui-family-audit.md | 4.2 to 4.5, Q4 to Q9 | the board is its own screen (D4, D5); orders include targets (D1); saving allowed in the board (D7); End-turn battles in the battles phase (D6) |
| moves-in-the-month.md | 2.6 "battles are fought in the order they happen, not in hex order"; group B "battle/2 and the format number" | idle battles in the order played; End-turn battles in hex order in the phase; `battle/2` is this build's (R46) |
| ui-and-controls-spec.md | bindings | the board's keys (R41) |
| fog-build-spec.md | R22 (battle view access) | unchanged; `of_live` and `BattlePlan` follow it (R24, R28) |

## Appendix B. Mockups to approve before the build (gate BB0)

Made as the tile window's were (artifact pages, code-drawn look, Studiolo tokens, 1280 x 720 and a 2x crop), one battle
throughout (Savoy against Milan at Cerano, 4 against 4 companies, day 3), reviewed by the art director and the creative
director before the owner sees them.

| # | Mockup | What the owner decides |
|---|---|---|
| MK1 | **The board's layout**: A, the dock in live mode (420 px on the left, map beside it); B, a board window over the shaded map (the Python panel's place) | Q2: A or B |
| MK2 | **Day 1, the line-up**: three empty lanes each with its chooser, the matchup words, the usual pick marked | how a fill is chosen (list under the lane, or drag from the reserve) |
| MK3 | **A dawn mid-battle**: an open lane with its chooser, a gun's target chip open, the stance strip with the Withdraw hover, the triangle legend | the orders' look and words |
| MK4 | **The round card and the result card**: per-lane losses, dice, a broken lane, the triangle's sentence; won, withdrew and fled results | what a round says |
| MK5 | **Entry and exit**: the End-turn moment (the enemy's walk, then "Milan attacks your army at Cerano"), Esc's "Fight the rest automatically?", "Auto this season's other battles", the Options entry, the army panel's "Open the board" | Q4, Q5 |
| MK6 | **The regiment hover card** with its strong and weak lines | the card's lines |

## Appendix C. Later (not in v1)

- The computer choosing its stance by day (Q3, after the playtest; moves the bands).
- Width 3 to 7, back slots, rotation, battle cards (M24; this seam is their first slice).
- Generals and their traits on the board; field forts (sieges design section 6).
- A live view for witnesses; joining a live battle with a second army in your turn.
- "Ask only when the odds are not Hopeless or Overwhelming" as a third Options value.
