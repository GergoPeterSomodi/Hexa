# Normal-map pieces: the tools

The rule book is `docs/design/map/pieces/GUIDE.md`. Read it first, then look at `wheat.py` and `settlements.py`:
they are the pattern to copy.

## Files

| File | What |
|---|---|
| `kit.py` | The shared kit: canvas, hex mask, palette, season colours, primitives, the sheet helper. **Do not edit it** in a family task; report what is missing |
| `wheat.py`, `settlements.py` | The two reference families |
| `<family>.py` | One module per family: `castles`, `vineyard`, `olives`, `grazing`, `salt`, `mines`, `timber`, `harbour` |
| `contract.py` | The kit's map contract on one page (`kit_contract.png`): wild land, coast sides, footprint, mirror, `pick`. Its `fishing()` is the pattern for a coast piece |
| `families.py` | The list of the sixteen families, for the pages that show them all |
| `overview.py` | Every family on two pages: `overview.png` (summer, with the ores, sites and landmark cities) and `overview_2.png` (the snow winter, the layouts, the coasts) |
| `crowding.py` | The look-alike review: `crowding.png` (everything at 50%, summer and the three winters) and `crowding_pairs.png` (the pairs of guide section 4, 50% and 100%) |
| `winters.py` | The three winters for all sixteen families (`winters.png`) and the two port modes (`ports.png`) |
| `additions.py` | The kit's additions of rounds 4 and 5 on one page (`kit_additions.png`): `drystone`, `ring`, `arc`, the mulberry, the new crops and tokens, `pick` with three layouts; `stockade`, `tent`, `bale`, `hold`, `dots`, the cypress, the domes and the minaret, plain and mirrored |
| `quarry.py`, `dyes.py`, `hemp.py`, `silk.py`, `furs.py`, `cotton.py`, `sites.py` | The families of round 4 |
| `landmarks.py` | The monuments of the ten landmark cities, called by `settlements.draw(landmark=)` |

## The module contract

```python
LEVELS = range(0, 4)                 # settlements range(1, 6), castles range(1, 4)
NAMES = {0: "wild land (the map's)", 1: "...", ...}    # a short name per level, for the sheet
VARIANTS = 2                         # layouts in this module (1 until the second layout is drawn)
GATES = {"south": (x, y), ...}       # where the piece's lane ends, 10 px inside the border (unmirrored)

def draw(level, season, variant=0, mirror=False):     # season: "spring" | "summer" | "autumn" | "winter"
    if level == 0:                   # no piece on the map; on the sheet: the wild land as the map draws it
        return kit.wild(season, "grass", seed=N)
    p = kit.Piece(season, ground="grass", seed=N, mirror=mirror)   # one seed and one ground per family
    L = LAYOUT[variant]              # the layout tables: one dict per layout
    ...                               # ground-plane calls first, then standing things, then season details
    return p.finish(label="family L%d" % level)     # a 112x112 pygame.Surface with alpha
```

- **The piece draws only the work.** No wild trees, bushes, scrub, tufts or stones: the map draws the wild land and
  thins it under the piece's footprint (the kit measures the footprint from what you draw).
- **Mirror**: pass `mirror=mirror` on and draw in unmirrored coordinates. The kit turns the ground round and moves
  each standing thing to its mirrored place without flipping it, so the light stays upper left. Never write
  `if mirror:`. Landmark functions `return p.stand(y, fn)`; a part of another thing gets `on=<that handle>`.
- **Coast families** also take `sea=None, shore=None, bay=None`, pass them to `kit.Piece`, call
  `shore = p.coast(...)` once and place everything at the water's edge with `shore.pt(u, v)` (u along the shore, v
  out to sea). In a carved port `shore.bay` is set (a `kit.Bay`: `u0`, `west`, `east`, `pt(u, v)` from the mouth
  line, `room(u)`, `uv(u, v)`); on an open shore it is `None`.
- **Winter**: the module is called `draw(level, "winter")` in every climate; the kit knows the hex's winter. Ask
  `p.winter` before drawing snow (False in a mild winter), `p.frozen` before drawing ice, and `season == "winter"`
  for what the season does. Colours only from `p.pal` and `kit.crop`.
- Extra keyword arguments with defaults are allowed (`animal="sheep"`, `flag=kit.FLAG`, `addon=False`, `ore=None`,
  `landmark=None`). The default must be the picture the module drew before the keyword existed.
- `VARIANTS = 3` where a family has a third layout (vineyard, grazing, castles). In `sites.py` the variant is the
  site (`VARIANTS = 6`); the map gives it from its data and takes only the mirror from `kit.pick`.
- Positions are fixed tables at the top of the module. No position may depend on the season. Random numbers only
  from a fixed seed, never from the season or the level.
