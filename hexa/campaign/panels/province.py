"""The province panel: who owns it, its people, the tile and its buildings, and what the player can do there."""
import pygame

from ...ui.icons import icon
from ...ui.kit import heading, panel_frame, wrap
from ...ui.theme import BAD_C, FAINT, GOLD, GOOD_C, MUTED, TEXT, WARN_C
from ..battleview import odds_view, siege_view
from ..data import (BUILDINGS, CASTLE_AREA, CASTLES, COLONY_DONE, GOODS, SETTLEMENT_SLOTS, SETTLEMENTS, TERRAIN, WORKS,
                    WORKS_BONUS, WORKS_ERA, WORKS_LEVELS)
from ..systems.areas import reach as castle_reach


def draw(ctx, world, ui, prov):
    """Draw the panel of `prov` (the open province, or the one a unit stands in)."""
    tag = world.player
    x, y, w = panel_frame(ctx)
    y = _header(ctx, world, prov, x, y, w)
    y = _siege(ctx, world, prov, tag, x, y, w)
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


def _siege(ctx, world, prov, tag, x, y, w):
    """The Siege block of a place under siege (0.2.2, design 4.7): the meter and its rate, the stores or the hunger, the
    seasons it falls in. The besieger gets "Storm now" (its word; storm_check's reason as the hover when it is off); the
    defender gets a relief line for each army that can reach the place (a click selects it). Nothing when no siege runs
    there or the viewer cannot see it. Reads the siege view only; the buttons press ("siege", ...) (siegeacts.py)."""
    view = siege_view(world, prov.pos, tag)
    if view is None or view["access"] == "hidden" or view["progress"] is None:
        return y
    y = heading(ctx, "Siege", y)
    falls = view["falls_in"]
    lines = [(f"Besieged by {view['besieger_name']}: {round(view['progress'])} of {round(view['need'])}, "
              f"+{round(view['rate'])} a season", TEXT),
             ("Too few men to take it" if falls is None else f"Falls in about {falls} season{'s' * (falls != 1)}",
              WARN_C if falls is None else TEXT)]
    if view["starving"]:
        lines.append((f"The garrison is starving: +{view['hunger']} a season", BAD_C))
    else:
        left = view["stores_left"]
        lines.append((f"Stores for {left} more season{'s' * (left != 1)}", MUTED))
    for text, colour in lines:
        for line in wrap(ctx.font, text, w):
            ctx.text(ctx.font, line, (x, y), colour)
            y += ctx.font.get_linesize()
    if tag and view["besieger"] == tag:
        y = _storm_now(ctx, world, prov, tag, x, y + 4, w)
    elif tag and view["defender"] == tag:
        y = _relief(ctx, view, x, y + 4, w)
    return y + 6


def _storm_now(ctx, world, prov, tag, x, y, w):
    """The besieger's "Storm now" button: the odds word of its stack on the place, or storm_check's reason when it is off."""
    units = [u for u in world.units_at(prov.pos) if u.owner == tag and u.kind.war]
    ok, reason = world.storm_check(units, prov.pos)
    word = odds_view(world, units, prov.pos, tag)["word"] if ok else ""
    ctx.button((x, y, w, 26), "Storm now", ok, ("siege", "storm", prov.pos),
               "The assault now: the garrison is cut by the siege's progress" if ok else reason, word, small=True)
    return y + 32


def _relief(ctx, view, x, y, w):
    """The defender's relief line for each army that can reach the place (the nearest first), a button that selects it."""
    if not view["relief"]:
        ctx.text(ctx.small, "No army of yours can reach it within four seasons", (x, y), MUTED, w)
        return y + 20
    for army in view["relief"][:2]:
        seasons = army["seasons"]
        ctx.button((x, y, w, 26), f"Relief: your army of {army['men']:,} men can reach it in {seasons} "
                   f"season{'s' * (seasons != 1)}", True, ("siege", "relief", army["pos"]),
                   "Select this army and look at it", small=True)
        y += 30
    return y


def _area_chip(ctx, world, prov, x, y, w):
    """The castle-area chip under the owner line (castle-areas.md section 4, item 2): held land, a castle, fallen land or
    open land, with its hover (the path the reach counts, or the castle's provinces). Nothing for land another castle
    holds, which the owner line already says, or for an unclaimed hex. Returns the y below the chip."""
    info = world.area_state(prov.pos, world.player)
    if info is None:
        return y
    state, holder = info["state"], info["castle"]
    if state == "castle":
        if prov.controller == prov.owner:
            return _chip_at(_castle_chip(ctx, world, prov, x, y, w))
        return _chip_at(_fallen_chip(ctx, world, prov, prov, x, y, w))
    if state == "held":
        return _chip_at(_held_chip(ctx, world, prov, info, x, y, w))
    if state == "fallen":
        return _chip_at(_fallen_chip(ctx, world, prov, world.provinces[holder], x, y, w))
    if holder is None:
        return _chip_at(_chip(ctx, x, y, w, "Open land: no castle holds it", None, None, lit=False))
    return y


