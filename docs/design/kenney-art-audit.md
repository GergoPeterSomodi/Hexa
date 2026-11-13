# Kenney art audit

Which Kenney Hexagon Pack files the game still uses, how visible each one is, and a plan to replace them with
our own code-drawn art before the Steam release. Roadmap item: "Kenney art audit" (playtest ideas).

Audited on the Europe 1480 map. Age of Discovery comes first. Conquest and Colonisation are frozen and are
listed at the end.

## Questions for the owner

1. **Replace everything, or only the most visible?** Option A: replace all 30 live files (about 2 weeks of
   art work in total). Option B: replace only the ground textures and the zoom-13 terrain tiles (steps 1-3,
   about a week), and keep the small props. Option C: keep Kenney art where it is now (it is CC0 and legal on
   Steam), and stop adding new uses. **Recommendation: B first, then decide on the rest.** Steps 1-3 cover
   almost all of the Kenney pixels on screen.
2. **Should Conquest and Colonisation change too?** They are 100% Kenney tiles. Option A: keep them as they are
   (frozen modes, CC0). Option B: point them at the new Age of Discovery tiles once those exist (cheap, as the
   mapping is the same). **Recommendation: A for now, B if they ship on Steam.**
3. **Native camps.** The Kenney camp tile shows tipis and a cactus on desert sand. It stands for every native
   people, from Siberia to Brazil. Should the replacement vary by region? (See step 4.)

## Summary

- **30 Kenney files are live in Age of Discovery:** 15 hex tiles and 15 small object sprites. 8 more are named
  in the code but never drawn (dead references). Conquest and Colonisation add 10 more files of their own.
- **Everything else is code-drawn:** the sea, coasts, rivers, roads, towns, castles, goods tiles, landmarks,
  units, trees, mountains and animals at the near zooms, and the whole user interface.
- **Share of the screen that is Kenney art** (measured: Kenney pixels painted a marker colour, five 700 x 500
  views of Europe at Paris, the Alps, Castile, Poland and Norway; sea counts as code-drawn):

| Zoom (hex radius) | What draws the map | Kenney share of the screen |
|---|---|---|
| 3, 5, 8 (5 is the start zoom) | flat colour map | 0% |
| 13 | tile art (`MapView._draw_tiles`) | 36% |
| 21 | landscape composites (`landscape.py`) | 42% |
| 34 | landscape composites | 51% |

- **What that share is.** At zoom 13, 76% of land hexes are a whole Kenney tile (forest, hills, mountain,
  desert, steppe, tundra, native camp), 19% are our tiles with Kenney props on them, and 6% are goods tiles.
  At zooms 21 and 34, 93% of land hexes sit on a Kenney *ground texture* (plain grass, dirt, sand or stone),
  but every tree, hill, peak, field and house standing on it is code-drawn. So at the near zooms Kenney is
  "the paper", not the drawing. It is the biggest share of pixels and also the easiest part to replace.

## The table

Visibility: **high** = a large share of the screen at a common zoom; **medium** = many hexes at one zoom;
**low** = a few hexes or a small prop. Counts are Europe 1480 hexes (30,450 hexes, 14,411 land provinces).

### Hex tiles (`hexagon-pack/PNG/Tiles/`)

