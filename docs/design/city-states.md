# Age of Discovery: city states and free cities (draft for the owner, not approved)

Status: design draft. Nothing is built. Requested in the playtest ideas of 2026-11-12.

## Owner's decisions (2026-11-13)
1. **Option B**: a new "city state" kind with its own rules, in two steps.
2. **Soft cap**: the bonuses stop past the start size + 10, and the country becomes a normal state.
3. **Buying:** only small city states (12 provinces or fewer), and **the price must be high**. Later, in the diplomacy rework, the city state must also **agree** to the sale, based on relations between the two states.
4. **The AI does not buy** in the first version.
5. **No mercenaries** (the owner decided this for recruiting too).
6. **Ragusa, and the Hansa split into towns, in step 2.**
7. **City states are playable** (Venice, Genoa, the Hansa).
8. **The Swiss stay one normal country.** A league of cantons is parked for later.

## Questions for the owner
1. **Which option?** (A) a label on today's countries; (B) a new "city state" kind with its own rules; (C) full diplomacy with leagues, protection and vassals. Recommend **B**, in two steps (see Options). Protection and leagues move to the diplomacy rework, because they need alliances, which do not exist yet.
2. **Size rule:** a province is one hex, so Venice starts with 43 provinces, the Hansa 24 and Genoa 8. Options: (a) a hard cap on land; (b) a soft cap: the city-state bonuses stop when land grows past the start size + 10, and the country becomes a normal state; (c) no size rule. Recommend **(b)**: growing is allowed, but it is a real choice with a price.
3. **Who can be bought?** Options: (a) any city state; (b) only small ones (12 provinces or fewer: Genoa, later Ragusa and single Hanse towns); (c) none, protection only. Recommend **(b)**. Buying Venice outright would be neither fun nor history.
4. **Can the AI buy city states?** Recommend **no in the first version**, so Genoa does not vanish in 1500 in half the games. Turn it on later after a soak run.
5. **Mercenaries:** the roadmap leaves mercenaries undecided (recruiting rework). Options: (a) decide them there, and city states use them later; (b) add them here, for city states only. Recommend **(a)**. The first version has no mercenaries.
6. **Add Ragusa (RAG)?** It does not exist today. Recommend yes, in step 2, together with splitting the Hansa into towns.
7. **Can the player play a city state?** Recommend yes (Venice, Genoa and the Hansa are already playable). The rules must keep them fun.
8. **The Swiss:** recommend not a city state. Keep them a normal country until mercenaries are designed; then a "league of cantons" with a mercenary theme fits.

## What exists today (checked in `hexa/campaign/geo.py` and a 1480 world)
These are normal countries in the 1480 data:
- `VEN` Venice: 7 seed points, including Crete and Cyprus; 43 provinces, 19 coastal
- `GEN` Genoa: 8 provinces
- `HAN` Hansa: seed points at Lubeck, Hamburg and Bremen; 24 provinces
- `SWI` Switzerland (16, no coast), `MLO` Milan (13), `TUS` Florence (9), `COL` Cologne, `BRU` Brunswick

There is **no Ragusa**, no Augsburg or Frankfurt city state, and no Antwerp state (Antwerp is in Burgundy). They act like any country: raise armies, take land, declare wars. So today Venice and Genoa play as small kingdoms.

Also missing today, and assumed by earlier drafts: unrest, relations between countries, casus belli, alliances, pirates, mercenaries and a "prosperity" value. This design uses none of them in step 1.

## Goal
City states make Europe richer. They are small, rich and trade-minded, and they live by trade, not land. Playing one, you win by money instead of conquest. Facing one, you get a choice: trade with it, buy it, or take it by war and pay the price. Buying also gives the economy a real money sink, which the 2026-11-11 playtest found missing (about 9,000 ducats by 1517 with nothing to spend them on).

## History in brief
- Venice and Genoa: sea empires, with fleets, colonies and hired troops.
- The Hanse: a league of towns, each self-governing, sharing convoys and privileges. It declined after 1500 as the Dutch and English rose.
- Ragusa: a tiny republic that paid tribute to the Ottomans and kept its trade.
- The Swiss: free cantons, famed mercenaries, rarely conquered.
- The Free Imperial Cities of the Holy Roman Empire (Augsburg, Nuremberg, Frankfurt): bankers and fairs.

## Options

