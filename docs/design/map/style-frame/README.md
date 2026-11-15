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

**The patch: the Gulf of Genoa.** It has everything the brief asks for, plus a sea coast (the owner's sore point):
the Ligurian Apennines with their crest and the Giovi pass, Genoa (a city and port) and the villages of Serravalle
(on the pass road) and Chiavari (a fishing harbour), the road from Genoa over the Giovi to the Po with stone bridges,
the Tanaro joining the Po by Alessandria, and the coast from Nice to Pisa. Ivrea and the Aosta valley were left out
because they have no sea coast. At radius 60 a 1280x720 frame covers about 12 x 9 hexes (80 of them land). The
6 x 6 core is columns 6-11, rows 9-14, between Alessandria and Genoa. The Maritime Alps (left) show the high
ranges with snow; Tuscany (right) shows a middle range.

**Data.** Heights, relief levels and ground cover: `heights_alps_po.json` and the exported layers. Rivers, streams,
crests and shore types: the layers. Places and passes: real coordinates from `region_alps_po.json`. There are six
authored roads (historic routes). Three things in the data were found and worked around (to fix in the data, not
in the art):
- The layers' place hexes are shifted one hex in Lombardy (Milan sits on Pavia's hex, Pavia on Lodi's), so its road
  net was not used.
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
     80 land hexes; the first pass had 183 places in the region. Ports stand on the shore.
   - **Roads:** only main historic routes (6 here), one width per class, with stone bridges at rivers and hairpins
     near passes.
6. **Names.**
   - **Places:** a dark rounded plate with a light bold sans font. Size shows importance: a city 16 px with a gold rim, a
     town 13.5 px, a village 11.5 px on a lighter plate. There are no level dots or crowns. The plate goes under the
     place, except that a port city's plate goes on the land side so it does not cover the harbour.
   - **Other names:** passes in italic serif with a halo, rivers in italic blue, the sea in spaced italics.
   - **Fonts:** Segoe UI and Georgia are stand-ins for open-licence fonts.
7. **The middle zoom (radius 30) simplifies.**
   - **Left out:** fields, streams, villages, town walls, river names and waves.
   - **Fewer pieces:** every other crest summit, half of each spur, one peak per massif, 60% of the hills, and a third
     of the trees (drawn bigger).
   - **Towns** become compact 3-6-house icons with one church or dome.
   - **Kept:** passes, roads, bridges and coasts.

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

Known limits: the shaded faces of the high Alps still show vertical bands where several peaks stand in a row. The
middle-zoom towns are small icons, not a final design.
