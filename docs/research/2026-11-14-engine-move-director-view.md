# Moving Hexa to another engine: the director's view

Date: 2026-11-14. Author: creative director. A paper study for the owner, who asked: "How could this be translated to
Godot? Is GDScript better? What is the best language to write this in?" No code was changed and nothing is approved.

This doc covers the player, the business, the timing and the studio process. The code and language side is the
technical director's study, `docs/architecture/2026-11-14-engine-and-language.md`, written at the same time. Where the
two disagree on cost, trust the technical director's numbers.

## The answer in short

**Not now. Stay in Python and pygame while the team makes war fun. Decide again at one fixed gate, before the 0.9.x
Early Access line, with a short measured Godot test in hand. If Hexa moves, Godot is the right target, the move happens
before Early Access, and it runs as its own phase, not alongside fun work.**

The reason: the game's biggest problem today is fun, not the engine. The owner's verdict on v0.2.0 was that the game
"wasn't really engaging", and the 0.2.x war line exists to fix that. No engine fixes thin decisions. An engine move now
would stop that work for weeks and give the owner releases that look better but play the same.

## 1. What a move would buy, and what it would cost

### What the player would get

| Area | In pygame today | In Godot | Matters for Hexa? |
|---|---|---|---|
| Smooth map | Drawn on the CPU. 14,000 provinces is a known speed risk (long-term roadmap, risks). | Drawn on the graphics card: smooth zoom and pan, big maps, high resolutions. | **High.** The map is the game. |
| UI | pygame-gui plus our own widgets; six button versions (architecture review). | A full UI toolkit with themes, layout, scaling and good text. | **High.** UI is a top complaint in every comparable game (principle 11). |
| Animation and "juice" | Hand-made each time. | Built-in tweens, particles and shaders. | **Medium.** Helps battles, sieges, the store trailer. |
| Sound and music | pygame.mixer can do what the roadmap asks. | Better mixing and buses, but not needed. | **Low.** Not a reason to move. |
| Screen sizes, 4K, high-DPI | Fixed window sizes today. | Built-in scaling. | **Medium.** Steam players expect it. |
| Steam Deck | A Windows build will most likely run through Proton (not tested). Controller and small-screen text need work in any engine. | Native Linux build; controller input is easier. | **Medium.** Deck players buy strategy games, but Deck support is UI work in any engine. |
| Consoles | Not realistic. | Possible through paid porting partners. | **Low.** Grand strategy sells on PC. |
| Web demo | Possible (pygbag), rough. | Built-in web export. | **Low.** A Steam demo matters more. |
| Modding | Python is very moddable (Civilization IV used Python for its rules and mods). | Possible, but harder for players to open up. | **Medium.** Mods come mostly from data files, which work in any engine. |

### What the business would get

- **Store page and trailer.** Steam does not care which engine is used. Players judge the trailer, the screenshots and
  the first ten minutes. Godot makes motion and polish cheaper, which shows in a trailer. The flat Kenney look is
  forgiving, so pygame can still look good in screenshots.
- **Packaging.** Python games are packed into an .exe with a bundler; such builds are sometimes flagged by antivirus
  tools (a common report, not measured for Hexa). Godot exports clean builds for Windows, Linux and macOS.
- **Collaborators.** Godot has a large, growing indie community and is free, open source and royalty-free. Python is
  known by even more people, but few game developers expect to ship a commercial game in pygame. Outside contributors,
  such as our GitHub collaborator, would likely find Godot more familiar as a games project; this is a guess.
- **Kenney fit.** Kenney himself makes Godot starter kits and tools, so the look and the engine sit well together.

### What it would cost

- **Weeks with nothing new to play.** About 44,000 lines of game code and 26,000 lines of tests. The rules are already
  free of pygame (architecture review), which helps a lot. But every screen, panel and piece of code-drawn art must be
  rebuilt. My rough guess is one to three months of the whole team before the Godot version plays like today's,
  plus a tail of small differences. The technical director's estimate overrules mine.
