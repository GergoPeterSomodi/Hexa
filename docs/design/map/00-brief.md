# The map: design brief (2026-11-14)

## Why this exists

The owner reset the Godot work: Hexa is **restarted in Godot**, not ported. The Python game is an example and a good
direction, not a target to copy. The first and only task now is to **plan how the map will look and how it is built**,
before any more game code is written. Design first, mockups first, then the owner decides, then it is built.

## Scope

- **Europe** (the 1480 setting; the existing geography data in `godot/data/geography/` is a usable source: coastlines,
  major rivers, mountain ranges, passes, cities, regions, place names).
- **One country is enough to show the look** (not all 49). The prototype region and country for every mockup:
  **northern Italy and the western Alps, with the Duchy of Milan as the one country** (Alps, valleys, the Po plain,
  rivers, lakes, the Ligurian coast, passes, cities: every kind of connection in one frame).
- **The look:** direction A "Hexa refined" (`docs/design/godot-look/README.md`, and the close-up mockups 07, 07b, 08 in
  that folder). Fresh design, not a copy of the Python art.
- **Start from the existing tiles:** the Kenney hexagon pack (`hexagon-pack/`, CC0) and the code-drawn art of the Python
  game (`hexa/campaign/art.py`, `landscape*.py`, `goodsart.py`, `landmarks.py`; baked copies in `godot/assets/baked/`, see
  `docs/design/art-inventory.md`) are the starting library for the new mode's objects.

## The core question: how things connect

Roads, valleys, rivers, cities, coasts, ridges and passes must join up across hex edges and look natural. The map is
generated with **wave function collapse (WFC)**: today a simple terrain-only WFC exists (`hexa/campaign/wfc.py` as the
example; the Godot port in `godot/core/mapgen/wfc.gd` with `terrain_prior.gd` and the FORBIDDEN pairs in
`godot/data/wfc.json`). The new design must model how WFC (or WFC plus other steps) joins every feature: what is fixed
from real geography, what is generated, what each hex edge "carries" (a socket vocabulary: river, road, coast, ridge,
valley floor...), and which combinations are allowed.

## Design threads (run in parallel, each writes its own doc in this folder)

1. `01-terrain-and-relief.md`: terrain kinds, elevation, mountains, hills, valleys, plains, how relief reads.
2. `02-water.md`: rivers (source to sea), lakes, coasts, deltas, the sea; how water joins across hexes.
3. `03-settlements-and-roads.md`: cities, towns, villages, ports, castles; roads, bridges, passes; how they connect.
4. `04-wfc-model.md`: the generation model that joins 1 to 3 (sockets, layers, constraints, order, performance).
5. `05-tiles-and-objects.md`: the tile and object library built from the existing tiles, matching the socket model;
   the one country's look (borders, colour, arms) in the prototype region.

Every thread uses the **same socket vocabulary** as the base for edge connections; thread 4 owns the final list, and the
others propose what they need in a section called "Sockets I need". Each doc ends with **at most 3 owner questions**
(plain words, recommended answer first). Mockups go in `docs/design/map/` with the thread number as a prefix.

## Not in scope now

Game rules, units, AI, panels, all 49 countries, the rest of the world. Nothing gets built in code until the owner has
approved the map design.
