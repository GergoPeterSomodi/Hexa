# Tech tree: build spec for the workers

This turns the approved design (`docs/design/tech-tree.md`) into code. The design describes what the player sees and the numbers. This spec says how to build it. If they disagree, follow this spec.

**Paths:**
- repo: `Hexa/`
- campaign code: `Hexa/hexa/campaign/`
- Python: the project virtual environment, run from `Hexa/`

## Module layout
| File | Owner (task) | Contents |
|---|---|---|
| `hexa/campaign/tech.py` (NEW) | T1 | Pure data and logic, with no pygame and no import of `world.py`. Holds the techs, national techs, idea cards, effect sums, research costs and the era gate. |
| `hexa/campaign/world.py` + `data.py` | T2 | Country state, research each season, and every effect hook below. |
| `hexa/campaign/ai.py` | T3 | AI picks research and ideas, and funds research. |
| `hexa/campaign/techscreen.py` (NEW) + small hooks in `app.py` | T4 | The tech screen and the new-age card pick. |
| `tests/test_tech.py` (NEW) | T1 | Tests of `tech.py` on its own. |
| `tests/test_tech_world.py` (NEW) | T2 | Tests of the effects in the world. |

## tech.py: data
```python
@dataclass(frozen=True)
class Tech:
    key: str          # "drill_yards"
    name: str         # "Drill yards"
    branch: str       # "military" | "trade" | "navigation" | "statecraft"
    era: int          # 1..3
    cost: int         # research points
    needs: tuple = () # tech keys
    effects: dict     # effect key -> number (see "Effect keys"); unlock flags are 1
    text: str = ""    # one-line effect for the screen, e.g. "+1 drill level at barracks"
    flavour: str = "" # one sentence for the side card
    cards: tuple = () # battle card names from the design (shown only; the battle system comes later)
    icon: str = ""    # a short icon key the screen draws, e.g. "drill", "wagon", "cannon", "ship", "coin", "book", "crown"...
    national: str = "" # country tag for a national tech, else ""

@dataclass(frozen=True)
class Idea:
    key: str; name: str; branch: str; effects: dict; text: str; nation: str = ""   # nation tag for national cards
```
- `TECHS`: dict key → Tech, holding all 38 tree techs from the design tables, with costs:
  - era I: 35-45 (Printing press 45)
  - era II: 90-110
  - era III: 170-200
  - Use the costs shown in [14_tech_tree_c.png](../design/images/14_tech_tree_c.png) where it shows them.
