# Merchant houses and trade stories (design proposal)

Status: **DRAFT proposal, not decided, not built** (2026-11-25). Everything here is "(suggested)": the owner has not approved any of it.
It extends the trade layer that M10 already specifies (`docs/architecture/m10-build-spec.md`) and the price work in
`docs/design/reactive-prices.md`; it does not replace them. It is meant for Phase 3 (events and characters) of
`docs/roadmap/long-term-roadmap.md`. New work lands in `godot/` only (`hexa/` is frozen at v0.2.2).

## 1. Goal

Turn the market simulation into a source of stories. Prices, routes and merchants already exist as numbers. This proposal gives them
**faces** (merchant characters and houses), **reasons to look** (price information that ages), **levers** (stockpiles and price policy)
and **consequences** (events that read the markets and write back to them). The default stays automatic: a player who ignores all of
this still gets a working economy, as M10 decided (re-pick, auto-recall, starter nudge).

## 2. What already exists (do not rebuild)

| Area | Where it is |
|---|---|
| Markets, catchments, routes, price rule and cap | M10 spec 4.2 to 4.5; `PRICE_CAP` 3.5 |
| Merchant counts, orders, estimate, idle and loss recall, re-pick | M10 spec 4.7 |
| Tolls, agreements, embargoes | M10 spec 4.8 |
| War closing routes (grain exempt), harvests, fairs | `reactive-prices.md`, M10 1.3 and 1.2, M12 `trade_fair` |
| What a viewer may know of other markets (a yes/no per market) | M10 spec 4.14, `Knowledge.market_seen` |
| Raw materials, industries, people | `economy-rethink.md` |

## 3. Proposal

### 3.1 Merchant characters and houses
- A **merchant** order today is an anonymous slot (`MerchantOrder`). Suggested: a slot may be held by a **named merchant**: traits
  (for example Honest, Greedy, Bold, Cautious), a skill, a home market, capital, a family.
- A **house** (`MerchantHouse`) groups family members, holds capital and debts, and passes on to an heir. A bad heir weakens the
  house; a strong one grows it. Houses are kept to a few hundred in the whole world; everyone else stays an aggregate.
- A merchant's traits change the order's outcome modestly (the estimate shows the effect: a Bold merchant raises load and risk).
  Numbers start small and go to the soak for tuning.
- Relationship to the player: a house can lend, be taxed, be given a charter (links to "trade companies" in Phase 3), or be wronged
  and leave. This is the CK3-style vassal feel, applied to commerce.

### 3.2 Information that ages
- M10 decides whether a price vector is **known** or "?" (`Knowledge.market_seen`). Suggested: known prices carry an **age** in seasons.
  A market seen through a consul, a merchant on its route, or a controlled hex is fresh; one seen only through an old report is stale.
- The order card's estimate uses the last known price and shows its age. A wrong estimate is the cost of poor information.
- Keeps determinism: age is a function of state, not of luck.

### 3.3 Stockpiles and speculation (small version)
- A state or a house may buy and hold a good in a market's depot (`stock[good]`) and release it later. Only staples and a few
  trade goods are stockable; perishables decay (rate per good in `GoodDef`).
- Holding staples in a famine can calm a price; holding too much starves the market and causes unrest in M4's terms.
- Limit it to one stockpile action per market per season, as a `stockpile_check`/`stockpile` pair.

### 3.4 Policy levers
- M10 already has tolls, agreements and embargoes. Suggested additions, each with a winner and a loser: **export ban** on a good
  (protects local price, hurts the producer), **price ceiling** on a staple in the country's own markets (calms unrest, causes
  shortage), **staple right** for a town (forces foreign goods through it, earns tolls).
- Each is a `x_check`/`x` pair with a reason text, on the same pattern as the M10 actions.

### 3.5 Trade events and chains
- Events **read** market state and **write** back through actions, never directly. Triggers (all computed from existing state):
  price deviation from the 12-season mean, shortage of a staple, a route closed by war, a blockade, a merchant's order lost.
- Samples: *grain famine* (cap prices, open granaries, or let it ride); *a merchant offers a monopoly for a loan*; *a guild asks for
  protection*; *pirates demand a cut* (Phase 4); *a house fails and its debts fall on the town*.
- They use the Phase 3 event pop-up (design still open in the long-term roadmap, section Phase 3) and the M12 incident system.
  Frequency is a player option; the default is low (about one trade event a year per country).

### 3.6 Named routes and chokepoints (hex-specific)
- A route that stays busy for years earns a name from its end markets ("the Salt Road") and a history line in the log. Mountain
  passes and straits on busy routes are the natural flashpoints for war and tolls, which ties trade to the war line.

## 4. Technical notes (Godot standard, `docs/architecture/godot-architecture.md`)

- **Layers:** `defs` (`MerchantTraitDef`, additions to `TradeDef`), `state` (`MerchantHouse`, a `Merchant` list on `MapState`, depot
  stocks), `systems` (`Houses`, `Stockpiles`, `TradeEvents`), `game`/`Actions` (the `*_check`/action pairs), `views` (the known-price
  age, the house card), `shell` (panels). `core/` has no engine calls; luck only through `core/rng.gd`.
- **Season order:** any new step goes into the season table (`PHASES` equivalent) in one place, with the pinned names test updated;
  house upkeep and succession run after the trade phase and before the economy collect.
- **Events, not polling:** a change the player should notice emits a bus event (`merchant_died`, `house_failed`,
  `stockpile_released`); handlers never change the game.
- **Saves:** a new `MapState` field bumps the save FORMAT and the digest; older saves are refused, as M10 does for its changes.
- **Soak and performance:** add invariants (house capital never negative without a debt line, stocks never negative, counts bounded by
  the cap) and a trade-event rate range to the soak; budget the house step in `perf_core_budget.json`. Houses are capped
  (suggested 300) to keep the season step cheap.
- **AI:** the AI plays houses through the same actions and reads prices only through `Knowledge` (M8 rule).
- **Refactors never ride with this:** it lands as separate milestones, one system each (standard section 9).

## 5. Suggested milestones (each playable and tested before the next)

1. Information age on known prices (3.2): smallest, no new content.
2. Named merchants on orders, no houses yet (3.1, first half).
3. Houses, capital and succession (3.1, second half).
4. Stockpile pair and the first two policy levers (3.3, 3.4).
5. Trade events and chains on the Phase 3 event system (3.5).
6. Named routes and the chokepoint hooks (3.6).

## 6. Open questions for the owner

1. Do merchants become named characters, or stay anonymous slots with a trait only?
2. How many houses are right: a handful of famous ones (Medici, Fugger) or many small ones?
3. Is stockpiling in scope for a first version, or only information and events?
4. Which policy levers (export ban, price ceiling, staple right) fit the current economy rethink, and which wait?
5. Should it wait until Phase 3 is designed, or can milestone 1 (information age) go into M10's trade work?
