# M2 build spec: Countries

Game designer (Opus), 2026-11-17. **Status: a proposal, design only; it waits for the owner's go.** Builds milestone M2
of `docs/architecture/godot-architecture.md` (the standard) on the M1 build spec (`m1-build-spec.md`) and the M1.5 UI
foundation (`ui-and-controls-spec.md`, `ui-style-and-feedback-spec.md`). Where this page is more exact it wins for M2;
section 1 lists every place where it refines an earlier page. The tasks are in `m2-build-plan.md`.

**What M2 is.** The north Italy map gets the states of 1480: who owns every district, their borders, colours, names and
arms. You start a New game, pick your country on the map, and you can build only on your own land. The map gains three
modes (Terrain, Owner, Relief), a minimap and a place search; the top bar shows your arms; a country panel tells you
about any country; the Godot editor paints the owner layer.

**When it starts.** After M1 is closed (its task T16, which retires `shell/worldmap/` and stores the first goldens, is
still open) and after M1.5 is closed (the owner has played it). M2 edits the map view, the HUD and the screens that
those two deliver, and takes its pictures against T16's goldens.

**M2 is done when:**

1. A New game on the scenario "Italy, 1480" shows **13 countries** (10 playable, 3 outside powers) owning the 340 land
   hexes exactly as section 4.5 lists them; `godot/tools/build_scenario.gd --check` is green in CI.
2. Borders are drawn on every land edge between two owners and on no other edge; a change of owner (a test of
   `Territory.transfer`, and a pin painted in the editor) redraws exactly the border chunks and overlay pixels it touches.
3. You pick your country on the map or from a keyboard list. Build, upgrade and clear succeed **only on your own land**;
   anywhere else they are refused with the reason ("not your land: the Duchy of Milan holds it"). A property test of
   2,000 random actions with random actors finds no accepted action off the actor's land.
4. Keys 1, 2, 3 and the top bar's switch show Terrain, Owner and Relief; the minimap, the place search (Ctrl/Cmd+F), the
   country panel (C), the arms and name in the top bar and the colour-blind palette work as section 7 says, each with its
   GUT test; the art director has signed their pictures (section 10).
5. On the made-up Europe (494 x 247 hexes, 60 countries) a frame stays under 16 ms at every zoom with the Owner overlay and
   the borders on, and the CPU rows of section 9 are within their limits (`tools/perf_map.gd`, nightly).
6. Lint, import, check_scripts and GUT are green; the owner has played the build through the checklist of the plan.

---

## 1. What is there today, and where this page refines earlier pages

### 1.1 Read in the code (master `bbef31b`)

