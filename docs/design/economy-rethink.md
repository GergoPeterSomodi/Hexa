# Economy rethink: raw materials, industries, settlements, people (revision 3)

Status: **ready for the build plan** (2026-11-23, issue #439). Planning only. Nothing here is built. This revision folds in
the owner's answers of 2026-11-23: the first twelve questions (all closed) and the new questions N1 to N5. One detail, N6,
carries a recommended default that the owner has not yet confirmed (marked "default, owner to confirm"). The numbers are
starting points for the soak to tune. Sources: `docs/roadmap/owner-asks-2026-11-23.md`, the M4 to M6 build specs, the M10
(trade) and M11 (research) specs, `docs/design/tech-tree.md`, `docs/design/reactive-prices.md`, and the frozen Python game.

## Changed from the first draft (history)

The owner's answers overrode these recommendations of draft 1:

| Topic | Draft 1 recommended | Owner decided (now the rule) |
|---|---|---|
| Where an industry stands | Its own hex near a town | A **slot in the settlement** (a building inside a village, town or city) |
| Raw at hand | Any owner's raw district counts | Only the country's **own** raw districts count |
| Inputs | Only the surplus in the country's stores | Also **bought from the market** |
| Bread | Comfort good, not food | Bread is **food** |
| Start workshops | A few in the Italy scenario | **None** at 1480; industries open by **year** before M11, then by technology |
| How industries unlock before M11 (N1) | A charter purchase | **A set year per industry** (armourer 1485, weaver 1490, bakery 1495 as a placeholder); no charter |
| Arms (Q12) | 1 arms = 2 iron in a company's cost, no other effect | **Arms are required to raise a company**; a country without arms buys them at a premium |
| Unchanged from draft 1 (confirmed) | | Weaver, armourer, bakery first; tier 0.8 / 1.0 / 1.1 / 1.25, no hamlets; one raw per tile (drop `keep_wild` on goods districts); growth `500 + 350 x surplus + 350 x prosperity`, ceiling 1200; M9.5 between M9 and M10 with the tile window (#436) first; FORMAT 7, older saves refused |

Draft 1's "cut for the first version" list is partly reversed: building slots inside settlements and workshops that buy input
from the market are now IN. Still out: luxury industries, mint, winter and weather for workshops, quality of goods.

## 1. Goal

A country can get rich from the land alone: sell wool, iron, grain. A country that turns its raw material into something
better, inside the right town, earns clearly more. People are part of the same loop: a country with a food surplus and
comfortable towns grows faster, bigger towns have more room for industries, and bread feeds people directly. The player's
choice each season: expand the land, learn and build an industry, or grow the towns.

What the player does: reads the land (what each tile makes), learns an industry, puts it in a settlement slot beside the
right raw tile, watches stocks turn into dearer goods, and grows the towns that host them. Why it is fun: a visible chain
(sheep, wool, cloth, ducats), a siting puzzle (own raw at hand, town size), a real reason to care about people, and a first
taste of "technology changes my economy".

## 2. What exists today

**Goods (M4).** 16 goods in four kinds: food (grain, fish), staple (oil, wine, salt), ware (hemp, silk, dyes, wool, cattle,
horses, copper, silver), material (timber, stone, iron), each with one fixed base price. No good is made from another. Goods
leave the stores through town needs, works' costs, raising companies, and the sale of stock above the reserve at the fixed
price. Crown income from goods is `tax_goods` 50 / 70 / 90 % of value sold. Stores are one pool per country.

**Tiles (M3, M4).** A hex holds one piece: wild land, a settlement (level 1 to 5), a castle or a goods district (stage 1 to
3). A district makes one good; output = `base[stage] x staffing x ring lift x season x tax x weather`. A walled town gives
neighbouring goods districts +10 %, a city +20 % (ring lift, any owner, unchanged). Works are one job at a time per hex.

**Settlements and people (M5).** Levels: 1 hamlet 1,000 people, 2 village 3,000, 3 town 10,000, 4 walled town 30,000, 5 city
60,000. People grow a flat rate while the country is fed and starve if not; a full village or town raises itself a level, up
to town; walls and cities are the crown's works.

**Not built yet.** M10 (markets, routes, reactive prices 0.3x to 3.5x base) and M11 (50 techs and ideas as modifier rows).
`tech-tree.md` already names the industry techs (Guilds, Ropewalk, Glass and leather, Corned powder).

## 3. What the answers change (the honest reconciliation)

### 3.1 Slots inside settlements (Q1)

An industry is no longer a hex piece. A settlement hex now holds its settlement plus a short list of **slots**.

- **Slots by level:** hamlet 0, village 1, town 2, walled town 3, city 4 (`slots_by_level`, data). One of each industry per
  settlement (no two weavers in one town), so the extra slots of a city leave room for later industries (rope, glass).
- **Tier is the settlement's own level.** No more "best settlement within two hexes" scan: the workshop sits in the town, so
  the town's level is its tier. Simpler than draft 1.
- **Building into a slot** is a works job on the settlement hex with the same cards, costs and stages (4 / 8 / 16 seasons) as
  every district. One job per hex still holds, so **a slot build and a level upgrade of the same settlement cannot run at
  once** (new question N5). Costs (data): stage 1 100 ducats + 5 timber, stage 2 +100 + 5, stage 3 +180 + 10.
- **A level drop** (hunger) makes the slots above the new count **idle** (they keep their stage, produce nothing, and wake
  when the level returns). Nothing is destroyed. Capture or cession of the town hands the slots to the new owner (3.5).
- **Staffing:** the settlement's own people are the first hands for its slots (the M4 hands rule, with the settlement hex
  counted as a source). Jobs per stage are data, like districts.
- **New state:** per settlement hex a slot list (industry id, stage, works timer). This is a per-hex field in `MapState`
  (schema bump) and goes into saves (FORMAT 7, Q10). The hex still holds one *piece*, so M3's one-piece rule is intact; the
  slots are a property of the settlement piece.
- **Settlement panel:** the tile window (#436) gets, for an own settlement, an **Industries** tab: slot rows (kind, stage,
  idle or working, where its input comes from, yield breakdown), free slots with a Build button and a card, and a line when
  the industry is not yet open ("opens in 1490"). #436 must be built first (Q9) and must leave room for this
  tab. A foreign settlement shows its slot kinds and stages if the hex is seen (a building is visible) and nothing of the
  output, tier bonus or stocks.
- **Map:** a small trade mark (loom, anvil, loaf) beside the settlement per working slot, so the player sees industry
  without opening the window.

### 3.2 Buying inputs from the market, and M10 (Q6)

This is the real conflict. M10 builds markets and prices; the owner wants workshops to buy there, and Q9 puts the economy
BEFORE M10. Resolution (recommended): **M9.5 ships a minimal "home market", M10 replaces its body.**

- **M9.5 home market:** one per country, a single door `Buying.price(country, good)` and `Buying.take(country, good, loads)`.
  Price = base price x `market_buy_permille` (1200: 20 % above base). Supply is unlimited. Only the recipe inputs (wool, iron,
  grain) are buyable by workshops, and **arms** by a raise of companies at a higher premium (3.7); never by towns. No selling side change (selling stays at the fixed base
  price), no routes, no foreign stock. The goods come from nowhere and the money goes nowhere: a faucet of goods, a sink of
  money, deliberately small.
- **M10 adds:** real markets, stock, routes, reactive prices; the `Buying` door's body reads them. The caller (the workshop
  step) does not change. M10's spec gets one line: "replaces `Buying`'s static price and unlimited supply".
