# Hexa

A small turn-based medieval strategy game on a hex map, made with pygame.
Explore a random map hidden by fog, fight the computer, and capture its castle.

## Setup

```bash
pip install -r requirements.txt
python play.py
```

`python play.py --seed 42` replays the same map. The map number is shown in the window title.

## How to play

- **Goal:** move a soldier onto the enemy (red) castle. If nobody wins by turn 40,
  the side with the higher army strength (total HP of all its units) wins.
- **Select** one of your blue units by clicking it, or press **Tab** to cycle through units that can still move.
- **Move** by clicking a highlighted hex. Moving reveals the map around your units.
- **Attack** by clicking an enemy with a red outline. If it isn't adjacent, your unit walks next to it first.
  Attacking needs at least one move left and ends that unit's turn. The defender strikes back if it survives.
- **End turn** with the button or **Space**. The enemy then moves.
- **R** starts a new map. **Esc** deselects, or quits if nothing is selected.

### Units

| Unit | HP | Attack | Defense | Moves | Sight | Notes |
|---|---|---|---|---|---|---|
| Scout (arrow) | 6 | 2 | 0 | 4 | 3 | Fast explorer. Cannot capture castles. |
| Soldier (swords) | 10 | 5 | 1 | 2 | 2 | Fights and captures castles. |

### Terrain

| Terrain | Move cost | Defense |
|---|---|---|
| Grassland, dirt | 1 | +0 |
| Forest | 2 | +1 |
| Hills | 2 | +2 |
| Mountain, lake | impassable | - |
| Your own castle | 1 | +1, and heals 2 HP per turn |

### Other rules

- Each castle trains a new soldier every 3 turns, unless an enemy is standing next to it (a siege).
- A unit that neither moves nor fights heals 1 HP at the end of the turn, but not while next to an enemy.
- Flanking: each of your other units next to the target adds +1 damage to your attack.
- The computer keeps one soldier guarding its castle. It gathers 3 soldiers, then attacks together.
  It can see the whole map.

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
