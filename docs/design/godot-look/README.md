# The game elements on Godot: three looks

Art director, 2026-11-14. **Status: mockups for the owner. Nothing is built.**

The owner decided on 2026-11-14 that units, towns, castles, panels and the HUD are redesigned for the Godot
version (`docs/roadmap/release-0.3.0-brief.md`, "Owner's decisions", point 4). This page shows three directions
on the same scene, so the owner can choose one before any of it is built. It feeds 0.3.2 (armies on the map),
0.3.4 (the player's panels) and 0.3.5 (every screen). The 0.3.0 map look is not changed by it.

## The scene

Every mockup shows the same 1280x720 frame: Iberia in summer 1489 at the play zoom (hex radius 21), with
Portugal at war with Castile.

- **Portugal's "Army of the Tagus"** (5 regiments, selected) besieges **Toledo** (a level 2 town with a level 2 castle).
- **A Castilian army** (5 regiments) marches from the north to relieve Toledo. The mouse is over it, so its hover card is open.
- **Aragon** (3 regiments) stands near Zaragoza, **Granada** (2 tired regiments) in the hills by Granada, and a Portuguese caravel lies off Lisbon.
- **Towns** of level 1 to 3 (Burgos, Valladolid, Lisbon and others). Lisbon is the capital.
- **The top bar**, **the army panel** on the right (with the siege and the three choices, each with its price), and **the hover card**.

The terrain, coasts, rivers, owners and town levels come from the real game's Europe map (a frame of the pygame
game and its map data). Direction A is drawn over a real game frame. B and C repaint the map from the same data.

| File | What it shows |
|---|---|
| `00_today_reference.png` | Today's game at the same zoom, for comparison (Portugal's country panel open). |
| `01_direction_a_hexa_refined.png` | Direction A: the scene. |
| `02_direction_b_illustrated_atlas.png` | Direction B: the scene. |
| `03_direction_c_campaign_board.png` | Direction C: the scene. |
| `04_pieces_compared.png` | The pieces of each direction, enlarged: armies (1 and 5 regiments, Castile next to Aragon, a ship), towns level 1-3, castles level 1-3. |
| `05_far_zoom_compared.png` | The same Iberia at radius 13 and 8, in each direction. |
| `06_play_zoom_detail.png` | Toledo at the play zoom, enlarged 2.5x, A, B and C side by side. |

## Direction A: "Hexa refined"

Today's Kenney family, made crisp and smooth. Same dark navy panels, same gold headings, same landscape art (the
art baker's atlases); only the pieces on top and the UI are redrawn.

- **Units:** a small hex plate in the nation's colour with one or two figures (pikeman, horseman, gun), a pennant,
  a round regiment-count badge and a strength bar. Selection is a gold hex ring with a soft glow. Ships are a small
  caravel with the nation's arms on the sail.
- **Towns and castles by level:** towns grow from 2 houses (level 1) to houses and a church (2) to a walled town
  with a cathedral (3). Castles grow from one tower (1) to a keep with towers and a curtain wall (2) to a star
  fort (3, the period's trace italienne). Name plates carry the level as gold dots and a crown on the capital.
- **Siege:** tents round the walls, a gold progress ring around the hex (one quarter per season), smoke, a red
  crossed-swords badge.
- **HUD and panels:** today's dark theme, tidied: grouped pills in the top bar, a research meter, the task flag,
  one strong "End season" button. The army panel has four stat tiles, regiment rows with health bars, the siege
  with its progress, and three choices with their price written under each (principle 3).
- **Godot features:** soft drop shadows under pieces, a glow on the selected hex (a shader or a blurred sprite),
  tokens that slide along the path with a tween, the siege ring animating as it fills, smoke particles, a UI
  Theme with nine-patch panels and scalable fonts.
- **Art cost (lowest):** everything is code-drawn and baked by the art baker, like today. About 1-2 weeks for the
  pieces and 1-2 weeks for the UI theme. No hand art.
- **Far zoom:** at radius 13 the pieces keep their size; at radius 8 an army becomes a coloured plate with its
  number, on today's flat political map. Proven by today's game.
- **Risks:** the play-zoom landscape is busy and dark (see `00` and `06`): small pieces fight the trees and
  farms around them. A needs the landscape thinned out under pieces and towns, and pieces about 20% larger than
  today. Castile and Aragon have nearly the same yellow; colour alone does not separate them. The ground art is
  still 42% Kenney pack at this zoom (`docs/design/kenney-art-audit.md`): A does not remove it.

## Direction B: "Illustrated atlas"

A hand-coloured 16th-century atlas: painted ground, ink outlines, banners, parchment.

- **Units:** each army is a **standard**: a swallow-tailed banner with the country's own arms (simplified: the
  quinas of Portugal, the castle of Castile, the red pales of Aragon), on a pole over a small ground plate ringed
  in the nation's map colour, with two painted soldiers. A ribbon gives the regiment count and a small bar the
  morale. The pole grows a little with the army's size. Ships are a caravel with the Cross of the Order of Christ.
- **Towns and castles by level:** the same steps as A, drawn in ink and wash; a level 3 town stands on a pale
  walled ground. Names are in a book face with a parchment halo, larger for level 3 towns; the capital has a red dot.
- **Siege:** an ink earthwork line on the besieger's side, gun smoke, and a small parchment tag "Siege 2/4".
- **March:** a red dashed ink arrow, as on period campaign maps.
- **HUD and panels:** a walnut top bar with parchment cartouches and a red wax "End season" button. The panel is
  a parchment sheet with red small-caps headings and a small picture of the castle under siege. The hover card is
  a parchment note.
