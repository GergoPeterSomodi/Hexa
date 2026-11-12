"""The top bar, option A of docs/design/ui/02_topbar_before_after.png: one row of icon chips.

    [flag] Venice | ducats 3,548 (+45) | research 34/120 (+6) | provinces 34 (+1) | regiments 14 (-1) |
    merchants 2/3 (±0) | prestige 412 (+3) | horses 2.4 (+0.3) | gunpowder 3.1 (-0.2) | sun Summer 1481 |
    map modes (4 icons) | Menu | End season

A chip is an icon, the value and the change since the season began (``resources.snapshot``): green up, red down, grey
for no change. For the key goods (horses and gunpowder, the price at the capital's market) a rise is red: they cost
more. Hovering a chip shows its card: the season's income and spending lines and the one-off items (ducats), or the
one-off items of the resource, and the footer says what a click opens. A click opens that panel: ducats and prestige
the ledger, research the technology screen, provinces and regiments the country panel, merchants and goods the market.
The chips are buttons named by those panels ("Ledger", "Research", "Provinces", "Army", "Market", "Prestige"), so
the old Ledger and Market buttons are gone.

Narrow windows drop things in this order (``plan``): the key goods, then the changes (they stay in the cards), then
"End season" becomes "End", then chips from the right (prestige first). The map modes, the date, Menu and End stay.
"""
import pygame

from ...ui import kit
from ...ui.icons import icon
from ...ui.theme import BAD_C, BG, FAINT, GOLD, GOOD_C, LINE, MUTED, TEXT
from .. import resources
from ..data import date
from ..mapview import GOODS_VIEWS, MODES
from ..panels.country import research_line

# name, icon, button label, action, footer of the card
CHIPS = (
    ("ducats", "ducats", "Ledger", ("panel", "ledger"), "Click: the ledger"),
    ("research", "research", "Research", ("tech",), "Click: technology (T)"),
    ("provinces", "provinces", "Provinces", ("panel", "country"), "Click: your country"),
    ("regiments", "army", "Army", ("panel", "country"), "Click: your country"),
    ("merchants", "merchants", "Market", ("panel", "market"), "Click: the market"),
    ("prestige", "prestige", "Prestige", ("panel", "ledger"), "Click: the ledger"),
)
GOODS = (
    ("horses", "horses", "Horses", ("panel", "market"), "Click: the market"),
    ("gunpowder", "powder", "Gunpowder", ("panel", "market"), "Click: the market"),
)
TITLES = {"ducats": "Ducats", "research": "Research points", "provinces": "Provinces", "regiments": "Regiments",
          "merchants": "Merchants", "prestige": "Prestige", "horses": "Horses", "gunpowder": "Gunpowder"}
GROUPS = (("income", "Income"), ("spending", "Spending"), ("oneoff", "One-off this season"))
AGE = 400               # ms a reading is kept when nothing in the game said it changed
MODE_W = 28             # a map-mode button
GOODS_GAP = 8           # the rule before the key goods
END_W, END_SHORT_W, MENU_W = 120, 64, 64


# ----- the numbers -----------------------------------------------------------------------------------------------
def readings(ctx, hud):
    """(snapshot, expected) of the player: remembered until the tracker hears an event, the turn or the map changes
    (or AGE ms pass), so a frame does not count the whole country again."""
    world, tracker = ctx.world, ctx.game.tracker
    now = pygame.time.get_ticks()
    key = (tracker.stamp, world.version, world.turn, world.player)
    found = hud.readings
    if found is None or found[0] != key or now - found[1] > AGE:
        found = hud.readings = (key, now, tracker.snapshot(world.player), resources.expected(world, world.player))
    return found[2], found[3]


def amount(value):
    """A signed amount: whole numbers plain, others with one decimal."""
    return f"{value:+,.0f}" if abs(value - round(value)) < 0.05 else f"{value:+,.1f}"


def change(name, reading, whole):
    """(text, colour) of a chip's change. Money and counts show whole numbers; research is what was gained (the
    points a finished technology cost are not a loss); a rise in a key good's price is red."""
    delta = reading.delta
    if name == "research":
        delta = round(delta - sum(line.amount for line in reading.lines if line.group == "oneoff"), 2)
    if whole:
        delta = round(delta)
    if abs(delta) < 0.05:
        return "(±0)", FAINT
    rising = delta > 0
    text = f"({delta:+,.0f})" if whole else f"({delta:+,.1f})"
    return text, (BAD_C if rising else GOOD_C) if name in resources.KEY_GOODS else (GOOD_C if rising else BAD_C)


def value_text(world, name, reading, snap):
    value = reading.value
    if name == "ducats":
        return f"{value:,.0f}"
    if name == "research":
        country = world.countries[world.player]
        cost = world.tech_cost(world.player, country.researching) if country.researching else 0
        return f"{int(value)}/{cost}" if cost else f"{int(value)}"
    if name == "merchants":
        return f"{value}/{snap['merchants_total'].value}"
    if name in resources.KEY_GOODS:
        return f"{value:.1f}"
    return f"{value:,}"