- **The order inside a workshop run:** take from the country's own surplus above the reserve first (free), then, if the
  workshop's **Buy inputs** switch is on (default on), buy the shortfall up to capacity at the market price, but only while
  the treasury stays above a floor (`buy_treasury_floor`, one season's upkeep and the army's pay, data). Buying shows as a new
  treasury line "Inputs bought" and a new stores flow `bought`; both extend the money and goods properties.
- **Why it cannot print money:** the crown keeps only 70 % of sales. Buy at 1.2x, sell the product, crown takes 0.7: a
  workshop must reach 0.7 x m x tier >= 1.2 to profit on bought input. Worked numbers (section 5) show village workshops
  LOSE on bought input, town ones break even, cities profit modestly. Own raw plus own bonus is where the money is.
- **Risks of this split:** (a) the `Buying` seam may be the wrong shape once M10 needs scarcity and per-market prices (keep it
  two functions, test it with a stub); (b) M10's tuning then also re-tunes workshop profit (one tuning, as draft 1 wanted, but
  the numbers shift when prices move: the soak ranges are re-run); (c) with unlimited supply a country with no land can still
  run a city weaver for a small profit: capped by slots and capacity and gone once M10 prices bite; (d) players may find a
  bakery a back-door food import (3.4): by design, at a price, bounded by capacity.
- **Alternatives:** (B) move the economy after M10, no seam, but the economy waits for trade, the longest queue; (C) fold the
  whole real market into M9.5, which is M10's size. Recommend the seam.

### 3.3 Own raw only (Q4)

"Raw at hand" gives **+25 %** (`near_input_permille` 250) when the **country owns** a district of the recipe's main input
within two hexes of the settlement, working at stage 2 or more (`near_input_min_stage`, new question N6, so a cheap stage 1
tile does not buy a bonus for bought input). Foreign raw tiles never count. The bonus is recomputed at once when ownership
changes. Ring lift for raw districts stays any-owner (unrelated).

### 3.4 Bread is food (Q7)

- **Food value (new `food_permille` on a good):** grain 1000, fish 1000, **bread 1500** a load. Recipe 3 grain -> 2 bread, so
  baking at tier 1.0 with no bonus is food-neutral (3.0 in, 3.0 out); with tier below 1 it loses food, above it gains.
- **Eating (owner, 2026-11-25):** towns draw their food need in food units, **the most efficient food first**: highest food
  value per load first, so bread (1.5) leads, then fish and grain (1.0 each); a tie goes to fish, then grain, then the lower
  good id, so the order is the same every time. This replaces "cheapest per unit first (grain, fish, then bread)" and the
  alternative "bread first". Bread is then eaten as it is made and sold only above the whole food need; grain and fish stay
  in the store (a larger carry) and are sold instead.
- **No double counting:** the country's "food made" for the surplus number counts raw food the districts make minus the grain
  the workshops take from its own stock, plus bread made x 1.5. Grain eaten and the same grain baked can never both count.
  Bought grain adds bread food without taking from the stock: an import, and so a surplus gain (by design).
