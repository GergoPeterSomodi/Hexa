# Crown projects: a use for late-game money (design proposal)

Status: DRAFT for the owner (2026-11-13). Nothing here is approved or built. This is proposal E1 of `docs/reports/economy-fun-test.md`. The owner asked for the design first, then a decision.
Mockups are listed in section 9. The owner sees them before any build.

## Questions for the owner

1. **Cost rule.** Is "10 seasons of gross income for the first purchase, x1.5 for each repeat of the same project" the right shape? Recommended: yes, with the income taken at the Normal tax level, so the player cannot make a project cheap by setting Low tax for one season (section 3). Alternatives: one shared ladder for all projects (a total of N bought, x1.5 each; it ends the sink sooner), or a plain flat cost (it fails: see the report, F8).
2. **How many projects in the first version?** Recommended: four (Bank, Court, Cathedral, Royal road). They use effects that already exist in the game. Navy yard and Palace come in a second step because they need a new effect and the overextension rules.
3. **Does Court speed up research?** Research is already too fast (report F9, question 5). Recommended: yes, but small (+5% per level, at most +25%), and do the research pace pass first or at the same time. Alternative: make Court a prestige-only project until research is tuned.
4. **Score.** Today score counts treasury / 50, so hoarding scores points and a purchase would lose points. Recommended: (a) every project pays score points worth twice what the money was worth in the treasury (Cathedral and Palace four times), and (b) the treasury term stops counting above 15 seasons of income. Alternative: change only (a).
5. **Can a project be bought on credit?** Recommended: no. The treasury must cover the full cost. Projects are for money you have. Debt stays a trap for emergencies, and the loans design can later add "finance a project" if it wants.

## 1. What problem this solves

From the economy fun test:

- After the build-out (about 1580 for a mid-sized country) there is nothing to decide. The AI buys every useful thing, then piles up money.
- Median AI treasury: 4.5 seasons of income in 1600, 44 in 1649, and 213 at the 90th percentile.
- Portugal ends 1649 with 152,000 ducats, Venice 179,000, France 848,000.
- A flat extra cost or a percentage levy does not help. It cuts income and leaves the pile. Something must be worth buying.
- The bankruptcy and loans design waits for this (decision E6). Debt means nothing while money has no use.

A Crown project is a big, repeatable, country-level purchase. Its price follows the size of the economy, so a rich country always has a next one to save for. The target is a median hoard under 15 seasons of income.

## 2. The projects

A project is bought for the whole country, once per few seasons, with ducats only. It has a level from 1 to 5. Each level gives its effect again and the next level costs more. The effect is shown on the capital (a small stamp on its province panel and, later, a banner on the map).

| Project | Needs | Effect per level (v1 numbers) | Kind |
|---|---|---|---|
| Bank | era 2, marketplaces with 3 levels in all | High tax hurts growth 10% less (`tax_relief` +0.10), burgher tax +4%, debt limit +1 season of running costs | economy |
| Court | era 2, a university | research +5% | research |
| Cathedral | era 1, a town or city | population growth +0.0001 a season, score points x4 | prestige |
| Royal road | era 2 | supply range +1 hex, market reach +5% | logistics |
| Navy yard (step 2) | era 2, a shipyard | ships cost 8% less (new effect `ship_cost`) | navy |
| Palace (step 2) | era 3, a city | score points x4, and it is the admin centre for the overextension rules when those come | prestige |

Notes on each:

- **Bank.** It is the one with a real economic reason: it softens High tax (the emergency lever from E3) and raises the debt limit, so it is the first project that interacts with bankruptcy. It lifts income a little. That is fine, because the cost then rises with it.
- **Court.** Research per level is small on purpose (see question 3).
- **Cathedral.** Mostly for score. Its growth effect is tiny (4% of the base growth per level) so it does not become a hidden income engine.
- **Royal road.** Matters to big and warring countries. It gives them something to spend on that helps the army without making it stronger in a battle.
- **Navy yard** needs a ship cost effect that does not exist yet (`nav_cost` only changes tech costs).
- **Palace** is the natural hook for the brakes design (`stop-steamrolling.md`): the capital and admin centres reduce distance unrest.

