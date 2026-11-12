"""The province panel: who owns it, its people, the tile and its buildings, and what the player can do there."""
import pygame

from ...ui.kit import heading, panel_frame
from ...ui.theme import BAD_C, FAINT, GOLD, GOOD_C, MUTED, TEXT
from ..data import (BUILDINGS, CASTLES, COLONY_DONE, GOODS, SETTLEMENT_SLOTS, SETTLEMENTS, TERRAIN, WORKS,
                    WORKS_BONUS, WORKS_ERA, WORKS_LEVELS)


def draw(ctx, world, ui, prov):
    """Draw the panel of `prov` (the open province, or the one a unit stands in)."""
    tag = world.player
    x, y, w = panel_frame(ctx)
    y = _header(ctx, world, prov, x, y, w)
    y = heading(ctx, "People", y)
    y = _people(ctx, world, prov, tag, x, y, w)
    if prov.owner == tag and tag:
        y = _tile(ctx, world, prov, tag, x, y, w)
        y = _buildings(ctx, world, prov, tag, x, y, w)
    elif prov.owner and tag:
        ctx.button((x, y, w, 26), f"Diplomacy with {world.countries[prov.owner].name}", True,
                   ("country", prov.owner), small=True)
        y += 32
    if prov.market:
        ctx.button((x, y, w, 26), f"Open the {prov.market.name} market", True, ("market", prov.market), small=True)


def _owner_line(ctx, world, prov, x, y, w):
    if prov.owner:
        country = world.countries[prov.owner]
        what = "Colony of " if prov.colony else "Trading post of " if prov.trading_post else ""
        pygame.draw.rect(ctx.screen, country.color, (x, y + 3, 12, 12))
        used = ctx.text(ctx.font, f"{what}{country.name}", (x + 18, y))
        if prov.region and prov.region not in prov.name and w - 26 - used > 40:
            ctx.text(ctx.small, f"·  {prov.region}", (x + 26 + used, y + 2), MUTED, w - 26 - used)
    else:
        land = prov.region if prov.region.endswith(" lands") else f"{prov.tribe} lands" if prov.tribe else ""
        ctx.text(ctx.font, f"Unclaimed: {land}" if land else "Unclaimed land", (x, y), MUTED, w)


def _header(ctx, world, prov, x, y, w):
    """Name, owner, terrain and market, occupier and the good it makes; returns the y below them."""
    ctx.text(ctx.title, prov.name, (x, y), width=w - 30)
    y += 30
    _owner_line(ctx, world, prov, x, y, w)
    y += 20
    market = f"   Market: {prov.market.name}" + (" (far: -30%)" if prov.remote else "") if prov.market else ""
    ctx.text(ctx.small, f"{TERRAIN[prov.terrain].name}{', coast' if prov.coastal else ''}{market}", (x, y), MUTED, w)
    y += 20
    if prov.controller and prov.controller != prov.owner:
        ctx.text(ctx.font, f"Occupied by {world.countries[prov.controller].name}", (x, y), BAD_C)
        y += 20
    if prov.good:
        line = f"Produces {GOODS[prov.good].name.lower()}"
        if prov.owner:
            line += f": {prov.output:.1f} a season, worth {prov.value:.1f} ducats"
        ctx.text(ctx.font, line, (x, y), width=w)
    else:
        ctx.text(ctx.font, "Produces nothing of value", (x, y), MUTED)
    return y + 26


def _people(ctx, world, prov, tag, x, y, w):
    """Peasants, burghers and nobles, food, natives and the colony's growth bar; returns the y below them."""
    if prov.owner:
        ctx.text(ctx.font, f"Peasants {prov.peasants:.1f}k   Burghers {prov.burghers:.1f}k   Nobles {prov.nobles:.1f}k",
                 (x, y), width=w)
        y += 20
        ctx.text(ctx.small, f"Food supply {prov.food * 100:.0f}%", (x, y), GOOD_C if prov.food >= 0.95 else BAD_C)
        if tag:
            ctx.text(ctx.small, f"Feeds {world.supply_limit(tag, prov.pos)} of your troops", (x + 130, y), MUTED)
        y += 18
    if prov.natives >= 0.1:
        ctx.text(ctx.font, f"{prov.tribe or 'Native'} people {prov.natives:.1f}k", (x, y), MUTED)
        y += 20
    if prov.colony:
        done = min(1.0, prov.pop / COLONY_DONE)
        pygame.draw.rect(ctx.screen, (50, 55, 64), (x, y + 2, w, 10), border_radius=4)
        pygame.draw.rect(ctx.screen, GOOD_C, (x, y + 2, w * done, 10), border_radius=4)
        ctx.text(ctx.small, f"Colony: {prov.pop:.1f}k of {COLONY_DONE:.0f}k people to become a full province",
                 (x, y + 14), MUTED)
        y += 34
    return y + 4