- **Fun work stops.** The war line (sieges, castles map mode, the battle board, war goals and peace) would wait.
  Porting while the rules keep changing means building every feature twice.
- **Losing what works.** The safety net (the unit and window tests, the behaviour oracle, soak, save checks, golden screenshots)
  is why releases are safe. It must be rebuilt in the new engine before the port can be trusted. Old saves would need
  a converter or a clean break, which is easiest before any player has a save.
- **The studio itself changes.** The team is AI agents. They know Python very well. They know GDScript less well,
  and Godot 3 and Godot 4 code are often mixed up. Godot work also lives partly in its visual editor, which agents
  cannot see. Workers, briefs, screenshot checks and reviews would all need a new routine. This is the cost I would
  most want the test (section 3) to measure.

### What comparable games chose (from memory; marked where unsure)

- **Grand strategy leaders** (Europa Universalis, Crusader Kings) use their own studio engines. Not an option for us.
- **Unity** carries most indie and mid-size strategy: Old World, Humankind, Endless Legend, RimWorld, BattleTech.
- **Godot** is rising fast: Brotato, Dome Keeper, Cassette Beasts. Slay the Spire 2 moved to Godot after Unity's 2023
  pricing scare. I know of few large grand strategy games in Godot yet.
- **Small frameworks can ship hits:** Balatro was made in LOVE (Lua), Stardew Valley in XNA. The tool did not hold them back.
- **Port after proof is a known path:** Vampire Survivors started in a web framework and was moved to Unity after it
  succeeded, to reach consoles and run faster. That is the pattern I recommend: prove the fun first, then move.
- **Python on Steam** is rare but real: Ren'Py visual novels (Doki Doki Literature Club), Python scripting in
  Civilization IV and EVE Online. I know of no big pygame strategy hit; treat that as a risk sign, not a rule.

## 2. When

| Option | For | Against | Verdict |
|---|---|---|---|
| **Now** | Less code to port; no players yet. | Stops the war fun fix at its most important moment; the rules still change every release. | No. |
| **Before Early Access (at a gate)** | Players and reviewers meet the final engine; no saves to break; the trailer and store page show the better look. | A dedicated phase with no new content. | **Recommended, if the move is wanted.** |
| **Between Early Access and 1.0** | Some money and player feedback first. | Early Access players expect steady updates; a port pauses them and risks their saves and the reviews. | Only if the test shows pygame is fine for EA. |
| **After 1.0** | Nothing ships late. | A port after launch rarely pays back for a premium PC strategy game. | Only for consoles, which we do not plan. |
| **Never** | Zero port cost. | The UI and map smoothness ceiling stays; the Steam polish bar is harder to meet. | A real option if the test fails. |

**Trigger conditions for the gate.** Decide at the gate only when all of these hold:
1. **The fun is proven.** The owner plays a release and calls war engaging, and the economy and trade fun tests pass
   their key lines (principles 1, 5 and 12).
2. **The core loop is stable.** The war line and the first living-world systems are in, so the rules stop changing
   every release.
3. **The art direction is locked**, so art is rebuilt once, not twice.
4. **A reason is measured, not felt.** At least one of: the map cannot reach the agreed frame rate on the low-end target
   PC; the UI polish the store page needs is too costly in pygame-gui; Steam Deck or packaging problems that pygame
   cannot fix.
5. **The Godot test passed** (section 3).

If 4 is not met, stay. A move without a measured reason is a cost with no proof of gain.

## 3. How it fits the studio process

**One release at a time still holds. A port cannot run as a quiet parallel track** next to the war line: the rules
change every patch, so the port would chase a moving target and double every feature. Two things can run in parallel:

- **Prep that helps either way (now, inside normal work).** Finish the approved architecture refactor. Much of it has
  landed (the event bus, the game manager, the systems modules, the UI kit, screens, shared drawing code and render
  caches); what is left should be finished. Clean seams make Hexa better in pygame and cheaper to move later: the
  pygame-free rules, the season table and the read-only views (such as the battle view) are exactly the parts a new
  engine's front end would sit on. Also: a tool that bakes the code-drawn art into image sheets. Useful for the store page, mockups and any engine.