Projects have no upkeep in v1. They also cannot be sold. The bankruptcy design may take one level as a penalty (section 6).

## 3. Cost

```
gross      = production + taxes + buildings + trade           (the positive parts of country.income)
base       = gross, with the tax parts scaled back to the Normal tax level
cost       = PROJECT_COST_SEASONS x base x PROJECT_REPEAT ^ (level of that project already bought)
```

- First purchase: 10 seasons of gross income. Each repeat of the same project costs 1.5 times the one before.
- "Gross" is chosen over net because net is nearly the same (upkeep and army are about 8% of income late) and gross has no negative cases.
- Why at Normal tax: Low tax cuts gross by 30% for one season. Without the rule a player could set Low, buy a 15,000 project for 4,500 less, and set Normal again. The tax parts (production tax and pop taxes) are divided by the current rate, so the cost does not move when the tax level moves. Nothing is stored.
- The cost is calculated when you buy. It rises as the economy grows. A country that waits does not get cheaper projects, but it also does not lose anything by waiting except the effect.
- A gap of 4 seasons between two purchases of one country keeps the AI from buying five in a row after a windfall.

## 4. What it does to the hoard (estimate, not an engine run)

Method: I took the measured mean income and treasury curves of the report (F1) for Portugal, Venice, France and Genoa. The model keeps the surplus the AI actually left unspent each season (the rise of the treasury curve from 1550 on), adds a buyer with the AI's reserve rule (80 + 3 x income), and lets it buy the cheapest available project every 4 seasons or more. Gross income is 1.08 x net. The projects change nothing else in the model: no income gain from the Bank, no upkeep. The scripts are in the scratchpad, not the repo.

Mean treasury in seasons of income, 1625 to 1649, and purchases made from 1550 (five levels per project):

| Setup | Portugal | Venice | France | Genoa |
|---|---|---|---|---|
| Today (report, 1649) | 103 | 123 | 204 | 85 |
| 4 projects, 10 / x1.5 (the v1 proposal) | 10 (8 buys) | 12 (9) | 22 (15) | 11 (7) |
| 6 projects, 10 / x1.5 | 9 (9) | 11 (10) | 15 (18) | 10 (8) |
| 6 projects, 10 / x1.3 | 9 (9) | 10 (11) | 14 (20) | 9 (8) |
| 6 projects, 8 / x1.5 | 8 (11) | 10 (12) | 16 (20) | 9 (9) |

What this says:

- The shape works. The estimate takes the hoard from 100 to 200 seasons of income down to about 10 seasons for the mid-sized countries.
- France stays above 15 with four projects. With six it is at 15. France is the case that needs the most projects, since it earns 4,000 a season and buys one every 4 seasons at most.
- A point-in-time reading (the last season) is lumpy: it swings 5 to 19 seasons depending on when the last purchase fell. The 25-year mean is the fair measure.
- The repeat factor (1.3 or 1.5) hardly changes the late hoard. The cost level (6, 8 or 10 seasons) does. The numbers to tune are `PROJECT_COST_SEASONS` and the project count, not the repeat factor.
- The model buys 8 to 18 projects per country over 100 years (France 15 to 24). That is a decision every 5 to 10 years, which matches the report's expectation.
- The surplus model assumes E2 (the 0.25 / 0.45 / 0.25 numbers) is not yet in. E2 raises income 20 to 45% and the surplus with it. Then the target needs about 1.3 times the cost level or the sixth project. Re-measure in the engine after both.

Not tested: the real AI in a full game. That is step 6 of the build plan.

## 5. How the AI buys

A new `_projects(world, tag)` step in `ai.py`, after `_build` and `_invest`, so the cheap and useful buildings are still bought first.

- Rule: a project is bought when the treasury minus the cost is still above the AI's reserve (80 + 3 x income) and 4 seasons have passed since its last purchase.
- Choice: the project with the best weight, divided by 1.5 to the power of its level. Weights: Bank 1.0, Royal road 1.0 when at war or with 15+ provinces else 0.4, Court 0.8, Cathedral 0.6, Navy yard 0.8 for countries with colonies or ports (else 0.2), Palace 0.6. A project below its level cap and with its needs met.
- The AI does not buy before it can afford one with its normal reserve intact. In 1500 a treasury is about 4 seasons of income and a project costs 10, so early game is unchanged. Projects only start to matter when the build-out has run out. This is on purpose.
- A distressed AI (debt, at war with a stronger enemy) does not buy.