# ----- the hover cards -------------------------------------------------------------------------------------------
def lines_of(reading, groups=GROUPS):
    """The card's lines for the ducats-style groups of a reading, with rules between them."""
    out = []
    for group, title in groups:
        rows = [line for line in reading.lines if line.group == group]
        if rows:
            out += ([("", None)] if out else []) + [(title, GOLD)]
            out += [(f"{line.label}\t{amount(line.amount)}", (MUTED, GOOD_C if line.amount > 0 else BAD_C))
                    for line in rows]
    return out


def card(ctx, name, snap, expected, footer):
    """The hover card of a chip: (title, lines) for ``kit.hover_card``."""
    world = ctx.world
    reading = snap[name]
    since = date(ctx.game.tracker.season).split()[0].lower()
    delta_text = change(name, reading, whole_numbers(name))[0].strip("()")
    shown = value_text(world, name, reading, snap)
    if name in resources.KEY_GOODS:
        title = f"{TITLES[name]}  {shown}   ({delta_text} since {since})"
        lines = [("The price at your capital's market.", MUTED), ("A rise costs you more.", MUTED)]
    elif name == "merchants":
        title = f"Merchants  {shown}   (busy / all)"
        lines = [(f"Busy on a route\t{reading.value}", (MUTED, TEXT)),
                 (f"All of them\t{snap['merchants_total'].value}", (MUTED, TEXT))]
    elif name == "prestige":
        title = f"Prestige  {shown}   ({delta_text} since {since})"
        lines = [("Your score in the ledger.", MUTED)]
    else:
        title = f"{TITLES[name]}  {shown}   ({delta_text} since {since})"
        lines = lines_of(reading)
        if name == "ducats" and lines:
            lines += [("", None), (f"Change since {since}\t{amount(reading.delta)}",
                                   (TEXT, GOOD_C if reading.delta >= 0 else BAD_C))]
        elif name == "ducats":
            lines = [("Nothing was collected yet: play a season.", MUTED)]
        if name == "research":
            lines += [("", None)] if lines else []
            lines.append((research_line(world), MUTED))
    lines.append(("", None))
    lines.append((_footer(name, expected, footer), FAINT))
    return title, lines


def _footer(name, expected, click):
    if name == "ducats":
        return f"Next season, expected: {amount(expected['ducats'])}  ·  {click}"
    if name == "research":
        return f"Next season: {expected['research']:+.1f} points  ·  {click}"
    return click


# ----- the bar ---------------------------------------------------------------------------------------------------
class Row:
    """One chip of the bar: what it says now (`value`, `delta`) and what it opens."""

    def __init__(self, ctx, spec, snap):
        self.spec, self.name, self.main = spec, spec[0], spec in CHIPS
        reading = snap[self.name]
        self.value = value_text(ctx.world, self.name, reading, snap)
        self.delta, self.colour = change(self.name, reading, whole_numbers(self.name))

    def width(self, ctx, deltas):
        """The chip's width, and the two pixels after it."""
        return kit.chip_width(ctx, self.value, self.delta if deltas else "", not self.main) + 2


def whole_numbers(name):
    return name not in resources.KEY_GOODS and name != "research"


def plan(ctx, rows, room_for):
    """How much of the bar fits: (key goods shown, changes shown, "End season" wide, how many main chips).

    The key goods go first, then the changes (they stay in the cards), then "End season" shortens to "End", then
    chips go from the right. `room_for(wide)` is the pixels the chips may use with the wide or the short End."""
    main = [r for r in rows if r.main]
    goods = [r for r in rows if not r.main]
    for show_goods, deltas, wide in ((True, True, True), (False, True, True), (False, False, True),
                                     (False, False, False)):
        used = sum(r.width(ctx, deltas) for r in main)
        if show_goods:
            used += sum(r.width(ctx, deltas) for r in goods) + GOODS_GAP
        if used <= room_for(wide):
            return show_goods, deltas, wide, len(main)
    count = len(main)
    while count > 1 and sum(r.width(ctx, False) for r in main[:count]) > room_for(False):
        count -= 1
    return False, False, False, count


def layout(ctx, rows, x, width):
    """``plan`` for chips that start at `x` in a window `width` wide: what the date, the map modes, Menu and End
    leave them."""
    after = 6 + 8 + 22 + ctx.bold.size(ctx.world.date())[0] + 10 + len(MODES) * (MODE_W + 2) + 4 + MENU_W + 6 + 10
    return plan(ctx, rows, lambda wide: width - x - after - (END_W if wide else END_SHORT_W))


