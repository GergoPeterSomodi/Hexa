# Age of Discovery: tech tree design (approved 2026-11-11, not built yet)

The user approved this design. Mockups:
- [14_tech_tree_c.png](../design/images/14_tech_tree_c.png): the tech screen, as approved
- [14_tech_tree_d_new_age.png](../design/images/14_tech_tree_d_new_age.png): the idea-card pick when a new era opens
- `14_tech_tree_a.png` and `14_tech_tree_b.png`: earlier concepts. A was chosen. B (one connected web) and C (era bar plus idea cards) were not, but C's cards were kept.

## Decisions
- **Layout:** four branches (rows) × three eras (columns). The branches are Military, Trade & Industry, Navigation and Statecraft. Some prerequisites cross branches; they are drawn as dashed lines.
- **One research at a time,** plus a queue. Clicking a far tech queues its whole path; right-click removes it from the queue.
- **Troops stay tied to eras, as they are now.** Reaching an era unlocks that era's three troops for everyone, and refits work as today. Military techs do NOT unlock troop types. They give tactics, siege, castles, supply and stack size.
- **Era gate:** era II opens in 1520 or later, once the country knows 4 era I techs. Era III works the same way: 1575, plus 4 era II techs. This replaces `ERAS` research costs and the single research bar.
  - Era II still opens tile levels 3-4 and era III opens level 5, as agreed for province investment.
- **Idea cards:** when a country enters era II and era III, it picks 1 of 3 cards, so a game has 2 ideas.
  - One card is always the nation's own.
  - The other two are drawn from the general deck, weighted toward the branch the country has researched most.
  - Cards are permanent bonuses that do not appear in the tree.
- **National tech:** each country starts with one national tech already known. It is drawn with a gold PORTUGAL-style tag, for example Portugal's Sagres school.

## Research points (RP)
Today: `RESEARCH_BASE` 0.6 + burghers/40, and `RESEARCH_FUND` turns 60 ducats into 15 points.
- **Keep** the base, burghers/40 and ducat funding.
- **Universities:** a new building, cities only, unlocked by the Universities tech. +1 RP each.
- **Coffee houses** (era III tech): burghers who get coffee add +25% to their research.
- **Printing press:** +15% to all research.
- **Diffusion:** a tech is 10% cheaper if a country you share a market with already knows it. The cap is 30%.
- **Target pace:**
  - a mid-sized country makes 2-6 RP per season
  - a tech every 3-10 years
  - about 70% of the tree by 1650
- **Costs (tune in play):** era I 35-45, era II 90-110, era III 170-200.

## The techs
For each tech: name, branch and era, what it gives, and its prerequisites (→). Every country starts with its national tech already known. Starting with others (for example Portolan charts for coastal countries) is optional.

### Military
| Era | Tech | Effect | Needs |
|---|---|---|---|
| I | Drill yards | +1 drill level at barracks (`UPGRADE_MAX` 2→3 for the attack/defense drill) | – |
| I | Supply trains | Wagons last 6 seasons (`WAGON_SEASONS` 4→6) | – |
| I | Siege craft | Cannons +1 siege | – |
| II | Tercio | Infantry +25% vs cavalry (on top of `PIKES_VS_HORSE`) | Drill yards |
| II | Standing army | Stack limit 6→7 | – |
| II | Bronze guns | Cannons +1 attack; cannons also need copper | Siege craft, *Corned powder* |
| II | Trace italienne | Allows the large castle (castle level 3), which needs stone | – |
| III | Volley fire | Infantry +1 attack | Tercio |
| III | Star forts | Castles +2 garrison defense, +2 siege points to take | Trace italienne |
| III | Magazines | Supply range +2, depots feed +2 troops | Supply trains |
| III | Military revolution | Stack limit 7→8, a general adds +1 more | Standing army |

`STACK_LIMIT` by era becomes base 6 + techs. The total is still 6/7/8.

