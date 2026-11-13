"""The battle panel (battle slice 1, PR 7): one battle as a window on the stack, over a shade of the map.

It is not opaque: the map shows under the shade, as for the pause menu. It opens from the press table (``("battle",
pos)``, see app.py) for a battle the player is a side of; a battle the player only watches is not opened (its log
tells the story). It shows the title and the ground, the front-line morale (a tug of war between the two sides), the
field (the back lines and reserves, the three lanes of each side, the front), the two sides with their men and losses,
the orders for this season (Attack, Hold, Withdraw, with the standing order when attacked), the last day's dice, and
the log.

It reads the battle only through ``battleview.battle_view`` and changes it only through the battle's own orders
(``world.battle_order``, ``world.standing_order``, each behind its ``*_check``). Countries' names and colours come from
the world's countries (the view gives tags); nothing else of the world is read. Where things go is screens/
battlelayout.py; the parts are drawn with ui/kit.py.

Keys: Esc closes; a right click or a click outside the panel closes too. The panel closes by itself when the battle
ends (the view is then None).
"""
import pygame

from .. import data
from ...ui import icons, kit
from ...ui.cache import BoundedCache
from ...ui.theme import FAINT, GOLD, INK, LINE, MUTED, PANEL_BG, TEXT, WARN_C
from .. import art
from ..battleview import battle_view
from . import Screen
from . import battlelayout as lay

FIGURE = 44                                   # the unit figure on a regiment card, in pixels
SHADE = (12, 14, 18, 170)                     # the map under the panel
STANCE_LABELS = (("attack", "Attack"), ("hold", "Hold"), ("withdraw", "Withdraw"))
STANDING_LABELS = (("hold", "Hold"), ("withdraw", "Withdraw"))
UNIT_KEY = {kind.name: key for key, kind in data.UNIT_KINDS.items()}      # the figure of a unit kind, by its name
_FIGURES = BoundedCache("battle_figure", 96)                              # (kind name, colour) -> figure surface
WHITE = (250, 248, 240)


def _pct(share):
    return f"{round(share * 100)}%"


def _ink_on(fill):
    """INK on a light fill, white on a dark one: the labels on the morale bar."""
    luminance = (0.299 * fill[0] + 0.587 * fill[1] + 0.114 * fill[2]) / 255
    return INK if luminance > 0.6 else WHITE


def _change(mult):
    """A damage multiplier as the panel says it: +20% or -10%."""
    pct = round((mult - 1) * 100)
    return f"{'+' if pct >= 0 else '-'}{abs(pct)}%"


def _stance_text(stance):
    """What a stance does, from data.STANCE (the damage it deals and takes)."""
    if stance == "withdraw":
        return "Withdraw: leave at the next day with half pursuit and keep your morale. Needs a retreat hex in reach."
    dealt, taken = data.STANCE[stance]
    if stance == "attack":
        return f"Attack: {_change(dealt)} damage dealt, {_change(taken)} taken. You lose more men both ways."
    return f"Hold: {_change(dealt)} damage dealt, {_change(taken)} taken. You lose fewer men."


def _figure(ctx, name, colour):
    key = UNIT_KEY.get(name, "pikemen")
    return _FIGURES.get((name, colour), lambda: art.figure(key, colour, FIGURE))


def _count(side):
    """Regiments a side has on the hex: its lanes, reserve, back line and routed ones."""
    return (sum(1 for lane in side["lanes"] if lane["id"] is not None) + len(side["reserve"])
            + len(side["back_line"]) + len(side["routed"]))


def _grid(side, back_first):
    """A side's regiments outside the lanes, as (regiment, group) pairs for the field's back grid. The enemy's grid has
    its back line on the outermost row (back_first); ours has its back line last, on the edge of the field."""
    back = [(unit, "back") for unit in side["back_line"]]
    reserve = [(unit, "reserve") for unit in side["reserve"]]
    routed = [(unit, "routed") for unit in side["routed"]]
    return back + reserve + routed if back_first else reserve + routed + back


def _ground(view):
    ground = view["ground"]
    parts = [ground["terrain"].capitalize() if ground["terrain"] else "Open country"]
    parts.append("wide front, 3 lanes" if ground["lanes"] >= 3 else f"narrow front, {ground['lanes']} lanes")
    if view["assault"]:
        parts.append(f"assault on a level {ground['castle']} castle")
    if view.get("crossing"):
        parts.append("across a pass")
    if view.get("uphill"):
        parts.append("uphill attack")
    return " · ".join(parts)


