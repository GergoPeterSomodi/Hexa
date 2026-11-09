# Hexa

A small turn-based strategy game on a hex map, made with pygame. It has two modes:

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
python play.py --mode conquest --seed 42
python play.py --mode colony --start land --goal independence
```

`--seed` replays the same map. The map number is shown in the window title. **M** goes back to the menu.

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

## Project layout

| File | What it does |
|---|---|
| `play.py` | Starts the game: menu, then the conquest window (mouse, keyboard, enemy turn timing) |
| `hexa/menu.py` | The start menu |
| `hexa/colony/` | Colonisation mode: `rules.py`, `mapgen.py`, `world.py` (rules), `ai.py` (rivals, natives, royal army), `render.py`, `app.py` (window) |
| `hexa/rules.py` | Unit, terrain and balance numbers |
| `hexa/world.py` | Game state and rules: movement, combat, fog of war, turns, winning |
| `hexa/mapgen.py` | Random map generation |
| `hexa/ai.py` | The computer opponent |
| `hexa/render.py` | Drawing the map, units and info bar |
| `hexa/hexgrid.py` | Hex grid maths |
| `tests/` | Rule tests: `python -m unittest discover -s tests -t .` |

Tile art: [Kenney Hexagon Pack](https://kenney.nl/assets/hexagon-pack) (CC0), in `hexagon-pack/`.
