# Hexa

[![tests](https://github.com/GergoPeterSomodi/Hexa/actions/workflows/tests.yml/badge.svg)](https://github.com/GergoPeterSomodi/Hexa/actions/workflows/tests.yml)

A small turn-based strategy game on a hex map, made with pygame. It has three modes:

- **Age of Discovery:** Europe, North Africa and the Mediterranean in 1480, with about 50 real
  countries. Pick any of them, run an economy of goods, markets and trade routes, fight your
  neighbours, and sail into the unknown to colonise the Americas, Africa and the Atlantic islands.
- **Conquest:** a small medieval map against one rival kingdom. Grow towns and capture its castle.
- **Colonisation:** a big unknown continent. Land your colonists, survive the winters, deal with
  native tribes, trade with your homeland and out-grow two rival companies.

## Setup

```bash
pip install -r requirements.txt
python play.py
```

The start menu picks the mode and, for colonisation, how you start and how you win.
You can also skip the menu:

```bash
python play.py --mode campaign --nation POR             # Age of Discovery as Portugal
python play.py --mode campaign --map random --seed 7    # Age of Discovery on a random world
python play.py --mode conquest --seed 42
python play.py --mode colony --start land --goal independence
```

`--seed` replays the same map. The map number is shown in the window title. **M** goes back to the menu.
`python play.py --help` lists every option.

`--nation` takes a country's tag or name in any case (`POR`, `por`, `Portugal`). Random worlds invent their own
countries (pass `--seed` too); an unknown name opens the country chooser and the terminal lists that map's countries.

## Conquest

- **Goal:** move a soldier onto the enemy (red) castle. If nobody wins by turn 40, the higher
  **score** wins: the total HP of all your units plus 10 per town.
- **Select** one of your blue units by clicking it, or press **Tab** to cycle through units that can still move.
- **Move** by clicking a highlighted hex. Moving reveals the map around your units.
- **Attack** by clicking an enemy with a red outline. If it isn't adjacent, your unit walks next to it first.
  Attacking needs at least one move left and ends that unit's turn. The defender strikes back if it survives.
- **Train units:** click one of your towns (click twice if a unit is standing in it), then a unit button
  or press **1-4**. Each town trains one unit per turn; new units can act next turn.
- **Build:** move a worker onto grassland, dirt, forest or hills inside your borders and press **B**.
- **Found a town:** move a settler at least 3 hexes away from every other town and press **B**.
- **End turn** with the button or **Space**. The enemy then moves.
- **R** starts a new map. **Esc** deselects, or quits if nothing is selected.

### Economy

You collect **food**, **wood** and **stone** at the start of every turn. The bar at the bottom shows
what you have and your income per turn.

| Source | Produces |
|---|---|
| Your castle | +2 food, +1 wood, +1 stone |
| Each other town | +1 food, +1 wood |
| Farm (grassland or dirt, costs 2 wood) | +2 food |
| Lumber camp (forest, costs 2 food) | +2 wood |
| Mine (hills, costs 3 wood) | +2 stone |
| Each soldier | -1 food (upkeep) |

- Every town owns the land within 2 hexes of it, shown by a border in its owner's color.
  Buildings on that land produce for the town's owner, so capturing a town takes its buildings too.
- An enemy unit standing on one of your buildings stops it from producing.
- If you run out of food, every soldier loses 1 HP per turn until there is food again.

### Units

| Unit | Cost | HP | Attack | Defense | Moves | Sight | Notes |
|---|---|---|---|---|---|---|---|
| Scout (arrow) | 2 food, 1 wood | 6 | 2 | 0 | 4 | 3 | Fast explorer. Cannot capture towns. |
| Soldier (swords) | 2 food, 2 wood, 1 stone | 10 | 5 | 1 | 2 | 2 | Fights and captures towns. Eats 1 food per turn. |
| Worker (hammer) | 3 food, 1 wood | 4 | - | 0 | 2 | 1 | Builds farms, lumber camps and mines. Cannot fight. |
| Settler (house) | 5 food, 3 wood | 4 | - | 0 | 2 | 1 | Founds a new town. Cannot fight. |

### Terrain

| Terrain | Move cost | Defense |
|---|---|---|
| Grassland, dirt | 1 | +0 |
| Forest | 2 | +1 |
| Hills | 2 | +2 |
| Mountain, lake | impassable | - |
| Your own town or castle | as the land | +1, and heals 2 HP per turn |

### Other rules

- Capturing an enemy town takes it over (with its land). Capturing the enemy **castle** wins the game.
- A unit that neither moves nor fights heals 1 HP at the end of the turn, but not while next to an enemy.
- Flanking: each of your other units next to the target adds +1 damage to your attack.
- The computer builds its own economy: workers, settlers and up to 4 towns. It keeps one soldier
  guarding its castle, gathers 3 soldiers, then attacks together. It can see the whole map.

All numbers are in `hexa/rules.py` if you want to rebalance the game.

## Age of Discovery

One turn is one season, from spring 1480 to 1650. Every land hex is a province.

**Controls:** left-click selects a province or unit, **right-click** moves the selected unit (or attacks
a red-outlined enemy). Right-click far away to send a unit there over several seasons. Mouse wheel or
**+/-** zooms, right-drag or **WASD** scrolls, **1-4** switch map modes (political, terrain, goods, markets;
press **3** again to switch the goods view between chips, deposits and prices), **Tab** cycles units,
**C** opens your country, **L** the ledger, **G** shows or hides the faint hex grid, **Space** ends the season.
Hover anything for a moment to get a card explaining it: troops, buttons, provinces, goods.

**Moving:** a selected stack shows where it can go this season (green, bright edge), next season (blue),
what it can attack (red; "fire" for cannons), and "stop" where an enemy castle will halt it. Hover a hex to
see the path, the move cost of each step and how many seasons it takes.

### Technology
- **T** (or **Technology** in the country panel) opens the tech tree.
  - It has four branches: Military, Trade & Industry, Navigation and Statecraft.
  - Each branch spans three eras and has 37 techs in all.
  - Every country also starts with one national tech, such as Portugal's Sagres school.
- **Researching:** one tech at a time. Click a far tech to queue its whole path; right-click removes a tech from the queue.
- **Research points** come from:
  - a base amount
  - burghers
  - universities, a city building unlocked by a tech
  - coffee houses
  - research bonuses, such as the Printing press
  - **Fund research**: 60 ducats buy 15 points, once a year
  - A tech is cheaper if countries you share markets with already know it.
- **What techs give:** tactics, drill levels, siege, castles (the large castle needs Trace italienne), supply, and stack size (base 6). They also give merchants, taxes, new manufactories (ropewalk, powder mill, glassworks, tannery), carracks and galleons, Atlantic crossings, plantations, and more.
- **Troop types still come with the eras.**
  - Era II opens from 1520 once you know 4 era I techs.
  - Era III opens from 1575 with 4 era II techs.
  - At each new era you pick 1 of 3 idea cards (one is your nation's), which are permanent bonuses.

### Menu, saving and options
- **Esc** (or **M**, or the **Menu** button) pauses the game and opens the menu: resume, save, load, options, back to the main menu, exit.
- **Saving:** there are eight save slots plus a quicksave (**F5** saves, **F9** loads) and an autosave (every year by default). Each slot shows the country, the date and the map.
  - Saves are kept in `~/.hexa/saves`. If a save can't be written (a read-only folder or a full disk), a message says why, the game carries on, and the slot keeps its previous save.
  - **Continue** on the start menu loads your latest save. If that save can't be read, the start menu says so instead of starting a new game.
- **Options:**
  - fullscreen (also **F11**)
  - window size: 1280x720, 1600x900 or 1920x1080; the map fills the extra space
  - autosave: off, every year or every 5 years
  - scroll speed
- Options are kept in `~/.hexa/settings.json`. If that file can't be written (a read-only folder or a full disk), a changed option still applies until you quit, and a message says it wasn't saved.

### The map
- **Two maps** (pick one in the menu, or with `--map europe|random`):
  - **Europe 1480** is the real map, with about 14,000 provinces.
  - **Random world** is a new world every game (`--seed` repeats one). It has invented countries in a known Old World with an inland sea, and an unknown New World across the ocean.
- **Wave function collapse:** both maps grow their terrain this way.
  - Every hex gets odds from its geography (latitude, mountain ranges, deserts, steppes, marsh regions, rivers).
  - Neighbouring hexes must fit together: mountains rise through hills, deserts fade through steppe and savanna, and snow only touches cold land.
  - Like clumps with like, so forests, marshes and hills form natural regions.
  - The random world also lays out its continents by wave function collapse, on a coarse grid.
- **Terrain:** farmland, steppe, forest, hills, mountains, desert, jungle, tundra, marsh, taiga, savanna, coast and snowfield.
  - Each has its own move cost, defense and population.
  - Vineyards, pastures and plantations show what farmland grows.
- **Rivers** (Rhine, Danube, Loire, Nile, Mississippi...): river land holds more people, and marching along a river costs one move less.
- **Roads** join each country's towns and its neighbours' capitals. Along a road, every hex costs one move.
- **Edge-matched tiles:** coasts, rivers, roads, bridges, town walls, towns and castles come from a wave function collapse tileset (`wfctiles.py`).
  - Every tile has a socket on each of its six edges, so coastlines, rivers and roads always join across hexes.
  - Settlements grow from hamlet to great city, and coastal towns get harbours.
- **Looks:**
  - Coasts have surf and shallow water.
  - Rivers have banks, and bridges where roads cross.
  - Borders are ribbons in the country's colours.
  - Towns and cities grow extra houses, mines smoke, and ports get docks.
  - Northern Europe frosts over in winter.
- **Close zoom** (hex radius 21 and 34): the landscape is drawn with the tile art. Peaks and forests cross hex borders,
  treeline and snow follow the altitude, and farms grow field systems with hedgerows. The faint hex grid is on by default
  (**G**, or Options > Hex grid).
- **Mountain passes:** the main Alpine and Pyrenean passes (Gotthard, Brenner, Mont Cenis, Simplon, Great St Bernard,
  Roncesvalles) and the Carpathian Dukla and Lupkow are closed by snow in winter (every fourth season, turn 4, 8, ...).
  Land units cannot enter a closed pass; the move says "The Gotthard pass is closed by snow until spring." A unit already
  on one may leave, and ships are not affected. A random world gets up to 8 passes on its longest ridges.
- **Debt:** a country may go into debt down to a limit of 6 seasons of running costs (at least 300 ducats). It pays 2%
  interest a season on debt up to that limit. Over the limit with a deficit, unpaid troops desert, oldest first and never
  the general. With no troops left, creditors seize buildings, works, castles and then settlement levels, one at a time.
  The log tells you each step.
- **Units:** close up, a stack shows up to three figures of what it holds, with a shield for its size. Zoomed out, it shows as a board-game token with era pips.

### Fog
- **Black fog:** places your country has never seen. In 1480 that is everything west of the Canaries:
  the Azores, Cape Verde and the Americas (Portugal and Castile also know the African coast).
- **Light fog:** places you know but cannot see right now. You see owners and terrain, not armies.
  You see around your provinces and your units; ships see furthest.

### Economy
- **Goods (32):**
  - **Raw:** grain, fish, salt, wine, wool, cotton, timber, iron, horses, cattle, stone, copper, hemp & flax.
  - **Luxuries:** sugar, tobacco, furs, ivory, spices, olive oil, silk, dyes, cocoa and coffee.
  - **Money:** silver and gold.
  - **Made in towns:** cloth, tools, weapons, rope & sails, glass, leather and gunpowder.
  - Each province produces one raw good, where it grew in 1480 (shown by the goods map mode). For example: horses on the steppe and in Hungary, copper in Sweden and Hungary, silk in Anatolia and Lombardy, olives around the Mediterranean, cocoa in Central America, coffee in Yemen and Ethiopia.
- **What goods are needed for:**
  - **Cavalry:** horses and leather.
  - **Cannons:** copper and gunpowder.
  - **Arquebusiers and musketeers:** gunpowder.
  - **Ships:** rope & sails.
  - **Towns, cities and castles:** stone, plus glass for a city and gunpowder for a large castle.
  - **Province investment:** timber, tools, stone and iron.
  - All of it is bought on the local market, so shortages raise prices.
- **Pops:** peasants, burghers and nobles. Peasants work the land, burghers staff manufactories,
  everyone eats and buys cloth, wine, salt and (the rich) sugar, spices, furs and more.
- **Markets:** about 20 market towns (Lisbon, London, Antwerp, Venice, Constantinople...).
  Each province sells in its nearest market. Prices rise when demand beats supply and fall when
  goods pile up (between 0.3× and 3.5× the base price). Colonial markets (Havana, Bahia, Elmina...)
  open once someone settles near them.
- **Trade routes:** goods flow between neighbouring markets (and across the Atlantic) from cheap to dear
  by themselves; market owners take tolls.
- **Merchants** are yours to play: in a market panel press **+** on a route and give a merchant an order,
  **export** or **import** a good you choose (12 units a season). The card shows the expected profit;
  the profit or loss each season is yours. You get more merchants from marketplaces and market towns.
- **The tile:** zoom in (mouse wheel) to see the map in tile art. Each province's tile can be improved:
  - **Investment** (no builder units: press **Invest** in the province panel):
    - Every goods tile has five levels, each with its own look. For example: wheat strips → open fields → grange barn → windmill farm → manor estate; iron diggings → … → ironworks; fishing beach → … → fishing harbour.
    - Each level costs ducats plus timber, tools, stone or iron bought on the local market, and gives +30% goods.
    - Levels 3–4 need the second era, and level 5 the third.
  - **Settlement:** countryside → village → town → city. Needs enough people; gives more taxes and
    building slots (1 / 3 / 5).
  - **Castle:** tower → small castle → large castle. Defensive: +defense for your armies there and much longer sieges.
- **One job per province each season:** train a unit, or start a settlement, castle or building (4 seasons to finish).
- **Buildings** (use the settlement's slots):
  - Manufactories:
    - weavers (wool or cotton → cloth)
    - toolmakers (iron → tools)
    - armouries (iron + tools → weapons)
    - ropewalks (hemp → rope & sails)
    - glassworks (stone + timber → glass)
    - tanneries (cattle → leather)
    - powder mills (salt(petre) + timber → gunpowder)
  - Marketplaces, ports and shipyards. Manufactories buy their inputs on the
  market and need burghers.
- **Money each season:** taxes on goods produced and on people (low/normal/high tax), a share of
  manufactory profits, and trade; minus upkeep for buildings, armies, ships and young colonies.
- Food shortages make people shrink; full markets make them grow.

### Colonies
Raise **colonists** (1,000 settlers from a province) and a **caravel** or **carrack** at a port.
Move the colonists onto the ship, sail into the black fog, and land on unclaimed coast:
- **Found a colony:** settlers take the land and it grows; at 5,000 people it becomes a full province.
  Natives nearby may raid young colonies.
- **Open a trading post:** on a coast with natives, who keep living there and produce goods for you.

### War
**Troops** stack on a hex (6 in 1480, 7 and 8 in later eras; a general adds 2). Click a stack to select it all;
untick units in the side panel to leave them behind. Right-click moves the ticked units or attacks.

| | 1480 | from ~1520 | from ~1575 | Good at |
|---|---|---|---|---|
| Infantry | Pikemen | Arquebusiers | Musketeers | Defending, holding castles, stopping cavalry |
| Cavalry | Knights | Lancers | Cuirassiers | Fast; hits hard in open land, weak in forests, hills and against castles |
| Cannons | Bombards | Culverins | Field guns | Fire 2 hexes away without reply, smash castles and speed up sieges; weak up close |

- **Battles:** the best 3 units of each side form the front line; every unit behind adds +5% (up to +25%),
  and cannons behind the line fire first. Defenders strike back. Terrain and castles help defenders.
- **Castles** have their own garrison (stronger with each level). They stop enemy armies walking past
  (armies must halt next to them) and must be **besieged** for several seasons (cannons and siege-master
  generals shorten it) or stormed. Taking a province without a castle needs one season.
- **Getting better:** research (burghers, or pay to fund it) unlocks new eras; **refit** old troops in a town.
  A **barracks** (infantry, cavalry) or **foundry** (cannons) lets you drill units for +attack / +defense.
  Units that survive battles become **Veteran** (+10%) and **Elite** (+20%). **Generals** (raised in your
  capital) give +2 stack room and +20% in their speciality: open field, forests and hills, storming castles,
  defending, or cavalry.
- **Feeding armies:** every troop takes 1,000 men from its province when raised and eats 0.5 grain a
  season from the local market (paid in ducats, it raises food prices). Each province **feeds** a number of
  troops (people and farms; half in foreign land): bigger stacks lose 1 HP a season. **Supply lines:** towns,
  castles and ports are depots; a stack within 3 hexes of one through land you control is in supply. Enemy
  armies cut the line; cut-off troops cannot heal and lose 1 HP a season. A **supply wagon** feeds its stack for
  4 seasons away from depots (refills in supply), or the stack can **forage** foreign land (the province loses
  people and half its goods).
- Troops heal in their own land when fed (faster in towns). Declare war on a neighbour from their country panel;
  make peace from yours: demand the land you occupy, offer white peace, or give up.

All numbers are in `hexa/campaign/data.py`; the map, countries and markets in `hexa/campaign/geo.py`.

## Colonisation

One turn is one season: spring, summer, autumn, winter. The map is bigger than the window:
scroll with the **arrow keys**, **WASD** or by dragging with the **right mouse button**, or click the minimap.
**C** centres on what you have selected.

### Setup choices

| Start | |
|---|---|
| Arrive by sea | A ship with 2 colonists, a soldier and a pioneer. Sail to the coast, land, found your first colony. |
| Settled coast | A colony of 2 people on the coast, with a soldier, a pioneer, a scout and a ship. |

| Goal | |
|---|---|
| Survive 10 years | After 40 seasons the best score wins: 10 per colony, 5 per person, 2 per building, 1 per soldier, gold / 10. Wiping out both rivals also wins. |
| Independence | Reach 12 population and 3 soldiers, then **declare independence** in a colony. The Crown lands 4 waves of royal regulars. Hold out for 12 turns (or destroy them all) to win. |
| Endless | No time limit. |

You lose if you have no colonies and no colonists left.

### Colonies

- **Colonists** found colonies (**B**) at least 3 hexes from other colonies and 3 from native villages,
  or **join** (**J**) a colony next to them for +1 population.
- Each colony owns the land within 2 hexes. **Pioneers** build there (**B**):

| Building | Land | Cost | Produces |
|---|---|---|---|
| Farm | grassland, plains | 2 wood | +3 food (nothing in winter) |
| Fishery | beach | 2 wood | +2 food, all year |
| Trapper camp | forest | 2 food | +2 wood +1 fur (winter: +1 wood +2 furs) |
| Silver mine | hills | 3 wood | +2 gold |

- A building only produces if someone works it: **each person in a colony works one building**.
- A colony itself makes +2 food +1 wood. Every person eats 1 food and every soldier 1 food per turn.
- Each colony does **one job per turn** (buttons or keys **1-7**): train a scout, pioneer or soldier,
  turn a person into a colonist, **grow** (+1 person for 6 food) or build a **stockade** (+2 defense).

### Survival

- **Winter:** farms freeze, every colony burns 1 wood, and units outside your own land lose 1 HP.
- **Summer:** colonies of 3+ people can lose a person to fever.
- **Out of food or wood:** your biggest colony loses a person (and soldiers starve when food runs out).

### The homeland

Sail a ship to the glowing east edge of the map to trade: sell furs (2 gold each) and timber,
buy food, colonists (6 gold), pioneers (5) and soldiers (8). Bought units board the ship.
Selling furs pleases the Crown: every 8 furs sold earns a free colonist the next spring.
A ship carries 4 units; select it and pick a passenger to take it ashore (costs 1 move).

### Native tribes

Three tribes live in villages inland. The coloured dot on a village shows their mood towards you:
green friendly, yellow wary, orange angry, red at war.

- A **scout** visiting a village for the first time gets a gift: gold, food, maps, or even a new colonist.
- Click a village to **gift** (3 gold, calms the whole tribe) or **trade** (2 wood for 3 furs, once per turn).
  You need a unit next to it or a colony within 4 hexes.
- Tribes get angry when you found colonies within 4 hexes of their villages, build next to them,
  or attack them. At 100 tension they go to war: their braves raid your colonies (stealing food
  and people) and burn your buildings. Gifts bring peace back.
- Soldiers can burn an empty village for loot, but that means war with its tribe and angers the others.

### Rival companies

The Crimson Company lands in the north and the Golden Company in the south. They settle,
build, trade with the natives and the homeland, and from about year 5 they attack weak colonies,
yours or each other's. Soldiers capture an enemy colony by walking into it when it is empty.

| Unit | Cost | HP | Attack | Defense | Moves | Notes |
|---|---|---|---|---|---|---|
| Colonist | 1 person + 2 food, or 6 gold | 4 | - | 0 | 2 | Founds or joins colonies |
| Pioneer | 3 food 1 wood, or 5 gold | 4 | - | 0 | 2 | Builds |
| Scout | 2 food 1 wood | 6 | 2 | 0 | 4 | Sees far, visits villages |
| Soldier | 2 food 2 wood 2 gold, or 8 gold | 10 | 5 | 1 | 2 | Fights, captures colonies, eats 1 food |
| Ship | - | 12 | - | 1 | 5 | Carries 4 units, trades with the homeland |
| Brave (natives) | - | 8 | 4 | 1 | 3 | Raids colonies, burns buildings |
| Regular (Crown) | - | 12 | 6 | 2 | 2 | The royal army after you declare independence |

All colonisation numbers are in `hexa/colony/rules.py`.

## Map editor

`python Hex.py` opens the original tile-painting map editor (it uses `map3.xml`).

## Development

**Plans and designs** live in [`docs/`](docs/README.md):
- the [roadmap](docs/roadmap/roadmap.md) and the [long-term roadmap](docs/roadmap/long-term-roadmap.md), whose final goal is a Steam release
- the approved designs (tech tree, battle system) with their mockups
- playtest and issue-triage reports

Version history is in [CHANGELOG.md](CHANGELOG.md).

The tests use Python's built-in `unittest` and, apart from the window tests in `tests/ui/` and nine game modules
that draw (skipped without pygame, see [Window tests](#window-tests-pygame)), don't need pygame:

```bash
python -m unittest discover -s tests -t .                              # all tests (about 2.5 minutes)
HEXA_FAST=1 python -m unittest discover -s tests -t .                  # skip the slow tests (about 30 seconds)
python -m unittest tests.test_game                                     # one file
python -m unittest tests.test_game.HexGridTest.test_pixel_round_trip   # one test
```

`HEXA_FAST=1` skips the tests marked `@slow` (the 100-season AI history, the AI game loops, the random-world
tests, the property-test games); they still count as tests, shown as skipped. CI always runs everything.
`tests/test_campaign.py` is the slowest because it builds the full Europe map.

`tests/test_fuzz_files.py` damages `settings.json` and save files at random (truncation, flipped bytes, wrong JSON
types, binary garbage, a good header with a wrong-shaped world after it) and checks that loading them never raises.
It runs 300 cases per test by default (a few seconds); `HEXA_FUZZ_CASES=3000` runs more, and `HEXA_FUZZ_SEED=<n>`
sets the first seed. A failure prints the seed of the case and a command that replays only that case, e.g.
`HEXA_FUZZ_SEED=20260110 HEXA_FUZZ_CASES=1 python3 -m unittest tests.test_fuzz_files`.

`tests/test_properties.py` checks whole games in all three modes. The same seed must play the same game under two
`PYTHONHASHSEED` values (two processes; Conquest to the end, Colonisation 30 rounds, the campaign 4 seasons), and a
campaign saved and loaded must play on exactly like the original. A seeded random player tries every `x_check` /
`x` pair, legal and illegal: a refused action must change nothing and an allowed one must succeed. The world
invariants in `tests/support/invariants.py` (units on legal hexes, cargo within capacity, stocks never negative,
province owners alive, prices within their limits, ...) are checked after every turn of those games. It plays 20
random games per mode (Conquest to the end, Colonisation 10 rounds, the campaign 3 seasons); `HEXA_PROP_GAMES=100`
plays more and `HEXA_PROP_SEED=<n>` sets the first seed. `HEXA_FAST=1` keeps one short game per mode. A failing
game prints its seed, its first problem and a command that replays only that game, e.g.
`HEXA_PROP_SEED=7 HEXA_PROP_GAMES=1 python3 -m unittest tests.test_properties.ColonyGamesTest`. To see a
determinism digest by hand: `PYTHONHASHSEED=0 python3 -m tests.support.digest_run colony 5 --turns 30`.

Shared test helpers live in `tests/support/`: `europe()` (one read-only Europe world), `fresh(player)` (a world
you may change), `random_world(seed)`, `play_seasons(world, n)`, `TempHome` and `@slow`; the invariant checkers
`check_conquest`, `check_colony` and `check_campaign`; the random players (`agents.py`), whole-world digests
(`digests.py`) and all-AI game loops (`games.py`). A test that changes a shared world fails the module's
`tearDownModule` guard, so use `fresh()` for anything you mutate.

The game rules, AI and map generation don't use pygame; only the window, menu and drawing code do.
To keep test runs or experiments away from your real saves and options, set `HEXA_HOME` to another folder
(the default is `~/.hexa`).

Python 3.10 or newer is needed (the suite passes on 3.10, the oldest version CI tests). Every push and pull
request runs the whole suite on GitHub Actions (`.github/workflows/tests.yml`) on Python 3.10, 3.13 and the
newest release, without installing pygame (the window tests show as skipped there; the `ui` job runs them).
To reproduce a CI run locally:

```bash
HEXA_HOME=$(mktemp -d) python -m unittest discover -s tests -t . -v
HEXA_HOME=$(mktemp -d) python -m unittest discover -s tests -t . -v --durations 15   # Python 3.12+: slowest tests
```

To see which code the tests reach, install coverage.py (the only development dependency, never needed to play)
and run the suite under it. The settings are in `.coveragerc` (branch coverage; `hexa/` and `play.py`, without the
tests and the legacy editor). Branch coverage is about 5 times slower on Python 3.12 and older, so CI measures on 3.14:

```bash
pip install -r requirements-dev.txt
HEXA_HOME=$(mktemp -d) coverage run -m unittest discover -s tests -t .
coverage report            # table in the terminal; coverage html writes htmlcov/index.html
```

Every CI run also shows the coverage table on its summary page and attaches the HTML report as the `htmlcov`
artifact. There is no minimum yet.

### Window tests (pygame)

`tests/ui/` drives the real windows (start menu, Conquest, Colonisation, Age of Discovery) through their own
`run()` loops with no screen: SDL's dummy video and audio drivers, fake time and scripted mouse and keyboard
input, then checks the game state. They need pygame, which has no wheels for Python 3.14 or newer yet, so use a
Python 3.12 (or 3.13) virtual environment. Without pygame these tests show as skipped. So do nine test modules of
the game's own that sit next to the unit tests but import pygame at the top (`tests/test_landscape.py`,
`test_passes.py`, `test_playtest.py`, `test_techscreen.py`, `test_uifixes.py`, `test_wfctiles.py`,
`test_goodsobjects.py`, `test_mapview_polish.py` and `test_town_labels.py`): each skips as a whole, and the `ui`
job runs them.

```bash
python3.12 -m venv .venv && .venv/bin/pip install pygame==2.6.1 -r requirements-dev.txt
HEXA_HOME=$(mktemp -d) .venv/bin/python -m unittest discover -s tests/ui -t . -v   # only the window tests (a few seconds)
HEXA_HOME=$(mktemp -d) .venv/bin/python -m unittest discover -s tests -t .         # everything, window tests included
HEXA_REQUIRE_PYGAME=1 python -m unittest discover -s tests/ui -t .                 # without pygame: errors, not skips
```

`HEXA_REQUIRE_PYGAME=1` turns the skips into errors, so a run that is meant to test the windows can't pass by
skipping them; CI's `ui` job sets it. When a window test fails it saves the last frame on screen to
`test-artifacts/<test name>.png` (`HEXA_TEST_ARTIFACTS` picks another folder), and CI attaches that folder to
the failed run. `SDL_VIDEODRIVER` and `SDL_AUDIODRIVER` default to `dummy`; set them (e.g. `SDL_VIDEODRIVER=x11`)
to open a real window instead, though the scripted run doesn't slow down for you to watch.

The helpers are in `tests/support/harness.py`: `UITestCase` (pygame set up, a temporary `HEXA_HOME`, the
driver reset), `driver.at(frame, events)` and `driver.run_for(frames, until=...)` to script a run, the events
`key`, `click`, `drag`, `wheel` and `hover`, and `button_rect`, `end_turn_rect`, `pause_button_rect`,
`menu_option_rect`, `menu_start_rect` and `hex_pixel` to find things on screen from the window's own state. Test
modules in `tests/ui/` import pygame and the window modules inside the tests, never at the top, so the
pygame-free run can still import them.

CI's `ui` job runs these tests on Python 3.12 with pygame 2.6.1 and adds a second coverage table, of lines
only: on 3.12 branch coverage is slow, and `HEXA_COVERAGE_BRANCH=0` switches it off in `.coveragerc`. Locally:

```bash
HEXA_COVERAGE_BRANCH=0 COVERAGE_CORE=sysmon HEXA_HOME=$(mktemp -d) .venv/bin/coverage run -m unittest discover -s tests/ui -t .
.venv/bin/coverage report
```

## Project layout

| File | What it does |
|---|---|
| `play.py` | Starts the game: menu, then the conquest window (mouse, keyboard, enemy turn timing) |
| `hexa/menu.py` | The start menu |
| `hexa/settings.py` | Player options, stored in `~/.hexa/settings.json` |
| `hexa/campaign/` | Age of Discovery: `geo.py` (real map, countries, markets, rivers), `randomgeo.py` (random worlds), `wfc.py` (wave function collapse), `art.py` (code-drawn tiles, figures, tokens), `data.py` (goods, buildings, balance), `world.py` (economy, trade, colonies, war), `ai.py`, `mapview.py`, `app.py`, `gamemenu.py` (in-game menu), `saves.py` (save slots) |
| `hexa/colony/` | Colonisation mode: `rules.py`, `mapgen.py`, `world.py` (rules), `ai.py` (rivals, natives, royal army), `render.py`, `app.py` (window) |
| `hexa/rules.py` | Unit, terrain and balance numbers |
| `hexa/world.py` | Game state and rules: movement, combat, fog of war, turns, winning |
| `hexa/mapgen.py` | Random map generation |
| `hexa/ai.py` | The computer opponent |
| `hexa/render.py` | Drawing the map, units and info bar |
| `hexa/hexgrid.py` | Hex grid maths |
| `tests/` | Rule tests (see Development); shared helpers in `tests/support/`; headless window tests in `tests/ui/` |
| `Hex.py`, `Game.py`, `Setting.py`, `Create_xml.py`, `Read_XML.py` | The original map editor and its XML map loading (`map*.xml`) |

Tile art: [Kenney Hexagon Pack](https://kenney.nl/assets/hexagon-pack) (CC0), in `hexagon-pack/`.