- **Godot features:** a watercolour blend shader between terrains, a paper-grain overlay, banners that wave (a
  vertex shader), nine-patch parchment panels, smoke particles, tweens.
- **Art cost (highest):** the whole map is repainted (the 0.3.0 terrain art would be replaced), arms for 49
  countries and the tribes must be researched and drawn, parchment textures must look hand-made, and period
  fonts must be found with an open licence. About 6-10 weeks, some of it hand art.
- **Far zoom:** the banners stay readable down to radius 8 and are the most distinctive marks of the three. The
  painted ground turns to soft washes, which is pleasant but blurry.
- **Risks:** the strongest period feel (principle 14) but the weakest contrast. Ownership shows only as a wash
  along borders, so "whose land is this?" is harder (principle 11). Parchment text is less readable than A or C.
  It is the most expensive and the easiest to get wrong: code-made "painting" can look cheap. It throws away
  the 0.3.0 map art. Heraldry for non-European peoples needs care (principle 16): no invented emblems.

## Direction C: "Campaign board"

A board game on a table: raised land tiles on a blue sea, stacked army discs, wooden town pieces, white cards.

- **Units:** an army is a **stack of discs** in the nation's colour, one disc per regiment (so its size is seen at
  a glance), with the main kind of troops on the top disc and a **number tag with its strength** (26, 29) and a
  health bar. Every nation has a pattern as well as a colour (Aragon's discs are striped), so near colours and
  colour-blind players are covered.
- **Towns and castles by level:** wooden blocks: 1 house, 2 houses, 3 houses and a spire. Castles are grey
  tower pieces: 1, 3, then 3 on a star base. Name pills carry the level number in a disc (orange for the capital).
- **Siege:** two camp tents and a **season dial** next to the castle (four segments, two filled), the same dial
  as in the panel.
- **March:** a thick red arrow with a white edge.
- **HUD and panels:** light cards floating on the map: resource pills, a season wheel, a big orange "End season"
  button. The army panel is a pile of cards: a header card, one small card per regiment kind, the supply line,
  the siege card with its dial, and the three choices as cards, the first with its chance ("45%").
- **Godot features:** the tile thickness and soft shadow on the sea (baked or a shader), a gentle sea shader,
  tokens that hop from hex to hex with a tween, the dial filling, a light UI Theme with rounded cards.
- **Art cost (low to medium):** every piece is code-drawn and simpler than today's. The terrain tiles are new
  but plainer than the current landscape (fewer objects). About 3-4 weeks. It also replaces all Kenney ground art.
- **Far zoom:** the clearest of the three: discs and pills stay sharp, tiles turn into a clean coloured board.
- **Risks:** it can read as a toy or a mobile game and lose the period feel (principle 14): it needs the arms on
  the discs, period names and period buildings to stay "1480-1650". It sets aside the landscape art made over the
  last months (trees, farms, animals, goods objects). Repeated tiles look samey without 3-4 variants per terrain.

## Side by side

| | A Hexa refined | B Illustrated atlas | C Campaign board |
|---|---|---|---|
| Keeps the Hexa identity | Yes | Partly (new map) | Partly (new map) |
| Reads at the play zoom | Fair (busy ground) | Fair (low contrast) | Best |
| Reads at far zoom | Good | Good (banners) | Best |
| Period feel (principle 14) | Fair | Best | Weakest |
| Art cost | 2-4 weeks, all code | 6-10 weeks, some hand art | 3-4 weeks, all code |
| Uses the 0.3.0 map art | Yes | No | No |
| Removes Kenney ground art | No | Yes | Yes |
| Risk to the port schedule | Low | High | Medium |

## Recommendation

**A, "Hexa refined", with three things borrowed from the others.** It keeps the look the owner chose, reuses the
baker and the 0.3.0 map, and costs the least while the port is the priority. The borrowings fix A's two weak spots:

1. **From B: each country's simplified arms** on the army's pennant, the panel and the hover card. They separate
   Castile from Aragon, help colour-blind players and give period colour (principle 14) at little cost.
2. **From C: the strength number on the army token** (with the regiment count in the hover card) and the season
   dial for sieges: "who is stronger?" in one look (principle 11).
3. **The landscape is thinned under pieces and towns** and the pieces are about 20% larger than today, so they
   stand out from the busy ground.

B's parchment look could still be used where it costs little and suits the moment: the event popups, the
chronicle and the end screen.

## Questions for the owner

1. **Which direction for the game elements?** A "Hexa refined" with the three borrowings (recommended), B
   "Illustrated atlas" or C "Campaign board".
2. **What should an army's badge on the map show?** Its strength number, with the regiment count in the hover
   card (recommended), or the regiment count as today.
3. **Should every country get simple arms as a second mark next to its colour?** Yes, code-drawn and simplified
   for all countries, researched with care for non-European peoples (recommended), or colour only as today.

## Limits of these mockups

- They are pictures, not game code. Animation (tweens, waving banners, smoke, the filling ring) is described, not shown.
- The fonts are stand-ins from the drawing machine (Segoe UI, Book Antiqua, Trebuchet). They cannot ship; the
  chosen direction needs open-licence fonts.
- The numbers in the panels (men, strength, odds) are made up for the picture.
- The arms are simplified sketches and need checking before they are used.
- Direction A is drawn over a frame of today's game, so the ground is today's art; B and C repaint it from the map data.
