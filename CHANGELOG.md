# Changelog

Versions follow `0.MINOR.PATCH` until the Steam release (1.0). Each release is a git tag `vX.Y.Z` with a GitHub
release. The save format has its own number (`hexa/campaign/saves.py` `VERSION`); older saves keep loading
unless a release says otherwise.

## v0.1.7: Mountains as natural borders
**Mountains and passes:**
- Ridge crests are natural borders: mountain hexes stay walkable, but land armies, supply, zones of control and roads
  cross a ridge only at a pass. There are 24 named passes plus extra ones wherever a ridge would split a landmass. Passes
  close in winter: a march that meets a closed pass waits for spring, and the hover names the pass (#87)
- The ridges live in the landscape tiles: five crest looks by range, altitude, terrain and climate; mountains draw about
  half as many peaks; in summer a pass is a valley with a track and a hospice, in winter a snow-filled saddle with a
  frozen snowflake mark (from mid zoom in). New option: Pass names (off by default)
- Africa: Maghreb steppe and plains, Sahel savanna and steppe, jungle only in the tropics, on Europe and random worlds (#97)

**Map:**
- No grid lines with the grid off at any zoom (#93, #95); no wave of tiles after a zoom (#94); no trees in the water (#96);
  borders stay in every map mode (#98); town names never overlap
- All 32 goods have their own code-drawn object in the Goods view (Deposits), replacing borrowed Kenney sprites and the
  crate fallback (fish is a basket of fish now, not a box)

**Playtest fixes:**
- Tech prerequisites enforced (#88); a "War on you!" alert (#89); the current research and queue marked (#90); Exit and
  Main menu ask Yes or No (#91); long marches wait for you at the end of a season, R continues them (#92)

**Code review and kioba's tests:**
- Kioba's testing foundation merged (#72-#86): CI on GitHub Actions, window, monkey and golden-screenshot tests, nightly
  soak and perf runs, a save-compatibility check
- Every bug they pinned is fixed: damaged save and settings files, three Colonisation rules, a minimap click, and orders
  round foreign land
- Code review fixes: the tax preview no longer changes the season, "a university", stuck-stack reasons, and
  greyed-out button hints

Old saves keep loading; mountain passes are rebuilt when a save is loaded.

## v0.1.6: Bug-fix round 2
The rest of kioba's v0.1.6 and v0.1.7 milestones, and a seamless map:
- With the hex grid off (G), tiles join with no gaps at any zoom; washes, fog and frost draw no lines between hexes (#71)
- Fog clears at once for hexes revealed partway through a move (#26)
- Changing the tax level previews the income without rerunning the season's economy (#23)
- Random worlds use their own Old World / New World regions instead of Europe's cut-offs (#31)
- An AI march plans its path once and walks without rescanning cargo (#30)
- One saves/options folder lookup (#32); loading builds the map view once; dead code removed (#33, #34)

## v0.1.5: Bug-fix round
**UI and controls** (kioba's milestone):
- Right-clicking to close the pause menu no longer gives the selected stack an order (#16)
- Loading a save slot asks first, as Main menu and Exit already did (#17)
- The top bar lays out from the right edge, so End season never covers Menu; Market and Ledger hide when they don't fit (#18)
- Esc clears the selected stack first; the next Esc opens the pause menu (#19)
- Attacking, founding and foraging cancel the stack's standing move order (#22)
- The panel close button closes the country and market panels (#24)

**Economy:**
- Debt limit of 6 seasons of running costs (at least 300 ducats); interest stops at the limit. Over it, with a deficit,
  unpaid troops desert, then creditors seize buildings, works, castles and settlement levels. An AI in debt raises taxes,
  stops spending and disbands troops. Interim rule until the debt and bankruptcy design (#69).

**Map:**
- Close-zoom panning is smooth and new ground fills in about a second; map overlays build about 6x faster (#67)
- Closed passes are marked in winter at every zoom; town names draw over unit tokens at zoom 13 and out (#70)
- Random worlds get up to 8 mountain passes that close in winter

## v0.1.4: New map look and playtest fixes
**New map look (M3, first part):**
- The two closest zooms draw a blended landscape: wavy edge transitions between every kind of ground, peaks and
  forests that rise over the hex behind, a treeline on the Alps, natural field systems on developed farms and
  forest clearings around towns. The map changes as provinces grow.
- Winter covers the high mountains in snow. **Mountain passes close in winter**: Gotthard, Brenner, Mont Cenis,
  Simplon, Great St Bernard, Roncesvalles, Dukla and Lupkow. Land armies can't enter them until spring (ships
  and armies already standing on one are not stopped); the AI routes around them.
- A faint hex grid, on by default: **G** or the options menu turns it off.
- The Goods view no longer crashes on cattle, copper and the other new goods.

Fixes from the 2026-11-11 playtest:
- Log lines read "upgraded to open fields" and "started an armoury" instead of "now a open fields" / "a armoury"
- Long button labels (Invest, ...) are cut with an ellipsis instead of running over the cost
- Merchant order buttons follow the merchant rules; a loss-making order stays allowed but its hint warns in red
- The game-over banner wraps inside the screen and names your own place and score
- No siege progress on a hex where two sides' troops stand
- A stack that can't move says why (a unit raised this season, already moved, or foraged), in a toast and in the unit panel

## v0.1.3: War and peace rules
Fixes from kioba's war and logistics milestone (all merged PRs, with tests):
- Cannons no longer bombard their own stack when it stands on an enemy castle hex (#63, fixes #12)
- Only the owner can forage a stack, so a player can't freeze an enemy army by foraging it (#62, fixes #13)
- Peace only sends home armies standing in the other party's land, so a siege on another front is kept (#61, fixes #14)
- White peace keeps provinces occupied by a third country in another war (#60, fixes #15)
- Boarding only picks a ship with room for the whole group (#66, fixes #20)
- Cut-off computer armies forage at the end of the season instead of just losing strength (#64, fixes #21)
- Battle reports count the strength lost in that fight, not all missing strength (#65, fixes #28)

## v0.1.2: Tech tree
- **Tech tree** for Age of Discovery: 37 techs in four branches (Military, Trade & Industry, Navigation,
  Statecraft) over three eras, plus a national tech for every country. Press **T** to open it.
- **Research** each season from the base, burghers, universities and coffee houses, plus once-a-year funding
  (60 ducats for 15 points). Techs are cheaper when your market partners already know them. There's a queue: click
  a far tech to queue its path.
- **Era gate:** era II opens from 1520 with 4 era I techs; era III from 1575 with 4 era II techs. At each new era
  you pick 1 of 3 idea cards (one is your nation's).
- **What techs change:**
  - stack size, drill levels, siege, the large castle, supply
  - merchants, taxes and routes
  - new manufactories: ropewalk, powder mill, glassworks, tannery
  - carracks and the new galleon, Atlantic crossings, plantations
  - universities, and more
- **AI** countries choose research by their situation, fund it and pick idea cards.
- Old saves load: their countries get techs that fit their era.
- The start menu shows the game version.

## v0.1.1: Crashes and save/load safety
No failed save, bad save file, bad settings file or bad `--nation` can crash the game or silently lose progress
(#5 to #11). See the GitHub release for details.