- `BRANCHES = ("military", "trade", "navigation", "statecraft")` and `BRANCH_NAMES`.
- `NATIONAL_TECHS`: tag → Tech, for the 12 countries in the design.
  - Each is era 1, already known at the start, and not part of the grid's 38.
  - The screen draws it in its branch's era I row, with a gold tag.
  - Plus `REGIONAL_TECHS`:
    - `italian` (Studia humanitatis: research +0.10)
    - `german` (Mining law: mines +0.10)
    - `north_african` (Corsairs: ship_sight +1; ships don't fight)
    - `default` (Local levies: manpower +0.10)
  - `national_tech(tag, region)` returns the right one. The world passes `region`, worked out from the capital's lon/lat.
- `IDEAS`: about 14 general cards (the design's 8 plus about 6 more of your own, using only implemented effect keys), each with a branch, plus `NATIONAL_IDEAS`, tag → list of 1-2 Ideas, for the 12 named countries.
  - Write effects only with the keys below.
  - Drop effects that need systems we don't have, such as "ships raid enemy routes" or "treasury may go to -200". Replace them with an implemented key and a matching text.

## Effect keys
`effects(country_techs, country_ideas, national_key)` returns `{key: summed number}` over the known techs, the ideas and the national tech. Missing keys count as 0.

Unlock flags (value 1):
- `guilds`, `ropewalk`, `powder_mill`, `glass_leather`, `university`
- `carrack`, `atlantic`, `plantations`, `cartography`, `galleon`, `trace_italienne`

Numbers:

| key | meaning | where T2 hooks it |
|---|---|---|
| `stack` | +stack limit | `stack_limit`: 6 + stack (+ `GENERAL_STACK` + `general_stack` with a general) |
| `general_stack` | extra slots from a general | same |
| `upgrade_max` | +drill levels | `upgrade_check`: `UPGRADE_MAX` + upgrade_max |
| `wagon_seasons` | +wagon seasons | wherever `WAGON_SEASONS` is assigned (recruit, refill) |
| `siege` | +siege points from cannons | `sieges()`: unit siege + bonus for the besieger's cannons |
| `vs_horse` | infantry multiplier vs cavalry | `_defense_value` / `_attack_value`: `PIKES_VS_HORSE` * (1 + vs_horse) |
| `infantry_attack`, `artillery_attack`, `cavalry_attack` | +attack | `_attack_value` by branch |
| `infantry`, `cavalry` | multiplier (e.g. 0.10 = +10%) | `_attack_value` and `_defense_value` by branch |
| `castle_max` | castle levels beyond 2 | `build_check` for castle: max level = 2 + castle_max (the base is 2 small castle; Trace italienne makes 3 possible) |
| `garrison_defense`, `siege_points` | castle strength | Garrison defense +; `sieges` need + siege_points per castle level of the defender |
| `supply_range`, `depot_supply` | supply | `in_supply` range = `SUPPLY_RANGE` + supply_range * SCALE; `supply_limit` + depot_supply in depot provinces |
| `manufactory_max` | Guilds | `build_check`: manufactories (`MANUFACTORIES`) max level 2 + manufactory_max (max 3) |
| `merchants` | +merchants | `merchants(tag)` |
| `farm_works` | per investment level, extra for `FARM_GOODS` | economy output: `WORKS_BONUS` + farm_works for farm goods |
| `mines` | output multiplier for iron/silver/gold/salt/copper | economy output |
| `wool` | output multiplier for wool | economy output |
| `burgher_tax` | +multiplier on the burgher part of pop tax | `_incomes` |
| `production_tax` | + added to `PRODUCTION_TAX` | `_incomes` |
| `high_tax` | + added to the high tax rate | `_incomes` (only when `tax == "high"`) |
| `tax_relief` | 0.5 = the high-tax growth penalty is halved | `grow` |
| `tolls` | + multiplier on toll income | `_incomes` (`TOLL_SHARE` * (1 + tolls)) |
| `colonial_route_cost` | (negative) multiplier on route cost when a colonial market is involved and its owner has it | `Route.cost` users: apply in `_trade` / `merchant_options` via a world helper `route_cost(route)` |
| `market_reach` | multiplier on `MARKET_REACH` for markets centred in that country | `_rebuild_markets` |
| `sea_range` | multiplier on `SEA_ROUTE_RANGE` if either market owner has it | `_build_routes` |
| `atlantic` (flag) | `ATLANTIC_RANGE` routes need a market owner with it; New World founding (`found_check`, land not in the old world) needs it | `_build_routes`, `found_check` |
| `colony_upkeep` | (negative) multiplier on `COLONY_UPKEEP` | `_incomes` |
| `colony_growth` | multiplier on `COLONY_GROWTH` | `grow` |
| `ship_sight`, `ship_moves` | added to naval units' sight and moves (moves * SCALE) | `see_from` / `update_visibility` / `start_units` (moves reset) |
| `trading_post_share` | multiplier | `Province.workers` uses `TRADING_POST_SHARE`; easiest is a world-level helper used in the economy |
| `manpower` | men per troop / (1 + manpower) | `recruit_check` / `recruit` |
| `research` | multiplier on all RP | research each season |
| `fund` | multiplier on funded RP | `fund_research` |
| `nav_cost` | (negative) multiplier on navigation tech cost | `tech.cost()` |
| `diffusion_cap` | + added to the 0.30 cap | `tech.cost()` |
| `farm_invest` | (negative) multiplier on investment cost for farm goods | `invest_cost` |
| `castle_cost` | (negative) multiplier on castle build cost | `build_cost` |
| `cavalry_cost` | (negative) multiplier on cavalry gold cost | `unit_cost` |
| `money_value` | multiplier on silver/gold production value | `_incomes` production value |
| `burgher_growth` | multiplier on burgher growth | `grow` |
| `coffee_research` | flag: burghers with coffee give +25% of their RP | research each season |

Unlock hooks (T2):
- **Ropewalk, powder mill, glassworks, tannery and University:** `build_check` refuses them without the matching flag (`ropewalk`, `powder_mill`, `glass_leather` for both glassworks and tannery, `university`). Existing buildings stay.
- **Carrack:** recruiting one needs the flag.
- **Galleon:** a new `UnitKind` `GALLEON`: "Galleon", moves 9*SCALE, sight 3*SCALE, naval, capacity 10, gold 90, goods `{"timber": 14, "rope": 6, "iron": 4}`, upkeep 1.0. It needs a shipyard and the flag. Add it to `UNIT_KINDS` and `raise_options`.
- **Plantations:** investment levels 3+ for sugar, tobacco, cotton and spices need the flag (`invest_check`).
- **Trace italienne:** see `castle_max`.
- **Cartography:** when it is learned, explore every coastal province and sea hex next to the centre of each market the country has a route with.
- **University:** a new `Building("university", "University", 300, 1, 0.5, "Scholars: +1 research a season", needs_burghers=3)`. Cities only (`settlement` 3). Not a manufactory. +1 RP.

## tech.py: logic
Pure functions over plain values. The world calls them.
```python
def available(known: set, era: int) -> list[str]        # not known, prerequisites known, era <= current era
def path_to(key, known: set) -> list[str]               # unknown prerequisites first, then key (for the queue)
def cost(key, known_by_neighbours: int, bonuses: dict) -> int
    # base cost * (1 - min(0.30 + diffusion_cap, 0.10 * known_by_neighbours)) * (1 + nav_cost if navigation)
def era_ready(era: int, year: int, known: set) -> bool  # can step from `era` to era + 1: year >= ERA_YEARS[era + 1]
                                                        # and >= ERA_GATE_TECHS (4) known techs of era `era`
def draw_ideas(tag, branch_counts: dict, taken: set, rng) -> list[Idea]   # 3 cards: the nation's own (if any, not
    # taken) + 2 general, weighted toward the branch with the most known techs (weight 3 vs 1); no duplicates
def effects(techs: set, ideas: set, national: str) -> dict
def research_points(base, burghers, universities, coffee_share, bonuses) -> float
    # (base + burghers / 40 + universities + coffee_share * burghers / 40 * 0.25 * coffee_research) * (1 + research)
```
- `ERA_YEARS = {2: 1520, 3: 1575}` and `ERA_GATE_TECHS = 4`.

## Country state (T2)
New fields on `Country`, with defaults so old saves migrate:
- `techs: set` (empty)
- `researching: str = ""`
- `queue: list` (empty)
- `ideas: set` (empty)
- `national: str = ""`
- `pending_ideas: list` (empty), the 3 Idea keys offered and waiting for a pick
- `research` (the existing field) becomes progress on the current tech

World API:

| Method | What it does |
|---|---|
| `has(tag, flag) -> bool` | |
| `bonus(tag, key) -> float` | cached per country; the cache is cleared when techs or ideas change |
| `research_rate(tag) -> (total, parts dict)` | parts are `{"base", "burghers", "universities", "coffee", "funding"}` for the screen |
| `tech_cost(tag, key)` | applies diffusion: the number of countries sharing a market with you (owning provinces in markets your provinces use) that know it |
| `set_research(tag, key)` | starts researching the key, or queues `path_to(key)` |
| `unqueue(tag, key)` | removes it from the queue |
| `fund_research(tag)` | keeps working: 60 ducats → 15 * (1 + fund) RP on the current tech; no era cap |
| `pick_idea(tag, idea_key)` | takes one of the pending cards |

The current troop era stays `country.era`, set only by the era gate.

Each season (replaces `_research`): for every alive country, add `research_rate` to `country.research`.
- **When it reaches the cost:** mark the tech known, then message: "Researched X: <text>". Start the next tech in the queue. If the queue is empty, the AI picks; the player is told "Pick new research (T)".
- **Era gate:** if `era_ready`, raise `country.era`, send the same troop message as today, and draw ideas into `pending_ideas`. The AI picks at once in `ai.py`; the player picks on the screen.

**Start of game:** each country gets its national tech plus these starting techs:
- **Colonial countries** (in `world.colonial` with start ≤ 0): Portolan charts and Astrolabe.
- **Every coastal country:** Portolan charts.
- **Big empires** (≥ 300 provinces, scaled by the map): Drill yards.

`country.researching` starts as a sensible era I tech; the AI changes it anyway.

**Migration of old saves:** countries with no techs get their national tech. They also get the first `ERA_GATE_TECHS` techs (by cost) of each era below their current era.

## Out of scope (don't build)
- Battle cards: keep them as data only. The screen may list card names; the battle system comes later.
- Loans, corsair raids and the price-swing part of Bourse. Leave them out of the effect texts.