- **Starvation by industry:** needs are served before workshops take anything (the reserve rule), so a workshop never makes a
  town starve this season. It can eat the surplus above the reserve, which is the carry for next season; a village bakery with
  no bonus (0.8) turns 3 grain into 2.4 food, so it shrinks the carry by 20 %. A pin: "after the works step, every town's
  need of this season is still met and the reserve is unchanged".
- **Comfort:** the comfort part of prosperity is cloth met for towns plus **bread's share of the food eaten** (full comfort at
  30 % bread, `bread_comfort_share` 300). Because bread is eaten first, the share is met whenever the stock holds it, so
  bread's comfort is never stuck at zero. Comfort still changes growth only, not taxes.
- **M4 food pins affected** (the first task is to grep tests for food, and the food keys of `game_defs`: `food_need_milli`):
  `test_good_defs` (good count 16 -> 19, kinds, new `food_permille`), `test_economy_defs`, `test_economy_season`,
  `test_economy_preview` and `test_economy_1480` (Genoa's table: bread stock zero so food units equal the old loads; stays
  exact with `IndustryFixture.off`), `test_improve_preview`, `test_no_other_writers` (new flows), `test_people_*`,
  `test_cards_people`, `test_people_growth` (the surplus now in food units), `test_map_modes`, `test_stats` and `test_snapshot`
  (new series), `test_save_file` (FORMAT 7). The rule that keeps almost all of them unchanged: with the fixture off, bread stock
  is zero and `food_permille` of grain and fish is 1000, so food units equal loads.

### 3.5 Own raw for bonus, any source for input: AI and conquest (Q4 + Q6)

Together: the bonus rewards owning the raw land beside the town, the input itself can come from anywhere.

- **AI:** the AI never needs a neighbour's raw or a trade deal to run a workshop; it needs a free slot, an open industry and a
  treasury above the floor. Its payback prior (`works_scan`) uses the card's number, which includes the bonus only if the AI
  owns a working raw district nearby, and subtracts the buying cost for the part it must buy. So AIs build raw districts
  beside their towns before the slot (the siting puzzle, solved by the same prior), and a merchant temper buys more.
- **Conquest:** (a) taking a town hands over its slots intact, but the new owner has no bonus unless it owns raw there: a
  conquered weaver town runs at tier only, on bought input; (b) taking or burning a raw district beside an enemy workshop
  town removes its bonus at once, a new war target value the AI should learn (a small `industry_value` term in province
  value, data weight); (c) an occupied town's slots are idle while occupied (M7 occupation), they wake on cession or
  liberation; (d) pillage stays out (as draft 1). The old "any owner" rule would have made border meadows a shared gift;
  "own only" makes them worth fighting for. It also means a rich city can still run on bought input: it is weaker, not dead.
- **Snowball check:** the rich country with own raw and a city gets +1.5625 yield; the poor one with bought input and a
  village gets 0.8 and loses money. The gap is wider than draft 1's; the soak range (section 10) is the brake test.

### 3.6 Industries open by year, later by technology (Q11, N1)

No workshop exists at the 1480 start in any scenario (the scenario bake has no slot rows). Industries are **buildings in
villages, towns and cities** (slots, 3.1), and a country may build one only once its **year gate** is open.

