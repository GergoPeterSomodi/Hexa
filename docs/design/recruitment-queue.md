# Recruitment queue, barracks and unit looks (issues 463 and 433)

**Status: draft. The owner's answers of 2026-11-26 to 2026-11-28 are recorded. Nothing of the design is built; only the
test helpers (task RQ0) are done.** Grounded in the Godot code on master.

The feature has two parts, designed here together:

- **Part 1, the queue** (sections 1 to 10): companies are queued at a barracks and are ready after a season.
- **Part 2, unit looks and selection** (section 11): unit art and cards, and picking units on the map.

Build tasks are in section 12, questions for the owner in section 13. "Page's choice" marks a rule the owner was not asked
about; the build takes it unless the owner says otherwise.

## Owner decisions (fixed)

| # | Decision | Date (2026) |
|---|---|---|
| 1 | Companies are queued with a **minus / count / plus** stepper in the tile window's Army tab, instead of an instant Raise. | 11-26 |
| 2 | Every company takes **one season** to be ready (all kinds the same for now). | 11-26 |
| 3 | Withdrawing a queued company gives **everything back** (ducats and goods), at any time before it is ready. | 11-26 |
| 4 | Companies queued together **train one per season, in turn**. | 11-26, 11-27 |
| 5 | A settlement **taken by force**: the queue is **lost** (the men go home; the ducats and goods are lost). | 11-27 |
| 6 | A settlement **besieged, or with an enemy army on it**: the queue **waits** (nothing finishes, nothing can be queued; withdrawing is allowed). | 11-27 |
| 7 | A settlement **ceded in a peace**: the queue is **lost**. | 11-27 |
| 8 | The tile window's footer queue shows **only the company in training now**. | 11-27 |
| 9 | A ready company with **no room on the hex waits**; the ones queued behind it do not train meanwhile. | 11-28 |
| 10 | A foreign army that is not an enemy changes nothing: **only enemies stop** the queue. | 11-28 |
| 11 | **Units can be built only with a barracks.** | 11-28 |
| 12 | The barracks requirement ships **together** with the queue. | 11-28 |
| 13 | At the start **only the capital** has a barracks. | 11-28 |
| 14 | A barracks can be built in a **town or bigger**. | 11-28 |
| 15 | A settlement with a barracks queues **at most 5 companies** ("as many as you want but limit to 5 now"). Kept in data. | 11-28 |
| 16 | **Unit rework** joins this feature: **looks and selection only** (unit art and cards; clicking units on the map apart from their tile). No new unit kinds, no combat or balance changes, no army organisation changes. | 11-28 |
| 17 | **Bern, Siena and Lucca start with a barracks** although they are villages; "town or bigger" applies to building. | 11-28 |
| 18 | France, Austria and the Papal States start with theirs at **Fréjus, Bolzano and Bologna**. | 11-28 |
| 19 | A barracks trains **one company a season**, although every country then starts at one company a season (confirms decision 4). | 11-28 |
| 20 | A barracks costs **150 ducats, 10 timber and 10 stone, takes 4 seasons, upkeep 1 ducat a season**. | 11-28 |

Decision 15 replaces the older limits (3 a settlement, then the smaller of 3 and a number by settlement size).

### Where the decisions and the data collide

Numbers are in section 3. The owner answered the first two (decisions 17 and 18).

| Conflict | What the data says | This page takes |
|---|---|---|
| **13 against 14:** only the capital has a barracks, but a barracks is for a town or bigger | The capitals of Switzerland (Bern), Siena and Lucca are **villages** | The start barracks is given whatever the size; decision 14 governs **building** (decision 17) |
| **13 against the map:** a capital has the barracks | France, Austria and the Papal States have **no capital on this map** | The scenario names one settlement for each (decision 18) |
| **11 with 14:** no barracks, no units; barracks only in a town | France, Siena and Lucca own **no town**. Siena and Lucca can **never** have one (each is beside a walled town, and two towns may not be neighbours) | Solved by the two rows above, as long as a barracks is never destroyed (question 4). Read strictly, Siena and Lucca could never raise a unit |

## 1. Goal

You plan your army a season ahead: order companies at your barracks, watch your money and the map, change your mind for free,
and end the season. The companies march out next season. Where your barracks stand is now a decision too: near the front they
answer quickly and are exposed; deep inland they are safe and slow.

Why it is fun: raising becomes a commitment you can still take back, a threat has to be seen coming, and a barracks is a
place worth building, defending and attacking.

## 2. How it works today

- **Raising** (`Military.raise_check` and `Military.raise`, action `raise {hex, kind, count}`): any settlement of your own
  that is not occupied and has no other country's army on it. The company exists at once.
