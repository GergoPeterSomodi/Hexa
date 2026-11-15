# 3D close-up test: Genoa

A test mockup of the same area as the 2D close-up (Savona, Genoa, Chiavari, the Giovi pass, the Apennines behind and
some Po plain), built as a real 3D scene in Godot 4.7.2, so the two options can be compared side by side. It is a
look test only: no game logic, no units, no input beyond a free camera.

| View | File | What it shows |
|---|---|---|
| Close | `3d_genoa_close.png` | The framing of the 4x 2D crop: Savona to Chiavari across, the Giovi at the top, tilted 50 degrees |
| Wide | `3d_genoa_wide.png` | The whole test area (about 157 by 133 km), tilted 70 degrees |
| Low | `3d_genoa_low.png` | A low camera over the harbour: the thing only 3D can do |

## How it is built

Everything is made in code at start-up (about 0.5 s); there are no models, textures, fonts or add-ons.

- **Heights.** `tools/worldmap/closeup_3d/extract_area.py` reads the ETOPO 2022 60 arc-second file and writes one
  small file (about 50 kB) with the heights of the window in metres, sea bed included, and stream lines from a flow
  count on that grid. The raw data and the derived file both stay outside the repository; the scene takes the path
  as an argument. Credit: NOAA National Centers for Environmental Information. 2022: ETOPO 2022 15 Arc-Second
  Global Relief Model. doi:10.25921/fd45-gt74
- **Ground.** One mesh, a 0.5 km grid (about 166,000 triangles), smooth normals. Land heights are multiplied by 7,
  the sea bed by 0.55. Stream beds are cut a little into the ground and the hills right behind each town are
  lowered, so the houses have a shelf to stand on. Colour comes from a shader that reads only height and slope:
  light green lowland with a faint patchwork of fields, darker wooded slopes, grey rock on steep faces, pale tops,
  a beach strip.
- **Sea.** One flat sheet with a shader. A small data texture gives it the depth of the bed and the distance to the
  shore, so it can tint the water by depth, draw a foam line on the shore and let swell lines walk in. It moves.
- **Objects.** Low-poly meshes built from triangles with the colour in the vertices: houses, towers, a church with
  a dome, the Lanterna, moles, ships, a cairn on the pass. About 3,800 trees (round ones low down, conifers higher
  up) and the houses are drawn as instanced meshes (MultiMesh). Roads and streams are ribbons laid on the ground.
- **Light.** One sun with shadows, one weak fill light without, sky colour as ambient light, distance haze.
  The project's Compatibility renderer (OpenGL), which is the one web and mobile builds use.
- **Projection.** The scene uses the game's map grid formulas, so the 28 km hexes are the game's own hexes.

Run it (from the repository root, `GODOT` set, the height file made first):

```bash
python tools/worldmap/closeup_3d/extract_area.py --etopo <etopo 60s east .nc> --out <folder>/heights_genoa.json
"$GODOT" --path godot res://prototypes/closeup3d/closeup3d.tscn -- --heights=<folder>/heights_genoa.json
# add --shots=<folder> to write the three images, print the frame times and quit
```

Keys: 1, 2, 3 for the three views; right mouse drag turns, the wheel zooms, WASD or the arrows move.

## Speed

Measured at 1280x720 with 4x anti-aliasing, on a desktop with a current high-end graphics card:

| View | Frame time | Triangles drawn per frame | Draw calls |
|---|---|---|---|
| Close | about 1.2 ms | 0.84 million | 54 |
| Wide | about 1.3 ms | 0.85 million | 69 |
| Low | about 1.3 ms | 2.1 million (four shadow splits) | 81 |

The scene itself is about 410,000 triangles (ground 166,000, trees 240,000); the shadow pass draws it again.

What this means for web and mobile, honestly:

- **It has not been run on a phone or in a browser.** The desktop number says only that the scene is light for a
  desktop. A mid-range phone is very roughly 20 to 50 times slower than this card, which would put this exact scene
  somewhere around 25 to 60 ms per frame: borderline.
- The cost is in the things a phone is bad at: shadows (the whole scene drawn a second time, or four more times at
  a low angle), anti-aliasing, and full-screen water with transparency. Without shadows the scene looks flat, so
  they cannot simply be switched off.
- This is 157 by 133 km. The real map is much larger, so a real 3D map needs the ground cut into chunks, far
  chunks at lower detail, trees dropped or merged at distance, and loading as the camera moves. None of that
  exists here, and it is real engineering work that the 2D map does not need.
- A web build would also need the height data shipped in some packed form; here it is one small JSON file.

## Hex grid, units and labels in 3D

- **Hex grid.** Drawn in the shaders of the ground, the sea and the trees from the world position, projected
  straight down. It follows the relief with no extra geometry and costs almost nothing. Under dense forest the
  line is carried over the tree tops, which works from above but breaks up at a low angle. A selected or
  highlighted hex would be done the same way (a tint inside the hex), or as a thin outline mesh laid on the ground.
- **Picking a hex.** Cast a ray from the cursor onto the ground height field, then use the same hex formula as the
  2D map. On steep ground the hex under the cursor is less obvious to the player than on a flat map.
- **Units.** Either small 3D figures standing on the hex centre at the ground height, or flat 2D counters that
  always face the camera. Figures need models and animation for every unit type (nothing here can be reused from
  the 2D art); counters keep the 2D art but look pasted on. Either way a unit behind a ridge or in forest can be
  hidden, so it needs an outline or a marker drawn through the terrain.
- **Labels.** Done here as normal 2D name plates on top of the 3D view, each placed at the screen position of its
  town every frame. They stay sharp and the same size at any zoom. They need rules the 2D map gets for free: hide a
  plate when a mountain stands in front of its town (done here with a ray over the heights), let the lesser name
  give way when two plates meet (done), keep plates off the screen edge (done).

## Honest weak points

- **Less readable than the 2D close-up at the same framing.** The 2D map draws each hill, town and wood as a clear
  sign. Here the same things are real shapes seen from one side: houses show mostly their roofs, the forest is a
  mass of dots, the Giovi road half disappears between trees. The 3D view is prettiest at the low angle, which is
  the angle a strategy map is least often played at.
- **The relief is exaggerated 7 times** (more than the 3 to 5 first tried) and the Apennines still read as gentle
  hills next to trees and houses that are about 15 times too large. At 60 arc-seconds the heights are smooth; there
  are no crags, cliffs or sharp ridge lines. The 2D map can simply draw a mountain as a mountain.
- **The coast is the coast of the height data** (cells of about 1.3 by 1.85 km), not the map's own coastline, so
  bays and capes are soft and the harbour of Genoa is invented (two moles put where the sea begins).
- **Streams** come from the flow count: right in the valleys, straight and stiff on the plain, and there are no
  bridges where the roads cross them.
- **Towns** are scattered houses with no streets, walls or gates; the towers are plain boxes.
- **Rock and ground colour** are simple bands by height and slope; there is no texture, so large slopes look smooth
  and plastic up close.
- **Shadows** are tuned per view; while the camera moves freely they can get soft or striped.
- **The edge of the board** shows at a low angle looking out to sea.
- **Art cost.** Every new object (unit types, city levels, castles, ships, landmarks, the ages) would have to be
  modelled, in code or in a 3D tool, and the present 2D art and the baked atlases would not carry over.
