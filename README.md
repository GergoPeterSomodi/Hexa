# Hexa

A small turn-based medieval strategy game on a hex map, made with pygame.
Explore a random map hidden by fog, grow towns and an economy, fight the computer, and capture its castle.

## Setup

```bash
pip install -r requirements.txt
python play.py
```

`python play.py --seed 42` replays the same map. The map number is shown in the window title.

## How to play

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

## Map editor

`python Hex.py` opens the original tile-painting map editor (it uses `map3.xml`).

## Project layout

| File | What it does |
|---|---|
| `play.py` | Starts the game: window, mouse and keyboard, enemy turn timing |
| `hexa/rules.py` | Unit, terrain and balance numbers |
| `hexa/world.py` | Game state and rules: movement, combat, fog of war, turns, winning |
| `hexa/mapgen.py` | Random map generation |
| `hexa/ai.py` | The computer opponent |
| `hexa/render.py` | Drawing the map, units and info bar |
| `hexa/hexgrid.py` | Hex grid maths |
| `tests/` | Rule tests: `python -m unittest discover -s tests -t .` |

Tile art: [Kenney Hexagon Pack](https://kenney.nl/assets/hexagon-pack) (CC0), in `hexagon-pack/`.