## 6. Score, tech tree, buildings, loans and bankruptcy

**Score.** Today: `pop / 20 + balance x 3 + colonial x 2 + treasury / 50`.

- A purchase takes money out of the treasury, which lowers score by `cost / 50`. So a project must give points back.
- Each country records the ducats it spent on projects (`paid`). Effect projects give `paid / 50 x 2` points, Cathedral and Palace `paid / 50 x 4`. A saved-up treasury and a spent one then rank the same only if the spending was at least twice as good. Spending wins.
- Proposed with it: the treasury term counts at most 15 seasons of income. Otherwise a 150,000 hoard stays worth 3,000 points and no project can beat it. This also fixes the playtest's missing goal.
- The "Prestige" chip in the top bar already reads `world.score`. Its hover card lists the parts, and gets a "Crown projects" line.

**Tech tree.** The tree gives unlocks and flat percentages once. Projects are the repeatable sink. They do not replace any tech.

- Projects are gated by era (`country.era`), not by single techs, so the tech tree stays as approved.
- Project effects use the same keys as techs and ideas (`tax_relief`, `research`, `supply_range`, `market_reach`, `burgher_tax`, `burgher_growth`), so every consumer in the economy code works unchanged. One new key (`ship_cost`) comes with the Navy yard.
- The effects are added in `CampaignWorld._effects` (the bonus cache). A purchase calls `tech_changed(tag)` so the cache is rebuilt.

**Buildings.** Buildings are per province, slot limited, and mostly pay back. Projects are per country and only a sink. Their needs tie them to buildings: a university for Court, marketplaces for Bank, a shipyard for Navy yard. That gives the buildings a second purpose and keeps a country from buying a project it has no base for.

**Loans and bankruptcy** (UI section 5, built after this):

- Projects can not be bought with debt, so a country in debt does not buy them.
- The Bank raises the debt limit by one season of running costs per level and makes High tax safer. A rich country is rewarded with credit.
- Bankruptcy gets a new penalty option, "lose a project level" (the one with the highest `paid`), next to the penalties in UI section 5. Rebuilding it costs again. This gives bankruptcy something worth losing for a rich country, which is what E6 wanted.
- "Ways out" in the debt panel does not offer selling a project in v1.

## 7. What the player sees

- **Treasury chip hover:** "Treasury: 42,000 (28 seasons of income). Next project: Bank level 2, 9,300. You can buy it now."
- **Crown window** (button in the top bar next to the Treasury, key P): six cards, each with a level meter (5 pips), the effect now and at the next level, the price, the seasons of income it equals, and a Buy button with a reason when disabled ("Needs a university", "Era 2", "Wait 3 seasons", "Not enough ducats: 4,100 more").
- **Purchase feedback:** a log line "Crown: Bank, level 2, 9,300 ducats" in the Money filter, a toast, a floating tag on the capital, and an event for the feed (`project_built`).
- **Reminder:** the end-of-turn list gets "A Crown project is affordable" when the treasury is above 20 seasons of income.
- **Country panel:** a row of six small stamps with levels.
- **Treasury window (UI section 7):** the "Unspent for N seasons" line links to the Crown window.

## 8. Save compatibility

- `Country` gets two fields with defaults: `projects: dict` ({key: level}) and `project_paid: float` plus `project_turn: int` (turn of the last purchase). Dataclass defaults are filled by `_migrate` (`fill_defaults`), so an old save loads with no projects and plays as before.
- No world attribute is added, so `WORLD_DEFAULTS` stays as it is. The effects are derived, so no cache is saved.
- Old saves load: the new fields are filled by default. A newer save in an older build is the open point. Older builds only ignore a newer save if `VERSION` is higher. Recommended: bump `VERSION` to 2 in this change. Old saves keep loading through `_migrate`, and `tools/save_compat.py` checks both directions.
- Score of an old save changes by the new treasury cap only. That affects the ranking display, not the game.
- Behaviour oracle: the AI's new step changes the fixed-seed games, so this is not a refactor PR. Update the oracle's expectations deliberately.

