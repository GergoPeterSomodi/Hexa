# How Hexa is made: the studio

Hexa is built by the owner with a team of AI agents in Claude Code. It is a lean version of the "Claude Code Game Studios" idea: specialised roles, review gates, and the owner deciding. The main planning session plans the work, briefs the agents, reviews their results and commits.

## The team

| Role | Model | What it does |
|---|---|---|
| Creative director | Opus | Reviews every design against the vision and the fun before the owner sees it |
| Technical director | Opus | Reviews architecture and big changes, and leads the architecture refactor |
| Producer | Sonnet | Keeps the roadmap, milestones, issue triage, the changelog and release notes |
| Game designer | Sonnet | Writes design docs for new systems: diplomacy, rebels, debt, colonisation, naval and more |
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

## Rules

- The owner decides on designs, looks and rules.
- Open bug issues are fixed before new features start.
- Only the planning session commits, merges, and writes to GitHub.