- **A short Godot test (later, as a side track on a branch, paper-planned like the next release).** Two weeks at most,
  done after the fun gate. It builds one slice: the Europe map with zoom and pan, the province hover card, and the
  battle panel, reading a real save. It is measured: frame rate on the low-end target, how many worker tasks pass review
  first time compared with Python, and how long one panel takes. The owner plays it for ten minutes.

**If the owner then says go, the port is its own phase** with its own MINOR number (for example "0.8.x New engine",
before 0.9.x Early Access). It keeps the studio rhythm:
- a frozen brief, like any release: parity first, no new features;
- small parity releases the owner plays, each checked against a list: same seed, same map, same battle result, and old
  saves either load or are clearly retired;
- the first Godot release the owner plays should be the map and one full season, so there is something real to try
  within the first weeks, not a long silence;
- bugs found in the Python version are still fixed there until the Godot version takes over.

**What the owner would see:** first the test slice; then parity releases that look and feel smoother but play the same
game; then a switch-over release; then the content line resumes. During the phase the fun work pauses. That is the price,
and the owner should agree to it knowingly.

## 4. Godot, Python, or something else (director level)

- **Stay in Python and pygame.** Cheapest and safest now. The whole studio routine works. The ceiling is the map's
  smoothness and the UI's polish. Good enough to find the fun; maybe not good enough for the Steam store at its best.
- **A Python engine with graphics-card drawing** (for example Arcade or pyglet). A smaller step: same language, same
  agents, faster map. Smaller communities and fewer tools than Godot. Worth a line in the technical director's study as
  the "middle road".
- **Godot (recommended target if Hexa moves).** Free, open source, no royalties, light editor, text-based scene files
  that agents can read, a good UI toolkit, clean exports, a Kenney-friendly community. **GDScript reads much like
  Python** (indentation, similar words), so the owner can still read the code and the diffs. C# in Godot is also
  possible but wordier; which language, and whether the rules could stay in Python behind a Godot front end, is the
  technical director's call.
- **Unity.** Proven for strategy games, but heavier, and its 2023 pricing scare cost it trust among indies. Its scene
  files are harder for agents to work with. No reason to prefer it over Godot for a 2D hex game.
- **Others** (LOVE, MonoGame, Bevy): possible, but each trades Python's familiarity for a smaller toolset than Godot.
  Not worth a study.

**What matters to the owner:** the language matters less than three things: can the AI team build in it reliably, can
the owner still read it, and does it lift the map and the UI to Steam quality. Godot with GDScript is the best bet on
all three, if the test confirms the first.

## 5. Decisions for the owner

1. **When to decide on the engine.**
   - **(Recommended) Not now.** Stay in Python through the war line. Decide at one gate before the 0.9.x Early Access
     line, when the trigger conditions in section 2 hold.
   - Decide now and port now.
   - Never: Python and pygame to 1.0.
2. **The Godot test.**
   - **(Recommended) Yes, but later:** a two-week test slice on a branch after the fun gate, measured against the pass
     bar in section 3, planned on paper alongside a normal release.
   - Yes, now, alongside the war line (it takes a planner's attention away from fun).
   - No test; decide on paper.
3. **Prep that pays either way.**
   - **(Recommended) Yes:** finish the approved architecture refactor in its planned phases, and add an art-baking tool
     when the art is next touched. No engine work.
   - Only the refactor.
   - Neither.

## Risks and unknowns

- Every cost figure here is a guess. The technical director's study and the test slice should replace them.
- Claims about other games' engines are from memory; the market researcher can check them before any are quoted.
- Steam Deck and antivirus points for the current build are untested. A one-day check would settle both.
- The biggest unknown is how well the AI team works in GDScript. Only the test answers that.
