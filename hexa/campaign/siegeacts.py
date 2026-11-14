"""The window's side of the sieges (release 0.2.2, design 4.5): what a right-click on a garrisoned castle does (Besiege, the
default, or Storm with Shift held), what the province panel's "Storm now" and relief line press, and the toasts for a
refused one. Each one is a ``*_check`` the world already has: the window asks it first, shows its reason when it says no,
and only then calls the action. Pygame-free: the window passes whether Shift is held.
"""
def stack_at(world, pos, tag):
    """The war units of country `tag` standing on hex pos (the besieger's stack of a running siege)."""
    return [u for u in world.units_at(pos) if u.owner == tag and u.kind.war]


def attack(ctx, group, pos, storm=False):
    """A right-click on an attack hex (ui.attacks): on a garrisoned castle, Besiege (no battle) by default and Storm when
    `storm` (Shift held: the assault battle, the garrison cut by the siege's progress). A refused siege or storm toasts its
    reason. Any other attack is the old one. True when the stack acted."""
    world = ctx.world
    if not world.besiege_target(group, pos):
        return world.attack_group(group, pos)
    if storm:
        ok, reason = world.storm_check(group, pos, stand=world.attack_options_group(group).get(pos))
        if not ok:
            ctx.toast(reason)
            return False
        return world.storm_group(group, pos)
    stand = world.attack_options_group(group).get(pos)
    ok, reason = world.besiege_check(group, pos, stand=stand)
    if not ok:
        ctx.toast(reason)
        return False
    return world.attack_group(group, pos)


def storm_now(ctx, pos):
    """The province panel's "Storm now": the player's stack on the besieged hex storms it now (the same battle as Storm)."""
    world = ctx.world
    units = stack_at(world, pos, ctx.player)
    ok, reason = world.storm_check(units, pos)
    if not ok:
        ctx.toast(reason or "No army of yours stands here")
        return False
    return world.storm_group(units, pos)


def relief(ctx, pos):
    """The defender's relief line: select one of its armies that can reach the besieged place (the army's hex is `pos`)."""
    units = stack_at(ctx.world, pos, ctx.player)
    if not units:
        ctx.toast("That army has moved on")
        return
    ctx.look_at(pos)
    ctx.select_unit(units[0])


def press(ctx, action):
    """The province panel's buttons: ("siege", "storm", hex) or ("siege", "relief", hex)."""
    if action[1] == "storm":
        storm_now(ctx, action[2])
    else:
        relief(ctx, action[2])
