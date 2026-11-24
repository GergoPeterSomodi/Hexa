# Owner's asks from the playtest, 2026-11-23

Bugs and features the owner wrote down while playing the Godot build. Each has an issue; the design questions are named so
planning can settle them before any build. They go through the release planning batch (frozen scope per release); none
starts before it, except the bug in item 4.

| # | Ask | Kind | Issue | Open design question |
|---|---|---|---|---|
| 1 | The log is an icon-only button in the bottom-left corner; clicking it slides the window up from the bottom | feature | #431 | none |
| 2 | A unit's move happens in the month when its destination is picked, not at End turn | feature (rule change) | #432 | how it fits the season rules: movement points, the AI's slice, zones of control, supply, fog, battles started by a move, undo |
| 3 | Units are clickable separately from their tile | feature | #433 | picking among several units on one hex |
| 4 | Movement paths: smooth continuous curve; fix the missing path on the tile the units stand on; three path looks to compare | bug + feature | #434 | which of three looks |
| 5 | Conquest and sight: land taken from me is not fogged for me; conquering gives me sight (the same for every AI) | feature (fog rule) | #435 | edge cases: a lost land still seen, a besieged castle's area |
| 6 | One uniform tile window: name, details (people, goods...), tabs for building, raising an army, raising ships | UI overhaul | #436 | the layout for own, foreign, sea and unseen tiles |
| 7 | Play a battle round by round with orders, not only auto-resolved | feature | #437 | fit to the M7 battle dock and rules (the in-turn battle board is already approved, not built) |
| 8 | Bring the useful unit and battle UIs of the last Python version into the Godot game, restyled to Studiolo | planning | #438 | the audit and the order; planned together with the owner |

Items 6, 7 and 8 belong together (one family: the unit, tile and battle screens) and are planned as one design pass
before any of them is built. Item 2 changes the rules of the season and needs the owner's confirmation of the design.

## Economy rethink (owner, 2026-11-23; issue #439)

- One raw material per tile. Raw material alone can make a country rich, but specific industries, which turn raw material
  into something more valuable, are worth more.
- Industry output improves with the settlement (village, town, city). A building whose raw material is at hand (used in its
  production) works more efficiently.
- Population plays a role: it grows from food surplus and prosperity.

Planning only: a design doc (`docs/design/economy-rethink.md`, revision 2) starts from what M4 to M6 built, says what changes
and what stays, the save and balance consequences and where it sits against M10 (trade) and M11 (research). No build before
the owner approves the revision.

**Owner's answers, 2026-11-23 (they decide the design; Q12 still pending):**

- An industry is a **slot in a settlement** (village 1, town 2, walled town 3, city 4), not its own hex. It needs a settlement
  panel (an Industries tab in the tile window, #436).
- First industries: weaver (wool to cloth), armourer (iron to arms), bakery (grain to bread). Tier yield: village 0.8, town
  1.0, walled town 1.1, city 1.25; no hamlets.
- "Raw at hand" (+25 %) counts only the country's **own** raw districts. One raw per tile: the small second wild yield on goods
  districts is dropped (settlements and ports keep theirs).
- Workshops may also **buy** inputs from the market. M9.5 therefore ships a minimal home market (static price 1.2x base, only for
  the three inputs, one seam `Buying`); M10 replaces it with real markets and moving prices.
- **Bread is food** (1.5 food units a load, grain and fish 1.0). This changes the M4 food pins (list in the design doc, 3.4).
- Growth: `500 + 350 x surplus + 350 x prosperity` permille, ceiling 1200.
- Placement: **M9.5** between M9 (diplomacy) and M10 (trade), the tile window (#436) first. Saves: FORMAT 7, older saves refused.
- **No workshops at the 1480 start.** Before M11, each industry opens in a set year for everyone (placeholder: armourer 1485,
  weaver 1490, bakery 1495; no charter to buy). M11 replaces the year with technology: Guilds (weaver, armourer), Crop rotation
  (bakery).
- **Arms equip armies:** raising a company needs arms (pikemen, crossbowmen, knights 1 each, bombards 2). A country without
  its own arms buys them from the market at a premium (1.5x base); with no arms and no money the raise is refused.
- Market buying: 1.2x base, a per-workshop switch, a treasury floor. Bread 1.5 food a load. Slots by level 1 / 2 / 3 / 4, one
  of each industry; one job per settlement at a time.
- Status: the design is ready for the build plan.

**Still open (design doc, section 14):** N6, the at-hand rule detail (default: own raw, stage 2 or more, flat 25 %; owner to
confirm). New small questions with recommendations: N7 the arms premium and count per company, N8 a raise with no arms and no
money (refuse), N9 arms for refit and upgrade.
