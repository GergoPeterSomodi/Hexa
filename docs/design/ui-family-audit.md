# The unit, tile and battle screens: audit and plan (issues #436, #437, #438)

Game designer, 2026-11-24. **Status: a proposal for the owner. Planning only: nothing is built, no code touched.** One design
pass for the family the owner asked for together: what the last Python version (v0.2.2) had, what Godot has now, one uniform
tile window (#436), battles played round by round (#437) and the order to build it in (#438).

Read for it: `docs/roadmap/owner-asks-2026-11-23.md`, `docs/architecture/m6-build-spec.md` 6.5 and 6.8,
`docs/architecture/m7-build-spec.md` 4.6, 4.7, 4.13, 5.3 and 10, `docs/design/economy-rethink.md` 3.1 and 7,
`docs/design/battle.md`, `battle-size-and-frontage.md`, `docs/roadmap/release-0.2.1-brief.md` (the board's origin), and the
Godot shell under `godot/shell/` (panels, hud, screens, map) and `godot/core/` (systems, views).

## 0. The short answer

1. **Most of the Python screens are already in Godot, and restyled.** The gap is not a pile of missing panels. It is two
   things: the tile is shown by three different widgets (hex panel, hex menu, raise list), and a battle can only be watched
   after it is over.
2. **One tile window** (section 3) replaces the hex panel, the hex menu and the Raise tab. It has a stable header and a tab
   strip: Details, Build, Industries (M9.5), Army, Ships (M19). It is built **right after M7 closes**, before M8, so M9.5
   finds the Industries tab waiting.
3. **Round-by-round battles** (section 4) are the existing dock turned live. The fight is already a loop of days over one
   state (`Combat.fight` calls `_day` up to `battle_days`), so the board needs a seam, not a new battle model. The player
   orders each day (stance, which reserve fills an open lane) and presses Fight day. Every battle nobody plays, and the AI's
   side, stay exactly as M7 has them, so the soak and the replay tests do not move. Built **after M8**, before M9.
4. **Port little else.** A short list (section 2) is worth doing; the rest belongs to later milestones (markets M10, techs
   M11, ships M19, colonies M21) and is ported there, from the Python design, not from its code.

## 1. Inventory: Python v0.2.2 against Godot

"Exists" means the Godot screen does the same job in Studiolo style. "Partly" names what is missing. File names are in
`hexa/campaign/` (Python) and `godot/` (Godot). I read the headers and signal lists of the Godot files, not every line, so
a "partly" is a pointer for the build task to confirm.

| Python screen | What it shows and its controls | Godot equivalent | Status |
|---|---|---|---|
| `panels/province.py` | Owner, people, siege block, castle-area chips, the tile, buildings with slots, build rows | `shell/panels/hex_panel.gd` (668 lines), `hex_war.gd`, `HexCard`, `PeopleView`, `ImprovePreview` | Exists, richer (gives, worth, delta chips, work under way, cancel). Its tab strip is Works or Raise only |
| `panels/unit.py` | The stack, ticked units, supply, battle line, refit and drill buttons, ship cargo, found colony | `shell/panels/army_panel.gd` (746), `army_war.gd` | Exists (split, join, disband, order, supply, standing order, storm). Drill and refit wait for M11; cargo for M19; found colony for M21 |
| `panels/raise_.py` | Every kind of troop with cost and a hover card | `shell/panels/raise_list.gd`, a tab of the hex panel; the hex menu's "Raise companies here..." | Partly: rows, costs, reasons exist; the per-kind hover card (`cards.troop_card`) is missing |
| `panels/country.py` | Country page: treasury, wars, merchants, peace terms, research | `shell/panels/country_panel.gd`, `country_war.gd`, the Study pages | Exists for M2 to M7; peace terms M9, merchants M10, research M11 |
| `panels/market.py` | Goods table and trade routes, merchant orders | none | Missing, M10's job |
| `panels/ledger.py` | Countries ranked | Study page Rankings (`screens/study/page_rankings`) | Exists |
| `hud/battles.py` | Crossed swords badge on the hex, tug bar under it from zoom 3, click opens the panel | `shell/map/war_mark.gd`, `war_marks.gd` (badge, ring tone, front-morale bar) | Exists |
| `hud/odds.py` | Odds card on the attack hover: men, morale, ground, ONE word | `shell/hud/odds_card.gd`, `core/views/odds_view.gd` | Exists |
| `hud/movecard.py` | Why this hex cannot be taken | `shell/hud/move_card.gd` | Exists |
| `hud/siegebadge.py`, `sieges.py` | Amber dial badge, relief line, grey flash on a lift | `war_mark.gd`, `SiegeView`, `hex_war.gd` | Exists |
| `hud/tasks.py` | The "N things to do" flag | `shell/hud/task_flag.gd`, `core/views/reminders.gd` | Exists |
| `hud/actionlog.py`, `feed.py` | Filtered, collapsible log | `shell/hud/action_log.gd`, `core/views/log_lines.gd` (#431 reshapes it) | Exists |
| `hud/topbar.py`, `floating.py` | Resource chips, rising ribbons | `hud/top_bar.gd`, `chips.gd`, `map/floaters.gd` | Exists |
| `screens/battle.py`, `battlelayout.py` | One battle: title, ground, tug bar, three lanes a side, reserve, back line, sides, **orders for the season (Attack, Hold, Withdraw)**, dice, log | `shell/screens/battle_dock.gd` (627), `screens/battle/` (picture, regiment tile), `core/views/battle_view.gd` | Partly: everything but the orders. The dock steps through a **finished** battle (Earlier, Next, Play); the standing order sits on the army panel |
| `battleview.py` | The read model with the fog rule | `core/views/battle_view.gd`, `odds_view.gd`, `siege_view.gd` | Exists |
| `screens/gamemenu.py` | Pause, save, load, options | `screens/pause_menu`, `save_load`, `options` | Exists |
| `screens/techscreen*.py` | Tech grid, idea cards | none | Missing, M11's job |
| `replay.py` | Movement replay | `shell/map/move_replay.gd` | Exists |
| (none) hex menu | Python had no hex menu | `shell/hud/hex_menu.gd` (a PopupMenu: works, raise, armies, supply, battle, siege, castle area) | Godot only; folded into the tile window (section 3) |

Mockups in `docs/design/ui/` that feed the work: `08_recruit_raise_tab.png`, `08b_recruit_build_tab.png` (the Python
Raise and Build tabs: the first draft of the tab idea), `17_recruit_raise_v2.png`, `18_battle_panel_v3_*` (lanes, the
five-lane board), `unit_select/`, and the Studiolo set in `studiolo/`.

## 2. What is worth porting, and what is not

**Worth doing (small, in the order of value):**

| Item | Why | Where it goes |
|---|---|---|
| The battle orders (Attack, Hold, Withdraw, with the price of each in its hover) and the dice and log read live | It is the one Python screen function Godot lacks, and the owner's #437 | Battle board, section 4 |
| Raise hover card per kind: men, upkeep, move points, what it beats, the cost lines | The player picks a company by what it is good at; the row shows only the price | Army tab (section 3), S |
| "Armies here" list on a tile with several stacks | #433: a stack is hard to pick from the map; Python's tick list worked | Army tab, replaces the hex menu's "Select the Army of X" items |
| The Python Raise and Build tab mockups' idea (one window, tabs) | It is what #436 asks for; the mockups already answered "tabs or two screens" | Section 3 |

**Not worth porting:**

| Item | Why not |
|---|---|
| Python's immediate-mode drawing, `kit.py`, the per-panel `draw(ctx, world, ui, subject)` | Godot has a scene kit and read models; copying code would go backwards. Port the content, never the code |
| Province "Buildings (n/slots)" list | The economy rethink replaces it with settlement slots and an Industries tab (economy-rethink 3.1) |
| The 5-lane battle layout and the 18 battle cards | Approved, but they are the board of M24 (width 3 to 7, back slots, rotation, cards, `battle-size-and-frontage.md`). v1 stays on three lanes |
| Cargo, found colony, ship raising | Ships M19 and colonies M21 have no rules in Godot yet. The tile window keeps a place (a Ships tab) and no more |
| Merchant orders and the market table | Rebuilt in M10 on real markets; the Python panel is a reference for the layout only |
| The country chooser and the idea modal | Already replaced (`country_pick`, M11's idea screen) |

## 3. The uniform tile window (#436)

### 3.1 What it replaces

| Today (Godot) | In the tile window |
|---|---|
| `HexPanel` (title, ledgers, War block, Works rows, Raise tab) | The window itself: header, Details, Build, Army |
| `HexMenu` (right-click popup) | Gone. A right click with no army selected selects the tile and opens the window on the tab last used (Build on first use). The menu's items become: works = Build rows; "Raise companies here" = Army tab; one item per army = rows of "Armies here"; "Show supply" = a button in Details; battle, siege, castle area = buttons in the War block |
| `RaiseList` | The body of the Army tab |
| A separate sea panel (`_show_sea`) and a home-reason line | One window, four cases (3.3) |

`HexPanelContract` stays as the seam so the map scene and tests change little. A right click with an army selected is still
an order (M6 D43). The army panel stays its own dock: it is about an army, not a tile. It borrows the same frame and
cartouche so the two look like one family.

### 3.2 The frame

```
+------------------------------------------+
| (seal)  Turin                        [x] |   Cartouche: place name, else the ground word
|  town, Piedmont  -  hex 5, 9             |   one subtitle line
|  [Savoy chip] own  -  People 30,300 +300 |   owner link, held/occupied/besieged badge, people
+------------------------------------------+
|  Job: Build vineyard, 2 seasons  [Cancel]|   only when a job is under way (one job a settlement)
+------------------------------------------+
|  Details | Build | Industries | Army | Ships |   tab strip (Segmented); only the tabs that apply
+------------------------------------------+
|  ...the open tab...                      |   scrolls inside the dock, like the hex panel today
+------------------------------------------+
```

The **job line** lives above the tabs because "one job per settlement at a time" (M6/M9.5) must show on every tab, whichever
one started it. The tab strip is hidden when only Details applies (foreign, sea, unseen): no one-tab strip. Tab order never
changes, and a tab that does not apply is **absent**, not greyed; why it is absent is one "Why not" line at the foot of
Details ("Raising needs a village or larger", "Not your land"). That keeps the strip short and the reasons in one place.

### 3.3 The four cases

**Own land.** Tabs: Details, Build, Industries (own settlement, from M9.5), Army (own settlement), Ships (own port, M19).

```
 Details                         Build                          Army
 Ground  farmland, lowland       Works rows (today's):          Men at hand 6,300  -  1 of 2 companies
 Raw     wool, 12 loads  (M9.5)    [Build vineyard  40 . 4 seas]  [Pikemen 500 men  25 . 1 iron  Raise]
 Gives   grain 8, wool 12          [(i)] +3 grain  -2 wool        [Crossbowmen ...              Raise]
 Worth   +14 a season            Upgrade, Clear, same rows        Armies here
 People  30,300 (+300)  room 45k Refused rows show the reason     [Army of Turin 1,000 men] [select]
 Supply  [Show supply]                                            [Army of Asti    500 men] [select]
 War     fortress 2, holds 8 hexes; [Open the battle] [Show area] Why not: (none)
```

**Foreign land, seen now.** One tab, so no strip. Details only: owner (link to its country card), the piece and its stage,
people "about 30,000" (rounded, as `PeopleView` gives), the ground, what the hex gives if the piece is visible, the War
block (held by, fortress, siege meter if seen, relief line), and the **Army** facts if a foreign army stands there (banded men,
no buttons; the odds word when you have an army selected, as the odds card says). Industries: slot kinds and stages if the
settlement is seen, never output, tier bonus or stocks (economy-rethink 3.1). A hostile fortress offers the same buttons as
today (Show area, Open the battle).

```
 Milan                                   hex 7, 9
 [Milan chip]  foreign  -  at war
 Ground  farmland        People about 30,000
 Piece   city, walled    Fortress 3, holds 14 hexes
 Siege   meter 3 of 9, relief 2 away   [Open the siege]
 Army    Army of Milan, about 1,500 men (seen)
```

**Sea.** Details only: "Open sea" or "Coastal sea", depth word, the coast hexes beside it, the crossing words if it is a
ferry or strait, whose ships are seen there (M19). Ships raised at a port are not here: the port settlement's Ships tab.

**Not in sight.** Fog follows `Sight.sees` and `Knowledge`, not a new rule:

| State | The window shows |
|---|---|
| In sight | Everything the case above says |
| Explored, not in sight now | Ground, relief, the place name (the map is known). The owner, people, works and armies are not remembered: "Out of sight. Last known state is not kept." (see Q3) |
| Never explored | Cartouche "Unexplored"; "hex 3, 4"; one line "You have not seen this land." Nothing else; no tabs |

Land taken from the player (#435): if the new rule keeps sight of lost land, the window treats it as in sight and the War
block says "Held by Milan since Spring 1481". The window needs no change for that; only the fog result changes.

### 3.4 How it meets the economy rethink

- The **Industries** tab is a slot of the registry (3.5): rows of kind, stage, working or idle, where its raw comes from,
  yield breakdown; free slots with Build and a card; "opens in 1490" for a closed industry; the "Buy inputs" switch of
  economy-rethink 3.2. The tab shows on own settlements; slots by level (village 1, town 2, walled 3, city 4).
- **Details** gains the raw line ("Raw: wool, 12 loads this season") for a raw district, and the slot kinds for a settlement.
- The **Army tab** gains the arms line the economy rethink adds ("arms 1 each; none in store: buys at 1.5x"), and the
  refusal "no arms and no money".
- The map's small trade marks (loom, anvil, loaf) are not part of the window.

### 3.5 How it is built

- A pure `core/views/tile_view.gd` (`TileView.of(game, viewer, hex)`) returns `{case, header, tabs, details, why_not}`. It
  composes `HexCard`, `PeopleView`, `Knowledge`, `Sight` and `HexWar`'s data. No nodes, no luck, no engine calls (layer rule).
- `shell/panels/tile_window.gd/.tscn` owns the frame, the job line and the strip. Each tab is a small script with
  `fill(game, viewer, hex)` and an id (`details_tab`, `build_tab`, `army_tab`, `industries_tab`, `ships_tab`), listed in one
  table `TileTabs.ALL` with its test "applies to this TileView". A later milestone adds a tab by adding a row and a file.
- The Build tab is today's rows moved over unchanged (they are the most tested part); the Army tab is `RaiseList` plus the
  "Armies here" rows. Nothing in `core/` changes except `tile_view.gd`.
- Keys: the existing `R` and `U` keep their meaning (R opens the Army tab, U the Build tab's first upgrade); `O` and
  Shift+F10 open the window at the cursor (no popup); Left and Right on the strip change tabs. All HUD buttons keep
  `focus_mode` NONE except the strip, as `ui-and-controls-spec.md` requires.
- Tests: `test_tile_view.gd` (the four cases, fog), `test_tile_window.gd` (tabs per case), the existing hex panel, raise
  list and hex menu tests move to the new window; the monkey (`monkey_m7.gd`) clicks the strip; the pictures tour adds the
  four cases at 1280 x 720.

## 4. Battles played round by round (#437)

### 4.1 What M7 gives, and what the board changes

M7 fights a whole battle in the `battles` phase: `Combat.fight(war, input, rng)` builds a state, loops `_day` until a side
breaks or day 8, and returns one frame per day. `BattleRecord` keeps `input`, `luck_before` and the frames; `Combat.replay`
fights it again from those. The dock shows the frames. The stances are fixed in the input (attacker Attack; defender its
standing order).

The board changes **one thing**: the stance and the lane fills of a day may come from the player instead of from the input.
Nothing else in the day (deploy, rolls, fire, back line, shock, flanks, morale, break test, flight) changes.

### 4.2 The seam (what core gains)

| Piece | Change |
|---|---|
| `Combat` | `fight` is split: `begin(war, input, rng) -> CombatState`, `play_day(state, orders) -> frame`, `finish(state) -> result`. `fight` becomes begin + loop of `play_day` with the input's own stances, so **all-default orders give the same frames and the same luck draws as today**. This is pinned by a test that compares digests over seeds 1 to 500 (the bands test's seeds) |
| Orders | `{day, side, stance, fills: {lane: unit key}}`, `fills` optional (default: M7's automatic pick). Per day, per side |
| `BattleRecord` | Gains `orders: Array` (default empty, so no format bump: a new body field with a default needs none, M3 4.10). `Combat.replay` applies them, so a played battle replays exactly and the dock and tests can verify it |
| `Battles` | `season` gains the split: `pending(game, tag)` lists the battles the player is a side of; `fight_one(game, battle, orders_source)` fights one; the rest are fought as now, in hex index order. `Game.act` gets `battle_day {hex, stance, fills}` and `battle_auto {hex}`, each with a `*_check` giving the reason (the pair rule) |
| `Season` | `run` is the table's whole walk; `run_to(name)` and `run_from(name)` expose the halves, so the flow can stop before `battles`. A test pins that `run_to + run_from` gives the same digest as `run` (refactor rule) |
| Luck | Unchanged: one stream (`game.luck.world`), battles in hex index order, no draw while the player thinks. A pause between battles draws nothing |

### 4.3 The flow, from the player's chair

**Entering from the map.** Three ways, all the same widget:

1. **Your attack (today's rules).** You give a march into an enemy stack and press End season. The season runs the AI and the
   movement phase; the walks replay (the stacks meet on the hex); then the flow enters a new state **BATTLE** and the board
   opens for each battle you are a side of, in hex order. When the last is done the remaining phases run and the report
   follows. (`SeasonFlow` states become IDLE, RUNNING, REPLAY, BATTLE, RUNNING, DECISIONS, REPORT.)
2. **An enemy attacks you.** Same: the board opens in BATTLE, you on the defender side, your army's standing order (Hold or
   Withdraw) as the first day's stance.
3. **If #432 is approved** (a move happens in the month it is ordered): the battle begins when you order the attack. The
   march plays at once, then the board opens, inside your turn, before End season. The board does not change; the trigger
   moves. Then a battle can exist while the game is idle, so a save must keep it (4.7).

The map badge stays what it is: a click on a finished battle's badge opens the dock for review. A battle you are not part of
is never played, never paused for.

**On the board** (the dock in live mode, 4.5):

1. Day 0: the sides, the ground chips, the odds word, the lanes as deployed. You read it and press **Begin**.
2. Each day you see the position at dawn and set the **orders strip**:
   - **Stance:** Attack, Hold, Withdraw. Sticky from day to day. Withdraw is offered from day 2 (before that it is disabled
     with the reason "can leave only from the end of day 2"). Each stance's hover shows its prices from `WarDef`: Attack
     deals 1200 and takes 1100 permille; Hold deals 900 and takes 800; Withdraw leaves at the end of the day for 5 % of men
     (10 % attacking) and 25 morale, or flees at under 10 % front morale (the flight price, 15 % of men, guns lost).
   - **Fill:** when a lane is open at dawn and more than one company could fill it, a chooser shows the candidates (M7's
     order is the default and pre-selected). It is the first real tactical choice: knights on the flank or kept back.
3. Press **Fight day N** (Enter or Space). The day plays as the dock plays a day now: dice, the hits, the tug bar moving, the
   log lines (0.6 s a day, instant under reduce motion). The new dawn position appears with the orders still set.
4. Repeat until a side breaks, withdraws or flees, or day 8 ends it. A result card gives who won, the men killed and
   wounded, the retreat or the storm, and one **Close** button.
5. **Auto to the end** on the strip fights the rest with the current stance and default fills (what happens today). The
   Options entry "Battles" (Play them, Ask only if the odds are not Hopeless or Overwhelming, Auto) sets the default; Auto
   makes the flow skip the board and show only the report, as now.

**Undo and skip.** Orders can be changed any number of times **before** Fight day. After it the day is final (the dice are
drawn); there is no undo of a fought day. Skip is Auto to the end; there is no "skip to the next battle" that hides a day.

**Timing.** A battle runs 1 to 8 days, usually 3 to 5 (M7's bands). At 3 to 5 clicks a battle it costs the player seconds,
and only battles the player is in are asked. Europe in a general war could bring several; the setting above and the report's
count ("3 battles awaiting you") keep it light (fun principle 11).

**What stays automatic.** Battles of AI against AI, battles the player only witnesses, and the AI's side in a player's
battle. The AI keeps M7's fixed stance and automatic fills in v1: that keeps the AI's results, the soak ranges and
`test_combat_bands` valid, and keeps M8's work separate. An AI that chooses by day (Withdraw when the front is below 30 %
after day 2, Hold when ahead) is a small later step (Q9).

### 4.4 Determinism and replay (the M7 constraints)

- **One stream, fixed order.** A battle's draws come in hex index order from `game.luck.world`; a played battle draws the
  same count as an auto one for the same orders. The pause waits with no draw.
- **Orders are inputs.** They go into `BattleRecord.orders`; `Combat.replay(record)` reproduces the battle from input,
  `luck_before` and orders. The existing `test_replay_battles.gd` gains a case with scripted orders.
- **Autoplay is the identity.** All-default orders equal today's fight, frame for frame and draw for draw (the digest test of
  4.2). That is what lets the AI, the soak and the oracle ignore the board.
- **The save.** Under today's rules the battle lives only inside End season, so no save is taken in it: while the board is
  up, Save is disabled with a reason ("Finish the battle first") and quitting to the menu asks, losing the season in
  progress back to the autosave. Under #432 a battle may be live at idle: the save then stores the battle's input, its
  `luck_before` and the orders so far, and load re-fights to that day (the fight is a pure function of those three), so
  `CombatState` is never serialised. That is a `battle/2` body with defaults, M-sized.
- **Save-scumming.** A player may reload and try other orders against the same dice. It is single-player and the dice depend
  on the whole earlier season; accept it (R3).

### 4.5 The screen

The board is the **battle dock in live mode**, not a new screen. The dock is already a left-side overlay of 420 px with the
face-off, stats, tug bar, lanes board, ground chips, log and result. Live mode adds, in its sticky footer where Earlier and
Next sit today:

```
+------------------- Battle of Alessandria, 1480 ------------------+
| [Savoy token] 4,000 men   morale ####----  vs   Milan 3,000 men  |
|   tug bar (front-line morale)           dice: 4 - 2   Day 3 of 8 |
|  enemy reserve  [pk][pk][xb]                                     |
|  enemy lanes    [ L ] [ C ] [ R ]                                |
|  ------------------- front line -------------------              |
|  your lanes     [ L ] [ C ] [ R ]     lane R is open: fill with  |
|  your reserve   [kn][pk][bm]          (o) Knights  ( ) Pikemen   |
|  log: day 2 - Savoy's right gave way ...                         |
+------------------------------------------------------------------+
| Stance [Attack][Hold][Withdraw]  [Fight day 3]  [Auto to the end]|
+------------------------------------------------------------------+
```

It takes its numbers from `BattleView` (the one source and its fog: a side sees both armies exactly; a witness sees rounded
numbers and has no orders). It adds a `live` flag, the orders strip, the fill chooser and the result card. A finished battle
still opens read-only with the stepper. Esc is the ScreenStack's: in live mode it asks "Auto-fight the rest?" instead of
leaving the battle undecided. The map beside it stays visible (the dock is an overlay), with the battle hex marked.

## 5. Build order, milestone placement, sizes, risks

### 5.1 Placement

M7 (war, in build: group A pushed) edits the hex panel, hex menu, army panel and dock through its tasks B19 to B28. Starting
the tile window before M7 closes would collide with them.

| Step | What | After | Before | Why there |
|---|---|---|---|---|
| **U1** | The tile window (#436) | M7 closed and played | M8 | Owner's pain today; M7's edits to the panel have settled; **M9.5 needs the Industries tab** and said the window is built first (economy-rethink Q9); M8 (AI) has no UI conflict, so U1 can also run beside M8's early groups if the owner wants speed |
| **U2** | The battle board v1 (#437) | M8 closed (the AI and the soak are stable on auto battles) | M9 | The board changes nothing in auto results, so it is safe once the AI is measured; it should be played before M9's peace terms make war longer, so the owner can judge war's feel |
| **U3** | Small ports (troop hover cards, "Armies here") | with U1 | n/a | Belongs to the Army tab |
| M9.5 | Industry | M9 | M10 | Adds the Industries tab file; no window work |
| M19, M21 | Ships and colonies | | | Add the Ships tab and the colony button as rows of `TileTabs`; the Python panels are the layout reference |
| M24 | The full battle board: width 3 to 7, back slots, rotation, cards | M12 | | v1's orders are its first slice; the dock and `Combat` seam stay |

If the owner decides #432 first, U2's trigger changes (4.3, way 3) and `battle/2` joins U2 (about one more M); decide #432
before U2 starts, not before U1.

### 5.2 Sizes (S half a day, M a day, L two or three days; worker-days)

**U1, the tile window:**

| Task | Size |
|---|---|
| T1 `TileView` and its tests (four cases, fog) | L |
| T2 `TileWindow` shell, job line, strip, `TileTabs`, Details tab, "Why not" | L |
| T3 Build tab (the moved rows, cards, cancel) | M |
| T4 Army tab (`RaiseList` moved, "Armies here", raise hover card) | M |
| T5 Remove `HexMenu`; right click, `O`, `R`, `U`; App and map wiring; the specs' edits | M |
| T6 Tests moved, monkey, pictures, README and `ui-and-controls-spec.md` edits | M |

About 2 L + 4 M, 9 to 10 worker-days, about 5 working days with two parallel tracks. No save change, no balance change.

**U2, the battle board v1:**

| Task | Size |
|---|---|
| T1 `Combat` split, orders, `BattleRecord.orders`, `replay`, the digest-equality property test | L |
| T2 `Battles` pending and fight_one, `Season.run_to/run_from`, the two actions and their checks, the refactor oracle | L |
| T3 `SeasonFlow` BATTLE state, the Options entry, Save disabled in the board, the report count | M |
| T4 Dock live mode: orders strip, fill chooser, Fight day, result card, keys, reduce motion | L |
| T5 Tests (scripted orders replay, flow, monkey), pictures, soak and band checks unchanged, docs | M |

About 3 L + 2 M, 9 to 10 worker-days. Opus reads T1 and T2 (the determinism seam); the rest is Sonnet work.

### 5.3 Risks

| # | Risk | Mitigation |
|---|---|---|
| R1 | Splitting `Combat.fight` changes the luck draws and breaks the soak and the bands | The digest-equality test over 500 seeds is the first test written, and `fight` is built on the new pieces so there is one code path |
| R2 | Splitting the season table changes order or digests | Pure refactor: `run_to + run_from` equals `run`; the oracle and `test_season.gd` pin it |
| R3 | A player reloads to try other orders on the same dice | Accept; single player. If it matters, mix the day number and the player's orders into a per-battle stream later |
| R4 | A war of ten battles tires the player | The "Battles" option, the Hopeless and Overwhelming skip, Auto to the end, the count in the report |
| R5 | The tile window loses a feature of the hex menu or the Raise tab | A checklist in T5 maps every menu item and every Raise-tab test to its new place |
| R6 | Decisions are thin: three stances and a lane fill may still feel small | It is v1 on purpose. The measure is the owner's playtest after U2; M24 adds rotation, width and cards |
| R7 | #432 and #435 land after the window and the board and force rework | The window reads `TileView`, so fog changes are in one file; the board's trigger is one call; decide #432 before U2 |
| R8 | Fog: the window leaks information (people, owner) of unseen land | `TileView` reads only `Sight` and `Knowledge`; a test walks every case with a viewer who sees nothing |
| R9 | Dead UI: a Ships tab that does nothing | It appears only on own ports, with one honest line, until M19 (Q2) |

## 6. Questions for the owner

1. **Does the tile window replace the hex menu entirely** (a right click on a hex opens the window; the popup goes)?
   Options: (a) replace, (b) keep a short popup that only opens the window on a tab. **Recommend (a).**
2. **The Ships tab before there are ships.** Options: (a) hide it until M19, (b) show it on own ports as a stub with one line,
   (c) show it everywhere, disabled. **Recommend (b):** you asked for it, and a visible stub keeps the place without a dead
   control on every hex.
3. **Explored but not in sight now: what does the window show?** Options: (a) ground and place name only, (b) also the last
   known owner (needs a stored memory of owners, a save change), (c) nothing. **Recommend (a)**; revisit with #435.
4. **Battle default.** Options: (a) play my battles on the board, with Auto to the end always one click away, (b) auto by
   default and opt in. **Recommend (a)**; the Options entry has three values (Play them, Ask unless Hopeless or Overwhelming,
   Auto).
5. **What are the orders of v1?** Options: (a) stance each day only, (b) stance plus which reserve company fills an open
   lane, (c) also the guns' target. **Recommend (b)**; width, rotation, cards and guns' targets wait for M24.
6. **When does the board open in a season?** Options: (a) after the walks replay, before the later phases (needs the season
   table split), (b) at the order itself, if #432 is approved. **Recommend (a) now**, with (b) as the trigger change if #432
   is approved.
7. **Decide #432 (moves happen when ordered) before or after the board?** Options: (a) before U2, (b) after, accepting
   rework. **Recommend (a)**; it changes the trigger, the save (`battle/2`) and the replay of walks.
8. **Saving during a battle.** Options: (a) Save disabled while the board is up (today's rules), (b) save the live battle
   (only worthwhile under #432). **Recommend (a)** for U2 and (b) only with #432.
9. **Does the AI choose its stance per day in a player's battle?** Options: (a) keep M7's fixed stance (results unchanged),
   (b) a simple morale rule (Hold when ahead, Withdraw under 30 % after day 2). **Recommend (a) for v1**, (b) when M8's AI is
   playtested; (b) makes battles harder and moves the bands.
10. **Order of work.** Options: (a) U1 after M7, U2 after M8; (b) U2 first because war feels thin now; (c) both after M12.
    **Recommend (a):** U1 unblocks M9.5 and is the owner's daily pain; U2 waits for M8 so the AI is measured on auto
    battles first. If M7's playtest shows the war flat, move U2 up and leave U1 where it is.
