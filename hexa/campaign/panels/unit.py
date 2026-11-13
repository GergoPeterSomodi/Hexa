"""The unit panel: the selected stack, its supply, the ticked units with refit and drill buttons, a ship's cargo."""
import pygame

from ...ui.kit import heading, panel_frame, wrap
from ...ui.theme import BAD_C, GOLD, GOOD_C, MUTED, TEXT
from ..battleview import battle_view
from ..data import COLONIST, FOOD_PER_TROOP, GENERAL, GENERAL_TRAITS
from .cards import unit_card


def draw(ctx, world, ui, unit):
    """Draw the panel of the selected `unit` and its stack (`ui.group`)."""
    x, y, w = panel_frame(ctx)
    group = ui.group or [unit]
    troops = [u for u in group if u.kind.war]
    y = _header(ctx, world, unit, group, troops, x, y, w)
    if unit.owner == world.player or _battle_of(world, unit):
        y = _battle(ctx, world, unit, troops, x, y, w)
    if troops and not unit.naval and not unit.carrier:
        y = _supply(ctx, world, unit, group, x, y, w)
    if unit.owner != world.player:
        _foreign(ctx, group, x, y)
    elif unit.naval:
        _cargo(ctx, world, unit, x, y, w)
    else:
        y = _orders(ctx, world, ui, unit, group, x, y, w)
        _found_buttons(ctx, world, x, y, w)


def _header(ctx, world, unit, group, troops, x, y, w):
    country = world.countries[unit.owner]
    title = unit.label if len(group) == 1 else f"Stack of {len(group)}"
    ctx.text(ctx.title, title, (x, y), width=w - 30)
    y += 30
    pygame.draw.rect(ctx.screen, country.color, (x, y + 3, 12, 12))
    line = country.name
    if troops and not unit.naval:
        men = sum(u.men for u in troops)
        line += f"   ·   {len(troops)}/{world.stack_limit(unit.owner, group)} troops   ·   {men:,} men"
    ctx.text(ctx.font, line, (x + 18, y), width=w - 18)
    return y + 22


STANDING = {"hold": "Hold: stands and fights where it is", "withdraw": "Withdraw: falls back if it has a hex to go to"}


def _battle_of(world, unit):
    """The battle view of the battle on the unit's hex, if one is there and the player may know of it (else None)."""
    view = battle_view(world, unit.pos, world.player)
    return view if view is not None and view["access"] != "hidden" else None


def _battle(ctx, world, unit, troops, x, y, w):
    """The battle on the stack's hex ("In battle: ..."), and the stack's standing order: what it does when it is attacked
    and given no order. The order is shown only; the toggle waits for the battle panel (PR 7, its press action)."""
    view = _battle_of(world, unit)
    in_battle = view is not None and unit.owner in view["sides"]["attacker"] + view["sides"]["defender"]
    own = bool(troops) and unit.owner == world.player
    if not (in_battle or own):
        return y
    if in_battle:
        ctx.text(ctx.small, f"In battle: {view['name']}", (x, y), GOLD, w)
        y += 17
    if own:
        ctx.text(ctx.small, "If attacked with no order: " + STANDING.get(unit.standing, unit.standing), (x, y), MUTED, w)
        y += 17
    return y + 6


SUPPLY_COLOUR = {"supplied": GOOD_C, "wagon": GOLD, "foraging": GOLD, "cut off": BAD_C}


def _supply_card(world, unit, limit):
    return ("Supply", [
        (f"Troops here eat {FOOD_PER_TROOP:g} grain each a season, bought on the local market.", TEXT),
        ("Towns, castles and ports are depots. A stack within "
         f"{world.supply_reach(unit.owner)} hexes of one, through land you control, is in supply.", TEXT),
        ("Enemy armies cut supply lines. Cut-off troops lose 1 HP a season and cannot heal.", BAD_C),
        (f"This land feeds {limit} troops (people and farms; half in foreign land).", TEXT),
        ("Bigger stacks lose 1 HP a season. Wagons and foraging keep stacks fed.", MUTED)])


def _supply(ctx, world, unit, group, x, y, w):
    """The supply line of a land stack, its hover card and (when it is cut off) the Forage button."""
    state, count, limit = world.supply_state(group)
    text = {"supplied": f"In supply (a depot within {world.supply_reach(unit.owner)} hexes)",
            "wagon": "Fed by the supply wagon", "foraging": "Foraging this season",
            "cut off": "Cut off from supply: no healing, -1 HP a season"}[state]
    ctx.text(ctx.small, text, (x, y), SUPPLY_COLOUR[state], w - 130)
    ctx.text(ctx.small, f"land feeds {count}/{limit}", (x + w - 120, y), BAD_C if count > limit else MUTED)
    ctx.hoverable((x, y, w, 16), _supply_card(world, unit, limit))
    y += 20
    here = world.provinces.get(unit.pos)
    if unit.owner == world.player and (state == "cut off" or (state != "supplied" and here and here.owner != unit.owner)):
        ok, reason = world.forage_check(group, world.player)
        ctx.button((x, y, w, 24), "Forage the land", ok, ("forage",),
                   reason or "Feed the stack from this province: it loses people and half its goods", small=True)
        y += 28
    return y


