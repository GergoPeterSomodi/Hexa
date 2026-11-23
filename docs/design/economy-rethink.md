# Economy rethink: raw materials, industries, settlements, people (design draft)

Status: DRAFT for the owner (2026-11-23, issue #439). Planning only. Nothing here is approved or built. The numbers are
starting points for the soak to tune, not promises. Sources: the owner's words in `docs/roadmap/owner-asks-2026-11-23.md`,
the M4 to M6 build specs (goods, works, stores, people), the M10 (trade) and M11 (research) specs, `docs/design/tech-tree.md`,
`docs/design/reactive-prices.md`, and the frozen Python game for the old manufactories.

## 1. Goal

A country can get rich from the land alone: sell wool, iron, grain. But a country that turns its raw material into something
better, in the right place, earns clearly more. A weaver beside a sheep district in a town beats the same wool sold raw, and
a city does it better than a village. People are part of the same loop: a country with a food surplus and comfortable towns
grows faster, and bigger towns are better places for industry. The player's choice each season becomes: expand the land,
build an industry, or grow the towns.

What the player does: reads the land (what each tile makes), places workshops next to the right raw tile and the right
town, watches stocks turn into dearer goods, and grows the towns that host them. Why it is fun: a visible chain (sheep, wool,
cloth, ducats) that the map shows, a siting puzzle (raw at hand, town tier), and a real reason to care about people.

## 2. What exists today (read from the Godot build and its specs)

**Goods (M4, `data/defs/goods/`).** 16 goods in four kinds: food (grain, fish), staple (oil, wine, salt), ware (hemp, silk,
dyes, wool, cattle, horses, copper, silver) and material (timber, stone, iron). Each has one fixed base price (1.0 to 7.0
ducats a load). No good is ever made from another good. Goods leave the stores in four ways only: towns' needs (food, wine,
salt, oil), works' costs (timber, stone, iron), raising companies (iron, timber, horses, copper), and sale of the stock above
the reserve at the fixed price. The crown's income from goods is `tax_goods`: 50 / 70 / 90 % (Low / Normal / High) of the
value sold. Stores are one pool per country (not per town). M10 turns the fixed price into market prices and adds routes.

**Tiles (M3, M4).** A hex holds one piece: wild land, a settlement (level 1 to 5), a castle, or a goods district (a family
at stage 1 to 3: wheat, hemp, silk, dyes, vineyard, olives, grazing, timber, quarry, salt, mines, harbour). So the
land is already close to "one raw per tile": a district makes one good (grazing picks sheep, cattle or horses; mines pick
iron, copper or silver, chosen when it is built). Three things break "one raw per tile" today:
- Wild yield: every land hex also makes its cover's grain or timber. A goods district keeps part of it (`keep_wild`: 50 / 25 /
  0 % at stages 1 / 2 / 3 for most families; settlements keep 100 to 50 %). At stage 2 this is usually under one load a season
  and floors to 0 in M4's own worked table.
- Port fish: a coastal settlement also makes fish.
- A wild hex makes its cover's good, which is its one raw (this part is already right).

Output of a district: `base[stage] x staffing x ring lift x season x tax x weather` (M4 4.4). Hands (people nearby) staff the
jobs of nearby districts. **Ring lift** already exists: a walled town gives neighbouring goods districts +10 %, a city +20 %.

**Settlements and people (M5).** Levels: 1 hamlet 1,000 people, 2 village 3,000, 3 town 10,000, 4 walled town 30,000, 5 city
60,000, each with a room (cap). People grow a flat rate per season (by tax level and season) as long as the country is
fully fed; they starve if not; a full village or town raises itself a level, up to town; walls and cities are the crown's
works. Growth ignores how much surplus the country has and how comfortable the people are. Taxes: towns pay by contentment
(food 70 %, wine, salt, oil 10 % each), the countryside pays a flat rate.

**Research and trade not built yet.** M10: markets, routes, reactive prices (0.3x to 3.5x base), appetite per good. M11: 50
techs and ideas as a table of modifiers that every system reads through the owner's effective definitions. `tech-tree.md`
already names industry techs (Guilds, Ropewalk, Glass and leather, Corned powder) from the old Python game, where seven
"manufactories" turned wool to cloth, iron to tools and weapons, hemp to rope, and so on, inside provinces.

## 3. What the owner's idea changes, and what stays

