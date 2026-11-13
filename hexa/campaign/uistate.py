"""What the Age of Discovery window remembers between frames: the selection, the open panel, the route, the toast.

``UI`` is plain state (no pygame): the window, the panels, the HUD and the screens read and set it. ``hint_text`` is the
one line a toast shows for a greyed-out button's hint.
"""
from ..ui.theme import BAD_C


def hint_text(hint):
    """One line for a toast from a button hint: the hint itself, or for a (title, lines) hover card the first
    line in red (the reason it is greyed out), else the card's title."""
    if isinstance(hint, str):
        return hint
    title, lines = hint
    reason = next((text for text, color in lines if color == BAD_C), None)
    return reason or title


class UI:
    def __init__(self):
        self.selected = None        # the unit shown on top of the selected stack
        self.group = []             # every unit of the selected stack
        self.picked = set()         # ids of the units in it that will move (tick boxes)
        self.province = None
        self.panel = None           # province, unit, country, market, ledger
        self.country = None         # tag shown in the country panel
        self.market = None
        self.reach = {}
        self.attacks = {}
        self.hover = None
        self.mouse = (0, 0)
        self.buttons = []
        self.toast = ""
        self.toast_until = 0
        self.reach2 = {}
        self.stops = set()
        self.path = []
        self.path_key = None
        self.speed = 3
        self.first_moves = 3
        self.order_route = None     # route whose merchant orders are open in the market panel
        self.hoverables = []        # (rect, card) areas that show a hover card
        self.anim = None            # (unit ids, route, start ms) of a move being shown
        self.hover_key = None
        self.hover_since = 0