| File | Used for | Where in the code | Hexes | Visibility | Replacement |
|---|---|---|---|---|---|
| Terrain/Grass/grass_05 | plains, forest, hills and mountain ground (tinted) | `landscape.GROUND`; `data.TERRAIN_SPRITES` plains (zoom 13) | 5,685 at 21-34; 909 at 13 | **high** | new recipe: flat grass fill + seeded tufts (step 1) |
| Terrain/Grass/grass_19 | second variant of the same | as above | 3,214 at 21-34; 933 at 13 | **high** | same recipe, variant 2 |
| Terrain/Sand/sand_07 | desert and coast ground; base of `art._beach` | `landscape.GROUND` "sand"; `TERRAIN_SPRITES` desert | 1,392 at 21-34; 994 at 13 | **high** | flat sand fill + dune ripples (`landscape` already draws dunes) |
| Terrain/Sand/sand_19 | second desert variant | as above | 648 at 21-34; 1,001 at 13 | high | same recipe. Note: this tile has a baked brown cliff side, which shows as a wedge in some desert hexes |
| Terrain/Dirt/dirt_06 | steppe and savanna ground | `landscape.GROUND` "dirt"; `TERRAIN_SPRITES` steppe | 1,242 at 21-34; 268 at 13 | high | flat dirt fill + specks |
| Terrain/Dirt/dirt_19 | second dirt variant (a smaller blob shape) | as above | 602 at 21-34; 270 at 13 | medium | same recipe |
| Terrain/Stone/stone_07 | alpine and tundra rock ground | `landscape.GROUND` "alpine" | 604 at 21-34 | medium | flat rock fill + cracks |
| Terrain/Grass/grass_12 | forest, jungle (zoom 13 only) | `data.TERRAIN_SPRITES` | 2,100 at 13 | **high** at 13 | `nature.draw_tile` mixed/pine forest (step 2) |
| Terrain/Grass/grass_13 | forest, jungle (zoom 13 only) | `data.TERRAIN_SPRITES` | 2,119 at 13 | **high** at 13 | `nature.draw_tile` forest / jungle |
| Terrain/Grass/grass_15 | hills (zoom 13 only) | `data.TERRAIN_SPRITES` | 695 at 13 | medium | `nature.draw_tile` hills |
| Terrain/Grass/grass_14 | mountains (zoom 13 only) | `data.TERRAIN_SPRITES` | 624 at 13 | medium | `nature.draw_tile` mountain range |
| Terrain/Stone/stone_05 | tundra (zoom 13 only; sand centre on stone) | `data.TERRAIN_SPRITES` | 243 at 13 | low | new tundra tile: rock ground + moss + low shrubs |
| Terrain/Stone/stone_12 | tundra (zoom 13 only; stone with trees) | `data.TERRAIN_SPRITES` | 255 at 13 | low | same tundra tile, variant 2 |
| Terrain/Grass/lake | lakes at every near zoom | `landscape._base_name`; `MapView` lake fallback | 83 | low | `wfctiles.sea_tile` in a lake colour |
| Western/western_indians | native camps (zoom 13 only) | `data.NATIVE_VILLAGE_SPRITE`, `MapView.tile_sprite` | 476 at 13 | medium | `life.native_village` already exists (step 4) |

### Object sprites (`hexagon-pack/PNG/Objects/`)

All are loaded by `art._obj` and placed by our code-drawn tiles in `art.py`: the marsh, taiga, snow, savanna
and beach tiles (`art.make_tile`), and the zoom-13 decorations (`art.decoration`). At zooms 21-34 only the
marsh and snow tiles still use them (343 hexes).

| File | Used for | Where in the code | Visibility | Replacement |
|---|---|---|---|---|
| treePine_large, treePine_small | taiga trees (snow-capped), snow tile, "trees" decoration | `art._taiga`, `_snow`, `decoration` | medium (1,107 taiga hexes at 13) | `nature.pine_tall`, `pine_short`, `snowy_tall`, `snowy_short` |
| treeRound_small, treeRound_large | marsh trees, beach tree, "trees" decoration | `art._marsh`, `_beach`, `decoration` | medium | `nature.oak`, `beech`, `linden` (small sizes) |
| rockGrey_small1-5, rockGrey_medium1, rockBrown_small | snow and savanna rocks, beach rock, "rocks" decoration | `art._snow`, `_savanna`, `_beach`, `decoration` | low | `nature.stone`, `boulder` |
| log | marsh and beach detail | `art._marsh`, `_beach` | low | `goodsobjects.log_end` or a small code log |
| farmland, hay | "fields" decoration (54 hexes at 13) | `art.decoration` | low | `landscape` field systems already draw fields; reuse them |
| house_small | "hamlet" decoration (7 hexes at 13) | `art.decoration` | low | a `goodsart.building` house |

### Dead references (named in code, never drawn)

| Name | Where | Action |
|---|---|---|
| fence, tower (Objects) | `art._vineyard`, `_pasture`, `decoration` "town"/"city" | remove: `data.GOOD_SPRITES` is never read and no code asks for "town"/"city" decorations |
| medieval_house, medieval_church, medieval_openCastle, medieval_tower, medieval_smallCastle, medieval_largeCastle | `data.SETTLEMENT_SPRITES`, `data.CASTLE_SPRITES` | remove: towns and castles are drawn by `wfctiles` |
| (any Objects file) | `goodsart._spr` and `Tile.sprite` | remove: no goods tile calls it |
| grass_05, grass_12, grass_15, sand_07, stone_07 | `wfctiles.base_tile` | only test and mockup sheets use it; switch to the new grounds in step 1 |