| Owner's idea | Today | Change |
|---|---|---|
| One raw material per tile | Nearly true; wild yield and port fish stack on top | Make it a rule: a tile's raw is shown and counted once; drop the small `keep_wild` second yield on goods districts (Q5) |
| Industry turns raw into something more valuable | No processing exists | New: workshop districts with recipes raw -> product, product dearer than its inputs |
| Raw alone can make a country rich | Yes, that is all there is | Stays: raw income is untouched. Industry adds on top |
| Output depends on village / town / city | Only ring lift (+10 / +20 %) for raw districts | Settlement tier sets how well a workshop runs (section 4.4) |
| Raw at hand gives efficiency | Nothing | A workshop with a district making its input within two hexes runs +25 % |
| Population from food surplus and prosperity | Flat growth while fed | Growth speed scales with the food surplus and the towns' comfort (section 4.6) |

Stays: districts, stages, works, jobs and hands, stores as one pool, fixed-price sale of the surplus (until M10), taxes, the
reserve rule (needs and reserves come before anything is sold or processed), integer arithmetic, one season order.

## 4. The model in plain words

### 4.1 Raw material per tile

Every land tile has exactly one raw material it makes: its district's good, or, if wild, its cover's good (grain on
farmland and grassland, timber on woods). A settlement's raw is its cover's wild good at its keep percent. The tile window
(#436) says it in one line: "Raw: wool, 12 loads this season". Raw goods are sold as today, at the base price now and the
market price from M10.

### 4.2 Industries are workshops: recipes from raw to product

A **workshop** is a new kind of goods district (a family, like vineyard or quarry). It stands on its own hex within two hexes
of a settlement of level 2 or more. It has a **recipe**: inputs in, product out, per season, at stages 1, 2, 3 (capacity grows
with the stage, as for every district). It takes its input from the country's stores, only from the stock above the
reserve (so food and needs come first; no workshop starves a town), up to its capacity, then sells or keeps the product.

Value multiplier m = (product price x loads out) / (input price x loads in). Starting recipes (all in `data/defs/`):

| Workshop | Recipe (in -> out) | Product price | Input value | Multiplier m | Capacity in, stages 1 / 2 / 3 (loads a season) |
|---|---|---|---|---|---|
| Weaver | 2 wool -> 1 cloth | 6.0 | 3.0 | 2.0 | 8 / 16 / 28 |
| Armourer | 2 iron -> 1 arms | 9.0 | 4.0 | 2.25 | 4 / 8 / 14 |
| Bakery | 3 grain -> 2 bread | 2.4 | 3.0 | 1.6 | 12 / 24 / 40 |

Rarer or dearer raw gets a higher multiplier; bulk food gets the lowest, so raw stays attractive for grain. Luxury raws
(silk, silver, dyes) have no industry in the first version: they are already rich as raw (silk stage 2 is about 54 ducats a
year from one tile).

New goods are `made` kind (a fifth kind): cloth, arms, bread, ids appended after silver (16, 17, 18). Cloth and arms have
reserve 0 (sold as made, until M10 lets them wait for a good price); arms are also kept as a war stock (4.8).

### 4.3 The season step

Inside `production`, after the goods are made and the towns have taken their needs, a new step runs between needs and sales:

```
made    districts make their raw (as M4)
needs   towns take food, wine, salt, oil; the rest is the surplus above the reserve
works   each workshop, in hex index order: takes min(capacity x staffing, surplus of its input) of the raw
        makes   taken x out / in x tier x (1000 + at_hand) / 1000        (integers, floored)
sales   the surplus of raw and the new goods is sold (M4 4.8, or M10's trade phase)
```

Workshops have no weather and no winter slot in the first version (flat 100 % all year); the people who work them are staffed
by hands like any district. One new flow in Stores, `worked` (raw taken in); the product is an ordinary `made` flow. The
property "closing minus opening equals the sum of the flows" still holds.

### 4.4 Settlement tier: village, town, city

The tier is the best settlement within two hexes of the workshop (same reach as silk and dyes rules today, and the same
neighbour scan that ring lift already uses). Tier multiplies the yield:

| Nearest settlement | hamlet | village | town | walled town | city |
|---|---|---|---|---|---|
| Can host a workshop | no | yes | yes | yes | yes |
| Yield (permille) | - | 800 | 1000 | 1100 | 1250 |

The tier also fits the existing ring lift for raw districts (unchanged: +10 % walled town, +20 % city). A town that falls a
level (hunger) lowers its workshops at once, so people and industry are tied together.

### 4.5 Raw at hand

If a district whose good is the recipe's main input stands within two hexes of the workshop (the same reach), the workshop runs
**+25 %** (`near_input_permille` 250). Any owner counts, as ring lift does. This is a siting reward only: the input itself
still comes from the stores, so a country without the raw nearby can still run the workshop, less well. It makes the puzzle:
a weaver in a town with sheep meadow beside it (+25 %) against a weaver in a bigger town far away (higher tier, no bonus).

Total yield = tier x (1 + at hand): from 0.8 (village, none) to 1.5625 (city, at hand).

### 4.6 People: surplus and prosperity

Growth in M5 (`People.change_at`) stays the one rule for one hex, with one new factor. Hunger, crowding and the room rules do not
change. Growth now needs the country fed (as today) and is scaled:

```
mult   = 500 + surplus x 350 / 1000 + prosperity x 350 / 1000          # permille; 500 fed only, 1200 at best
growth = floor(people x growth_bp[tax] x growth_percent[slot] x mult / 1e9)
```

- **Surplus** (0 to 1000): how far the country's food made over the season exceeds the food its towns eat, scaled so a surplus
  of 25 % of the need or more counts 1000 (data constants).
- **Prosperity** (0 to 1000): the mean of M4's contentment (wine, salt, oil, food) and a new **comfort** (cloth and bread
  met for the towns, appetite per 1,000 town people, like the other needs). Comfort changes growth only, not taxes: M4's
  tax pins do not move.