- **Cap per season** by settlement level (`FamilyDef.raise_cap`): hamlet 1, village 1, town 2, walled town 3, city 4.
- **Kind gates** (`UnitDef.min_level`): pikemen and crossbowmen from a hamlet, knights from a village, bombards from a town.
- **Room:** 8 companies of one country on a hex.
- **Men:** a tenth of the people of the hex and of your six neighbouring hexes. Ducats and goods are paid at once.
- **Mustering:** an army with a company raised this turn cannot walk this season. Disbanding that company on its home hex in
  the same season refunds it.
- **Computer:** raises one company at a time, up to 2 a turn at peace and 4 at war.
- **Barracks:** none in the Godot rules. `godot/data/buildings.json` (exported from the frozen Python game, read by no rule)
  lists a Barracks at 220 ducats, upkeep 0.4, one level, whose job was drilling for better attack or defence.
- **Buildings in Godot** are either a hex's one piece (settlement, castle, harbour, a goods district: `Works` puts them
  through `Improve`) or nothing. A settlement hex already holds its settlement, so a barracks needs a place of its own.

## 3. What the data says (Italy, 1480, the only scenario)

Settlements and people come from the map and are the same for every seed. 71 settlements: 23 villages, 36 towns, 10 walled
towns, 2 cities. Settlements cannot be founded or pulled down.

| Country | Capital | Town or bigger | Barracks at start, words as read | Barracks at start, this page | Today's cap: companies a season | War goal, in pikemen companies | Pikemen companies the start barracks' men give with no growth |
|---|---|---|---|---|---|---|---|
| Savoy | Turin, town | 10 | Turin | Turin | 24 | 8 | 116 |
| Milan | Milan, city | 17 | Milan | Milan | 40 | 10 | over 200 |
| Venice | Venice, city | 5 | Venice | Venice | 20 | 11 | 138 |
| Genoa | Genoa, walled town | 2 | Genoa | Genoa | 5 | 2 | 81 |
| Tuscany | Florence, walled town | 2 | Florence | Florence | 7 | 2 | 80 |
| Mantua | Mantua, town | 1 | Mantua | Mantua | 2 | 1 | 36 |
| Ferrara | Ferrara, walled town | 2 | Ferrara | Ferrara | 5 | 2 | 85 |
| Switzerland | Bern, **village** | 6 | none; can build | Bern | 14 | 5 | 16 |
| Siena | Siena, **village** | 0 | **none, ever** | Siena | 1 | 1 | 6 |
| Lucca | Lucca, **village** | 0 | **none, ever** | Lucca | 1 | 1 | **2** |
| France | **off the map** | 0 (3 villages) | **none until a village becomes a town** | Fréjus (village) | 3 | 2 | 41 |
| Austria | **off the map** | 2 | none; can build | Bolzano (town) | 5 | 2 | 33 |
| Papal States | **off the map** | 1 | none; can build | Bologna (walled town) | 6 | 4 | 92 |

- **Capital is a town or bigger:** 7 of 13. Village: 3. Off the map: 3.
- **Villages that can never become a town** (beside a walled town or city): 9. Siena, Lucca, Lausanne, Lodi, Piacenza,
  Bergamo, Vicenza, Treviso, Ravenna.
- **Kinds:** a town trains all four. A village barracks (Bern, Siena, Lucca, Fréjus, or a town that shrank) cannot train
  **bombards**. A town that shrank to a hamlet cannot train knights either.
- **Slower raising:** today a country can raise 1 to 40 companies a season; at the start it will finish **1 a season** in the
  whole country, until it builds more barracks. Milan's war goal then takes 10 seasons instead of 3.
- **If the start barracks is occupied**, other places to build one: Milan 16, Savoy 9, Switzerland 6, Venice 4, Austria,
  Genoa, Tuscany and Ferrara 1, **none** for Mantua, Siena, Lucca, France and the Papal States. Those five raise nothing
  until they retake it or make peace (France and the Papal States also if a village of theirs grows into a town and gets a
  barracks). Today France and the Papal States could still raise in their other villages.
- **A French village to a town:** about 30 seasons of growth at normal taxes, or the settlement work (200 ducats, 20 timber,
  10 stone, 8 seasons), and then the barracks work.
- **Affording a barracks** at the proposed 150 ducats, 10 timber, 10 stone: every country can at the start (the poorest,
  Lucca, has 225 ducats; every country has 40 timber and 40 stone). From an empty treasury, saving the 150 ducats at the
  first year's income and no army: Lucca about 19 seasons, Siena 10, Mantua 9; France, Austria and Ferrara 3; every other
  country at most 2. An army's upkeep (6 a pikemen company) makes the small states much slower.
- **Men:** repeated raising at one barracks takes people from its own hex first, so that town shrinks (Turin: 10 companies
  take it from 10,000 towards 5,000). Lucca's whole barracks area holds men for 2 pikemen companies before it must grow.
- **Iron** (unchanged by this design): every company needs iron, every country starts with 20, and without an iron mine
  there is no way to get more before markets exist.

