# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Hexa is a turn-based hex strategy game in plain Python + pygame with three modes (Conquest, Colonisation,
Age of Discovery) behind one launcher. `README.md` is the player-facing rules reference: its tables mirror the
balance numbers in the rules/data modules, so update it when you change rules, numbers or controls.

## Commands

```bash
pip install -r requirements.txt                      # pygame; pygame-gui is only for the legacy editor
python play.py                                       # start menu
python play.py --mode conquest --seed 42             # skip the menu; --seed replays a map
python play.py --mode colony --start land --goal independence
python play.py --mode campaign --nation POR          # Age of Discovery as a given country tag
python play.py --mode campaign --map random --seed 7
python Hex.py                                        # legacy tile-painting map editor
```

Tests use stdlib `unittest` (no pytest, linter or formatter is configured):

```bash
python -m unittest discover -s tests -t .                                 # everything, ~2 min
python -m unittest tests.test_game                                        # one module
python -m unittest tests.test_campaign.WarTest                            # one class
python -m unittest tests.test_game.HexGridTest.test_pixel_round_trip      # one test
```

Use `python3` where `python` isn't on PATH. Tests do not need pygame installed. `test_campaign` is the slowest (~1 min) because building the Europe map
takes seconds; `test_game` runs in ~10 s.

## Architecture

### One launcher, three modes

`play.py:main()` loops: `hexa/menu.py:Menu` returns settings, the chosen app's `run()` returns `"menu"` or
`"quit"`. The Conquest app class lives in `play.py` itself.

| Mode | State and rules | AI | Balance numbers | UI |
|---|---|---|---|---|
| Conquest | `hexa/world.py` `World` | `hexa/ai.py` | `hexa/rules.py` | `play.py` `App`, `hexa/render.py` |
| Colonisation | `hexa/colony/world.py` `ColonyWorld` | `hexa/colony/ai.py` | `hexa/colony/rules.py` | `hexa/colony/app.py`, `render.py` |
| Age of Discovery | `hexa/campaign/world.py` `CampaignWorld` | `hexa/campaign/ai.py` | `hexa/campaign/data.py` | `hexa/campaign/app.py`, `mapview.py`, `art.py` |

Colonisation builds on Conquest code: `colony/rules.py` imports `Terrain` from `hexa/rules.py`,
`colony/render.py` subclasses `hexa.render.Renderer`, and `colony/mapgen.py` reuses `hexa.mapgen._noise`.
The campaign is self-contained apart from `hexa/hexgrid.py`.

### Conventions shared by all modes

- **No pygame in game state.** World, rules, AI, mapgen, geo, WFC and saves modules never import pygame. Tests
  rely on this; keep drawing and input in the `app`/`render`/`mapview`/`art`/`menu` modules.
- **`*_check` / action pairs.** A world exposes `x_check(...) -> (ok, reason)` next to `x(...)`, which checks
  again and then acts (`train_check`/`train`, `build_check`/`build`, `found_check`/`found`, ...). The UI uses
  the check to enable buttons and shows `reason` as the hover hint. New player actions should follow this.
- **Hex coordinates** (`hexa/hexgrid.py`) are pointy-top, "odd-r" offset `(col, row)` tuples (odd rows shift
  half a hex right). `hex_center`/`pixel_to_hex` assume the fixed 60x70 Kenney sprite and serve Conquest and
  Colonisation; the campaign's `MapView` has its own zoomable geometry (`ZOOMS`) and uses only `neighbors`.

### Turn flow and AI

- **Conquest / Colonisation:** `ai.take_turn(world, side)` is a generator that yields after every unit action.
  The app's `update()` drains it and pauses `AI_STEP_MS` only when the acting unit is visible to the player.
  These AIs see the whole map.
- **Campaign:** one turn is one season. `CampaignApp.end_turn()` runs `ai.run(world, tag)` synchronously for
  every non-player country, then `world.end_round()` (logistics, sieges, war timeouts, economy, growth,
  research, turn counter), then moves units along multi-season orders (`unit.goal`). Campaign AIs only know
  what their country has explored (`country.explored`). `world.player = None` makes everything visible, as in
  most tests.

### Campaign internals

- **Geography sources.** A world is built from either the `hexa/campaign/geo.py` module (real 1480 map:
  lon/lat polygons rasterised onto the hex grid with a Mercator projection, `SCALE = 2`) or
  `randomgeo.generate(seed)`, which returns a `SimpleNamespace` that copies geo's interface and projection.
  `world.py` reads geography only through `self.geo`, so any new attribute must exist on both sources, or be
  read with a `getattr` default as `COLONIAL` and `FORCE_SEA` are. Distances in `data.py` scale with
  `geo.SCALE`.
- **Terrain** comes from `wfc.collapse` (wave function collapse): per-hex priors from `CampaignWorld._prior`
  plus the `FORBIDDEN` adjacency pairs at the top of `campaign/world.py`.
- **Build caching.** Building a world takes seconds, so `CampaignWorld.__init__` stores a pickled snapshot of
  each fresh `(map, seed)` world in the module-level `_SNAPSHOTS` and restores later constructions from it.
  `map_source` caches random geographies in `_RANDOM_GEOS`. Tests share one module-level `WORLD` for read-only
  checks and call `fresh()` when they mutate.
- **Redraw invalidation.** `MapView` and the minimap cache surfaces keyed on `(zoom, mode, world.version,
  player)`. Call `world.changed()` after any mutation that affects the map, and `world.changed(ownership=True)`
  when province owners change: that also clears the `provinces_of` cache (`_owned`) and `_castle_list`.
- **Saves** (`campaign/saves.py`): one JSON header line, then a pickle of `world.save_state()` (the world's
  `__dict__` minus `geo`, which is rebuilt from `map` + `seed` on load). Files with a different `VERSION` are
  ignored. Renaming or adding attributes and dataclass fields changes what saves contain. Lazily added
  attributes use `getattr`/`__dict__.setdefault` (`_known_world`, `_explored_from`) so older saves still load;
  bump `VERSION` when compatibility breaks.
- Saves and options (`hexa/settings.py`) live in `~/.hexa/`; the `HEXA_HOME` environment variable overrides
  this, and `tests/test_saves.py` uses it with a temporary folder.
- `gamemenu.GameMenu` is a mixin base class of `CampaignApp`: the Esc menu, save/load, options, and the screen
  mode (window size, fullscreen).
- `art.py` draws extra tiles, decorations, unit figures and tokens in code, in the Kenney style at 120x140.
  `MapView` switches from flat colours to tile art at zoom index `TILE_FROM`.

### Legacy map editor

`Hex.py`, `Game.py`, `Setting.py`, `Create_xml.py` and `Read_XML.py` at the repo root are the original
pygame-gui tile editor (it loads `map3.xml`). They don't touch the `hexa` package, and the `map*.xml` / `.tmx`
files are their data. `pygame-gui==0.5.7` is in `requirements.txt` only for this editor.

### Assets

`hexagon-pack/` is the Kenney Hexagon Pack (CC0). Every app gets `TILES_DIR` (`hexagon-pack/PNG/Tiles`) from
`play.py`; the campaign's `art.py` finds object sprites in the sibling `Objects` folder.
