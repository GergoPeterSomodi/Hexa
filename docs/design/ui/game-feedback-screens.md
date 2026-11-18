# Game feedback: the season report, the works preview and the study

Game and UI systems designer, 2026-11-17. **Status: a proposal for the owner. Nothing here is built before the owner's go.**
It adds three of the owner's asks to `docs/architecture/ui-and-controls-spec.md` (the UI spec), in the approved Studiolo
look. Numbers marked *example* are placeholders: the M4 district-economy design sets the real ones.

> 1. "End season should open up a dialog of the summary of what happened, not just a toast."
> 2. "Upgrade needs to showcase what the upgrade brings in, plus gains per field. Change is super important per season."
> 3. "Civ allows to look into more insights and statistics of the whole economy, trade, diplomacy etc."

**Facts this page stands on** (read in the code, master `d28e5e8`):

| Where | Fact |
|---|---|
| `core/systems/improve*.gd`, `world_improve.gd` | Build, upgrade, clear are instant check/do pairs giving `{ok, reason}`; one event, `hex_changed`. Settlements 1-5 (hamlet to city), castles and goods 1-3; level 2 needs a place within two hexes or a road, level 3 a town within two; pair rules |
| `core/state/map_state.gd` | Play state is `main_use` and `level` only: no money, people, works, seasons or history |
| `core/defs/map_data.gd` | Per hex: cover, height, `climate` (snow, frost, mild: the winter slot), `fertility` and `ore` (**all zero** today), pass, place. Per edge: river, road |
| `data/maps/north_italy.tres` | **Genoa (8, 13) is level 4, a walled town** (castle 2, port, mild winter). Savona (6, 13) and Cuneo (5, 13) are level 3 towns side by side. (7, 12): farmland, 665 m, frost winter, river on its west edge, no road |
| v0.2.2 `economy.py`, `resources.py` | `economy(preview=True)` is the season's own function. The chips' `Tracker` takes its baseline at End season, keeps 12 seasons, **not saved** |
| v0.2.2 `feed.py`, `reminders.py`, `ledger.py`, `country.py` | You hear an event if you are a party or saw its hex. `unfinished()` gives the task lines. The ledger and country panel show **every** country's score, income, treasury and army unchecked |
| `docs/design/ui/09`, `12`, `13`, `14` | Debt, market, treasury (12-season chart) and investment-payback designs: reused below |

---

## A. The Chancellor's report

### A.1 When it opens, and how it closes

After **End season**: the busy pill while the phases run; the movement replay (M6, Space skips it); any **decision
screens** the season queued (war declared on you M7, peace offer M9, idea pick M11), one at a time; then **the report**,
a `MODAL` screen (map dimmed and paused). Closing it starts the new season. Toasts for what the report holds are dropped.

- **Space, Enter** or the primary "Begin Summer" (default focus), **Esc** or the close button: close. Nothing to cancel.
- **J**, the top bar's date medallion, or a season header in the action log: open it again.
- **Guard:** End season ignores key echo and any press within 400 ms of the report closing: Space, Space never plays two seasons.
- **Option** `game/season_report`: **Full** (default); **Brief** (At a glance and notices only, opened only for a serious
  notice or a change over a tenth of the treasury, else a toast); **Off** (toast "Spring 1480 ended: ▲ +86 ducats. J: the report").

### A.2 Structure

A vellum letter in the walnut `ModalFrame` (about 860 x 620): velvet ribbon with the season that ended, the wax seal
with the country's initial, a left nav list with counts, one scrolling body. Sections, not tabs: it reads top to bottom.

| # | Section | Shows | From |
|---|---|---|---|
| 1 | At a glance | up to five headline chips, largest swing first | M3 date, works; M4 money, goods |
| 2 | Before next season | notices with **Go** buttons, worst first, at most five | M3 works, winter; M4 money, food; then each M |
| 3 | Treasury | opening, in, out, your spending, closing | M4 |
| 4 | Goods | stock and change, made and used | M4 |
| 5 | Works | finished (what each brings), begun, under way | M3 |
| 6 | People | growth and decline by place, food | M5 |
| 7 | Your orders | built, upgraded, cleared; later raised, marched, declared, traded | M3 |
| 8 | What befell *country* | others' and the world's doings that touched you or that you saw | M6 |
| 9 | Standing | your rank among the countries you know | M4, score M12 |

