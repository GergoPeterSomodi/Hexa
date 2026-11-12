"""The look of the six kinds of event, shared by the floating ribbons and the action log: a colour and an icon each.

The kinds are those of ``feed.COLOUR_KINDS``: war red, siege amber, gains gold, own actions green, losses rose, others
white (docs/design/ui/README.md, section 3).
"""
from ..feed import COLOUR_KINDS

KINDS = {
    "war": ((255, 96, 74), "army"),
    "siege": ((255, 168, 60), "castle"),
    "gain": ((255, 214, 70), "ducats"),
    "own": ((128, 228, 110), "check"),
    "loss": ((235, 120, 170), "down"),
    "other": ((242, 240, 232), "flag"),
}
assert tuple(KINDS) == COLOUR_KINDS, "a colour kind of the feed has no look"


def colour(kind):
    """The RGB colour of a feed colour kind."""
    return KINDS[kind][0]


def glyph(kind):
    """The icon name (hexa/ui/icons.py) of a feed colour kind."""
    return KINDS[kind][1]