| Finding | Where | What it means for M2 |
|---|---|---|
| `Game` holds `map`, `state`, `seed_value`, `events`, `improvement`; `act`/`check` look pairs up in `Actions.pair_of` (build, upgrade, clear) | `core/game/game.gd`, `core/game/actions.gd` | M2 adds the countries, the player and one action; the actions gain an actor |
| `MapState` has `main_use` and `level` only; schema `hexa-godot/map-state/1`; `digest()` over both | `core/state/map_state.gd` | M2 adds `owner` (schema 2) |
| The only Resource class is `MapData`; no `GameDefs`, `CountryDef` or scenario | `core/defs/` | M2 creates them (standard 4.1) |
| `Improve.*_check` refuse with lower-case phrases ("not a land hex", "something already stands here") | `core/systems/improve.gd`, `world_improve.gd` | The home rule speaks the same way |
| `Session`: `game`, `new_game(map_id, seed)`, `start_game`, `map_of`, `check`, `act`, `_drain` (hex_changed only). `Events`: `hex_changed`, `game_started` | `shell/autoload/` | M2 adds `new_scenario`, `defs`, `player_tag`, `reseed`, a public `drain`, two events |
| `TileMapView`: lines at z 50, the shadow group at 60, the standing group at 70, `marks` at 90; **no tint layer**; one `EdgeLineLayer` mesh a chunk of 32 x 32 cells with colours fixed per kind | `shell/mapview/tile_map_view.gd`, `edge_line_layer.gd` | Borders get their own chunk meshes; the tint becomes a shader overlay (1.2) |
| A map-layer canvas shader already exists (the shadow group's `shadow_cover.gdshader`) | `shell/mapview/` | Map shaders are established practice; the UI has none (1.2) |
| `FarPicture`/`FarMap` draw terrain only; `MapLabels` styles a place as a capital from `MapData.places[].capital`, which is true for **Milan only** | `core/views/far_picture.gd`, `shell/mapview/map_labels.gd` | Capitals come from the game's countries in M2 |
| The north Italy map: 21 x 19 hexes, **340 land**, 83 places (58 named towns, 13 unnamed towns, Bard fort, Certosa di Pavia, 10 pass hospices), 24 passes; window lon 5.6 E, lat 47.3 N | `data/maps/north_italy.tres` | Section 4 assigns every land hex |
| The v0.2.2 countries exported: 49 tags with name, colour, capital; their territory seed points | `data/countries.json`, `data/geography/countries.json` | Starting values for the roster (4.2) |
| The M1.5 frame (App, HUD, kit, `Settings`, `Bindings`, screens, `HexCard`, `CameraRig`) is **specified, not built** | `ui-and-controls-plan.md` U1 to U16, `ui-style-and-feedback-plan.md` S1 | M2 names those pieces "(M1.5)"; it starts after they exist |

### 1.2 Refinements (decided here)

| Earlier page | M2 | Why |
|---|---|---|
| Standard 3.2 layer 7 and M1 spec 5 (z 80): country colour as a `TileMapLayer` of `mark/white` tinted per country | **One overlay node** (`ModeOverlay`, z 80): a quad over the whole map with a canvas shader that finds the hex under each pixel and reads two one-byte-a-hex textures (owner, height) and a palette. The same node draws the Terrain tint, the Owner mode and the Relief mode | A tint layer costs about 570 bytes a cell (M1's measure): 70 MB on Europe. The overlay costs 0.25 MB, one draw, and a mode switch is one uniform. `mark/white` is used by the editor's pin tiles (8.4) |
| Standard 3.3: borders in the chunk line node | Borders are **their own chunk meshes** at z 85, above the standing group and the overlay, built by `BorderLines` (6.3) | Rivers and roads sit under the trees (z 50); a border must read over a forest and over the tint |
| M1 spec 7: the far picture carries "M2's country colours" | The far picture stays terrain only; the overlay draws over it at every zoom | One source of country colour for the map, the far zoom and the minimap |
| UI spec 4.1: `view_mode_1..4` "political, terrain, relief" | **1 Terrain, 2 Owner, 3 Relief**; 4 Supply from M6 | The approved mockup orders them so, with Terrain first and on |
| UI spec 7: the mode overlay reads "a data texture of one pixel a hex"; colours from `core/views/map_modes.gd` | Two R8 textures (owner id, height band) and two 256 x 1 palettes; the shader picks the colour per mode | A mode or palette change rewrites no pixel of the map |
| Style spec 2, row 8, and UI spec 8: "no shaders in the UI" | Unchanged for the UI. **The map-mode overlay is a map layer's canvas shader that reads only its own textures, never the screen; this is allowed.** The minimap's picture is a small copy of the map and uses the same material (7.8). The wording of both pages is edited to say so (section 12) | Screen reads are what the rule protects against (cost, the Compatibility renderer, `CanvasGroup`); a shader on its own data textures is neither |
| Style spec 4.5, slice 2: `shield_rim`, `shield_mask`, `pennant` | `shield_rim` (48 x 56), `shield_rim_sm` (20 x 24), `pennant_pole`, `pennant_cloth`; no mask (7.2) | The arms are polygons clipped in code; the top bar needs a small rim; the cloth is tinted, the pole is not |
| UI spec 7: place search matches `MapData.places` (prefix, then substring, then accent-free) | Places, passes and countries; ranks prefix, word start, substring; accents always folded (5.7) | A country is what a player often looks for; folding always is simpler than a third pass |
| Standard 3.6: the editor paints cover, owner, main use and level, places | M2's editor **paints owner** and shows the other layers read-only; painting cover and places arrives with E2 (the Europe map build), through the same "paint, write overrides, rebuild, check" path (8.4) | Cover and places are built from geography and checked by `build_map --check`; hand overrides belong with the map that needs them. Starting pieces come from the seeded search, not from data |

---

## 2. Decisions taken

Each is decided. "Reverse" is the cost to change it later (S half a day, M a day, L two or three days).

| # | Question | Decision | Why | Reverse |
|---|---|---|---|---|
| D1 | Who exists on the map | 13 countries: **Savoy, Milan, Venice, Genoa, Florence, Switzerland, Mantua, Ferrara, Siena, Lucca** (playable) and **France, Austria, the Papal States** (outside powers) | The v0.2.2 Italian roster plus the four states that held towns on this map in 1480; each holds at least one town of the map | A `CountryDef` and seed lines (S each) |
| D2 | States the map cannot show | **Folded:** Montferrat, Saluzzo and the Orléans county of Asti into Savoy; Valais and the Three Leagues into Switzerland; the bishoprics of Geneva and Lausanne into Savoy; Trento and Brixen into Austria; Romagna's vicars into the Papal States | None has its seat among the map's named places (Casale, Saluzzo are not places), or each would be one hex; v0.2.2 also gave Asti to Savoy | Add the def and seeds when a map names the seat (S) |
| D3 | Owner per hex, from what | **A rule over data:** every town of the map and a few anchor hexes are seeds with a tag; land grows from them by travel cost (crests and rivers cost more) up to a reach; pins correct single hexes. The result is committed and checked in CI | Keeps v0.2.2's "land goes to the nearest seed" and works unchanged for Europe (E2); towns make borders historical; the check keeps data and rule in step | Seeds and pins are data (S) |
| D4 | Owner storage | `MapState.owner`, one byte a hex: 0 no one, 1 to 254 a country id (its place in the scenario's list) | 122 KB on Europe; ids never move during a game (a dead country keeps its slot) | Widen to 16 bits (M) |
| D5 | Sea | Owner 0, never owned; no tint; no border along a coast | No sea war before M12 (owner's answer: land game first) | A sea owner layer later (M) |
| D6 | Unowned land | Possible (a pin to no one, or out of reach); no tint in Terrain, parchment in Owner mode; bordered; nobody builds there. North Italy 1480 has none | The rule needs the case for Europe; 1480 Italy was all claimed | none |
| D7 | Outside powers | Own land, have colours and arms, **cannot be played**: their capital is off the map. Listed greyed with the reason | Playing France with 34 Alpine hexes would mislead; their strength is off the map | One flag (S) |
| D8 | Capitals | Turin, Milan, Venice, Genoa, Florence, Bern, Mantua, Ferrara, Siena, Lucca; Paris, Vienna, Rome off the map | v0.2.2's capitals; Savoy's seat was Chambéry, but v0.2.2 and the map's weight put it at Turin | Data (S) |
| D9 | The sandbox (map only) | Keeps M1's game: **no countries, no home rule**, no Owner mode | It is the developer's map tool until M12; the rule needs countries to mean anything | none |
| D10 | Who acts | Every action takes `tag` (the actor). `Session.act` fills the player's tag; the AI (M8) and tests pass their own | One door for player and AI; no rule reads "the player" | none |
| D11 | Choosing the country | An action, `choose_country {tag}`, allowed once; before it nothing can be built | The player is saved state and part of the digest, so it changes through an action | none |
| D12 | Home rule wording | Lower case, as M1's reasons: "not your land: the Duchy of Milan holds it", "no one holds this land", "choose your country first" | M4's `reason_words` rewrites them for cards; the panel shows them as they are until then | Text (S) |
| D13 | Map modes and keys | 1 Terrain (default), 2 Owner, 3 Relief; 4 unbound until Supply (M6). The season preview leaves the keys (Layers popover and F3 keep it until M3) | The mockup's order; UI spec 1 and style spec 1 #10 | Bindings (S) |
| D14 | How modes are drawn | One shader overlay with id and height textures and palettes (1.2) | Memory, one draw, instant switch | Tint tiles (L, and 70 MB on Europe) |
| D15 | Borders | An ink line on the edge plus a band of each country's colour fading into its own hex, in chunk meshes at z 85; hidden with the tiles below zoom 0.20 | Readable over trees and tint; a mesh costs nothing while it stands (M1's lesson) | z and widths are constants (S) |
| D16 | Colours | v0.2.2's colours kept, **except Milan** (its teal was 22 ΔE from Venice's and 28 from Savoy's); four new colours. Neighbours differ by ΔE76 ≥ 30 (tested) | Keep tags and starts; a political map needs neighbours apart | Data (S) |
| D17 | Colour-blind palette | The eight Okabe-Ito colours (black replaced by pale grey); each scenario gives each country one, chosen so neighbours stay ≥ 20 ΔE76 apart under normal, protan, deutan and tritan vision (tested). The **pattern on occupied land** comes with occupation (M7) | A palette built for colour-vision types; per scenario because neighbours differ by map | Data (S) |
| D18 | Arms | Code-drawn heater shield: a division (12 kinds) in two tinctures, under a baked brass rim; simplified real arms | `design.md` 5 ("code-drawn heater shield with a brass rim"); 13 countries need no painter | Data (S) |
| D19 | Pennants | On the map at playable capitals, in Owner mode and while picking | `design.md` 5 ("pennants only on the map"); marks where to click | Hide (S) |
| D20 | Country names on the map | One label per region of 3 hexes or more, at its deepest hex, sized to the region; always in Owner mode and while picking, in Terrain below zoom 0.9 | Names belong on a political map; place names win up close | Constants (S) |
| D21 | The pick | After New game the map opens in Owner mode with a ribbon, a keyboard list and the country panel in the dock with "Play as" | UI spec 2 ("the country pick on the map with a list for keyboard play"); v0.2.2's chooser | none |
| D22 | Place search scope | Named places, passes and countries; prefix, then word start, then substring; accents ignored | Countries in the search cost nothing and answer "where is Mantua" | none |
| D23 | Minimap | Far picture plus the overlay in the hexagon frame, bottom right; on by default; a switch in Layers and Options | UI spec 7; with owner colours it is useful even on north Italy | Default (S) |
| D24 | The editor's layers | Paints owner (as pins); shows cover, relief, rivers, roads, places read-only; cover and places paintable from E2 | 1.2 | Overrides path exists (M each) |
| D25 | Season table | **M2 adds no phase.** Ownership changes only through `Territory.transfer` (tests, editor; capture in M7, peace in M9) | The season table arrives in M3 | none |
| D26 | Saves | M3 owns save and load; M2 states the fields and makes them round-trip (5.9) | Standard 9: saves are M3 | none |
| D27 | Country data | One `CountryDef` file a country (`data/defs/countries/`), listed by `data/defs/game_defs.tres`; scenarios are `ScenarioDef` files listed there too | Standard 4.1 (one `GameDefs`); no folder scan in an export | none |
| D28 | Unnamed towns | Seeds by hex with a note naming the real town (the 13 bracketed names of 4.4: Belluno, Alba, Pontremoli and the rest); the map's names are not changed | Names come from the map builder; M2 does not edit map data | none |

---

## 3. The v0.2.2 reference

| v0.2.2 | Where | Kept | Changed for the district map, and why |
|---|---|---|---|
| `COUNTRIES`: tag, name, colour, seed points (the first is the capital) for 49 countries | `hexa/campaign/geo.py` 437, `data/countries.json` | Tags, names, colours (but Milan's), capitals; "seeds grow land" | Seeds are the map's **towns** plus anchors, not lon/lat points: with 28 km districts the towns set the borders |
| `build_countries`: every province goes to the nearest seed in cube distance, within `TERRITORY_RADIUS = 4 * SCALE` (8 old hexes, about 450 km), only on the seed's landmass; the capital province is forced to its country | `hexa/campaign/systems/worldgen.py` 293 to 330, `data.py` 503 | Nearest seed, a reach, same landmass (growth walks land only), capitals owned (a check) | **Travel cost**, not straight distance: a crest without a pass costs +3 and a river +1, so the Alps and the big rivers make borders; ties go to the earlier seed; pins fix single hexes |
| Unowned provinces become a tribe's land (`TRIBES`) | worldgen 343 | The unowned case | No tribes: north Italy has no unowned land; Europe's unowned land waits for colonies (after M12) |
| `Province.owner`, `controller` per province | `state.py` | Owner | **Per hex** (district); `controller` arrives with occupation (M7) |
| `Country` dataclass: tag, name, color, capital, treasury, tax, orders, income, alive, era, research, explored, memory, techs, researching, queue, ideas, national, pending_ideas | `state.py` 120 | tag, capital, alive | Everything else arrives with its system (treasury M4, explored M6, techs M11) |
| Political map mode, key 1; four modes on 1 to 4 | `mapview.MODES`, `app.py` | Modes on number keys | Terrain is mode 1 (the map is the art now); Relief replaces goods |
| Minimap, 1 px a hex, owner colours, click to jump | `app.py` `draw_minimap` | All of it | The far picture under the overlay, in the hexagon frame, with drag |
| "Choose your country: click any country on the map"; the panel shows "Play as X" and a tip (`TIPS`); `--nation` on the command line | `app.py` 849, `panels/country.py` `_chooser` | The flow, the button, the tip, the flag | A keyboard list beside the map; outside powers greyed with the reason; `--country=TAG` |
| Country panel: header with colour and counts; own: research, treasury, wars, merchants; other: treasury, war or peace, "Show their capital" | `panels/country.py` | Header, counts, "show their capital" | M2's panel has identity and land; each later system adds its section (7.4) |

---

## 4. Who owns what in 1480 (the design content)

### 4.1 The scenario

| Field | Value |
|---|---|
| id | `north_italy_1480` |
| Name | Italy, 1480 |
| Blurb (New game page) | "The north of Italy under the Peace of Lodi: five powers, their small neighbours, and the kings beyond the Alps." |
| Map | `north_italy` (its digest is stored and checked) |
| Year | 1480 (the calendar starts in M3, spring) |
| Countries | 13, ids 1 to 13 in v0.2.2's order, then the new ones (table 4.2) |

### 4.2 The countries

Colours are sRGB. "CB" is the index into the colour-blind palette (4.6). Districts and towns are the result of 4.4 on
today's map.

| Id | Tag | Name | Long name | Adjective | Colour | CB | Capital | Districts | Towns (of which level 4+) |
|---|---|---|---|---|---|---|---|---|---|
| 1 | FRA | France | Kingdom of France | French | `#2846aa` | 3 | Paris (off the map) | 34 | 3 (0) |
| 2 | AUS | Austria | Archduchy of Austria | Austrian | `#e6e6e6` | 4 | Vienna (off the map) | 37 | 3 (0) |
| 3 | SWI | Switzerland | Swiss Confederation | Swiss | `#be3232` | 1 | Bern (5, 0) | 45 | 8 (0) |
| 4 | SAV | Savoy | Duchy of Savoy | Savoyard | `#829678` | 5 | Turin (5, 9) | 58 | 13 (1) |
| 5 | MLO | Milan | Duchy of Milan | Milanese | `#3460b2` (v0.2.2 `#3c8c96`) | 3 | Milan (9, 9) | 52 | 20 (2) |
| 6 | VEN | Venice | Republic of Venice | Venetian | `#1ea08c` | 5 | Venice (18, 7) | 42 | 10 (4) |
| 7 | GEN | Genoa | Republic of Genoa | Genoese | `#be3c6e` | 1 | Genoa (8, 13) | 14 | 2 (1) |
| 8 | TUS | Florence | Republic of Florence | Florentine | `#8c32a0` | 3 | Florence (15, 15) | 14 | 3 (2) |
| 9 | PAP | Papal States | Papal States | Papal | `#f0e6a0` | 1 | Rome (off the map) | 20 | 4 (1) |
| 10 | MAN | Mantua | Marquisate of Mantua | Mantuan | `#cd9632` | 1 | Mantua (14, 10) | 3 | 1 (0) |
| 11 | FER | Ferrara | Duchy of Ferrara | Ferrarese | `#78aadc` | 4 | Ferrara (16, 10) | 12 | 2 (1) |
| 12 | SIE | Siena | Republic of Siena | Sienese | `#a0522d` | 5 | Siena (16, 16) | 7 | 1 (0) |
| 13 | LUC | Lucca | Republic of Lucca | Lucchese | `#d76e3c` | 5 | Lucca (12, 15) | 2 | 1 (0) |

Sentences use "the " + long name ("the Papal States", "the Swiss Confederation"). Totals: 340 land hexes, 0 unowned.

**Tips** (one line in the pick):

| Tag | Tip |
|---|---|
| SAV | Passes over the Alps and the Piedmont plain: many roads, few rich towns. |
| MLO | The richest plain of Europe, and every neighbour wants a piece of it. |
| VEN | A lagoon city with a mainland empire: trade first, land second. |
| GEN | A narrow coast of harbours under the mountains; little land, much sea. |
| TUS | Bankers and cloth towns behind the Apennines. |
| SWI | Hard mountain valleys that hold the passes to the north. |
| MAN | A small marquisate in the marshes of the Mincio, between Milan and Venice. |
| FER | The Este duchy on the lower Po, between Venice and the Pope. |
| SIE | A proud hill republic, watched by Florence. |
| LUC | A tiny silk republic that must stay friends with everyone: a hard start. |
| FRA, AUS, PAP | (not playable; the panel says "Its capital, Paris, is off this map.") |

### 4.3 The rule (deterministic)

The scenario stores **seeds**, **pins** and the growth numbers; `ScenarioGrowth.grow` (5.1) turns them into the owner of
every hex.

1. **Seeds.** A *town seed* sits on every place of the map with `level >= 1` or `castle >= 1` (72 on north Italy),
   carrying the tag of its 1480 holder. An *anchor seed* is a land hex with no such place, for land whose towns are not on
   the map (28 on north Italy). Seeds keep their order in the list: towns in map place order, then anchors.
2. **Step cost** between two neighbouring land hexes across edge `e`: `step_cost` (2), plus `crest_cost` (3) when
   `map.crest[e] == 1` and `map.pass_edge[e] == 0`, plus `river_cost` (1) when `map.river[e]` is 1 to 3 (a river, not a
   stream). Sea is never entered.
3. **Growth** (Dijkstra with a bucket queue on integer cost): a town seed starts at cost 0, an anchor at `anchor_start`
   (1). Entries are taken in ascending (cost, seed order, hex index). An entry whose hex is already claimed is dropped;
   an entry with cost over `reach` (32) is dropped; otherwise its hex is claimed for its tag and each unclaimed land
   neighbour is queued at cost + step.
4. **Pins** then overwrite single hexes (`tag` `&""` = no one).
5. Sea hexes are 0. Land no seed reached within `reach` is 0 (no one).

Integer costs, a fixed order and no luck: the same map and scenario give the same bytes on every machine.

### 4.4 The seeds of `north_italy_1480`

Town seeds by holder (the map's place name, or the real town of an unnamed place in brackets, with its hex). The file
lists them in the map's place order, then the anchors in the order below (left column, then right); the table groups
them by holder for reading:

| Tag | Town seeds |
|---|---|
| SAV | Turin 5,9; Cuneo 5,13; Asti 8,10; Vercelli 6,9; Ivrea 6,8; Chivasso 5,10; Aosta 5,7; Susa 4,9; Nice 4,16; Geneva 1,4; Lausanne 2,4; Bard fort 6,7; (Alba) 6,11; (Moûtiers) 2,8 |
| MLO | Milan 9,9; Como 8,5; Monza 9,7; Varese 10,6; Pavia 10,9; Lecco 10,5; Lodi 11,9; Cremona 12,9; Parma 13,11; Piacenza 11,10; Alessandria 7,9; Novara 7,8; Bellinzona 9,4; Locarno 7,5; Lugano 8,4; Domodossola 7,6; Bormio 13,4; Sondrio 11,4; Chiavenna 10,4; (Pontremoli) 12,12 |
| VEN | Bergamo 11,8; Brescia 13,6; Verona 15,8; Venice 18,7; Padua 17,8; Vicenza 16,7; Treviso 17,7; Chioggia 18,9; Ravenna 17,12; (Belluno) 18,4 |
| GEN | Genoa 8,13; Savona 6,13 |
| TUS | Florence 15,15; Pisa 13,16; (Cortona) 17,18 |
| SWI | Bern 5,0; Brig 5,4; Sion 3,4; Martigny 3,5; Lucerne 7,1; Chur 10,2; Airolo 7,3; (Murten) 3,1 |
| MAN | Mantua 14,10 |
| FER | Modena 14,11; Ferrara 16,10 |
| SIE | Siena 16,16 |
| LUC | Lucca 12,15 |
| PAP | Bologna 16,12; (Cesena) 18,14; (Pesaro) 19,15; (Gubbio) 19,18 |
| AUS | Bolzano 15,3; Trento 15,6; (Glurns) 13,2 |
| FRA | (Besançon) 1,0; (Fréjus) 1,17; (Brignoles) 0,16 |

Anchor seeds (hex, tag, the note stored with it):

| Hex | Tag | Note | Hex | Tag | Note |
|---|---|---|---|---|---|
| 0,7 | SAV | Chambéry, the seat of the Savoy court | 16,11 | FER | Argenta (Este) |
| 2,6 | SAV | Faucigny and Chamonix | 17,11 | FER | Comacchio (Este) |
| 1,10 | FRA | Dauphiné: the Oisans and Briançon | 13,12 | FER | the Reggio hills (Este) |
| 1,12 | FRA | Dauphiné: Gap and Embrun | 14,12 | FER | the Frignano (Este) |
| 1,15 | FRA | Provence: Digne and Draguignan | 13,14 | FER | the Garfagnana (Este) |
| 19,1 | AUS | Pustertal and Lienz (Tyrol, Gorizia) | 17,13 | PAP | Forlì and Faenza (papal vicars) |
| 19,3 | VEN | Carnia (Friuli, Venetian since 1420) | 18,16 | PAP | Città di Castello |
| 14,4 | AUS | Val di Sole (bishopric of Trento, under Tyrol) | 18,18 | PAP | Perugia |
| 11,3 | SWI | Upper Engadin (League of God's House) | 17,15 | TUS | Sansepolcro (Florentine since 1441) |
| 5,15 | GEN | Riviera di Ponente: Ventimiglia, Sanremo | 17,16 | TUS | Arezzo (Florentine since 1384) |
| 6,14 | GEN | Riviera di Ponente: Albenga, Finale | 12,14 | LUC | the Versilia hills: Camaiore |
| 8,11 | GEN | the Oltregiogo: Novi, Ovada | 14,18 | SIE | Massa Marittima (Siena) |
| 6,6 | MLO | the Valsesia (contado of Novara) | 16,18 | SIE | Montalcino (Siena) |
| 13,10 | MAN | Gonzaga lands: Viadana, Sabbioneta | 14,9 | MAN | Gonzaga lands: Goito |

Pins: **none** in the first file. Growth numbers: `step_cost` 2, `crest_cost` 3, `river_cost` 1, `anchor_start` 1,
`reach` 32. On today's map the largest cost reached is 7, so every land hex is owned.

### 4.5 The result (owner per hex)

Letters: R France, A Austria, H Switzerland, S Savoy, M Milan, V Venice, G Genoa, F Florence, P Papal States, N Mantua,
E Ferrara, I Siena, L Lucca, `~` sea. Odd rows are shifted half a hex right, as on the map.

```
 0  R R R H H H H H H H H H A A A A A A A A A
 1   R R H H H H H H H H H H A A A A A A A A A
 2  R R S H H H H H H H H H A A A A A A V A A
 3   S S S H H H H H M M H H M M A A A V V V V
 4  S S S H H H H M M M M M M M A A A V V V V
 5   S S H H H H M M M M M M M V A A A V V V V
 6  S S S H H S M M M M M M V V V A A V V V V
 7   S S S S S S S M M M M V V V V V V V V ~ ~
 8  S S S S S S S M M M M V M M V V V V V ~ ~
 9   R S S S S S S M M M M M M M N V V V V ~ ~
10  R R R S S S S S S S M M M N N E E E V ~ ~
11   R R R S S S S S G G M M M M E P E E ~ ~ ~
12  R R R R S S S G G G G M M E E P P V V ~ ~
13   R R R S S S G G G G G M M E E P P P ~ ~ ~
14  R R R S S S G G ~ ~ ~ ~ L E E F F P P ~ ~
15   R R R S S G ~ ~ ~ ~ ~ ~ L F F F F F P P P
16  R R R S S ~ ~ ~ ~ ~ ~ ~ ~ F F F I F P P P
17   R R R ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ F I I I F P P P
18  ~ ~ R ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ I I I F P P P
```

**Regions** (connected land of one owner): one each, except France (Franche-Comté 7 hexes and Dauphiné-Provence 27, both
on the map's edge) and Venice (the mainland 40 and Ravenna 2, reached by sea, as in 1480). A test pins this list.

**Passes** (owner of the pass hex, in the map's spelling): Switzerland: Great St Bernard, Simplon, Gotthard, Furka,
Splugen, Julier. Savoy: Little St Bernard, Mont Cenis, Mont Genevre, Col di Tenda. Milan: Lukmanier, San Bernardino,
Maloja, Bernina, Stelvio, Tonale, Aprica, Cisa. Austria: Resia, Brenner, Arlberg. Genoa: Cadibona, Giovi. France: Col de
Larche.

**Neighbours** (24 pairs, used by the colour tests): AUS-MLO, AUS-SWI, AUS-VEN, FER-LUC, FER-MAN, FER-MLO, FER-PAP,
FER-TUS, FER-VEN, FRA-SAV, FRA-SWI, GEN-MLO, GEN-SAV, LUC-MLO, LUC-TUS, MAN-MLO, MAN-VEN, MLO-SAV, MLO-SWI, MLO-VEN,
PAP-TUS, PAP-VEN, SAV-SWI, SIE-TUS.

### 4.6 Colours

**Normal palette** (`CountryDef.colour`, table 4.2). Smallest neighbour distance (ΔE76, CIE Lab D65): FER-MLO 35.6;
all 24 pairs ≥ 30, the test's limit `GameDefs.min_contrast`. Unowned land in Owner mode: `GameDefs.unowned_colour`
`#d8ccb0`.

**Colour-blind palette** (`GameDefs.cb_palette`, index 0 to 7): `#e69f00` orange, `#56b4e9` sky, `#009e73` bluish green,
`#f0e442` yellow, `#0072b2` blue, `#d55e00` vermilion, `#cc79a7` reddish purple, `#ebebeb` pale grey. The scenario's
`cb_colours` (column CB of 4.2) was chosen by an exhaustive search for the largest smallest distance between neighbours,
measured as the minimum of ΔE76 under normal vision and under the Machado (2009) full-severity protan, deutan and tritan
simulations: **24.8** (sky against blue). The test's limit is `GameDefs.min_contrast_cb` = 20.

**How the distance is computed** (`ColourContrast`, so the code gives these numbers): sRGB to linear by the IEC formula
(`c / 12.92` up to 0.04045, else `((c + 0.055) / 1.055) ^ 2.4`); linear to XYZ by the sRGB D65 matrix (rows 0.4124 0.3576
0.1805; 0.2126 0.7152 0.0722; 0.0193 0.1192 0.9505); XYZ to Lab with white (0.95047, 1.0, 1.08883) and `f(t) = cbrt(t)`
above 0.008856, else `7.787 t + 16 / 116`; ΔE76 is the straight distance in Lab. A simulation multiplies the linear RGB by
the Machado matrix, clamps to 0..1 and re-encodes to sRGB before Lab. Protan: 0.152286 1.052583 -0.204868; 0.114503
0.786281 0.099216; -0.003882 -0.048116 1.051998. Deutan: 0.367322 0.860646 -0.227968; 0.280085 0.672501 0.047413;
-0.011820 0.042940 0.968881. Tritan: 1.255528 -0.076749 -0.178779; -0.078411 0.930809 0.147602; 0.004733 0.691367
0.303900.

**On the map** (constants of `MapModes`, signed by the art director on the pictures of section 10):

| Mode | What the overlay draws on land | Alpha | Sea |
|---|---|---|---|
| Terrain | the owner's colour as a light tint (switch "Country tint", on by default; off hides the overlay) | 0.14 | clear |
| Owner | the owner's colour; unowned land `unowned_colour` | 0.55 | clear |
| Relief | a height ramp (below) | 0.65 | clear |
| any, while picking | the hovered country brighter: colour mixed 15 % with white, alpha + 0.20 | | |

Relief ramp (metres to colour, linear between stops): 0 `#4f8a4a`, 150 `#79a557`, 400 `#b7b56a`, 800 `#c49a5c`,
1,300 `#a2744c`, 1,900 `#8e7f74`, 2,500 `#c9c7c4`, 3,200 and above `#f4f5f8`. The height byte of a land hex is
`1 + clampi(height_m / 16, 0, 254)` (16 m a step, an integer division); 0 marks sea.

**Borders:** ink `#1c140d` at alpha 0.85, 2.4 map px wide on the edge; a band 7 map px deep inside each owned hex along
the edge, in the owner's palette colour, alpha 0.85 at the edge fading to 0 inside. Between a country and unowned land:
ink and the country's band. Coast and sea edges: nothing.

Colour is never the only cue: borders separate every region, country names sit on the map, and the hover card and the
hex panel name the owner.

### 4.7 Arms

A heater shield 48 x 56 logical px, drawn as polygons (section 7.2) under the baked brass rim. Twelve divisions:
`plain`, `per_pale`, `per_fess`, `per_bend`, `quarterly`, `cross`, `saltire`, `chief`, `fess`, `pale`, `bend`,
`bordure`. Tinctures (`GameDefs.tinctures`): or `#d4a82c`, argent `#efeadf`, gules `#b3261e`, azure `#2b5aa8`, sable
`#241f1c`, vert `#2e7d3c`, purpure `#6b3a7a`.

| Tag | Arms (division, field, charge) | After |
|---|---|---|
| SAV | cross, gules, argent | Savoy: gules a cross argent |
| GEN | cross, argent, gules | Genoa: the cross of St George |
| MLO | quarterly, or, azure | the Sforza-Visconti quarters |
| VEN | bordure, gules, or | the red and gold of St Mark |
| TUS | per_pale, argent, gules | the old arms of Florence |
| SWI | bend, gules, or | Bern's bend |
| MAN | fess, or, sable | the Gonzaga bars |
| FER | per_bend, azure, argent | the Este eagle's colours |
| SIE | per_fess, argent, sable | the Balzana |
| LUC | per_fess, argent, gules | Lucca's party arms |
| PAP | saltire, gules, or | the crossed keys |
| AUS | fess, gules, argent | the Bindenschild |
| FRA | pale, azure, or | the lilies' colours |

---

## 5. Interfaces

Layers as the standard: `defs` (Resources and pure functions of them), `state`, `systems`, `game`, `views`, `shell`.
`core/` makes no engine calls and takes no luck (M2 needs none). New files are marked **new**.

### 5.1 Definitions (`core/defs/`)

```gdscript
# core/defs/country_def.gd  (new)
class_name CountryDef extends Resource
const DIVISIONS: Array[StringName] = [&"plain", &"per_pale", &"per_fess", &"per_bend", &"quarterly", &"cross",
	&"saltire", &"chief", &"fess", &"pale", &"bend", &"bordure"]
@export var tag: StringName               # three capital letters, unique; v0.2.2's tags kept
@export var name: String                  # "Genoa"
@export var long_name: String             # "Republic of Genoa"; sentences say "the " + long_name
@export var adjective: String             # "Genoese" (M3's report and log)
@export var colour: Color                 # the map colour
@export var capital_name: String          # the seat when it is off the map: "Rome"; "" otherwise
@export var arms_division: StringName      # one of DIVISIONS
@export var arms_field: StringName         # a key of GameDefs.tinctures
@export var arms_charge: StringName
@export_multiline var tip: String          # one line for the pick
func validate(tinctures: Dictionary) -> Array[String]    # tag form, names, division and tinctures known

# core/defs/scenario_def.gd  (new)
class_name ScenarioDef extends Resource
const NO_HEX := Vector2i(-1, -1)
@export var id: String                     # "north_italy_1480"
@export var name: String                   # "Italy, 1480"
@export_multiline var blurb: String
@export var map_id: String                 # "north_italy"
@export var map_digest: String             # MapData.digest() the owner was grown on
@export var year: int = 1480
@export var countries: Array[StringName] = []   # tags; a country's id is its index + 1
@export var capitals: Array[Vector2i] = []      # per country; NO_HEX: off the map (an outside power)
@export var cb_colours: PackedByteArray         # per country: an index into GameDefs.cb_palette
@export var seeds: Array[Dictionary] = []       # {hex: Vector2i, tag: StringName, kind: &"town" | &"anchor", note: String}
@export var pins: Array[Dictionary] = []        # {hex: Vector2i, tag: StringName (&"" = no one), note: String}
@export var step_cost := 2
@export var crest_cost := 3
@export var river_cost := 1
@export var anchor_start := 1
@export var reach := 32
@export var owner: PackedByteArray              # the grown result: per hex, a country id; 0 = no one
func id_of(tag: StringName) -> int              # 0 when not listed
func tag_of(id: int) -> StringName              # &"" for 0 or out of range
func playable(tag: StringName) -> bool          # listed and its capital on the map
func validate(map: MapData, defs: GameDefs, deep: bool) -> Array[String]   # 8.2; deep also regrows and checks colours
func digest() -> String                         # sha256 of every field in a fixed order

# core/defs/game_defs.gd  (new): the one list of definitions (standard 4.1); M4 and later add their arrays
class_name GameDefs extends Resource
@export var countries: Array[CountryDef] = []
@export var scenarios: Array[ScenarioDef] = []
@export var tinctures: Dictionary[StringName, Color] = {}
@export var cb_palette: PackedColorArray        # 8 colours (4.6)
@export var unowned_colour: Color
@export var min_contrast := 30.0                # ΔE76 between neighbours, normal palette
@export var min_contrast_cb := 20.0             # the same, worst of four visions, colour-blind palette
func country(tag: StringName) -> CountryDef     # null when unknown (a dictionary built on first use)
func scenario(id: String) -> ScenarioDef        # null when unknown
func validate() -> Array[String]                # unique tags and ids; each def's validate; palette of 8
func digest() -> String

# core/defs/scenario_growth.gd  (new; in defs because the editor (shell) and the tools both call it, and mapgen is
# for tools only)
class_name ScenarioGrowth extends RefCounted
static func grow(map: MapData, scenario: ScenarioDef) -> PackedByteArray     # 4.3, steps 1 to 5
static func step(map: MapData, scenario: ScenarioDef, hex: Vector2i, direction: int) -> int   # 4.3 step 2
static func neighbour_pairs(map: MapData, owner: PackedByteArray) -> Array[Vector2i]   # (a, b) ids, a < b, sorted
static func regions(map: MapData, owner: PackedByteArray, id: int) -> Array[PackedInt32Array]  # hex indices, by first index

# core/defs/colour_contrast.gd  (new)
class_name ColourContrast extends RefCounted
enum Vision { NORMAL, PROTAN, DEUTAN, TRITAN }
static func delta_e(a: Color, b: Color) -> float             # CIE76 in Lab (D65), on the sRGB values
static func simulate(c: Color, vision: Vision) -> Color      # Machado 2009, severity 1, in linear RGB
static func worst_delta_e(a: Color, b: Color) -> float       # min over the four visions
```

### 5.2 State (`core/state/`)

```gdscript
# core/state/country.gd  (new): what changes about a country during a game. Treasury (M4), armies (M6),
# techs (M11) join it with their systems.
class_name Country extends RefCounted
const SCHEMA := "hexa-godot/country/1"
var id: int                   # 1 to 254: the byte in MapState.owner
var tag: StringName
var capital: Vector2i         # ScenarioDef.NO_HEX when off the map
var alive := true
func to_dict() -> Dictionary
static func from_dict(d: Dictionary) -> Country      # null on a wrong schema
func digest_text() -> String                         # "id|tag|col,row|alive"

# core/state/map_state.gd  (edit)
const SCHEMA := "hexa-godot/map-state/2"   # 1 still loads: owner all 0
var owner: PackedByteArray                  # per hex: country id, 0 = no one; sized by create(); copied by duplicate_state()
# to_dict() adds "owner" (base64); from_dict() reads it (schema 2) or fills zeros (schema 1); digest() adds owner
```

### 5.3 Systems (`core/systems/`)

```gdscript
# core/systems/territory.gd  (new)
class_name Territory extends RefCounted
const OWNS: Array[String] = ["owner"]
static func setup(game: Game, scenario: ScenarioDef) -> void      # state.owner = a copy of scenario.owner
static func owner_id(game: Game, hex: Vector2i) -> int            # 0: no one, sea or off the map
static func owner_tag(game: Game, hex: Vector2i) -> StringName    # &"" for 0
static func at_home_check(game: Game, tag: StringName, hex: Vector2i) -> Dictionary   # {ok, reason}, table below
static func transfer(game: Game, hexes: Array[Vector2i], to_id: int) -> int   # returns hexes changed; sea, off-map and
	# hexes already owned by to_id are skipped; queues ONE {kind: "owners_changed", hexes: Array[Vector2i]} when any
	# changed; to_id 0 frees land. Not an action: called by tests and tools in M2, by capture (M7) and peace (M9)
static func districts(game: Game, id: int) -> PackedInt32Array    # hex indices, ascending
static func count(game: Game, id: int) -> int
static func neighbours(game: Game, id: int) -> PackedInt32Array   # ids sharing a land edge, ascending, 0 left out

# core/systems/countries.gd  (new)
class_name Countries extends RefCounted
const OWNS: Array[String] = ["countries", "player"]   # Game fields
static func setup(game: Game, scenario: ScenarioDef) -> void      # game.countries from the scenario, in id order
static func by_tag(game: Game, tag: StringName) -> Country        # null when none
static func by_id(game: Game, id: int) -> Country                 # null for 0 or out of range
static func def_of(game: Game, tag: StringName) -> CountryDef
static func playable(game: Game, tag: StringName) -> bool         # alive and its capital on the map
static func choose_check(game: Game, args: Dictionary) -> Dictionary
static func choose(game: Game, args: Dictionary) -> Dictionary    # sets game.player; queues {kind: "country_chosen", tag}
```

**The home rule.** `Territory.at_home_check(game, tag, hex)`, in this order:

| Case | Verdict |
|---|---|
| The game has no countries (a map-only game) | ok |
| The hex is sea or off the map | ok (the acting system gives its own refusal, "not a land hex") |
| `tag` is `&""` | "choose your country first" |
| No country has `tag` | "no country %s" |
| The country is not alive | "%s is no more" (its name; dead countries arrive in M12) |
| The hex's owner is 0 | "no one holds this land" |
| The owner is another country | "not your land: the %s holds it" (its long name) |
| Otherwise | ok |

`Improve.build_check`, `upgrade_check` and `clear_check` call it right after reading the hex, with
`StringName(args.get("tag", &""))`. `Improve.OWNS` is unchanged; `Improve.build_options` is unchanged (the panel asks the
home rule first, 7.6).

**Choosing.** `Countries.choose_check(game, {tag})`:

| Case | Verdict |
|---|---|
| The game has no countries | "this map has no countries" |
| `game.player` is set | "a country is chosen already: %s" (its name) |
| No country has `tag` | "no country %s" |
| Its capital is off the map | "%s cannot be played here: its capital, %s, is off this map" (name, `capital_name`) |
| Not alive | "%s is no more" |
| Otherwise | ok |

### 5.4 Game and the action table (`core/game/`)

```gdscript
# core/game/game.gd  (edit)
var defs: GameDefs = null                   # null in a map-only game
var scenario: ScenarioDef = null            # null in a map-only game; fixed data, named by id in saves
var countries: Array[Country] = []          # countries[id - 1]
var player: StringName = &""                # the human's tag; &"" before the pick, in AI-only games, in a map-only game
static func new_scenario(p_map: MapData, p_defs: GameDefs, p_scenario: ScenarioDef, p_seed: int) -> Game
	# new_game(p_map, p_seed) (the improvement search), then Countries.setup and Territory.setup; asserts the
	# scenario's map_id is the map's id
func has_countries() -> bool
func digest() -> String   # sha256 of "map id|seed|scenario id or ''|player|state.digest()|each country's digest_text()"
```

`Game.new_game(map, seed)` and `Game.with_state(map, state, seed)` stay as they are: a map-only game.

```gdscript
# core/game/actions.gd  (edit)
const NAMES: Array[String] = ["build", "upgrade", "clear", "choose_country"]
#   build {hex, family, tag}   upgrade {hex, tag}   clear {hex, tag}   choose_country {tag}
# pair_of("choose_country") -> [Countries.choose_check, Countries.choose]
```

**OWNS after M2:** `Improve` writes `main_use`, `level`; `Territory` writes `owner`; `Countries` writes `countries`,
`player`. A test fails when an action of one writes a field of another.

### 5.5 Events

Rules append to `game.events`; `Session` drains them into `Events` signals (standard 4.4).

| Event (queued dict) | Signal | Queued by | Heard by |
|---|---|---|---|
| `{kind: "owners_changed", hexes: Array[Vector2i]}` | `owners_changed(hexes: Array[Vector2i])` | `Territory.transfer` | `MapScene` (overlay pixels, border chunks, country labels, pennants), `Hud` (the dock's panel refreshes), F3 |
| `{kind: "country_chosen", tag: StringName}` | `country_chosen(tag: StringName)` | `Countries.choose` | `App` (ends the pick, glides to the capital, toasts, restores the mode), `TopBar`, `Hud`, `MapScene` (pennants of the pick go) |

`hex_changed` and `game_started` are unchanged. M3's action log and report will read both new kinds (section 13).

### 5.6 Session (`shell/autoload/session.gd`, edit)

```gdscript
const DEFS := "res://data/defs/game_defs.tres"
func defs() -> GameDefs                      # loaded once; push_error and null when it fails validate()
func new_scenario(scenario_id: String, seed_value: int, player: StringName = &"") -> String
	# the scenario and its map from defs(); a shallow validate: on a problem it returns the first line and starts
	# nothing (the App toasts it and stays on the menu); else Game.new_scenario, start_game, and, when `player` is
	# given, act("choose_country", {tag: player}) (the command line, reseed); returns ""
func player_tag() -> StringName              # game.player, or &"" with no game
func reseed() -> void                        # the same map or scenario and player with seed + 1 (Ctrl/Cmd+R)
func drain() -> void                         # was _drain: empties game.events into Events; act() calls it, and so do
	# tools and tests that call a system directly (Territory.transfer); M3's season calls it after each phase
# act(action, args) and check(action, args): in a game with countries, when args has no "tag", a copy of args gets
#   tag = game.player (so a panel's verdicts and its acts speak for the player)
# drain(): owners_changed -> Events.owners_changed.emit(hexes); country_chosen -> Events.country_chosen.emit(tag)
```

`Session.new_game(map_id, seed)` stays for the sandbox. M1.5's `end_game()` and `unsaved_actions` are unchanged
(`choose_country` counts as an action). Still two autoloads.

### 5.7 Views (`core/views/`, pure, no engine calls)

```gdscript
# core/views/map_modes.gd  (new)
class_name MapModes extends RefCounted
enum Mode { TERRAIN, OWNER, RELIEF }          # keys 1, 2, 3
const TINT_ALPHA := 0.14
const OWNER_ALPHA := 0.55
const RELIEF_ALPHA := 0.65
const HOT_ALPHA := 0.20
const HOT_LIGHTEN := 0.15
const RELIEF_STOPS := [[0, Color("#4f8a4a")], [150, Color("#79a557")], [400, Color("#b7b56a")], [800, Color("#c49a5c")],
	[1300, Color("#a2744c")], [1900, Color("#8e7f74")], [2500, Color("#c9c7c4")], [3200, Color("#f4f5f8")]]
const HEIGHT_STEP_M := 16
# plain inputs (task C4):
static func hex_at_px(px: Vector2) -> Vector2i        # the cell under a map pixel, as TileMapLayer.local_to_map (the shader's twin)
static func height_bytes(map: MapData) -> PackedByteArray                 # 4.6; once per map
static func relief_ramp() -> PackedColorArray                             # 256 entries, by height byte
static func palette_from(colours: PackedColorArray, unowned: Color) -> PackedColorArray   # 256 entries: [0] unowned, [id] colours[id - 1]
static func colour_of(mode: int, owner_id: int, height_byte: int, palette: PackedColorArray, tint_on: bool, hot_id: int) -> Color
	# the shader's fragment colour for one texel pair (the twin the tests use)
# reading the game (task C11):
static func modes(game: Game) -> Array[int]           # [TERRAIN, OWNER, RELIEF]; no OWNER in a map-only game
static func palette(game: Game, colour_blind: bool) -> PackedColorArray   # palette_from the countries' colours or CB colours
static func colour_at(game: Game, mode: int, hex: Vector2i, palette: PackedColorArray, tint_on: bool, hot_id: int) -> Color
	# colour_of for the hex's owner and height byte

# core/views/border_lines.gd  (new)
class_name BorderLines extends RefCounted
const INK := Color("#1c140d", 0.85)
const INK_WIDTH := 2.4
const BAND_DEPTH := 7.0
const BAND_ALPHA := 0.85
static func for_chunk(map: MapData, owner: PackedByteArray, chunk: Vector2i, palette: PackedColorArray) -> Array[Dictionary]
	# for every hex of the chunk (EdgeLines.CHUNK cells a side) and its three owned edges (E, NE, NW): when both hexes are
	# land and their owners differ, one {kind: "border", points: [corner, corner], width: INK_WIDTH, colour: INK} and, for
	# each side with an owner, one {kind: "border_band", polygon: 4 points (the two corners and the same corners moved
	# BAND_DEPTH toward that hex's middle along the corner bisectors), colours: [edge, edge, inner, inner]}
static func chunks_touched(map: MapData, hexes: Array[Vector2i]) -> Array[Vector2i]   # each hex's chunk and its six neighbours'

# core/views/country_names.gd  (new)
class_name CountryNames extends RefCounted
const MIN_REGION_HEXES := 3
static func places(game: Game) -> Array[Dictionary]
static func places_of(game: Game, ids: PackedInt32Array) -> Array[Dictionary]
	# one per region of MIN_REGION_HEXES or more: {id, tag, text (the short name), at: Vector2 (map px, the middle of the
	# region's hex farthest in steps from its edge; ties by lowest index), span_px: float ((max col - min col + 1) * 104),
	# hexes: int}; in id order, then region order

# core/views/country_card.gd  (new)
class_name CountryCard extends RefCounted
static func of(game: Game, tag: StringName) -> Dictionary
	# {tag, name, long_name, adjective, colour, arms: {division, field: Color, charge: Color},
	#  relation: &"you" | &"neighbour" | &"other" | &"outside", capital: {name, hex, off_map: bool},
	#  focus: Vector2i (the capital, or the label hex of the largest region), districts, towns, cities (level 4 and up),
	#  land: Array[{cover: String, count: int}] (largest first), neighbours: Array[{tag, name}] (id order),
	#  passes: Array[String], playable: bool, play_reason: String, tip: String}

# core/views/place_search.gd  (new)
class_name PlaceSearch extends RefCounted
const LIMIT := 8
const FOLD := {"à": "a", "á": "a", "â": "a", "ä": "a", "è": "e", "é": "e", "ê": "e", "ì": "i", "í": "i", "ò": "o",
	"ó": "o", "ô": "o", "ö": "o", "ù": "u", "ú": "u", "ü": "u", "ç": "c", "ñ": "n", "ł": "l", "ń": "n", "ś": "s",
	"ź": "z", "ż": "z", "ı": "i", "ğ": "g", "ş": "s", "ø": "o", "å": "a", "ß": "ss"}
static func fold(text: String) -> String          # lower case, FOLD applied, spaces collapsed, trimmed
static func find(game: Game, text: String, limit: int = LIMIT) -> Array[Dictionary]
	# {kind: &"country" | &"place" | &"pass", name, hex, tag (the country, or the owner of the hex), detail}
	# detail: "country, 52 districts" / "town, Duchy of Milan" / "pass, 2,469 m". Rank: the folded name starts with the
	# folded text; then a word of it does; then it contains it. Within a rank: countries, places by level (high first),
	# passes; then name; then hex index. Unnamed places are left out. "" gives [].

# core/views/hex_card.gd  (M1.5, edit): adds the line "Owner" with the owner's long name (", yours" added on the
# player's land; "no one" for unowned land; no line at sea or in a map-only game), in the card's own line format
```

### 5.8 The season table

M2 adds no row: the table (`core/game/season.gd`) arrives in M3. Nothing in M2 runs per season.

### 5.9 Saves and the digest (for M3)

M3 owns save and load. These are the fields it must save, and how the digest already covers them:

| Field | Saved as | Digest |
|---|---|---|
| `MapState.owner` | `MapState.to_dict()` key `owner` (base64), schema 2 | `MapState.digest()` |
| `Game.countries` | a list of `Country.to_dict()` in id order | `Game.digest()` (each `digest_text`) |
| `Game.player` | the tag as text | `Game.digest()` |
| `Game.scenario` | its id, plus its `digest()` in the save header beside the map's id and digest | `Game.digest()` (the id) |
| `Game.defs` | not saved: fixed data, read from `res://data/defs/game_defs.tres` | not in the game digest |

The save header (standard 5.5) shows the country's long name and arms tag. A save names its scenario; loading checks the
scenario id exists in `GameDefs` (a missing one refuses the save as "made by another build"). M2's tests prove each piece
round-trips (section 10).

---

## 6. The map

### 6.1 The layer stack after M2

| z | What | Node | Since |
|---|---|---|---|
| 0 to 45 | ground, shade, light, sea, coast, piece ground, grid | `TileMapView` chunk layers | M1 |
| 50 | rivers, roads, tracks | `EdgeLineLayer` a chunk | M1 |
| 60, 70 | shadows; the standing group | | M1 |
| **80** | **the mode overlay** (tint, Owner, Relief; fog later in the same node) | `ModeOverlay` (World child) | M2 |
| **85** | **borders** | `EdgeLineLayer` a chunk, under `TileMapView`'s `Borders` node | M2 |
| **86** | **pennants** at capitals | `CapitalMarks` (World child) | M2 |
| 90 | selection, build targets | `marks` | M1 |
| screen | country names under place names | `CountryLabels`, then `MapLabels`, in the `Names` CanvasLayer (M1.5) | M2 |

Below zoom 0.20 `TileMapView` (with lines and borders) is hidden and the far picture shows; the overlay, pennants and
names stay. The overlay is drawn over `FarMap` too.

### 6.2 The mode overlay (`shell/map/mode_overlay.gd` + `.gdshader`, new)

```gdscript
class_name ModeOverlay extends Node2D          # z_index 80; one draw_rect over the map's px rectangle with the material
func setup_from(map: MapData, owner: PackedByteArray, palette: PackedColorArray) -> void   # builds the four textures below (C4)
func setup(game: Game, colour_blind: bool) -> void   # setup_from(game.map, game.state.owner, MapModes.palette(game, colour_blind)) (C13)
func set_palette_colours(palette: PackedColorArray) -> void   # a palette given as colours (the editor; C4)
func set_mode(mode: MapModes.Mode) -> void           # a uniform; hides the node in Terrain with the tint off
func set_tint(on: bool) -> void
func set_palette(colour_blind: bool) -> void         # rewrites the 256 x 1 palette only
func set_hot(id: int) -> void                        # the hovered country while picking; 0 none
func update_hexes(hexes: Array[Vector2i]) -> void    # rewrites those owner texels; one texture update a frame
func material_for_minimap() -> ShaderMaterial        # a copy sharing the textures, in UV mode (7.8)
func texture_bytes() -> int                          # for F3 and the perf tool
```

| Texture | Format, size | From |
|---|---|---|
| `owner_ids` | R8, cols x rows | `Image.create_from_data` on `state.owner` (no loop) |
| `heights` | R8, cols x rows | `MapModes.height_bytes(map)`, once per map |
| `palette` | RGBA8, 256 x 1 | `MapModes.palette(game, colour_blind)` |
| `ramp` | RGBA8, 256 x 1 | `MapModes.relief_ramp()` |

The shader (GLSL ES 3.0, canvas_item, Compatibility renderer): the vertex stage passes the map pixel (`VERTEX`, or
`UV * map_size` in minimap mode); the fragment finds the cell with the algorithm of `MapModes.hex_at_px` (the
pointy-top hexagon of the 104 x 102 cell, rows 76.5 px apart, odd rows shifted 52 px), returns clear off the map,
`texelFetch`es the owner id and the height byte, and picks the colour by mode with the alphas of 4.6. **It reads no screen
texture.** Uniforms: `mode`, `tint_on`, `hot_id`, `from_uv`, `map_size`, the alphas.

`FarMap` (`shell/mapview/far_map.gd`, edit) gains `func texture() -> ImageTexture` (the far picture, null before it is
built), so the minimap draws the same texture with no copy.

### 6.3 Borders (`TileMapView` and `EdgeLineLayer`, edits)

`TileMapView` gains a `Borders` node (z 85) beside `_lines` and:

```gdscript
const BORDERS_Z := 85
func set_chunk_borders(chunk: Vector2i, lines: Array[Dictionary]) -> void   # one EdgeLineLayer a chunk; [] frees it
func border_chunks() -> Array[Vector2i]
```

`EdgeLineLayer` learns two kinds: `border_band` (a polygon with per-vertex colours, drawn first) and `border` (a stroke
with the line's own `colour`, drawn over). Rivers, roads and tracks draw as before. The map scene builds the borders of
every chunk at game start in the same sliced queue as the lines, and on `owners_changed` rebuilds
`BorderLines.chunks_touched(map, hexes)`; a palette change rebuilds every chunk (sliced, 5 ms a frame).

### 6.4 Country names (`shell/mapview/country_labels.gd`, new) and pennants (`shell/map/capital_marks.gd`, new)

`CountryLabels` (a Node2D in the `Names` layer, drawn before `MapLabels`) draws `CountryNames.places(game)` in screen
space: the name upper-cased in the Theme's `TitlePanel` font (Cinzel), `Tokens.TEXT` at 0.9 alpha over a 4 px `Tokens.INK`
outline. Size `clamp(round(0.6 * span_px * zoom / (0.62 * letters)), 13, 40)` px; drawn only at 13 px or more, and only
in Owner mode, while picking, or below zoom 0.9 in Terrain. It recomputes on `game_started` (all) and `owners_changed`
(`places_of` the ids that changed); it lays out again on `CameraRig.view_changed`, never every frame. `MapLabels` takes
the capitals from the game (`Country.capital`), not from `MapData.places[].capital`, and lists `CountryLabels`' boxes in
its `obstacles`.

`CapitalMarks` puts a `pennant_pole` (24 x 56, brass) and a `pennant_cloth` (28 x 20, white, tinted with the country's
palette colour) 46 px above the middle of each playable capital, as `Sprite2D`s in map space; visible in Owner mode and
while picking. The textures come from the window's Theme (`get_window().theme.get_icon(&"pennant_pole", &"Kit")`), never
from a file path, so the 1x and 2x kits both work. Bake slice 2 (task C5) also makes `minimap_frame` (256 x 144, margins 56 and 16), `shield_rim`
(48 x 56) and `shield_rim_sm` (20 x 24), each at 1x and 2x.

### 6.5 The map scene (`shell/map/map_scene.gd`, edits)

| On | Does |
|---|---|
| `game_started` with countries | `ModeOverlay.setup`; queues every chunk's borders after its lines; `CountryLabels` and `CapitalMarks` set up; the mode from `state/map_mode` (Owner while picking) |
| `game_started` without countries | the overlay only for Relief; no borders, names or pennants |
| `owners_changed(hexes)` | `update_hexes`; queue the touched border chunks; names of the changed ids; pennants |
| `country_chosen` | pennants and the pick's highlight off; mode back to `state/map_mode` |
| `set_mode(mode)` (key, top bar) | overlay uniform, names' and pennants' visibility; writes `state/map_mode` (not while picking) |
| `configure(settings)` (M1.5) | also `map/borders` (the Borders node), `map/owner_tint`, `accessibility/country_colours` (palette, border rebuild) |
| `MapInput.select_requested` while picking (a game with countries and no player) | does not select the hex: emits `country_clicked(tag)` with the owner's tag (none for sea or unowned land) |
| `MapInput.hover_changed` while picking | `ModeOverlay.set_hot(owner id)`; emits `country_hovered(tag)` (`&""` off land) |

`MapScene` gains `signal country_clicked(tag: StringName)`, `signal country_hovered(tag: StringName)`,
`func set_mode(mode: int) -> void`, `func mode() -> int`, `func picking() -> bool`.

---

## 7. The UI of M2

Built from the M1.5 kit (`ui-and-controls-spec.md` 3.5, `ui-style-and-feedback-spec.md` 5). Every control's colours and
fonts come from the Theme; HUD controls take no focus, screens do.

### 7.1 Keys and settings

| Action (`Bindings.DEFAULTS`) | Key (Mac) | Does | Who hears it |
|---|---|---|---|
| `view_mode_1`, `_2`, `_3` | 1, 2, 3 | Terrain, Owner, Relief; refused with a toast "no countries on this map" for Owner in a map-only game | `MapInput` -> `mode_requested(mode)` |
| `view_mode_4` | 4 | registered in M6 (Supply) | |
| `ui_find_place` | Ctrl+F (Cmd+F) | opens and closes the place search | `MapInput` -> `find_place_requested` |
| `game_country` | C | your country's panel; while picking, focus to the list; a map-only game toasts "no countries on this map" | `MapInput` -> `country_requested` |
| removed | 1 to 4 | `view_season_1..4` leave the keys (the Layers popover and F3 keep the preview until M3) | |

`MapInput` (M1.5) loses `season_requested(i)` and gains `mode_requested(mode: int)`, `find_place_requested`,
`country_requested`.

| `Settings.SCHEMA` key | Type, choices (default) | Page and row | Applies |
|---|---|---|---|
| `map/borders` | bool (true) | Map: "Borders"; also Layers | `MapScene.configure` |
| `map/owner_tint` | bool (true) | Map: "Country tint in Terrain"; also Layers | `ModeOverlay.set_tint` |
| `map/minimap` | bool (true) | Map: "Minimap"; also Layers | `Hud` |
| `accessibility/country_colours` | `standard`, `colour_blind` (`standard`) | Accessibility: "Colour-blind safe country colours" (a switch) | overlay palette, borders, minimap, editor |
| `state/map_mode` | `terrain`, `owner`, `relief` (`terrain`) | no row (remembered) | `MapScene` |

Each row carries `since: 2`; the Options screen shows them under M1.5's rule (later rows hidden).

### 7.2 Country arms (`shell/ui/country_arms.gd`, new)

```gdscript
class_name CountryArms extends Control     # mouse ignored; custom_minimum_size 48 x 56 (or 20 x 24 with `small`)
@export var small := false
func set_country(card_arms: Dictionary) -> void   # CountryCard.of(game, tag)["arms"]; {} draws nothing
const SHIELD := PackedVector2Array([Vector2(0, 0), Vector2(48, 0), Vector2(48, 26), Vector2(47, 33), Vector2(45, 39),
	Vector2(41, 45), Vector2(36, 50), Vector2(30, 54), Vector2(24, 56), Vector2(18, 54), Vector2(12, 50), Vector2(7, 45),
	Vector2(3, 39), Vector2(1, 33), Vector2(0, 26)])     # the heater outline at 48 x 56 (scaled for `small`); the bake
	# draws the rim on the same points (tested)
```

`_draw()`: the field polygon (`SHIELD`), the division's charge polygons clipped to it with `Geometry2D.intersect_polygons`,
antialiased 1 px division lines, then the rim (`get_theme_icon(&"shield_rim", &"Kit")`, or `shield_rim_sm` when small).
Division geometry at 48 x 56: per_pale the right half; per_fess below y 26; per_bend below the line (0,0)-(48,56);
quarterly the top-right and bottom-left quarters about (24, 26); cross bands 10 px through x 24 and y 22; saltire two
9 px bands on the diagonals; chief y 0 to 16; fess y 20 to 34; pale x 17 to 31; bend a 10 px band on the diagonal;
bordure a 6 px rim (the field is the inner shield); plain nothing.

### 7.3 The top bar (`shell/hud/top_bar.tscn/.gd`, M1.5, edit)

Left to right after the brand: `CountryArms` (small) and the long name, one flat button ("Republic of Genoa"; tooltip
"Your country (C)"; opens the country panel). While picking: "Italy, 1480: choose your country". A map-only game keeps
M1.5's "North Italy · Sandbox, seed N". Then the mode switch: a `Segmented` "Terrain | Owner | Relief" (Owner hidden in a
map-only game), tooltips with the key, emitting the same `mode_requested`. Narrowing: the name hides before the switch;
arms, brand, Layers, help and menu always show. Listens to `game_started`, `country_chosen`.

### 7.4 The country panel (`shell/panels/country_panel.tscn/.gd`, new; in the dock)

```gdscript
class_name CountryPanel extends PanelContainer    # a PanelFrame (M1.5) with the cartouche title
signal play_requested(tag: StringName)
signal look_at_requested(hex: Vector2i)
signal country_requested(tag: StringName)         # a neighbour link
func show_country(tag: StringName, picking: bool) -> void
func refresh() -> void                            # from CountryCard.of(Session.game, tag)
func clear() -> void
func shown_tag() -> StringName
```

| Part | Content (from `CountryCard`) |
|---|---|
| Title (cartouche) | short name |
| Head | `CountryArms` 48 x 56; long name; "your country" / "neighbour" / "outside power" in `Hint` |
| Ledger (key and value rows) | Capital (a link that glides there; "Rome, off this map" for an outside power); Districts; Towns ("20, 2 of them cities"); Passes (names, or "none"); Land (the three largest covers: "farmland 17 · grassland 10 · woods 9") |
| Neighbours | one link each, in id order; a click shows that country |
| While picking | the tip in `LabelFlavour`; **Play as {name}** (`ButtonPrimary`, `KitButton.set_verdict(Session.check("choose_country", {tag}))`, so an outside power shows the lock and the reason) |
| Footer | "Show on the map" (glides to `focus`, switches to Owner mode) |

Later milestones add sections here: treasury and taxes (M4), army (M6), Declare war (M7), relations and war goals (M9),
research (M11). Opens with C, the top bar name, the hex panel's Owner link, a neighbour link, a country search result and
the pick. Esc closes it (the M1.5 ladder's dock step). The dock shows one panel at a time: a newly opened country panel
replaces the hex panel, and selecting a hex replaces the country panel.

### 7.5 The pick (`shell/screens/country_pick.tscn/.gd`, new, `OVERLAY`)

Pushed by the App when a game with countries starts with no player. The map stays live in Owner mode, fitted.

| Part | Content |
|---|---|
| Top centre | `Ribbon` "Choose your country"; a `Hint` line "Click a country's land, or pick it from the list" |
| Left | a `PanelFrame` "Countries", `Tokens.PANEL_W` wide: a `NavList` of the playable countries (`text` the short name, `count` the districts), largest first, ties by id; below a `SectionHead` "Outside powers", one `Hint` line each ("France: Paris is off this map") |
| Dock | the panel of the country last clicked on the map or chosen in the list, `picking = true` |

Input: a click on land shows its owner's panel (not the hex panel) and glides there (`MapScene.country_clicked`);
hovering land brightens its owner and its row (`country_hovered`). The list has the keyboard: Up and Down move, Enter
shows that country (panel and glide), Enter again on the same row plays it (HUD buttons take no focus, so the list does
what Play as does). "Play as" and that second Enter call `Session.act("choose_country", {tag})`. On `Events.country_chosen` the screen ends itself; the App glides to the capital
and toasts "You rule the Republic of Genoa from Genoa." `back()` (Esc): closes the dock's panel when one is open,
otherwise asks the App for the pause menu; it always returns true (the pick cannot be skipped).

### 7.6 The hex panel and the hover card (M1.5, edits)

- **Hex panel** (`shell/panels/hex_panel.tscn/.gd`): an "Owner" row (the long name as a link to its country panel,
  "no one", nothing at sea or in a map-only game), as the mockup shows. The works section shows only when
  `Territory.at_home_check(Session.game, Session.player_tag(), hex)` is ok; otherwise one `Reason` line with its reason
  ("not your land: the Duchy of Milan holds it"). The buttons still take their verdicts from `Session.check`.
- **Hover card**: `HexCard.of` gives the owner line (5.7); `MapHover` needs no change.
- A refused U (or any key action) toasts the reason, as M1.5 does.

### 7.7 New game (`shell/screens/new_game.tscn/.gd`, new, `MODAL`, 640 x 440)

A `ModalFrame` with the ribbon "New game". Body: `SectionHead` "Scenario", one toggle row for each scenario of
`GameDefs.scenarios` (M2 has one: "Italy, 1480", selected) with its blurb in `LabelFlavour`; `SectionHead` "Your country",
`Body` "You choose it on the map once it is drawn."; a "More" toggle that shows "Seed" (a `LineEdit` of digits, filled
with a random seed from the shell's own `RandomNumberGenerator` when the page opens; `core/` is not involved) and a
"Random" button. Footer: Back (Esc), **Begin** (`ButtonPrimary`, focused; Enter). Begin sends
`ctx.app_requested(&"new_game", {scenario: id, seed: n})`. The main menu gains **New game** (primary, focused, first);
Map sandbox becomes a secondary button while developer tools are on.

### 7.8 The minimap (`shell/hud/minimap.tscn/.gd`, new)

In `MapArea`'s bottom-right column above the zoom control (M1.5 layout). A `PanelContainer` of the variation
`PanelMinimap` (the baked `minimap_frame`, 9-slice), 220 x 124 logical px, holding `Picture` (a Control whose `_draw()`
draws the far picture's texture (`FarMap.texture()`, shared, no copy) as the elongated hexagon of the frame's opening
with UVs, letterboxed on `Tokens.SLOT`), `Overlay` (the same polygon with `ModeOverlay.material_for_minimap()`) and
`Frame` (the camera's rectangle from `CameraRig.view_changed`, 2 px `Tokens.GOLD`, clamped to the opening). A click
glides (`look_at_requested(map_px)`, M1.5's HUD signal), a drag jumps while held. Hidden without a game, with
`map/minimap` off and in photo mode.

### 7.9 Place search (`shell/screens/find_place.tscn/.gd`, new, `OVERLAY`)

Top centre under the bar, 420 px wide: a `PanelCard` with a `LineEdit` ("Find a place or a country") and up to 8 result
rows (name in `Label`, `detail` in `Hint`) from `PlaceSearch.find`. Typing refreshes the list; Up and Down move; Enter
or a click: a place or pass sends `ctx.app_requested(&"look_at", {hex, select: true})`; a country sends
`ctx.app_requested(&"country", {tag})` (glide to `focus`, its panel). The screen ends after a choice; Esc or
Ctrl/Cmd+F closes it. While the `LineEdit` has focus no map key fires (M1.5's "text fields win").

### 7.10 Layers popover, F3, pause menu (M1.5, edits)

- **Layers:** switches Borders, Country tint, Minimap (the three settings); the season preview stays until M3.
- **F3:** a line "countries 13 · mode Owner · border chunks 1 · overlay 0.4 KB".
- **Pause menu:** the subtitle is the long name ("Republic of Genoa"); M3 adds the date.

### 7.11 The App (`shell/app/app.gd`, M1.5, edits) and the command line

| Request or event | The App |
|---|---|
| `app_requested(&"new_game", {scenario, seed})` | pops the menus, pushes Loading, `Session.new_scenario(scenario, seed)`; a returned problem pops Loading, toasts it and shows the main menu again |
| `game_started` with countries and no player | sets Owner mode for the pick, pushes `country_pick` |
| `app_requested(&"country", {tag})` | `hud.show_country(tag, picking)`, glides to the card's `focus` |
| `app_requested(&"close_dock")`, `app_requested(&"pause")` | closes the dock panel; pushes the pause menu |
| `country_chosen` | glides to the capital, toasts, restores the mode |
| `MapScene.country_clicked(tag)` (only while picking) | `hud.show_country(tag, true)` and a glide to its capital |
| `MapScene.country_hovered(tag)` | the pick list's row under the hover |
| `MapInput.country_requested`, `find_place_requested` | the dock's country panel; push or pop `find_place` |

Command line: `-- --new-game [--scenario=north_italy_1480] [--country=TAG] [--seed=N]` starts a scenario game and skips
the pick when `--country` is given; `-- --sandbox` is unchanged.

`Hud` (M1.5) gains `show_country(tag: StringName, picking: bool)`, `close_dock()` and the minimap in its bottom-right
column; `screen_ids.gd` gains `country_pick` and points `new_game` and `find_place` at their scenes.

---

## 8. Data and the editor

### 8.1 Files

| File | Holds | Made by |
|---|---|---|
| `godot/data/defs/game_defs.tres` | `GameDefs`: the 13 countries (external), the one scenario (external), tinctures, CB palette, unowned colour, contrast limits | by hand (task C9) |
| `godot/data/defs/countries/<tag lower>.tres` (13) | one `CountryDef` each, table 4.2 and 4.7 | by hand (C9) from this page; v0.2.2's `data/countries.json` for names and colours |
| `godot/data/scenarios/north_italy_1480.tres` | `ScenarioDef`: 4.1, 4.4 by hand; `owner` and `map_digest` written by the tool | seeds by hand (C9), `owner` by `tools/build_scenario.gd` |

All text `.tres`. `godot/data/README.md` gets a section for `defs/` and `scenarios/`.

### 8.2 Checks

`ScenarioDef.validate(map, defs, deep)` reports, each as one line naming the field:

1. `map_id` is the map's; `map_digest` equals `map.digest()` ("built on another map: run tools/build_scenario.gd").
2. 1 to 254 countries, unique, each in `defs`; `capitals` and `cb_colours` sized to them; each `cb_colours` value under 8.
3. A capital is `NO_HEX` or a land hex holding a place; `capital_name` is set for every `NO_HEX` country.
4. Seeds: each on land, its tag listed, `kind` town or anchor; **every place with level >= 1 or castle >= 1 has exactly one
   town seed on its hex**; no anchor on such a place; no two seeds on one hex.
5. Pins: on land; tag listed or `&""`.
6. `owner` has `map.hex_count()` bytes; sea bytes are 0; values up to the country count; every listed country owns a hex;
   every on-map capital is owned by its country.
7. *Deep:* `owner` equals `ScenarioGrowth.grow(map, self)`; every neighbour pair (`neighbour_pairs`) is at least
   `min_contrast` apart in `colour` and at least `min_contrast_cb` apart (worst of four visions) in the CB palette.

`GameDefs.validate()`: unique tags; each `CountryDef.validate`; 8 CB colours; every scenario's id unique.

### 8.3 The tool (`godot/tools/build_scenario.gd`, new) and CI

```
"$GODOT" --headless --path godot -s res://tools/build_scenario.gd [-- --scenario=north_italy_1480]           # regrow, write owner and map_digest, print the table of 4.2
"$GODOT" --headless --path godot -s res://tools/build_scenario.gd -- --check                                 # every scenario of GameDefs: deep validate; exit 1 on any line
```

A CI step "Generated scenarios are current (build_scenario --check)" follows "Generated map is current" in
`.github/workflows/godot.yml`, with the same error style. A change to the map, the seeds, the pins or the growth numbers
without a rebuild fails it.

### 8.4 The editor (`shell/editor/scenario_editor.tscn/.gd`, new, `@tool`)

Opened in the Godot editor (same engine). It shows a scenario on the game's own layers and paints the owner layer.

```gdscript
@tool
class_name ScenarioEditor extends Node2D
@export var scenario: ScenarioDef                    # the file it edits
@export var mode: MapModes.Mode = MapModes.Mode.OWNER
@export var colour_blind := false
@export var show_seeds := true
@export var live_regrow := true                      # regrow on every paint; off for maps over 10,000 hexes
@export var inspect_hex := Vector2i(-1, -1)          # type a hex; `facts` shows it
@export_multiline var facts := ""                    # filled by the tool: cover, height, relief, climate, place,
	# rivers, roads, pass, owner, the seed or pin on it, the growth cost
@export_tool_button("Regrow") var regrow_action := regrow
@export_tool_button("Write the scenario") var write_action := write
@export_tool_button("Check") var check_action := check
func regrow() -> void        # pins from the Pins layer, ScenarioGrowth.grow, overlay and borders redrawn
func write() -> void         # pins and owner and map_digest into the file (ResourceSaver), then check()
func check() -> void         # deep validate; the lines go to `facts` and the Output panel
```

There is no `Session` in the editor: the scene loads the scenario's map (`res://data/maps/<map_id>.tres`) and
`res://data/defs/game_defs.tres` itself. Children: `View` (`TileMapView` filled by `MapCells` from the map and a wild
`MapState`, summer tiles), `Overlay` (`ModeOverlay`), borders (`TileMapView.set_chunk_borders`), `Seeds` (a display
layer in map space: a dot on town seeds, a ring on anchors, tinted by tag) and **`Pins`**: a `TileMapLayer` with a TileSet the editor builds from the
marks atlas's `mark/white` tile: one alternative tile per country (its palette colour, custom data `tag`) and one grey
"no one". The designer selects `Pins` and paints with Godot's TileMap tools; a painted cell is a pin, an erased cell is
no pin; `changed` regrows when `live_regrow` is on. Pins equal to what growth gives are dropped on Write. Cover, places,
main use and level are shown, not painted (D24).

---

## 9. Speed

On the made-up Europe (`FakeMap.build(494, 247, 1480)`, 122,018 hexes) with a made-up scenario of 60 countries
(`FakeScenario.build`, below), measured by `godot/tools/perf_map.gd` (windowed, 1920 x 1080, the full tileset), which
gains a `--countries=60` pass (on by default) and these rows in `godot/tests/perf_budget.json`:

| Row | Limit | Class | What |
|---|---|---|---|
| `owner_frame_worst_ms` | 16 | gpu | worst frame panning at zooms 2, 1, 0.5, 0.25, 0.12 in Owner mode with borders and names on |
| `owner_frame_mean_ms` | 8 | gpu | mean of the same |
| `height_bytes_ms` | 60 | cpu | `MapModes.height_bytes` once per map |
| `overlay_setup_ms` | 20 | cpu | `ModeOverlay.setup` (four textures) |
| `mode_switch_ms` | 2 | cpu | `set_mode` to the next frame |
| `borders_all_ms` | 2,000 | cpu | every border chunk built, total CPU of the 5 ms slices |
| `border_chunk_ms` | 10 | cpu | one chunk's `BorderLines.for_chunk` and mesh, worst |
| `owner_change_frame_ms` | 16 | cpu | `Territory.transfer` of 1 hex through `Session`: drained, texel written, touched chunks rebuilt, the two countries' names, to the next frame; worst of 24 |
| `owner_change_200_ms` | 50 | cpu | a transfer of 200 hexes (a peace treaty): all the work, total; each frame under 16 ms (chunks sliced) |
| `country_names_ms` | 15 | cpu | `CountryNames.places_of` for the largest country |
| `scenario_grow_ms` | 5,000 | cpu | `ScenarioGrowth.grow` on the whole map (the tool and the editor, not play) |
| `owner_mem_mb` | 8 | mem | overlay textures and border meshes |

`FakeScenario.build(map: MapData, count: int, seed_value: int) -> Dictionary` (`core/mapgen/fake_scenario.gd`, new;
tools and tests only): `count` capitals among the map's places, taken in place order when at least 20 hexes from every
capital taken before; every place a town seed of its nearest capital (cube distance, ties by id); tags `F01` to `F60` (two digits, as many as `count`); colours
by the golden-angle hue (saturation 0.55, value 0.8); CB colours greedy in id order; `ScenarioGrowth.grow`; returns
`{defs: GameDefs, scenario: ScenarioDef}`. No luck: the same map gives the same scenario.

Never asserted in GUT. The nightly perf job fails past a CPU or memory limit; the gpu rows are enforced with
`--gpu-limits` on real hardware, which the owner runs once on Windows and once on the Mac before M2 closes. The UI probe
(`tools/ui/perf_ui.gd`, M1.5) adds the minimap and the pick screen to its HUD frame row.

North Italy for scale: 399 hexes, one border chunk, a few hundred border segments; nothing there is measurable.

---

## 10. Tests

GUT unless said. Every new check has a planted-fault case (marked P).

| File | Cases |
|---|---|
| `tests/core/test_country_defs.gd` (new) | every file of `data/defs/` loads and validates; P: a duplicate tag, a lower-case tag, an unknown division, an unknown tincture, 7 CB colours, a scenario listed twice, each reported with its field |
| `tests/core/test_colour_contrast.gd` (new) | ΔE of black and white is 100; a colour against itself 0; the simulations of the Okabe-Ito colours against reference values (to 0.5); `worst_delta_e` is the minimum |
| `tests/core/test_country_state.gd` (new) | `Country` round trip; P: a wrong schema gives null; `digest_text` changes with each field |
| `tests/core/test_map_data.gd` (edit) | `MapState` round trip with `owner`; a schema 1 dict loads with owner 0; the digest moves with one owner byte |
| `tests/core/test_scenario_growth.gd` (new) | on a 9 x 7 fixture map (built in the test): a crest without a pass costs 5, with a pass 2, a river 3, a stream 2; ties go to the earlier seed; anchors start at 1; reach leaves land at 0; pins overwrite, `&""` frees; sea stays 0; the same input twice gives the same bytes; `neighbour_pairs` and `regions` on a known layout |
| `tests/core/test_scenario_def.gd` (new) | P for each rule of 8.2: the map digest changed; a capital on sea; a capital owned by another; a place with no town seed; two seeds on a hex; an anchor on a town; a pin on sea; an owner byte on sea; a stale owner (one byte flipped) with `deep`; two neighbours with the same colour; two neighbours with CB colours under 20 apart |
| `tests/core/test_scenario_1480.gd` (new) | the committed scenario validates deep; counts per country equal table 4.2; towns per country equal 4.2; every land hex owned; the regions are the list of 4.5; the pass owners equal 4.5; the neighbour pairs equal 4.5; the 10 playable and 3 outside powers |
| `tests/core/test_territory.gd` (new) | `at_home_check`: every row of its table; `transfer` skips sea, off-map and unchanged hexes, queues one event with exactly the changed hexes, none when nothing changed; `districts`, `count`, `neighbours` on the fixture |
| `tests/core/test_countries.gd` (new) | `setup` gives ids in order and capitals; `choose_check`: every row of its table; `choose` sets the player and queues `country_chosen` once; a second choose is refused and changes nothing |
| `tests/core/test_improve_actions.gd` (edit) | the 2,000-action property on the fixture scenario with actors drawn from all tags and `&""`: check and act agree; **every accepted build, upgrade or clear is on the actor's land**; a refused one leaves the digest as it was; OWNS: Improve never writes owner, countries or player, Territory only owner, Countries only countries and player (P: a stub action registered by the test that writes `owner` is reported); the map-only game still builds anywhere; same seed and actions, same digest |
| `tests/core/test_map_modes.gd` (new) | `hex_at_px` gives every hex for its own middle (`MapTiles.cell_centre`) and for points 40 px from the middle toward each neighbour; `palette_from` and, from C11, `palette` (both palettes, index 0); `height_bytes` (sea 0, 16 m steps, the cap); `relief_ramp` at the stops; `colour_of` for each mode, tint off, hot; `modes` of a map-only game has no OWNER |
| `tests/core/test_border_lines.gd` (new) | two owners on a fixture: one border per differing land edge, none on coast or between equal owners; two bands per country edge, one beside unowned land; polygons inside their hex; every edge appears once over all chunks (no double at chunk seams); `chunks_touched` |
| `tests/core/test_country_names.gd` (new) | one name per region of 3+; the deepest hex; ties by index; `places_of` equals the matching part of `places` |
| `tests/core/test_country_card.gd` (new) | Genoa's card from the committed scenario: districts 14, towns 2, capital Genoa, neighbours Milan and Savoy, relation `you` when the player is GEN; France `outside` with the reason; `land` sums to districts |
| `tests/core/test_place_search.gd` (new) | "ver" gives Verona and Vercelli (prefix rank) before any substring; "mil" gives the country Milan first, then the town; "bernin" gives the Bernina pass (prefix) then Hospice Bernina (word start), not Bern; `fold("Città")` is "citta"; unnamed places never appear; at most 8 |
| `tests/core/test_hex_card.gd` (edit) | the owner line, ", yours", "no one", none at sea and in a map-only game |
| `tests/core/test_fake_scenario.gd` (new) | 60 countries on a 120 x 60 fake map; every listed country owns land; same map, same bytes |
| `tests/shell/test_session.gd` (edit) | `new_scenario` with and without a player, and with a planted bad scenario (P: it returns the problem and starts nothing); `act` and `check` fill `tag`; `country_chosen` is emitted once after the act; `Territory.transfer` then `drain()` emits `owners_changed` once with the changed hexes; `reseed` keeps scenario and player |
| `tests/shell/test_mode_overlay.gd` (new) | `MapModes.hex_at_px` equals `TileMapLayer.local_to_map` (a layer with the M1 TileSet) on 10,000 points of a 30 x 20 grid (points within 0.5 px of an edge are listed, not failed: rounding differs there); the textures' sizes and bytes; `set_mode` changes only a uniform (no texel written: a counter); `update_hexes` writes exactly those texels; the minimap material shares the textures |
| `tests/shell/test_border_mesh.gd` (new) | `EdgeLineLayer` with border kinds: bands before ink; vertex colours as given; `set_chunk_borders([])` frees the node |
| `tests/shell/test_map_scene.gd` (edit) | a scenario game: border chunks exist; a `Territory.transfer` through `Session` rebuilds exactly `chunks_touched` (a counter) and writes those texels; keys 1, 2, 3 set the mode; a map-only game has no borders |
| `tests/shell/test_layer_stack.gd` (edit) | z 80 overlay, 85 borders, 86 pennants, names under place names |
| `tests/shell/test_country_labels.gd` (new) | sizes by the formula; hidden under 13 px; shown in Owner mode at zoom 2; capitals from the game in `MapLabels` |
| `tests/shell/test_country_arms.gd` (new) | each division's polygons lie inside `SHIELD`; the colours drawn are the tinctures (a draw recorder); small and large |
| `tests/shell/test_country_panel.gd` (new) | the rows of 7.4 for Genoa; a neighbour link emits `country_requested`; picking shows Play as with the verdict; France's button is off with the reason |
| `tests/shell/test_country_pick.gd` (new) | the list order; Enter on Genoa shows Genoa, Enter again chooses it (the event pops the screen); Play as does the same; Esc with the dock open closes it, then asks for pause; a click on Milanese land shows Milan |
| `tests/shell/test_new_game.gd` (new) | Begin sends `new_game` with the scenario and the typed seed; Random changes the seed; Esc goes back |
| `tests/shell/test_find_place.gd` (new) | typing, arrows, Enter on a place sends `look_at` with select; on a country sends `country`; Ctrl+F closes |
| `tests/shell/test_minimap.gd` (new) | a click at the minimap's middle asks to look at the map's middle; the frame follows `view_changed`; hidden with the setting off |
| `tests/shell/test_app_flow.gd` (edit) | main menu, New game, Begin, the pick, Play as Genoa, the top bar shows "Republic of Genoa", C opens the panel, Esc closes it, Esc pauses; `--new-game --country=GEN` skips the pick |
| `tests/shell/test_hud.gd`, `test_hex_panel.gd`, `test_bindings.gd`, `test_settings.gd` (edits) | the top bar parts and narrowing; the Owner row and the home reason; the M2 actions and no season keys; the five keys of 7.1 with their defaults and P: a wrong value falls back |
| `tests/shell/test_scenario_editor.gd` (new) | headless: the editor scene loads the scenario; `set_cell` on `Pins` and `regrow` moves the owner and the border chunk; `write` to a `user://` copy, `check` reports nothing; an erased pin restores the grown owner |
| Python `tests/test_bake_ui.py` (edit) | slice 2 pieces at both scales; `shield_rim`'s transparent interior contains `CountryArms.SHIELD` (read from the .gd as the bake reads `tokens.gd`); P: a rim one pixel off fails |
| `tests/shell/test_ui_monkey.gd` (edit) | adds 1, 2, 3, C, Ctrl+F, clicks during the pick and Play as; invariants: an accepted works action is always on the player's land; the player never changes after the pick; the digest changes only after an accepted action |
| `godot/tools/map/probe_mode_overlay.gd` (new, windowed; CI under xvfb with the perf job) | draws north Italy in each mode, reads the frame back, and compares the pixel at every hex middle with `MapModes.colour_at` (tolerance 3 per channel); prints PASS or FAIL per mode; P: `--plant` swaps two palette entries and must print FAIL |
| Pictures (`tools/ui/shot_ui.gd`, M1.5) | Terrain, Owner and Relief at fit and at zoom 1 on Genoa; both palettes; the pick with Genoa's panel; the country panel; New game; the search with results; the minimap; the arms sheet of all 13. Signed by the art director; then goldens (0.5 %) |

**Determinism:** the property test and `test_map_data` digest checks above; **save round trip:** `MapState`,
`Country` and the `Game` fields of 5.9 each round-trip in their tests (the whole save is M3's).

---

## 11. Risks and probes

| Risk | Probe and when | Fallback |
|---|---|---|
| The shader's hex lookup and the tiles disagree near edges | `test_mode_overlay.gd` (the twin against `local_to_map`) in task C4; `probe_mode_overlay.gd` in CI and on the owner's Mac during C4, before C13 builds on the overlay | Draw the tint as per-hex polygons in the border meshes (costs memory; measured) |
| R8 textures or `texelFetch` misbehave on the Mac's Compatibility driver | `probe_mode_overlay.gd` on the owner's Mac on C4's first day | RGBA8 textures (four times the bytes, still under 1 MB) |
| Borders over trees read as clutter; the tint too weak or strong | the pictures of section 10, signed by the art director in C13 | Borders at z 55 (under the trees, bands only); the alphas are constants |
| History disputes (a hex, a fold) | Opus walks the reviewer and the owner through 4.4 and 4.5 before C9 | Seeds and pins are data; the CI check keeps them honest |
| Tiny countries (Lucca 2, Mantua 3) are no fun to play | the playtest (pick Lucca); M4 and M8 decide their economy and AI | Mark them outside powers (one value each) |
| Country names collide with place names at middle zoom | pictures at zoom 0.5 and 0.9 | Hide country names above zoom 0.7 in Terrain |
| `Geometry2D` clipping draws seams between division polygons | the arms sheet at 1x and 2x | Draw each division as one polygon computed already clipped |
| The editor's live regrow is slow on Europe | `scenario_grow_ms` | `live_regrow` off by default above 10,000 hexes (built in) |
| Painting in the editor writes a scenario that the CI then rejects | `write` runs `check` and prints the lines | none needed |

---

## 12. Changes to other pages

Made in this change:

| Page | Edit |
|---|---|
| `docs/architecture/godot-architecture.md` | 9.1, row M2: modes in the order Terrain, Owner, Relief. 9.2, row M2: points at this spec and its plan; status "specified and planned, waits for the owner's go; starts after M1 (T16) and M1.5 close" |
| `docs/architecture/m1-build-spec.md` | Section 5, row z 80: the tint becomes M2's mode overlay; a new row z 85, borders |
| `docs/architecture/ui-style-and-feedback-spec.md` | Section 2, the row of UI spec 8: "no shaders in the UI" with the map shaders allowed (1.2); 4.5, slice 2 pieces renamed (`shield_rim`, `shield_rim_sm`, `pennant_pole`, `pennant_cloth`) |
| `docs/architecture/ui-style-and-feedback-plan.md` | The slice 2 line names task C5 of `m2-build-plan.md` |
| `docs/architecture/ui-and-controls-spec.md` | 4.1, the `view_mode` row: 1 Terrain, 2 Owner, 3 Relief, 4 Supply (M6); 6.5, the colour-blind row: the pattern comes with occupation (M7); 7, the map-mode row: id and height textures and a palette; 8, the shader line names the minimap |
| `docs/architecture/ui-and-controls-plan.md` | Section 4, row M2: the mode order and the files of this spec |
| `docs/design/ui/design.md` | Section 9, slice 2 rows: the renamed pieces |
| `docs/README.md` | Links to this spec and its plan |

Made by the tasks (listed in the plan): `godot/README.md` (layout, keys, the editor; C19), `godot/data/README.md` (C9),
`.github/workflows/godot.yml` (the scenario check, C6), `godot/tests/perf_budget.json` (C18), `CLAUDE.md` (one line,
`build_scenario.gd --check`, in its Godot command list; C19). No port rule changes: no new autoload, no new layer.

---

## 13. What M2 hands to later milestones

| M | Takes from M2 | M2 leaves for it |
|---|---|---|
| M3 | The fields of 5.9 to save; `owners_changed` and `country_chosen` for the action log ("You rule the Republic of Genoa"); `CountryDef.adjective` and the seal's initial for the report; `Territory.neighbours` for `Knowledge.knows` (a shared border); the long name for the pause menu and save rows | Save and load, the header's scenario digest, the date in the top bar |
| M4 | `Country` for the treasury; the home rule for works and `cancel_work`; `Territory.districts` for the economy's sums; the country panel's treasury section | Money, taxes, the chips |
| M6 | Owner for supply and movement; the overlay for the Supply mode (a third texture) and fog (a fourth); `view_mode_4` | Armies |
| M7 | `Territory.transfer` for capture; a `controller` byte beside `owner`; the CB **pattern on occupied land** in the overlay; Declare war in the country panel | Occupation and its pattern |
| M8 | Actions with `tag`; `Countries.playable` and outside powers as AI countries | The AI |
| M9 | `transfer` for peace terms; relations and war goals in the country panel; a Relations mode | Diplomacy |
| M12 | `Country.alive` and "is no more"; CB colours for countries that appear in play (the least-used colour among its neighbours) | Countries that fall or rise |
| E2 | `ScenarioGrowth` and `build_scenario` for Europe 1480 (v0.2.2's seed points as anchors plus the map's towns); the editor's paint path for cover and places | The Europe scenario |