Pace check, a village growing to a town (34 seasons today in frost at Normal): at mult 500 it takes 68, at 750 it takes 45,
at 1000 as today 34, at 1200 it takes 28. A country that only just feeds its people grows slowly; a rich fed one grows faster
than today. Settlements still raise themselves to town only; walls and cities stay the crown's works.

### 4.7 How it feeds treasury, trade, people, army

- **Treasury:** processed goods are sold like any good, so `tax_goods` (50 / 70 / 90 %) taxes their value. No new line is
  needed; the report's Goods section shows the new goods and "worked" flows. Workshops pay upkeep (stage 2: 3 a season, like a
  mine) so a badly sited one can lose money.
- **Trade (M10):** cloth, arms and bread get an appetite and a market price like the others; a glut of cloth now lowers its
  price. That is the natural brake on industrial snowball, and it works only from M10.
- **People:** comfort goods (cloth, bread) raise prosperity, so industry feeds growth; bigger towns host better workshops.
- **Army (M6):** arms stand in for iron when raising a company (1 arms = 2 iron in the cost goods, Q12), so an armourer
  cheapens war. No quality effect in the first version.

## 5. Worked numbers: raw only against industry

All per year (4 seasons), stage 2 districts, calm weather, Normal taxes, fixed prices. Raw output from M4's frost-year column
(sheep 48 loads, iron 29, wheat 32). The workshop takes all of that tile's output (capacity is not the limit). "Worth" is the
value of what is sold; the crown takes 70 % of it. Gain is worth minus the raw worth.

**Chain 1: wool -> cloth** (raw: 48 wool x 1.5 = **72**)

| Site | Yield | Cloth | Worth | Gain over raw |
|---|---|---|---|---|
| Village, no wool at hand (0.8) | 19.2 | 19.2 x 6 | 115 | +43 (+60 %) |
| Town, no wool at hand (1.0) | 24 | 24 x 6 | 144 | +72 (+100 %) |
| Town, wool at hand (1.25) | 30 | 30 x 6 | 180 | +108 (+150 %) |
| City, wool at hand (1.5625) | 37.5 | 37.5 x 6 | 225 | +153 (+212 %) |

**Chain 2: iron -> arms** (raw: 29 iron x 2.0 = **58**)

| Site | Arms | Worth | Gain |
|---|---|---|---|
| Village, none at hand | 11.6 | 104 | +46 (+80 %) |
| Town, none at hand | 14.5 | 131 | +73 (+125 %) |
| Town, iron at hand | 18.1 | 163 | +105 (+181 %) |
| City, iron at hand | 22.7 | 204 | +146 (+252 %) |

**Chain 3: grain -> bread** (raw: 32 grain x 1.0 = **32**; only surplus above the reserve is baked)