def draw(ctx, hud):
    """Draw the top bar and register its buttons."""
    world, screen = ctx.world, ctx.screen
    view = ctx.view_rect()
    top, width = view.y, view.right
    pygame.draw.rect(screen, BG, (0, 0, width, top))
    pygame.draw.line(screen, LINE, (0, top - 1), (width, top - 1))
    x, shown, deltas, wide = 12, [], False, True
    if world.player:
        snap, expected = readings(ctx, hud)
        x = _country(ctx, x)
        rows = [Row(ctx, spec, snap) for spec in CHIPS + GOODS]
        goods, deltas, wide, count = layout(ctx, rows, x, width)
        shown = [r for r in rows if r.main][:count] + ([r for r in rows if not r.main] if goods else [])
        x = _draw_chips(ctx, x, shown, deltas, snap, expected) + 6
    x = _date_and_modes(ctx, x, top)
    _right(ctx, width, END_W if wide else END_SHORT_W)


def _country(ctx, x):
    """The country's colour square (it opens the country panel) and name; returns the x after them."""
    world, screen = ctx.world, ctx.screen
    country = world.countries[world.player]
    pygame.draw.rect(screen, country.color, (x, 12, 22, 22), border_radius=3)
    pygame.draw.rect(screen, (10, 10, 10), (x, 12, 22, 22), 1, border_radius=3)
    kit.button(ctx, (x - 2, 8, 28, 30), "", True, ("panel", "country"), "Your country: income, taxes, diplomacy (C)")
    pygame.draw.rect(screen, country.color, (x, 12, 22, 22), border_radius=3)
    x += 30
    return x + ctx.text(ctx.title, country.name, (x, 10)) + 16


def _draw_chips(ctx, x, rows, deltas, snap, expected):
    """Draw the chips from `x`; the hovered one gets its hover card as the hint. Returns the x after the last."""
    mouse = ctx.ui.mouse
    for row in rows:
        if row.name == "horses":                    # a rule before the key goods
            pygame.draw.line(ctx.screen, LINE, (x + 2, 10), (x + 2, 36))
            x += GOODS_GAP
        name, glyph, label, action, footer = row.spec
        rect = pygame.Rect(x, 8, row.width(ctx, deltas) - 2, 30)
        hint = card(ctx, name, snap, expected, footer) if rect.collidepoint(mouse) else ""
        kit.chip(ctx, rect, glyph, row.value, row.delta if deltas else "", row.colour, label, action, hint,
                 not row.main)
        x = rect.right + 2
    return x


def _date_and_modes(ctx, x, top):
    """A rule, the season's icon and date, then the map-mode buttons (and the goods views under "goods")."""
    world, screen, view = ctx.world, ctx.screen, ctx.view
    pygame.draw.line(screen, LINE, (x, 10), (x, 36))
    x += 8
    glyph = icon("snow" if world.winter() else "sun", 18)
    screen.blit(glyph, glyph.get_rect(midleft=(x, 23)))
    x += 22 + ctx.text(ctx.bold, world.date(), (x + 22, 14)) + 10
    for i, mode in enumerate(MODES):
        r = kit.icon_button(ctx, (x, 9, MODE_W, 28), mode, mode.title(), ("mode", mode),
                            f"{mode.title()} map ({i + 1})", view.mode == mode)
        if mode == "goods" and view.mode == "goods":
            _goods_views(ctx, r, top)
        x += MODE_W + 2
    return x


def _goods_views(ctx, anchor, top):
    """The three views of the goods map, in a row under the goods button; the row moves left, never into the open
    side panel (its clicks are the panel's), and is left out when it cannot fit."""
    hints = {"chips": "What each tile makes", "deposits": "The goods as little objects on the land",
             "prices": "Today's price: green cheap, red dear (press 3 again to switch)"}
    widths = [ctx.small.size(name.title())[0] + 12 for name in GOODS_VIEWS]
    limit = (ctx.panel_rect().x if ctx.ui.panel else ctx.view_rect().right) - 8
    total = sum(widths) + 3 * (len(widths) - 1)
    if limit - total < 4:
        return
    sx = max(4, min(anchor.x, limit - total))
    for name, w in zip(GOODS_VIEWS, widths):
        b = kit.button(ctx, (sx, top + 4, w, 22), name.title(), True, ("goods_view", name), hints[name], small=True)
        if ctx.view.goods_view == name:
            pygame.draw.rect(ctx.screen, GOLD, b, 1, border_radius=5)
        sx += w + 3


def _right(ctx, width, end_w):
    """Menu, and End season at the edge when a country is chosen."""
    world = ctx.world
    if world.player:
        kit.button(ctx, (width - end_w - 10, 7, end_w, 32), "End season" if end_w >= 110 else "End",
                   not ctx.busy and not world.over, ("end",), "Let the season pass (Space)")
        menu_x = width - 10 - end_w - 6 - MENU_W
    else:
        menu_x = width - 80
    kit.button(ctx, (menu_x, 10, MENU_W, 26), "Menu", True, ("game_menu",), "Save, load, options and exit (Esc)",
               small=True)
