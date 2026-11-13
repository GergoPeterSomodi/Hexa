# How Hexa is made: the studio

Hexa is built by the owner with a team of AI agents in Claude Code. It is a lean version of the "Claude Code Game Studios" idea: specialised roles, review gates, and the owner deciding. The main planning session plans the work, briefs the agents, reviews their results and commits.

## The team

| Role | Model | What it does |
|---|---|---|
| Creative director | Opus | Reviews every design against the vision and the fun before the owner sees it, using the fun principles |
| Technical director | Opus | Reviews architecture and big changes, and leads the architecture refactor |
| Producer | Sonnet | Keeps the roadmap, milestones, issue triage, the changelog and release notes |
| Game designer | Sonnet | Writes design docs for new systems: diplomacy, rebels, debt, colonisation, naval and more |
| Market researcher | Sonnet | Researches what makes strategy games fun, what players and the Steam market want, and proposes improvements; keeps the fun principles in [research](research/fun-principles.md) |
| Systems and economy designer | Sonnet | Balances the game with measured full games to 1650 |
| Art director | Opus | Designs and reviews code-drawn art in one style; tracks the Kenney art still in use |
| UI and UX designer | Opus | Makes screen and menu mockups (see [design/ui](design/ui/README.md)) |
| QA and playtest lead | Sonnet | Bug hunts: long games, draw sweeps, save checks, monkey tests, fun notes |
| Code reviewer | Sonnet | Checks each worker's changes and each pull request for real bugs, proving each one |
| Workers | Haiku or Sonnet | Build one well-scoped task each, with tests and screenshots |

## How work flows

1. **Idea:** it goes into the [roadmap](roadmap/roadmap.md) backlog.
2. **Design:** the game designer or UX designer writes it up. The creative director reviews it (the technical director too, for code-heavy work).
3. **Approval:** the owner picks among the options. Nothing is built before this step.
4. **Build:** a worker builds it, with tests and screenshots. Parallel workers never share files.
5. **Review:** the code reviewer checks the changes. The planning session runs the tests, looks at the screenshots and commits.
6. **Release:** the producer drafts the notes. Releases are numbered 0.1.x until the 1.0 Steam launch.

## How a release runs (decided 2026-11-13)

One release is built at a time. The next one is planned alongside it, on paper only.

1. **Planning (before any code).** The producer drafts a one-page release brief: the theme, candidate items from the backlog, open bugs, and what the last playtest found. The creative director checks it against the fun principles and cuts what is off-theme. Designs and mockups for the release are made now. The owner decides everything in **one batch**: what is in, what is out, and every design question. The brief is then frozen: scope, order of work, and a done-when list with a short playtest checklist.
2. **Build.** Only the brief's items are worked on. A new idea goes into the backlog with the release it fits; it is not started. Bugs are the only exception. If an item grows, the owner is told and something is cut.
3. **Release check.** Tests, soak, saves, performance, the changelog and release notes; then the owner plays it with the checklist.
4. **Look back (five minutes).** What went well and what annoyed in play; it feeds the next planning.

**In parallel:** while release N is built or checked, release N+1 is planned on paper (brief draft, designs, mockups, reviews). N+1's code starts only after N ships, and N+1's brief is locked only after the owner has played N. Nothing from planning changes N's scope.

## Rules

- The owner decides on designs, looks and rules.
- Open bug issues are fixed before new features start.
- Only the planning session commits, merges, and writes to GitHub.