| Site | Bread | Worth | Gain |
|---|---|---|---|
| Village, none at hand | 17.1 | 41 | +9 (+28 %) |
| Town, none at hand | 21.3 | 51 | +19 (+60 %) |
| Town, wheat at hand | 26.7 | 64 | +32 (+100 %) |
| City, wheat at hand | 33.3 | 80 | +48 (+150 %) |

**Chain 4 (raw is enough): silk.** 9 loads x 6.0 = **54** a year from one tile, no industry in the first version. A silk tile
earns more than a plain bread chain in a town. Raw luxury stays a real strategy.

**Is it worth the hex?** A second raw wool tile adds 72 worth. A weaver beside the first tile adds 43 (village, no wool at
hand), 72 (town), 108 (town, wool at hand) or 153 (city, at hand). So a bad site (village, far from the raw) loses to simply
planting more raw land; a good site clearly wins. Treasury effect of the good town weaver: +108 x 0.7 = 75.6, less upkeep
12 = about **+64 a year**, for a cost of about 200 ducats and 10 timber: a payback of about 3 years, against about 2.5 for a
new raw tile (100 + 10 timber, +42 a year after upkeep). Industry pays back at about the same pace as raw but adds to what the
raw tile already makes, and raw land is limited by terrain.

**A whole country.** A country with one stage-2 sheep district, one iron mine and one wheat district, each with a workshop in
a town with the raw at hand: raw-only worth 72 + 58 + 32 = 162 (crown 113); with the three workshops 180 + 163 + 64 = 407
(crown 285, less 36 upkeep = 249). That is about +136 a year, 2.2 times the raw crown take, or about +30 % on Genoa's
whole 1480 income of 458 a year (M4 4.15). It must not be more: the soak target is an industrial country earning 1.2 to
1.6 times a raw-only twin at year 40, and the raw-only twin never below 60 % of it.

## 6. Player and AI

**Player:** builds a workshop through the same works card as every district (cost, stages 4 / 8 / 16 seasons, ground rules).
The card shows the recipe, tier, "at hand" bonus, this season's use and output and the change in income, from the same code
the season runs (`ImprovePreview`), so what the card says is what happens.

**AI (M8 `AiEconomy`):** workshops are one more option in `works_scan` (hexes within two of a settlement of level 2 or more).
The prior is the card's payback; it is zero when the input has no surplus, so the AI never builds a weaver without wool. Each
temper gets one data weight (`industry_priority`: merchants high, warlike armourer-leaning, builders middle, as the walls
priority is done today). The AI also upgrades a settlement partly for the workshops it hosts. Traces log "industry: weaver at
(x, y), wool at hand, payback n seasons". No AI micro-management: it builds and upgrades, the season runs the rest.

## 7. UI

Points to `docs/design/ui/` (the Studiolo style) and the tile window of issue #436.

