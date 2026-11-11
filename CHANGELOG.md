# Changelog

Versions follow `0.MINOR.PATCH` until the Steam release (1.0). Each release is a git tag `vX.Y.Z` with a GitHub
release. The save format has its own number (`hexa/campaign/saves.py` `VERSION`); older saves keep loading
unless a release says otherwise.

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
