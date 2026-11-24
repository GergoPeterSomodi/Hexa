# godot/data: the data the Godot project reads

The numbers and the geography are written once from the frozen Python game (v0.2.2 model) by the exporters in `tools/`; the `worldmap/` files are the map prototype's own data. The Godot project reads these
files; it never imports Python. Every file is UTF-8 JSON, written with Python's `repr` floats (shortest exact form),
so each float reads back to the same double. Each file has a `schema` key (`hexa-godot/<name>/1`); a change of
shape bumps the number.

Regenerate (only if an exporter had a mistake):

    python tools/export_data.py
    python tools/export_geography.py

`tests/test_godot_export.py` runs the exporters into a temporary folder and checks that the committed files are
byte-for-byte what they write, that the counts are right, and that the floats round-trip.

Conventions: points are `[longitude, latitude]` in degrees; hexes are `[column, row]`; colours are `[r, g, b]`
(0..255); a missing value is `null`; levels are integers from 0 (none) upwards. Lists keep the Python order, which
the builder relies on (`geo.COUNTRIES` order, `geo.CITIES` order, the row-by-row hex order).

## Files

| File | Size (bytes) | What it holds | Exporter |
|---|---|---|---|
| `constants.json` | 630 | area, scale, years, seasons, eras, map seed (1480), territory radius, garrison | export_data |
| `terrain.json` | 2,775 | 15 terrain kinds (lake and ocean included), rough, narrow, open ground, elevation | export_data |
| `goods.json` | 5,616 | 32 goods, foods, farm goods, needs, output, price floor and cap, elasticity | export_data |
| `buildings.json` | 8,769 | buildings, manufactories, works (investment levels), settlements (village, town, city), castles | export_data |
| `units.json` | 10,212 | unit kinds (all), troops by branch and era, stack limits, manpower | export_data |
| `countries.json` | 8,008 | 49 countries: tag, name, colour, capital; colonial start turns; coastal knowledge | export_data |
| `wfc.json` | 1,505 | forbidden neighbour pairs, the affinity used by the builder, the default affinity, the terrain seed | export_data |
| `geography/projection.json` | 632 | Mercator projection constants (computed values, exact) | export_geography |
| `geography/land.json` | 28,603 | land outlines (7 masses, 17 islands), lakes, seas, forced sea and land points | export_geography |
| `geography/terrain_shapes.json` | 7,739 | deserts, steppes, Maghreb, marsh boxes, hills, fertile rivers, 18 mountain lines with heights | export_geography |
| `geography/rivers.json` | 9,664 | 35 rivers as polylines | export_geography |
| `geography/passes.json` | 1,874 | 24 named passes | export_geography |
| `geography/cities.json` | 8,199 | 102 cities with size | export_geography |
| `geography/countries.json` | 10,308 | 49 country tags with their territory seed points (the capital first) | export_geography |
| `geography/markets.json` | 3,690 | 41 market towns (colonial flag) | export_geography |
| `geography/tribes.json` | 3,645 | 56 native peoples with their point | export_geography |
| `geography/regions.json` | 58,870 | 684 regions (name, point, country tag) and the city-to-region table | export_geography |
| `geography/naming.json` | 4,428 | compass words, anchor weights, exonyms, skip list, landform words | export_geography |
| `geography/placenames.json` | 302,333 | 6,940 real places with the GeoNames credit | export_geography |
| `worldmap/region_alps_po.json` | | the north Italy map's skeleton: the window, the grid, rivers, lakes, places and gorges (by hand) | by hand |
| `worldmap/heights_alps_po.json` | | the per-hex heights of the same window | `tools/worldmap/extract_heights.py` |
| `worldmap/shoreline_alps_po.json` | | the real coast lines of the window in km (the style frame's coast, carved ports included) | `tools/worldmap/export_shoreline.py` |
| `worldmap/height_grid_alps_po.json` | | a fine height raster of the window (4 samples per hex width, ETOPO 2022, NOAA) | `tools/worldmap/export_height_grid.py` |

Total about 0.7 MB. No file is gzipped (none is large enough to need it).

## Schemas

**constants.json**: `area` (provinces per original province, 4), `scale` (2), `start_year` (1480), `end_year` (1650),
`seasons` (4 names), `eras` (list of `{era, name, start_year, third}`; `third` is the unused third field of
`data.ERAS`), `map_seed` (1480: the Python Europe seed), `territory_radius` (8), `garrison_hp`, `garrison_men`, `men`.

**terrain.json**: `terrain` (list of `{key, name, color, move, defense, density}`): `move` is the land movement
cost, `null` = not walkable (lake, ocean); `density` is people per hex in thousands, already divided by `area`.
`rough`, `narrow`, `open_ground` are lists of keys; `elevation` maps key to height.

**goods.json**: `goods` (list of `{key, name, price, color, kind}`; `kind` is food, raw, made, luxury or money),
`foods`, `farm_goods`, `needs` (class -> good -> amount per 1,000 people), `output` (good -> raw output per 1,000
peasants), `price_floor`, `price_cap`, `elasticity`.

**buildings.json**: `buildings` (list of `{key, name, cost, max_level, upkeep, hint, needs_coast, needs_burghers,
inputs, outputs}`), `manufactories`, `plantation_goods`, `mine_goods`, `build_turns`; `works` = `{levels, bonus,
cost, goods, era, upkeep, level_names}` (`level_names` maps a good to its five level names; the builder uses the
names for the tile art only); `settlements` = list of `{level, name, cost, goods, pop, slots, tax, upkeep}` for
levels 0 to 3 (level 2 is a town, 3 a city); `castles` = list of `{level, name, cost, goods, upkeep, area}` for
levels 0 to 3 (1 tower, 2 small castle, 3 large castle); `castle_defense`, `castle_siege`.

**units.json**: `unit_kinds` (all unit kinds: `{key, name, moves, sight, naval, capacity, gold, goods, upkeep, branch,
era, hp, attack, defense, range, siege, needs}`), `troops` (the nine war units, in data order), `branches`,
`branch_names`, `general`, `stack` (`{base, limit_by_era (keys are "1", "2", "3"), general, civilian, front}`),
`manpower`, `food_per_troop`, `colonist_people`. `troop(branch, era)` in data.py is the lookup: the troop with that
branch and era.

**countries.json**: `countries` (list of `{tag, name, colour, capital: {lon, lat}}`, in `geo.COUNTRIES` order),
`colonial_start` (tag -> turn; a country not listed has none: `starting_units` uses 999 as its default), `coastal_knowledge`,
`known_world_rule` (text of the Python lambda; the numbers are in it).

**wfc.json**: `forbidden` (list of `[tile, tile]` pairs that may not touch; symmetric), `affinity_in_build_map` (1.6,
the value `build_map` passes), `affinity_default` (1.5, the value of `wfc.collapse` when none is passed),
`rng_seed_for_terrain` (text: `world.seed`, see `constants.json`).

**geography/projection.json**: `start` ([8, 46], the camera start), `lon0`, `lon1`, `lat_top`, `lat_bottom`, `scale`,
`col_deg` (1.45 / scale), `row_deg` (col_deg times 0.8660254), `y_top` (Mercator of lat_top), `cols` (203), `rows`
(150). Use these exact doubles; do not recompute them.

**geography/land.json**: `landmasses` (list of `{name, points}`: europe_asia, scandinavia, britain, ireland, africa,
north_america, south_america), `islands` (17 `{name, points}`), `lakes` (5 `{points}`), `seas` (2 `{points}`),
`force_sea` (points), `force_land` (18 points). Polygons are closed by the builder (no repeated first point).

**geography/terrain_shapes.json**: `deserts`, `steppes`, `maghreb` (lists of polygons), `marshes` (list of
`{lon0, lat0, lon1, lat1, k}`, a box with the marsh share `k`), `hills` (polylines), `fertile_rivers` (polylines),
`mountains` (18 `{line, height}`; `height` from the Python table, `default_height` 0.6 for a line past the table),
`default_height`.

**geography/rivers.json**: `rivers` (35 `{name, points}`, in `geo.RIVERS` order).

**geography/passes.json**: `passes` (24 `{name, lon, lat}`). The game's 72 pass hexes and 47 pass edges are derived
from these and the mountain lines by the builder (`terrain.passes`, `terrain.pass_edges`).

**geography/cities.json**: `cities` (102 `{name, lon, lat, size}`), in `geo.CITIES` order.

**geography/countries.json**: `countries` (49 `{tag, seeds}`): `seeds` are the territory seed points in order, the
first being the capital. Names and colours are in `countries.json` (data).

**geography/markets.json**: `markets` (41 `{name, lon, lat, colonial}`).

**geography/tribes.json**: `tribes` (56 `{name, lon, lat}`).

**geography/regions.json**: `regions` (684 `{name, lon, lat, tag}`; `tag` null when no country held it),
`city_region` (city name -> region name).

**geography/naming.json**: `compass` (8 words), `own_weight` (0.7), `sea_penalty` (10.0), `anchor_cell_degrees` (4.0),
`exonyms` (modern name -> 1480 name), `skip` (list), `land_words`, `coast_words`, `river_words`.

**geography/placenames.json**: `credit` (`{text, source, url, licence, licence_url, note}`), `places` (6,940 rows of
`[longitude, latitude, name]`, biggest first). **The GeoNames credit (CC BY 4.0) must appear in the credits file of
the Windows zip.** The credit text is copied from the Python module.

## Notes for a map builder that reads these files (kept from the 0.3.0 work)

1. **The random stream.** Python uses `random.Random(seed)` with `random()` and `choices()`, and the builder draws in
   a fixed order. GDScript's generator is different, so Godot's Europe will not be Python's terrain hex for hex, and
   nothing in the terrain, goods or the random population factors can be matched hex by hex. This is why the map check
   compares counts and the hard hex facts only (classes, cities, rivers, ridges, passes, castles 2 and 3, towns 2 and
   3, owners by country). Keep one `rng.gd` seeded from the map seed; do not try to copy Python's numbers.
2. **Order.** Python sets are not ordered; the builder sorts where it matters (`sorted(land)` for the wave function,
   `sorted` in the pass lists). Where Python iterates a dict, the order is insertion order: the terrain dict is filled
   row by row (`for r`, then `for c`), countries in `geo.COUNTRIES` order, provinces in sorted position order. Keep
   these orders in GDScript or the random draws land in different places.
3. **72 passes against 24.** `geo.PASSES` lists 24 named passes; the game has 72 pass hexes (`terrain.passes`) and 47
   pass edges. The derived ones are the builder's job, not the data's.
4. **Floating-point maths.** Mercator uses `log`, `tan` and `degrees`; Godot's doubles agree to the last digit in
   almost all cases but not guaranteed. The committed map file is what the builder makes (docs/architecture/godot-architecture.md section 4.2).
5. **Art.** Sprite names are not exported (the Python art baker and the art inventory own them). Colours of terrain and
   goods are exported; the tile art is not.
6. **Random worlds** are not exported (not in 0.3.0).
7. **The tech tree and the special goods' art** are not in this release (0.3.1 and later).
8. **Place names.** `naming.name_europe` takes the three biggest places per hex from `placenames.json`, then the
    region names. The 1480 names of exonyms are in `naming.json`.

## Definitions and Scenarios (`defs/`, `scenarios/`)

Godot text `.tres` resources read by `core/defs/` and validated in CI:

| Path | Resource | Contents |
|---|---|---|
| `defs/game_defs.tres` | `GameDefs` | Master catalog: references the 13 countries, `north_italy_1480`, the 16 goods, plus heraldic `tinctures`, the 8-colour Okabe-Ito `cb_palette`, `unowned_colour`, neighbour contrast thresholds (`min_contrast = 30.0`, `min_contrast_cb = 20.0`), and the M4 economy numbers (M4 spec 4.6 to 4.12, 5.1): covers' `wild_good` and `wild_yield`, `country_people`, tax levels, weather odds, port and fishing percents, start treasury, and the M5 people numbers (M5 spec 4.4, 5.1): `growth_bp`, `growth_percent`, `hunger_bp`, `hunger_percent`, `left_bp`, `town_floor`, `people_top_level`, `levy_permille`. From M6 (M6 spec 4.2, 4.3, 5.1) the 4 `units` and 8 `terrains`, the step cost numbers (`relief_move_add`, `highway_cap`, `road_cap`, `track_divisor`, `winter_snow_percent`, `pass_closing_climate`, `stream_cost`, `river_cost`, `ford_cost`, `ferry_cost`, `river_wade_class`, `river_wall_class`, `wade_plan_cost`), supply and forage (`supply_reach`, `supply_wade_cost`, `depot_min_level`, `army_food_milli`, `forage_percent`, `forage_loss_permille`, `starve_permille`) and the march and sight numbers (`stack_limit`, `march_seasons_max`, `wait_ratio_percent`, `wait_extra_seasons`, `land_sight`). |
| `defs/goods/<key>.tres` | `GoodDef` | The 16 goods of the economy (M4 spec 4.2, 5.1), id 0 to 15 in order (`grain`, `fish`, `oil`, `wine`, `salt`, `hemp`, `silk`, `dyes`, `wool`, `cattle`, `horses`, `timber`, `stone`, `iron`, `copper`, `silver`): key, name, kind, fixed price (thousandths of a ducat), need, weight, food order, fixed reserve, harvest word, icon. From M6 (spec 5.1) horses keep a fixed reserve of 10 and copper of 5 (any ware may have one; food and staples may not). |
| `defs/families/<key>.tres` | `FamilyDef` | The 14 works families (M3 spec 4.3, 5.1): id, key, `work_seasons` by level, `clear_seasons`. From M4 (spec 4.4, 5.1): the good made (or `by_extra` for grazing and mines, with `extra_permille`), `base` and `season_percent` for goods families, `weather_bound`, `keep_wild`, `jobs`, `upkeep`, `walls`, `cost` and `cost_goods`, the card's `ground_text`; settlements add `people`, `ring_lift`, `port_fish`, `port_dues`; from M5 (spec 4.5, 5.1) `room` and `falls_below` by level, and the costs of levels 2 and 3 are 60 and 200 ducats (M4: 100 and 300, spec 4.6). From M6 (spec 5.1) settlements add `raise_cap`, the companies a season it may raise by level (0, 1, 1, 2, 3, 4). From M7 (spec 4.3, 5.1) settlements and castles add `fortress`, the fortress level of each level's piece (settlements 0, 0, 0, 0, 2, 3; castles 0, 1, 2, 3); the goods families have none. |
| `defs/countries/<tag>.tres` | `CountryDef` | One file per country, lowercase 3-letter tag (`fra`, `aus`, `swi`, `sav`, `mlo`, `ven`, `gen`, `tus`, `pap`, `man`, `fer`, `sie`, `luc`): names, sRGB colour, off-map `capital_name`, heraldic arms (`arms_division`, `arms_field`, `arms_charge`), and pick `tip`. |
| `defs/units/<key>.tres` | `UnitDef` | The 4 kinds of company (M6 spec 4.2, 5.1), id 0 to 3 in order (`pikemen`, `crossbowmen`, `knights`, `bombards`): names (one, many), branch, men, raise cost and goods, upkeep, move points, sight, the settlement level that raises it, refill, figure icon. From M7 (spec 4.6, 5.1) also the war numbers `attack`, `defence`, `fire_permille` and `siege_points`. |
| `defs/war.tres` | `WarDef` | The war's numbers (M7 spec 4.3 to 4.9, 5.1), one inspector: the fight tables by branch and the stances, the dice, the morale and day numbers, the ground and rank numbers, garrisons, sieges, occupation, peace and the truce, and the odds words and ground factors. `war_tables.gd` prints its three tables. |
| `defs/ai.tres` | `AiDef` | The numbers every computer country shares (M8 spec 4.4, 5.1): how often it thinks of war, the smallest armies, the ranges it weighs, the works scan, raises a season, the payback priorities and the yield ratio. `ai_tables.gd` prints it. |
| `defs/tempers/<key>.tres` | `AiTemperDef` | The 5 temperaments (M8 spec 4.4, 5.1): `builder`, `cautious`, `steadfast`, `aggressive`, `opportunist`; the reserve, payback, army sizes and mix, and every ratio and span of its wars and peace. `ai_tables.gd` prints the grid. |
| `defs/terrain/<key>.tres` | `TerrainDef` | The 8 grounds (M6 spec 4.3, 5.1), id = the map's cover number 0 to 7 (`farmland`, `grassland`, `woods`, `marsh`, `rock`, `snow`, `tundra`, `sand`): move points to enter and forage permille. From M7 (spec 4.6, 5.1) also `defence_permille`, `rough` and `narrow`. |
| `scenarios/north_italy_1480.tres` | `ScenarioDef` | The 1480 scenario (`Italy, 1480`) on `maps/north_italy.tres`: country order, capitals, colour-blind palette indices, town/anchor `seeds`, `pins`, growth parameters, the grown `owner` array + `map_digest`, and (M8 spec 4.4, 5.1) `tempers`, one `defs/tempers` key a country in country order, and `start_armies` (empty in 1480). `tempers` and `start_armies` are written by hand; `build_scenario.gd` keeps both when it regrows `owner`. `regions` (names; index 0 is the first) and `discovery` (one `{tag, regions}` entry a country, fog spec R5) are written by hand; `region` (one byte a hex: the region's index + 1, 0 for none) is written by `build_scenario.gd` from its region source (north Italy: every hex is `europe`), and `--check` compares it. |

Whenever `maps/north_italy.tres` or the scenario seeds, pins, or growth constants change, regrow `owner` and `map_digest` and verify everything passes deep validation:

    godot --headless --path godot -s tools/build_scenario.gd
    godot --headless --path godot -s tools/build_scenario.gd -- --check

`build_scenario.gd --check` runs in CI and exits non-zero if `owner`, `map_digest`, `region`, or any validation or contrast rule is out of date.