def _foreign(ctx, group, x, y):
    for u in group[:14]:
        ctx.text(ctx.small, f"{u.label}   {u.men:,} men" if u.kind.war else u.label, (x, y), MUTED)
        y += 18


def _cargo(ctx, world, unit, x, y, w):
    ctx.text(ctx.font, f"Moves left {unit.moves_left}/{unit.kind.moves}", (x, y))
    y += 24
    cargo = world.cargo(unit)
    y = heading(ctx, f"Cargo {len(cargo)}/{unit.kind.capacity}", y)
    for passenger in cargo:
        ctx.button((x, y, w, 24), passenger.label, True, ("pick", passenger),
                   "Select it (tick more to land them together), then right-click the coast", small=True)
        y += 28
    if not cargo:
        ctx.text(ctx.small, "Empty. Units board by moving onto the ship from the coast.", (x, y), MUTED, w)


def _orders(ctx, world, ui, unit, group, x, y, w):
    """How to give orders, why the stack is stuck, the march button, Tick all / none and one row a unit."""
    ctx.text(ctx.small, "Ticked units move and fight together. Right-click to move or attack;", (x, y), MUTED, w)
    ctx.text(ctx.small, "right-click far away to march over several seasons.", (x, y + 15), MUTED, w)
    y += 36
    active = ctx.active()
    stuck = world.stuck_reason(active) if active else ""
    for line in wrap(ctx.small, stuck, w):
        ctx.text(ctx.small, line, (x, y), GOLD)
        y += 15
    if stuck:
        y += 6
    if any(ctx.is_marching(u) for u in active):
        ctx.text(ctx.small, "On a march: it waits for your order each season.", (x, y), GOLD, w)
        y += 16
        ctx.button((x, y, w, 26), "Continue march (R)", True, ("continue",),
                   "Walk on along the planned route (the dashed line)", small=True)
        y += 32
    ctx.button((x, y, 110, 22), "Tick all / none", True, ("all",), small=True)
    y += 28
    for u in group[:13]:
        _row(ctx, world, ui, unit, u, x, y, w)
        y += 26
    return y


def _row(ctx, world, ui, unit, u, x, y, w):
    """One unit of the stack: a tick box, its label (with a hover card) and, for troops, Refit and drill buttons."""
    ticked = u.id in ui.picked
    ctx.button((x, y, 22, 22), "x" if ticked else "", True, ("toggle", u),
               "Untick to leave this unit behind (split the stack)", small=True)
    label = u.label
    if u.kind.war:
        label += f"   {u.men:,} men"
    elif u.kind is GENERAL:
        label = f"General: {GENERAL_TRAITS[u.trait]}"
    color = TEXT if u.moves_left > 0 else MUTED
    if u.kind.war and not u.supplied:
        color = BAD_C
    ctx.text(ctx.small, label, (x + 28, y + 3), color, 196 if u.kind.war else w - 30)
    ctx.hoverable((x + 28, y, 196 if u.kind.war else w - 30, 22), unit_card(world, u))
    if u.kind.war:
        _drill_buttons(ctx, world, unit, u, x + w - 126, y)


def _drill_buttons(ctx, world, unit, u, bx, y):
    ok, reason = world.refit_check(u)
    if u.kind.era < world.countries[u.owner].era:
        ctx.button((bx, y, 52, 22), "Refit", ok, ("refit", u), reason or "Re-equip as the newest troops", small=True)
    for i, stat in enumerate(("attack", "defense")):
        ok, reason = world.upgrade_check(u, stat)
        level = u.atk_up if stat == "attack" else u.def_up
        if level < world.drill_max(unit.owner):
            cost = world.upgrade_cost(u, stat)
            ctx.button((bx + 56 + i * 36, y, 32, 22), "+A" if stat == "attack" else "+D", ok,
                       ("upgrade", u, stat), reason or f"Drill +1 {stat} for {cost} ducats", small=True)


def _found_buttons(ctx, world, x, y, w):
    """Found colony / Trading post for a ticked colonist."""
    workers = [u for u in ctx.active() if u.kind is COLONIST]
    if not workers:
        return
    worker = workers[0]
    y += 4
    ok, reason = world.found_check(worker)
    bw = (w - 6) // 2
    ctx.button((x, y, bw, 26), "Found colony (B)", ok, ("found", worker, False),
               reason or "Settlers take this land; it grows into a full province", small=True)
    ok, reason = world.found_check(worker, trading_post=True)
    ctx.button((x + bw + 6, y, bw, 26), "Trading post", ok, ("found", worker, True),
               reason or "Trade with the natives here: they keep the land, you get their goods", small=True)
