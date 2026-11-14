# Release 0.3.0 brief: LOCKED

**LOCKED on 2026-11-14.** The owner answered both questions (below) and gave the go to install Godot. Scope is
frozen: new ideas go to the backlog, bugs are the only exception. The plan behind it is `docs/roadmap/godot-port-plan.md`.

Built on the owner's answers of 2026-11-14: the game moves to Godot; only Age of Discovery on the Europe map; Windows
only; GDScript; the Europe map is **rebuilt in Godot**; the screens stay today's; and *"Build the map first and we can
start designing the game elements."*

## Theme

**The map.** Europe 1480 on screen in the new engine, made by a map builder that lives in Godot. Nothing else: no
season, no armies, no panels.

Fun principles (docs/research/fun-principles.md): none is served directly. This release is the first cost of the engine
decision. It is judged on two questions only: is this the Europe you know, and does the map look and move at least as
well as today's.

## What the owner can play

- Start `Hexa.exe` from the Windows zip. Europe 1480 appears, with the coast of Africa and the Americas as today.
- Pan with the mouse or the keys, zoom smoothly from the whole map down to one town.
- Switch between the terrain view and the countries view.
- See rivers, roads, ridges and passes, towns, castles, and the names of countries, towns and provinces. The province
  under the mouse shows its name, country and terrain.
- That is all. There is no "End season" yet.

## Open bugs

Open bug issues of the Python game stay open and are fixed in Godot, in the release that builds the part they are about.
The producer checks the list when this brief is locked; an open bug about the map itself (a wrong name, a town in the
sea, a broken coast) belongs to this release.

## The first step: Godot on the build machine

Godot is not installed on the build machine today. Before any other work:

- Install **Godot 4.7.2-stable** for Windows, the standard build (not the .NET one), from the official download page of
  godotengine.org. On 2026-11-14 it is the latest stable 4.x there and on the engine's GitHub releases (released 18
  August 2026). If a newer 4.x stable is out on the day, take that one and change the number here and in CI.
- Check the download against the checksum file published with the release. Unzip it outside the repository; the tools
  find it through an environment variable (`GODOT`), never through a path written in the repo.
- The same version is pinned in CI. No upgrade inside a release.
- The test tool GUT is copied into `godot/addons/gut/` at the release that matches this Godot version, and pinned.
- The owner installs nothing: the Windows zip holds the whole game.

## Scope

