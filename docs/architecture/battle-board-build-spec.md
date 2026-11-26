# Battle board build spec: battles played day by day on a board (issue 437, with 438)

Technical director, 2026-11-25. **Status: a proposal; no task starts before the owner's go, and no build task before the
mockups of Appendix B are approved (gate BB0).** The owner's answers of 2026-11-25 are recorded: the board is a window over the map (D5, R48), and the End turn's
battles are preceded by one question with a setting that turns it off (D18, D23, R47). **The owner's answers of 2026-11-26
and 2026-11-27 are recorded too: version 1 is watch only (D1) and battles should aim for about 10 rounds (D24, section
1.3).** Builds section 4 of `docs/design/ui-family-audit.md` ("the audit") **as the
owner answered it** (2026-11-24: play my battles on the board with Auto one click away; the deeper orders; save anywhere;
decide issue 432 first), on top of the moves build of issue 432 (`docs/design/moves-in-the-month.md`, "the moves design";
its build spec `moves-build-spec.md`; the moves build ships first, the owner's answer of 2026-11-25). Where the audit or the moves design say something else, this
page wins for the build. The tasks are in `battle-board-build-plan.md`. Appendix A lists the specs this page amends.

**What it is, in one paragraph.** A battle the player is a side of is no longer fought out of sight: it is shown on a
**board**, one **round** (a day of the fight) at a time. **Version 1 is watch only.** The line-up, the refills, the stances
and the fire of guns and crossbows are automatic, as today. At each dawn the player sees both armies exactly, the lanes, the
reserve and the matchups of the unit triangle (pikes hold horse, horse rides down shot and guns, shot and guns wear down
pikes from the back). **Next round** plays the day; a **round card** says what happened; **from the second round** the player
may **Withdraw**, at the price today's rules set; and **Auto to the end** is always one click away. A battle opened by the
player's own move (issue 432) is fought at once; a battle the computer starts at End turn is fought in the season's battles
phase, which pauses for it, after one question: "Fight your N battles automatically?" (D23, R47). The computer's side, and
every battle nobody plays, use the default orders, which give **exactly** the fight of the M7 code on the committed numbers:
the same frames and the same luck draws. A battle is a pure function of its input, its luck state before day 1 and the
orders, so it replays exactly and a save taken at any dawn (even inside End turn) reloads to the same dawn. The orders of
`docs/design/battle-orders.md` (stances by day, fills, gun targets, leave a flank open, presets, tactics) are **later**
(Appendix C).

**The battle board build is done when:**

1. Every rule R1 to R48 holds, each with its GUT case and its planted fault (P) of section 7 (R3, R4, R34 and R35 are not
   built in v1).
2. **Default orders are the identity:** over seeds 1 to 500 of the bands fixture, `Combat.fight` built on the split gives
   the same frames, end and luck state as the unsplit code recorded before BB1 on the committed numbers
   (`test_combat_split.gd`; the 10-round retune of D24 lands before that recording); the split moves none of
   `test_combat_bands.gd`, the soak's ranges or an AI test.
3. A battle left by Withdraw replays frame for frame from its record (`Combat.replay`), and a game with battle orders
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
| Deploy fills each empty open lane from the reserve in `FILL_ORDER` (centre, left, right) by `_pick` (infantry centre, cavalry flanks, missile and artillery last, then defence, then lowest id); a company moved up after day 1 is shaken | `combat_day.gd` `deploy`, `_pick` | v1: the line-up and every refill stay automatic (R3) |
| Fire: every ranged company in the reserve shoots; bombards at the enemy centre, crossbowmen at `FILL_ORDER[k mod 3]`; fallback `target_at` (that lane, then 1, 0, 2) | `combat_hit.gd` `fire`, `target_at` | There is **no target order** today, and v1 adds none (R4; later, Appendix C) |
| Stances: input `stance.att` is always `attack`; `stance.def` is `hold` or the defender's standing `withdraw`; fixed for the whole fight | `battles.gd` `input_of` | v1: the human side's one change of stance is to Withdraw (R5); the AI keeps M7's fixed stance (D9) |
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
| The battle panel's place | A window over a shade of the map, centred, up to 1240 x 880, closed by Esc or a click outside | Layout B of MK1, decided 2026-11-25 (D5, R48); Esc asks instead of closing (D8) |
| The field | Enemy back line and reserve at the top, enemy lanes, a dashed front line with crossed swords, our lanes, our reserve at the foot; band labels ("left flank"); cards shrink when a reserve is long | **Ported** as is (R32), our side at the foot; the shrink is the body's scroll at R39's sizes |
| The morale bar | A tug of war of front morale, each country's name and percent on its own fill, ink chosen by the fill's lightness, a gold middle tick | **Ported** (the dock's tug bar already has it), plus the flee line |
| "Your orders this season" | Attack, Hold, Withdraw as three choices with the reason when refused; two lines of what the stance does; the Withdraw price in its hover | **Only Withdraw in v1** (R33, R29): offered at every dawn from the second round, its price in the hover; Attack and Hold are not chosen on the board |
| "When attacked, with no order given" | The standing order (Hold, Withdraw) set in the panel | **Not on the board**: it stays on the army panel (M7 B26); the board shows it as the defender's stance |
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
| The orders of each fought day: the human side's `{}`, or `{stance: "withdraw"}` | `Battle.orders`, then `BattleRecord.orders` | yes | `BattleLive.play_day` |
| Days fought | `Battle.day` | yes | the same |
| The working state at today's dawn (lanes, reserve, morale, routed) | `CombatState`, rebuilt by re-fighting | **no** (a cache) | `BattleLive.state_of` |
| What the player has not yet sent | nothing to hold in v1: a button sends its action at once | no | the board; nothing reaches the game before Next round, Withdraw or Auto |
| What the season waits for | `game.season_stage` (`&"battles"`) | yes | `BattleLive` (through `Battles.season_step`) |
| Who gives orders in the phase | `game.battle_orders` (a hook) | no | the shell (`BoardHook`), the replay (`LogBattleOrders`) |
| The finished battle | `BattleRecord` (frames, end, orders) | yes (kept 60) | `BattleEnd.apply` |

Each round the player watches. At each dawn from the second round he may withdraw; Auto to the end is open at every dawn.
Nothing else (D1).

### 1.3 What controls how long a battle lasts, and the 10-round target

**The owner's target (2026-11-26 and 2026-11-27): a battle should aim for about 10 rounds** (D24). This section is read from
the code and `data/defs/war.tres`; **no code and no number is changed by this page**, and the figures below are hand
estimates, not measurements. No mean battle length of the Godot fight is recorded in the docs; `godot/tools/war_report.gd` and
`godot/tools/probes/probe_calibrate.gd` print one. The studies of the Python fight, whose rules M7 ported, found about 4 days
(`battle-size-and-frontage.md` 2.5 and 2.6, `battle-plan-review.md` 2.2).

**What ends a battle** (`combat_day.gd` `finish`, in this order): a side has no man left; a side **breaks** (no reserve with
its centre or two lanes empty, or front morale under `flee_morale` 100 of 1,000); a side on Withdraw leaves at day
`withdraw_day` 2; at day `battle_days` 8 the side with the lower front morale withdraws.

**What sets the pace:**

| What | Where | Today |
|---|---|---|
| Morale lost by a company a day: `morale_per_loss` x the day's losses (permille of its men at dawn), plus a flat drain, divided by its rank | `combat_day.gd` `morale` | 5 x losses; +20 in a lane, +30 in the reserve, +30 when unfed |
| Extra morale blows | `combat_day.gd` `_breaks` | a broken flank costs the centre 100 a day; a newly broken centre costs every company in the reserve or lanes 250 once |
| The size of a hit: base x target's full men x attack / defence x the striker's share of men x both stances x pikes or flank x shaken x ground x die x spread | `combat_hit.gd` `hit` | bases: shock 80, back line 40, crossbows' fire 25, bombards' 50 permille; die 700 to 1,400; spread plus or minus 500 |
| The morale a company brings | the army | its current morale (500 or more to attack); a garrison 1,000 |
| Numbers | the armies | a bigger reserve lengthens a battle |

**An even example today** (companies of 500 pikemen, farmland, attacker on Attack, defender on Hold, middle die and spread):
each company loses about 32 men a day (6 %), so about 340 morale a day (5 x 63 + 20). From full morale it is under the flee
level on the **third** day; reserves add days.

**What a 10-round target changes** (to be measured and tuned; open question 7 of the plan):

1. **The day cap must rise above the target** (proposed 15). Raising it alone changes nothing: battles end by morale long
   before. Two code constants also hold it at 8, `WarDef.MAX_BATTLE_DAYS` and `BattleRecord.MAX_DAYS` (validation and the
   record's load checks), so this is a code change as well as a data change.
2. **The pace must slow to about a quarter to a third** (about 90 to 100 morale a day instead of about 340). Two ways:
   - **Smaller hits (recommended):** every hit base at about a quarter to a third (for example shock 80 to 20 to 24, back line,
     crossbow fire and bombard fire in step), and the per-day flat drains (20, 30, 30, flank 100) at about a third. In the
     example a shock of 20 gives about 10 to 11 days and 24 about 9; the men lost in a whole battle stay near today's.
   - **Less morale per loss** (`morale_per_loss` 5 to 1, hits unchanged): also near 10 days, but the men lost roughly triple
     (towards half of an army). Not recommended.
3. **If the flat drains stay as they are,** ten rounds make them much heavier: a company waiting in the reserve loses 300
   morale (plus 300 when unfed) before it fights, and one broken flank can take the centre's whole morale.
4. **What else moves:** the pass and river penalties last one day, so they weigh less; the shaken day weighs less; more dice
   average out, so the stronger side wins more reliably (the bands move; 4 against 2 on farmland already reads 100 %); a
   defender on the standing Withdraw still leaves at day 2, now after much smaller losses, so that withdrawal gets cheaper;
   small hits round down (a battery of 100 men); a battle takes about 2.5 times the luck draws; records hold more frames; the
   day-step and rebuild times grow (section 8).
5. **What must be measured and pinned again:** `test_combat_bands.gd`, the worked hit of M7, `test_war_defs.gd`, the days 1
   to 8 cases of `test_combat_props.gd`, the odds words' bands, the war report, the soak and AI ranges. One `WarDef` serves
   every battle, so the computer's battles change with the player's.
6. **Order:** the retune lands **before** BB1 records the identity digests (plan task BB15, proposed).

---

## 2. Decisions taken

Q1 to Q10 are the owner questions of `battle-board-build-plan.md`, section 9. Q2 and Q4 were answered on 2026-11-25 (D5,
D18, D23) and Q1 on 2026-11-26 and 2026-11-27 (D1: watch only); the others stay open, and each decision that names one is its
recommended answer and changes if the owner answers otherwise.

| # | Question | Decision | Why |
|---|---|---|---|
| D1 | The orders of v1 | **Watch only** (owner, 2026-11-26 and 2026-11-27): no stances, no fills, no targets, no presets; the line-up is automatic; the player watches the rounds and may withdraw from the second round (D10), or press Auto (D11). The order packages A, B and C of `docs/design/battle-orders.md` are **not chosen for v1** and are later work (Appendix C), as are rotation, width, back slots and cards (M24) | The owner's answer; it replaces the earlier "stance, fills and gun targets" |
| D2 | Luck | **One stream** (`game.luck.world`), as M7. No per-battle stream. A live battle's days are contiguous on it because nothing else may act while it is live (R10) | Keeps "default orders are the identity": M7's frames, the bands, the soak and the AI tests do not move. A per-battle stream would re-base all of them |
| D3 | What is saved of a battle in progress | Its **input, luck state before day 1, orders so far and day count**; the `CombatState` is never saved: it is re-fought on demand (R11) | The audit 4.4 and the owner's answer 7; a fight is a pure function of those |
| D4 | Board or dock | A new screen **`BattleBoard`** for a live battle; the dock stays the review of a finished one. Both build from shared widgets moved out of the dock (BB8) | One job per screen; the dock's tests stay; the board's size is the mockup's choice (D5) |
| D5 | The board's size and place | **A window over the map** (the owner's answer to Q2, 2026-11-25): a board window over the shaded map like the Python battle panel, centred, at most 1100 x 680 logical, the battle hex glided into the visible strip; not the dock. The dock in live mode is dropped. The window lies over the map and the right-hand dock column alike (R48); the dock stays the review of a finished battle | The owner asked to port the Python battle UI; fills, targets and the triangle need width |
| D6 | When a battle is fought | **Opened at idle by the player's own action:** at once, on the board, before anything else. **Opened during End turn** (the computer's at-once marches, standing marches in the movement phase, storms): in the battles phase, in hex index order, the season **pausing** at each one the player is a side of | Moves design 2.6 and the audit 4.3; hex order keeps the bands and the AI's battles as M7; the computer never waits for the player inside its turn |
| D7 | Saving during the End-turn pause | **Allowed.** The game is at a clean point (AI orders and movement done, earlier battles settled); `game.season_stage = &"battles"` is saved and a load resumes the pause | Owner answer 7 ("allowed anywhere") |
| D8 | Leaving a battle undecided | **Never.** Esc and Close ask "Fight the rest automatically?"; the only ways out are a battle's end or Auto | A battle at idle blocks every other action (R10); an undecided battle would block the game |
| D9 | The computer's orders | **Default orders**: its input stance all battle (attacker Attack; defender its standing Hold or Withdraw), `_pick` fills, today's fire targets | Owner rule "AI battles resolve with the same rules"; results and soak ranges stay measured. A per-day AI is Q3 |
| D10 | Withdraw | The player's one order. Offered at every dawn **from the second round** (`withdraw_day`) when the side has a retreat; the army **leaves at the end of that round**. The rest is today's rule, taken as the default: the price (5 % of the men, 10 % as the attacker, morale set to 250), the retreat needed, a break or a wipe in the same round going first, and the round fought on the withdraw stance's numbers | Owner: "may withdraw from the second round". Today's code leaves only at the end of day 2, so the build widens it to any round from 2 (R5) |
| D11 | Auto | One click: plays the remaining days with default orders (the input's stances; it never orders a withdrawal) | The audit 4.3; one rule for "Auto to the end", the Options' Auto and a missing order |
| D12 | A missing order | Means the default order. A day with no logged order replays with the default | The Options' Auto, the setting off and a trimmed log all replay right with no record |
| D13 | Who is human | `game.player` only (one player). With `game.player == &""` (AI-only, watch, sandbox) no battle is ever live and no phase ever waits | The soak, the AI tests and the oracle-style replays see M7's game |
| D14 | Witnesses | No live view for a country that is not a side; it sees the finished record as today | Fog rule unchanged (fog spec R22); a witness of a live battle cannot exist at idle in v1 |
| D15 | Per-round results | Derived in a view from consecutive frames (men per company) and the dawn lanes; **no new frame key** | The record stays M7's form apart from `orders` |
| D16 | The triangle on the board | A matchup word (Strong, Even, Weak) and its reasons for each facing pair, computed from the same functions the hit uses (`attack_value`, `defence_value`, `extra_of`, `ground_mult`) with the dice and spread left out. Information only (Q8) | Visible, honest and never out of date with the data |
| D17 | A battle with nothing to watch or choose | A battle whose human side is a lone garrison (no reserve, no retreat) is fought at once with defaults and named in the report (Q9 asks about other battles with no retreat) | No board of many Next-round clicks with no choice |
| D18 | Several battles in one End turn | Each opens in hex order, after **one question before the first**: "Fight your N battles automatically?" (the owner's answer to Q4, 2026-11-25; D23, R47). The footer has no "Auto the rest" button; each board keeps its own **Auto to the end** ("Auto this one") | The owner: "Auto all battles at the end of turn is a hit"; a question before it runs, not a button inside a battle; Q4 is answered |
| D19 | The Options entry | "Your battles": **Play on the board** (default) or **Auto**; a second row "Battles at End turn" (ask, auto, board) belongs to D23 | The audit's option, in two values; Q5 |
| D20 | Format | `SaveFile.FORMAT` up by one with `OLDEST_FORMAT` the same (older refused quietly, as the fog build). If the moves build's FORMAT bump is merged but not released, the board rides it (one bump for the release) | One release at a time; no save from an unreleased format must load |
| D21 | Ownership of the seam with the moves build | Section 3.6: the moves build opens battles and owns movement points; this build owns the fight, the live state, the orders, the pause, the board and the saved battle | Group B of the moves design shares the saved battle; one owner per file avoids a collision |
| D22 | Task IDs | `BB0` to `BB15` | T, F, FG, K, TW, B, C, L are taken |
| D23 | The End-turn prompt (the owner's answer, 2026-11-25) | At the first wait of the battles phase, when the player is a side of one or more battles in it that need a choice (not D17's lone garrisons), one question: "Fight your N battles automatically?" ("Fight your battle automatically?" for one) with **Yes** (every one runs on Auto, logged `battle_auto`, named in the report), **No** (each opens on the board in hex order) and a box **"Don't ask again"** that keeps the answer as the setting `game/battles_at_end` (`ask` default, `auto`, `board`); an Options row "Battles at End turn" turns it back to `ask`. Not shown when "Your battles" is Auto (D19) or the setting is not `ask`. The moves build (MV21) builds the setting, the row and the widget, dormant because every battle is automatic there; this build gives `BattlesAtEnd.count` its value, gives No its effect and shows the row | "Auto all battles at the end of turn is a hit. Ask before it runs all, with a notification that can be turned off."; the box is the planner's reading of "turned off" (it keeps the answer you gave) |
| D24 | Battle length | **About 10 rounds** (owner, 2026-11-26 and 2026-11-27). A data retune with a higher day cap, for every battle, made and measured before the split's digests (section 1.3, task BB15, Q7) | The owner's target; today a battle ends after about 3 to 4 days and is capped at 8 |

---

## 3. The rules

"P" names the planted fault the test must catch. "Human side" is the side whose tag is `game.player`. Paths are under
`godot/`.

### 3.1 The combat seam (core/systems)

- **R1** **The split.** `Combat.begin(war, input, rng) -> CombatState`, `Combat.play_day(st, orders) -> frame`,
  `Combat.finish(st) -> end`. `Combat.fight` is `begin`, then `play_day(st, [{}, {}])` until `st.over` or `battle_days`,
  then `finish`: the one code path. With all-default orders the frames, the end and the `Rng` state after the fight equal
  the unsplit code's for seeds 1 to 500 of the bands fixture (digests recorded before the split, on the numbers of D24, kept
  as a fixture). P: a split that draws once more a day; a frame key in another order.
- **R2** **Orders.** In v1 one side's orders for one day are `{}` (default) or `{stance: "withdraw"}` (absent: the side's
  stance of the day before, or the input's on day 1). `play_day` takes `[attacker, defender]`. `CombatOrders.normal(orders)`
  gives the canonical form (no empty parts) that the record and the digest keep. Later orders add keys beside `stance`. P: two
  equal orders whose normal forms differ.
- **R3** **Fills.** Not in v1 (D1): deploy and every refill are M7's (`_pick` in `FILL_ORDER`; a company moved up after day 1
  is shaken). Later (Appendix C).
- **R4** **Targets.** Not in v1 (D1): guns and crossbows fire as today (bombards at the centre, crossbowmen at
  `FILL_ORDER[k mod 3]`). Later (Appendix C).
- **R5** **Stance and Withdraw.** The day's stance of each side is used for that day's hits (`stance_dealt`, `stance_taken`).
  A side whose stance is Withdraw and that has a retreat leaves at the end of the **first** day `>= withdraw_day` (today:
  `==`); both sides on Withdraw: the lower front morale, as today. The player's only stance change in v1 is to Withdraw
  (either side, attacker included), from the second round. The check refuses it for a side with no retreat ("no hex to fall
  back to from Cerano"); the input's silent "withdraw without retreat is hold" stays for the computer's input. P: a Withdraw
  on day 3 that does not leave; a standing day-1 Withdraw that leaves on another day than M7's.
- **R6** **`CombatOrders.check(st, side, orders) -> {ok, reason}`** is pure and names every refusal in words: an order other
  than Withdraw ("not in this version"); Withdraw before the second round ("you can withdraw from the second round");
  Withdraw with no retreat. P: each refusal planted once.
- **R7** **The record.** `BattleRecord` gains `orders: Array` of `{day, side, orders}` (normal form), the human side's
  only, in play order; `battle-record/2`. `Combat.replay(war, record)` re-fights with them. A record with no orders
  replays as M7. P: a replay that drops a day's withdrawal.

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
  phase that is the same moment M7 builds it; at idle it is the moment the player first presses Next round (or Withdraw or
  Auto).
- **R14** **The actions.** `battle_day {hex, stance, tag}` (`stance` absent, or `withdraw`) and `battle_auto {hex, tag}`
  join the table of `core/game/actions.gd` with their checks
  (`BattleLive.day_check`/`battle_day`, `auto_check`/`battle_auto`). `day_check`
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
  P: an AI side given the player's withdrawal.

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
  (`Combat.odds_card` on the current men and morale); the **Withdraw** option with its state, reason and price text; the dawn
  lanes of both sides (holding company, open, closed, broken); the last day's round (R27); the log so far; `more_waiting`
  (other wanted battles this season). P: a Withdraw offered that the check refuses.
- **R25** **The coming day of the other side is never shown.** The plan holds the computer's stance of the days fought
  (from the frames' input stance; exact for a side, as M7) and nothing about its coming day. P: the computer's next stance
  or orders in the plan.
- **R26** **The triangle, visible.** `BattleMatchup.of(war, st, striker, target, flank)` gives `{permille, word, tone,
  reasons}` for one company against another from `attack_value`, `defence_value`, `extra_of` and `ground_mult` (no dice, no
  spread, no draw): the ratio against an even pair of the same men; `word` Strong (at least 1250), Even, Weak (at most 800);
  `reasons` the named factors that apply, each with its signed percent and tone ("Pikes against horse +25 %", "Horse in the
  open +40 %", "Horse in rough ground -30 %", "Guns against walls x2", "Veteran +10 %", "Uphill -5 %"). The plan gives it for
  each facing lane pair.
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
- **R29** **Prices**, from `WarDef`, in the Withdraw hover: "leaves at the end of this round (the second at the earliest):
  5 % of your men (10 % as the attacker) are lost and
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
- **R33** **The footer** (watch only): **Next round** (primary, "Next round: 3"), **Withdraw** (disabled on round 1 and with no
  retreat, its reason as tooltip; its price in the hover, R29), **Auto to the end** (the owner's "Auto this one", one click;
  there is no button for the other battles, the question of D23 covers them, and `more_waiting` shows only as a quiet line "1
  more of your battles waits"). No stance switch. How the rounds advance is Q6; the default is one click a round. P: a
  Withdraw button enabled on round 1.
- **R34** **Fills.** Not in v1 (D1). Later (Appendix C).
- **R35** **Targets.** Not in v1 (D1). Later (Appendix C).
- **R36** **Next round** sends `Session.act("battle_day", {hex})`; **Withdraw** sends `Session.act("battle_day", {hex,
  stance: "withdraw"})`, which plays that round and ends the battle (Q10: whether it asks first; the default is no extra box).
  The round then plays as the dock plays a day (dice, hits, the tug bar), 0.6 s, instant under reduce motion; the round card
  shows; then the new dawn. A refused act toasts its reason and changes nothing. P: a second act before the day's draw is
  over.
- **R37** **The result card**: who won and how (broke, withdrew, fled, wiped out, held to the last day), killed and wounded
  each side, the retreat hex or the surrender, the storm and sack, and "Review in the dock" (opens the finished record).
  Close returns control to the flow (R44).
- **R38** **The hover rule** (tile window R37): every icon and every number on the board explains itself: a tooltip on each
  chip, die, morale bar, lane label, figure, rank pip, the odds word and each button (a disabled one keeps its reason); a
  hover card (`RegimentCard`: kind, men of full, attack and defence, rank and its bonus, morale, fed or hungry, what it is
  strong and weak against from `BattleMatchup.legend`) on every regiment. `test_board_tips.gd` walks day 1, a mid-battle
  dawn and the result, and fails on a control without one. P: a regiment with no card.
- **R39** **Sizes.** Every text on the board is 15 logical pixels or larger (the `Body` style and up). The board lies inside
  the viewport at 1280 x 720 scale 1, 2560 x 1440 scale 2 and 1920 x 1080 at UI scales 1.25 and 1.5, with a full battle (8
  companies a side, three lanes, a garrison); the body scrolls, the footer is pinned. P: a label under 15; a board taller
  than the viewport.
- **R40** **Style.** Studiolo tokens only, 2D code-drawn art (the dock's picture, figures and ink), no downloaded or baked
  file, no `Color(` literal, no `theme_override_` in `.tscn`. New widgets go to `shell/screens/battle/` with their own test.
- **R41** **Keys** (`shell/input/bindings.gd`, rebindable): Enter or Space Next round; Shift+W Withdraw (proposed); Shift+A
  Auto to the end; Esc the confirm of R31. While the board is
  up, map keys that would act (End season, march, raise) do nothing (the guard refuses them anyway). P: Space reaching End
  season under the board.
- **R42** **Openers.** A live or waited battle opens the board from: the army panel's "In battle: X · Open the board"
  (`army_war.gd`), the Town tab's battle row, the map's war badge on that hex, the task flag line. A finished battle still
  opens the dock. P: a live battle's badge opening the dock with no record.
- **R43** **The Options entry** "Your battles" (`battles`: `board` default, `auto`). With `auto`, `BoardHook.wants` is
  false (the phase fights them with defaults: D12) and a battle that becomes live at idle is sent `battle_auto` at once
  (logged) and its result shown as a toast with "Review" (opens the dock). With `board`, the End-turn question of R47 applies.

### 3.6 The flow, the saves and the moves seam

- **R44** **Session and SeasonFlow.**
  - `Session.drain` emits `Events.battle_waiting(hex)` once when `BattleLive.live(game)` becomes non-null at idle (after
    the move that opened it, after a load); `Session.finish_step` returns false and emits it when `season_step` waits.
  - `Session.act` and `check` accept `battle_day` and `battle_auto` while the season waits (the only exception to "wait for
    the season to end"); everything else keeps that refusal.
  - `SeasonFlow` gains **BATTLE**. In End turn: RUNNING until the wait; then REPLAY of the walks recorded so far (the
    enemy's march onto the hex; skippable); then, at the first wait only, the prompt of R47 when it applies (Yes runs every waiting battle on Auto and the
    flow goes on; No goes on to the board); then BATTLE (the board); when the battle ends, RUNNING resumes `finish_step`
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
| The End-turn prompt (R47) | MV21 builds the setting `game/battles_at_end`, its Options row (hidden), the widget `AutoBattlesAsk` and `BattlesAtEnd.count` (0 until the board); no prompt is shown, battles at End turn are fought automatically | Gives `count` its value, gives No its effect (the board) and shows the Options row |

  P: a battle fought inside the computer's orders phase (`test_battle_season_wait.gd` drives an AI march into the player's
  army and checks no record exists before the battles phase).
- **R47** **The End-turn question** (D23). `BattlesAtEnd.count(game, viewer)` (`core/views/battles_at_end.gd`, built by the moves
  build's MV21 and returning 0 there) gives the number of the player's battles in the battles phase that need a choice (a side
  of the battle, D17's lone garrisons not counted). At the first wait, when it is 1 or more, the setting is `ask` and "Your
  battles" is not Auto, the shell pushes `AutoBattlesAsk` (a `Confirm`): "Fight your N battles automatically?" with Yes, No
  and the box "Don't ask again". Yes sends `battle_auto` for each of the player's waiting battles in hex order (logged; the
  report says "You fought N battles automatically"); No opens the first on the board, the rest in hex order as D6 says. With
  the box ticked the answer is kept as `game/battles_at_end` (`auto` for Yes, `board` for No); the Options row "Battles at End
  turn" (Ask me, Fight automatically, Play on the board) sets it back. The question is a setting and a shell widget: nothing is
  saved in the game, nothing is drawn from luck, and a save made while it is up reloads at the same wait. P: a question with a
  count of 0; a box that keeps nothing; a question shown with the setting `auto`; Yes that leaves one battle for the board.
- **R48** **The window and its seam with the docks** (D5). The board is a `Screen` over the map: a shade over the whole viewport
  (map input blocked), the board centred over the map and the right-hand dock column alike, at most 1100 x 680 logical and
  shrunk to the viewport minus `Tokens.S2` on every side; the battle hex is glided into the visible strip by the camera. It does
  not resize or move any dock: the tile window (440 x 640, `tilewin-build-spec.md` R33) keeps its state under the shade and is
  as it was when the board closes. The finished-battle dock (the 420 px left overlay) is a separate surface: "Review in the
  dock" closes the board and opens the dock on the record. P: a board wider than the viewport at 1280 x 720; a tile window that
  changes tab or size while the board is up; "Review in the dock" that leaves the board open.

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
const STANCES: Array[String] = ["withdraw"]                   # the orders a player may give in v1
static func check(st: CombatState, side: int, orders: Dictionary) -> Dictionary      # {ok, reason} (R6)
static func normal(orders: Dictionary) -> Dictionary                                   # canonical form (R2)

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
static func day_check(game: Game, args: Dictionary) -> Dictionary        # battle_day {hex, stance, tag}
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
#   morale, front, colour}, odds: {word, value}, withdraw: {ok, reason, price},
#  lanes: {ours: Array[L], theirs: Array[L]},   L = {lane, state: &"held"|&"open"|&"closed"|&"broken", company: {} | C,
#   matchup: {} | M},   C = {key, kind, name, figure, men, full, morale, rank, rank_name, shaken, hungry},
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
func fight_day() -> bool                                                 # Next round
func withdraw() -> bool
func auto_rest() -> bool
func shown_day() -> int
# shell/screens/battle/ (new widgets; the first four moved out of the dock in BB8)
#   battle_field.gd, tug_bar.gd, day_log.gd, dice_row.gd, orders_strip.gd (the footer),
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
| The enemy's orders for the coming day | **never** (R25) | Orders are given at the same dawn by both |
| Another army marching to join | no (not in the plan) | Joins happen in the movement phase, before day 1 |
| Witnesses, other battles waiting | the count `more_waiting` of the player's own | Own battles only |
| A battle you are not a side of | no board, no live view (D14) | Fog rule: battles you are not in are hidden in light fog |

---

## 6. Sketches

The approved mockups (Appendix B) fix look and spacing; this sketch fixes the order of parts (layout B, the window, decided 2026-11-25).

```
+--------------------------- Battle of Cerano, Spring 1481 ------------------------- [look] [x] +
| [Savoy arms] Savoy  4,000 of 4,500  morale 72%   ODDS: EVEN   Milan 3,200 of 3,500  [Milan]  |
| tug bar: front morale  ######|#####------------ flees under 10 %           Round 3              |
| ground: [farmland] [river crossed: -20 % day 1] [uphill -5 %]                                  |
+-----------------------------------------------------------------------+-----------------------+
|  MILAN reserve   [xb 480] [bm 100]                                    | Round 2               |
|  MILAN lanes     [ L: kn 230 ]  [ C: pk 410 ]  [ R: pk 380 ]          | Savoy lost 240 (L 90, |
|  --------------------------- front line ----------------------------- |   C 150), Milan 310   |
|  SAVOY lanes     [ L: open   ]  [ C: pk 470 ]  [ R: kn 240 ]          | Your left gave way.   |
|                                                                       | Your pikes held their |
|                                                                       |   knights: +25 %      |
|  SAVOY reserve   [kn 250] [bm 100]                                    | dice 4 (x1.1) - 2     |
|                                                                       | Log ...               |
|  TRIANGLE  pikes hold horse . horse rides down shot and guns . shot and guns wear pikes      |
+-----------------------------------------------------------------------+-----------------------+
| [ Next round: 3 ]   [ Withdraw ]   [ Auto to the end ]                    1 more of your battles waits         |
+-----------------------------------------------------------------------------------------------+
```

---

## 7. Tests

All under `godot/tests/`. Every edited test keeps its planted faults; a task may not delete a P without replacing it.

### 7.1 New tests

| Test | Cases | Planted faults |
|---|---|---|
| `core/test_combat_split.gd` | the digests of seeds 1 to 500 against the fixture recorded from the unsplit M7 code before BB1, after BB15 (frames, end, luck state); `fight` = `begin` + `play_day` + `finish`; a record with orders replays equal | R1, R7 |
| `core/test_combat_orders.gd` | each refusal of R6; Withdraw leaving on day 2, 3 and 7; the attacker's Withdraw; `normal` | R2, R5, R6 |
| `core/test_battle_phase.gd` | the sliced battles phase equals the atomic one on the war rig's seasons; storms engage once; hex order; `LogBattleOrders` over a synthetic log | R18, R19, R21 |
| `core/test_battle_live.gd` | a battle at idle is live; the guard refuses each action of `Actions.NAMES` and End season; `play_day` freezes input and luck on day 1; rebuild equals; the rng mismatch ends a draw; the record keeps the orders; `fight_at` | R8 to R13, R15, R16 |
| `core/test_battle_actions.gd` | the check/act pair over 200 seeded random orders (nothing, Withdraw, and illegal ones) on 20 fixture battles: refused acts change nothing (digest), accepted ones play one day; `battle_auto` from each day equals `play_day` with `{}` | R14, D11 |
| `core/test_battle_season_wait.gd` | the sliced battles phase on a fixture with three battles (computer, player, computer by hex index): the wait at the player's, the hex order, nothing drawn in the wait; `Season.run` equals the sliced run with no hook; `LogBattleOrders` replay equals the live run; an AI march into the player's army fights nothing before the phase (R46) | R18 to R22, R46 |
| `core/test_battle_save.gd` | `battle/2` round trip; save, load, save byte-equal at idle on day 3 and in the wait on days 0 and 2; the board's plan equal after load; the previous FORMAT refused; a damaged live battle refused | R8, R45 |
| `core/test_battle_plan.gd` | the plan of day 1 (Withdraw refused), a mid-battle dawn, a narrow ground, an assault, a lone garrison (D17); the Withdraw option agrees with `CombatOrders.check`; prices follow a changed `WarDef`; `{}` for a witness and a stranger; no coming enemy order | R24, R25, R29 |
| `core/test_battle_matchup.gd` | knights against pikes Weak, knights against crossbowmen in the open Strong, in woods not; bombards against walls; rank and uphill reasons; the word against the hit's factors over every branch pair, both fights | R26 |
| `core/test_battle_round.gd` | per-lane losses add up; broken lanes; routed; the sentences; day 1 from the input's men | R27 |
| `core/test_battle_door.gd` | the scan of R30 | one P per forbidden name |
| `shell/test_battle_board.gd` | opens on `battle_waiting`; parts in order; Next round sends no order; Withdraw is disabled on round 1 and sends the withdrawal; the round card; the result card; Esc asks; reduce motion; keys of R41 | R31, R32, R33, R36, R37, R41 |
| `shell/test_board_tips.gd` | the hover walk of R38 on day 1, mid-battle and the result | R38 |
| `shell/test_board_sizes.gd` | R39 at the four sizes and scales, both themes, a full battle; every label 15 or more | R39 |
| `shell/test_orders_strip.gd`, `test_round_card.gd`, `test_result_card.gd`, `test_regiment_card.gd` | each widget alone | a disabled Withdraw that sends |
| `shell/test_battle_wait.gd` | the flow with a fake board: the state walk of R44, act refused but for the battle actions, save in the wait and the resume, the Options' Auto | R43, R44 |
| `shell/test_battle_prompt.gd` | R47: the question with a stub count of 0, 1 and 3 (the words for one); Yes sends `battle_auto` in hex order, No opens the board; the box keeps `auto` or `board` and Options sets `ask` back; not shown with `auto`, with "Your battles" Auto or with a lone garrison; a save while it is up reloads at the same wait | R47 |
| `shell/test_battle_flow.gd` | headless app: a march into an enemy army (moves build) opens the board; three rounds and Auto, and a second battle left by Withdraw; IDLE again. End season with a computer attack: REPLAY, BATTLE, RUNNING, REPORT; save in the wait and load resumes; the Options' Auto | R42 to R44 |

### 7.2 Tests that move or change

| Test | Change | Task |
|---|---|---|
| `core/test_combat.gd`, `test_combat_props.gd`, `test_combat_hostile.gd` | `fight` through the split; a hostile orders case per R6 refusal | BB1 |
| `core/test_combat_bands.gd` | **unchanged by the split, must stay green** (the identity); BB15 sets its figures for about 10 rounds first | BB1 proves it |
| `core/test_battles.gd` | the phase through begin, steps and end; storms engage once | BB2 |
| `core/test_season.gd` | PHASES unchanged; the battles phase sliced equals atomic | BB2 |
| `core/test_replay.gd` | a log with `battle_day` at idle and inside a season | BB5 |
| `core/test_save_file.gd`, `test_war_save.gd` | FORMAT bump; `battles/2`; `season_stage` | BB5 |
| `core/test_battle_view.gd` | `of_live`; the round in the dock's model | BB6 |
| `core/test_owns.gd`, `test_no_other_writers.gd` | `season_stage`'s one writer; a Battle's live fields written only through `BattleLive` | BB4 |
| `core/test_invariants.gd`, `tests/core/invariants.gd` | at most one live battle; no live battle while in season unless waited; a battle's day 0 to `battle_days`; orders no more than days | BB4 |
| `shell/test_battle_dock.gd` | unchanged in what it asserts; the widgets moved (BB8) must keep it green | BB8 |
| `shell/test_season_flow.gd` | the BATTLE state; two replays; save allowed | BB7 |
| `shell/test_army_panel.gd`, `test_town_tab.gd`, `test_war_marks.gd`, `test_task_flag.gd` | "Open the board" for a live battle | BB10 |
| `shell/test_options.gd`, `test_settings.gd` | the `battles` entry | BB7 |

**Unchanged, must stay green:** every AI test, `test_ai_determinism.gd`, the soak's suites and ranges, `test_fog_views.gd`,
`test_tile_*.gd`, `test_snapshot.gd` (apart from the new body fields), `test_combat_bands.gd`.

### 7.3 Soak

A soak suite `orders` (`tools/soak.gd --suite=orders`): AI games where one country is given a seeded random
`BattleOrders` hook (a legal Withdraw on a random round, Auto sometimes) in place of the player. Invariants
every season (the soak's own and section 7.4's core ones); the game's log replays to the same digest at the end; its war
ranges are reported, not gated. The `ai`, `passive` and `europe` suites are unchanged and must give the same digests as
before BB1 (identity).

### 7.4 Monkey

**Monkey** (`tests/shell/monkey_board.gd`, extends the fog monkey): on a fixture where the player's armies stand next to
enemy armies at war, it marches into them (a battle at idle), sends legal and illegal orders (Withdraw on any round),
presses Next round, Withdraw, Auto, Esc then both answers, saves and loads at random dawns, ends seasons so the computer
attacks (the wait), answers the End-turn question both ways and switches the Options' entries. **Invariants each frame:** while a battle is live, every non-battle
action is refused and End season is refused; Withdraw is enabled exactly when `CombatOrders.check` allows it; the board shows
`BattlePlan.of`'s numbers; the rebuilt state's luck equals the world's; a battle has 0 to `battle_days` days
and no more orders than days; after save and load the digest and the plan are equal; the board is inside the viewport; no
board is up without a live or waited battle. **Counters** above 0: `board_days`, `board_autos`, `board_saves`,
`season_waits`, `board_withdraws`.

### 7.5 Pictures

`tools/ui/shot_ui_board.gd` (1280 x 720 scale 1, 2560 x 1440 scale 2, 1920 x 1080 at UI scale 1.5): round 1 with the
automatic line-up and Withdraw disabled; a mid-battle dawn with an open lane; the Withdraw hover; a
round card; a result card (won, withdrew, fled); an assault; a narrow ground; the End-turn "battle awaits" moment and the question "Fight your N battles automatically?"; the Esc
confirm; the Options entries; the army panel's "Open the board". **The owner is asked before any windowed run.** The art
director signs them against the approved mockups. Goldens that show the army panel, the Town tab's battle row or the dock
are made again and reviewed side by side.

---

## 8. Performance

BB3 records the baseline of the rows marked "as today"; BB13 adds the new rows and measures all; both tables in its pull
request.

| Row | Class | Limit | Expected | Note |
|---|---|---|---|---|
| `fight_ms`, `battles_ms`, `battle_view_ms`, `season_ms` (`perf_core`) | cpu | as today | within 5 % of BB3's baseline | the split adds no work on the default path |
| **new** `play_day_ms` (`perf_core`) | cpu | 0.5 mean | about 0.2 | one `BattleLive.play_day` of 8 against 8, rebuild cached |
| **new** `battle_rebuild_ms` (`perf_core`) | cpu | 2.0 worst | about 1.3 at day 7; more with longer battles | `state_of` from cold at the day before the cap (a load, a cache miss); the limit is checked again after D24 |
| **new** `battle_plan_ms` (`perf_core`) | cpu | 2.0 mean | about 0.6 | `BattlePlan.of` uncached at a mid-battle dawn |
| **new** `board_open_ms` (`perf_ui`) | gpu | 16 | under 10 | the board from `battle_waiting` to its first full draw, 8 v 8, worst of 3 |
| **new** `board_day_ms` (`perf_ui`) | gpu | 16 | under 8 | Next round to the next dawn drawn, reduce motion, worst frame |
| `save_ms`, `load_ms` | cpu | as today | within their limits | a live battle adds one input and one order entry a day; the load's rebuild is lazy |
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
- **A withdrawal changes later luck,** and longer battles draw more. Accepted (the log replays it);
  the owner accepted reloading for other dice (answer 7).
- **Ten clicks a battle tire the player,** all the more at about 10 rounds with one decision. Auto to the end, the End-turn
  question of D23, the Options' Auto and D17 keep it light; Q6 asks whether rounds play by themselves; the playtest measures
  it.
- **Watching may feel passive.** The only choice is when to leave; the round card and the matchup words must make the fight
  readable. The order packages stay ready for later (Appendix C).
- **The 10-round retune moves every battle** (D24, section 1.3): bands, soak, AI and odds are measured again before BB1.
- **The triangle words mislead.** They come from the hit's own factors and are tested against them over every pair.
- **Three lanes may feel thin.** It is v1 on purpose (audit R6); M24 adds width, back slots, rotation and cards on this seam.

---

## Appendix A. Amendments to earlier specs

| Spec | Section | Amendment |
|---|---|---|
| m7-build-spec.md | 4.6 (the day, stances fixed, withdraw on day 2, the hit bases and the day cap of 8), 5.3 (`Combat`), 5.2 (`Battle` never saved at idle), 6.5 (the dock opens only finished battles) | R1, R2, R5 to R7 (split, the Withdraw order, `>=` withdraw); D24 (about 10 rounds); R8 (`battle/2`, live at idle); D4 (the board for live battles) |
| m3-build-spec.md | 4.10 (the body), 5.4 (the action log, the replay) | `season_stage`; `battle_day`, `battle_auto` records; `LogBattleOrders` (R23) |
| m8-build-spec.md | 4.2 (the season's slices), 4.15 (replay of AI orders) | the battles phase is sliced too (R18); the battle hook beside the orders hook (R19) |
| ui-family-audit.md | 4.2 to 4.5, Q4 to Q9 | the board is its own screen (D4, D5); v1 is watch only, the deeper orders are later (D1); saving allowed in the board (D7); End-turn battles in the battles phase (D6) |
| moves-in-the-month.md | 2.6 "battles are fought in the order they happen, not in hex order"; group B "battle/2 and the format number" | idle battles in the order played; End-turn battles in hex order in the phase; `battle/2` is this build's (R46) |
| ui-and-controls-spec.md | bindings | the board's keys (R41) |
| moves-in-the-month.md | 2.6 ("the battle board (the live dock)") | a window over the map, not the dock (D5, R48) |
| fog-build-spec.md | R22 (battle view access) | unchanged; `of_live` and `BattlePlan` follow it (R24, R28) |

## Appendix B. Mockups to approve before the build (gate BB0)

Made as the tile window's were (artifact pages, code-drawn look, Studiolo tokens, 1280 x 720 and a 2x crop), one battle
throughout (Savoy against Milan at Cerano, 4 against 4 companies, round 3), reviewed by the art director and the creative
director before the owner sees them. **Reduced for the watch-only v1:** MK2 (the day 1 line-up with its choosers) is dropped;
five mockups remain.

| # | Mockup | What the owner decides |
|---|---|---|
| MK1 | **The board's layout** (decided 2026-11-25: a board window over the shaded map, the Python panel's place; the dock in live mode is dropped): the window at 1280 x 720 with the tile window's dock column behind its shade, the battle hex in the visible strip, and "Review in the dock" | the look and spacing only (Q2 is answered) |
| MK3 | **A dawn mid-battle**: both armies as deployed, the footer (Next round, Withdraw, Auto) with the Withdraw hover, the triangle legend; round 1's disabled Withdraw as a crop | how watching a round looks and reads |
| MK4 | **The round card and the result card**: per-lane losses, dice, a broken lane, the triangle's sentence; won, withdrew and fled results | what a round says |
| MK5 | **Entry and exit**: the End-turn moment (the enemy's walk, then "Milan attacks your army at Cerano"), Esc's "Fight the rest automatically?", the End-turn question "Fight your N battles automatically?" with its "Don't ask again" box, the Options entries, the army panel's "Open the board" | Q5 (Q4 is answered) |
| MK6 | **The regiment hover card** with its strong and weak lines | the card's lines |

## Appendix C. Later (not in v1)

- **The orders, not chosen for v1** (`docs/design/battle-orders.md`): package A (a stance each day: Attack, Hold,
  Withdraw), package B (fills and the day-1 line-up with presets, leave a flank open, one fire order or a target per ranged
  company: the earlier rules R3, R4, R34, R35) and package C (three one-shot tactics, a loss forecast).
- The computer ordering its stance or a withdrawal by day (Q3, after the playtest; moves the bands).
- Width 3 to 7, back slots, rotation, battle cards (M24; this seam is their first slice).
- Generals and their traits on the board; field forts (sieges design section 6).
- A live view for witnesses; joining a live battle with a second army in your turn.
- "Ask only when the odds are not Hopeless or Overwhelming" as a third Options value.
