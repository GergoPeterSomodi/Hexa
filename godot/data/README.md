# godot/data: the contract for the Godot map builder

Written once from the frozen Python game (v0.2.2 model) by the exporters in `tools/`. The Godot project reads these
files; it never imports Python. Every file is UTF-8 JSON, written with Python's `repr` floats (shortest exact form),
so each float reads back to the same double. Each file has a `schema` key (`hexa-godot/<name>/1`); a change of
shape bumps the number.

Regenerate (only if an exporter had a mistake):

    python tools/export_data.py
    python tools/export_geography.py
    python tools/export_map_reference.py      # about 15 s: builds the Python Europe at 8 seeds

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
| `rules/builder_functions.json` | 108,381 | the Python builder's functions as steps (see below) | export_data |
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
| `map_reference.json` | 102,589 | the Python Europe measured at seeds 1480 and 1 to 7 (the check, see below) | export_map_reference |

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
from these and the mountain lines by the builder (`terrain.passes`, `terrain.pass_edges`); the map reference counts them.

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

**map_reference.json**: `equal` (facts that must match Godot's Europe exactly: `{value, same_in_all_seeds}`, plus
`per_seed` if the seeds disagree), `close` (counts that luck moves: `{value, min, median, max}` over the eight seeds;
per-country and per-kind facts are maps of the same), `hexes_1480` (per-hex facts of seed 1480: `class_rows`, one
string per row of `L` land, `O` ocean, `K` lake, one character per hex; `owner_rows`, one string per row with a
code per hex from `owner_codes` (`_` = none)). The Python values are the reference numbers of the brief's "The new
Europe is checked" section; the rules for "close" values are applied by the checker, not by the exporter.

## rules/builder_functions.json: the Python builder as steps

Some of the builder is code, not numbers: the terrain priors, the goods rules, the population factors, the road
search, the naming. Retyping them would invite drift, so the exporter reads them from the Python source with the
`ast` module (nothing is run) and writes each function as a list of steps. Keys are `hexa/...py::name`; each entry
has `file`, `name`, `line` (the Python line of its `def`), `params` and `steps`.

A step is an object with `when` (a list of if-test texts that must all hold; an `else` branch is the negated test,
written `not (...)`), and an `op`:
- `assign`: `var` = `value`
- `set`: `var[key]` = `value` (the Python dict `var` is a Godot Dictionary)
- `return`: the function returns `value`
- `loop`: `head` (the `for` or `while` line as text) and `body` (its steps, run per iteration)
- `stmt`: any other statement, as source text (`continue`, `break`, a lambda, a call)

A value is a literal, `{"name": x}` (a local or parameter), `{"dict": [[k, v], ...]}`, `{"list": [...]}`, or
`{"expr": "source text"}`. Port the steps in order: a `return` ends the function, so a later step is reached only when the earlier returns did not fire. An `expr` is Python source to be written in GDScript by hand.
The functions are: `hexa/hexgrid.py` (neighbours, cube coordinates, distance, within); `geo.py` (all: Mercator,
`lonlat`, `hex_of`, the outline tests, `land_cells`, the desert, steppe, Maghreb and marsh tests, the distances);
`systems/worldgen.py` (all: `build_map`, `trace`, `near_line`, `terrain_prior`, `good_for`, `build_countries`,
`build_roads`, `starting_units`, the ridge and pass functions); `systems/terrain.py` (`pass_tables`, `ridge_edges`,
`pass_edges`, `passes`, `pass_name`, `geo_key`); `naming.py` (all: anchors, regions, labels, unique names, the
Europe names); `specialgoods.py` (`special_good`); `wfc.py` (`collapse`).

## What the builder cannot take straight from the data (read this before porting)

1. **The random stream.** Python uses `random.Random(seed)` with `random()` and `choices()`, and the builder draws in
   a fixed order. GDScript's generator is different, so Godot's Europe will not be Python's terrain hex for hex, and
   nothing in the terrain, goods or the random population factors can be matched hex by hex. This is why the map check
   compares counts and the hard hex facts only (classes, cities, rivers, ridges, passes, castles 2 and 3, towns 2 and
   3, owners by country). Keep one `rng.gd` seeded from the map seed; do not try to copy Python's numbers.
2. **Order.** Python sets are not ordered; the builder sorts where it matters (`sorted(land)` for the wave function,
   `sorted` in the pass lists). Where Python iterates a dict, the order is insertion order: the terrain dict is filled
   row by row (`for r`, then `for c`), countries in `geo.COUNTRIES` order, provinces in sorted position order. Keep
   these orders in GDScript or the random draws land in different places.
3. **Numbers inside the steps.** The population factors, the burgher and noble shares, the natives' factors and the
   road reaches (14, 16 and 9 times `SCALE`) are literal numbers in the steps of `build_countries` and `build_roads`.
   They are Python literals in the steps, not named constants: port them as written.
4. **72 passes against 24.** `geo.PASSES` lists 24 named passes; the game has 72 pass hexes (`terrain.passes`) and 47
   pass edges. The derived ones are the builder's job, not the data's.
5. **Floating-point maths.** Mercator uses `log`, `tan` and `degrees`; Godot's doubles agree to the last digit in
   almost all cases but not guaranteed. The map file is made once in CI and shipped; other machines check counts
   (brief, risk 7).
6. **Art.** Sprite names are not exported (the Python art baker and the art inventory own them). Colours of terrain and
   goods are exported; the tile art is not.
7. **Random worlds** are not exported (not in 0.3.0).
8. **Lambdas and text rules.** `KNOWN_WORLD` and the `near` helper inside `good_for` are Python lambdas; their text is
   in the data (`known_world_rule`, and the `stmt` steps of `good_for`).
9. **The tech tree and the special goods' art** are not in this release (0.3.1 and later).
10. **Place names.** `naming.name_europe` takes the three biggest places per hex from `placenames.json`, then the
    region names. The 1480 names of exonyms are in `naming.json`.
