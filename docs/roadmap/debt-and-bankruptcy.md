# Debt and bankruptcy roadmap

Status: idea stage (2026-11-12). Nothing here is designed or approved yet. The design comes with mockups and is approved by the owner before any build.

## The idea (owner, 2026-11-12)

A country should have a **hard debt limit**. When it reaches that limit, it **goes bankrupt**. Bankruptcy is like a reset of its finances, with **long-lasting penalties**. Possible penalties:
- castles ruined
- units deserting
- provinces lost to the creditors
- a lasting percentage penalty to the economy

The exact penalties depend on how debt is modelled.

## What exists today (v0.1.5, an interim fix for #69)

This is a stopgap that stops the endless debt spiral. It is not the final design.

- **Debt limit:** 6 seasons of running costs, at least 300 ducats (`DEBT_SEASONS`, `DEBT_FLOOR` in `data.py`).
- **Interest:** 2% a season, on debt up to the limit only.
- **Over the limit with a deficit:**
  - Unpaid troops desert first: the oldest era first, never the general.
  - With no troops left, creditors seize one level at a time: buildings, then works, castles and settlement levels.
  - The treasury is held at the limit (a write-off).
- **The AI in distress:** it raises taxes, stops spending, and disbands troops until it runs a surplus.

## Steps

1. **Model the debt.** Decide what debt is:
   - one number, or loans: taken on purpose, with an amount, rate and term
   - who the creditors are: banks such as the Fuggers and Genoa, burghers, or other countries
   - whether interest depends on reputation or credit rating
   - whether debt can be taken on purpose: for example, a war loan
2. **Warning stages before bankruptcy:** for example, rising interest, then unrest, then a "credit refused" stage, each shown clearly in the UI with a countdown.
3. **Bankruptcy event:**
   - The hard limit triggers it, as a pop-up with a choice where possible. One option is to default on the creditors; another is to sell provinces or pay with goods.
   - The debt is reset, and a choice of penalties applies, such as:
     - castles ruined: a level lost, rebuilt at full cost
     - the army deserts: a share of the troops, the elites first
     - provinces pledged or lost to creditors, or to a creditor country
     - a lasting economy penalty: for example, −X% tax and trade income for N years, or a higher interest rate for N years
     - prestige or score loss, and worse relations with creditor countries
4. **Recovery:** how long the penalties last, how they fade, and whether a reform choice can shorten them.
5. **UI:**
   - the debt shown in the resource bar and the ledger
   - a debt panel: loans, interest, the limit and the countdown
   - log messages, with floating text for seizures and desertions
6. **AI:** it borrows sensibly, avoids bankruptcy, and recovers after one. It needs to be checked in the long-run tests: few bankruptcies, and none that run forever.
7. **Balance and fun test:** is debt a meaningful tool (borrow to win a war), and is bankruptcy dramatic but survivable?

## Open questions for the owner

- Loans as a player choice, or debt only as a result of a negative treasury?
- Which penalties: all of the listed ones, a choice at bankruptcy, or random by situation?
- Do provinces go to a creditor country? That needs diplomacy, and could be a casus belli.
- How long do the penalties last: years, or until a reform?
- Does the debt carry over, or does bankruptcy wipe it completely?

## Where it fits

- It's planned with the balance and fun pass (M4), together with the economy fun test.
- It builds on the architecture refactor: debt as its own system module, and the event bus for the bankruptcy pop-up.
- Its event pop-up can share the system with the RPG-style events (Phase 3).