**Scanning rules.** Lines sort by size (ducats at this season's prices; men for armies); six show, then "and 4 more". The
report's three largest swings get a gilt rule. A gain is `GOOD_INK` with "▲ +", a loss `BAD_INK` with "▼ −": **sign and
glyph always, colour never alone**. Tabular figures, right aligned. Unchanged items share one line ("Unchanged: stone,
hemp"). A place name is a link: the report closes and the camera glides there.

### A.3 The Genoa example (as M5 would show it; *example* numbers)

```
+=============================[  SPRING 1480  ]==============================+
|  The Chancellor's report to the Doge of Genoa. Summer 1480 begins.   (G)   |
|  At a glance     | AT A GLANCE                                             |
|  Before Summer 2 | (o) Treasury 1,240 ▲ +86    (o) Grain 320 ▲ +14         |
|  Treasury        | (o) Fish 64 ▲ +9   (o) Wine 41 ▼ −6   (o) Works 1 done  |
|  Goods 5         | BEFORE SUMMER                                           |
|  Works 2         | ! Wine runs out in 6 seasons; the first vintage is      |
|  People          |   Autumn 1481.                           [Go to (7, 12)] |
|  Your orders 1   | . A work slot is free: 1 of 2 in use.      [Show Genoa] |
|  Standing        | TREASURY                     1,154 -> 1,240   ▲ +86     |
|                  |   Taxes on people                             ▲ +64     |
|                  |   Taxes on goods                              ▲ +52     |
|                  |   Port dues, Genoa                            ▲ +35     |
|                  |   District upkeep, 31 districts               ▼ −16     |
|                  |   Walls of Genoa and Savona                   ▼ −9      |
|                  |   Vineyard begun above Savona (7, 12)         ▼ −40     |
|                  |   Left over each season ▲ +126; with your spending ▲ +86 |
|                  |   GOODS ... WORKS ... PEOPLE ... ORDERS ... STANDING    |
|  [Open the study I]        Full | Brief          [ Begin Summer  Space ]    |
+============================================================================+
```

Below the fold, exactly:

- Goods: "Grain 320 ▲ +14 (made 96, eaten 82)", "Fish 64 ▲ +9 (caught 31, eaten 22)", "Wine 41 ▼ −6 (made 0: the vines
  rest in spring; drunk 6)", "Timber 58 ▲ +4 (first cut at the Polcevera woods)", "Salt 22 ▲ +3", "Unchanged: stone, hemp".
- Works: "Finished: logging camp, Polcevera woods (9, 13), first stage. Brings timber +4 in spring, +6 in winter; upkeep −1."
  "Under way: vineyard above Savona (7, 12), 1 of 4 seasons. Ready Spring 1481; first vintage Autumn 1481."
- People: "Genoa 62,000 ▲ +700 · Savona 14,000 ▲ +150 · the countryside 136,000 ▲ +450." "Food: 127 made for 104 eaten: fed, 23 to spare."
- Your orders: "Built 1: vineyard above Savona."
- Standing: "Among the 6 countries you know: land 4th (38 districts), income 2nd (▲ +151 a season)."

The sums close (151 − 25 − 40 = +86; food 127 − 104 = 23 = grain +14 and fish +9). **Every ducat is explained**: a
property test fails if the lines do not add up to the change (M4's "no money from nowhere").

### A.4 Lines later milestones add (*example* strings)

| M | Example |
|---|---|
| M3 (no money yet) | At a glance "Works 1 finished, 1 under way."; in Autumn, "Winter comes: Col di Tenda closes; frost stops the fields above the Po." [Show the passes] |
| M6 | "Raised 1 company of crossbowmen at Genoa (▼ −30)." "The army at Novi is out of supply: it loses men next season." [Go to the army] |
| M7 | "Battle of Gavi: Milan won; you lost 400 men, they 650." [Show] "Siege of Novi: 2 of 5." |
| M9, M10 | "The truce with Milan ends in 2 seasons." [Open Diplomacy] "Grain in the Genoa market rose 1.10 → 1.30 (▲ +18%): a poor harvest in Lombardy." |
| M11, M12 | "Researching Double-entry books: 12 of 40." "Debt 240: interest ▼ −5." "Score 48 ▲ +2, 3rd of 6." |

### A.5 How it is fed (no polling)

```
Game.act(name, args) ----------> game.action_log (saved: the replay record, standard 5.1)
Treasury.move(tag, n, why, hex) -> country.ledger_open (saved: the one door for money)
season phases -> game.events --+-> Session drains -> Events signals (log, floaters, map)
                               +-> the season runner tees each event into game.chronicle
phase "stats" (new: after scores, before the calendar) closes the ledger, appends Stats rows
Session emits Events.season_ended(turn) -> the report shows SeasonSummary.of(game, tag, turn)
```

`core/views/season_summary.gd` (pure) gives one list per section of `{text, amount, unit, tone, hex, rank}`, from the
two last `Stats` rows, the closed ledger, the action log since the last season, the season's chronicle and
`core/views/reminders.gd` (notices). Built once per `(turn, tag)`, under 2 ms. **Fog:** "What befell" keeps an event
only if you are a party or saw its hex then (events carry `witnesses`, as v0.2.2's `unit_moved.seen`). All inputs are
saved, so J after a load still works.

### A.6 Empty and quiet states

No work, order or event and every change under 2 %: the ribbon, **"A quiet season."**, one line ("The treasury grew by
126 ducats; nothing else of note."), the notices, the button. Brief opens nothing. Before M4: "A quiet season. No works
under way." [Show where to build].

---

## B. The works preview (build, upgrade, clear)

### B.1 Where it shows

1. **Hex panel rows** carry cost and up to three delta chips: `Build vineyard  ▲ wine +12 a year  ▲ +22 a year  40 · 4 seasons`.
   A refused row is greyed with its reason.
2. **The works card**, on hover after the tooltip delay, the row's (i), or U: a large card docked left of the hex panel
   (`OVERLAY`, the map live). Shift holds it while the pointer moves.
3. **The confirm.** A click starts the work (undo: `cancel_work` this season, UI spec 7). Option `game/confirm_works`:
   Off, **Expensive only** (default: over a quarter of the treasury, or 4+ seasons), Always; then the card's "Begin the
   work" confirms.
4. **On the map**, while the card is open: the next piece as a ghost (its baked tile at 55 % alpha); the changed yields
   as still labels over each affected hex ("+12 wine"); the **Yields** map mode (M2's data-texture overlay) tinting the
   district and its ring by gain.

### B.2 What the card shows

**Brings**, per field before → after (goods, jobs, people room, defence, sight, trade reach, upkeep); the **four-season
strip** (current season gilt-edged, the hex's winter slot); **where the gain lands** (district, ring of six by name,
country); a **chart** of the country's gain per season and year, before and after; **cost and time** with ✓ / ✗
requirements; **payback**; **next stages**. **Gain** = goods at this season's prices in your market, plus ducats, less
upkeep; "Treasury only" shows ducats alone.

### B.3 Seasons: what changes and why

The strip is only honest if M4's economy has seasons. **Requirement on the M4 design:** a season profile per family and
winter slot (a `.tres`), and stocks that carry goods across seasons. *Example*:

| Family | Spring | Summer | Autumn | Winter: mild / frost / snow |
|---|---|---|---|---|
| Wheat | little | harvest | some | little / none / none |
| Vineyard | none | none | vintage | none |
| Olives | none | none | some | harvest (mild only) |
| Grazing | wool | most (high pastures) | some | little / little / none |
| Timber | some | some | some | felling, most (none in snow) |
| Fishing | full | full | full | 70 / 50 / 30 % |
| Mines, quarry | full | full | full | full / 70 % / shut behind a closed pass |

Shown when they apply: a **road** of level 2-3 to the market adds value, none costs a quarter; a **river** edge helps
hemp and mills; **cover** decides the families; a **pass** in the snow slot closes in winter; a **neighbour** may add or
forbid (pair rules, a town's demand). Luck (harvests, late frost) is never counted: "Weather not counted".

### B.4 Example: a vineyard above Savona (7, 12) (*example* numbers)

```
+-[ HILLS ABOVE SAVONA ]---------------------------------------------- 7, 12 -+
| Vineyard, first stage            Farmland 665 m · frost winter · river W    |
| BRINGS (a year)   wine 0 -> 12 ▲ +12   grain 6 -> 2 ▼ −4   upkeep ▼ −4     |
| +-Spring-+-Summer-+=Autumn=+-Winter-+      GAIN A SEASON, COUNTRY          |
| | wine   | wine   | wine   | frost: |      Sp 164 ######## 162             |
| |  0 > 0 |  0 > 0 | 0 > 12 | nothing|      Su 171 ######## 168             |
| | grain  | grain  | grain  | grows  |      Au 205 ########### 233          |
| |  1 > 0 |  3 > 1 |  2 > 1 |        |      Wi 118 ##### 117                |
| +--------+--------+========+--------+      Year 658 -> 680  ▲ +22          |
| WHERE IT LANDS (a year)   This district 6 -> 32 ▲ +26   Upkeep ▼ −4         |
|   Neighbours: Savona (6, 13) buys the wine: its price 2.8 -> 2.5 in autumn  |
|   Country 658 -> 680 ▲ +22                                                  |
| COST 40 ducats · 4 seasons · ready Spring 1481 · first vintage Autumn 1481  |
|   ✓ farmland or meadow, 100-900 m   ✓ no snow winter   ✓ work slot 1 of 2   |
| PAYS BACK in Autumn 1482, 10 seasons from now (at today's prices)           |
| NEXT: stage 2 possible (Savona 1 hex away); stage 3 possible (a town within |
| two hexes, under 1,200 m).                       Weather not counted        |
|                       [Pin to compare]              [ Begin the work ]      |
+-----------------------------------------------------------------------------+
```

The seasons add up: −2, −3, +28, −1 = +22 a year. Payback from Spring 1481: −2, −5, +23, +22, +20, +17, +45 (Autumn
1482, past the 40 spent).

> **M4's numbers** (`docs/architecture/m4-build-spec.md` 4.15 c and 4.16): this card's district, season and payback
> figures are reproduced exactly by M4's tables; the country's own figures (658 → 680, the chart) and the neighbour's
> price line are not (the country is 511 → 533 on seed 1480; prices react only in M10).

### B.5 Example: Genoa, and a refusal (*example* numbers)

**Genoa is already level 4 in `north_italy.tres`**, so its card is 4 → 5; the 3 → 4 case is Savona's, which the rules refuse.

- "Genoa: walled town to city (level 4 → 5)." "600 ducats · 40 stone · 20 timber · 8 seasons (ready Spring 1482)."
  "✓ highway", "✓ food to spare in the market (23 a season)", "✓ work slot 1 of 2".
- Brings, a season: "People room 70,000 → 100,000", "Taxes on people 38 → 52 ▲ +14", "Jobs for burghers ▲ +3,000",
  "Sight 2 → 3 hexes", "Market reach 3 → 4 hexes", "Upkeep 6 → 11 ▼ −5". Each season alike; port dues 30 % lower in
  winter. Ring: "2 passes, 1 wood, 1 sea: nothing to lift."
- "Gain ▲ +9 a season: pays back about 67 seasons after the work, near 1498. A prestige work, not an investment."
- Savona, "town to walled town (level 3 → 4)", refused. Today's string (`_pair_against`): "a town needs its own
  countryside: no two towns side by side (settlements 3 at 5, 13)". The card: **"Cuneo (5, 13) is a town beside
  Savona: two towns may not stand side by side."**

> **M4's numbers replace this example** (`docs/architecture/m4-build-spec.md` 4.15 d): Genoa's city costs 1,000 ducats,
> 20 timber and 40 stone, brings people 30,000 → 60,000 and about +45 a season, and pays back in about 32 seasons: an
> investment, not a prestige work. The Savona refusal stands as written.

### B.6 Compare

"Pin to compare" keeps the card; hovering another row or hex adds a second column (shared rows and chart scale); the
better year is gilt-ruled.

### B.7 The read model: `core/views/improve_preview.gd`

`ImprovePreview.of(game, tag, hex, {action, family})` gives `verdict` (from `game.check` itself), `reason_words`, `cost`,
`requirements`, `brings`, `by_season`, `lands`, `payback`, `next_stages` and `map_marks` (hex → delta).

- **Same code path.** M4 writes one `Economy.district_output(game, view, hex, season)` and one
  `Economy.market_prices(game, view, market, supply)`. The season calls them on the real state; the preview on a
  `StateView`, `MapState` plus a what-if overlay (hex → use, level) that reads fall through. No second formula to drift.
- **Delta method.** Country after = country before (cached) + district deltas over the hex and its ring + the price
  change in the affected markets: about 28 district runs an option. **Cache** by `(game.version, tag, hex, option)`, 64
  entries; `game.version` (new in M3) rises with each action and season.
- **One what-if:** `EconomyPreview.with(game, tag, changes)` also serves the tax hover and "Expected next season".
- **Fog.** You build only at home (M2). A ring hex of another country is named only if you see it, its gain stays out
  of your total ("Also helps Milan's district at (9, 11)"), and its stocks and plans are never read.

---

## C. The statesman's study (insights)

### C.1 The hub

An `OPAQUE` screen. Opened by a book medallion in the top bar, **I** (last page), **L** (Economy: it **is** the M4
ledger) or a chip (ducats open Economy, prestige Rankings). A row or "Show on map" closes it and glides or switches the
map mode; I returns to the same page and scroll. Later pages are hidden, not greyed.

```
+==================[ THE STATESMAN'S STUDY ]=============== Spring 1481 ==[x]=+
| ECONOMY  <  | This season | Districts | Goods | History | Debt             |
| Trade       |                                                               |
| Diplomacy   |                    (the page)                                 |
| Military    |                                                               |
| People      |                                                               |
| Research    |                                                               |
| Rankings    |                                                               |
| History     |  I: close   [ ]: page   Ctrl+[ ]: tab   Enter: look there    |
+=============================================================================+
```

### C.2 The pages

| Page | Widgets | Others' data | Ships |
|---|---|---|---|
| **Economy** | money in/out stacked bars and lines, treasury line with change bars (12 or 40 seasons), Earns most / Costs most, district table (gain, goods, upkeep), tax hover preview (design 13) | none | M4 (This season), M4.5 |
| **Trade** | price table with sparklines and ▲▼, flows overlay, best and worst goods, merchants and profit (design 12) | public prices of known markets | M10 |
| **Diplomacy** | relations matrix (war, truce and seasons left, alliance, opinion word), war score bars, coalition risk | public facts | M9 (wars M7) |
| **Military** | armies table (men, upkeep, supply, place), losses chart, upkeep share | seen armies, banded strength | M6, M7 |
| **People** | population by place, food balance chart, growth and decline, hungry places | none | M5 |
| **Research** | points chart, techs by branch, era progress | eras of known countries | M11 |
| **Rankings** | ranked bars on land, income, army, people, score; your line through time | known, banded | M4.5, more per M |
| **History** | timeline (a tick a season, marks for wars, battles, works, eras), chronicle with filters All, War, Money, Works, Mine | what you witnessed | M4.5 |

Tables sort on a header click (stable, ties by id) and remember it per page. "Show on map" picks a mode: Yields, Trade
flows, Relations, Supply, Food.

### C.3 The Economy page (*example* numbers)

```
+- This season -+- Districts -+- Goods -+- History -+- Debt -+--------------------------+
| MONEY IN                       ▲ +151 | LAST 12 SEASONS   bars: change  line: treasury |
| [ people 64 ][ goods 52 ][ port 35 ]  |      _.-'''-._.--'''                         |
| MONEY OUT                      ▼ −25 |  ## ## ## ##    ## ## ## ##  ## ## ##        |
| [ upkeep 16 ][ walls 9 ]              |              vv winter 1480: wall repairs    |
| Left over ▲ +126 a season             | EARNS MOST           | COSTS MOST            |
| Your spending ▼ −40: vineyard (7, 12) | Genoa people   +41   | 31 districts   −16    |
| Expected next season ▲ +131           | Genoa port     +35   | Walls of Genoa −6     |
| TAX  Low | Normal | High              | Polcevera woods +4   | Savona walls   −3     |
|   hover: "High: ▲ +38, people ▼ −0.3% a season"                                     |
+--------------------------------------------------------------------------------------+
```

> **M4's numbers replace this example** (`docs/architecture/m4-build-spec.md` 4.15 and 4.16): on seed 1480 Genoa's
> Spring 1480 reads money in +102 (+65, +7, +30), out −16 (−12, −4), left over +86, and the chart starts with the first
> season played.

### C.4 Charts and tables in Godot

- **`InkChart`** (a `Control` drawing in `_draw()`): line, paired bars, stacked bar, sparkline. Ink on a vellum inset,
  brass hairlines on leather: `draw_polyline` (antialiased), `draw_rect`, `draw_dashed_line`, `draw_string` with the
  Theme font. Each series has its own ink **and** dash or marker. `queue_redraw()` only on new data; the value under the
  pointer through `_get_tooltip()` as a `HoverCard`. No shaders.
- **`StudyTable`**: Godot's `Tree` with columns (draws only visible rows, keyboard ready); `column_title_clicked` sorts.
- **`RelationMatrix`**: a `_draw` grid with country initials and icon-atlas glyphs (war, truce, alliance).
- A page is built on first open, refreshed on `season_ended`, and opens in under 16 ms.

### C.5 What you may know of others

Stricter than v0.2.2: **only countries you know** appear (met: a shared border, or one of their hexes explored);
others count as "2 countries unknown". Their numbers are **banded** to two figures ("about 1,200", "about 40,000 men");
wars, truces and alliances are public; their research in progress, stocks, exact treasury, orders and unseen armies
never show. History shows what you witnessed. The AI reads the same views (standard 5.6).

### C.6 History storage

`Stats` (`core/state/stats.gd`, `to_dict`), owned by `core/systems/stats.gd` (`OWNS: ["stats"]`), written only by the new
season phase **`stats`** (after scores, before the calendar; the season test pins it). Sizes for Europe, 60 countries:

| Part | Content | Size |
|---|---|---|
| Season ring | last 40 seasons per country: treasury, income lines, spending, people, food, districts by family, land, army and upkeep, losses, war score, prestige, score, research | ~0.4 MB |
| Year rows | the winter row of every year, 1480-1650 | ~1.6 MB |
| Goods block | per country and season: made, used, stock of the goods it touches | ~1 MB |
| Chronicle | 3,000 newest notable events with hex, tags, witnesses | ~0.3 MB |

Packed arrays, compressed in the save, part of the digest (deterministic). Market prices keep their own 40 seasons. Unlike
v0.2.2's tracker it is **saved**: charts that empty on load would break the study, and our save format bears it.

### C.7 Milestone placement

| Milestone | Adds |
|---|---|
| M3 | `Stats`, the `stats` phase and the chronicle; the report (works, orders, notices) |
| M4 | money and goods in the report; the works card with seasons and payback; the study frame with **Economy, This season** as the ledger (L) |
| **M4.5, new: "Insights I"** | chart and table kit, Economy's other tabs, History, Rankings (land, income), the Yields map mode. Done when the owner answers five questions from the study in under a minute each ("which district earns most?", "why did the treasury fall in Winter 1480?") |
| M5; M6-M7; M9; M10; M11 | People; Military; Diplomacy; Trade; Research, each built and tested with its system |
| M12 | score in Rankings, the debt tab, text size and high contrast in charts |

**Recommendation: M4.5, then pages with their systems.** The chart kit is paid once; a page built with its system is
checked against real data by its designers, where a late Insights milestone would find missing fields after the systems
froze; and M4 stays on the district economy, the critical path.

---

## D. Cross-cutting

### D.1 One source for each number

| Need | Source | Used by |
|---|---|---|
| What happened | Stats rows, closed ledger, action log, chronicle | report, study, chips |
| What would happen | `Economy.district_output`, `market_prices` via `EconomyPreview` / `ImprovePreview` | works card, tax hover, "Expected next season" |
| What is left to do | `core/views/reminders.gd` | report notices, task flag |
| What you may see of others | `core/views/knowledge.gd` (`knows`, `band`, `witnessed`) | report, study, cards |

### D.2 Events to add (one Events signal each)

`season_ended(turn)` (after the last drain), `work_started`, `work_finished`, `work_cancelled` (M3); `goods_short` (M4);
`town_grew`, `district_declined` (M5); `truce_ended` (M9); `price_moved` (M10, over 15 % a season); v0.2.2's war, siege,
battle, research and era kinds with their milestones. Money is state (`Treasury.move`, the ledger), not an event stream.

### D.3 Kit and Theme additions

`VellumSheet` (vellum in `ModalFrame`, ribbon, seal), `DeltaChip`, `SeasonStrip`, `PreviewCard` (a large `HoverCard`),
`InkChart`, `StudyTable`, `RelationMatrix`, `NavList` (in the mockup). Variations `VellumBody`, `VellumMuted`,
`VellumHead`, `NumberGood`, `NumberBad`, `TableHeader`, `TableRow`. Tokens `GOOD_INK`, `BAD_INK`, `WARN_INK` and five
chart inks (iron-gall, lapis, madder, verdigris, ochre), each 4.5:1 or more on vellum (a token test).

### D.4 Keyboard, accessibility, options

Bindings `game_report` J and `game_study` I (L opens Economy). Every section, card and page is reachable by Tab; Enter
on a row looks there. Reduce motion: no rising labels, no sliding card, an instant replay before the report. Text size
(M12) reflows the vellum and the chart fonts. Options on the Game page: `game/season_report` (Full), `game/confirm_works`
(Expensive only), `game/preview_on_map` (On: ghost, labels, Yields tint).

### D.5 Tests

| Test | Proves |
|---|---|
| `test_season_summary.gd` (pure) | lines sum to the change; largest first; the quiet state; an unseen event is absent |
| `test_improve_preview.gd` (property, 200 seeded cases) | finish the work, play four calm seasons (luck off): real output and gain equal the preview's to the unit; `game.digest()` unchanged by a preview |
| `test_stats.gd`, `test_knowledge.gd` | ring wraps; save-load-save equal; unknown countries never shown; banding |
| shell tests | report after replay and decisions; Space closes without ending the next season; a study row emits `look_at`; charts draw 0, 1, 40 points |
| perf probe | summary and build list under 2 ms; study page under 16 ms; `stats` phase under 1 ms a country |

### D.6 Risks

Too much to read (guard: fixed order, six lines then "more", Brief, the quiet state); preview drift (one function, the
property test); AI secrets (`knowledge.gd` is the only door to another country); save size (year rows, the probe); a
stale report (it opens last); no seasons in M4's economy (the strip goes flat: question 2).

### D.7 Questions for the owner (recommendation first)

1. **Report every season?** *Full by default, Brief and Off in Options.* Or Brief by default.
2. **Seasons change output** (vintage in autumn, felling in winter, frost and snow by winter slot) with stocks carrying
   goods: *yes, a requirement on M4.* Or flat output with winter penalties only.
3. **Insights placement:** *a small M4.5, then pages with their systems.* Or one Insights milestone after M11.
4. **Others' numbers:** *known countries only, banded.* Or v0.2.2's openness.
5. **The ledger is the study's Economy page (L):** *yes*, instead of the dock panel planned for M4.
6. **Confirm before a work:** *only when expensive*, `cancel_work` as undo. Or always, or never.
7. **History kept:** *40 seasons in detail plus a row a year.* Or every season (about four times the size).
8. **Districts change their ring** (a city lifts its farmland, a town buys the wine): *yes, a little,* set by M4.