def _chip_at(rect):
    """The y below a chip (its rect), or None when nothing was drawn."""
    return rect.bottom + 6


def _chip(ctx, x, y, w, line1, line2, shield, lit=True):
    """A chip: an optional shield (name, colour), a line and an optional smaller line under it, in a frame of the shield's
    colour (or a plain one). Returns its rect."""
    h = 40 if line2 else 26
    rect = pygame.Rect(x, y, w, h)
    edge = shield[1] if shield and lit else (60, 68, 80)
    pygame.draw.rect(ctx.screen, (31, 36, 45), rect, border_radius=5)
    pygame.draw.rect(ctx.screen, edge, rect, 1, border_radius=5)
    tx = x + 8
    if shield:
        ic = icon(shield[0], 22, shield[1])
        ctx.screen.blit(ic, ic.get_rect(midleft=(x + 6, rect.centery)))
        tx = x + 34
    ctx.text(ctx.font, line1, (tx, y + 3), TEXT if lit else MUTED, w - (tx - x) - 8)
    if line2:
        ctx.text(ctx.small, line2, (tx, y + 21), MUTED, w - (tx - x) - 8)
    return rect


def _held_chip(ctx, world, prov, info, x, y, w):
    """Held land: the owner's shield, "Held by the castle of X", how far it is and the castle's reach; the hover lists the
    path the distance is counted along (the owner's own land, not across the border)."""
    castle = world.provinces[info["castle"]]
    level, d, reach = castle.castle, info["distance"], castle_reach(castle.castle)
    owner = world.countries[prov.owner]
    kind = CASTLES[level].lower()
    rect = _chip(ctx, x, y, w, f"Held by the castle of {castle.name}",
                 f"{d} hex{'' if d == 1 else 'es'} away  ·  a {kind} holds land {reach} hexes out",
                 ("shield", owner.color))
    names = [world.provinces[p].name for p in reversed(info["path"])]
    rows = [names[i:i + 3] for i in range(0, len(names), 3)]
    lines = [(" > ".join(row) + (" >" if i < len(rows) - 1 else ""), TEXT) for i, row in enumerate(rows)]
    lines += [("", None), (f"Counted along {owner.name}'s own land, not across the border", MUTED),
              (f"A {kind} holds land up to {reach} hexes out", MUTED)]
    ctx.hoverable(rect, (f"{castle.name} is {d} hex{'' if d == 1 else 'es'} away", lines))
    return rect


def _castle_chip(ctx, world, prov, x, y, w):
    """A castle's own chip: how many provinces it holds and how far out, the level's reach as the hover's last line; the
    hover lists up to twelve of them."""
    n, reach = world.area_opens(prov.pos), castle_reach(prov.castle)
    owner = world.countries[prov.owner]
    plural = "" if n == 1 else "s"
    rect = _chip(ctx, x, y, w, f"Holds {n} province{plural}, up to {reach} hex{'' if reach == 1 else 'es'} out",
                 f"reach: a tower {CASTLE_AREA[1]} hexes, a small castle {CASTLE_AREA[2]}, a large castle {CASTLE_AREA[3]}",
                 ("shield", owner.color))
    names = sorted({world.provinces[p].name for p in world.area(prov.pos)
                    if p != prov.pos and world.provinces[p].controller == prov.owner})
    lines = [(", ".join(names[i:i + 3]), TEXT) for i in range(0, min(12, len(names)), 3)]
    if len(names) > 12:
        lines.append((f"and {len(names) - 12} more", MUTED))
    lines += [("", None), (f"{owner.name}'s land within {reach} hexes of {prov.name},", MUTED),
              ("nearer to it than to another castle", MUTED)]
    ctx.hoverable(rect, (f"The castle of {prov.name} holds {n} province{plural}", lines))
    return rect


def _fallen_chip(ctx, world, prov, castle, x, y, w):
    """Open land of a castle that has fallen: a grey broken shield; the land does not flip by itself (castle-areas 2.3)."""
    rect = _chip(ctx, x, y, w, f"Open: the castle of {castle.name} has fallen",
                 "its land lies open: walk in and take it", ("shield_broken", (150, 150, 150)), lit=False)
    return rect


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
    y = _area_chip(ctx, world, prov, x, y, w)
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