## Replacement plan

In priority order: most screen share first, cheapest wins early. Sizes: S = up to a day, M = 2-3 days,
L = a week, for one worker plus an art review.

1. **Ground textures (M).** Replace grass_05/19, dirt_06/19, sand_07/19, stone_07 and lake with seeded,
   code-drawn ground fills: the pack's base colour, a lighter left half or soft light patches, and sparse tufts,
   specks or ripples. Keep the colours within a few points of the Kenney averages, because `landscape.py` tints
   them, blends wavy bands between them and takes their average colour for the hex rim. This removes about
   85-95% of the Kenney pixels at zooms 21 and 34, and fixes the sand_19 cliff wedge and the blob-shaped
   grass_19/dirt_19 edges. Deliver as an A/B sheet at every zoom first, then swap the names in
   `landscape.GROUND`, `data.TERRAIN_SPRITES` and `wfctiles.BASE_SPRITES`.
2. **Zoom-13 terrain tiles (M).** Replace grass_12/13/14/15 and stone_05/12 with `nature.draw_tile` tiles on the
   step-1 grounds, plus one new tundra recipe. The forest and mountain tiles are the most "Kenney-looking" art
   left, and today they do not match the code-drawn trees players see one zoom further in. Check that
   2,000+ forest hexes still read as forest at radius 13 (density, not detail).
3. **Props inside our own tiles (S).** In `art.py`, swap `_obj` calls for `nature` trees and stones, a code log,
   and a `goodsart` house. Re-check the taiga snow caps, which today whiten the Kenney pines in code.
4. **Native camps (S).** Draw the zoom-13 camp with `life.native_village` on the local ground instead of the
   western_indians tile. Option: vary tents by region (tipis, longhouses, huts). That needs the owner's call
   (question 3).
5. **Clean up dead references (S).** Remove the unused constants, art recipes and `goodsart._spr` listed above,
   so the audit stays honest. A code task for a worker; no art change on screen.
6. **Conquest and Colonisation (M, optional).** Map their terrain names to the new tiles from steps 1-2, and draw
   farm, lumber camp, mine, cabin, house, castle, warehouse and ruins in code (or reuse the `wfctiles` towns and
   castles). Only if those modes ship (question 2).

After steps 1-4, Age of Discovery would load no Kenney file. Add a test then that fails if `hexa/campaign/`
loads anything from `hexagon-pack/`, so new uses cannot creep back in.

## Conquest and Colonisation (frozen, lower priority)

Both draw every hex as a Kenney tile through `hexa/render.py` (`Renderer.sprite`). Units and borders are code-drawn.

- **Shared tiles:** grass_05, grass_19, dirt_06, dirt_19, grass_12, grass_13, grass_15, grass_14, lake
  (`hexa/rules.py`, `hexa/colony/rules.py`).
- **Conquest only:** Medieval/medieval_farm, medieval_lumber, medieval_mine (improvements),
  medieval_largeCastle (castle), medieval_house (town).
- **Colonisation only:** Sand/sand_05 and sand_19 (beach), Mill/mill_warehouse (fishery), medieval_farm,
  medieval_lumber (trapper), medieval_mine (silver mine), medieval_cabin, medieval_house, medieval_openCastle
  (colony sizes), Western/western_indians (villages), medieval_ruins (ruins).
- Visibility: **high** in those modes (close to 100% of the map), but the modes are frozen and not the Steam
  focus.

## Licence

The Kenney Hexagon Pack is CC0 (public domain dedication). We may use, change and sell it, on Steam too, with no
attribution needed. Crediting Kenney is still good practice, and the game already does it: the main menu
credits box and the README both name the pack and its CC0 licence. Keep that credit while any Kenney file ships.
If every file is replaced, a "thanks to Kenney for the original style" line in the credits is a kind touch, and
the `hexagon-pack/` folder can then leave the Steam build (keep it in the repo for the frozen modes if needed).

## How this was measured

- Code search for every place that loads a pack file (`TILES_DIR`, `hexagon-pack`, `Objects`, `.png`,
  `image.load`) in `hexa/`.
- Hex counts: `MapView.tile_sprite` (zoom 13) and `landscape._base_name` (zooms 21-34) over every hex of a new
  Europe 1480 world.
- Screen share: full `MapView.draw` frames with every pack image recoloured to a marker colour on load, and the
  marker pixels counted. Season: the 1480 start. Fog: none (no player). Units and labels count as code-drawn.