- **Before M11 (the owner's decision, no charter):** each industry has an `available_year` in data, the same for every
  country: **armourer 1485, weaver 1490, bakery 1495**; stage 3 of every industry opens at 1520 (`stage3_year`, the start of
  era II). Nothing to buy, no new country field, no new save state: `industry_open(year, industry)` is derived from the
  calendar. The slot rules ask only that one function.
- **Why these years (a placeholder, tuned in the soak):** the three arrive one after another, so the first decades have
  news each time (the first weaver appears ten years in). The armourer comes first because arms are now needed to raise
  companies (3.7): until 1485 every army is equipped by buying, at a premium, which makes the first years tense and gives the
  armourer an immediate reason. The bakery comes last because food is not scarce early and bread needs a grain surplus to be
  worth baking. Five to fifteen years is 20 to 60 seasons: long enough to feel like a new age, short enough that a playthrough
  sees it.
- **M11 replaces the gate with technology** (`tech-tree.md`, Trade & Industry): Guilds (era I) opens weaver and armourer,
  Crop rotation (era I) opens bakery, Guilds' era II follow-up opens stage 3. `industry_open` then reads the tech modifiers
  (`industry_unlock`, `industry_stage_max`) instead of the year; the callers do not change, and the year data is removed in
  M11's spec. Later industries (rope, glass, leather, powder) go straight to era II techs.
- **How the player and the AI first get one:** the Industries tab shows a not yet open industry greyed out with "opens in
  1490"; once open, a slot with a Build button. The AI needs no new option: the same slot build in `works_scan`, with the
  payback prior, starts the year it opens (merchants first on weavers, warlike on armourers, builders on bakeries).
- **Accepted cost:** with a year gate nobody can race ahead of the others; there is no choice in the opening of an industry,
  only in where and when to build it. That choice returns with M11.

### 3.7 Arms equip armies (Q12, decided)

**Rule:** raising a company needs **arms** in its cost. Iron is no longer the stand-in for the equipment. Arms are a made
good (4.2) from the armourer, or bought from the market at a **premium** (`arms_buy_permille` 1500: 50 % above the base of
9.0, so 13.5 a load, against 1.2x for ordinary inputs, because war cannot wait; confirmed in new question N7).

**Company cost (unit defs, data), today and new** (the other goods stay as they are):

| Company | Today (ducats + goods) | New (ducats + goods) |
|---|---|---|
| Pikemen | 25 + 1 iron | 25 + **1 arms** |
| Crossbowmen | 30 + 1 iron + 1 timber | 30 + **1 arms** + 1 timber |
| Knights | 45 + 1 iron + 3 horses | 45 + **1 arms** + 3 horses |
| Bombards | 60 + 5 iron + 3 copper | 60 + **2 arms** + 5 iron + 3 copper |

**Paying:** the raise first uses arms in the country's stores. If the stores are short, the shortfall is **bought** at the
premium and paid from the treasury together with the ducats, in the same action (the card shows "arms: 1 from stores" or
"arms: 1 bought, 13.5 ducats"). Buying shows on the "Inputs bought" treasury line and the `bought` flow.

**No arms and no money:** the raise is refused with one line, "no arms: 1 needed, 0 in the stores, 14 ducats to buy it, 8 in
the treasury", and nothing changes (the `raise_check` and `raise` pair contract holds). There is no unequipped or
half-strength company in the first version (new question N8). The answers open to the player are to build an armourer, save
up, or raise fewer companies.

**Worked cost of the equipment part of a company** (one arms load; own arms are valued at what the crown forgoes by not
selling them, 70 % of 9.0 = 6.3; the other goods and the ducat cost are unchanged and left out):

| Company | Old equipment (iron, 2.0 a load) | Own arms, cash 0 (forgone sale 6.3) | Bought arms, cash |
|---|---|---|---|
| Pikemen, Crossbowmen, Knights (1 arms) | 2.0 | 6.3 | 13.5 |
| Bombards (2 arms) | 0 (iron stays) | 12.6 | 27.0 |

So a pikemen company costs 25 ducats plus 1 arms: **31.3 with own arms, 38.5 with bought arms, against 27 before** (+16 % and
+43 %). Six pikemen companies: 188 with own arms, 231 bought. A country that arms itself keeps its army nearly as cheap as
before in cash (25 a company, the arms come from its own stores); a country that buys pays dearly. This drag is deliberate
(a country now pays for equipping its men); the soak watches army size per country, and the levers are data only (the ducat
cost of a company, the premium). One armourer town of section 5 makes about 18 arms a year at stage 2 with own iron: enough
for 18 companies in a year, so one armourer arms a peacetime country; a country at war needs a second.

**M7 / M8 interaction:**
- `Military.raise_check` keeps its order (hex, level, cap, held hex, stand, men, ducats) and gains the arms step after the
  ducats: stores, else market, else the refusal above. `men_at_hand` and the raise cap per hex do not change: men and arms are
  two separate limits and the smaller binds. Supply (M6, feeding in the field) is untouched: arms are a one-time cost of
  raising, not an upkeep. Refit and upgrade costs (`upgrade_cost`) check iron too and need an arms translation in the same
  data pass.
- **Reserve:** arms get a stores reserve (`arms_reserve_loads`, data, two companies' worth), so the armourer's product is kept
  for the army and not sold the moment it is made; only the surplus above the reserve is sold.
- **AI (M8):** `ai_forces` asks `raise_check`, so it sees the refusal; `ai_economy` prices a company's goods at the base
  price, so arms count 9 in its payback numbers. The armourer becomes **strategic**: warlike tempers get a high
  `industry_priority` for it, and an AI that cannot arm itself does not plan a war it cannot equip (a readiness line in the
  war plan: arms in stores plus treasury buying power for the planned companies). War needs arms, so the armourer's town
  becomes a military target, and in M10 an arms embargo or a blockade that stops buying is a real weapon (a line for M10's
  spec).
- **Fixture and pins:** `IndustryFixture.off(defs)` restores the iron cost in the unit defs, so every M6 to M8 pin holds with
  the fixture off. With it on, these change: `test_military` (`cost_of`, the shortfall text), `test_ai_forces`,
  `test_army_share`, `test_log_others`, `test_movement_war` (any raise that sets up armies), `test_ai_economy` (company
  valuation), the unit-def and good-def tests (goods 16 to 19), the raise-list panel text (`raise_list.gd`). New tests: raise
  with own arms, with bought arms, with neither (refusal, nothing changed), arms reserve not sold, the check-and-act pair
  property for raise with arms.


## 4. The model in plain words

### 4.1 Raw material per tile (Q5)

Every land tile makes exactly one raw: its district's good, or, if wild, its cover's good. The small second wild yield
(`keep_wild`) on goods districts is **dropped** (0 % at every stage); settlements and ports keep theirs (a village still
makes some grain, a port its fish). The tile window says it in one line: "Raw: wool, 12 loads this season". Raw is sold as
today (base price now, market price from M10).

### 4.2 Industries: recipes from input to product

A **recipe**: inputs in, product out, per season, with a capacity per stage. Value multiplier m = product value / input value.

| Industry | Recipe | Product price | Input value | m | Capacity in, stage 1 / 2 / 3 (loads a season) | Upkeep a season, stage 2 | Opens (year, then tech) |
|---|---|---|---|---|---|---|---|
| Weaver | 2 wool -> 1 cloth | 6.0 | 3.0 | 2.0 | 8 / 16 / 28 | 3 | 1490 / Guilds |
| Armourer | 2 iron -> 1 arms | 9.0 | 4.0 | 2.25 | 4 / 8 / 14 | 3 | 1485 / Guilds |
| Bakery | 3 grain -> 2 bread | 2.4 | 3.0 | 1.6 | 12 / 24 / 40 | 2 | 1495 / Crop rotation |

New goods are a fifth kind, `made`: cloth, arms, bread, ids 16, 17, 18 (appended after silver). Cloth: reserve 0 (sold
as made until M10). Bread: food 1500 permille, kept as a food reserve (4.3). Luxury raws (silk, silver, dyes) have no industry.

### 4.3 The season step

Inside `production`, between needs and sales:

```
made    districts make their raw (as M4)
needs   towns take food (in food units, the most food per load first: bread, then fish, grain), wine, salt, oil; the rest is the surplus above the reserve
works   each working slot, in settlement index then slot order:
          own    = min(capacity x staffing, own surplus of the input)
          bought = if Buy inputs on and treasury stays above the floor:
                     min(capacity x staffing - own, ...) at base x market_buy_permille / 1000   (Buying.take)
          makes  = (own + bought) x out / in x tier x (1000 + at_hand) / 1000      (integers, floored)
sales   the surplus of raw and the new goods is sold (M4 4.8, or M10's trade phase)
```

Workshops have no weather or winter slot (flat all year). New stores flows: `worked` (own raw taken in) and `bought`
(market input); the product is an ordinary `made` flow; a new treasury line "Inputs bought". "Closing minus opening equals
the sum of the flows" and the money identity still hold.

### 4.4 Tier by settlement level (Q3)

| Settlement | hamlet | village | town | walled town | city |
|---|---|---|---|---|---|
| Slots | 0 | 1 | 2 | 3 | 4 |
| Yield (permille) | no | 800 | 1000 | 1100 | 1250 |

Total yield = tier x (1 + own at-hand 0.25): 0.8 (village, none) to 1.5625 (city with own raw). A level drop lowers tier and
idles the top slots at once; the card warns ("this town is under 3,000 people").

### 4.5 People: surplus and prosperity (Q8)

```
mult   = 500 + surplus x 350 / 1000 + prosperity x 350 / 1000          # permille; 500 fed only, 1200 at best
growth = floor(people x growth_bp[tax] x growth_percent[slot] x mult / 1e9)
```

- **Surplus** (0 to 1000): food units made over the season minus food units eaten, as a share of the need; 25 % of the need
  or more counts 1000 (data). Food units per 3.4.
- **Prosperity** (0 to 1000): the mean of M4's contentment (wine, salt, oil, food) and the new **comfort** (cloth met for towns
  plus bread's share of food eaten). Growth only, not taxes: M4's tax pins do not move.
- Pace (a village to a town, 34 seasons today in frost at Normal): at mult 500 it takes 68, at 750 45, at 1000 34, at 1200 28.
  Hunger, crowding and room rules do not change; settlements still raise themselves to town only.

### 4.6 How it feeds treasury, trade, people, army

- **Treasury:** products are sold like any good, taxed by `tax_goods`. Workshops pay upkeep; bought input is a new expense
  line. The report shows Goods, "worked", "bought" and a per-country "Industry added +n" note.
- **Trade (M10):** cloth, arms and bread get appetite and market prices; a glut of cloth lowers its price (the natural brake,
  from M10 only). `Buying` becomes a real market read.
- **People:** bread feeds, bread and cloth raise prosperity; bigger towns have more slots and a better tier.
- **Army (M6, M7):** arms are required to raise a company; a country without them buys them at a premium (3.7). The
  armourer is strategic, not just a sale good. No quality effect of arms in the first version.

## 5. Worked numbers under the new rules

All per year (4 seasons), stage 2 slot, calm weather, Normal taxes (crown takes 70 %), fixed prices, market buying at 1.2x.
Raw from M4's frost column: wool 48 (x1.5 = 72, crown 50.4), iron 29 (x2.0 = 58, crown 40.6), grain 32 (x1.0 = 32, crown
22.4). "Own" = own working raw district at hand, input from the country's own surplus (bonus 1.25). "Bought" = no raw land,
all input at 1.2x, no bonus. "Net" = crown take of the product, minus what the raw would have given the crown (own) or the
buying cost (bought), minus upkeep (weaver and armourer 12 a year, bakery 8).

**Chain 1: wool -> cloth (6.0 a load)**

| Site | Yield | Cloth | Worth | Crown 70 % | Net before upkeep | Net after upkeep |
|---|---|---|---|---|---|---|
| Village, own wool | 1.0 | 24 | 144 | 100.8 | +50.4 | +38.4 |
| Town, own wool | 1.25 | 30 | 180 | 126.0 | +75.6 | +63.6 |
| Walled town, own wool | 1.375 | 33 | 198 | 138.6 | +88.2 | +76.2 |
| City, own wool | 1.5625 | 37.5 | 225 | 157.5 | +107.1 | +95.1 |
| Village, bought (cost 86.4) | 0.8 | 19.2 | 115 | 80.6 | -5.8 | -17.8 |
| Town, bought | 1.0 | 24 | 144 | 100.8 | +14.4 | +2.4 |
| City, bought | 1.25 | 30 | 180 | 126.0 | +39.6 | +27.6 |

**Chain 2: iron -> arms (9.0 a load)**

| Site | Yield | Arms | Worth | Crown | Net before | Net after |
|---|---|---|---|---|---|---|
| Village, own iron | 1.0 | 14.5 | 130.5 | 91.4 | +50.8 | +38.8 |
| Town, own iron | 1.25 | 18.1 | 163.1 | 114.2 | +73.6 | +61.6 |
| City, own iron | 1.5625 | 22.7 | 203.9 | 142.7 | +102.1 | +90.1 |
| Village, bought (cost 69.6) | 0.8 | 11.6 | 104.4 | 73.1 | +3.5 | -8.5 |
| Town, bought | 1.0 | 14.5 | 130.5 | 91.4 | +21.8 | +9.8 |
| City, bought | 1.25 | 18.1 | 163.1 | 114.2 | +44.6 | +32.6 |

**Chain 3: grain -> bread (2.4 a load; also food at 1.5 a load)**

| Site | Yield | Bread | Worth | Crown | Net before | Net after | Food units made from the grain |
|---|---|---|---|---|---|---|---|
| Village, own grain | 1.0 | 21.3 | 51.2 | 35.8 | +13.4 | +5.4 | 32 (from 32: neutral) |
| Town, own grain | 1.25 | 26.7 | 64.0 | 44.8 | +22.4 | +14.4 | 40 (+8) |
| City, own grain | 1.5625 | 33.3 | 80.0 | 56.0 | +33.6 | +25.6 | 50 (+18) |
| Village, bought (cost 38.4) | 0.8 | 17.1 | 41.0 | 28.7 | -9.7 | -17.7 | 25.6 imported |
| Town, bought | 1.0 | 21.3 | 51.2 | 35.8 | -2.6 | -10.6 | 32 imported |
| City, bought | 1.25 | 26.7 | 64.0 | 44.8 | +6.4 | -1.6 | 40 imported |

The bakery is a thin ducat earner and a good people engine: it makes more food from the same grain in a bigger town, and
bought grain is food imported at 1.2 ducats a unit (a famine relief, bounded by capacity and a slot).

**Chain 4 (raw is enough): silk.** 9 loads x 6.0 = 54 a year from one tile, no industry. Raw luxury stays a real strategy.

**Is it worth the slot?** Weaver in a town with own wool: net +63.6 a year for about 200 ducats and 10 timber: payback about
3.1 years, against about 2.5 for a raw tile (100 + 10 timber, +42 after upkeep). A bought-only village slot loses money, so
the bad site is also a visible loss (the card says so). The slot is not free: a settlement has 1 to 4 of them.

**A whole country.** One stage-2 sheep, iron and wheat district; weaver and armourer in a town (2 slots), bakery in a second
town, all own at hand: raw crown 113.4; with industry 113.4 + (75.6 + 73.6 + 22.4) - 32 upkeep = 252.9: about **+139.6 a year**,
2.2 times the raw crown, about +30 % on Genoa's 1480 income of 458. Soak target unchanged: an industrial country earns 1.2 to
1.6 times its raw-only twin at year 40, and the raw-only twin never falls below 60 % of it.

## 6. Player and AI

**Player:** waits for the industry's year (3.6), then builds it in a free slot through the settlement's works card (cost, stages
4 / 8 / 16 seasons). The card shows the recipe, tier, whether own raw is at hand, the Buy inputs switch (per workshop, on its own card; decided 2026-11-25), this season's use,
buying and output, and the income change per year, from the same code the season runs (`ImprovePreview`).

**AI (M8 `AiEconomy`):** one new option, a slot build in `works_scan` (settlements with a free slot and an open industry),
plus the arms readiness rule and the strategic armourer weight (3.7). The prior is the card's payback, zero when there is neither a surplus nor a positive bought-input
margin, so the AI never builds a loss maker. One data weight per temper (`industry_priority`). It also upgrades a settlement
partly for its slots and builds raw next to its industry towns (3.5). No micro-management. Traces log "industry: weaver in
Genoa slot 2, own wool at hand, payback n seasons".

## 7. UI

Points to `docs/design/ui/` (the Studiolo style) and the tile window #436.

- **Tile window (#436):** own settlement: Details (people, raw, goods), tab **Industries** (slot rows, Build, "opens in <year>" lines),
  tabs for army and ships are #436's. A raw district shows "Raw: wool, 12 loads". Foreign: piece, stage, owner, slot kinds
  if seen. Sea or unseen: as today.
- **Works card (slot):** recipe, tier table (village / town / city), own raw at hand (a yes or no and where), Buy inputs
  switch, capacity, change in income per year.
- **Goods screen (Statesman's Study):** the new goods, "worked" and "bought" columns, each slot's line, an **Industries**
  list (open and not yet open, with the year; M11 replaces the year with the tech link). Treasury page: the "Inputs bought" line.
- **Map:** a small mark per working slot; the "at hand" relation as a thin link to the own raw tile while the card is open.
- **People:** the town card adds the surplus and prosperity bars, the growth word ("slow", "steady", "fast") and bread's food
  line.
- **Report:** per good "worked", "bought", "made"; the glance note "Industry added +64 this year".

## 8. Interactions

| System | Effect |
|---|---|
| Economy (M4) | One new step in `production`; `EconomySeason`, `EconomyPreview`, `DistrictCache` learn slots; food measured in food units; a treasury line |
| People (M5) | `change_at` takes `mult`; surplus and prosperity derived each season, not stored; slots idle on a level drop |
| War (M6, M7) | Arms required to raise a company, bought at a premium if short (3.7); conquest and occupation rules in 3.5; raw loss removes the bonus; pillage out |
| Diplomacy (M9) | Nothing new; war weariness reads `tax_goods`, now including made goods |
| Trade (M10) | Replaces `Buying`; cloth, arms, bread get appetite and prices (X31); free traders carry them; a toll on them |
| Research (M11) | Modifier keys `industry_unlock`, `industry_yield_permille`, `industry_stage_max`; replaces the year gate: Guilds and Crop rotation open the industries |
| Debt (M12) | Upkeep and purchases show deficits sooner; no other change |

## 9. Saves, balance, fog

**Saves (Q10).** Bump `save_file.gd` FORMAT to **7** and refuse older saves with a clear message (public save compatibility
starts at M12). Changes in the file: goods ids 16 to 18; `MapState` slot lists per settlement hex; unit defs use arms; Stores `FLOWS` + `worked`, `bought`; `Stats.SERIES` industry rows; a treasury line; the digest text. The saved game plays by
new rules (growth, no `keep_wild`), so old digests cannot match anyway.

**Balance.** The brakes, in order: slots per settlement, the year gate, input as own surplus or bought at 1.2x,
capacity by stage, upkeep, tier and own-raw siting, and from M10 falling prices. `IndustryFixture.off(defs)` (tests only, the
`TradeFixture.still` pattern): no slot usable, `Buying` off, `mult` fixed at 1000, bread stock zero, so every pin of M3 to M9
holds. Genoa's table (M4 4.15) is untouched.

**Fog.** A foreign settlement's slot kinds and stages are visible with the hex; output, tier bonus, stocks, buying and
comfort are not. Cloth and arms prices follow M10's knowledge rule. Rankings stay banded. The test viewer `&""` sees all. A
lost tile's fog is #435's one shared rule.

## 10. Tests and the soak

- Pure unit tests: recipe step (floors, capacity, own then bought, treasury floor), tier and slot tables, own at-hand scan with
  the stage rule, food units and no double counting, growth `mult` (40 seeded cases), no stock writer outside `stores.gd`, money
  and goods properties extended to `worked` and `bought`.
- Pins: "needs met and reserve unchanged after the works step"; "bought-only village slot never raises the treasury"; "a level
  drop idles the top slot and nothing else"; "capture hands slots over, bonus recomputed".
- Preview equals season for slots: 200 seeded cases now include slot builds, the year gate, Buy inputs and raising with arms.
- Worked-numbers test: each cell of section 5 pinned on a fixture so doc and code cannot drift.
- Soak (`tools/soak.gd`): invariants every season: no negative stock; made never above capacity x tier x at-hand; `worked +
  bought` equals input taken; people grow only when fed; no slot built before its industry's year; no raise without arms. Ranges: industrial twin 1.2 to 1.6 of the
  raw-only twin at year 40; at least half the AI countries own a workshop by year 40; no AI ruin from workshops or buying alone;
  no country buying more than a set share of its inputs for 40 years (a monitor for the unlimited-supply loophole).
- `tools/economy_report.gd` gains an industry block (per country and slot: used, bought, made, worth, tier, at hand).
- Goldens change for the goods screen, works card and tile window: planned with #436, refreshed once.

## 11. Where it fits (Q9)

Order: M7 war (building), M8 AI, M9 diplomacy, **M9.5 Industry**, M10 trade, M11 research, M12 whole game. The tile window
(#436) is built just before M9.5 and must leave an Industries tab. M9.5 is now about **1.3 M4-sized slices** (slots and the
settlement panel, the home market seam, arms as a raise cost and bread-as-food are new); plan it as two build groups: **A** the model
(defs, slots, recipes, year gate, arms in unit defs, stores, season step, preview, tests), **B** the surfaces (growth rule, `Buying`, AI options,
cards and Industries tab, report, soak ranges, docs). M10's spec gets three edits (goods and appetite rows, `Buying`
replacement, `worked`/`bought` in its flow table); M11's gets four modifier keys and the removal of the year gate; M10's also gets the arms embargo line.

## 12. Risks

- **Snowball.** Rich countries with own raw and cities pull ahead. Brakes in section 9; soak range; lower the city tier 1250
  to 1150 (data only) if still strong.
- **The seam.** `Buying` may not fit M10; keep it two functions and stub-tested.
- **Unlimited-supply loophole until M10.** A landless city weaver earns about +28 a year on bought input; capped by slots,
  capacity and the soak monitor; gone when M10 prices bite.
- **Food model confusion.** Two food units (grain 1.0, bread 1.5) and a surplus in food units may confuse players; the town
  card must say it in words.
- **Slot and level upgrade share one job.** Can slow a growing city; see N5.
- **The year gate dies with M11.** Little throw-away code (a year table); one spec line removes it.
- **Arms make wars dearer and slower to start.** +16 % (own arms) to +43 % (bought) on a company; the soak watches army size;
  levers are data only (3.7). An AI with no armourer buys at the premium, so early wars can drain treasuries.
- **Spreadsheet feel.** The chain line and at-hand link must be clear; playtest the card first.
- **Slower growth** for countries that only just feed their people (500 vs 1000): intended, playtest early game.
- **Build size.** Do not add era II industries to M9.5.
- **Arms as the raise bottleneck.** A country that loses its armourer town in war cannot rearm except by buying; in M10 a
  blockade can stop that. Intended, but the AI's readiness rule must be tested for deadlocks (no raise, no peace).

## 13. Smallest first version

Three industries (weaver, armourer, bakery) as settlement slots (village 1, town 2, walled 3, city 4); year gate as the
tech stand-in; arms required to raise a company (own or bought at a premium); tier table; own at-hand +25 %; the home market `Buying` at 1.2x for the three inputs; bread as food 1.5; the
growth multiplier with surplus and prosperity (comfort from cloth and bread); one AI option pair with a temper weight; the
Industries tab, works card section, the raise card's arms line and report lines; three goods; tests, soak ranges, economy report. No real prices (M10).

## 14. Questions for the owner

**Closed by the owner's answers of 2026-11-23:** Q1 slot in the settlement; Q2 weaver, armourer, bakery; Q3 0.8 / 1.0 / 1.1 /
1.25, no hamlets; Q4 own raw only; Q5 one raw per tile, drop `keep_wild` on goods districts; Q6 buy from the market; Q7 bread
is food; Q8 `500 + 350 x surplus + 350 x prosperity`, ceiling 1200; Q9 M9.5, tile window first; Q10 FORMAT 7, refuse older
saves; Q11 no start workshops, technology unlocks; **Q12 arms are needed to raise companies, bought at a premium if not made
(3.7)**; **N1 industries open from a set year (no charter), M11 replaces the year with techs (3.6)**; **N2 market buying 1.2x
base, per-workshop switch, treasury floor**; **N3 bread is 1.5 food per load**; **N4 slots grow with the settlement, 1 / 2 / 3
/ 4 by level, one of each industry**; **N5 one job per settlement hex at a time**.

**Default, owner to confirm:**

N6. **At-hand rule detail.** Own district, working at stage 2 or more, within two hexes, flat 25 %. Alternatives: stage 1
    counts; or the bonus scales with the raw's output. **Default: stage 2 or more, flat 25 %.**

**New questions from this revision (each with a recommendation):**

N7. **The arms premium and the count per company.** Recommend 1500 permille of base (13.5 a load) and 1 arms per pikemen,
    crossbowmen and knights company, 2 per bombards. Alternatives: premium 1300 (kinder to a young country) or 2000 (makes the
    armourer almost mandatory). The soak tunes it; the card shows both prices.
N8. **A raise with no arms and no money.** Recommend refusal with a clear line, no half-equipped company. Alternative: a
    cheap unarmed "levy" company at half strength, raisable without arms (a safety valve against deadlock, but a new unit kind
    and a balance pass).
N9. **Arms for refit and upgrade (M6).** Recommend refit and upgrade costs use arms as well (the same data pass as 3.7), with
    the same buying rule. Alternative: they keep iron, so arms are only for raising.

---

## Owner's answers, 2026-11-24 (N6 to N9)

- **N6, raw at hand:** an own raw district at stage 2 or better within two hexes gives the +25 % bonus (the recommended
  rule), and the bonus grows by small steps as that raw district is upgraded (a higher stage of the raw tile adds a little
  more; the exact steps are data, set by the soak).
- **N7, arms price:** the market price of arms is to be decided later; use 50 % over the base price as a placeholder.
- **N8, no arms and no money:** the raise is refused with a clear message; no unarmed levy.
- **N9, refit and upgrade:** they need arms too (the same rule as raising).

All the open questions of this design are now answered; the next step is its build plan (M9.5), after the tile window
and the fog and movement decisions that touch the same panels and views.

## Owner's answers, 2026-11-25 (build questions of M9.5)

- **Bread order:** towns eat the most efficient food first (highest food value per load; bread 1.5, then fish and grain; ties
  fish, grain, then good id). This replaces "bread last" (the design) and "bread first up to 30 %" (the build spec's
  recommendation). Bread's comfort is full whenever the stock holds 30 % of the need; the food surplus does not depend on the
  order; bread is sold only above the whole food need; the balance soak adds bread eaten and sold and re-measures the
  bakery's payback.
- **Plaque bar:** nothing yet. The Town tab plaques show the category name and "N built of M" only; no workers bar. The
  workers data stays in the models, and a bar is a later decision once real workers data exists.
- **Buy inputs switch:** one switch per workshop, on that workshop's own card (opened by a click on its tile), default on,
  with a small coin badge on the tile while it buys (option A of the sketch "Buy Inputs Switch"). The final card is mocked up
  at the gate (EC0) before the shell is built.
- Still open, with their recommendations in the build plan (section 10): whether the free refill of men needs arms (question 2),
  cloth as a comfort need (5), and the Slots chip replacing the Works chip on settlements (6).