### Trade & Industry
| Era | Tech | Effect | Needs |
|---|---|---|---|
| I | Guilds | Manufactories (weaver, toolmaker, armoury) can reach level 3; otherwise they stop at 2 | – |
| I | Double-entry books | +1 merchant | – |
| I | Crop rotation | Farm goods tiles +10% output per investment level | – |
| II | Ropewalk | Ropewalk building: hemp → rope | Guilds |
| II | Banking | Burgher tax +20%; loans | Double-entry books |
| II | Corned powder | Powder mill | Guilds |
| II | Glass & leather | Glassworks (sand/stone → glass) and tannery (cattle → leather) | – |
| III | Joint-stock company | +2 merchants; colonial trade routes cost less | Banking, *Colonial charters* |
| III | Bourse | Market reach +30%; prices swing less | Banking |
| III | Coffee houses | Coffee in burgher needs; +25% research from burghers who have it | Glass & leather, *Universities* |

### Navigation
| Era | Tech | Effect | Needs |
|---|---|---|---|
| I | Portolan charts | Sea routes +25% range (`SEA_ROUTE_RANGE`) | – |
| I | Carrack | Carracks (shipyard), which today are always available | – |
| I | Astrolabe | Atlantic crossing: `ATLANTIC_RANGE` routes, plus colonists can land across the ocean | – |
| II | Ocean pilots | Colony range +50%; ships +1 sight | Portolan charts, Astrolabe |
| II | Plantations | Spice plantations; sugar, tobacco and cotton plantation levels | – |
| II | Cartography | See every coast you trade with | – |
| III | Galleon | Galleons (rope, iron, timber) | Carrack, *Ropewalk* |
| III | Mercator charts | Ships +1 move | Cartography |
| III | Overseas factories | Trading posts +50% share (`TRADING_POST_SHARE`) | Ocean pilots |

The caravel is known from the start.

### Statecraft
| Era | Tech | Effect | Needs |
|---|---|---|---|
| I | Tax rolls | Production tax +2% (`PRODUCTION_TAX`) | – |
| I | Printing press | Research +15% | – |
| II | Universities | University building (cities): +1 RP | Printing press |
| II | Colonial charters | Colony upkeep −50%; colony growth +20% | – |
| II | Royal bureaucracy | High tax hurts growth half as much | Tax rolls |
| III | Absolutism | Manpower +25%; "high" tax +0.1 | Royal bureaucracy |
| III | Mercantilism | Tolls ×2 on your own markets (`TOLL_SHARE`) | – |

Uses for the new goods agreed elsewhere:

| Good | Use |
|---|---|
| horses | cavalry raise cost (all eras) |
| copper | Bronze guns |
| stone | castles and Trace italienne |
| hemp | Ropewalk → rope → galleons and cheaper carracks |
| cattle | tannery → leather |
| coffee and cocoa | burgher needs, plus Coffee houses |
| silk and dyes | luxury cloth (handled by the economy session) |

## Battle cards from techs (added 2026-11-11 at the battle session's request)
The battle system is approved (`docs/design/battle.md`, Rounds 3-4, mockups 14-16). Each researched tech adds 1-2 cards to a random battle deck.
- **On the tech screen:** each node shows small card chips (one per card) at its bottom right. The side card has a "Battle cards" section with the full cards. See `14_tech_tree_e_cards.png`.
- **Every deck** starts with 5 era I cards: Pike hedge, Knightly charge, Rally the banner, Forced march and Sharpened stakes.
- **Card list (approved by the user 2026-11-11; fine-tune numbers with the battle session):**

| Tech | Cards |
|---|---|
| Drill yards | Pike square, Change of front |
| Supply trains | Wagon fort, Loot the baggage |
| Siege craft | Grand battery, Mine the walls |
| Tercio | Pike and shot, Dig in |
| Standing army | Pistol ride, Call the ban |
| Bronze guns | Great bombard, Guns gallop up |
| Trace italienne | Counter-mine, Sally out |
| Volley fire | Rolling volley, Countermarch |
| Star forts | Burn the fields |
| Magazines | Night attack, Campfires burning |
| Military revolution | Platoon fire; also +1 command point per day (this is the "Staff college" from the battle notes) |
| Corned powder | Through the wall, Smoke screen |
| Tax rolls | Turncoats |
| Printing press | Feigned retreat (drill manuals) |
| Absolutism | Hold the line |
| Carrack | By river and sea |
| Ocean pilots | Know the land |
| Cartography | Catch them crossing |
| Colonial charters | Native allies, Guns and horses |

- **From general traits and ranks** (not from techs):

| Source | Card |
|---|---|
| Ranger general | Ambush in the woods |
| Cavalier general | Lure the horse |
| Defender general | Dig trenches |
| Siege master general | The open gate |
| Field marshal general | Lead from the front |
| Elite regiment | Veterans' resolve |

