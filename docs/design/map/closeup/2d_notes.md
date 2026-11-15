# 2D close-up of Genoa (hex radius 240)

Art director. **Status: a mockup for the owner to compare with the 3D test. Nothing in the game is changed.**

| File | What it shows |
|---|---|
| `2d_genoa_close_slopes.png` | **The current picture** (redrawn 2026-11-15 to the rule "one city, one hex", see the last section) |
| `2d_genoa_close.png` | Before: the first version, 1280x720: Savona to Chiavari, the Giovi pass at the top, Genoa in the middle |
| `2d_genoa_compare.png` | Before: the style frame simply enlarged 4x (left) and the first version (right) |
| `2d_genoa_slopes_compare.png`, `compare_2d_3d.png` | Before: comparisons made with the first version |

The sections below describe the first version; where the current picture differs, the last section says so.

The view is the same patch as the style frame, at hex radius 240 (one 28 km hex is about a third of the screen
width). The coast, the town sites, the pass and the ridges come from the same data as the frame, so both pictures
show the same ground. It follows the frame's rules: one 3/4 camera, ground at 85% height, standing things upright
and drawn back to front, light from the upper left, the same palette, ink lines and name plates.

## What was added (detail that only appears at this zoom)

- **Genoa as a real port city.** About 80 buildings and 25 towers instead of 30 toy houses:
  - the harbour basin with a stone quay, four piers, bollards, goods, a crane and a shipyard with two hulls on the slips;
  - the old mole and the new mole with harbour lights, and the Lanterna on its rock with the city's arms;
  - the Ripa (a row of tall arcaded houses on the quay) and the Palazzo San Giorgio;
  - rows of houses climbing the hill, with tiled roofs, windows, shutters, doors and chimneys;
  - the striped cathedral with its dome, three more churches and four tower houses;
  - the town wall going up the hill to a castle and down again, with a tower at every turn and two gates;
  - terraced gardens between the top houses and the wall.
- **Hills and ridges with form.** Lit and shaded faces, a lighter band under the crest, fall lines, minor spurs,
  woods on the slopes painted canopy by canopy, bushes along the foot, dry-stone terraces with olives on farmed hills.
  Each hill takes its tone from the ground it stands on.
- **Ground.** Soft slope shading, grass tufts, strip fields (wheat with sheaves, green crops, fallow, vineyards,
  olive groves) with hedges, cart tracks from each hamlet and farm to the road, sheep on the pastures.
- **Trees.** Five kinds instead of two: broadleaf in three tones, fir, cypress, umbrella pine and olive. Each has an
  ink rim, a shaded side, highlights and a soft ground shadow. The mix changes with height and near the coast.
- **Water.** Three shallow-water bands that follow the shore, foam lines, wave strokes, cliffs with strata and a
  wet foot, sand, boulders. Two torrents (Polcevera and Bisagno) with gravel beds and stone bridges.
- **Roads.** The Giovi road winds up to the pass, with a cairn, a hospice and two mule trains on the way. The coast
  road passes Genoa's gates.
- **Ships.** Carracks with rigging, sails with the red cross, pennants, wakes and bow waves; galleys with oars
  and a striped awning; fishing boats at sea and pulled up on the sand; gulls.
- **Small places.** Savona with its wall and church, Chiavari with a jetty, seven unnamed hamlets with a church
  each, farmsteads and three coastal watchtowers.
- **Soft shadows** under everything that stands (one blurred layer, multiplied onto the ground).

## What is in code

Everything is drawn in code with pygame. No image files, no downloads, no extra libraries.

