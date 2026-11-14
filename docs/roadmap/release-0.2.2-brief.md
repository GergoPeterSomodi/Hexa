# Release 0.2.2 brief: LOCKED

**LOCKED on 2026-11-13.** The owner took the recommended answer on all four questions and every default. Scope is frozen:
new ideas go to the backlog, bugs are the only exception. The design is `docs/design/sieges-and-retreats.md` section 4.

## Theme

**Sieges.** Places hold out. Taking land becomes a short story with a clock: you besiege or you storm, the defender
relieves the place or lets it fall, and the map shows it. This answers the owner's v0.2.0 note P4 ("castles shouldn't be
captured so quickly ... each turn the siege takes some progress based on attack and defence"). It is also the first new war
*decision* since battles: 0.2.1 made war followable, 0.2.2 makes it a choice, on both sides of the wall:
- **The attacker** chooses each season: keep starving the place (slow, no losses) or storm it now (fast, bloody; cheaper the
  longer the siege has run, dearer if a relief army is coming). The 2-season floor is for sieges: a Storm on arrival can
  still take a place at once, at its cost (Storm is the fast, costly choice; Besiege the slow, cheap one).
- **The defender** chooses: send the relief army and fight for the place, or let it fall and spend the army elsewhere.

Principles it is for (docs/research/fun-principles.md v2): **2** trade-offs (besiege slowly and cheaply, or storm fast and
dear; relieve or let go), **3** the price before the choice (seasons to take, the storm's odds word), **9** remembered moments
(a named siege with a relief battle and a last storm). Also helped: **14** period feel (sieges were the war of the age), **6**
brakes on snowballing (land changes hands more slowly). Checked for harm: **11** (one new choice in the attack list, no new
screen), **12** (the AI must besiege and relieve too, measured below), **1** (wars must still move land, measured below).

## Open bugs

`gh issue list --state open`: none on 2026-11-13. The v0.2.1 playtest reported no bugs.

## Scope

| # | Item | Design | Size | Status |
|---|---|---|---|---|
| 1 | **Siege rules.** Every place holds out at least 2 seasons. A siege meter fills each season from the besieger's men against the garrison, guns and a siege-master general; castles, hills and mountains need more; a garrison starves after its stores run out (1 + castle level seasons). The siege lifts when a relief army wins, the besieger leaves, or peace is made. Besiegers feed off the province, and its output stops while besieged. | 4.1 to 4.3 | M | **In** |
| 2 | **Besiege or Storm.** Moving onto a garrisoned castle offers Besiege (the default) or Storm (the assault battle of today). A storm faces a garrison already cut by the siege's progress, so a late storm is cheaper. "Storm now" stays open every season of a siege, with its odds word: this is the decision the patch is for, so it is not on the cut list. | 4.5 | S to M | **In** |
| 3 | **The odds card reads garrisons properly.** Storm shows a word from the field army plus the garrison counted by its own weight (replaces today's one factor per castle level, which misreads castles). Besiege shows "Falls in about N seasons" (or "Too few men"), and warns when the war will end first ("the war ends in 3 seasons"). | 4.6 | S to M | **In** |
| 4 | **The AI besieges and relieves.** Targets by seasons to take, besieges by default, storms when the siege is about half done, sends relief when it is strong enough, and splits spare stacks onto separate sieges so wars still move land. | 4.8, 4.9 | M | **In** |
| 5 | **On screen.** The siege badge on the map (decision 4), a Siege block in the province panel (progress, rate, hunger, seasons left, and for the defender the relief line "Relief: your army X can reach it in 1 season"), log lines and ribbons with a named siege ("Siege of Lisbon, 1532": started, starving, lifted, fallen), and a task flag line for a place of yours under siege. | 4.7, mockup `docs/design/ui/20_siege_badge.png` | M, art | **In** |
| 6 | Odds words: "Favourable" and "Overwhelming" read almost alike since 0.2.1; move the Overwhelming line so the two differ. | 0.2.1 brief backlog | S | **In**, first to cut |

**Size:** M to L, the top of what one patch holds. The AI (item 4) is the risky part: it must be re-measured, and it may need
the fallback in the defaults (war length 20).

**Cut list, in order:** 6; the grey flash of a lifted siege (the log line and the ribbon stay); the hills and mountains extra
need (keep the castle levels); the AI's split-stack rule (keep it only if the war targets are missed without it). Never cut:
Storm now, the relief line, the AI's relief army (without them the defender has no decision and the patch is only slower
wars).

**Not in 0.2.2:** field forts (design section 6, after sieges are played), the garrison sallying out, sieges from the sea,
the battle board (0.2.3), the trade patch.

**Order of work:** rules, odds card, AI, screen, art, proof (design section 11).

## Defaults (taken unless the owner overrules one)

These follow from the design or from earlier decisions; they need no answer, but the owner may change any of them. The two
marked **look** change how the game feels most; they are the ones worth a minute.

- **Besiegers forage the province for free** (otherwise every siege starves the besieger first), and a besieged province
  produces nothing. **(look)**
- **Too few men is no siege at all:** a besieger with fewer men than the garrison starts no meter and no hunger, and the
  province keeps its output. (Otherwise one regiment parked at a big castle would shut its economy down for free.)
- **Hunger:** a place holds out 1 + castle level seasons on its stores, then the meter gains 2 points a season.
- **Crowding:** at the garrison's size the siege moves slowly; at 4 times the garrison it moves fastest.
- **One regiment alone** cannot take a level 2 or 3 castle.
- **Storm cut:** a full siege meter halves the garrison a storm faces; half a meter cuts it by a quarter.
- **A lifted siege starts from zero** next time (progress, hunger and seasons). This is what makes a relief army worth
  sending. **(look)**
- **Peace ends every siege**, progress lost. Player wars still end after 32 seasons, AI wars after 16.
- **A stack that retreated this turn** cannot besiege where it lands (as in 0.2.1).
- **AI wars stay at about 16 seasons** (`WAR_LENGTH_AI`); the AI's targets change instead (measured: a longer limit does not
  move more land). If the targets below are missed with the new AI, it goes to 20, not more.