- **Trade techs** add no cards; they pay off on the economy side.

## National techs (draft; the remaining countries use a regional default)
| Country | Tech | Effect |
|---|---|---|
| Portugal | Sagres school | Navigation techs −25% |
| Castile | Tercios viejos | Infantry +10% |
| Venice | Banco di Rialto | Banking known; tolls +25% |
| Genoa | Casa di San Giorgio | Funding gives +25% |
| France | Gendarmerie | Cavalry +10% |
| England | Wool staple | Wool +20% |
| Ottomans | Janissary corps | Stack +1 |
| Hansa / Lübeck | Kontor | +1 merchant |
| Austria | Habsburg marriages | Diffusion cap 50% |
| Burgundy / Netherlands | Polders | Farm investment −25% |
| Muscovy | Streltsy | Manpower +25% |
| Poland | Hussars | Cavalry +1 attack |

Regional defaults:

| Region | Tech |
|---|---|
| Italian states | Studia humanitatis: research +10% |
| German states | Mining law: mines +10% |
| North African states | Corsairs: ships +1 attack |

## Idea cards (draft deck; 2 picks per game)
- **National:** each country has 1-2 cards of its own, e.g. Portugal's Casa da Índia (spice routes +50% profit, trading posts +1 level).
- **General:**

| Card | Effect |
|---|---|
| Condottieri | cavalry −25% ducats, +1 stack for armies with a general |
| Fuggers' credit | funding +25%, treasury may go to −200 |
| Humanism | research +10% |
| Corsair letters | ships raid enemy routes |
| Reformed church | burgher growth +20% |
| Royal mint | silver and gold +15% value |
| Engineers | castles −25% cost |
| Navigators' guild | ships +1 sight |

There are about 12-16 cards in all, each tagged with a branch so the draw can lean toward one.

## AI
- **Choosing research:** when its research finishes, the AI scores each available tech. The score is a base value plus its situation:
  - **at war or a neighbour is stronger:** Military ×2
  - **coastal, with colonies or a colonial plan:** Navigation ×1.5
  - **treasury below a year of upkeep:** Trade ×1.5
  - **close to an era gate:** era-gate techs ×1.5
  - **personality** (warlike / mercantile / colonial, from the country's data): ×1.25
  - a small random factor so AIs differ

  It takes the best score. No queue is needed.
- **Funding:** it funds research when its treasury is above 2 years of upkeep and it is not at war.
- **Idea cards:** it takes its national card unless another card scores higher by the same weights.

## Screen (as in the mockup)
- **Opening it:** a T hotkey, plus a button in the country panel. The raise panel keeps a one-line era/research summary that links to the screen.
- **Top bar:** research per season split by source, the Fund research button and Close.
- **Strip:** the current research with its progress and seasons left, and the queue.
- **Grid:**
  - era headers show the year reached or the gate condition, plus that era's troops
  - each node shows an icon tile, name, one-line effect and cost
  - node states: known (green + check), researching (gold + progress), available (grey border), missing a prerequisite (dim + red "needs …"), later era (faint)
- **Side card (selected tech):** what it unlocks, its prerequisites, what it leads to, and which known countries already have it.
- **New-age modal:** what the era unlocks, plus the 1-of-3 card pick.

## Code impact (for the implementing session)
- **`data.py`:**
  - add `Tech`, `TECHS`, `NATIONAL_TECHS` and `IDEAS`
  - `ERAS` keeps its names and years and drops the costs; add `ERA_GATE_TECHS = 4`
  - `STACK_LIMIT` becomes a base value plus tech bonuses
- **`world.py`:**
  - `Country` gets `techs: set`, `researching`, `queue` and `ideas`
  - `_research` adds RP to the current tech and checks the era gate (year + techs)
  - `fund_research` keeps working, with no cap at era 3
  - effects are read through small helpers (`has(tag, "tech")`, `bonus(tag, "stack")`) instead of spreading constants around
  - save compatibility: old saves get techs implied by their era
- **`app.py`:** the new tech screen and the new-age modal; slim down the raise panel's research block.
- **`ai.py`:** tech choice, funding, idea picks.
- **Coordinate with:**
  - province investment: level gates by era
  - new goods / buildings: ropewalk, powder mill, glassworks, tannery and University are unlocked by techs here
  - battle design: tactics bonuses