| File (in `tools/worldmap/closeup_2d/`) | Lines | Content |
|---|---|---|
| `scene.py` | 160 | The view, the coast outline (taken from the frame's land data, with the harbour bay carved in) |
| `terrain.py` | 690 | Sea, land, shore, hills, ridges, woods, shadows |
| `paint.py` | 640 | The pieces: trees, houses, churches, towers, walls, the lighthouse, bridges, ships |
| `closeup.py` | 750 | The composition: Genoa, towns, fields, roads, streams, ships, names, the comparison |

- **Data-driven:** the coast, the shore kinds, the ground cover, the ridges and hills, the town and pass sites, the woods.
- **Placed by hand for this picture:** Genoa's layout (bay, walls, landmarks), the two torrents, the road lines,
  the hamlets and field blocks, the ships. A full map would need rules for these (see the cost below).
- **Anti-aliasing:** drawn at 2560x1440 and scaled down to 1280x720.

Run from the repository root: `python tools/worldmap/closeup_2d/closeup.py OUT_DIR [PLAIN_CROP.png]`, with the
`STYLE_FRAME_LAYERS` environment variable set to the exported layers file. The second argument (the frame's plain
4x crop) makes the comparison image.

## Render time

About **2 seconds** to paint the 2560x1440 picture (pure Python and pygame, one core, about 1,000 standing objects and a few thousand canopy dabs on the slopes),
plus about 3 seconds to load the frame's world data. This is a one-off painting, not a per-frame cost. In the game
the pieces would be drawn once into sprite sheets and the ground into cached chunks; a frame then only places
sprites.

## What it would cost for every object kind

This mockup took one working session. It already holds about 30 reusable pieces. Rough estimates for the whole map:

| Work | Estimate |
|---|---|
| The remaining terrain pieces: snow and rock mountains, plains rivers with banks, lakes, marsh, lagoon, big river bridges | 4-6 days |
| Regional building sets (the map covers more than Liguria: Alpine, Po plain, later the rest of Europe), 2-3 sets | 3-5 days per set |
| A rule-based town builder (port, hill, river and plain towns; walls, gates, landmark slot) instead of hand placement | 5-8 days |
| Hand-made landmark cities (as Genoa here) | about 1 day per city |
| Rules for fields, tracks, hamlets and terraces from the map data | 3-4 days |
| Units, armies and fleets at this zoom (not in this mockup) | 3-5 days |
| Bringing it into the game: sprite sheets, cached ground chunks, the zoom switch, tests | 5-10 days, depends on the engine |

So a first full close zoom for the Alps and Po region is about 4-6 weeks of work, and each new region adds a
building set and its landmark cities.

## Honest weak points

- **Genoa is hand-placed.** It is the best part of the picture and the part that does not yet scale.
- **The hills are still separate humps** standing on flat ground. They are shaded and planted, but the land does
  not rise as one body from the coast to the crest, as the real Riviera does. This is the limit of the frame's rule
  "flat ground, upright hills"; 3D gives this for free.
- **The view angle is fixed.** Every piece is painted for one camera; a rotating or tilting camera would need 3D.
- **Buildings are fronts with a roof**, all facing the viewer. Up close a street has no depth.
- **Scale is symbolic.** Genoa covers about 12 km of coast; a house is 400 m wide. It reads as a board-game map,
  not as a landscape.
- **Some look-alikes remain:** the fir trees and the canopy dots on the ridges repeat, and the hamlets are close
  variants of one another.
- **The name plates do not grow with the zoom** (an interface size was used). The plate for Genoa sits above the
  castle and covers some woods.
- **The unnamed hamlets** break the frame's rule "real towns only"; here they are scenery without plates.
- **Nothing moves.** Waves, flags, ships and smoke are still; animation would be extra work.
- Fonts are the frame's stand-ins, as before.

## Slope shading (added 2026-11-15)

`2d_genoa_close_slopes.png` is the same picture with the frame's slope rule (see the style-frame README), and
`2d_genoa_slopes_compare.png` shows it before and after. `2d_genoa_close.png` is unchanged; `STYLE_FRAME_SLOPES=0`
draws it again.

- The ground is toned from real heights smoothed to 1 km: lit west flanks, shaded east flanks, darker floors along
  the Polcevera and the Bisagno (both torrents are pressed into the height field), paler ground towards the crest.
- The noise that faked rolling ground before is cut to a light texture.
- Trees take the tone of their slope; ranges take it at their foot; hills on floors and flat ground are left out.
- Limits: the heights are real but warped, because the map's Genoa stands 21 km south of the real shore, so about
  15 km of real slope is drawn over 36 km. The data has one height per 1.3 x 1.9 km, so there is no relief finer than
  about 30 px here. The ground stays flat in the view: houses, roads and fields do not climb. The hill under Genoa
  is still hand-painted.
- Heights: NOAA National Centers for Environmental Information. 2022: ETOPO 2022 15 Arc-Second Global Relief Model.
  doi:10.25921/fd45-gt74 (a small derived grid, kept outside the repository).

## One city, one hex (2026-11-15)

The owner's rule: one city, one hex, drawn inside it. `2d_genoa_close_slopes.png` was redrawn to it and is now the
same picture as panel 3 of the growing map (`../growing/notes.md` has the rule, the district table and the alignment
sheet). What changed against the first version:

- Genoa stands in the middle of its own hex (8,13) instead of across the border of two hexes. It is smaller (about
  half the hex's width); its basin is the corner of sea inside the hex and both moles stay inside it.
- Savona and Chiavari moved inside their hexes. The seven unnamed hamlets are gone: each hex has one seat.
- The coast is the normal map's line with three small harbour coves (at most 3.5 km from it); the hand-carved bay and
  capes are gone.
- One torrent, the map's stream on the hex border (Bisagno); the Polcevera is not in the map data and is gone.
- The roads follow the normal map's lines and meet at the centre of Genoa's hex, behind the north gate; the Giovi
  hairpins are gone.
- Farms and field parcels are placed per hex and never cross a border.
- `scene.py` has the hex helpers and the map's lines; `stages.py` the district table; `closeup.py` without `--stage`
  draws panel 3.

## For the owner to decide

1. **2D or 3D for the closest zoom?** Compare with the 3D test of the same area.
   - 2D (this): one style with the rest of the map, cheap to run, all code-drawn; fixed camera, symbolic scale.
   - 3D: real slopes and a free camera; a second art pipeline and a different look from the middle zoom.
2. **Hamlets and farms without names** at the closest zoom: keep as scenery (recommended), or real towns only.
3. **Landmark cities:** hand-made for the great cities (recommended: capitals and great ports), or all towns from the
   town builder.