## 9. Mockups needed (before any build)

1. The Crown window, six cards, with disabled and affordable states.
2. The treasury chip hover card with the "next project" line, and the Prestige hover with the projects line.
3. The capital's project stamps (panel row) and the six small icons in the ink-outline style.
4. The purchase moment: toast, log line and the floating tag on the capital.
5. The end-of-turn reminder line.
6. Later, with bankruptcy: the "lose a project level" choice card.

## 10. Numbers for `data.py`

```
PROJECT_COST_SEASONS = 10      # first purchase = this many seasons of gross income (at Normal tax)
PROJECT_REPEAT = 1.5           # each repeat of the same project costs this much more
PROJECT_MAX_LEVEL = 5          # Palace: 3
PROJECT_GAP = 4                # seasons between two purchases of one country
PROJECT_SCORE = 2              # score per 50 ducats paid, effect projects; prestige projects x2 more
HOARD_SCORE_SEASONS = 15       # the treasury scores only up to this many seasons of income
PROJECTS = { key: Project(name, era, needs, effects per level, text) }   # table in the table of section 2
```

Constants are starting points. Tune `PROJECT_COST_SEASONS` first (6, 8 or 10), then the project count.

## 11. Smallest first version

- Four projects: Bank, Court, Cathedral, Royal road. Only existing effect keys.
- The cost rule of section 3, the 4-season gap and the level cap.
- The AI step.
- The Crown window and the treasury hover line. No map art, no reminder.
- The score change.

Out of v1: Navy yard, Palace, the capital stamps, the reminder, any bankruptcy link.

## 12. Build steps

1. Mockups 1 to 5 approved by the owner.
2. `data.py`: constants and the `PROJECTS` table. README table.
3. `campaign/systems/projects.py`: `project_cost`, `project_check` / `buy_project` (a pair, with facades on `CampaignWorld`), `gross_income`. `Country` fields. `_effects` merge. Event `project_built`. Add the pair to `tests/support/agents.py`.
4. `season.score` change (projects and the hoard cap). Update the tests that pin score.
5. `ai._projects`. Unit tests: no buy before the reserve, 4-season gap, level cap.
6. A full-game measurement: seeded AI games to 1650, 3 seeds, median hoard in seasons of income, purchases per country, effect on income (the Bank), against the table in section 4. Adjust `PROJECT_COST_SEASONS`.
7. The Crown window, treasury hover line, feed line, floating tag.
8. Save compatibility: `VERSION` bump, `tools/save_compat.py` both ways, a test that an old save loads with empty projects.
9. Step 2 content: Navy yard (`ship_cost`), Palace, the stamps, the reminder.
10. Then the bankruptcy and loans design, with the project-level penalty.

## 13. Risks

- **The AI may not buy as modeled.** The estimate ignores the AI's building list, wars and income gains. Step 6 tests it. If the hoard stays high, raise the cost level or add the two step-2 projects.
- **Bank snowball.** The Bank raises income, so the other projects cost more. This is a soft brake. If it still snowballs, make the Bank's tax bonus 3% per level.
- **Court and research.** Research is fast already (see question 3).
- **Score trap.** A score of 4 times for the Cathedral and Palace makes them the "winning" purchase for a score-minded player. They give almost no effect, so this is a choice, not an exploit. Playtest it.
- **Tax rule complexity.** The Normal-tax rule is a few lines but has to match `economy.incomes` exactly. A test compares it against a run at each tax level.
- **E2 interaction.** E2 raises income and the surplus, so both must be re-measured together.
- **Lumpy purchases.** The treasury will climb to the cost, drop, and climb again. That is the intended rhythm, but the Treasury window must show it, or the player thinks the money disappeared.
- **Small states.** Palatinate earns about 230 a season and reaches 6,700 in 1649. A project costs 2,300. It buys two or three. That is fine, and none of them bankrupts it.
- **Not run in the engine.** All figures above are a model on the report's mean curves, three games of which are noisy (up to 50% for small states).