## 4. The barracks

### 4.1 What it is

A **building of a settlement**, beside the settlement itself: one level, at most one a settlement. It does one thing in this
version: companies can be queued there. Drill, faster training and more levels come later (section 9, seams). It has no
picture on the map in this version (page's choice); the Town tab shows it.

| Name (data) | Where | Value (decision 20) |
|---|---|---|
| `cost` | a new `data/defs/buildings/barracks.tres`, listed by `GameDefs` | 150 ducats |
| `cost_goods` | the same | 10 timber, 10 stone |
| `seasons` | the same | 4 |
| `upkeep` | the same | 1 ducat a season |
| `min_level` | the same | 3 (town), decision 14 |
| `barracks` | `ScenarioDef`, a list of hexes kept by hand | the 13 hexes of section 3 |

A scenario that lists none gives each capital on the map a barracks (page's choice, for made-up test scenarios).

### 4.2 Building one

A **work**, like every other building: action `build_barracks {hex, tag}`, a `Work` with the new action `barracks`.

- Checks, in order: your land; no work under way on the hex; not occupied or besieged; a settlement; no barracks there yet;
  a **town or bigger** ("a barracks is built in a town or larger"); a free work slot (question 5); ducats; goods.
- It behaves as other works do: it counts down in the works step, halts under occupation, siege and in a snow winter, is
  refunded when cancelled in the season it began, and is lost with nothing back when the land is lost.
- One work a hex: while a barracks is built, that settlement cannot be upgraded, and its people neither raise nor lower its
  level (today's rule for any work).
- Work slots: Switzerland, Mantua, Siena, Lucca, France and Austria have 1; Savoy, Genoa, Ferrara and the Papal States 2;
  Milan and Tuscany 3; Venice 5.
- Upkeep is paid with the settlement's own upkeep, by the same rule. There is no way to pull a barracks down (page's choice).

### 4.3 Trouble

| Case | The barracks | The queue | A barracks work under way |
|---|---|---|---|
| Besieged, or an enemy army on the settlement | stands | waits (decision 6) | halts (an enemy army without a siege or occupation does not halt works, as today) |
| Taken by force (storm, siege, walk-in) | **stands** (question 4); nobody raises on occupied land | **lost** (decision 5) | halts |
| Retaken, or released in a peace | the owner's again, working | empty | goes on |
| Ceded in a peace | **passes to the new owner**, working | lost (decision 7) | lost, nothing back |
| The town shrinks to a village or hamlet | stays and works (page's choice, question 4) | stays | goes on |

- **Loss of the capital.** A capital can be taken by force but is never ceded (a peace moves no capital), and it does not
  move. While it is occupied you raise only at other barracks, or build one in another town. At the peace or the retaking it
  comes back with its barracks. Countries are not eliminated in today's rules.
- The seats of France, Austria and the Papal States are not capitals in the rules, so they **can** be ceded. A country that
  loses its last barracks this way builds a new one in a town, if it has or can make one.
- In today's rules a peace moves only land the winner already occupies, so a ceded settlement has usually lost its queue at
  the capture. Decision 7 still applies to every change of owner (developer transfer, later diplomacy).

## 5. The queue

### 5.1 Season by season

| When | What happens |
|---|---|
| Spring 1481, your turn | Plus queues a company at Turin's barracks. Ducats, goods and men leave now. Minus gives all of it back. |
| End season, computer turns | Computer countries queue by the same action. A queued company does not exist yet: it cannot fight, be seen or be attacked. |
| End season, new `muster` step | In each settlement the **company in training** (the oldest queued) counts down one season. At zero it appears. The ones behind it do not count down. |
| Summer 1481, your turn | The company is in an army with full move points and can march at once. Upkeep and food start with this season. The next queued company is now in training. |

- The `muster` step sits **after `march_on` and before `stats`**: battles, sieges, works and the end-of-season marches are
  over, and the season's report and statistics include the new company. It pays no upkeep for the queued season (today a
  company does, so this is a small saving).
- A ready company joins the first army of yours on the hex (by id) that is not marching or storming and did not walk in the
  end-of-season leg; otherwise it makes a new army.
- **One company a settlement a season** (decision 4). Three queued in Spring 1481 are ready in Summer, Autumn and Winter.
- Withdrawing the company in training puts the next in training; it is ready at the coming muster step.
- A company the computer queues into an empty queue during End season is ready in that same End season, exactly as yours
  queued in your turn.

### 5.2 Numbers (data, not code)

| Name | Where | Value |
|---|---|---|
| `recruit_queue_size` | `GameDefs` | 5 companies a settlement with a barracks (decision 15) |
| `raise_seasons` | `UnitDef`, one per kind | 1 for all four |
| `min_level` | `UnitDef` (today's data) | pikemen 1, crossbowmen 1, knights 2, bombards 3 |
| `levy_permille` | `GameDefs` (today's) | 100 |
| `stack_limit` | `GameDefs` (today's) | 8 |

`Recruiting.queue_size(game, tag, hex)` is `recruit_queue_size` where a barracks stands, else 0. The queue size and the
countdown each go through one function, so later modifiers have one place to go.

### 5.3 What disappears

| Today | With the queue |
|---|---|
| Raising in any settlement | Only where a barracks stands (decision 11) |
| The per-season cap (`raise_cap`, "raised this season") | Gone, with its data field. The queue limit of 5 is the only limit |
| Refusal for **any** foreign army | Only an enemy army or a siege (decisions 6 and 10) |
| Mustering (`Army.mustering`, its token mark, words and preview cases) | Gone: the queue is the mustering. An army that receives a company is not frozen (amends moves rules R15, R16, R20) |
| Refund by disbanding in the raising season | Gone. Disbanding sends the men home, nothing else, and always asks first. The refund moves to withdrawing |

**Kept:** the kind gates by level (`min_level`). With barracks in towns they matter only for a village barracks (no
bombards) and a shrunken town. **Kept:** the levy from the hex and its ring; it does not conflict, but see the risks.
The scenario's starting armies are still placed directly.

### 5.4 Costs and men

| Moment | Ducats and goods | Men |
|---|---|---|
| Queue (plus) | paid: ledger and store flows `raise` | levied from the hex, then its ring; **each company remembers its source hexes** |
| Withdraw (minus) | all returned: flows `refund` | back to those hexes; to the settlement if a source hex is no longer yours |
| Queue lost | gone | back to those hexes, whoever holds them now (page's choice) |
| Ready | nothing | they are the company's men |

Everything is checked and taken at queue time, so a ready company never fails for lack of money. A queue of several
companies in one action levies once, as today, and shares the source hexes out in order. Queued men are in neither the people
nor an army.

### 5.5 The actions

**`raise {hex, kind, count, tag}`** keeps its name and arguments and now queues. First refusal wins:

1. your own settlement, not occupied;
2. a barracks ("no barracks at Asti (8, 10): companies are raised where a barracks stands");
3. the kind, and its level ("Bombards are raised in a town or larger");
4. room in the queue ("Turin (5, 9) has its queue full: 5 of 5 companies", or "room in the queue for 1 more company");
5. no siege and no enemy army on the settlement ("an enemy army stands at ...: nothing can be queued");
6. men, ducats, goods, the books' limits (today's rows).

**Room on the hex is not checked when queuing** (page's choice): it would cut the limit of 5 whenever armies stand there.
Room is checked when a company is ready.

**`withdraw {muster, tag}`** is new, through `Session.act`. Allowed for any company still queued on your unoccupied
settlement, **under siege too**. No confirm box. The stepper's minus withdraws the newest queued company of that kind; a
queue row's minus withdraws that one. Refused only if the treasury or stores cannot take the refund.

### 5.6 When the queue cannot go on

| Case | Rule |
|---|---|
| Besieged, or an enemy army on the settlement at the muster step | The queue waits: no countdown, nothing finishes, nothing new. Withdraw allowed |
| The company in training is ready and the hex holds 8 of your companies | It holds the training place until it fits or is withdrawn; those behind it **do not train** (decision 9) |
| A foreign army that is not an enemy | Nothing changes (decision 10). Today's movement rules keep such an army off your land, so the case is rare |
| Taken by force, ceded or transferred | Lost, through one function, the moment control leaves the owner, during your turn too |
| The settlement shrinks | The queue stays; level gates are checked only when queuing |

## 6. Interactions

**Economy.** Money and goods leave at queue time (up to 5 companies a barracks: 300 ducats for five batteries of bombards).
Upkeep and food start when ready. A barracks competes with other works for slots, money, timber and stone. Debt and
bankruptcy (later) must decide whether queued money counts.

**War.** A threatened town cannot make defenders on the spot. A barracks town is a target: taking it empties the queue and
stops the raising there; a ceded one serves the winner.

**Fog.** A queue is its owner's information: another country's tile shows no queue, count or footer row, and queuing and
withdrawing have no witnesses. A barracks is a building: a foreign one shows among the land facts only while the tile is in
sight (page's choice). A new army is seen like any army. A lost queue is reported to its owner only. No check or refusal of
another country may depend on your queue (a "twin" test: two games differing only in foreign queues look alike).

**Saves.**

- New state, written only by a new `Recruiting` system: `MapState.barracks` (one byte a hex), `game.musters` (one entry a
  queued company) and `next_muster_id`. An entry: `{id, tag, hex, kind, queued_turn, seasons_left, paid, paid_goods,
  levy: [[hex, men]]}`. `Work` gains the action `barracks`.
- All of it is saved, checked on load (a barracks only on a settlement; an entry only on an unoccupied settlement of its tag
  with a barracks) and covered by `Game.digest()`. The entry checks arrive with their rules (RQ7, RQ8).
- **Save FORMAT 9** (`OLDEST_FORMAT` 9, no upgrade step): the body changes and an old `raise` record would mean something
  else. No build is handed out between RQ1 and RQ11. Later specs' format numbers move up.

**Action log and replay.**

- Logged: `raise`, `withdraw`, `build_barracks` (and `cancel_work`). The computer's records replay through the same door.
- The `muster` step uses no luck; a ready company and a lost queue are consequences, not log records.
- Two developer actions, **logged and replayed** like `dev_money`: `dev_barracks {hex}` puts a barracks; `dev_muster {ids}`
  finishes queued companies now, leaving the receiving army with no move points this season (so it waits, as today). Tests,
  tools and the console use only these, so a replay gives the same game.

**Reports and statistics.**

- Events: `muster_queued`, `muster_withdrawn`, `muster_lost` (count, ducats, goods, men), all for the owner only; the
  existing `army_raised` is sent when the company is **ready**, with no cost in it. Barracks works use the work events.
- Season report and log: "1 company of pikemen ready at Turin"; "Vercelli's queue was lost: 3 companies, 75 ducats, 3 iron;
  1,500 men went home"; "Barracks finished at Asti"; a captured or ceded barracks is named with its district.
- Reminder (page's choice): "You have no barracks you can use: no company can be raised."
- Statistics, no new series: men raised counts in the season a company is ready; spending in the season it is queued;
  refunds on withdrawal; men under arms exclude queued men. The "no men appear or vanish" test counts the queue as a third
  place. The ledger forecast does not count the upkeep of queued companies in this version.

## 7. The computer countries

Same checks and actions, no shortcut. Without the two changes below its wars stall: one barracks gives one company a season.

**Building barracks** (a new AI step before the works steps, so it gets first claim on a slot and the money):

- wanted = war goal of men / (`AiDef.companies_per_barracks` 4 x 500 men), rounded up, at least 1. The war goal is used in
  peace too, so barracks stand before the war. At the start: Milan and Venice want 3, Savoy and Switzerland 2, the rest 1;
- it has: usable barracks plus barracks under way;
- with **none**, it builds as soon as it can pay (its money reserve waived); with fewer than wanted, one at a time and only
  keeping its reserve;
- where: a town or bigger that passes the check, not on the front, nearest the front first; if all are on the front, the
  farthest from the enemy.

**Using the queue:**

- it queues only at barracks whose queue is **empty** (`AiDef.queue_depth` 1): full production, no money locked ahead;
- companies queued at barracks that are not waiting count toward its goal of men, its upkeep room and its mix of kinds
  (without this it over-raises);
- places keep today's order (nearest the front first) and must pass the check; it skips a hex with 8 of its companies;
- `raises_peace` 2 and `raises_war` 4 stay, now meaning companies queued a turn;
- first version: it never withdraws, and builds no village up to a town for the sake of a barracks.

## 8. UI and tooltips

No stepper mock was found in the repository; these are the states to show. Layout follows the tile window
(`docs/architecture/tilewin-build-spec.md` R12, R21, R26, R27) in its present style. The look of unit figures and rows
comes with part 2.

**Army tab, head:** "Men to levy 6,300 · queue 2 of 5".

**No barracks** (your settlement): one stop line under the head, "No barracks here: build one in the Town tab" (a village:
"No barracks here: a barracks is built in a town or larger"), and the company rows greyed. The line opens the Town tab.

**Company row:** figure, name, age badge, "500 men · 25 ducats + 1 iron", then `[-] 1 [+]`: the companies of that kind
queued here. The stepper replaces the Raise button.

| State | Look | Tooltip |
|---|---|---|
| Plus ready | enabled | "Queue 1 company of pikemen: 25 ducats, 1 iron, 500 men. Ready Summer 1481." (the season of its turn in the queue) |
| Plus refused (money, goods, men) | greyed, red reason line | the rule's reason |
| Level too low | lock | "Bombards are raised in a town or larger" |
| No barracks, queue full, siege or enemy army | all plus greyed, reason said once under the head | "Queue full: 5 of 5. Withdraw one to change it." |
| Minus ready | enabled | "Withdraw 1 company of pikemen: +25 ducats, +1 iron, 500 men go home." |
| None of the kind queued | minus greyed, count 0 | "None queued" |

**Queue list**, under the rows, heading "Queued": at most 5 one-line rows in training order, each with figure, name, state
and minus. States: "in training: ready Summer 1481"; "queued: ready Autumn 1481"; "waiting: under siege"; "waiting: an enemy
army is here"; "waiting: no room (8 of 8)" with the rows behind it "waiting its turn". Waiting uses the bad tone. The row
tooltip lists what withdrawing returns. Empty: no heading. The window has no scroll bar, so 4 kinds and 5 queue rows must
fit its smallest size; the placeholder boxes hide first.

**Footer:** the work row stays. Below it, one recruit row for **the company in training only** (decision 8): its small figure
and "ready Summer 1481" or "waiting: ...". A click opens the Army tab. The idle line shows only with neither a work nor a
company.

**Town tab, Settlement strip:** a Barracks tile like the other building tiles.

| State | Words |
|---|---|
| built | "working · upkeep 1" |
| building | "building · 1 of 4 seasons" |
| can build | "cost 150 · 10 loads of timber · 10 loads of stone · upkeep 1" |
| short | "cost 150 · you have 120", or the goods reason |
| locked (village or hamlet) | "needs a town" |
| refused | occupied, siege, no free work slot, one job at a time |

Hover card: "Companies are raised here: up to 5 queued, one ready a season." It has no yearly gain. A built barracks on a
village reads "working". Foreign tile in sight: "Barracks" among the buildings in the land facts. The icon is the art
director's (a stand-in until approved).

**Elsewhere:** the Raise companies window uses the same stepper and head. The company card gains "Ready: Summer 1481" and
"Upkeep starts when ready". On your other land the dimmed Army tab reads "Companies are
raised at a barracks" in place of "Raising needs a village or larger". Toasts: "Queued ... ready Summer 1481.",
"Withdrawn: ...", "Barracks begun at ...". Developer console: `barracks c r` and `muster`. Plus and minus work from the
keyboard.

## 9. Risks and seams

- **Much slower raising** (section 3). Armies may stay small, a lost battle is hard to recover from, and large realms gain
  only if they spend on barracks. Soak and playtest: men under arms, leader against the median, captures a war, seasons to
  reach the war goal.
- **No emergency defence.** Walls and garrisons matter more; the attacker gains.
- **One barracks is one point of failure.** Mantua, Siena, Lucca, France and the Papal States cannot build a second while
  it is occupied. Count the seasons countries spend unable to raise.
- **A captured barracks helps the winner** (question 4). Watch the snowball.
- **Barracks towns drain** their own people first; a capital town may fall a level. Measure it.
- **Small states** are weakest: Lucca has men for 2 companies, and a second barracks is out of reach.
- **Money parked** in queues is lost with the town. A long queue near the front is a real gamble, and meant to be.
- **Stuck queues** under long sieges: visible and withdrawable. The computer never withdraws; count what is stuck.
- **A crowded window** (section 8).
- **Cost of change:** many tests raise at settlements with no barracks.

**Seams.** *Arms (M9.5, `economy-build-spec.md` R45 to R49):* arms are needed to queue; stored arms and the shortfall bought
are taken then, the entry records both apart, withdrawing undoes the exact transaction, a lost queue loses both. M10's
market must undo its stock change the same way. *M9.5 workshops:* the barracks uses no workshop slot (page's choice); its
work follows "one job a settlement". *Later:* drill (M11, M12), barracks levels, faster training, other modifiers of the
queue. M11's plan reuses `mustering` for refits; it brings its own once this removes it.

## 10. Smallest first version

Decisions 1 to 15, sections 4 to 8, in one release.
Left out: barracks levels and drill, different times per kind, reordering the queue, pulling a barracks down, computer
withdrawals, a barracks picture on the map.

## 11. Part 2: unit looks and selection (issue 433)

### 11.1 Scope

**In:** unit art; unit cards and rows; picking units on the map apart from their tile.
**Out:** new unit kinds, combat and balance numbers, army organisation (splitting, joining, stack size).

This page does **not** design the art or the selection behaviour. An art director is preparing mockup options; every such
point is **from the approved mockup**.

### 11.2 Already built

From the code and `tests/shell/test_unit_select.gd`:

- A click on one of your tokens selects the army, not the hex under it; a click on the hex selects the hex.
- One token a country on a hex. Each further click on a stack takes its next army; the ring follows the selected army.
- The click area is the plate and badge and follows the zoom. Foreign tokens are never selected (the click picks the hex),
  and unseen armies cannot be hit. Unit clicks are refused while moves replay.
- Tab goes to the next army; the Army tab lists your armies on the hex with a Select button.
- **Open:** the fan picker.

### 11.3 Points waiting for a mockup

| Point | Where | Content |
|---|---|---|
| Figures of the four kinds | `tools/ui_bake/pieces_m6.py` (32 px cells), the theme | from the approved mockup |
| Map token: plate, figure, strength, stack, selected state | `shell/map/army_token.gd`, `army_tokens.gd` | from the approved mockup |
| Picking among stacked armies (the fan picker or another way) | `shell/map/map_armies.gd`, `army_tokens.gd`, `shell/input/map_input.gd` | from the approved mockup |
| Unit cards and company rows | `shell/ui/company_row.gd`, `shell/panels/army_panel.gd`, `core/views/company_card.gd` | from the approved mockup |

Whatever is approved must keep: fog (nothing unseen can be picked), a keyboard path, the colour-blind country colours, all
zoom levels, and no orders during a replay.

### 11.4 Where it touches the recruitment screens

The company rows of the Army tab and of the Raise companies window, the 5 queue rows, the footer's recruit row, the company
hover card, the army panel's company rows, and the token of a newly ready army. The queue is built with today's figures and
rows; part 2 restyles them afterwards. The battle screens read the same figures: whether they change is from the approved
mockup. The queue's states and words (section 8) stay.

## 12. Build tasks

Paths are under `godot/` unless they start with `tools/ui_bake`. Every task leaves the game playable and the tests green.
`military.gd` is near the 800-line mark, so the queue gets its own files.

**RQ0 is done** (on master): `ArmyFixture.raise_now` and `AppFlowHelpers.console_raise`. What it found is placed so:

| Finding | Handled in |
|---|---|
| `test_war_savoy` and `test_march_via` raise through the helper: finishing a company outside the action log would make replays differ | RQ6 and RQ8: the helper uses only the logged `raise`, `dev_muster` and `dev_barracks` (added in RQ1) |
| March stories order a march in the raising season; they change when mustering goes | RQ6: `dev_muster` leaves the army with no points, so the order is stored and walks as today. RQ9 updates the words and previews |
| The live-against-loaded witnesses test in `test_army_season` would pass empty with only a queued company | RQ6: it finishes the company first and asserts an army exists |
| A new name in `Actions.NAMES` shifts the random stream of `RandomPlayer` tests and `war_report` | RQ2: `RandomPlayer` picks from a fixed list of today's names; tests that want the new actions ask for them |
| `shot_ui_m6`, `perf_ui_m6` and `army_report` depend on instant raising | RQ6 (the two UI tools), RQ9 (`army_report`) |

### 12.1 The queue (one release, decision 12)

| Task | Size | What | Main files | Key tests |
|---|---|---|---|---|
| RQ1 | S | Barracks data and state, start placement, `dev_barracks`, FORMAT 9. No rule reads it yet | `core/state/map_state.gd`, new building def and `data/defs/buildings/barracks.tres`, `core/defs/{game_defs,scenario_def}.gd`, `data/scenarios/`, new `core/systems/recruiting.gd`, `core/game/{game,replay,snapshot,save_file}.gd` | 13 barracks at the hexes of section 3; save, load, save byte-equal; damaged body refused; replay equal |
| RQ2 | M | Building a barracks: action, work, checks, capture and cession, upkeep (economy pins updated); fixed list in `RandomPlayer` | `core/systems/{works,recruiting,economy_season}.gd`, `core/state/work.gd`, `core/game/actions.gd`, `core/views/works_view.gd` | each check row; village refused; halt, cancel refund, lost on cession; barracks survives capture and passes on cession; old random streams unchanged |
| RQ3 | S/M | Town tab tile, hover card, work words and marks, foreign land facts | `core/views/{tile_buildings,building_card,tile_view,log_lines}.gd`, `shell/panels/tile_tabs/building_strips.gd`, `shell/map/work_marks.gd` | each row state; no gain figure; foreign tile only in sight |
| RQ4 | S/M | The computer builds barracks | `core/ai/{ai_turn,ai_know}.gd`, a new AI step file, `core/defs/ai_def.gd`, `data/defs/ai.tres` | wanted number per country; none: reserve waived; place choice; slot respected |
| RQ5 | S | The muster entry: state, save, digest, load checks. No rule yet | new `core/state/muster.gd`, `core/game/{game,snapshot}.gd` | round trip; each planted fault refused |
| RQ6 | M | `raise` queues (limit 5 replaces the season cap; until RQ8 at any settlement), `withdraw`, `muster` step with all the waiting rules, `dev_muster`, men and refunds; computer counts and uses the queue; helpers and UI tools; minimal toast | `core/systems/{recruiting,military}.gd`, `core/game/{actions,season,replay}.gd`, `core/ai/{ai_forces,ai_know}.gd`, `core/views/{tile_army,company_card}.gd`, `shell/hud/dev_commands.gd`, `tests/core/army_fixture.gd`, `tests/shell/app_flow_helpers.gd`, `tools/ui/{shot_ui_m6,perf_ui_m6,shot_ui_tile}.gd` | queue then withdraw restores money, goods and people; ready exactly one season later and able to march; never two a settlement a season; 6th refused; waits for siege, enemy, occupation and no room, blocking those behind; non-enemy changes nothing; computer within goal and depth; replay equal |
| RQ7 | S | Loss of the queue: capture, cession, transfer; the load check refuses an entry on land its tag does not hold unoccupied | `core/systems/{recruiting,occupation,wars}.gd`, `core/game/game.gd` | each way of losing it (storm, siege, walk-in, peace, transfer); men return; save and load after each |
| RQ8 | S | **The requirement:** `raise` needs a barracks, and so does a saved entry; helper and fixtures give one | `core/systems/military.gd`, `core/ai/ai_forces.gd`, `core/views/tile_view.gd`, `tests/core/{army_fixture,random_player}.gd`, tests that act `raise` | refused without; occupied only barracks: none raised; rebuilt barracks raises; every country raises at the start |
| RQ9 | M | Remove mustering, the disband refund and `raise_cap` | `core/state/army.gd`, `core/systems/{movement,movement_phase,walk_now,military}.gd`, `core/defs/family_def.gd`, `data/defs/families/settlements.tres`, `core/views/{move_preview,move_words,army_view,summary_armies,reminders,company_card}.gd`, `shell/map/{army_token,army_tokens,move_orders}.gd`, `shell/panels/army_panel.gd`, `tools/{army_report.gd,probes/probe_movement.gd}` | a new company marches at once; disband returns men only and asks; report shows barracks |
| RQ10 | M | Events, log, season report, reminder, statistics, notices | `core/views/{log_lines,season_summary,summary_doings,summary_armies,reminders}.gd`, `core/state/chronicle.gd`, `shell/autoload/{events,session}.gd`, `shell/hud/{notifications,chips,task_flag}.gd` | each line; cost shown at queuing only; foreign queues invisible (twin test); stats rules |
| RQ11 | M | Stepper, queue list, footer row, no-barracks line, Raise window, tooltips, toasts, player docs | `shell/ui/company_row.gd`, `shell/panels/tile_tabs/army_tab.gd`, `shell/screens/raise_screen.gd`, `shell/panels/{tile_window.gd,tile_tabs/job_line.gd}`, `core/views/tile_army.gd`, `README.md` | every state of section 8; keyboard; fit at the smallest window; monkey |
| RQ12 | S | Soak and ranges, perf, pictures, owner playtest | `tools/soak.gd`, `tools/ui/shot_ui_tile.gd` | the measures of section 9; the soak reports the seasons each country cannot raise |

### 12.2 Unit looks and selection

Each task **starts only when the owner has approved its mockup**. They come after the queue tasks they share files with; the
queue tasks never wait for them (whether the release does: question 6).

| Task | Size | What | After | Main files | Key tests |
|---|---|---|---|---|---|
| UR1 | S/M | Unit figures | art mockup; independent of the queue | `tools/ui_bake/pieces_m6.py`, UI kit assets, `tools/build_theme.gd` | baked files match; theme has each figure; owner sees pictures |
| UR2 | S/M | Map token look | token mockup; UR1, RQ9 | `shell/map/{army_token,army_tokens}.gd`, `core/views/army_view.gd` | token tests; contrast, colour-blind colours, zoom |
| UR3 | M | Picking units on the map | selection mockup; RQ9, UR2 | `shell/map/{map_armies,army_tokens}.gd`, `shell/input/map_input.gd` | `test_unit_select` extended to the approved behaviour; fog, keyboard, replay |
| UR4 | M | Unit cards and rows, queue and footer figures | card mockup; UR1, RQ11 | `shell/ui/company_row.gd`, `shell/panels/army_panel.gd`, `shell/panels/tile_tabs/army_tab.gd`, `shell/screens/raise_screen.gd`, `core/views/company_card.gd` | panel, tab and window tests; fit |
| UR5 | S | Pictures, perf, owner playtest | all | `tools/ui/{shot_unit_select,shot_ui_tile,perf_ui_m6}.gd` | before and after pictures |

**Earlier pages this amends:** `m3-build-spec.md` (a new work), `m6-build-spec.md` (raising and refund),
`m8-build-spec.md` (computer raising), `moves-build-spec.md` (R15, R16, R20), `tilewin-build-spec.md` (R12, R21, R22, R26,
R27), `economy-build-spec.md` (R46, R49), `m11-build-plan.md` (mustering) and the save format numbers of later specs.

## 13. Questions for the owner

Questions 1 to 3 (the village capitals, the capitals off the map, the cost) were answered on 2026-11-28: decisions 17,
18 and 20, with the training speed confirmed in decision 19. For the rest the build takes the recommendation unless you
say otherwise.

4. **Does a barracks survive being captured?** (a) Yes: it stands, the new owner of ceded land gets it, and it also keeps
   working if the town shrinks. (b) Capture destroys it; then your own capital must be allowed to rebuild one even as a
   village, or Siena and Lucca can be left without units for good. **Recommend (a).**
5. **Does building a barracks take a work slot, like other buildings?** (a) Yes: you choose between a barracks and another
   work. (b) No, it is built beside them. **Recommend (a).**
6. **If the unit mockups are not approved in time, may the queue and barracks be released without the new unit looks?**
   (a) Yes, the looks follow in the next release. (b) No, they ship together. **Recommend (a).**
