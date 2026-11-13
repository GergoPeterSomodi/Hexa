"""Where the two stacks of a battle stand on its hex (battle slice 1, PR 6, spec 6.3): the attacker's stack a third of
half the hex radius to the left of the centre, the defender's to the right, so both show (a third of the radius was tried
first: the two figures overlapped on the map, see the PR 6 screenshots). Pygame-free: the map asks ``slot``
for the key each stack is drawn under and ``shift`` for its offset. Off a battle hex both answers are the plain ones, so
the map draws exactly what it drew before."""

SHARE = 1 / 2       # of the hex radius: how far each side's stack stands from the centre of a battle hex


def slot(battle, pos, owner):
    """The key a stack of ``owner`` on ``pos`` is drawn under: ``(pos, "attacker")`` or ``(pos, "defender")`` when a
    battle is fought there and the owner is one of its sides, else ``(pos, None)``. ``battle`` is the state.Battle on
    ``pos`` or None."""
    if battle is None:
        return pos, None
    if owner == battle.attacker:
        return pos, "attacker"
    if owner == battle.defender:
        return pos, "defender"
    return pos, None


def shift(r, side):
    """The horizontal offset, in pixels, of a stack of ``side`` (see ``slot``) for a hex of radius ``r``."""
    if side == "attacker":
        return -SHARE * r
    if side == "defender":
        return SHARE * r
    return 0