- Running the module writes both sheets: `kit.sheet(draw, LEVELS, title, path, NAMES, ground="...", wild=True)` and
  `kit.variant_sheet(draw, LEVELS, title, "<family>_variants.png", NAMES, ground="...")`.

## Running

Python with pygame is needed; nothing else, and no data files. From the repository root:

```
python tools/worldmap/pieces/wheat.py            # writes docs/design/map/pieces/wheat.png
python tools/worldmap/pieces/wheat.py out.png    # or any other path
```

A line `PIECE PROBLEM <label> <season>: N px ...` means a standing thing leaves the hex margin: move it in.

## Output naming

- Sheets: `docs/design/map/pieces/<family>.png` (grazing: `grazing_sheep.png`, `grazing_cattle.png`,
  `grazing_horses.png`) and `<family>_variants.png`.
- Single pieces, when the game needs them later: `<family>_L<level>_<season>.png`, 112x112, hex centred.
- Trial pictures and crops go in your own scratch folder, not in the repository.

## The kit in one page

Coordinates are 100% pixels from the hex centre (x right, y down; the hex is 104 wide and 102 tall).

**Ground plane** (drawn at once, in call order)

| Call | Draws |
|---|---|
| `p.scrub(x, y, w, h, dark=0.07)` | A darker patch of the ground itself (scrub, where work will come): an overlay |
| `p.blob(x, y, w, h, col, alpha=, edge=)` | A soft ellipse: trodden or cleared ground (give `alpha`), a mound or disc (give `edge`) |
| `p.over(fn, alpha)` | Any ground drawing `fn(pen)` laid half-transparent |
| `p.patch(pts, col, ink)` | A flat shape (a yard, a pan) |
| `p.field(cx, cy, w, h, angle, cols, strips, furrows=)` | A block of strips; returns its corners |
| `p.rows(cx, cy, w, h, angle, n, dashed=)` | Plant rows on a soil block |
| `p.hedge(pts)`, `p.fence(pts)`, `p.terrace(pts, face=)` | Lines on the ground; `face=2` gives a terrace wall a visible front |
| `p.drystone(pts, closed=)` | A grey dry-stone field wall (upland pastures); a thin line: put a meadow patch inside |
| `p.ring(cx, cy, rx, ry=, kind=, gate=, claim=)` | A round pen: `kind="fence"` a paddock, `kind="stone"` a sheepfold; `gate` an angle in degrees (90 = the front); claims its inside |
| `p.arc(cx, cy, rx, ry, a0, a1, col=, lw=, dashed=)` | A curved plant row (contour rows), angles in degrees |
| `p.road(pts, w, track=)`, `p.water(pts, w)`, `p.pond(pts, col=, edge=)` | Roads, streams and canals (frozen in winter), ponds. Tracks are overlays |
| `p.coast(y0)` | The shore the map gave (`Piece(sea=, shore=)`; in front on the sheets). Returns a `Shore`: `pt(u, v)`, `at(u, v, du, dv)`, `rect(u, v, w, h)`, `land(x, y)`, `depth`, `front`, and for tall things `fits(u, v, tall, wide)`, `fit(...)` (slides towards the shore, or `None`), `first(spots, tall, wide)`. Draws a sea on the sheets only |
| `p.claim(pts)` | Ground the piece holds without drawing on it (a court, a square): it counts for the footprint. `p.wall` claims the inside of its ring |
| `p.hold(points, side=3.5, back=4, front=8)` | The claim round a row or group of low things (bales, frames, vats, low trees): no wild tree behind them with its crown over them, none in front |
| `p.dots(points, col, size=1)` | Dots lying on the ground (bolls, blossom, crumbs); no footprint |
| `p.jetty(a, b, stone=, snow=)` or `p.jetty([pts], ...)` | A jetty, quay or mole; a list of points makes a bent mole; `snow=True` caps it in winter |
| `p.tufts(n, avoid=)`, `p.stones(spots)`, `p.scree(n)` | Ground scatter |
| `p.snow_patch(x, y, w, h)` | A drift (winter only) |

**Standing** (queued, drawn back to front by foot y)