- **Tile window (#436):** header with name and owner; a Details block with **Raw** (good, loads this season), **People**,
  and for a workshop the **Chain** line "2 wool -> 1 cloth: town x1.0, wool at hand x1.25, uses 12, makes 15, worth 90".
  A Build tab lists raw districts and workshops with their cards; the tab for an army and the tab for ships are #436's.
  A foreign tile shows its piece, stage and owner, and nothing about its output (section 9). A sea or unseen tile shows
  what it shows today.
- **Works card:** one new section "Industry" with the recipe, the tier table (village / town / city), whether raw is at
  hand, the capacity, and the change in income per year.
- **Goods screen (Statesman's Study, Economy page):** the goods list shows the new made goods; a "worked" column and each
  workshop's line. The Treasury section does not change.
- **Map:** the workshop is drawn as its own piece (a Kenney-style flat building with its smoke or loom mark); the "at hand"
  relation shows as a thin link to the raw tile while the card is open, like M4's map marks.
- **People:** the town card adds the surplus and prosperity bars and the growth speed in words ("slow", "steady", "fast").
- **Report:** the Goods section lists "worked" and "made" per good; a new Industry note per country in the glance ("Industry
  added +64 this year").

## 8. Interactions

| System | Effect |
|---|---|
| Economy (M4) | One new step in `production`; `EconomySeason`, `EconomyPreview` and `DistrictCache` learn the workshop. The cache keeps tier and "at hand" (season-free); the input is run in the country step |
| People (M5) | `change_at` takes `mult`; two new numbers per country derived each season, not stored |
| War (M6, M7) | Armies raised with arms; occupying a town hands its workshops to the new owner; a lost town lowers tier at once; pillaging stays out |
| Diplomacy (M9) | Nothing new. War weariness reads `tax_goods`, which now includes made goods |
| Trade (M10) | New goods in markets, appetite and price tuning (X31 includes them); free traders carry cloth and arms; a toll on them |
| Research (M11) | Modifier keys: `industry_unlock` (which families), `industry_yield_permille`, `industry_stage_max`. Guilds opens stage 3; Ropewalk, Glass and leather, Corned powder add workshops in era II |
| Debt (M12) | Workshops are upkeep, so a deficit shows sooner; no other change |

## 9. Saves, balance, fog

**Saves (FORMAT).** `save_file.gd` is at FORMAT 6 with OLDEST_FORMAT 6 and no upgrade step yet. What changes: goods ids
appended (stock and stats arrays are already padded with zeros when shorter); `MapState.main_use` ids appended for the three
workshop families; Stores `FLOWS` appends `worked`; `Stats.SERIES` appends the industry rows; the digest text gains the new
flows. No new stored field for the efficiency: tier and "at hand" are derived. But a saved game plays differently afterwards
(growth rule, dropped keep_wild), so replays and digests of old saves would differ. Recommendation: bump FORMAT to 7 and
refuse older saves with a clear message, since public save compatibility only starts at M12 (Q10). `ScenarioDef` and the
scenario bake: workshop families added to the family list; a few start workshops (Q11).

**Balance.** The crown takes 70 % of sales, so a new good adds to treasuries quickly. The brakes, in order: input must exist as
surplus, capacity by stage, upkeep, the hex it takes, tier and "at hand" siting, and from M10 the falling price of a glut.
`IndustryFixture.off(defs)` (tests only, same pattern as `TradeFixture.still` and `ResearchFixture.off`): no workshop usable and
`mult` fixed at 1000, so every pin of M3 to M9 holds. Genoa's table (M4 4.15) is untouched: all workshops off, and the dropped
`keep_wild` floors to 0 in it already.

**Fog and knowledge.** You see a foreign piece if you see or know its hex (it is drawn); you do not see its output, tier
bonus, stock or comfort. Market prices of cloth and arms follow M10's knowledge rule (only markets you know). Standing and
rankings stay banded; no new exact value of another country leaks. The viewer `&""` (tests) sees all, as before. A lost tile
is not fogged for the old owner by this system (that is #435, one rule shared).

## 10. Tests and the soak

- Pure unit tests: the recipe step (integer floors, capacity, surplus), tier table, "at hand" scan, growth `mult`, 40 cases
  seeded; text test that no writer of stock exists outside `stores.gd`; the money and goods properties (M4 done-when 2) extended
  to `worked`.
- Preview equals season for workshops: 200 seeded cases (M4 done-when 4) now include workshop builds and upgrades.
- Worked-numbers test: each cell of the tables in section 5 pinned on a fixture, so the doc and the code cannot drift.
- Soak (`tools/soak.gd`, suites ai, passive, europe): invariants every season: no negative stock; made never above capacity x
  tier x at-hand; `worked` equals the raw taken; people grow only when fed. Ranges: an industrial twin earns 1.2 to 1.6 times
  the raw-only twin at year 40; at least half of the AI countries own a workshop by year 40; no AI ruin from workshops alone.
- `tools/economy_report.gd` gains an industry block (per country, per workshop: used, made, worth, tier, at hand).
- Goldens (UI screenshots) change for the goods screen, works card and tile window: planned with #436, refreshed once.

## 11. Where it fits, and what to cut or reorder

Order today: M7 war (in build), M8 AI (specced, `ai_economy.gd` exists), M9 diplomacy, M10 trade, M11 research, M12 whole game.

Recommended: **M9.5 "Industry", after M9 and before M10**, with the tile window (#436) built just before it so the window is
the home of the chain line. Reasons: M10 tunes appetites and prices good by good (task X31); doing industries first means one
tuning, not two. M11 can then give industries their techs as modifier rows without a rewrite. M9 (diplomacy) hardly touches
the economy, so nothing blocks the order. Fits roughly one M4-sized slice: defs and recipes, the workshop family and its works
rules, the production step and preview, growth rule, AI option, cards and tile window rows, report and stats, tests and
soak, docs. M10's spec needs a small edit (three more goods, appetite rows, `worked` in its flow table); M11's table adds
three modifier keys.

Cut for the first version: building slots inside settlements, luxury industries, mint, workshops that buy input from the market,
winter and weather for workshops, quality of goods, prosperity room, specialisation by country. Reorder: nothing from M10 to M12
leaves; the era II workshops (rope, glass, leather, powder) wait for M11's techs.

## 12. Risks

- **Snowball.** Rich countries build more workshops. Brakes in 9; the soak range and M10's falling prices. If still strong,
  lower tier 1250 to 1150 (data only).
- **Feels like a spreadsheet.** The chain line and the "at hand" link on the map must be clear. Playtest with the card first.
- **Starving by industry.** Prevented by the reserve rule (workshops take only surplus), pinned by a test.
- **Input arbitrage (M10).** If workshops could buy raw abroad cheaply, import-process-sell loops appear. Not allowed in v1.
- **Growth slower than today for unfed-surplus countries** (500 vs 1000 permille). Intended, but a playtest must confirm it
  does not stall early game; the pace table in 4.6 is the lever.
- **Two numbers for "raw" (wild yield).** Dropping `keep_wild` on goods districts changes a few small pins; the grep of
  tests is the first task.
- **Tier drop on a hungry town** can collapse a chain; the card should warn ("this town is under 3,000 people").
- **Build size.** About one M4-sized slice; do not add era II workshops to it.

## 13. Smallest first version

Three workshops (weaver, armourer, bakery), on their own hexes within two of a village or bigger; tier table; "at hand" +25 %;
the production step and preview; the growth multiplier with surplus and prosperity (comfort from cloth and bread); one AI
option with a temper weight; the works card section and the tile window rows; the three goods; tests, soak ranges, the
economy report. No trade effects yet beyond fixed prices; M10 adds prices.

## 14. Questions for the owner

1. **Where does an industry stand?** (A) on its own hex near a town, a goods district like the others; (B) a building slot
   inside the settlement hex, with slots by level (hamlet 0, village 1, town 2, walled 3, city 4). Recommend A for the first
   version: it reuses works, pieces, previews and the AI unchanged and keeps one piece a hex; B needs a new per-hex state
   and a save change, and can come later on top of A.
2. **Which industries first?** Recommend three: weaver (wool), armourer (iron), bakery (grain). Rope, tannery, glassworks,
   powder mill come with M11's era II techs.
3. **Tier numbers and who can host.** Recommend village 0.8, town 1.0, walled 1.1, city 1.25, hamlets cannot host.
   Alternative: allow hamlets at 0.6.
4. **"Raw at hand".** Recommend +25 % when a raw district is within two hexes, any owner. Alternative: only your own district,
   or a graded bonus by how much raw it makes.
5. **One raw per tile and the wild yield.** Recommend dropping the small `keep_wild` second yield on goods districts only;
   settlements and ports keep theirs. Alternative: keep everything and only show one raw in the tile window.
6. **Where do inputs come from?** Recommend only the surplus above the reserve in the country's stores. Alternative (from
   M10): workshops may buy raw at the home market; richer, but creates arbitrage.
7. **Is bread food?** Recommend no: a comfort good that helps growth and sells, so the food rules stay as they are.
   Alternative: bread feeds 1.5 loads of grain (baking then costs no food).
8. **Growth rule.** Recommend `500 + 350 x surplus + 350 x prosperity` (ceiling 1200 of today's pace). Alternative: ceiling
   1000, so no country ever grows faster than now.
9. **Milestone placement.** Recommend M9.5 after M9, before M10, with the #436 tile window first. Alternatives: fold it into
   M10 (one tuning, bigger milestone) or after M12 (safest, but the economy stays flat for the first public release).
10. **Saves.** Recommend bump FORMAT to 7 and refuse older saves with a clear message. Alternative: keep loading old saves
    (they would play by the new rules from the load).
11. **Historic start workshops (1480).** Recommend a few in the Italy scenario as data (Florence weavers, Milan armourers),
    so the AI and the player see industry from turn 1. Alternative: none, everyone builds.
12. **Arms and the army.** Recommend arms replace iron in a company's cost (1 arms = 2 iron), no quality effect yet.
    Alternative: arms in the store give new companies +1 attack, which needs an M7 balance pass.