- **Sieges are named** in the log like battles ("Siege of Lisbon, 1532", "Second Siege of Lisbon").
- **Old saves:** load and play on; a place that was nearly taken under the old rule may need a season or two more.

## Done when

- No open bug issue; the full suite, soak, save-compat and perf pass; AI time per season up by at most 10%.
- **Pace:** every cell of the seasons-to-take table within 1 season in the engine; no place falls to a siege in under 2 seasons in any
  test or soak game (a Storm on arrival can take a place at once, at its cost); 1 regiment cannot take a castle 2 or 3.
- **Odds card:** each garrison test pair reads its word's band (one band low at most, never too high); a lone level 3
  garrison against 1.7 to 3.3 times its men no longer reads "Hopeless".
- **A late storm is cheaper:** in seeded storm scenarios (40 seeds), storming at half the meter loses fewer men (median)
  than storming on arrival, and its odds word is the same or better.
- **AI wars** (seeded all-AI, 4 worlds, 240 seasons): at least 17 provinces change hands per decade per world (today 23.6),
  at most 20% of wars move no province, at most 35% end by the length limit (today 22%; 50% before the AI change).
- **The AI uses the new decision:** at least half of the AI's captures of castles 2 and 3 follow 2 or more seasons of siege
  (not a storm on arrival), and at least 1 in 5 AI sieges of castles 2 and 3 meets a relief battle (starting numbers).
- **Snowballing:** the largest country's land share by 1600 is not higher than today.
- **Owner playtest:** besiege a level 2 or 3 castle and follow its seasons, its hunger and a relief battle on the badge and
  in the log without help; storm a place late in a siege and see it cost less; as the defender, see the task flag line and
  the relief line, and choose to relieve or let go.

## Measured in the build (2026-11-14)

All-AI, Europe 1480 and random worlds 7, 11 and 21, 240 seasons each, pooled:
- Provinces changing hands: at least 17 per decade in every world (met). Wars moving no province: 12% (met). Wars ended by
  the length limit: 29% (met pooled; one world 40%). AI castle 2/3 captures after 2+ seasons of siege: 61% (met; was 1 in 21
  before the AI fix). AI time per season unchanged (met).