### A. A label only (cheapest)
Add a `city_state` flag to `COUNTRIES`. Keep all current rules. Effects: more trade income, AI less aggressive. No new actions. Pro: tiny build. Con: no new player choices; it is just a rebalance.

### B. A new kind with its own rules (recommended, in two steps)
- **Step 1 (smallest):** a city state gets trade bonuses while it stays small (the soft cap). The player can **buy** a small city state with ducats.
- **Step 2:** new tags (Ragusa, Hanse towns as separate cities), and the AI may buy.

### C. Full system (largest)
Leagues with members and fees, protection pacts with tribute, vassals, guarantees and defensive pacts. These all need countries to join each other's wars, so they belong to the planned **diplomacy rework** (alliances, war goals, claims). Recommend designing them there, with the league and protection ideas below as input.

**Recommendation: B.** It adds a real choice now, without waiting for diplomacy, and does not build a second, smaller diplomacy system that the rework would then have to replace.

## Rules (option B)
All numbers live in `data.py` as named constants.

**City state definition.** A country with `kind = "city_state"` in the country data. At start: VEN, GEN, HAN; later RAG. TUS and MLO stay normal.

**What it gets (while small).**
- Market bonus: +15% on goods sold through its ports (`CITY_STATE_TRADE`).
- Burgher tax +10%.
- These are passive bonuses. They make the country rich; they are not the decisions. The decisions are growing past the cap, buying, and war.

**Soft cap.** `CITY_STATE_GROWTH = 10`: while its land provinces are at most its start count + 10, the bonuses hold. Above it, the bonuses stop and it becomes a normal country (a log line and a notice say so). Overseas colonies and trading posts do not count. The player sees the count in the country panel ("Land 47 of 53").

**Buying a city state (annex by money).**
- Only city states with `CITY_STATE_BUYABLE = 12` land provinces or fewer.
- Price: `ANNEX_SEASONS` (suggest 40) seasons of the city state's net income, at least `ANNEX_MIN` ducats. Each later purchase by the same buyer costs +25%, resetting after 20 seasons.
- Allowed only if: the buyer is not at war with it, they have not been at war for 8 seasons, and the city state is not at war with anyone.
- Effect: its provinces become the buyer's. The buyer gets a prestige gain smaller than a conquest. The bought provinces give half income for 8 seasons (a stand-in for unrest, until the rebels design exists).
- The AI does not buy in step 1.

**Taking one by war.** Allowed, as today. No new coalition rules in step 1; the anti-steamrolling ideas (coalitions, overextension) will cover it.

**Swiss.** No change in step 1 (see question 8).

### Ideas for the diplomacy rework (not step 1)
- **Protection:** a big country protects a city state for tribute (about 8% of its income) and must join any war against it. The protector must have a real cost: if it does not send troops within 2 seasons, the pact ends and it loses prestige. A cap of 3 protected cities per protector.
- **Leagues:** a named group (Hanseatic League) with a small fee (about 2% of income), no tolls between members and +10% merchant profit. Declaring war on a member means war with the league. Leaving takes a 4-season notice with no refund. A league ends below 2 members.
- **Hanse decline scenario:** needs leagues (see the campaign doc).

## Player and AI
- **Player:** `buy_city_check/buy_city`. It follows the `*_check` pair rule.
- **AI as a city state:** trade first (ports, markets), defence second, land last. It does not declare war on a country with more provinces, and it avoids growing past its soft cap.
- **AI toward a city state:** unchanged in step 1 (it may still conquer one, as today).

## UI
- **Country panel:** a "City state" badge, the land count against the soft cap, and a tooltip listing the bonuses.
- **Buy button** on a foreign city state's country panel: "Buy Genoa (3,800 ducats)", with the check's reason on hover when it is not allowed.
- **Buy dialogue:** price, what you get, the half-income period, and the price rise for the next purchase.
- **Action log:** new notices for a city bought and a city state that grew into a normal country.
- No diplomacy UI exists in `docs/design/ui/` yet, so these are new mockups.

## Interactions
- **Economy and markets:** the trade bonus reads the `kind` flag in the market code; no new market kind.
- **Prestige** (today in `resources.py`) gets the buy gain.
- **Tech:** later, a Statecraft tech may lower the buy price, and a "Free Port" idea card may help city states.
- **Debt:** a bought city state brings its debt with it.
- **Diplomacy rework:** protection and leagues are designed there (see above).
- **Rebels:** the half-income period becomes real unrest when rebels exist.
- **Anti-steamrolling:** buying must count toward any future overextension or coalition rule, like conquest.
- **Campaign mode:** the Hanse decline scenario waits for leagues.

