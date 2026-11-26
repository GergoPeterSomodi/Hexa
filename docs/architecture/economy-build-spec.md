# Economy build spec: raw materials, workshops in settlement slots, workers, arms, bread (M9.5, issue 439)

Technical director, 2026-11-25. **Status: a proposal; it waits for the owner's go. Nothing here is built.** Builds
`docs/design/economy-rethink.md` revision 3 with the owner's answers of 2026-11-23 and 2026-11-24 ("the design"), on top of
the fog build and the tile window (`fog-build-spec.md`, `tilewin-build-spec.md`, both on master; the tile window's owner
mockup v4, the Town tab with its wooden building strips, is in the working tree as this is written). Where the design says
something else, this page wins for the build; every place it differs is in section 11. The tasks are in
`economy-build-plan.md`. M9.5 sits between M9 (diplomacy) and M10 (trade) in the roadmap.

**What it is, in one paragraph.** Every land tile makes one raw good. Settlements get **slots** (village 1, town 2, walled
town 3, city 4) that hold **workshops**: the **weaver** (2 wool make 1 cloth), the **armourer** (2 iron make 1 arms) and the
**bakery** (3 grain make 2 bread), one of each per settlement, built and upgraded through three stages by the ordinary works.
They open in set years (armourer 1485, weaver 1490, bakery 1495, the third stage in 1520) until M11's techs replace the
years. A workshop yields by its settlement's level (0.8, 1.0, 1.1, 1.25), gains 25 % when its country owns a working raw
district of its input within two hexes, takes its input from the country's own surplus first and, when its **Buy inputs**
switch is on, buys the rest from a small **home market** at 1.2 times the base price while the treasury stays above a
floor. Workshops employ **workers** from the settlement's hands, like districts. Three goods join the game: **cloth**,
**arms** and **bread**. Bread is food (1.5 a load). **Arms are needed to raise a company**, from the stores or bought at
1.5 times the base price. People grow by `500 + 350 x surplus + 350 x prosperity` permille of today's rate, where comfort
(cloth and bread) is part of prosperity. The tile window's Town tab shows it with no redesign: a **Workshops** strip, the
plaques' name and "N built of M" count (no workers bar yet), the **Slots** chip ("2 / 3"), locked tiles that say what opens them, and the words of every
tooltip.

**The economy build is done when:**

1. Every rule R1 to R70 holds, each with its GUT case and, where section 8 names one, its planted fault (P).
2. On "Italy, 1480", seed 1480, as Genoa (a city, 4 slots): in Spring 1480 every workshop row is locked ("opens in 1485",
   "opens in 1490", "opens in 1495"); in Spring 1485 `build_workshop {hex: Genoa, industry: armourer}` succeeds, the job
   line shows "armourer, first stage", and four seasons later the slot works; a pikemen company raised in Genoa then takes 1
   arms from the stores, or buys it for 14 ducats when the stores are empty.