| Call | Draws |
|---|---|
| `p.tree(x, y, sc, kind, i, bare=)` | `round`, `conifer`, `poplar`, `bush`, `olive`, `fruit`, `mulberry`, `cypress` (evergreen in every winter). `bare=True`: leafless in any season |
| `p.house(x, y, w, h, roof_h, wall, kind, roof, door, smoke)` | `kind`: `ridge` or `gable`; `roof`: `tile`, `thatch`, `slate` |
| `p.church(x, y, size, sc, roof=)` | `chapel`, `church`, `cathedral`; `roof`: `tile`, `slate`, `thatch` |
| `p.tower(x, y, w, h, col, top, flag)` | `top`: `battlement`, `cone`, `flat` |
| `p.wall(cx, cy, rx, ry, kind, towers, gate, back_towers, col=, tower_col=, tower_top=, tower_roof=)` | A ring wall: `palisade` or `stone`; `col=kit.STONE_GREY` for castles; `tower_top="cone"` caps every tower |
| `p.stockade(pts, kind=, height=, col=, closed=, posts=, claim=)` | A straight-sided wall along the points: `palisade`, `stone` or `low`. Unmirrored points; the kit turns the plan round and lights each side anew. Leave a side out for an open front |
| `p.bale(x, y, w, h, col=, band=, lift=)`, `p.tent(x, y, w, h, col=, poles=)` | The standard bale (`lift` stacks it) and tent |
| `p.boat(x, y, sc, sail)` | A ship (1.0), a fishing boat (0.7) or a small boat on the beach (0.55) |
| `p.person(x, y, col)`, `p.animal(x, y, kind, flip, sc=, col=)` | `sheep`, `cow`, `horse`; `sc=0.7` for young, `col` for another coat |
| `p.haystack(x, y)`, `p.heap(x, y, w, h, col)`, `p.logs(x, y, n)` | Stacks, cone heaps, log piles |
| `p.smoke(x, y, always=, foot=)` | Smoke (autumn and winter only; `always=True` for the listed chimneys). Never call `kit._smoke` |
| `p.stand(y, fn, lift=, x=, on=)` | Returns a handle. Your own landmark: `fn(pen)` draws with `pen.poly`, `pen.rect`, `pen.box`, `pen.line`, `pen.lines`, `pen.circle`, `pen.ellipse`, `pen.dot`, and for monuments `pen.dome(x, y, w, h, col, col_d, snow=)`, `pen.onion(...)`, `pen.minaret(x, y, h, w=, col=, cap=)` |
| `p.cast(x, y, w)` | The ground shadow for your own landmark |

**For the map.**

| Call | Gives |
|---|---|
| `kit.take_apart(draw, level, season, hex=(col, row), sea=, shore=, bay=, climate=)` | The piece without its ground base, as layers: `ground` (the detail, 2x), `shadow`, `standing` (`(foot_y, order_y, fn)` back to front), `footprint` (a mask: the map draws no wild tree or bush with its foot in it), `shore`, `mirror`, `variant`. **Level 0 gives `None`.** Layout and mirror come from the hex. Works with every module as it is |
| `kit.winter_of(lat, height_m, sea_km)` | The hex's winter: `"snow"`, `"frost"` or `"mild"` (give it as `climate=`); `kit.cold_index(...)` is the number behind it |
| `kit.carve(sea, shore, (u0, width, depth))` | A carved port: the shore with the bay cut in, as a `Shore`; the map turns to sea what is not `.land(x, y)`, then hands the piece the new shore line and the same `bay=`. `kit.BAY_WIDTH`, `BAY_BACK`, `BAY_REACH` are the bay's size and limits (5 km, carved ports only; `kit.COVE_REACH` is the 3.5 km of every other coast change) |
| `kit.pick(col, row, variants)` | `(variant, mirror)` for a hex: always the same; with two layouts no two neighbours equal; with three each of the grid's three classes shows its own layout |
| `kit.in_footprint(mask, x, y)` | True if the piece-px point is in the footprint |
| `kit.mirror_gates(GATES, mirror, variant)` | The gate points as they lie in a mirrored piece; `GATES` is one dict, or a list with one dict per layout |

**For the sheets.** `kit.with_wild(draw, level, "winter", climate="mild")` shows a piece in another winter and
`kit.with_wild(..., bay=(0, kit.BAY_WIDTH, 13))` in a carved bay (the kit carves the stand-in shore);
`with kit.climate("frost"): ...` sets the winter round any other call.
`kit.wild(season, ground, seed, coast=)` is the level 0 picture; `kit.sheet(..., wild=True)`
shows every piece in the terrain's wild land thinned by its footprint; `kit.variant_sheet(...)` shows the layouts,
their mirrors and a block of hexes chosen by `pick`; `kit.with_wild(draw, level, season, variant=, mirror=)` gives
one such picture.

**Colours**: fixed tokens `kit.INK`, `kit.ROOF`, `kit.STONE` ...; the signature tokens of the round 4 families
(`kit.MARBLE`, `kit.DYE`, `kit.ORES` ...: guide section 4); season tokens `p.pal["grass"]` ...; crops
`kit.crop("wheat", season)` (also `hemp`, `hemp_row`, `cotton_soil`, `cotton`, `mulberry_soil`); helpers `kit.mix(c1, c2, t)`, `kit.shade(c, f)`; flags `p.season`, `p.winter` (snow
lies), `p.frozen`, `p.climate`.

For a landmark of your own, copy the shape of `windmill()` in `wheat.py`: call `p.cast`, define `fn(pen)`, draw the
lit body, the shaded right part, the snow variant, then the ink, and queue it with `p.stand(foot_y, fn)`.