| # | Item | Size | Proof |
|---|---|---|---|
| 1 | **Godot project and CI.** The pinned engine; the `godot/` layout; the lint script (layers, no engine calls in `core/`, no Godot 3 spellings, luck only through `rng.gd`); GUT; the GitHub Actions workflow below. | M | CI green on a pull request; a tagged build starts on Windows |
| 2 | **Data files, exported once from Python.** `tools/export_data.py` (the game's numbers; the builder reads terrain, towns, castles, goods and troop tables) and `tools/export_geography.py` (the projection, the land outlines as longitude and latitude points, lakes, deserts, steppes, marshes, 35 rivers, 18 mountain ranges, 24 passes, 102 cities, 49 countries, 56 tribes, 684 regions, the place names with their GeoNames credit). The Godot loaders with their schema. | M | Python: the files read back equal to the modules' tables. GUT: every file loads; the counts are right |
| 3 | **The map builder in Godot** (`godot/core/mapgen/`, with `hexgrid.gd`, `rng.gd`, `geo.gd` and the Province, Country and Unit state classes). Ported step by step from the Python builder: land and sea from the outlines (Mercator), rivers, ridges and passes, terrain (priors and the wave function collapse), provinces and names, countries, population, goods, towns, castles, roads, starting units. Random worlds are not built. | L to XL, about 3 weeks | The builder's tests, rewritten from the Python map tests; a hand-made small geography checked by hand; the map check of item 4 |
| 4 | **The map check and the map file.** `tools/export_map_reference.py` (the Python Europe at 8 seeds: the facts no seed changes, and the range of every count that luck moves); `godot/tools/map_report.gd` (the same table for Godot's Europe); `godot/tools/build_map.gd` (writes the map file); the contact-sheet tool. | M | The table of "The new Europe is checked" below; CI rebuilds the map file and gets the committed one |
| 5 | **The art baker and the art inventory.** `tools/bake_art.py` at hex radius 60; the inventory document (baked as it is / baked as pieces / redone in Godot). For 0.3.0: terrain tiles, river, road and coast pieces, towns, castles, landmarks. | L | The Python sprite hashes unchanged; the art director signs the art contact sheets |
| 6 | **The map view.** Tile layers (ground; rivers, roads, coasts; ridges and passes as plain marks; towns and castles; borders; labels), the far-zoom countries texture, the camera (pan, smooth zoom), the terrain and countries views, the province under the mouse. | L | The `hexgrid` table test against Python; goldens; frame time on the low-end PC |
| 7 | **Speed probe.** The builder's road search and territory flood in GDScript, against Godot's built-in path finder and against Python; the builder's total time. | S | The ratio table in the release notes |
| 8 | **Freeze paperwork.** The document edits listed in the plan (B14): roadmap, CHANGELOG header, CLAUDE.md port rules; the CI guard that no file under `hexa/` changes. | S | In the release |

**Size:** XL, 6 to 8 engineer-weeks, the largest release of the port. The map builder (item 3) is the big part and the
risky one.

**Order of work.** Item 1 first. Then item 2. Then three tracks that share no files: the builder (3, in `core/`), the
map view (6, in `shell/`, started on flat colours as soon as land and countries exist), the art (5, Python tools). Then
the check and the map file (4), the review of the new Europe, the speed probe (7), the paperwork (8).

**Internal builds on the way** (shown to the owner if wanted, not releases): an empty window from CI; the coast and the
countries in flat colours; the full map with art.

**Cut list, in order:** the landmarks; the Python column of the speed probe; the smooth-zoom snap points; the starting
units (they move to 0.3.2, which first shows them); the provinces' contents: population, goods, buildings, garrisons
(they move to 0.3.1, which first uses them, with their rows of the map check).

**Never cut:** land and sea, rivers, ridges and passes, terrain, province names, countries, towns and castles, roads;
the map check and the contact sheet; the two views; CI and the Windows build. Without them it is not "the map".

**Not in 0.3.0:** any rule or season; markets and start techs (they are trade and research, 0.3.1); units drawn on the
map; fog; panels, the top bar, menus, settings; saves; the reference report of behaviour bands (0.3.1); ground blends,
drawn ridge crests and the close-up landscape (0.3.1 and 0.3.5, see decision 2); random worlds; any change under
`hexa/`; any web or phone build; any redesign.

**Meanwhile, on paper.** While 0.3.0 is built, the design team designs the game elements of the next releases (0.3.1
onwards), as the studio process allows. None of it changes this scope.

## GitHub Actions

One new workflow, `.github/workflows/godot.yml`. The Python workflows stay and run only when `hexa/`, `tests/` or the
Python `tools/` change.

- **Setup, shared by all jobs:** download the pinned Godot Linux build and its export templates from the official
  release, check both against the published checksum file, cache them by version.
- **On every pull request that touches `godot/` or the exporters:**
  1. *Lint and load:* the lint script; import the project headless; fail on any script warning or error.
  2. *Tests:* GUT, headless, with a JUnit report in the job summary.
  3. *Map:* run `build_map.gd` headless, compare the result with the committed map file, run the map check against
     `europe_reference.json`, print the map report in the job summary.
  4. *Goldens:* screenshots of fixed map scenes under a virtual display with software rendering (true headless mode
     draws nothing), compared with a pixel tolerance. Made on Linux only, as today.
- **On a tag `v0.3.*`:** export the Windows build headless (the "Windows Desktop" preset, release, 64-bit, the game
  data packed into the exe), zip it with the licence and credits file, upload it as the workflow's artifact. Then a
  smoke start on a Windows runner: the exe starts, loads the map file, checks the counts and exits with 0.
- The planning session attaches the zip to the GitHub release, as today. CI writes nothing to the repository.
- Not in 0.3.0: the nightly soak, perf and bands jobs (there is no game to soak yet); an exe icon and version stamp
  (they need an extra tool; 0.3.5).

## Defaults (taken unless the owner overrules one)

- **Engine:** Godot 4.7.2-stable, the Compatibility renderer (old PCs; the only one a browser could use later), GDScript.
- **The whole map of today is built:** Europe, North Africa, the Near East, and the coasts of Africa and the Americas.
  "Europe only" means no random worlds, not a smaller map.
- **The map file ships; the builder does not run when the game starts.** The builder makes Europe from a fixed seed,
  the result is reviewed and committed as one file, and every game loads it (decision 1).
- **Picking the Europe:** the builder is run for a handful of seeds. Those that pass the counts go on one contact
  sheet. The art director proposes one and shows two others; the owner signs it or picks another. **(look)**
- **Same Europe, not the same hexes:** coasts, cities, rivers, passes and the big castles sit on the same hexes as in
  Python. Forests, hills, small towns, towers and roads may fall differently. **(look)**
- **The art is still drawn by the Python art code** and baked into image files once. Only the map is built in Godot.
- **Everything is visible:** no fog and no "unknown world" yet.
- **Controls:** drag or the arrow keys and WASD to pan, the wheel to zoom, one key and one button to switch the view,
  Esc to quit. Where today's game has a key for the same thing, the same key.
- **The window** can be resized; it starts at 1280 x 720 or larger. The version is in the title.
- **Place names** carry the GeoNames credit (CC BY 4.0) in the credits file of the zip.
- **Bugs found in the Python builder** while porting are fixed in Godot and noted in the changelog, not copied.

## The new Europe is checked

Against the Python map at v0.2.2 (measured: seed 1480, and the range over seeds 1480 and 1 to 7).

**Must be equal** (no seed changes them in Python either):
- the grid, 203 x 150; land, ocean and lake per hex (14,411 / 15,956 / 83); 1,459 coastal provinces;
- 102 cities on the same hexes with the same names; 35 rivers on the same 680 hexes;
- 441 ridge edges, 47 pass edges, 72 passes with the same names;
- 49 countries with the same capitals; castles of level 2 and 3 (42 and 7) on the same hexes; 73 and 33 towns of size
  2 and 3.

A per-hex difference in the land is listed and explained (a hex centre lying on an outline); more than 5 is a bug.

**Must be close** (luck moves them in Python too):

| What | Python: seed 1480 (range) | Rule |
|---|---|---|
| Terrain mix | plains 2,228 (2,197 to 2,292), forest 1,971 (1,830 to 1,971), hills 883 (852 to 920), mountains 749 (749 to 787), marsh 287 (234 to 287), and the other eight kinds as in the plan (B5) | Each kind inside the Python range widened by 10 percent of its median, at least 25 hexes |
| Provinces per country | 4,311 owned in all (4,292 to 4,315); largest spread Tunis, 140 to 158 | Each country inside its range widened by 5 percent, at least 3; the owner of at least 99 percent of the land hexes as in Python |
| Towers | 18 (11 to 21) | 9 to 24 |
| Small towns | 432 (392 to 447) | Inside the range widened by 10 percent |
| Roads | 623 hexes (595 to 630) | Inside the range widened by 10 percent; every pair of cities joined in Python is joined |
| Population | 31,721 (31,046 to 32,047) | Within 5 percent in all, 15 percent per country |
| Goods | 25 goods; 1,963 provinces with none (1,963 to 2,016) | Each good within 15 percent of the Python median, at least 10 provinces; every good present |
| Starting units | 133: 83 pikemen, 28 knights, 10 bombards, 7 generals, 5 caravels | The same kinds per country, each standing inside its country |
| Names | 14,411, all different | All different, none empty |

Terrain is not compared hex by hex: two Python seeds agree on only 62 percent of the land, so it would prove nothing.

**By eye.** A contact sheet of twelve regions (Iberia, France, the British Isles, the Low Countries and the Rhine, the
Alps and northern Italy, southern Italy, the Balkans, Anatolia, Poland and Lithuania, Scandinavia, the Maghreb, the
Caribbean coast), Python beside Godot, in the terrain view and the countries view, plus the whole map in both. The art
director reviews it first; then the owner. The map file is frozen only after the owner signs.

## Done when

- Godot 4.7.2 (or the newer stable taken on the day) is pinned on the build machine and in CI; the workflow is green; a
  tag produces the Windows zip and its smoke start passes.
- The data files and the geography files are in the repo with their proof tests green, and the GeoNames credit is in
  the zip.
- The builder's tests pass, the lint passes, and `core/` uses no Node and no luck outside `rng.gd`. Building twice
  from the same seed gives the same file.
- The new Europe passes every "equal" line and every "close" rule above, or the miss is explained and accepted by the
  systems designer and listed in the release notes.
- The contact sheet is signed by the art director and by the owner; the signed map file is committed.
- The Windows build shows the map at 60 frames a second while panning and zooming, on the owner's PC and on the
  low-end PC; no seams, gaps or flicker at any zoom.
- The art inventory exists and says how each group of today's art comes to Godot.
- The speed table says "go", or names the fallback that 0.3.2 must plan in.
- The Python tests still pass and no file under `hexa/` has changed since v0.2.2.
- The owner has played the checklist below.

## Risks

1. **The builder is ported wrongly in a way the counts do not show.** Guards: the per-hex equal lines, the builder's own
   tests, the small hand-made geography, the contact sheet.
2. **The owner does not like the new Europe.** Guards: several seeds on the sheet; the art director's review first; the
   file is frozen only after the signature. One or two rounds are planned in the size.
3. **The release runs long.** It is the largest of the port. Guard: the cut list moves province contents and starting
   units to the releases that first use them; the never-cut list keeps the map whole.
4. **The map looks plainer up close than today's** (no ground blends, ridge crests or close-up landscape yet), and is
   judged as worse for it. Guard: decision 2; the release notes say what is still to come.
5. **The team is new to Godot,** and the agents cannot see its editor. Guards: the lint, the project load with warnings
   as errors, small text scenes, a screenshot test per scene.
6. **Today's tile art does not layer cleanly in Godot** (seams, edge pieces). Guard: the art inventory; the fallback of
   drawing the map in chunks behind the same map-view interface (plan, B8).
7. **The map file differs between machines** in the last digit of the maths. Guard: the file made in CI is the one that
   ships; other machines check counts, not the file's hash.

**The last cheap exit is after this release.** Until then the Python game is untouched and complete.

## Playtest checklist (Windows zip, about fifteen minutes)

Unzip the release anywhere and start `Hexa.exe`. Windows may warn about an unknown publisher the first time, as with
earlier builds. Keep Python 0.2.2 open beside it.

1. Does the build start, and does the whole map appear within a few seconds?
2. Pan across Europe and zoom from the whole map down to one town. Is it smooth? Any seams, gaps or flicker?
3. Is it the Europe you know? Look at the coasts of Iberia, Italy, the British Isles and the Baltic.
4. Switch between the terrain view and the countries view. Are the borders and colours right? Find Portugal, Castile,
   France, Venice and the Ottomans.
5. Hover Lisbon, Paris, Venice and Constantinople. Are the names right? Hover three places in the countryside: do the
   province names read well?
6. Find three castles, three rivers and two Alpine passes you know. Are they where they should be?
7. Look at the terrain of a region you have played (for example Castile and Granada). It will differ from Python's. Is
   it as believable?
8. Resize the window and play at your usual size. Does anything break?
9. Read the map report (one page) and the speed table in the release notes. Anything surprising?

## Scope change (2026-11-14, owner): the map is built in the new look

After seeing the close-up mockup (`docs/design/godot-look/07_closeup_view.png`, `07b_closeup_compare.png`), the owner
asked "why don't you build this close up instead of the previous version?" 0.3.0's map is now drawn in direction A
instead of the baked v0.2.2 tiles: ground that blends between hexes, three mountain types (snowy peaks, rocky ranges,
rolling hills, the ranges kept light so pieces stand out), drawn ridge crests and passes, forests and fields spread across
hexes, towns and tile upgrades by level, at every zoom from the far map to the close-up. The map data stays as built
(checked against Python), except that **the Po valley around Milan and Turin becomes plains and farmland** (the data
marked it as mountains). Defaults taken for the owner (overrule any): the Po fix, the lighter ranges, the strength badge
right of the army token. About 3 to 5 weeks more for 0.3.0. The baked v0.2.2 tiles stay as the fallback until the new art
covers every terrain kind.

## Owner's decisions (2026-11-14)

1. **One Europe for every game:** Godot builds Europe once from a fixed seed; the owner approves it; every game starts on it.
2. **Basic map look now, polish later:** tiles, rivers, roads, towns, castles and names in 0.3.0; ground blends, drawn ridge
   crests and the close-up landscape later.
3. **Godot:** the owner approved downloading the official Godot 4 stable for Windows (64-bit zip) onto the build machine.
4. **The game elements are redesigned for Godot** (owner, same day, asked what "start designing the game elements" meant):
   while 0.3.0 is built, the design team redesigns units, towns, castles, panels and the HUD for the Godot version, with
   mockups first for the owner. This replaces "today's screens as they are" for the later releases; the port plan's
   0.3.4-0.3.5 are re-planned once those designs are approved. 0.3.0's map look is unaffected.