class BattleScreen(Screen):
    opaque = False

    def __init__(self):
        self.pos = None           # the hex of the battle on show (None: closed)
        self.buttons = []         # (rect, action, enabled, hint) of the last frame, for the clicks

    # ----- opening and closing ----------------------------------------------------------------------
    def open(self, ctx, pos):
        """Show the battle on ``pos``. Refuses (with a toast) when there is none or the player is not one of its sides."""
        view = battle_view(ctx.world, tuple(pos), ctx.player)
        if view is None:
            ctx.toast("That battle is over.")
            return False
        if view["viewer_role"] is None:
            ctx.toast("You only watch this battle: its log tells the story.")
            return False
        self.pos = tuple(pos)
        if self not in ctx.screens:
            ctx.screens.push(self)
        return True

    def close(self, ctx):
        self.pos = None
        ctx.screens.remove(self)

    def on_exit(self, ctx):
        self.buttons = []

    def _view(self, ctx):
        """The battle on show as the player sees it, or None: closed, over, or the player is no side of it any more."""
        if self.pos is None or ctx.player is None:
            return None
        view = battle_view(ctx.world, self.pos, ctx.player)
        return view if view is not None and view["viewer_role"] is not None else None

    def update(self, ctx, dt):
        if self.pos is not None and self._view(ctx) is None:
            self.close(ctx)                 # the battle ended (or the player is no side of it any more)

    # ----- input ------------------------------------------------------------------------------------
    def handle_event(self, ctx, event):
        """Every event while the panel is up is used here, so nothing reaches the map (the window handles F5, F9 and
        F11 first)."""
        if event.type == pygame.QUIT:
            ctx.running, ctx.result = False, "quit"
        elif event.type == pygame.KEYDOWN and event.key == pygame.K_ESCAPE:
            self.close(ctx)
        elif event.type == pygame.MOUSEMOTION:
            ctx.ui.mouse = event.pos
        elif event.type == pygame.MOUSEBUTTONDOWN and event.button in (1, 3):
            self._click(ctx, event)
        return True

    def _click(self, ctx, event):
        if event.button == 3:
            self.close(ctx)
            return
        view = self._view(ctx)
        if view is None:
            return
        for rect, action, enabled, hint in self.buttons:
            if rect.collidepoint(event.pos):
                if enabled:
                    self._press(ctx, action)
                elif hint:
                    ctx.toast(hint)
                return
        if not pygame.Rect(lay.panel(*ctx.screen.get_size())).collidepoint(event.pos):
            self.close(ctx)

    def _press(self, ctx, action):
        world, tag = ctx.world, ctx.player
        kind, value = action
        if kind == "close":
            self.close(ctx)
        elif kind == "stance":
            ok, reason = world.battle_order_check(self.pos, tag, value)
            if ok:
                world.battle_order(self.pos, tag, value)
            else:
                ctx.toast(reason)
        elif kind == "standing":
            ok, reason = world.standing_check(self.pos, tag, value)
            if ok:
                world.standing_order(self.pos, tag, value)
            else:
                ctx.toast(reason)

    # ----- drawing ----------------------------------------------------------------------------------
    def draw(self, ctx):
        self.buttons = []
        view = self._view(ctx)
        if view is None:
            return
        width, height = ctx.screen.get_size()
        kit.shade(ctx.screen, (0, 0, width, height), SHADE)
        frame = lay.panel(width, height)
        pygame.draw.rect(ctx.screen, PANEL_BG, frame, border_radius=10)
        pygame.draw.rect(ctx.screen, LINE, frame, 1, border_radius=10)
        self._header(ctx, view, frame)
        self._morale(ctx, view, frame)
        self._field(ctx, view, frame)
        self._side_column(ctx, view, frame)
        hover = ctx.ui.mouse
        for rect, action, enabled, hint in self.buttons:
            if not enabled and hint and rect.collidepoint(hover):
                kit.tip(ctx, hint)
                break

    def _header(self, ctx, view, frame):
        x, y, w, _ = frame
        close = lay.close_button(frame)
        ctx.text(ctx.big, view["name"], (x + lay.PAD, y + 10), TEXT, w - 420)
        ctx.text(ctx.font, _ground(view), (x + lay.PAD, y + 48), MUTED, w - 420)
        right = close[0] - 16
        kit.text(ctx.screen, ctx.small, f"Season {view['seasons']}  ·  {view['days']} days fought", (right, y + 16),
                 MUTED, align="right")
        timing = "Quick battles" if view["timing"] == "full" else "Clash"
        kit.text(ctx.screen, ctx.small, f"Timing: {timing}", (right, y + 36), MUTED, align="right")
        self._button(ctx, close, "Close", ("close", None), True)

    def _button(self, ctx, rect, label, action, enabled, hint=""):
        """A menu button of the panel: drawn, and its hit box kept for the clicks of this frame."""
        kit.menu_button(ctx, rect, label, enabled)
        self.buttons.append((pygame.Rect(rect), action, enabled, hint))

    def _morale(self, ctx, view, frame):
        x, y, w, _ = lay.morale(frame)
        left_tag, right_tag = view["sides"]["attacker"][0], view["sides"]["defender"][0]
        att, dfn = view["side"][left_tag], view["side"][right_tag]
        names = self._names(ctx, view)
        share = att["front_morale"] / (att["front_morale"] + dfn["front_morale"]) \
            if att["front_morale"] + dfn["front_morale"] > 0 else 0.5
        ctx.text(ctx.bold, "Front-line morale", (x + lay.PAD, y + 1), TEXT)
        kit.text(ctx.screen, ctx.small, f"breaks under {round(data.BREAK * 100)}%", (x + w - lay.PAD, y + 4), MUTED,
                 align="right")
        bar = pygame.Rect(x + lay.PAD, y + 24, w - 2 * lay.PAD, 19)
        left_colour, right_colour = self._colour(ctx, left_tag), self._colour(ctx, right_tag)
        kit.tug_bar(ctx.screen, bar, share, left_colour, right_colour)
        pygame.draw.line(ctx.screen, GOLD, (bar.centerx, bar.y - 3), (bar.centerx, bar.bottom + 2), 2)
        self._bar_label(ctx, (bar.x + 8, bar.y + 3), f"{names[left_tag]}  {_pct(att['front_morale'])}", left_colour,
                        "left")
        self._bar_label(ctx, (bar.right - 8, bar.y + 3), f"{_pct(dfn['front_morale'])}  {names[right_tag]}",
                        right_colour, "right")
        if bar.collidepoint(ctx.ui.mouse):
            kit.tip(ctx, f"The men-weighted morale of the lanes. A side breaks when its line breaks or falls under "
                         f"{round(data.BREAK * 100)}%.")

    def _bar_label(self, ctx, pos, text, fill, align):
        """A label on the morale bar over its side's fill: INK on a light fill, white on a dark one, 1 px shadow."""
        colour = _ink_on(fill)
        shadow = WHITE if colour == INK else INK
        kit.text(ctx.screen, ctx.small, text, (pos[0] + 1, pos[1] + 1), shadow, align=align)
        kit.text(ctx.screen, ctx.small, text, pos, colour, align=align)

    def _names(self, ctx, view):
        return {tag: (ctx.world.countries[tag].name if tag in ctx.world.countries else tag)
                for tag in view["side"]}

    def _colour(self, ctx, tag):
        country = ctx.world.countries.get(tag)
        return tuple(country.color) if country is not None else MUTED

    def _field(self, ctx, view, frame):
        ours = ctx.player
        enemy = next(tag for tag in view["side"] if tag != ours)
        mine, theirs = view["side"][ours], view["side"][enemy]
        top_units = _grid(theirs, back_first=True)
        bottom_units = _grid(mine, back_first=False)
        slots = lay.field_slots(frame, len(top_units), len(bottom_units))
        fx, fy, fw, fh = lay.field_rect(frame)
        pygame.draw.rect(ctx.screen, (19, 22, 28), (fx, fy, fw, fh), border_radius=8)
        pygame.draw.rect(ctx.screen, LINE, (fx, fy, fw, fh), 1, border_radius=8)
        names = self._names(ctx, view)
        self._side_label(ctx, (fx + 10, slots["labels"]["top"] + 2), names[enemy], self._colour(ctx, enemy),
                         "back line and reserve")
        for index, (regiment, group) in enumerate(top_units):
            self._regiment(ctx, slots["top"][index], regiment, group, enemy)
        castle = view["ground"]["castle"]
        self._lanes(ctx, slots["enemy"], theirs, enemy, slots["labels"]["enemy_lanes"], castle)
        self._front(ctx, slots, fx, fw, mine, theirs)
        self._lanes(ctx, slots["ours"], mine, ours, slots["labels"]["ours_lanes"], castle)
        self._side_label(ctx, (fx + 10, slots["labels"]["bottom"] + 2), names[ours], self._colour(ctx, ours),
                         "reserve and back line")
        for index, (regiment, group) in enumerate(bottom_units):
            self._regiment(ctx, slots["bottom"][index], regiment, group, ours)

    def _side_label(self, ctx, pos, name, colour, rest):
        """A field's label: the country's name in a light shade of its colour, the rest muted."""
        head = name.upper()
        ctx.text(ctx.small, head, pos, icons.shade(colour, 0.45))
        ctx.text(ctx.small, f"  {rest}", (pos[0] + ctx.small.size(head)[0], pos[1]), MUTED)

    def _lanes(self, ctx, rects, side, tag, label_y, castle=0):
        names = ("left flank", "centre", "right flank")
        colour = self._colour(ctx, tag)
        for index, lane in enumerate(side["lanes"]):
            x = rects[index][0]
            ctx.text(ctx.small, names[index], (x + 2, label_y + 2), FAINT)
            self._lane(ctx, rects[index], lane, colour, castle)

    def _lane(self, ctx, rect, lane, colour, castle):
        if not lane["open"]:
            kit.regiment_card(ctx, rect, None, "No lane", None, "Narrow ground", "", 0, 0, colour, tone="muted")
        elif lane["id"] is None:
            kit.regiment_card(ctx, rect, None, "Empty", None, "Waiting for a regiment", "", 0, 0, colour, tone="muted")
        elif lane["id"] == "garrison":
            full = data.GARRISON_MEN * data.GARRISON_HP * max(1, castle)
            kit.regiment_card(ctx, rect, _figure(ctx, "Garrison", colour), "Garrison", None, "Castle garrison",
                              f"{lane['men']:,} men", min(1.0, lane["men"] / full), lane["morale"] or 0, colour,
                              state_colour=WARN_C)
        else:
            state = "Lane broken" if lane["broken"] else "In the line"
            kit.regiment_card(ctx, rect, _figure(ctx, lane["kind"], colour), lane["kind"], lane["rank"], state,
                              f"{lane['men']:,} men", lane["men"] / data.MEN, lane["morale"] or 0, colour,
                              state_colour=WARN_C if lane["broken"] else None)

    def _regiment(self, ctx, rect, unit, group, tag):
        colour = self._colour(ctx, tag)
        state = {"back": "fires", "reserve": "RESERVE", "routed": "ROUTING"}[group]
        routed = group == "routed"
        kit.regiment_card(ctx, rect, _figure(ctx, unit["kind"], colour), unit["kind"], unit["rank"], state,
                          f"{unit['men']:,} men", unit["men"] / data.MEN, unit["morale"], colour,
                          tone="routing" if routed else "normal", state_colour=WARN_C if routed else None)

    def _front(self, ctx, slots, fx, fw, mine, theirs):
        y = slots["front"] + lay.FRONT_H // 2
        x = fx + 8
        while x < fx + fw - 8:                 # the dashed front line
            pygame.draw.line(ctx.screen, GOLD, (x, y), (min(x + 12, fx + fw - 8), y), 2)
            x += 20
        ctx.text(ctx.small, "front", (fx + fw - 44, y - 16), GOLD)
        for index in range(3):
            rect = slots["ours"][index]
            if mine["lanes"][index]["id"] is None or theirs["lanes"][index]["id"] is None:
                continue
            cx = rect[0] + rect[2] // 2
            pygame.draw.line(ctx.screen, TEXT, (cx - 7, y - 7), (cx + 7, y + 7), 2)   # crossed swords: a fight
            pygame.draw.line(ctx.screen, TEXT, (cx + 7, y - 7), (cx - 7, y + 7), 2)

    def _side_column(self, ctx, view, frame):
        x, y, w, h = lay.side_rect(frame)
        ours = ctx.player
        names = self._names(ctx, view)
        for tag in view["sides"]["attacker"] + view["sides"]["defender"]:
            y = self._side_block(ctx, x, y, w, tag, view["side"][tag], names[tag], tag == ours)
            y += 6
        y = self._orders(ctx, view, x, y + 4, w)
        y = self._dice(ctx, view, x, y + 6, w, names)
        self._log(ctx, view, x, y + 6, w, frame)

    def _side_block(self, ctx, x, y, w, tag, side, name, you):
        colour = self._colour(ctx, tag)
        pygame.draw.circle(ctx.screen, colour, (x + 8, y + 10), 7)
        pygame.draw.circle(ctx.screen, LINE, (x + 8, y + 10), 7, 1)
        ctx.text(ctx.bold, name + ("  (you)" if you else ""), (x + 22, y), TEXT, w - 22)
        general = f"General: {side['general']}" if side["general"] else "No general"
        ctx.text(ctx.small, f"{_count(side)} regiments  ·  {general}", (x + 22, y + 20), MUTED, w - 22)
        ctx.text(ctx.small, f"Men {side['men']:,} now, {side['start']:,} at the start", (x + 22, y + 36), TEXT, w - 22)
        ctx.text(ctx.small, f"Killed {side['killed']:,}  ·  wounded {side['wounded']:,}", (x + 22, y + 52), MUTED,
                 w - 22)
        return y + 72

    def _orders(self, ctx, view, x, y, w):
        ctx.text(ctx.bold, "Your orders this season", (x, y), GOLD, w)
        pygame.draw.line(ctx.screen, LINE, (x, y + 22), (x + w, y + 22))
        y += 30
        ours = view["side"][ctx.player]
        orders = ours["orders"] or {}
        stance = ours["stance"]
        for (tag, label), rect in zip(STANCE_LABELS, lay.split(x, y, w, 3, 30)):
            ok = orders.get(tag, {}).get("ok", False)
            kit.choice(ctx, rect, label, enabled=ok, selected=tag == stance)
            self.buttons.append((pygame.Rect(rect), ("stance", tag), ok, orders.get(tag, {}).get("reason", "")))
        y += 36
        for index, line in enumerate(kit.wrap(ctx.small, _stance_text(stance or "hold"), w)[:2]):
            ctx.text(ctx.small, line, (x, y + index * ctx.small.get_linesize()), MUTED, w)
        y += 46                                 # two lines of the hint, always: the stance changes its length
        ctx.text(ctx.small, "When attacked, with no order given:", (x, y), MUTED, w)
        y += 16
        standing = ours["standing"]
        for (tag, label), rect in zip(STANDING_LABELS, lay.split(x, y, w, 2, 26)):
            ok = orders.get("withdraw", {}).get("ok", False) if tag == "withdraw" else True
            reason = orders.get("withdraw", {}).get("reason", "") if tag == "withdraw" else ""
            kit.choice(ctx, rect, label, enabled=ok, selected=tag == standing)
            self.buttons.append((pygame.Rect(rect), ("standing", tag), ok, reason))
        return y + 34

    def _dice(self, ctx, view, x, y, w, names):
        ctx.text(ctx.bold, "Last day's dice", (x, y), GOLD, w)
        pygame.draw.line(ctx.screen, LINE, (x, y + 22), (x + w, y + 22))
        y += 30
        dice = view["dice"]
        if dice is None:
            ctx.text(ctx.small, "No day fought yet.", (x, y), MUTED, w)
            return y + 22
        half = w // 2
        for index, tag in enumerate(view["side"]):
            if tag not in dice["rolls"]:
                continue
            left = x + index * half
            kit.die(ctx.screen, (left, y, 36, 36), dice["rolls"][tag], edge=self._colour(ctx, tag))
            mult = dice["mult"].get(tag, 1.0)
            ctx.text(ctx.small, names[tag], (left + 44, y + 2), TEXT, half - 48)
            ctx.text(ctx.small, f"rolled {dice['rolls'][tag]}, x{mult:g}", (left + 44, y + 18), MUTED, half - 48)
        return y + 46

    def _log(self, ctx, view, x, y, w, frame):
        """The newest lines of the battle's log that fit, the newest at the bottom."""
        ctx.text(ctx.bold, "Battle log", (x, y), GOLD, w)
        pygame.draw.line(ctx.screen, LINE, (x, y + 22), (x + w, y + 22))
        y += 30
        _, top, _, height = lay.body(frame)
        line = ctx.small.get_linesize()
        max_lines = max(1, (top + height - 8 - y) // line)
        if not view["log"]:
            ctx.text(ctx.small, "Nothing has been fought yet.", (x, y), MUTED, w)
            return y
        blocks = []
        for entry in view["log"]:
            colour = WARN_C if entry["kind"] == "lane_broken" else TEXT
            blocks.append([(text_line, colour) for text_line in (kit.wrap(ctx.small, entry["text"], w - 4) or [""])])
        pos = y
        for text_line, colour in lay.last_lines(blocks, max_lines):
            ctx.text(ctx.small, text_line, (x, pos), colour, w)
            pos += line
        return pos