3. With `IndustryFixture.off` every pinned number of M3 to M9 holds unchanged (Genoa's table of the M4 spec 4.15 included).
4. The preview equals the season to the unit over 200 seeded cases that include workshop builds, the year gates, the Buy
   inputs switch, buying at the floor, bread and raising with arms (R50).
5. `SaveFile.FORMAT` is one above master's when the build starts (8 if M9 has not landed, 9 if it has: R13); an older save
   reads "Made by an older test build"; save, load, save is byte-equal with slots, workshop works and the new goods.
6. The soak's `industry` suite meets its ranges over 10 seeds of 160 seasons (section 9), and the `ai` suite's re-measured
   ranges hold.
7. The perf rows of section 10 are within their limits.
8. Lint, import, check_scripts, GUT, both UI `--check`s, `build_tile_tabs.gd --check`, `build_scenario.gd --check` and
   `bake_ui.py --check` green; the owner has approved the gate mockup (EC0, which includes the workshop card with its Buy inputs switch) and played the plan's checklist.

---

## 1. What is there (master after the fog build and the tile window)

| Finding | Where | Meaning for the build |
|---|---|---|
| 16 goods in four kinds (food, staple, ware, material), ids 0 to 15 append-only; `GoodDef.COUNT` 16; food eaten by `food_order` (fish 0, grain 1) | `core/defs/good_def.gd`, `data/defs/goods/*.tres` | Three goods appended (ids 16 to 18), a fifth kind `made`, a new field `food_permille` (R1) |
| 14 improvement families (`FamilyIds`), each one `FamilyDef` with `base`, `jobs`, `upkeep`, `keep_wild`, `cost`, `cost_goods` per level; grazing and mines make by extra (sheep wool, cattle, horses; iron, copper, silver) | `core/defs/family_ids.gd`, `family_def.gd`, `data/defs/families/*.tres` | No new family: workshops are not pieces. `keep_wild` of hemp, silk, dyes, vineyard and olives (50 / 25 / 0) goes to 0 (R5) |
| A hex holds one piece (main use and level, one byte each); works are one job a hex (`MapState.work_at`) | `core/state/map_state.gd` (schema 5), `core/systems/improve.gd`, `works.gd` | Slots are per-hex arrays beside the piece (R9); the one-job rule already gives N5 |
| "Work slots" already exist: the country's **works crews** (`work_slots_base` 1 plus one per city), `Works.slots`, `WorksView.slots`, the strip's "Works 1 of 3" cell, the refusal "no free work slot" | `core/systems/works.gd`, `core/views/works_view.gd`, `tile_view.gd` | A name clash. The code keeps `Works.slots` for crews; the player's words say "works crews" and "slots" means workshop slots only (D7) |
| Hands and jobs: a district's staffing is the owner's hands (people of the hex and its owned ring x 300 permille) over the jobs on the same hexes; settlements have 0 jobs | `core/systems/economy.gd` (`_hands_and_jobs`, `jobs_i`, `staffed`), `district_cache.gd` | Workshop jobs join the settlement hex's jobs; a workshop's staffing is its settlement's (R26) |
| The season: production (made, needs, sales), income (money lines re-derived from the flows), works, people | `core/game/season.gd`, `core/systems/economy_season.gd` | The workshop step goes inside the pure `goods_step`; the money for bought input is an income line from the `bought` flow (R37, D11) |
| `Stores.FLOWS` made, used, sold, work, refund, dev, army, raise; `Treasury.WHY` ten reasons, `SPENDING` work, refund, raise | `core/systems/stores.gd`, `treasury.gd` | Appended: flows `worked`, `bought`, `crafted`; lines `upkeep_workshops`, `inputs_bought`, `arms_bought` (R40) |
| Growth: `grown = people x growth_bp[tax] x growth_percent[slot] / 1e6`, only when fed; settlements raise themselves to town (`people_top_level` 3) | `core/systems/people.gd` (`_rule`, `season`, `fed_of`) | `_rule` gains the multiplier (R42); `fed_of` counts food units (R35) |
| Raising: `raise_check` order hex, home, occupied, settlement, kind, level, cap, held, stand, men, ducats, goods, books; units cost iron (pikemen 1, crossbowmen 1 + 1 timber, knights 1 + 3 horses, bombards 5 + 3 copper) | `core/systems/military.gd`, `data/defs/units/*.tres` | Iron becomes arms (R45); an arms step joins the check after the ducats (R46) |
| **No refit and no upgrade exist in Godot.** The one way a company regains men is the free `Military.refill` in `ready_units` | `core/systems/military.gd` | N9 ("refit and upgrade need arms") has nothing to change now; recorded for M11 (R49, open question 2) |
| The AI: `AiEconomy.works_scan / works_card / works_act` with a prior in permille a year of the cost; `AiForces._raise_one` tests `treasury - ud.cost` against the reserve; `AiWar.blocker` lists the war gates; `AiTemperDef`, `AiDef` hold the weights | `core/ai/*.gd`, `core/defs/ai_*.gd` | One new option, one new step, three new weights (R58 to R64) |
| Previews: `EconomyPreview` (718 lines) runs the same `goods_step` and money lines as the season; `ImprovePreview` (829 lines, allowlisted) makes the works card | `core/views/economy_preview.gd`, `improve_preview.gd` | Both near or over the size limit: the workshop card goes to a new `core/views/workshop_preview.gd` (R51) |
| The tile window (v4): the Town tab stacks `building_strips.gd` (one wooden strip a group of `TileBuildings.of`: a plaque with the group's icon, name and "N built of M", then icon tiles `BuildingRow` in six states) and `land_facts.gd`; `StripCells` draws up to four chips of `TileView.strip`; `TileBuildings.gate_of` returns `{}`, groups carry `slots: {}` | `shell/panels/tile_tabs/`, `shell/ui/building_row.gd`, `strip_cells.gd`, `core/views/tile_buildings.gd`, `tile_view.gd`, `building_card.gd`, `tile_army.gd`, `company_card.gd` | The models fill the fields the window already reads; the strips gain one tile state and a coin badge (section 6); no bar |
| `SaveFile.FORMAT` 7 (the fog build); the M9 spec also claims 7, the M10 spec 8 and the M11 spec 9 | `core/game/save_file.gd`, `m9/m10/m11-build-spec.md` | The chain is stale; this build takes master's plus one and the later specs move up (R13, Appendix A) |
| The scenario bakes owners, regions, discovery and start armies; pieces come from the map | `core/defs/scenario_def.gd`, `tools/build_scenario.gd` | No start workshops (the owner's Q11): the scenario does not change (R8) |
| `EconomyFixture.defs(calm, still)` is the one entry to test definitions (84 test files use it); `PeopleFixture.still` freezes people | `tests/core/economy_fixture.gd` | `IndustryFixture.off` is applied there by default, so the old pins hold without editing them (R67, D20) |

---

## 2. Decisions taken

| # | Question | Decision | Why |
|---|---|---|---|
| D1 | Where workshops live | Per-hex slot arrays in `MapState` beside the piece: `slot_kind`, `slot_stage`, `slot_flags`, four bytes a hex each (`Slots.MAX` 4) | The hex keeps one piece (M3's rule); dense bytes are cheap to copy, hash and save (about 20 KB a map each) |
| D2 | One owner for the slots | New `core/systems/slots.gd` (`Slots`): the only writer of the three arrays; `OWNS` lists them | The one-owner rule; `Improve.clear_here` calls `Slots.clear_hex` |
| D3 | Where the rules live | New `core/systems/industry.gd` (`Industry`): gates, tier, raw at hand, workers, the working list, the recipe arithmetic, the build checks and actions; new `core/systems/buying.gd` (`Buying`): the home market; new `core/systems/growth.gd` (`Growth`): the multiplier | `economy_season.gd`, `works.gd` and `people.gd` stay small; the names match the readers tech-tree v2 section 5 gives (`Industry.output`, `Slots.count_at`, `Buying.price`, `Works.industry_open`, `Works.stage_max`) |
| D4 | The numbers | New `core/defs/industry_def.gd` (one `.tres` per industry in `data/defs/industries/`) and `core/defs/economy_def.gd` (`data/defs/economy.tres`); `GameDefs` gains `industries` and `economy` | `game_defs.gd` is 558 lines; the `war` and `ai` defs set the pattern |
| D5 | The actions | `build_workshop {hex, industry, tag}`, `upgrade_workshop {hex, industry, tag}`, `set_buy_inputs {hex, industry, on, tag}`; a workshop work is a `Work` with action `&"workshop"`, family 1 (settlements), `industry` and `level_to` the stage | One action table; the works phase, cancel, refund and the job line work unchanged |
| D6 | One job a settlement (N5) | The existing `work_at(hex)` rule: a workshop work and a level upgrade of the same settlement never run at once; a workshop work takes one of the country's works crews | Already true in `Works._begin_check`; no new rule |
| D7 | The word "slot" | Code: `Works.slots` stays (crews). Words: "works crews" for crews ("no free works crew: 3 of 3 in use"), "slots" only for workshop slots | Two meanings of one word on one window would confuse; the tile window's R19 already says "works crews" |
| D8 | Bread's kind | `made`, with `food_permille` 1500 and `food_order` 2; edible means `food_permille > 0` | A made good that is also food; the food code reads one field instead of a kind |
| D9 | How towns eat food (owner, 2026-11-25) | Towns eat the **most efficient food first**: the edible goods sorted by `food_permille` from the highest (bread 1500 a load), then by `food_order` (fish 0 before grain 1, as today's code), then by good id; each takes `min(held, ceil(left / food_permille))`. No comfort share limits the eating | The owner's answer replaces both the design's "bread last" and this page's earlier "bread first up to 30 %"; a load of bread feeds half as much again, so fewer loads leave the store. Consequences in R33 |
| D10 | Cloth for the towns | Cloth has a comfort need (`need_milli` 50 a season per 1,000 town people); towns take it **after** the workshops have made it and before the sale | The design's "cloth met" needs a need; cloth's reserve is 0, so the need must be met in the same season; open question 5 |
| D11 | The money for bought input | Production moves the goods (`bought`), income pays them (`inputs_bought` = the `bought` flow at the buying price, rounded up), as income already does for `tax_goods` from `sold` | One way to pay, the same in the season and the preview; the floor is checked in production on the treasury of that moment |
| D12 | The workshop's product flow | A new flow `crafted`, not `made` | `made` stays the land's output (stats, the Study's columns, M4's pins); the report adds both |
| D13 | Arms bought for a raise | Paid at once in the raise on its own line `arms_bought` (in `SPENDING`), the goods through `bought` then `raise` | A player's choice, not the season's income; `left_over` stays the season's measure |
| D14 | The treasury floor | One season of upkeep: districts, walls, workshops and the army (`buy_floor_seasons` 1) | The design's rule, from numbers the income phase already has |
| D15 | Rounding of the recipe | Input taken in whole batches (`input_loads`); output `batches x output_loads x tier x (1000 + at hand) / 1,000,000`, floored a season and a slot | Integer and exact; no input wasted on a part batch |
| D16 | Raw at hand (N6) | The country's own district (owned and not occupied) whose good is the input, at stage 2 or more, within two hexes; the best one counts: stage 2 250 permille, stage 3 300 (`near_input_permille`) | The owner's answer: +25 %, growing by a small step with the raw tile's stage |
| D17 | Idle slots | A slot at a position at or past `Slots.count_at(level)`, or on an occupied or besieged hex, is **idle**: no output, no jobs, no upkeep; it keeps its stage and wakes by itself | The design: nothing destroyed; an idle slot costs nothing |
| D18 | Year gates | `Works.industry_open(game, tag, industry)` and `Works.stage_max(game, tag)` read the calendar year against `IndustryDef.year` and `EconomyDef.stage3_year`; the tag is unused until M11 | M11 replaces the bodies with tech rows K1 and K2; callers never change |
| D19 | News of an opening | One event `industry_opened {industry, year}` in the `calendar` phase, the first season of the opening year; no phase is added | The first decades get news; the phase table and its pins stay |
| D20 | Keeping old pins | `IndustryFixture.off(defs)` closes every industry (year 9999), turns market buying off (permille 0), fixes the growth multiplier at 1000, restores `keep_wild`, the units' iron costs, zero arms reserve and zero cloth need; `EconomyFixture.defs` applies it unless asked `industry = true` | Every M3 to M9 pin holds without editing 84 files; new tests opt in |
| D21 | Save format | `FORMAT` = master's + 1, `OLDEST_FORMAT` = `FORMAT`, no upgrade step; older saves refused quietly | The owner's Q10 (refuse); public save compatibility starts at M12 |
| D22 | Start stock | Countries start at their reserve, as today: 2 arms each (arms' `reserve_fixed`), no cloth, no bread | One rule; a tiny gift, the soak sees it |
| D23 | Demolishing a workshop | None in v1; clearing the whole settlement drops its slots | One of each industry fits in every slot count; no real need |
| D24 | Groups on the Town tab | Settlement, **Workshops**, Land, Harbour, Defence | The workshops belong to the settlement; one strip a category |
| D25 | The workforce bar (owner, 2026-11-25: nothing yet) | **Deferred.** The Town tab plaques show only the category name and "N built of M"; no workers bar and no workers line in the plaque tooltips. The models still carry `workforce` per group (data kept, R56) so a later bar follows the data without redesign; a bar is a later owner decision and no task asks for one | The owner wants nothing on the plaques beyond the count until real workers data exists |
| D26 | The fourth chip on own land | A settlement shows **Slots** ("2 / 3") in place of Works; other own land keeps Works ("1 of 3") | Tile window D16; the chip row holds four cells |
| D27 | The Buy inputs switch (owner, 2026-11-25: decided, option A) | One switch **per workshop**, on that workshop's own card (the `WorksPreview` screen), opened by a click on its built tile; default on; the AI flips it by the same action. While the workshop is buying, its tile wears a small coin badge. The card (the approved sketch "Buy Inputs Switch", option A) shows the status, what it needs and makes per season, its upkeep, the switch, a line about the 1.2 times price and the treasury floor, and "bought this season" | Hover cards are not interactive; the card is where the numbers are. The sketch's floor of 200 ducats is an example: the rule stays `buy_floor_seasons` and the card prints the country's own floor. EC0 re-draws the final card first |
| D28 | Task IDs | `EC0` to `EC21`; rules `R1` to `R70`, decisions `D1` to `D32` | E, T, F, FG, K, TW are taken |
| D29 | M11 hooks | `Slots.count_at`, `Works.industry_open`, `Works.stage_max`, `Industry.output` and `Buying.price` all take the tag | Tech rows K1 to K6 read per country |
| D30 | AI raises with arms | `AiForces` prices a company as `Military.cost_of(...).ducats + Military.arms_quote(...).cost` against its reserve | It never asks for a raise it cannot pay |
| D31 | The soak twin | The `industry` suite plays each seed twice: A as committed, B with every industry year at 9999 (a raw-only world); ratios are per country of A over B | The design's "industrial twin"; the same seeds and AI in both |
| D32 | Where words come from | Every player-facing string of this build is in `core/views/` (models) or the tooltip table of R57, never built in the shell from numbers | One place for the words, testable headless |

"Open question n" in this page points to section 10 of the plan, where each has a recommendation; the build takes the
recommendation until the owner answers. Open questions 1, 3 and 4 are answered (below); 2, 5 and 6 stay open.

**Owner's answers, 2026-11-25.**

- **Eating order (question 1):** towns eat the most efficient food first, highest food value per load first (D9, R33); this
  replaces both "bread last" and "bread first up to 30 %". Ties go to `food_order`, then good id.
- **Plaque bar (question 4):** nothing yet. Plaques show the category name and "N built of M"; no workers bar; the data is kept
  (D25, R56) and a bar is a later decision, not part of any done-when.
- **Buy inputs switch (question 3):** decided, option A of the sketch "Buy Inputs Switch": one switch per workshop on its own
  card, opened by a click on its tile, default on, with a small coin badge on the tile while it is buying (D27, R61). Every other default is listed in the plan's section 9.

---

## 3. The rules

"P" names the planted fault a test must catch. The viewer `""` (sandbox, tests) sees everything. "Own" land means owned by
the tag and not occupied by another country.

### 3.1 Data

- **R1 Goods.** `GoodDef.KEYS` gains `cloth` (16), `arms` (17), `bread` (18); `COUNT` 19; `KINDS` gains `&"made"`. New field
  `food_permille` (food units a load: grain 1000, fish 1000, bread 1500, all others 0). A good is edible when
  `food_permille > 0`; an edible good has a `food_order` (fish 0, grain 1, bread 2), others -1; it only breaks ties between equal `food_permille` (R33). `validate` allows
  `reserve_fixed` on `made` goods and `need_milli` (a comfort need) on `made` goods with `need_weight` 0.

| Key | Id | Kind | Price (milli) | food_permille | food_order | need_milli | reserve_fixed | Icon |
|---|---|---|---|---|---|---|---|---|
| cloth | 16 | made | 6000 | 0 | -1 | 50 | 0 | `good_cloth` |
| arms | 17 | made | 9000 | 0 | -1 | 0 | 2 | `good_arms` |
| bread | 18 | made | 2400 | 1500 | 2 | 0 | 0 (R33) | `good_bread` |

  P: a good with `food_permille` and no `food_order`; ids out of order.
- **R2 Industries.** `IndustryDef` (`core/defs/industry_def.gd`): `id` (1 to 3; 0 is none), `key`, `name`, `input` (good
  key), `input_loads`, `output` (good key), `output_loads`, `capacity` (input loads a season by stage, `[0, s1, s2, s3]`),
  `jobs`, `upkeep`, `cost`, `cost_goods`, `work_seasons` (each by stage), `year`, `icon`. `IndustryDef.KEYS` is append-only.

| Industry | Id | Recipe | Capacity in, stage 1 / 2 / 3 | Jobs 1 / 2 / 3 | Upkeep a season 1 / 2 / 3 | Cost (ducats + timber) 1 / 2 / 3 | Seasons 1 / 2 / 3 | Opens | Icon |
|---|---|---|---|---|---|---|---|---|---|
| weaver | 1 | 2 wool -> 1 cloth | 8 / 16 / 28 | 500 / 1000 / 2000 | 2 / 3 / 5 | 100 + 5 / 100 + 5 / 180 + 10 | 4 / 8 / 16 | 1490 | `ind_weaver` |
| armourer | 2 | 2 iron -> 1 arms | 4 / 8 / 14 | 500 / 1000 / 2000 | 2 / 3 / 5 | as weaver | 4 / 8 / 16 | 1485 | `ind_armourer` |
| bakery | 3 | 3 grain -> 2 bread | 12 / 24 / 40 | 500 / 1000 / 2000 | 1 / 2 / 4 | as weaver | 4 / 8 / 16 | 1495 | `ind_bakery` |

  Value multiplier m: weaver 2.0, armourer 2.25, bakery 1.6 (product value over input value at base prices). P: an industry
  whose input or output is not a known good; capacity falling with the stage.
- **R3 The economy numbers.** `EconomyDef` (`core/defs/economy_def.gd`, `data/defs/economy.tres`):

| Field | Value | Meaning |
|---|---|---|
| `slots_by_level` | 0, 0, 1, 2, 3, 4 | workshop slots by settlement level 0 to 5 (hamlet 0, village 1, town 2, walled town 3, city 4) |
| `tier_permille` | 0, 0, 800, 1000, 1100, 1250 | workshop yield by settlement level (no hamlet) |
| `near_input_permille` | 0, 0, 250, 300 | raw-at-hand bonus by the raw district's stage (N6) |
| `near_input_radius` | 2 | hexes |
| `market_buy_permille` | 1200 | workshop inputs bought at 1.2 x base; 0 = no market |
| `arms_buy_permille` | 1500 | arms bought at 1.5 x base (N7 placeholder); 0 = no market |
| `buy_floor_seasons` | 1 | seasons of upkeep kept in the treasury when buying input |
| `stage3_year` | 1520 | the third stage of every industry opens |
| `growth_base`, `growth_surplus`, `growth_prosperity` | 500, 350, 350 | permille of the growth multiplier (R42) |
| `surplus_full_permille` | 250 | a surplus of 25 % of the need counts full |
| `bread_comfort_share` | 300 | permille of the food need that, eaten as bread, gives full bread comfort (it no longer limits the eating) |

- **R4 Arms in the units' costs** (N7: 1 arms a company, 2 for bombards; the other goods unchanged):

| Company | Today | New |
|---|---|---|
| Pikemen | 25 + 1 iron | 25 + 1 arms |
| Crossbowmen | 30 + 1 iron + 1 timber | 30 + 1 arms + 1 timber |
| Knights | 45 + 1 iron + 3 horses | 45 + 1 arms + 3 horses |
| Bombards | 60 + 5 iron + 3 copper | 60 + 2 arms + 5 iron + 3 copper |

- **R5 One raw a tile (Q5).** `keep_wild` of hemp, silk, dyes, vineyard and olives becomes 0, 0, 0, 0; settlements
  (100, 100, 100, 75, 50), castles (100) and the families already at 0 keep theirs. P: a goods district stage 1 still giving
  its cover's grain.
- **R6 Families, categories and raw.** No family changes. The categories and raw goods the Town tab and the at-hand rule read:

| Family (id) | Category on the Town tab | Raw it makes | Feeds |
|---|---|---|---|
| settlements (1) | Settlement | its wild yield (grain), port fish | (bakery only through the country's stock) |
| castles (2) | Defence | wild yield kept 100 % | |
| wheat (3) | Land | grain | **bakery** (at hand) |
| hemp (4), silk (5), dyes (6) | Land | hemp, silk, dyes | (later rope; none in M9.5) |
| vineyard (7), olives (8) | Land | wine, oil | |
| grazing (9) | Land | wool (sheep), cattle, horses (by extra) | **weaver** (sheep pasture at hand) |
| timber (10), quarry (12), salt (13) | Land | timber, stone, salt | |
| mines (11) | Land | iron, copper, silver (by extra) | **armourer** (iron mine at hand) |
| harbour (14) | Harbour | fish | |
| weaver, armourer, bakery (industries) | **Workshops** | cloth, arms, bread | |

  The at-hand test asks `Economy.good_of(view, hex) == the input` (so a grazing district counts for the weaver only with
  sheep, a mine for the armourer only with iron).
- **R7 Defs check and digest.** `GameDefs.validate` checks 19 goods, 3 industries (ids 1 to 3 once, keys in order), the
  `EconomyDef` sizes and bounds (slots 0 to 4 rising, tiers 0 to 2000, permilles 0 to 3000, years 1480 to 1650); `digest()`
  feeds both. `GameDefs.industry(id)` and `industry_id(key)` look them up.
- **R8 No start workshops (Q11).** No scenario has slot rows; `ScenarioDef` and `build_scenario.gd` are unchanged and
  `--check` stays green. P: a game at turn 0 with any slot filled.

### 3.2 State, saves, digest

- **R9 Slots in the map state.** `MapState` gains `slot_kind`, `slot_stage`, `slot_flags` (`PackedByteArray`, size hexes x
  `Slots.MAX`); entry `i * 4 + k` is slot position `k` of hex `i`: kind = industry id (0 empty), stage 1 to 3, flags bit 0 =
  Buy inputs **off** (so 0 is the default on). Positions are filled from 0 in build order and never have holes. `create`,
  `duplicate_state`, `to_dict` (base64), `from_dict` and `digest` carry them; the schema goes up one (`map-state/6` if M9 has
  not landed, else M9's plus one); the previous schema reads with empty slots (tests only).
- **R10 The what-if overlay.** `StateView.with_slots(changes)` lays slot rows over the view (hex index -> PackedByteArray of
  `Slots.MAX * 3` bytes: kinds, stages, flags) and `slot_kind_at(i, k)`, `slot_stage_at(i, k)`, `slot_flags_at(i, k)` read
  through it, like `with` and `with_people`. P: a view that writes the base.
- **R11 The workshop work.** `Work` gains `industry` (int, 0 for other works); `ACTIONS` gains `"workshop"`; the schema goes up
  one (`work/3`; `work/2` reads with industry 0). A workshop work has family 1, `level_to` = the stage it builds.
- **R12 One writer.** `Slots.put(game, hex, industry, stage)`, `Slots.set_flags(game, hex, industry, flags)` and
  `Slots.clear_hex(game, hex)` are the only writes of the three arrays; each touches `game.districts` for the hex and bumps
  `game.version` as `Improve` does; `test_owns.gd` and `test_no_other_writers.gd` cover them. P: a planted write in
  `industry.gd`.
- **R13 The save format.** `SaveFile.FORMAT` = master's FORMAT + 1 at the start of the build and `OLDEST_FORMAT` = FORMAT (8 if
  M9 has not landed; 9 if M9 landed with 8). The older file is refused quietly: "Made by an older test build". The body keeps
  its keys; `map_state` and `works` carry R9 and R11; goods arrays have 19 entries. No upgrade step. P: an older file loaded.
- **R14 Digest and round trip.** `Game.digest()` changes only through `MapState.digest()` (the three arrays) and the work's
  `industry`; save, load, save is byte-equal on north Italy turn 40 with three workshops and one under way; ten seasons after
  a load give the digest of ten without. P: the flags left out of the digest.

### 3.3 Slots and building

- **R15 Slot count (N4).** `Slots.count_at(game, tag, level) -> int` = `slots_by_level[level]` (0 for any non-settlement);
  `Slots.used(game, view, i)` = filled positions; `Slots.free(game, view, i)` = count - used, at least 0. P: a hamlet with a
  slot.
- **R16 One of each (N4).** A settlement holds at most one workshop of each industry; positions are in build order.
- **R17 `build_workshop_check {hex, industry, tag}`**, the first refusal in this order (each `{ok, reason, kind}`; `kind` is
  `&""`, `&"gate"`, `&"level"` or `&"rule"`):
  1. no hex, no industry, unknown industry ("no such workshop");
  2. home (`Territory.at_home_check`);
  3. not a settlement: "workshops stand in villages, towns and cities";
  4. a work under way (the works' own words, `Works._begin_check` row 3);
  5. occupied or besieged (row 3b's words);
  6. gate: "opens in 1490" (`kind` gate; R19);
  7. already one: "this town has a weaver";
  8. no free slot: a hamlet "hamlets have no workshop slots: a village has 1"; else "every slot is taken: a town has 2, a
     walled town 3" (`kind` level: the next level's count);
  9. no free works crew: "no free works crew: 3 of 3 in use";
  10. payment: ducats, then goods (the works' own words).
  `build_workshop` checks again, begins the work (`Works._begin_workshop`: pays, appends, emits `work_started`). P: a check
  that passes where the action refuses (the check/act pair over every settlement of three countries).
- **R18 `upgrade_workshop_check {hex, industry, tag}`**: rows 1, 2, 4, 5 as R17; "no weaver here"; "the weaver is idle: <why>";
  "the weaver is at its top stage" (stage 3); gate "the third stage opens in 1520" (`kind` gate, `Works.stage_max`); crews;
  payment. Cost and seasons of stage s are `IndustryDef.cost[s]`, `cost_goods[s]`, `work_seasons[s]`. When the work finishes,
  `Industry.finish_here` sets the stage (`Slots.put`); a build whose slot vanished meanwhile (the town fell a level) is
  cancelled "blocked" as works are today.
- **R19 The gates (N1).** `Works.industry_open(game, tag, industry) -> bool`: the year of `game.turn` is at least
  `IndustryDef.year`; `Works.stage_max(game, tag) -> int`: 3 from `stage3_year`, else 2. Before M11 the tag is unused.
  P: a weaver begun in Winter 1489.
- **R20 Cancel and refund.** A workshop work cancels and refunds like any work (the season it began: ducats and goods back).
- **R21 Idle (D17).** `Industry.idle_why(game, view, i, k) -> String`: "" when working; else "the town is too small for 3
  workshops" (position at or past the count of its level), "occupied by the <occupier>", "under siege". An idle slot keeps
  its kind, stage and flags; it makes nothing, employs no one, pays no upkeep and wakes when the cause ends. P: a level drop
  that idles any slot but the top ones.
- **R22 Capture, cession, clearing.** Slots belong to the hex: a new owner gets them at once with their stages and flags; the
  raw-at-hand bonus is recomputed from the new owner's land the same season. `Improve.clear_here` on a settlement calls
  `Slots.clear_hex` (the work card's words say "its workshops are pulled down"). P: slots left on a cleared hex.
- **R23 `set_buy_inputs {hex, industry, on, tag}`**: own settlement, a built workshop of that industry, `on` a bool and not
  already so ("buying is already on"); sets bit 0; emits `buy_inputs_set {tag, hex, industry, on}`. Free; not a work.
- **R24 Fog of slots.** A slot's kind and stage are facts of the land: shown with the hex once discovered (light fog exact),
  with "working" or "idle"; its output, tier, bonus, staffing, stocks and buying are own-only.

### 3.4 Recipes and the season

- **R25 Tier (Q3).** `Industry.tier(game, view, i) = tier_permille[level]`; a level change changes it at once.
- **R26 Workers.** A working slot has `IndustryDef.jobs[stage]` jobs; `Economy.jobs_i` of a settlement hex adds the jobs of its
  working slots (so they share the hands of the hex and its owned ring with the districts round it, the M4 hands rule);
  `Economy.staffing` of a settlement with working slots is `_staffing_i` (1000 before); `DistrictCache` keeps them in
  `F_JOBS`. `Industry.workforce(game, view, i) -> {employed, capacity}` = (sum of jobs x staffing / 1000, sum of jobs).
  P: workshop jobs left out of a neighbouring district's staffing.
- **R27 Raw at hand (D16).** `Industry.at_hand(game, view, i, industry, tag) -> {permille, hex}`: the best own, unoccupied hex
  within `near_input_radius` whose good is the input and whose stage is 2 or more: `near_input_permille[stage]`; ties: the
  lower hex index; `{0, NO_HEX}` for none. Foreign tiles never count. P: a foreign iron mine counted; a stage-1 pasture counted.
- **R28 The working list.** `Industry.working_of(game, view, tag) -> Array[Dictionary]`, the country's working slots in
  settlement index then position order: `{hex, i, position, industry, stage, tier, at_hand, at_hand_hex, staffing, capacity
  (capacity[stage] x staffing / 1000, rounded down to whole batches), buy (bool), upkeep, jobs}`. Pure; reads only the view,
  the map, the owners and the occupation. Cached per `game.version` for the game's own view.
- **R29 The recipe.** `Industry.output(defs, industry, input_loads, tier, at_hand) -> int` =
  `(input_loads / input_loads_of_recipe) x output_loads x tier x (1000 + at_hand) / 1,000,000`, floored; the input is always
  whole batches.
- **R30 Own input first, then bought.** For each working slot in order, with the stock after the needs (R32):
  `own = min(capacity, held[input] - reserve[input])` in whole batches (never below the reserve); then, if its switch is on
  and `Buying.price` is above 0, `bought = min(capacity - own, what the treasury can pay above the floor)` in whole batches;
  the treasury budget falls by each purchase's cost before the next slot. P: own input taken from the reserve.
- **R31 The home market (N2).** `Buying.price(game, tag, good) -> int` (milli a load) = base x `market_buy_permille` / 1000 for
  a workshop input, x `arms_buy_permille` / 1000 for arms; 0 for any other good or when the permille is 0. `Buying.plan(game,
  tag, good, loads, budget) -> {loads, ducats}` (pure: the most whole batches the budget pays, `ducats` = ceil(loads x price /
  1000)); `Buying.take(game, tag, good, loads, why) -> bool` (`Stores.move(+loads, &"bought")`; the money is R37's or R46's).
  Supply is unlimited; nothing is sold through it; towns never buy. **M10 replaces the bodies**; callers stay.
- **R32 The goods step** (`EconomySeason.goods_step`, pure; the order is the rule):
  1. **held** = stock + made;
  2. **needs**: food in food units (R33), then wine, salt, oil as today;
  3. **works**: each working slot of R28 in order (R30, R29): input taken, bought, crafted (added to held);
  4. **comfort**: towns take cloth up to its need (`need_loads(town, cloth.need_milli)`);
  5. **sales**: held above the reserve is sold at `prices`.
  It returns today's keys plus `worked` (input taken by good, positive), `bought` (by good), `crafted` (by good),
  `bought_milli`, `slots` ([{position, own, bought, crafted}] in R28's order). With no working slot and no bread or cloth it
  returns exactly today's values. P: works before needs; the reserve lowered by a workshop.
- **R33 Food units (N3, D9).** Food need in units = today's loads (`food_need_milli`); towns eat in milli-units, the **most
  efficient food first**: every edible good sorted by `food_permille` descending, then `food_order` ascending, then good id (so
  bread 1500, fish 1000, grain 1000: a fixed order, no randomness), each `take = min(held, ceil(left / food_permille))`;
  `taken.food` = need - ceil(left / 1000), at most the need (the last bread load may overshoot by under 1.5 units: capped,
  not carried). Grain's reserve stays four seasons of the food need (and the armies' food, which is grain only); bread's
  reserve stays four seasons of the comfort share (`reserve_seasons x need_loads(town, food_need_milli x share / 1000) x 1000
  / 1500`, rounded up), and now only guards the sale: bread is eaten before anything else, so it is sold only above the whole
  food need. `content_of` and `People.fed_of` count food units (`used x food_permille / 1000`). With no bread every number
  equals today's (fish before grain). P: bread eaten after grain; a tie broken by anything but `food_order`.
  *Consequences (owner's answer of 2026-11-25).* (a) **Comfort:** `bread met` (R44) is the bread eaten over the comfort share
  of the need, so it reaches 1000 as soon as the stock the bakeries left at the start of the season is 30 % of the need in
  units, and it is proportional below that; bread eaten above 30 % feeds but adds no comfort. Bread baked in the works step is
  in the stock for the next season's eating (needs come before works). (b) **Growth:** the surplus counts food made less food
  eaten in units, so it does not depend on the order; growth differs from the old "up to 30 %" rule only through the stock.
  (c) **Stock and sale:** towns draw bread down first, so the bread stock stays near zero and bread is sold only when the
  bakeries outrun the whole food need; grain and fish stay in the store longer (more carry, a little more sold). A bakery
  earns by sparing grain and fish, not by selling bread, until M10 prices bite. (d) **The soak (EC17, EC20):** new records
  `bread_eaten` and `bread_sold` per country and a range for bread's share of the food eaten; the `industry` income ratio
  and the bakery's payback (so the AI's bakery prior) are re-measured; the levers are data (`bread_comfort_share`, the
  bakery's recipe and years). Whether bread's reserve should become four seasons of the whole food need is left to EC20.
- **R34 Needs before workshops.** After the works step every town's need of this season is still met as before it and the
  reserve of every good is unchanged (a pinned property over 40 seeded seasons).
- **R35 No double counting.** The country's food made for the surplus (R43) = edible `made` and `crafted` in units minus the
  own grain the workshops took (`worked - bought` of grain); bought grain baked is an import (it adds bread, takes no stock).
- **R36 The production phase** applies the step per living country in id order: `made`, `bought`, `crafted`, `worked`
  (negative), `used`, `sold` (this order never takes a stock below 0); a need short emits `goods_short` as today.
- **R37 Income.** `money_lines` gains `upkeep_workshops` (minus the working slots' upkeep, count = working slots) and
  `inputs_bought` (minus ceil(sum of the `bought` flow x `Buying.price` / 1000), count = goods bought); tax_goods counts made
  goods sold. P: bought input paid twice (production and income).
- **R38 The treasury floor (D14).** Buying in production is allowed while `treasury - cost >= floor`, `floor` =
  `buy_floor_seasons x (upkeep_districts + upkeep_walls + upkeep_workshops + upkeep_army)` of the season (positive
  amounts); a treasury at or under the floor buys nothing. P: buying that takes the treasury under the floor.
- **R39 No weather, no winter** on workshops (flat all year); a besieged settlement's slots are idle (R21).
- **R40 Flows and lines.** `Stores.FLOWS` appends `worked`, `bought`, `crafted`; `Treasury.WHY` appends `upkeep_workshops`,
  `inputs_bought`, `arms_bought`; `SPENDING` gains `arms_bought`. "Closing minus opening equals the sum of the flows" and the
  money identity hold (`test_money_property.gd`, the goods property). Input taken = `-worked`; own input = `-worked - bought`.
- **R41 Stats.** `Stats.SERIES` appends `workshops` (working slots), `crafted_value` (crafted at price, ducats),
  `inputs_bought`, `upkeep_workshops`, `arms_bought`, `surplus`, `prosperity` (permille); a save with fewer columns loads the
  rest as zeros (the existing rule).

### 3.5 People (Q8)

- **R42 The multiplier.** `Growth.mult(surplus, prosperity, defs) = growth_base + surplus x growth_surplus / 1000 + prosperity x
  growth_prosperity / 1000` (permille, 500 to 1200). `People._rule` grows `min(p x rates.x x mult / 1e9, room - p)`; hunger,
  crowding, the level steps and `people_top_level` are unchanged. With `mult` 1000 every number equals today's. P: the
  multiplier applied to hunger.
- **R43 Surplus.** `Growth.surplus(made_units, eaten_units, need) -> permille` = clamp((made - eaten) x 1000 x 1000 / (need x
  `surplus_full_permille`), 0, 1000); need 0 gives 1000. `eaten` = the towns' food used plus the armies' (`army` flow), in units.
- **R44 Prosperity and comfort.** `prosperity = (content + comfort) / 2`; `content` = M4's contentment (R33 units);
  `comfort = (cloth met + bread met) / 2`: cloth met = cloth used over its need (1000 when the need is 0), bread met =
  bread eaten in units over `need x bread_comfort_share / 1000`, at most 1000 (bread is eaten first, so it is met whenever the stock holds that share). Growth only: taxes do not read it.
  A fed, content country with no workshop gets `mult` about 500 + 350 x surplus + 175: about today's pace at a 25 % surplus.
  `People.season` computes `mult` per country from the open flows (`Growth.of_flows(game, c)`); the preview from its step's
  arrays (`Growth.of_step`), the same pure function. P: the preview's mult read from the flows of the game.

### 3.6 Arms

- **R45 Arms are needed (Q12).** The unit costs of R4. Arms are kept in the stores by their reserve (2) and sold only above it.
- **R46 The raise's arms step.** `raise_check` keeps its order and after "not enough ducats" asks
  `Military.arms_quote(game, tag, kind, count) -> {need, own (from the stores, the reserve included), bought, price, cost}`:
  the shortfall is bought at `arms_buy_permille`; refused when `ducats + cost > treasury`. `raise` then moves the bought arms
  in (`Buying.take`, `bought`), pays them (`Treasury.move(-cost, &"arms_bought", hex)`), takes all its goods (`raise`) and the
  ducats as today. No floor applies (war cannot wait). P: a raise that leaves the stores negative; a check that passes where
  the raise refuses.
- **R47 No arms and no money (N8).** One line, nothing changed: "no arms: 1 needed, 0 in the stores, 14 ducats to buy it, 8 in
  the treasury"; with the market off "no arms: 1 needed, 0 in the stores, and none can be bought". No unarmed company.
- **R48 The texts.** `raise_options` cost text "25 · 1 arms"; the arms part of every card from `arms_quote` (R60).
- **R49 Refit and upgrade (N9).** Neither exists in Godot. M11's refit and upgrade (era troops, tech row K7) must take arms
  through `arms_quote` (Appendix A). `Military.refill` (men regained in supply) stays free in M9.5 (open question 2).

### 3.7 Previews

- **R50 The preview equals the season.** `EconomyPreview.with` passes each season's working list (from its view, with
  `changes.slots` laid over by `StateView.with_slots`) and the running treasury (the treasury now plus the earlier seasons'
  net) to `goods_step`; `money_lines` gets the same upkeep and bought numbers; the people step uses `Growth.of_step`. Over
  200 seeded cases (builds, upgrades, gates, the switch, the floor, bread, cloth, raises) the preview of the next season
  equals the played season to the unit. P: the preview reading the game's treasury after season 1.
- **R51 The workshop card.** `ImprovePreview.of(game, tag, hex, {action: &"workshop", industry, stage})` delegates to
  `WorkshopPreview.of` (new `core/views/workshop_preview.gd`) with the card's usual keys (verdict, `blocked_by`, cost,
  seasons, payback, year gain, chips, marks) plus `workshop {recipe_text, tier, tier_text, at_hand {permille, hex, text},
  capacity, workers {employed, capacity}, buy, year {own, bought, crafted, bought_ducats, upkeep}}`; the year gain is the realm
  measure as for every card. `ImprovePreview.options_of` lists a settlement's workshop options. Marks include the at-hand hex.
  P: a gain that differs from EconomyPreview's year difference.
- **R52 One card for all.** The Town tab, the works card screen and the AI read the same `ImprovePreview.of`; the AI never
  has its own arithmetic for the take decision (its prior is only the scan's sort, R59).

### 3.8 The window follows the data (section 6 has the tables)

- **R53 The Slots chip.** On an own settlement `TileView.strip`'s third cell is `{key "slots", value "2 / 3", label "Slots",
  tone plain}` (used includes a workshop under way; bad tone never); other own land keeps "works". P: a slots chip on a
  district.
- **R54 Land facts.** `TileView.land` gains `raw` (`{good, name, loads}` this season, own and foreign-discovered: "Raw: wool,
  12 loads this season") and, own only, `workers` (`{employed, capacity, hands}` of the tile, Economy's hands and jobs). The
  Food chip (`MapModes.food_year`) counts a settlement's bakery: bread made in units less the own grain it takes, over a calm
  year.
- **R55 The Workshops group.** `TileBuildings.of` gains group `workshops` (after `settlement`, settlement hexes only) with
  `slots {used, total}` and rows: one **built** row per filled slot (state `built`, or `idle` with its reason; `level` = the
  stage), one **building** row for a workshop work, one **upgrade** row per built workshop below `stage_max` (ready, short,
  locked by `stage3_year`, refused), one **build** row per industry not built here (ready, short, locked by year `kind` gate,
  locked by slots `kind` level). Every hammer is its check's ok. `gate_of` returns `{year}` from the check's `kind` gate;
  `state_of` maps `kind` level to `locked` too. P: a ready row for a closed industry; a hammer that disagrees with its check.
- **R56 The workforce data (D25; no bar yet).** Every group still carries `workforce: {} | {value, max, text, tip}`: Land and
  Harbour: the district on the hex (`jobs x staffing / 1000` of `jobs`); Workshops: `Industry.workforce`; Settlement: people
  of room; Defence: garrison men of full (a fortress only). The shell draws **no bar** and prints none of these in a plaque
  tooltip; the plaque shows the name and "N built of M" only (a later bar is the owner's decision and reads these fields as
  they are). P: a `workforce` value above its max.
- **R57 The words.** Every tooltip and line of section 6.3 comes from the models (`TileBuildings` rows' `state_text`, `tip`,
  the groups' `tip`, `TileView` cells' `tip`); the shell prints them. P: a shell file that formats a number into a tooltip
  of this build.
- **R58 Foreign tiles.** `TileView.land.buildings` lists slot buildings ("Weaver, second stage · working"); the strip's
  Buildings count includes them; nothing of output or buying. P: a foreign slot's output in any model.
- **R59 Growth on the town.** `TileView.land.people` gains, on an own settlement, `growth {mult, surplus, prosperity, comfort,
  word}` from `Growth.of_flows` of the last closed season (`word`: "slow" under 700, "steady" under 1000, "fast" from 1000);
  the Land facts show the surplus and prosperity bars, the word, and the food line in units where bread is eaten ("Food:
  40 units eaten, 6 of them bread"). P: a growth word on a foreign town.
- **R60 Arms in the Army tab.** `TileArmy.raise.arms = {in_stores, premium_text: "bought arms cost 13.5 each (+50 %)"}`;
  `CompanyCard` lines "arms: 1 from the stores (6 there)" or "arms: 1 bought, 14 ducats"; a company row's state line
  "500 men · 25 ducats + 1 arms · upkeep 6".
- **R61 The workshop card on screen.** `WorksPreview.show_option` shows R51's workshop section and, for a built workshop,
  the **Buy inputs** switch (`KitSwitch`, `Session.act("set_buy_inputs", ...)`, per workshop); the workshop's tile wears a coin
  badge while it is buying (`buying` on its `TileBuildings` row); a click on a built workshop tile opens the card
  (`works_requested {what: &"workshop_card", args: {hex, industry}}`).
- **R62 Map marks.** A small trade mark beside a settlement per working slot (loom, anvil, loaf: the industry icons), drawn
  from a pure `core/views/workshop_marks.gd` (fog: discovered hexes only); idle slots draw no mark.
- **R63 Study, report, reminders, log.** The Study's goods page lists 19 goods with `worked`, `bought`, `crafted` columns and an
  Industries list (each industry: open or "opens in 1490", the country's workshops, made a year); the treasury page names
  the three new lines; the report adds per good worked, bought, crafted and "Industry added +64 this year" (new
  `core/views/summary_industry.gd`); a reminder "The weaver's craft is open: you have a free slot in Asti" for four seasons
  after an opening while the player has a free slot and none of that industry; log lines for `industry_opened`,
  `buy_inputs_set` and workshop works (new `core/views/log_lines_industry.gd`); the People page shows each country's growth
  word (R59).

### 3.9 The AI

- **R64 The workshop option.** `AiKnow.work_candidates` already holds own settlements; `AiEconomy._scan_hex` adds on a
  settlement every workshop build and upgrade option whose check is ok or refused only for money. **The prior** (permille a
  year of the cost, as districts): with `own_est` = the input the country sold last closed season (its surplus, per season),
  `cap` = the stage's capacity (full staffing), `margin` = `output_loads / input_loads x product price x tier x (1000 + at
  hand) / 1,000,000 - Buying.price(input)` per input load, `bought_est` = `cap - own_est` if `margin > 0` else 0:
  `value = 4 x (crafted x product price - own x input price - bought x buy price) / 1000 - 4 x (upkeep[s] - upkeep[s - 1])`
  with `crafted` from R29; `prior = value x 1000 / (cost ducats + cost goods at price)`; 0 when `value <= 0`. The take
  decision is the card's payback (R52).
- **R65 Weights.** `AiTemperDef.industry_priority` (permille by industry id) multiplies the score:

| Temper | Weaver | Armourer | Bakery |
|---|---|---|---|
| builder | 1300 | 1000 | 1500 |
| cautious | 1000 | 1200 | 1300 |
| steadfast | 1000 | 1500 | 1200 |
| aggressive | 900 | 2000 | 1000 |
| opportunist | 1500 | 1200 | 1000 |

  The armourer's weight is also at least `AiDef.arms_priority` (1500) while arms in store are under the reserve plus
  `war_arms_companies`.
- **R66 Siting.** A district build or upgrade to stage 2 or 3 whose good is the input of an own built or building workshop
  within two hexes gets priority at least `AiDef.at_hand_priority` (1500); a settlement upgrade whose level adds a slot,
  while an open industry is not yet built there, adds `AiDef.slot_value` (10 ducats a season) to its year.
- **R67 The buying step.** A new AI step `buying` (after `works_act`, before `forces`): for each own built workshop, the switch
  is set on when `margin > 0`, off when `margin <= 0`, except an armourer while arms in store are under the reserve plus
  `war_arms_companies` (kept on); through `AiKnow.act("set_buy_inputs", ...)`; one trace line each change.
- **R68 Raising and war.** `AiForces._raise_one` tests `treasury - (ducats + arms cost) >= reserve` (D30). `AiWar.blocker`
  adds, after the war chest: "it cannot arm 4 companies (2 arms, 27 ducats short)" when arms in store plus
  `(treasury - chest) x 1000 / arms price` is under `war_arms_companies` (asked only when some unit kind's cost names arms,
  so under `IndustryFixture.off` nothing changes). The blocker only stops a declaration; a country at
  war still makes peace by `AiPeace` (no deadlock by construction). `AiWar.prize_of` adds `AiDef.industry_value` (300) per
  working slot it has seen in the target's land within `prize_range`. Traces: "industry: weaver in Genoa slot 2, own wool at
  hand, payback 12 seasons". P: an AI raise refused for arms it could not pay (the soak counts refusals).

### 3.10 Determinism, fixtures, soak, speed

- **R69 Determinism.** No luck in any rule of this build; every loop is in id, index or position order; every amount an int
  with non-negative operands or `Economy.floor_div`. The AI's jitter draw count does not change for a seat with no workshop
  option (one draw per card as today).
- **R70 The fixture (D20).** `IndustryFixture.off(defs)` (tests only, `tests/core/industry_fixture.gd`) and `on(defs)`;
  `EconomyFixture.defs(calm, still, industry = false)` applies `off` unless `industry` is true. With `off`, the M3 to M9 pins
  and Genoa's table hold unchanged, and the fixture games' digests move only once, when R14 adds the slot arrays to the
  digest. P: a pinned test that only passes with
  the fixture on.

---

## 4. Interfaces

```gdscript
# core/defs/industry_def.gd (new) @tool Resource; data/defs/industries/weaver.tres, armourer.tres, bakery.tres
const KEYS: Array[StringName] = [&"", &"weaver", &"armourer", &"bakery"]   # append-only; id = index
@export var id: int; key: StringName; name: String; input: StringName; input_loads: int; output: StringName
@export var output_loads: int; capacity, jobs, upkeep, cost, work_seasons: PackedInt32Array   # [0, s1, s2, s3]
@export var cost_goods: Array[Dictionary]; year: int; icon: StringName
func validate(defs: Resource = null) -> Array[String]

# core/defs/economy_def.gd (new) @tool Resource; data/defs/economy.tres (R3's fields)
func validate() -> Array[String]

# core/defs/game_defs.gd (edit): @export var industries: Array[IndustryDef]; @export var economy: EconomyDef
func industry(id: int) -> IndustryDef; func industry_id(key: StringName) -> int

# core/state/map_state.gd (edit): var slot_kind, slot_stage, slot_flags: PackedByteArray
# core/state/state_view.gd (edit): func with_slots(changes: Dictionary) -> StateView
#   func slot_kind_at(i: int, k: int) -> int; slot_stage_at(i, k) -> int; slot_flags_at(i, k) -> int
# core/state/work.gd (edit): var industry: int = 0; SCHEMA work/3

# core/systems/slots.gd (new) OWNS ["slot_kind", "slot_stage", "slot_flags"]
const MAX := 4
static func count_at(game: Game, tag: StringName, level: int) -> int
static func used(game: Game, view: StateView, i: int) -> int
static func rows(game: Game, view: StateView, i: int) -> Array[Dictionary]   # [{position, industry, stage, buy}]
static func position_of(game: Game, view: StateView, i: int, industry: int) -> int   # -1 none
static func put(game: Game, hex: Vector2i, industry: int, stage: int) -> bool
static func set_flags(game: Game, hex: Vector2i, industry: int, flags: int) -> bool
static func clear_hex(game: Game, hex: Vector2i) -> void

# core/systems/industry.gd (new) OWNS []
static func build_workshop_check(game, args) -> Dictionary; build_workshop(game, args) -> Dictionary
static func upgrade_workshop_check(game, args) -> Dictionary; upgrade_workshop(game, args) -> Dictionary
static func set_buy_inputs_check(game, args) -> Dictionary; set_buy_inputs(game, args) -> Dictionary
static func finish_here(game: Game, work: Work) -> Dictionary      # called by Works._put_piece
static func tier(game: Game, view: StateView, i: int) -> int
static func at_hand(game: Game, view: StateView, i: int, industry: int, tag: StringName) -> Dictionary
static func idle_why(game: Game, view: StateView, i: int, k: int) -> String
static func jobs_at(game: Game, view: StateView, i: int) -> int     # read by Economy.jobs_i
static func workforce(game: Game, view: StateView, i: int) -> Dictionary
static func working_of(game: Game, view: StateView, tag: StringName) -> Array[Dictionary]
static func output(defs: GameDefs, industry: int, input_loads: int, tier: int, at_hand: int) -> int
static func margin_milli(game: Game, tag: StringName, row: Dictionary) -> int   # per bought input load (AI, card)
static func season_news(game: Game) -> void                          # industry_opened, from the calendar phase

# core/systems/buying.gd (new) OWNS []
static func price(game: Game, tag: StringName, good: int) -> int     # milli a load; 0 = not buyable
static func plan(game: Game, tag: StringName, good: int, loads: int, budget: int, batch: int = 1) -> Dictionary
static func take(game: Game, tag: StringName, good: int, loads: int) -> bool

# core/systems/growth.gd (new) OWNS []
static func mult(defs: GameDefs, surplus: int, prosperity: int) -> int
static func surplus(defs: GameDefs, made_units: int, eaten_units: int, need: int) -> int
static func of_flows(game: Game, c: Country) -> Dictionary           # {mult, surplus, prosperity, comfort}
static func of_step(game: Game, step: Dictionary, needs: Dictionary) -> Dictionary

# core/systems/works.gd (edit)
static func industry_open(game: Game, tag: StringName, industry: int) -> bool
static func stage_max(game: Game, tag: StringName) -> int
static func workshop_cost(game: Game, industry: int, stage: int) -> Dictionary
# core/systems/economy_season.gd (edit): goods_step(game, needs, reserve, stock, made, prices, slots := [], budget := 0)
# money_lines(..., workshop_upkeep := 0, workshop_count := 0, bought_milli := 0, bought_count := 0)
# core/systems/military.gd (edit): static func arms_quote(game, tag, kind, count) -> Dictionary
# core/game/actions.gd (edit): "build_workshop", "upgrade_workshop", "set_buy_inputs"

# core/views/workshop_preview.gd (new); core/views/workshop_marks.gd (new); core/views/summary_industry.gd (new);
# core/views/log_lines_industry.gd (new)
```

New events (the `Game.emit` kinds, `Session`'s drain and `Events` signals): `industry_opened {industry, year}` (witnesses
all), `buy_inputs_set {tag, hex, industry, on}`. Work events carry the work's `industry`.

---

## 5. The season step in one picture

```
production, per country in id order (pure goods_step, then the moves)
  held   = stock + made                                    (districts, as M4)
  needs  = food, the most food per load first (bread, then fish, grain); wine, salt, oil
  works  = for each working slot (settlement index, position):
             own    = min(capacity x staffing, held - reserve)          whole batches
             bought = Buy on and price > 0 ? min(capacity - own, budget above the floor) : 0
             crafted = batches x out x tier x (1000 + at hand) / 1e6    floored
  comfort = towns take cloth up to its need
  sales   = held above the reserve
  moves   = made, bought, crafted, worked, used, sold                   (Stores.move each)
income
  ... today's lines, then upkeep_workshops (working slots), inputs_bought (bought flow x price, rounded up)
people
  mult = 500 + 350 x surplus + 350 x prosperity (permille);  growth = people x rate x mult / 1e9
```

---

## 6. The window follows the data

The approved Town tab (mockup v4) needs no redesign: the models fill what it already reads, the strips draw one more tile
state and a coin badge. The gate mockup (EC0) shows the result before the shell work starts.

### 6.1 What each model gains

| Model | Today | After M9.5 |
|---|---|---|
| `TileView.strip` (own settlement) | People, Food, Works "1 of 3", Ducats | People, Food, **Slots "2 / 3"**, Ducats (each cell gains `tip`) |
| `TileView.land` | people, food, made, buildings (foreign), ground, war | + `raw` (R54), + `workers` (own), + slot buildings in `buildings` (foreign, R58) |
| `TileBuildings.of` groups | Settlement, Land, Harbour, Defence; `slots: {}` | + **Workshops** after Settlement with `slots {used, total}`; every group + `workforce` (R56) and `tip` |
| `TileBuildings` rows | states built, building, ready, short, locked, refused; `gate {}` | + state **idle**; `gate {year}` or `{level}`; workshop rows with `icon` = the industry key, `level` = the stage; + `tip` |
| `BuildingCard.of` | Each year it would; To build; verdict | + workshop sections: **Recipe** ("2 wool make 1 cloth"), **Yield** (tier, raw at hand), **Workers**, **Buying** (on or off, the price) |
| `TileArmy.raise.arms` | `{}` | `{in_stores, premium_text}` (R60) |
| `CompanyCard.of` | ducats and goods lines | + the arms line from `arms_quote` |
| `ImprovePreview` / `WorksPreview` | works options and card | + workshop options and R51's section; the Buy inputs switch (R61) |

### 6.2 What changes in the shell (small and named)

| File | Change |
|---|---|
| `shell/panels/tile_tabs/building_strips.gd` | `GROUP_ICONS` and `GROUP_MEANINGS` gain `workshops`; the plaque shows the name and the count line "N built of M" for every group (for Workshops M is the slots: "2 built of 3"); **no bar**; the plaque tooltip is `group.tip`; a click on a built workshop tile emits `workshop_card` |
| `shell/ui/building_row.gd` | `FAMILY_ICONS` gains the three industry keys; state `idle` (`PanelTileTileIdle`: the built look, dimmed, with the level); the tooltip is `data.tip` when present |
| `shell/ui/strip_cells.gd` | `ICONS` gains `slots`; the tooltip is the cell's `tip` when present |
| `shell/panels/tile_tabs/land_facts.gd` | the raw line and the workers line (R54) |
| `shell/screens/works_preview.gd` | the workshop section and the Buy inputs switch (R61) |
| `shell/app/works_flow.gd` | the `workshop_card` request opens `WorksPreview` on the built workshop |
| `shell/panels/tile_tabs/army_tab.gd`, `shell/screens/raise_screen.gd`, `shell/ui/company_row.gd` | the arms banner and line (already fields; shown when present) |
| `tools/build_theme.gd` and both themes | `PanelTileTileIdle` |
| `shell/map/` (a marks layer beside `CapitalMarks`) | R62's marks |
| `shell/autoload/session.gd`, `events.gd` | the two new events |

### 6.3 The words (R57)

| Where | Text |
|---|---|
| Workshops plaque | "Workshops" · "2 built of 3"; tooltip "Workshops\nBuildings that turn raw goods into dearer ones. 2 of 3 slots in use: a walled town has 3 (a village 1, a town 2, a city 4)." |
| Land plaque bar (deferred, D25: not shown) | "Workers: 1,800 of 2,000 jobs filled (90 %). The hands come from the people of this tile and the six round it that you hold." Kept as data for a later bar |
| Settlement plaque bar (deferred, D25: not shown) | "People: 6,200 of 10,000. A town grows to its room, then may become a larger place." |
| Defence plaque bar (deferred, D25: not shown) | "Garrison: 400 of 600 men." |
| Slots chip | value "2 / 3", label "Slots"; tooltip "Slots: 2 / 3\nWorkshop slots in use here, of the 3 a walled town has. A village has 1, a town 2, a walled town 3, a city 4." |
| Ready build tile | "Weaver\nCan build: 100 ducats, 5 timber, 4 seasons.\n2 wool make 1 cloth. Own wool at hand: +25 %." (or "No own wool within two hexes: input from your stores or bought.") |
| Short tile | "Weaver\ncost 100 · you have 64" (bad tone; the strip's red line) |
| Locked by year | "Weaver\nLocked: opens in 1490." (M11: "Locked: needs Guilds.") |
| Locked by slots | "Bakery\nLocked: every slot is taken. A city has 4 slots." / "Hamlets have no workshop slots: a village has 1." |
| Locked third stage | "Weaver, third stage\nLocked: the third stage opens in 1520." |
| Built, working | "Weaver (level II)\nWorking: 16 wool in (own 12, bought 4), 10 cloth out this season. Upkeep 3. Click for its card." |
| Built, idle | "Weaver (level II)\nIdle: the town is too small for 3 workshops. It works again when the town grows back." / "Idle: occupied by the Duchy of Milan." / "Idle: under siege." |
| Card, Buying | "Buy missing input: on" · "Bought wool costs 1.8 a load (1.2 x the base 1.5). Buying stops when the treasury would fall under 84 (a season's upkeep)." |
| Arms banner | "Arms in stores 6 · bought arms cost 13.5 each (+50 %)" |
| Raise refusal | "no arms: 1 needed, 0 in the stores, 14 ducats to buy it, 8 in the treasury" |
| Land facts | "Raw: wool, 12 loads this season" · "Workers here: 3,600 hands for 4,200 jobs (86 %)" |
| News | "The weaver's craft is open: weavers can be built in villages, towns and cities from 1490." |

---

## 7. Fog: what each new fact reads

| Fact | Read through | Undiscovered | Light fog | In sight |
|---|---|---|---|---|
| Slot kinds, stages, working or idle | `Slots.rows` after `Knowledge.discovered` | hidden | exact | exact |
| Raw line of a district | district output after the gate | hidden | exact | exact |
| Workers, output, tier, at hand, buying, stocks | own-only models | n/a | n/a | own only |
| Map marks | `WorkshopMarks` after the gate | none | shown | shown |
| AI: slots of a target | `AiKnow.slots_seen` (discovered hexes) | not counted | counted | counted |

`test_tile_fog.gd`'s twin test gains slots: two games that differ only in the slots of undiscovered hexes give equal
`TileView`s on every hex; `test_ai_fog.gd`'s door scan lists `slots_seen`.

---

## 8. Tests

All under `godot/tests/`. Every edited test keeps its planted faults; a task may not delete a P without replacing it.

### 8.1 New tests

| Test | Cases | Planted faults |
|---|---|---|
| `core/test_industry_defs.gd` | three industries, fields, keys, validate errors; the goods table of R1; the economy numbers' bounds | R1, R2, R7 |
| `core/test_slot_state.gd` | arrays sized, duplicate, to_dict / from_dict, the old schema empty, the overlay reads and never writes, digest changes with a flag | R9, R10, R14 |
| `core/test_slots.gd` | count by level, one of each, positions, put / set_flags / clear_hex the only writers, idle by level, occupation, siege, wake | R12, R15, R16, R21 |
| `core/test_industry_actions.gd` | every row of R17 and R18 in order on Genoa, Asti, a hamlet, a foreign town; gates at Winter 1489 / Spring 1490; finish, cancel, refund; blocked when the town fell; capture hands over; clearing drops; `set_buy_inputs` | R17 to R23 |
| `core/test_industry_rules.gd` | tier, at hand (own, foreign, stage 1, 2, 3, ties, occupied), workers in a neighbour's staffing, the working list order, `output` floors | R25 to R29 |
| `core/test_buying.gd` | price per good and permille 0; plan in batches and at a budget; take moves `bought` only; a stub market (M10's seam test) | R31 |
| `core/test_workshop_season.gd` | the step order; own then bought; the floor; the switch off; needs met and reserve unchanged after works (40 seeded seasons); food units and the bread share; cloth comfort; the move order never below 0; flows and lines; upkeep only for working slots | R30, R32 to R40 |
| `core/test_industry_numbers.gd` | each cell of the design's section 5, computed by the season on a fixture town, pinned as integers (and the doc table updated to them in EC21) | drift between doc and code |
| `core/test_growth.gd` | `mult` on 40 seeded cases; surplus clamp and need 0; comfort parts; `of_flows` equals `of_step` on the same season; hunger untouched | R42 to R44 |
| `core/test_military_arms.gd` | raise with own arms, with bought arms, the reserve used, neither (refusal, nothing changed), market off; the arms_bought line; the check/act pair with arms | R45 to R48 |
| `core/test_workshop_preview.gd` | card fields per state; gain equals EconomyPreview's year difference; options of a settlement | R51, R52 |
| `core/test_tile_workshops.gd` | the Workshops group rows and states on Genoa through 1480, 1485, 1490, 1520; slots chip; workforce data per group (no bar drawn); the growth facts; the words of 6.3 | R53 to R59 |
| `core/test_ai_industry.gd` | the prior on four fixture towns (own, bought, loss: 0); weights; siting priority; the buying step's switch; raising priced with arms; the war blocker line; prize term; traces | R64 to R68 |
| `core/test_industry_fog.gd` | slots in the twin test; foreign rows without output; marks gated | R24, R58, section 7 |
| `shell/test_town_workshops.gd` | the strip with its plaque (name and count, no bar) and tooltip; the coin badge on a buying workshop; idle tiles; a click on a built tile asks `workshop_card`; locked tiles' words | R55 to R57, R61 |
| `shell/test_workshop_card.gd` | the card's section; the switch acts through `Session.act`; Esc | R61 |

### 8.2 Tests that move or change

| Test | Change | Why | Task |
|---|---|---|---|
| `core/test_good_defs.gd`, `test_economy_defs.gd` | 19 goods, the made kind, `food_permille` | R1 | EC1 |
| `core/test_unit_defs.gd`, `test_family_defs.gd` | arms costs; `keep_wild` 0 | R4, R5 | EC6, EC8 |
| `core/test_save_file.gd`, `test_snapshot.gd`, `test_war_save.gd`, `test_country_state.gd` | the new FORMAT; slots and works in the round trip; the pinned digest re-pinned once with the reason | R13, R14 | EC2 |
| `core/test_state_view.gd` | the slot overlay | R10 | EC2 |
| `core/test_stores.gd`, `test_treasury.gd`, `test_no_other_writers.gd`, `test_owns.gd` | new flows, lines, owner | R12, R40 | EC3, EC5 |
| `core/test_works.gd`, `test_improve_actions.gd`, `test_check_contract.gd`, `random_player.gd` | the workshop work; "works crew" words; the three new pairs | R17, R18, R23, D7 | EC5 |
| `core/test_economy.gd`, `test_district_cache.gd`, `test_season_profile.gd` | settlement jobs with slots; the profile's key | R26 | EC5 |
| `core/test_economy_season.gd`, `test_money_property.gd`, `test_economy_genoa.gd`, `test_economy_1480.gd` | food units; the step's new keys; with the fixture off unchanged | R32 to R40, R70 | EC8 |
| `core/test_people*.gd`, `test_cards_people.gd` | `mult` 1000 under the fixture; `fed_of` in units | R42, R33 | EC7 |
| `core/test_military.gd`, `test_ai_forces.gd`, `test_army_share.gd`, `test_log_others.gd`, `test_movement_war.gd` | arms in the cost texts and the shortfall line when the fixture is on; off: unchanged | R46 to R48 | EC6 |
| `core/test_economy_preview.gd`, `test_improve_preview.gd`, `test_ai_preview_share.gd` | the 200 cases gain workshops; options of a settlement | R50, R51 | EC11 |
| `core/test_tile_buildings.gd`, `test_tile_view.gd`, `test_tile_army.gd`, `test_building_card.gd`, `test_company_card.gd`, `test_works_view.gd` | the new group, chip, fields, labels | R53 to R60 | EC9, EC13 |
| `core/test_ai_economy.gd`, `test_ai_turn.gd`, `test_ai_war.gd`, `test_ai_door.gd`, `test_ai_fog.gd`, `test_ai_determinism.gd` | the option, the `buying` step in the table, the blocker, the door's new reads; the fixture games' digests unchanged since EC2's one re-pin of the digest's shape | R64 to R69 | EC12 |
| `core/test_log_lines.gd`, `test_season_summary.gd`, `test_reminders.gd`, `test_study_economy.gd`, `test_stats.gd` | the new lines, columns, series | R41, R63 | EC10, EC15 |
| `shell/test_town_tab_strips.gd`, `test_building_row.gd`, `test_tile_window_tips.gd`, `test_army_tab.gd`, `test_raise_screen.gd`, `test_works_preview.gd`, `test_study.gd` | the strip, idle tile, tips, arms banner, workshop card | section 6 | EC13 to EC15 |
| `core/test_fog_exact.gd`, `test_tile_fog.gd`, `test_tile_door.gd` | scans list the new view files | R24, R58 | EC9, EC16 |
| `core/test_ai_soak_quick.gd`, `tests/core/invariants.gd` | the new invariants | section 9 | EC17 |

**Unchanged, must stay green:** every M3 to M9 rule test that goes through `EconomyFixture.defs` (the fixture off),
`test_season.gd` (no phase added), `test_replay*.gd`, `test_battles.gd`, `test_combat*.gd`, `test_supply.gd`,
`test_occupation*.gd`, `test_wars*.gd`, `test_sight.gd`, `test_fog_views*.gd`.

### 8.3 Goldens and pictures

The tile window's pictures (`tools/ui/shot_ui_tile.gd`: own city on the Town tab before and after 1490, an idle workshop, the
workshop card with its switch, the Army tab's arms banner, a foreign town's workshops in light fog), the Study's goods and
treasury pages, the report and the raise screen are made again once in EC21; **the owner is asked before any windowed run**;
the art director signs them against the EC0 mockup. Changed goldens are reviewed side by side.

### 8.4 Monkey

`tests/shell/monkey_tile.gd` gains a workshop step: on own settlements it hovers Workshops tiles, presses a ready hammer when
one allows, clicks a built workshop to open its card and flips Buy inputs, closes the card. Invariants each frame: the
Workshops strip shows exactly `TileBuildings` rows; the Slots chip equals `Slots.used / count_at`; no ready tile for a closed
industry; no plaque draws a bar; a coin badge shows exactly on buying workshops; each settlement shows each industry at most once. Counters `workshop_cards`,
`buy_switches`, `workshop_builds` above 0 on at least one of three seeds (one past 1490 by a prepared state).

---

## 9. The soak and how balance is measured

**Invariants every season** (`tests/core/invariants.gd`, both soak suites and the quick soak):

1. no negative stock (kept); `-worked = own + bought` per good and `own >= 0`;
2. per slot, `crafted <= Industry.output(capacity, tier, at hand)` of that season;
3. `bought` is 0 for a country whose switches are all off or whose market permille is 0, and the treasury after production
   is at least the floor whenever `bought > 0`;
4. every filled slot is on a settlement hex, its industry opened (the year is at least its `year`), its stage at most
   `stage_max`, no industry twice on a hex, positions without holes;
5. a slot is idle exactly when R21 says;
6. every `army_raised` event's goods include arms per its unit def (no raise without arms);
7. people grow only where the country is fed (kept), and `mult` is 500 to 1200.

**The `industry` suite** (`tools/soak.gd --suite=industry --seeds=1-10 --seasons=160`, nightly `soak-ranges` job): each seed
plays twice, A with the committed defs and B with every industry's year at 9999 (D31). Per country at year 40 (the last 4
seasons) the record keeps: crown income (`Treasury.left_over` of the four closed ledgers), workshops, input taken and bought
over the game, men under arms, people, seasons under 0, raises refused for arms. Ranges (judged over the full 10 seeds;
starting values the balance task EC20 measures and keeps):

| Measure | Range |
|---|---|
| income A / B, countries with a workshop at year 40 (median) | 1.2 to 1.6 |
| income A / B, every country (worst) | at least 0.6 and at most 1.67 |
| AI countries alive at year 40 owning a workshop | at least 50 % |
| country-games with a treasury under 0, A minus B | at most 5 percentage points |
| bought share of a country's workshop input over the game (worst) | at most 600 permille |
| men under arms, A over B (median) | at least 750 permille |
| raises refused for arms, a seat a season (median) | at most 0.5 |
| wars of 40 seasons or more in which neither side raised a company | 0 |
| all people at year 40, A over B (median) | 900 to 1150 permille |

The `ai` suite's ranges of M8 are re-measured once with the committed rules (growth slower, arms dearer); a range that moves
keeps its new value with the measurement in EC20's pull request. `tools/economy_report.gd` gains an industry block (per
country and slot: used, bought, crafted, worth, tier, at hand) so a tuner reads one game in detail. The levers are data only:
the industries' capacities and upkeep, the tiers (the design's brake: the city tier 1250 to 1150), the buy permilles, the
growth weights, the AI weights.

---

## 10. Performance

EC5 records the baseline of the rows below before any rule lands; EC18 adds the new rows and measures all on the rig
`PerfFixture.europe_industry` (the made-up Europe with 120 working slots planted: every town and city of 60 countries with a
weaver and an armourer at stage 2, half with a bakery); both tables in EC18's pull request.

| Row | Class | Limit | Expected | Note |
|---|---|---|---|---|
| `production_ms` | cpu | 80 (was 70) | +5 | the workshop step for 60 countries; the known_over of issue 409 stays |
| **new** `working_list_ms` | cpu | 5.0 | about 2 | `Industry.working_of` for every country, cache cleared |
| `income_ms`, `people_ms`, `works_phase_ms` | cpu | as today | unchanged within 5 % | one more line; `mult` per country; workshop works |
| `season_ms` | cpu | 380 | unchanged within 5 % | the war rig, with slots planted |
| **new** `workshop_card_ms` | cpu | 2.0 | about 1 | one `ImprovePreview.of` for a workshop option, the base warm |
| `options_ms` | cpu | 2.0 | about 1.5 | a city with every workshop option |
| `tile_buildings_ms`, `tile_buildings_gains_ms` | cpu | 2.0, 40 | +0.3, +6 | with the Workshops group (issue 458 stays) |
| `ai_season_ms` | cpu | 3000 | unchanged within 5 % | the workshop scan and the buying step |
| **new** `ai_workshop_scan_ms` | cpu | 5.0 | about 2 | one seat's workshop options and priors, mean |
| `save_ms` | cpu | 1000 | unchanged | three byte arrays more |
| **new** `town_tab_open_ms` (perf_ui) | gpu | 16 | under 10 | own city with four workshops, cold |

If `production_ms` passes its limit: `working_of` is cached in the season profile's table (keyed on the slot arrays' hash and
the owners) instead of per version. If `workshop_card_ms` passes: the card reuses the country's preview base per frame (the
M4 cache key), as the tile window's spec 8 does.

---

## 11. Where the design and the code disagree (and what this page decides)

1. **The save format.** The design says FORMAT 7; the fog build already took 7, and the M9, M10 and M11 specs claim 7, 8, 9
   (with `map-state/6`, `map-state/7`, `work/3`). This build takes master's plus one (R13); Appendix A moves the later specs.
2. **Refit and upgrade (N9).** The design and tech-tree v2 (`Military.refit_cost`, K7) assume the Python refit and upgrade;
   Godot has neither, only the free `refill`. Nothing to change now; M11 carries the rule (R49).
3. **The word "slot".** "Work slots" (country crews) already exist in code, the strip and refusals; D7 keeps the code and
   changes the words.
4. **Food order.** The design says towns eat "grain, fish, then bread"; the code eats fish (order 0) before grain (1). The
   code's order stays.
5. **Bread's comfort and the eating order.** Eating bread last (the design's recommendation) makes "bread's share of the food
   eaten" almost always 0, so bread could never raise prosperity. The owner decided (2026-11-25) that towns eat the most
   efficient food first, bread leading (D9, R33), which also gives bread comfort.
6. **Cloth's comfort.** "Cloth met for towns" needs a cloth need, and cloth's reserve of 0 sells it the season it is made;
   D10 adds a comfort need met after the works step (open question 5).
7. **The product's flow.** The design books the product as `made`; D12 uses `crafted` so `made` stays the land's.
8. **The Industries tab.** The design asks for an Industries tab; the tile window decided no such tab (its D6), and the built
   v4 has a Town tab with strips: workshops are a Workshops strip (D24).
9. **Workforce bars.** The tile window spec (D14, Appendix C) left out workforce bars; the owner's v4 had a bar on every
   plaque and M9.5 first supplied its data (D25). The owner then decided (2026-11-25) on no bar yet: plaques show the name and
   count only; the data stays.
10. **The worked numbers.** The design's section 5 uses fractions (37.5 cloth); the game floors a season and a slot (about
    36). `test_industry_numbers.gd` pins the integers and EC21 updates the table.
11. **The AI's company price.** The design says the AI prices a company's goods at base; `AiForces` compares only the ducats
    with its reserve. D30 adds the arms cost.
12. **`Buying.take(country, good, loads)`** in the design becomes `(game, tag, good, loads)` (the core's style).
13. **Castles' `keep_wild`.** The design names settlements and ports as keeping their wild yield; castles keep it too (R5).
14. **Slot techs.** Tech-tree v2 adds slots through K4 (Work house, Manufactories); the review recommends none in the first
    version. Out of this build; `Slots.count_at` takes the tag for M11 (D29).

---

## 12. Risks

- **Snowball.** Own raw plus a city gives 1.5625 against a village's 0.8 on bought input. The soak's twin ranges; the city tier
  is data (1250 to 1150).
- **The seam.** `Buying` may not fit M10's scarce, per-market prices: kept to `price`, `plan`, `take`, stub-tested.
- **The unlimited-supply loophole until M10.** The bought-share range and the floor; gone when M10's prices bite.
- **Food in two units.** The words say it ("bread feeds half again as much as grain"); the town card shows food in loads and
  units only where they differ.
- **Arms slow wars and drain treasuries.** The soak's men and refusal ranges; levers in data; the AI's blocker and its
  priced raise.
- **Slower growth (500 when only just fed).** Intended; the owner's early-game playtest; growth weights are data.
- **Shared hands.** A workshop's jobs lower its neighbours' staffing; the card shows it (the year gain includes it).
- **Pins.** Goods 16 to 19 and the new rules touch many tests; the fixture default keeps M3 to M9's; the plan's grep list.
- **Build size.** About 1.3 of M4: two big rule tasks (EC5, EC8) and the previews (EC11). No era II industry in M9.5.
- **M9 lands in the same files** (`EconomySeason`, `People`, `Works`, `Treasury`, `Stats`, the AI, `SaveFile`). M9.5 starts
  on master after M9 merges; if the order changes, R13's rule and Appendix A still hold.

---

## Appendix A. Amendments to other specs (made by EC21)

| Spec | Amendment |
|---|---|
| `m9-build-spec.md` D60 | FORMAT 8 (not 7; the fog build took 7), `map-state/6`, `country/5`, `war/2` unchanged in meaning |
| `m10-build-spec.md` | FORMAT one above M9.5's; `map-state` and `work` one above M9.5's; `Buying.price` and `take` read the market (stock, price, scarcity); cloth, arms, bread get appetite rows; `worked`, `bought`, `crafted` in its flow table; an arms embargo or blockade stops arms buying |
| `m11-build-spec.md` | FORMAT one above M10's; tech rows K1 (`Works.industry_open`), K2 (`Works.stage_max`), K3 (`Industry.output`), K4 (`Slots.count_at`), K5 and K6 (`Buying.price`); the year table (`IndustryDef.year`, `stage3_year`) removed; refit and upgrade take arms through `Military.arms_quote` |
| `tilewin-build-spec.md` D14, D16, Appendix C | The Slots chip is built (D26); workforce bars are deferred, their data only (D25) |
| `docs/design/economy-rethink.md` | status built; FORMAT; D9, D10, D12; section 5's integers |