## Risks
- **Snowball:** a rich player buys every small city state. Mitigation: only small ones are for sale, the price rises 25% per purchase, half income for 8 seasons, and later the anti-steamrolling rules.
- **Too few buyable states in 1480:** only Genoa is small enough today. Step 1 alone feels thin until Ragusa and the Hanse towns arrive in step 2. That is the main reason to keep step 2 close behind.
- **Set-and-forget:** the trade bonuses are passive. If a playtest shows that Venice never feels the soft cap, the city state adds nothing. Check it in a full Venice game.
- **Historical honesty:** the Hanse is a league of towns, not one country. Until step 2, HAN is one city state.
- **Ragusa's place:** Venice has a seed point at Kotor (19.0 E, 42.4 N), close to Ragusa (18.1 E, 42.65 N). Ragusa must not take Venice's start land.
- **Structure not there yet:** `hexa/campaign/systems/` and `systems/season.py` arrive with the refactor phases. Until then the code goes where the structure rules allow.
- **Old saves:** a save made before the `kind` field must load as before, with the city states as normal countries or filled in by `_migrate`.

## Smallest first version
Option B step 1, nothing else:
1. `kind = "city_state"` on VEN, GEN and HAN, with the trade and tax bonus and the soft cap.
2. **Buy** for the player only, with the price, the price rise and the half-income period.
3. No leagues, no protection, no mercenaries, no AI buying.
A soak run checks that the city states behave (they stay under their cap in most seeds) and that the balance is not broken.

## Build plan (fits the structure rules)
1. Data: `kind`, `CITY_STATE_*` and `ANNEX_*` constants in `campaign/data.py`. README rules table updated.
2. `hexa/campaign/systems/citystates.py`: `buy_city_check/buy_city`. It takes `world` as a parameter and writes only its own attributes: `OWNS = {"city_buys"}` (purchase count and last turn per buyer). A new `WORLD_DEFAULTS` entry (`city_buys = {}`), so old saves load; no `VERSION` bump needed.
3. A facade on `CampaignWorld` and a pair in `tests/support/agents.py`. The UI acts only through them.
4. Events: `city_bought` (tag=buyer, `loser`, `price`) and `city_state_grew` (tag). Add them to `CAMPAIGN_KINDS` and the docstring; log handlers in `feed.py`.
5. The trade bonus and soft-cap check run in the economy step of the season.
6. AI: city states avoid growing past their cap (a small block in `ai.py`).
7. Panels: a badge and the buy button in `panels/country.py`, a buy dialogue, all with `kit`.
8. Step 2: Ragusa (RAG) needs a seed point in `geo.py` COUNTRIES (about 18.1 E, 42.65 N), a national tech and a name; random worlds get city states by rule (a small rich port country), not by tag.
9. Tests: check/action contract; save-compat; the oracle (a prepared state with a bought city); soak run. Split in two PRs: rules, then UI.

## Mockups needed before any build
1. The country panel with the city-state badge, the land count against the cap, and the buy button.
2. The buy dialogue with price, price rise and the half-income warning.
3. A map mark for a city state's capital, at two zoom levels.
4. The log line and floating text for "Venice bought Genoa".
5. Later, for the diplomacy rework: the league panel and the protection mark.

## Creative director review (2026-11-12)
**Verdict: needs work (smaller scope), then ready.** The idea fits the vision and gives the economy a money sink. But the first draft rested on systems that do not exist (unrest, relations, casus belli, pirates, alliances, mercenaries) and on an 8-province cap, while Venice starts with 43. I cut it to a buildable step 1 and moved protection and leagues to the diplomacy rework.

Weigh most:
1. **Protection and leagues wait for the diplomacy rework** (question 1), so we do not build a second, small diplomacy that gets replaced.
2. **The soft cap and "only small ones can be bought"** (questions 2 and 3): they keep Venice playable and stop a rich player buying the map.
3. **Step 1 is thin on its own:** only Genoa is buyable in 1480. Plan step 2 (Ragusa, Hanse towns) soon after, or wait and build both together.
