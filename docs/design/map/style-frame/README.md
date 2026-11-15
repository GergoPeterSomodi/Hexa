# Map style frame (art reset, 2026-11-14)

Art director. **Status: for the owner to approve. Nothing in the game is changed.** One frame drawn with the rules below,
so the bulk redraw can follow them. It answers the owner's notes on the first art pass (one view angle, ranges not
triangles, varied coasts, no flat grey, fewer places and roads, clean names, one style).

| File | What it shows |
|---|---|
| `style_frame_close.png` | The close zoom (hex radius 60), 1280x720 |
| `style_frame_middle.png` | The same patch at the middle zoom (hex radius 30), 640x360: what simplifies |
| `style_frame_tilt_ab.png` | Owner's choice: the ground plane at 85% height (A) or full height as in 07 (B) |
| `slope_before_after.png` | The slope rule: the close zoom before and after, with the Genoa area enlarged |
| `sites_before_after.png` | One town, one hex: the close zoom before and after, with Savona, Genoa and Chiavari enlarged |
| `style_frame_close_before.png`, `style_frame_middle_before.png` | The two frames before the one-hex rule |

**The patch: the Gulf of Genoa.** It has everything the brief asks for, plus a sea coast (the owner's sore point):
the Ligurian Apennines with their crest and the Giovi pass, Genoa (a city and port) and the villages of Serravalle
(on the pass road) and Chiavari (a fishing harbour), the road from Genoa over the Giovi to the Po with stone bridges,
the Tanaro joining the Po by Alessandria, and the coast from Nice to Pisa. Ivrea and the Aosta valley were left out
because they have no sea coast. At radius 60 a 1280x720 frame covers about 12 x 9 hexes (80 of them land). The
6 x 6 core is columns 6-11, rows 9-14, between Alessandria and Genoa. The Maritime Alps (left) show the high
ranges with snow; Tuscany (right) shows a middle range.

**Data.** Heights, relief levels and ground cover: `heights_alps_po.json` and the exported layers. Rivers, streams,
crests and shore types: the layers. Places and passes: real coordinates from `region_alps_po.json`; each town's hex
is the hex of those coordinates and its site lies inside that hex (see "One town, one hex" below). There are six
authored roads (historic routes). Three things in the data were found and worked around (to fix in the data, not
in the art):
- The layers' place hexes are wrong for half the towns in view, so its road net was not used. The export snaps
  every town to the best-scoring hex within one hex of its place; the list is under "One town, one hex".
- Mont Cenis in the region file lies 13 km south of the real col.
- There is no Scrivia or Polcevera line: a data stream stands in for the lower Scrivia.

## The rules

1. **One view angle, a slight 3/4 view.** One camera for everything.
   - **On the ground plane:** ground, fields, rivers, roads, coast, moles, wall footprints and the hex grid. North-south
     distances are drawn at 85%.
   - **Standing upright and unsquashed:** mountains, hills, trees, houses, towers, bridge arches, lighthouse, ships and
     cairns. They are drawn in order of their foot, back to front.
   - **Light and line:** light comes from the upper left. Lit faces are on the left, shaded faces on the right, with a
     soft ground shadow to the lower right. Ink lines are 1-2 px.
   - **Clear view:** nothing tall stands within 9 km in front of (south of) a place.
2. **Ranges are built from the crest edges.**
   - **Ranges:** the crest edges are chained into lines, smoothed and sampled every 4.3 km. Summits sit on every other
     sample, sized by the hexes on both sides: height in px = 8 + 40·t^0.85, where t = (m − 450) / 2650. Saddles drop
     to 40-65% of the summits, and one summit in three is raised 16%. Where a range runs across the screen it is one
     silhouette (one ink line, fall lines between the peaks), not a row of triangles.
   - **Passes:** the ridge dips to a saddle where the road crosses. The saddle gets a cairn and flag, a hospice above
     1500 m, and the pass name in italics. Where a river cuts through the range, the ridge dips to a gorge.
   - **Shoulders:** from every other summit a spur runs down the falling side, one peak every 6.8 km. Each spur peak is
     lower than the last and never higher than the ground under it. A spur stops at 640 m, or 3.6 km from water, a
     road or a place. This leaves open valleys between the spurs, with a green valley floor along the river.
   - **Massifs:** high hexes (over 1100 m) away from the ranges get one short ridge of 2-3 peaks along the contour.
     Below that come rounded hills (380-1500 m).
   - **No carpet:** there is no grid of peaks anywhere.
   - **Colours and snow by height:** wooded green with rounded tops below 1700 m; stony tops over wooded slopes from
     1700 to 2250 m; bare rock with snow caps above that. The caps cover 20-46% of the peak and grow with height.
     No snow lies on the ground.
3. **Ground.** Cover colours blend across the hex edges, with gentle hill shading.
   - **Stony ground is never flat grey:** it has boulders, scree streaks, grass tufts, sparse pines and alpine meadow
     patches.
   - **Fields** lie in blocks of strips around the places and on farmland, never as single scattered plots.
4. **Coasts vary.** The coastline is the blended hex land plus three octaves of noise. It wanders about a third of a
   hex around the hex edges, and each land hex centre stays land. The shore type changes along the coast:
   - **Cliffs** where the shore is high and a 6.5 km noise allows. On coasts facing the viewer the cliff face is seen,
     with foam at its foot.
   - **Sand** on low shores and **wet rocks** on hilly ones.
   - **Ports** always have a low shore with a quay and boats. The great port also gets two moles, a lighthouse and ships.
   - **Water:** a light shallow band and a foam line along the shore.
5. **Places and roads.**
   - **Places:** real towns only. A town in a hex next to a bigger place is dropped (here Lodi, Cremona and Lucca). There
     are only a couple of villages per frame, each with a role. The frame has 12 towns and cities and 2 villages in
     80 land hexes; the first pass had 183 places in the region. Ports stand on the shore of their own hex.
   - **One town, one hex:** every place belongs to one hex and is drawn inside it (the section below).
   - **Roads:** only main historic routes (6 here), one width per class, with stone bridges at rivers and hairpins
     near passes. A road ends at a town's site inside the town's hex.
6. **Names.**
   - **Places:** a dark rounded plate with a light bold sans font. Size shows importance: a city 16 px with a gold rim, a
     town 13.5 px, a village 11.5 px on a lighter plate. There are no level dots or crowns. The plate goes under the
     place, except that a port's plate goes on the land side (above, or beside the town when the sea lies east or west)
     so it does not cover the harbour. The plate lies inside the town's hex.
   - **Other names:** passes in italic serif with a halo, rivers in italic blue, the sea in spaced italics.
   - **Fonts:** Segoe UI and Georgia are stand-ins for open-licence fonts.
7. **The middle zoom (radius 30) simplifies.**
   - **Left out:** fields, streams, villages, town walls, river names and waves.
   - **Fewer pieces:** every other crest summit, half of each spur, one peak per massif, 60% of the hills, and a third
     of the trees (drawn bigger).
   - **Towns** become compact 3-6-house icons with one church or dome.
   - **Kept:** passes, roads, bridges and coasts.

## One town, one hex, drawn inside it (added 2026-11-15, the owner's rule)

Every settlement belongs to exactly one hex of the map, and its picture and its name plate are drawn inside that hex,
clear of the border. The close-up of Genoa was built on this rule first (`../growing/notes.md`); the frame now follows
it, so the two zooms agree. See `sites_before_after.png` and `../growing/alignment.png`.

- **Which hex.** The hex that holds the town's real coordinates (the region file). The exported layers are used only
  where a town lies within 1.5 km of a hex border and the layers put it across that border (Cuneo).
- **Where in the hex.** The point nearest to the real position at which the picture and the plate fit, at least
  0.5 km (2 px at the close zoom) from the border. Cities fill most of a hex, so they end up near its centre; towns
  and villages keep more of their real position. The same site serves both zooms.
- **Ports.** A port stands on a shore of its own hex, and its quay, moles and lighthouse stay in the hex. Where the
  hex had no shore of its own a small cove is cut (Genoa's basin, Savona, Chiavari, Nice); no cove moves the coast
  more than 3.5 km from the first line. Genoa, Savona and Nice are drawn at 80-85% so they fit between the hex
  centre and the quay. Ships at anchor may lie outside.
- **Roads.** A road ends at a town's site. Round Genoa the roads are the close-up's own lines: they meet at the
  centre of Genoa's hex behind the town, and the coast road stops at the centre of Chiavari's hex with a lane down
  to the village.
- **Shared with the close-up.** The town sites, the coves and the road lines round Genoa are one set of numbers
  (`tools/worldmap/style_frame/sites.py`), taken from the close-up. Measured in the close-up's view: the map's roads
  lie within 0.1 km of the close-up's, the two coasts within 1.0 km, and Genoa, Savona, Chiavari and the Giovi stand
  on the same hexes (8,13; 7,13; 9,13; 9,12) within 0.7 km.
- **The check.** `render.py` draws every town's picture once more on an empty sheet and measures, pixel by pixel,
  how far the picture and the plate keep from the hex border; it prints one line per zoom and a `SITE PROBLEM` line
  for each failure. At the close zoom all 14 places pass. At the middle zoom all 12 pictures pass, but five plates
  are wider or taller than the room a 52 px hex leaves (Genoa, Turin, Pavia, Pisa, Alessandria); they stay centred
  in their own hex and are listed as notes. Not checked: ships, ground shadows and the fields round a town.

| Town | Hex | Layers hex | Drawn before (km) | Drawn now (km) | Moved |
|---|---|---|---|---|---|
| Genoa | 8,13 | 8,13 | 265, 340 (0.5 km from the border) | 252, 340 | 12 km |
| Turin | 5,9 | 5,9 | 164, 248 (0.1 km from the border) | 168, 232 | 16 km |
| Pavia | 9,9 | 10,9 | 279, 235 | 280, 232 | 3 km |
| Pisa | 13,16 | 13,16 | 376, 398 | 378, 402 | 5 km |
| Asti | 7,10 | 8,10 | 204, 267 | 210, 257 | 12 km |
| Alessandria | 8,10 | 7,9 | 236, 266 | 238, 257 | 9 km |
| Piacenza | 11,10 | 11,10 | 320, 250 | 322, 255 | 5 km |
| Parma | 12,11 | 13,11 | 370, 278 | 364, 279 | 6 km |
| Savona | 7,13 | 6,13 | 228, 345 (0.5 km from the border) | 230, 339 | 6 km |
| Cuneo | 5,13 | 5,13 | 153, 324 (in hex 4,13) | 168, 328 | 16 km |
| Nice | 4,16 | 4,16 | 139, 400 | 134, 405 | 7 km |
| Susa | 3,9 | 4,9 | 114, 240 | 112, 232 | 8 km |
| Serravalle | 8,11 | not in the data | 255, 287 | 254, 284 | 3 km |
| Chiavari | 9,13 | not in the data | 292, 343 (on the shore of sea hex 10,14) | 280, 342 | 13 km |

Positions are km from the north-west corner of the region window. Most of a move is the plate: the picture and the
plate together are 60-70 px tall in a hex 102 px tall, so a town that stood near a border has to come to the middle.

**Data problems found (to fix in the data, not in the art):**
- The layers put seven of the twelve towns in view on another hex than their coordinates: Pavia, Asti, Alessandria,
  Parma, Savona, Susa and Cuneo. Asti and Alessandria change sides (Asti ends up east of Alessandria), Savona loses
  its sea hex and is no longer a port, and Susa lands on the plain next to Turin. Only Cuneo's move is small enough
  to accept (it stands 0.9 km from the border).
- Susa's own hex (3,9) is a 3,320 m peak hex in the heights and also holds the Mont Cenis saddle; Cuneo's hexes
  (4,13 and 5,13) are both above 2,000 m. The valleys these towns stand in are narrower than a hex.
- Serravalle and Chiavari are villages the frame adds; they are not in the region file. The layers have unnamed
  villages on 9,13 and near Serravalle instead.
- Savona's hex is next to Genoa's, so rule 5 (a town next to a bigger place is dropped) would drop Savona; it is
  kept because the close-up is built round it.

## The slope rule (added 2026-11-15, for the owner to see; nothing is rolled out)

The land rises as one body from the coast to the crest; it is not flat ground with separate humps on it. The ground
plane stays flat in the view (rule 1): the rise is shown with tone only. See `slope_before_after.png` (the frame, before
and after, with the Genoa area enlarged) and `../closeup/2d_genoa_slopes_compare.png`.

- **One height field.** Real heights, smoothed to about 11 px on screen at each zoom (3 km at radius 60, 1 km in the
  close-up), so the shapes are broad and soft, not a relief map.
- **Slope tone.** Slopes that face the light are a little lighter and warmer (up to 16%), slopes turned away a little
  darker and cooler (up to 16%). The tone is nearly two-tone, like the standing hills, with soft edges. The light comes
  from the left and a little from above, as on the standing mountains; a light from straight above-left would put
  every coast that faces the viewer in the shade.
- **Valley floors** are up to 10% darker, crests up to 5% lighter. **High green ground** goes a little paler (up to
  30% towards a pale green at 850 m). Stone takes about half of every tone, so it stays light.
- **Flat land stays plain.** Ground that rises less than about 7 m per km gets no tone; the dark tones start later
  (15 m per km), because a dark tone on a gentle ramp reads as a stain.
- **Drawn water lies in a valley.** The height field is pressed down along the drawn rivers and streams, so the
  shading always agrees with the map.
- **Woods follow the land.** Every tree takes the tone of the slope it stands on.
- **Hills and ranges sit on the slope.** Green hills and wooded ranges take the slope tone at their foot and a third
  of the ground colour. A rounded hill is left out on a valley floor and on flat ground, and one in two to four is
  left out where the shaded slope already shows the rise (here 187 of the 396 hills in view go).
- **Not changed:** the high ranges, snow, coasts, places, roads and names.

**Data.** The fine heights are NOAA ETOPO 2022 (60 arc-second), cut to a small derived grid that is kept outside
the repository. The map's coast is the hex coast, which lies up to about 20 km off the real one (Genoa stands 21 km
south of its real place), so the heights are read through a soft warp that carries the real shore onto the drawn
shore and fades out inland. Without the derived grid the generator falls back to the per-hex heights: the land still
rises, but the valleys are missing.

**Switch.** `STYLE_FRAME_SLOPES=0` turns the rule off and gives the earlier pictures again, pixel for pixel;
`STYLE_FRAME_HEIGHTS` names the derived grid. The code is `tools/worldmap/style_frame/slopes.py`.

**Known limits.** The shading follows the real land, the standing hills and ranges follow the hex data, so a lit
slope and a drawn hill do not always meet. West of Turin the real Alps reach further east than the drawn peaks, and
the shaded flank shows as a dark green wedge on ground drawn as meadow. The high Alps gain little: their ground is
mostly hidden by the peaks, and the peaks are still separate cut-outs (see the report).

Credit for the heights: NOAA National Centers for Environmental Information. 2022: ETOPO 2022 15 Arc-Second Global
Relief Model. doi:10.25921/fd45-gt74

## For the owner to decide

1. **Ground tilt:** A (85% height, a real 3/4 ground; recommended) or B (full height as in 07). See
   `style_frame_tilt_ab.png`. The difference is small; A makes fields, walls and harbours read as lying flat.
2. **Place density:** as drawn (every real town in the list, no two next to each other; recommended), or fewer
   (cities only, plus one town per two hexes).
3. **The frame:** at radius 60 a 1280x720 screen shows about 12 x 9 hexes, not 6 x 6. Is this the close zoom you
   want, or should the closest zoom go to about radius 90?
4. **Plates at the middle zoom:** a readable plate does not always fit in a 52 px hex. Keep them as drawn (centred in
   their hex, hanging over a little; recommended), name only the cities at that zoom, or shrink the font below 9 px.
5. **Susa and Cuneo:** keep them in their mountain hexes as drawn (recommended; they read as valley towns), or follow
   the layers and put Susa on the plain next to Turin.

Known limits: the frame's pictures here are drawn without the slope rule, as before (`slope_before_after.png` has
both). `style_frame_tilt_ab.png` was not redrawn and still shows the towns at their old places. The shaded faces of the high Alps still show vertical bands where several peaks stand in a row. The
middle-zoom towns are small icons, not a final design.