def _works_row(ctx, world, prov, tag, x, y, w):
    """The tile's improvement (field, mine, ...) with its Invest button."""
    level = prov.works
    name = world.works_name(prov) or "Untouched land"
    pips = "".join("*" if i < level else "." for i in range(WORKS_LEVELS))
    ctx.text(ctx.font, f"{name}" + (f"  +{WORKS_BONUS * level * 100:.0f}%" if level else ""),
             (x, y + 3), TEXT if level else MUTED, 190)
    ctx.text(ctx.small, pips, (x + 192, y + 5), GOLD)
    if level < WORKS_LEVELS:
        nxt = WORKS[prov.good][level]
        ok, reason = world.invest_check(tag, prov)
        goods = ", ".join(f"{n:g} {GOODS[g].name.lower()}" for g, n in world.invest_goods(prov).items())
        hint = reason or (f"Invest: {nxt} (+{WORKS_BONUS * 100:.0f}% {GOODS[prov.good].name.lower()}). "
                          f"Needs {goods}, bought on the local market. Era {WORKS_ERA[level]}+.")
        ctx.button((x + 230, y, w - 230, 23), f"Invest: {nxt}", ok, ("invest", prov), hint,
                   f"{world.invest_cost(prov)}", small=True)
    else:
        ctx.text(ctx.small, "fully developed", (x + 240, y + 5), FAINT)


def _queued(prov, key):
    return next((item for item in prov.queue if item[0] == key), None)


def _building_note(ctx, queued, x, y):
    ctx.text(ctx.small, f"building, {queued[1]} season{'s' * (queued[1] != 1)} left", (x + 170, y + 5), GOLD)


def _town_row(ctx, world, prov, tag, key, names, x, y, w):
    """The settlement or the castle: its level, or what is being built, or the button to raise it."""
    level = prov.settlement if key == "settlement" else prov.castle
    current = names[level] or ("Countryside" if key == "settlement" else "No castle")
    ctx.text(ctx.font, current, (x, y + 3), TEXT if level else MUTED, 150)
    queued = _queued(prov, key)
    if queued:
        _building_note(ctx, queued, x, y)
    elif level < 3:
        ok, reason = world.build_check(tag, prov, key)
        goods = ", ".join(f"{n:g} {GOODS[g].name.lower()}" for g, n in world.build_goods(prov, key).items())
        hint = reason or (("More people, taxes and building slots" if key == "settlement"
                           else "Defends the land: +defense, longer sieges") +
                          (f". Needs {goods} from the market." if goods else ""))
        ctx.button((x + 160, y, w - 160, 23), f"To {names[level + 1].lower()}", ok, ("build", prov, key),
                   hint, f"{world.build_cost(prov, key)}", small=True)


def _tile(ctx, world, prov, tag, x, y, w):
    """The tile section of the player's own province: the busy note, the improvement, settlement and castle."""
    if prov.busy:
        ctx.text(ctx.small, "This province has done its job for this season.", (x, y), GOLD)
        y += 18
    y = heading(ctx, "The tile", y)
    if prov.good in WORKS:
        _works_row(ctx, world, prov, tag, x, y, w)
        y += 26
    for key, names in (("settlement", SETTLEMENTS), ("castle", CASTLES)):
        _town_row(ctx, world, prov, tag, key, names, x, y, w)
        y += 26
    return y


def _buildings(ctx, world, prov, tag, x, y, w):
    """The buildings list with its Build / Upgrade buttons, and the Raise units button below it."""
    slots = SETTLEMENT_SLOTS[prov.settlement]
    y = heading(ctx, f"Buildings ({world.slots_used(prov)}/{slots} slots)", y + 2)
    for key, b in BUILDINGS.items():
        if b.needs_coast and not prov.coastal:
            continue
        level = prov.level(key)
        queued = _queued(prov, key)
        label = f"{b.name} {'I' * level}" if level else b.name
        ctx.text(ctx.font, label, (x, y + 3), TEXT if level else MUTED, 150)
        if queued:
            _building_note(ctx, queued, x, y)
        elif level < world.building_max(tag, key):
            ok, reason = world.build_check(tag, prov, key)
            ctx.button((x + 160, y, w - 160, 23), "Upgrade" if level else "Build", ok,
                       ("build", prov, key), reason or b.hint, f"{world.build_cost(prov, key)}", small=True)
        else:
            ctx.text(ctx.small, "complete", (x + 170, y + 5), FAINT)
        y += 26
    y += 4
    ctx.button((x, y, w, 28), "Raise units here...", not prov.busy, ("raise", prov),
               "Infantry, cavalry, cannons, generals, scouts, pioneers, colonists and ships" if not prov.busy
               else "This province already did its job this season", small=True)
    return y + 34
