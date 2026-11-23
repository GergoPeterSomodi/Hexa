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

Planning only: a design doc (`docs/design/economy-rethink.md`) starts from what M4 to M6 built, says what changes and what
stays, the save and balance consequences and where it sits against M10 (trade) and M11 (research), with questions for the
owner. No build before the owner approves it.