- **Accepted misses:** relief battles at AI castle 2/3 sieges 10% (target 20%): with the 2-season floor a defender has about
  one season to arrive and is often further away; a gather rule is built and works when it can. The largest country's land
  share at 1600 is 14.9% against 14.7% (one seed, within noise; 15.3% before the AI fix). Backlog: a longer relief reach or
  a defender's stack inside its own castle, after the owner has played sieges.
- `WAR_LENGTH_AI` stays 16: 20 was measured and was worse on every missed item.

## Owner's decisions (2026-11-13)

1. **How a siege works:** the siege meter (men, cannons, a siege general and hunger against the castle, the ground and the
   garrison).
2. **Pace:** as designed. 3 regiments with no cannons take 2 / 3 / 4 / 7 turns (no castle / castle 1 / 2 / 3); with 2 culverins
   2 / 2 / 2 / 3.
3. **A castle with soldiers inside:** Besiege by default, Storm as the second choice, open every turn.
4. **Siege badge:** B, the dial in the ring.
5. **Defaults:** all taken as listed.

## Creative review (2026-11-13)

**Verdict: approve with changes (made above).** The theme is right and it is the first new war decision since 0.2.0: Besiege or
Storm is a real trade-off every season of a siege (principle 2), its price is on the card (3), and a named siege with a relief
battle is the kind of story principle 9 asks for. It is one patch, at the top of the size range. The draft carried the
attacker's half of the decision well and the defender's half barely; that, and a war-length target that was already met before
the AI change, were the main fixes.

Changes made:
- **"Storm now" taken off the cut list.** Without it a storm happens only on arrival, the siege's progress never cuts the
  garrison, the "late storm is cheaper" playtest line cannot happen, and Besiege versus Storm becomes a one-time pick: a
  set-and-forget siege. It is the per-season decision.
- **The defender's decision added to scope:** the relief line in the province panel (the design had it, the brief did not),
  and the AI's relief made un-cuttable. Without it the defender watches a meter fill.
- **"Too few men is no siege"** made a default: under the crowd rule, a lone regiment at a big castle would stop its output
  with no hope of taking it (a cheap grief and a stalemate maker).
- **The war clock shown:** the Besiege entry warns when the war will end before the place falls (player wars end at 32
  seasons; peace wipes the meter). Otherwise a player can spend 7 seasons for nothing without being told (principle 3).
- **Done when tightened.** "At most 50% of wars end by the length limit" was already met in the scratch run where the AI does
  not besiege at all (4.9: exactly 50%, against 22% today); it is now 35%. The 4.9 run is also optimistic: its sieges were 2
  seasons because the AI still stormed castles. Once the AI besieges castles for 4 to 7 seasons, wars slow further, so the
  stalemate risk (wars that move no land, principle 1) is bigger than the table shows. Added: an AI-behaviour target (it must
  besiege and relieve, principle 12) and a measured "late storm is cheaper" check.
- **Sieges are named** like battles (principles 9, 14): the mockup already says "Siege of Brescia"; the log follows.
- **Cut list made real:** the lift flash and the terrain extra need are cheap to drop; the decision's two halves are not.
- **Questions reworded** for the owner: what a season, a regiment, the odds card, Besiege and Storm mean, in place; question 2
  sets the pace against the 16-turn AI war.

On "is four enough": yes. The four are the only choices that change what the patch *is* (the model, the pace, the choice
itself, the look). The rest are consequences or tuning, all listed as defaults; two are marked **look** because they shape how
a siege feels (free foraging, a lifted siege resets). None is a hidden question, and no default needs an answer to start.

Sensitive topics: none touched. Wars and sieges here are between countries with castles; the tribal nations are not at war
in the game today. If a later design lets armies besiege tribal or colonial settlements, the hunger lines ("the garrison is
starving") need their own review under principle 16.

Risks to watch in the playtest: turtling behind level 3 castles (the design's answer: raise hunger before the rate); a big
army with culverins taking everything in 2 to 3 seasons (the snowball target covers the AI; watch it in the player's hands);
and whether a player can follow two or three sieges at once from the badges and the task flag alone.
