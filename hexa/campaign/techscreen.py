"""The technology screen (T) and the new-age idea pick: a mixin for CampaignApp.

The screen covers the window: a top bar (research per season and its parts, Fund research, Close),
a strip with the current research and its queue, the grid (4 branch rows x 3 age columns) and a side
card for the selected tech. The idea modal sits over the map while the player has pending idea cards.
"""
import math

import pygame

from ..ui.kit import flat_button, shade, text as _text, wrap as _wrap
from ..ui.theme import (font as _font, TECH_BAR as BAR, TECH_BG as BG, TECH_BUTTON as BUTTON, TECH_BUTTON_HOT as BUTTON_HOT,
                        TECH_DARK_INK as DARK_INK, TECH_FAINT as FAINT,
                        TECH_GOLD as GOLD, TECH_GREEN as GREEN, TECH_LINE as LINE, TECH_MUTED as MUTED,
                        TECH_PANEL as PANEL, TECH_QUEUE_TEXT as QUEUE_TEXT, TECH_RED as RED, TECH_TEXT as TEXT,
                        TECH_WHITE as WHITE)
from . import tech
from .data import BRANCHES, ERAS, RESEARCH_FUND, troop

TOP_H = 50          # top bar
STRIP_H = 64        # research strip
HEAD_H = 66         # era headers (fixed while the grid scrolls)
NODE_H = 54
NODE_GAP = 8
BRANCH_GAP = 12
LABEL_W = 104       # branch labels on the left of the grid
BLOCK_H = 2 * NODE_H + NODE_GAP + BRANCH_GAP

BRANCH_COLOUR = {"military": (196, 72, 64), "trade": (206, 160, 52),
                 "navigation": (62, 130, 204), "statecraft": (146, 98, 198)}
BRANCH_ICON = {"military": "pike", "trade": "scale", "navigation": "compass", "statecraft": "crown"}
ROMAN = {1: "I", 2: "II", 3: "III"}
# fill, border, border width for each node state
STATE_STYLE = {
    "known": ((31, 50, 40), (80, 170, 100), 2),
    "researching": ((58, 48, 22), GOLD, 2),
    "queued": ((40, 42, 30), (170, 140, 60), 1),
    "available": ((36, 40, 49), (110, 118, 132), 1),
    "blocked": ((30, 30, 36), (84, 60, 60), 1),
    "later": ((26, 29, 35), (46, 51, 62), 1),
}


# ----------------------------------------------------------------- small helpers

def _mix(a, b, f):
    return tuple(int(x + (y - x) * f) for x, y in zip(a, b))


def _join(words):
    if len(words) <= 1:
        return "".join(words)
    return ", ".join(words[:-1]) + " and " + words[-1]


def _idea(key):
    if key in tech.IDEAS:
        return tech.IDEAS[key]
    return next((i for lst in tech.NATIONAL_IDEAS.values() for i in lst if i.key == key), None)


def _glyph(surf, icon, x, y, s):
    """A simple white glyph centred on (x, y), sized by s (about 0.3 of a 30 px tile)."""
    c = WHITE
    w = max(1, round(s * 0.2))

    def p(dx, dy):
        return (round(x + dx * s), round(y + dy * s))

    def line(pts, width=None):
        pygame.draw.lines(surf, c, False, pts, width or w)

    def poly(pts, colour=c):
        pygame.draw.polygon(surf, colour, pts)

    def rect(dx, dy, dw, dh, colour=c):
        pygame.draw.rect(surf, colour, pygame.Rect(round(x + dx * s), round(y + dy * s),
                                                   max(1, round(dw * s)), max(1, round(dh * s))))

    def circle(dx, dy, r, fill=True):
        pygame.draw.circle(surf, c, p(dx, dy), max(1, round(r * s)), 0 if fill else max(1, w))

    if icon == "drill":
        line([p(-1, -1), p(1, 1)], w + 1)
        line([p(1, -1), p(-1, 1)], w + 1)
    elif icon == "wagon":
        rect(-1, -0.5, 2, 1.0)
        circle(-0.6, 0.8, 0.35)
        circle(0.6, 0.8, 0.35)
    elif icon == "cannon":
        rect(-1, -0.5, 2, 0.7)
        circle(-0.5, 0.5, 0.4)
        circle(0.5, 0.5, 0.4)
    elif icon == "pike":
        line([p(0, -1.1), p(0, 1)], w)
        poly([p(0, -1.2), p(0.4, -0.6), p(-0.4, -0.6)])
    elif icon == "flag":
        line([p(-0.7, -1), p(-0.7, 1)], w)
        poly([p(-0.7, -1), p(1, -0.6), p(-0.7, -0.1)])
    elif icon == "castle":
        rect(-0.8, -0.3, 1.6, 1.3)
        rect(-0.8, -0.8, 0.4, 0.5)
        rect(0.4, -0.8, 0.4, 0.5)
    elif icon == "musket":
        line([p(-1, 0.8), p(1, -0.8)], w + 1)
        rect(-1.2, 0.5, 0.6, 0.5)
    elif icon == "star":
        pts = []
        for k in range(10):
            ang = -math.pi / 2 + k * math.pi / 5
            rr = 1.0 if k % 2 == 0 else 0.45
            pts.append(p(math.cos(ang) * rr, math.sin(ang) * rr))
        poly(pts)
    elif icon == "barrel":
        rect(-0.7, -1, 1.4, 2)
        line([p(-0.7, -0.4), p(0.7, -0.4)], 1)
        line([p(-0.7, 0.4), p(0.7, 0.4)], 1)
    elif icon == "crown":
        poly([p(-1, 0.6), p(-1, -0.2), p(-0.5, 0.1), p(0, -0.7), p(0.5, 0.1), p(1, -0.2), p(1, 0.6)])
        rect(-1, 0.6, 2, 0.3)
    elif icon == "guild":
        rect(-0.9, -1, 1.8, 0.7)
        line([p(0, -0.3), p(0, 1)], w + 1)
    elif icon == "scale":
        line([p(-1, -0.5), p(1, -0.5)], w)
        line([p(0, -1), p(0, 1)], w)
        circle(-0.7, 0.2, 0.35)
        circle(0.7, 0.2, 0.35)
    elif icon == "wheat":
        line([p(0, 1), p(0, -1)], w)
        for k in (-0.6, 0.0, 0.6):
            poly([p(0, k), p(0.5, k - 0.3), p(0, k - 0.5)])
            poly([p(0, k), p(-0.5, k - 0.3), p(0, k - 0.5)])
    elif icon == "rope":
        circle(0, 0, 0.9, False)
        circle(0, 0, 0.5, False)
    elif icon == "bank":
        poly([p(-1, -0.3), p(0, -1), p(1, -0.3)])
        rect(-1, -0.3, 2, 0.2)
        for dx in (-0.6, -0.2, 0.2, 0.6):
            rect(dx - 0.08, -0.1, 0.16, 1.0)
        rect(-1, 0.9, 2, 0.2)
    elif icon == "coin":
        circle(0, 0, 1.0, False)
        circle(0, 0, 0.45)
    elif icon == "powder":
        circle(-0.5, 0.4, 0.4)
        circle(0.5, 0.4, 0.4)
        circle(0, -0.4, 0.4)
    elif icon == "glass":
        poly([p(-1, -1), p(1, -1), p(0.2, 0.1), p(-0.2, 0.1)])
        line([p(0, 0.1), p(0, 1)], w)
        line([p(-0.5, 1), p(0.5, 1)], w)
    elif icon == "scroll":
        rect(-0.8, -1, 1.6, 2)
        for dy in (-0.5, 0.0, 0.5):
            pygame.draw.line(surf, DARK_INK, p(-0.5, dy), p(0.5, dy), 1)
    elif icon == "cup":
        poly([p(-1, -0.5), p(1, -0.5), p(0.6, 0.6), p(-0.6, 0.6)])
        circle(1, 0, 0.3, False)
        rect(-0.8, 0.6, 1.6, 0.25)
    elif icon == "chart":
        line([p(-1, 0.8), p(-0.3, -0.1), p(0.2, 0.3), p(1, -0.8)], w + 1)
        line([p(-1, -1), p(-1, 1), p(1, 1)], 1)
    elif icon in ("ship", "galleon"):
        poly([p(-1, 0.3), p(1, 0.3), p(0.6, 0.9), p(-0.6, 0.9)])
        line([p(0, 0.3), p(0, -1)], w)
        poly([p(0.1, -0.9), p(0.9, -0.2), p(0.1, -0.2)])
        if icon == "galleon":
            line([p(-0.5, 0.3), p(-0.5, -0.6)], w)
            poly([p(-0.4, -0.6), p(-0.9, -0.1), p(-0.4, -0.1)])
    elif icon == "compass":
        circle(0, 0, 1.0, False)
        poly([p(0, -0.7), p(0.35, 0), p(0, 0.7), p(-0.35, 0)])
    elif icon == "globe":
        circle(0, 0, 1.0, False)
        pygame.draw.ellipse(surf, c, pygame.Rect(round(x - 0.45 * s), round(y - s),
                                                 round(0.9 * s), round(2 * s)), w)
        line([p(-1, 0), p(1, 0)], 1)
    elif icon == "plant":
        line([p(0, 1), p(0, -0.2)], w)
        poly([p(0, 0.2), p(-0.9, -0.2), p(-0.5, -0.8), p(0, -0.3)])
        poly([p(0, -0.2), p(0.9, -0.6), p(0.5, -1), p(0, -0.6)])
    elif icon == "map":
        poly([p(-1, -0.8), p(-0.35, -1), p(0.35, -0.8), p(1, -1), p(1, 0.8), p(0.35, 1),
              p(-0.35, 0.8), p(-1, 1)])
    elif icon == "factory":
        rect(-1, -0.2, 2, 1.2)
        poly([p(-1, -0.2), p(-0.5, -0.9), p(-0.5, -0.2), p(0, -0.9), p(0, -0.2), p(0.5, -0.9), p(0.5, -0.2)])
    elif icon == "press":
        rect(-0.9, -0.2, 1.8, 1.1)
        rect(-1, -1, 2, 0.3)
        line([p(0, -0.7), p(0, -0.2)], w + 1)
    elif icon == "book":
        poly([p(-1, -0.7), p(-0.1, -0.5), p(-0.1, 0.9), p(-1, 0.7)])
        poly([p(1, -0.7), p(0.1, -0.5), p(0.1, 0.9), p(1, 0.7)])
    else:
        circle(0, 0, 0.6)


def _tile(surf, rect, colour, icon):
    radius = max(4, rect.w // 5)
    pygame.draw.rect(surf, colour, rect, border_radius=radius)
    pygame.draw.rect(surf, _mix(colour, (0, 0, 0), 0.35), rect, 1, border_radius=radius)
    _glyph(surf, icon, rect.centerx, rect.centery, rect.w * 0.3)


def _dashed(surf, colour, pts, width):
    for (x1, y1), (x2, y2) in zip(pts, pts[1:]):
        length = math.hypot(x2 - x1, y2 - y1)
        if length == 0:
            continue
        steps = int(length // 9) + 1
        for i in range(steps):
            t0 = i * 9 / length
            t1 = min(1.0, (i * 9 + 5) / length)
            if t0 >= 1:
                break
            pygame.draw.line(surf, colour,
                             (round(x1 + (x2 - x1) * t0), round(y1 + (y2 - y1) * t0)),
                             (round(x1 + (x2 - x1) * t1), round(y1 + (y2 - y1) * t1)), width)


class TechScreen:
    tech_open = False
    tech_selected = None      # key of the tech shown in the side card
    tech_scroll = 0           # pixels the grid body is scrolled down
    tech_buttons = ()         # (screen rect, action) for every clickable thing drawn last frame

    # ----- state ------------------------------------------------------------------------
    def idea_pending(self):
        """The idea card keys the player has to choose from now (empty when none)."""
        if not self.player:
            return []
        return list(self.world.countries[self.player].pending_ideas)

    def open_tech(self):
        if not self.player:
            return
        country = self.world.countries[self.player]
        self.tech_open = True
        self.tech_scroll = 0
        if self.tech_selected is None:
            self.tech_selected = country.researching or None

    def close_tech(self):
        self.tech_open = False

    def tech_toggle(self):
        if self.tech_open:
            self.close_tech()
        else:
            self.open_tech()

    # ----- input ------------------------------------------------------------------------
    def tech_handle(self, event):
        """Every event while the tech screen or an idea modal is up. Nothing reaches the map."""
        if event.type == pygame.QUIT:
            self.running, self.result = False, "quit"
            return
        pending = bool(self.idea_pending())
        if event.type == pygame.KEYDOWN and not pending:
            if event.key == pygame.K_ESCAPE:
                self.close_tech()
            elif event.key == pygame.K_t:
                self.tech_toggle()
        elif event.type == pygame.MOUSEMOTION:
            self.ui.mouse = event.pos
        elif event.type == pygame.MOUSEWHEEL and self.tech_open and not pending:
            self.tech_scroll = max(0, min(self._tech_max_scroll(), self.tech_scroll - event.y * 40))
        elif event.type == pygame.MOUSEBUTTONDOWN and event.button in (1, 3):
            for rect, action in reversed(self.tech_buttons):
                if rect.collidepoint(event.pos):
                    self.tech_press(action, event.button == 3)
                    return

    def tech_press(self, action, right=False):
        world, tag = self.world, self.player
        country = world.countries[tag]
        kind = action[0]
        if country.pending_ideas and kind != "pick":
            return                      # the idea pick comes first
        if kind == "close":
            self.close_tech()
        elif kind == "queue":
            if right:
                self._unqueue(action[1])
            else:
                self.tech_selected = action[1]
        elif kind == "node":
            if right:
                self._unqueue(action[1])
            else:
                self.tech_click(action[1])
        elif kind == "fund":
            ok, reason = world.fund_check(tag)
            if not ok:
                self.toast(reason)          # the reason is the button's hint
            elif not country.researching:
                self.toast("Pick a tech first: the points go to the tech being researched.")
            else:
                world.fund_research(tag)
        elif kind == "pick":
            idea = _idea(action[1])
            if world.pick_idea(tag, action[1]) and idea is not None:
                self.toast(f"Idea adopted: {idea.name}. {idea.text}")
            else:
                self.toast("That card is no longer on offer.")

    def tech_click(self, key):
        """Research a tech: set it as the current research (its unknown prerequisites queue first)."""
        world, tag = self.world, self.player
        country = world.countries[tag]
        t = tech.tech(key)
        self.tech_selected = key
        if t is None or key in country.techs:
            return
        if t.era > country.era:
            self.toast(f"{t.name} waits for the {ERAS[t.era][0]}.")
            return
        if world.set_research(tag, key):
            now = tech.tech(country.researching).name
            if country.queue:
                self.toast(f"Researching {now}, then {len(country.queue)} more in the queue.")
            else:
                self.toast(f"Researching {now}.")
        else:
            self.toast(f"{t.name} cannot be researched yet.")

    def _unqueue(self, key):
        t = tech.tech(key)
        if self.world.unqueue(self.player, key) and t is not None:
            self.toast(f"Removed {t.name} from the queue.")

    # ----- layout -----------------------------------------------------------------------
    def _tech_geometry(self):
        W, H = self.screen.get_size()
        side = max(270, min(340, int(W * 0.22)))
        left = W - side
        era_x = LABEL_W + 8
        era_w = (left - era_x - 6) // 3
        body_top = TOP_H + STRIP_H + HEAD_H + 4
        return {"W": W, "H": H, "side": side, "left": left, "era_x": era_x, "era_w": era_w,
                "body_top": body_top, "body_h": H - body_top}

    def _tech_max_scroll(self):
        return max(0, 4 * BLOCK_H - self._tech_geometry()["body_h"])

    def _tech_cells(self):
        """Techs per (branch, era) cell, with the national tech in its branch's era I cell."""
        country = self.world.countries[self.player]
        cells = {}
        for key, t in tech.TECHS.items():
            cells.setdefault((t.branch, t.era), []).append(key)
        nat = tech.tech(country.national) if country.national else None
        if nat is not None:
            cells.setdefault((nat.branch, 1), []).append(nat.key)
        return cells

    def _tech_nodes(self, geo):
        """Node rects in grid-body coordinates (before scrolling)."""
        rects = {}
        node_w = (geo["era_w"] - 14) // 2
        cells = self._tech_cells()
        for bi, branch in enumerate(tech.BRANCHES):
            top = bi * BLOCK_H
            for era in (1, 2, 3):
                for i, key in enumerate(cells.get((branch, era), [])):
                    x = geo["era_x"] + (era - 1) * geo["era_w"] + (i % 2) * (node_w + 6)
                    y = top + 6 + (i // 2) * (NODE_H + NODE_GAP)
                    rects[key] = pygame.Rect(x, y, node_w, NODE_H)
        return rects

    def _tech_state(self, key, country):
        t = tech.tech(key)
        if key in country.techs:
            return "known"
        if key == country.researching:
            return "researching"
        if key in country.queue:
            return "queued"
        if t.era > country.era:
            return "later"
        if all(n in country.techs for n in t.needs):
            return "available"
        return "blocked"

    def tech_order(self):
        """Position of each tech on the research path: 0 is the tech being researched, 1 and up the queue."""
        country = self.world.countries[self.player]
        order = {}
        if country.researching:
            order[country.researching] = 0
        for i, key in enumerate(country.queue):
            order.setdefault(key, i + 1)
        return order

    def _tech_cost(self, key):
        return self.world.tech_cost(self.player, key)

    def _who_has(self, key):
        """Names of the other countries that know the tech and that the player has explored."""
        world = self.world
        seen = world.countries[self.player].explored
        names = []
        for c in world.countries.values():
            if c.tag == self.player or not c.alive or key not in c.techs:
                continue
            if c.capital in seen:
                names.append(c.name)
        return names

    # ----- drawing ----------------------------------------------------------------------
    def draw_tech(self):
        """Called last in draw(): the screen when open, then the idea modal while cards are pending."""
        self.tech_buttons = []
        if self.tech_open:
            self._draw_tech_screen()
        if self.idea_pending():
            self._draw_idea_modal()

    def _draw_tech_screen(self):
        screen = self.screen
        geo = self._tech_geometry()
        country = self.world.countries[self.player]
        screen.fill(BG)
        self._draw_tech_topbar(geo, country)
        self._draw_tech_strip(geo, country)
        self._draw_tech_headers(geo, country)
        self._draw_tech_grid(geo, country)
        self._draw_tech_side(geo, country)
        self._draw_tech_toast(geo)

    def _tech_button(self, rect, label, action, enabled=True, detail=""):
        rect = flat_button(self.screen, rect, label, _font(13, True), _font(11), self.ui.mouse, enabled, detail)
        self.tech_buttons.append((rect, action))

    def _draw_tech_topbar(self, geo, country):
        screen, world, W = self.screen, self.world, geo["W"]
        pygame.draw.rect(screen, BAR, (0, 0, W, TOP_H))
        pygame.draw.line(screen, LINE, (0, TOP_H - 1), (W, TOP_H - 1))
        x = _text(screen, _font(22, True, True), "Technology", (14, 9), GOLD).right + 14
        sub = f"{country.name} · {world.date()} · {ERAS[country.era][0]}"
        x = _text(screen, _font(12), sub, (x, 19), MUTED).right + 16
        total, parts = world.research_rate(self.player)
        chips = [("Research", f"+{total:.1f} / season", GOLD), ("Base", f"{parts['base']:.1f}", TEXT),
                 ("Burghers", f"{parts['burghers']:.1f}", TEXT),
                 ("Universities", f"{parts['universities']:.1f}", TEXT)]
        if parts["coffee"] > 0.005:
            chips.append(("Coffee", f"{parts['coffee']:.1f}", TEXT))
        if parts["funding"] > 0.005:
            chips.append(("Funding", f"{parts['funding']:.1f}", TEXT))
        fund_x = W - 12 - 92 - 8 - 196
        for label, value, colour in chips:
            label_w = _font(11).size(label)[0]
            value_w = _font(12, True).size(value)[0]
            w = label_w + value_w + 24
            if x + w > fund_x - 10:
                break
            rect = pygame.Rect(x, 12, w, 26)
            pygame.draw.rect(screen, (36, 41, 52), rect, border_radius=6)
            _text(screen, _font(11), label, (x + 8, 18), MUTED)
            _text(screen, _font(12, True), value, (x + 14 + label_w, 17), colour)
            x += w + 6
        gold, points = RESEARCH_FUND
        points = points * (1 + world.bonus(self.player, "fund"))
        ok, _reason = world.fund_check(self.player)
        ok = ok and bool(country.researching)
        self._tech_button((fund_x, 10, 196, 30), f"Fund research +{points:.0f}", ("fund",), ok, f"{gold} ducats")
        self._tech_button((W - 12 - 92, 10, 92, 30), "Close (T)", ("close",))

    def _draw_tech_strip(self, geo, country):
        screen, world = self.screen, self.world
        left, y0 = geo["left"], TOP_H
        pygame.draw.rect(screen, PANEL, (0, y0, left, STRIP_H))
        pygame.draw.line(screen, LINE, (0, y0 + STRIP_H - 1), (left, y0 + STRIP_H - 1))
        if country.researching:
            t = tech.tech(country.researching)
            _tile(screen, pygame.Rect(14, y0 + 12, 40, 40), BRANCH_COLOUR[t.branch], t.icon)
            _text(screen, _font(10, True), "RESEARCHING", (64, y0 + 10), FAINT)
            _text(screen, _font(16, True), t.name, (64, y0 + 26), TEXT, width=165)
            cost = self._tech_cost(t.key)
            frac = min(1.0, country.research / cost) if cost else 1.0
            bar = pygame.Rect(240, y0 + 20, 150, 12)
            pygame.draw.rect(screen, (50, 55, 64), bar, border_radius=5)
            if frac > 0:
                pygame.draw.rect(screen, GOLD, pygame.Rect(bar.x, bar.y, max(6, int(bar.w * frac)), bar.h),
                                 border_radius=5)
            _text(screen, _font(13, True), f"{int(country.research)} / {cost}", (bar.right + 8, y0 + 17), GOLD)
            rate = world.research_rate(self.player)[0]
            if rate > 0:
                seasons = max(1, math.ceil(max(0, cost - country.research) / rate))
                when = f"about {seasons} season{'s' * (seasons != 1)}"
            else:
                when = "no research coming in"
            _text(screen, _font(11), when, (240, y0 + 38), MUTED)
        else:
            _text(screen, _font(14, True), "Nothing is being researched", (64, y0 + 14), GOLD)
            _text(screen, _font(11), "Click a technology in the grid to research it.", (64, y0 + 38), MUTED)
        qx = 480
        _text(screen, _font(10, True), "QUEUE", (qx, y0 + 8), FAINT)
        x, cy = qx + 52, y0 + 22
        shown = 0
        for key in country.queue:
            t = tech.tech(key)
            w = min(170, 34 + _font(11).size(t.name)[0])
            if x + w > left - 14:
                break
            rect = pygame.Rect(x, cy, w, 24)
            pygame.draw.rect(screen, (38, 44, 55), rect, border_radius=6)
            _tile(screen, pygame.Rect(x + 3, cy + 3, 18, 18), BRANCH_COLOUR[t.branch], t.icon)
            _text(screen, _font(11), t.name, (x + 26, cy + 6), TEXT, width=w - 30)
            self.tech_buttons.append((rect, ("queue", key)))
            x += w + 6
            shown += 1
        if shown < len(country.queue):
            _text(screen, _font(11), f"+{len(country.queue) - shown} more", (x, cy + 6), MUTED)
        elif not country.queue:
            _text(screen, _font(11), "empty", (x, cy + 6), FAINT)
        _text(screen, _font(11), "Click a far tech to queue its path. Right-click to remove.",
              (qx, y0 + STRIP_H - 16), FAINT)

    def _draw_tech_headers(self, geo, country):
        screen = self.screen
        y = TOP_H + STRIP_H
        pygame.draw.rect(screen, BG, (0, y, geo["left"], HEAD_H))
        pygame.draw.line(screen, LINE, (0, y + HEAD_H - 1), (geo["left"], y + HEAD_H - 1))
        for era in (1, 2, 3):
            x = geo["era_x"] + (era - 1) * geo["era_w"]
            if era > 1:
                pygame.draw.line(screen, LINE, (x - 5, y + 8), (x - 5, y + HEAD_H - 8))
            reached = era <= country.era
            _text(screen, _font(16, True, True), f"{ROMAN[era]}  {ERAS[era][0]}", (x + 4, y + 8),
                  TEXT if reached else MUTED, width=geo["era_w"] - 8)
            if reached:
                status, colour = f"reached {ERAS[era][1]}", MUTED
            else:
                have = sum(1 for k in country.techs if k in tech.TECHS and tech.TECHS[k].era == era - 1)
                status = f"{tech.ERA_YEARS[era]} · {have} of {tech.ERA_GATE_TECHS} era {ROMAN[era - 1]} techs"
                colour = GOLD if have >= tech.ERA_GATE_TECHS else RED
            _text(screen, _font(11), status, (x + 4, y + 30), colour, width=geo["era_w"] - 8)
            names = " · ".join(troop(b, era).name.lower() for b in BRANCHES)
            _text(screen, _font(11), "troops: " + names, (x + 4, y + 46), FAINT, width=geo["era_w"] - 8)

    def _draw_tech_grid(self, geo, country):
        screen = self.screen
        body = pygame.Rect(0, geo["body_top"], geo["left"], geo["body_h"])
        dy = geo["body_top"] - self.tech_scroll
        rects = self._tech_nodes(geo)
        screen.set_clip(body)
        for bi, branch in enumerate(tech.BRANCHES):
            y0 = bi * BLOCK_H + dy
            pygame.draw.rect(screen, BRANCH_COLOUR[branch], (0, y0 + 6, 3, BLOCK_H - 16))
            tag_y = y0 + 8
            pygame.draw.rect(screen, BRANCH_COLOUR[branch], (8, tag_y, 30, 30), border_radius=6)
            _glyph(screen, BRANCH_ICON[branch], 23, tag_y + 15, 9)
            lines = _wrap(_font(13, True), tech.BRANCH_NAMES[branch], LABEL_W - 12)
            for i, line in enumerate(lines):
                _text(screen, _font(13, True), line, (8, tag_y + 40 + i * 15), BRANCH_COLOUR[branch])
            total = sum(1 for t in tech.TECHS.values() if t.branch == branch)
            known = sum(1 for k, t in tech.TECHS.items() if t.branch == branch and k in country.techs)
            nat = tech.tech(country.national) if country.national else None
            if nat is not None and nat.branch == branch:
                total += 1
                known += 1 if nat.key in country.techs else 0
            _text(screen, _font(11), f"{known} / {total} known", (8, tag_y + 42 + len(lines) * 15), MUTED)
            if bi:
                pygame.draw.line(screen, LINE, (0, y0), (geo["left"], y0))
        # prerequisite lines first, so the cards cover their ends
        order = self.tech_order()
        for key, rect in rects.items():
            t = tech.tech(key)
            for need in t.needs:
                p = rects.get(need)
                if p is None:
                    continue
                a = p.move(0, dy)
                b = rect.move(0, dy)
                if b.left >= a.right + 4:
                    sx, sy, ex, ey = a.right, a.centery, b.left, b.centery
                    mid = (sx + ex) // 2
                    pts = [(sx, sy), (mid, sy), (mid, ey), (ex, ey)]
                elif b.top > a.top:
                    pts = [(a.centerx, a.bottom), (b.centerx, b.top)]
                else:
                    pts = [(a.centerx, a.top), (b.centerx, b.bottom)]
                cross = tech.tech(need).branch != t.branch
                if self.tech_selected in (key, need) or (key in order and need in order):
                    colour = GOLD           # the selected tech, and the path being researched
                elif need in country.techs and key in country.techs:
                    colour = (62, 124, 88)
                else:
                    colour = (78, 86, 100)
                if cross:
                    _dashed(screen, colour, pts, 2)
                else:
                    pygame.draw.lines(screen, colour, False, pts, 2)
        for key, rect in rects.items():
            state = self._tech_state(key, country)
            screen_rect = rect.move(0, dy)
            visible = screen_rect.clip(body)
            if visible.height > 0:
                self._draw_tech_node(screen_rect, key, state, country)
                self.tech_buttons.append((visible, ("node", key)))
        screen.set_clip(None)

    def _draw_tech_node(self, rect, key, state, country):
        screen, world = self.screen, self.world
        t = tech.tech(key)
        fill, border, width = STATE_STYLE[state]
        pygame.draw.rect(screen, fill, rect, border_radius=7)
        if key == self.tech_selected:
            pygame.draw.rect(screen, WHITE, rect.inflate(6, 6), 1, border_radius=9)
        pygame.draw.rect(screen, border, rect, width, border_radius=7)
        order = self.tech_order()
        if key in order:                    # the research path: a gold ring and its place in line
            pygame.draw.rect(screen, GOLD, rect.inflate(4, 4), 2, border_radius=9)
            label = "NOW" if order[key] == 0 else str(order[key])
            img = _font(11, True).render(label, True, DARK_INK)
            pill = pygame.Rect(0, 0, max(18, img.get_width() + 8), 16)
            pill.center = (rect.x + 4, rect.y + 2)
            pygame.draw.rect(screen, GOLD, pill, border_radius=8)
            screen.blit(img, img.get_rect(center=pill.center))
        col = BRANCH_COLOUR[t.branch]
        if state in ("blocked", "later"):
            col = _mix(col, (70, 74, 82), 0.6)
        _tile(screen, pygame.Rect(rect.x + 7, rect.y + (rect.h - 28) // 2, 28, 28), col, t.icon)
        tx = rect.x + 42
        name_c = TEXT if state in ("known", "researching", "queued", "available") else \
            MUTED if state == "blocked" else FAINT
        _text(screen, _font(13, True), t.name, (tx, rect.y + 6), name_c, width=rect.w - 52)
        desc_c = MUTED if state != "later" else FAINT
        if state == "researching":
            cost = self._tech_cost(key)
            frac = min(1.0, country.research / cost) if cost else 1.0
            bar = pygame.Rect(tx, rect.y + 25, rect.w - 52, 6)
            pygame.draw.rect(screen, (50, 55, 64), bar, border_radius=3)
            pygame.draw.rect(screen, GOLD, pygame.Rect(bar.x, bar.y, max(4, int(bar.w * frac)), bar.h),
                             border_radius=3)
        else:
            _text(screen, _font(11), t.text, (tx, rect.y + 22), desc_c, width=rect.w - 50)
        # battle cards: one small chip per card, bottom right (not drawn for ages not yet reached)
        chips = min(2, len(t.cards)) if state != "later" else 0
        for i in range(chips):
            cx = rect.right - 8 - (chips - i) * 10
            pygame.draw.rect(screen, (196, 160, 84), (cx, rect.bottom - 14, 7, 10), border_radius=2)
        room = rect.w - 42 - chips * 10 - 6
        y = rect.y + 36
        if state == "known":
            if t.national:
                nation = world.countries[t.national].name.upper() if t.national in world.countries else t.national
                label = _font(10, True).render(nation, True, GOLD)
                tag = pygame.Rect(tx, y - 1, label.get_width() + 10, 14)
                pygame.draw.rect(screen, (110, 88, 28), tag, border_radius=4)
                screen.blit(label, label.get_rect(center=tag.center))
            else:
                _text(screen, _font(11), "known", (tx, y), GREEN)
            rx, ry = rect.right - 12, rect.y + 11
            pygame.draw.lines(screen, GREEN, False, [(rx - 5, ry), (rx - 2, ry + 3), (rx + 4, ry - 4)], 2)
        elif state == "researching":
            _text(screen, _font(11, True), f"{int(country.research)} / {self._tech_cost(key)}", (tx, y), GOLD,
                  width=room)
        elif state == "queued":
            n = country.queue.index(key) + 1
            _text(screen, _font(11), f"queued #{n} · {self._tech_cost(key)} RP", (tx, y), QUEUE_TEXT, width=room)
        elif state == "available":
            _text(screen, _font(11), f"{self._tech_cost(key)} RP", (tx, y), MUTED, width=room)
        elif state == "blocked":
            missing = next(n for n in t.needs if n not in country.techs)
            _text(screen, _font(11, True), f"needs {tech.tech(missing).name}", (tx, y), RED, width=room)
        else:
            _text(screen, _font(11), f"{self._tech_cost(key)} RP", (tx, y), FAINT, width=room)

    def _draw_tech_side(self, geo, country):
        screen = self.screen
        rect = pygame.Rect(geo["left"], TOP_H, geo["side"], geo["H"] - TOP_H)
        pygame.draw.rect(screen, PANEL, rect)
        pygame.draw.line(screen, LINE, rect.topleft, rect.bottomleft)
        x, w = rect.x + 16, rect.w - 32
        legend_y = rect.bottom - 118
        pygame.draw.line(screen, LINE, (x, legend_y - 8), (rect.right - 16, legend_y - 8))
        t = tech.tech(self.tech_selected) if self.tech_selected else None
        y = rect.y + 14
        if t is None:
            for line in _wrap(_font(12), "Click a technology to read what it does, what it needs and what it leads to.", w):
                _text(screen, _font(12), line, (x, y), MUTED)
                y += 16
        else:
            state = self._tech_state(t.key, country)
            _tile(screen, pygame.Rect(x, y, 52, 52), BRANCH_COLOUR[t.branch], t.icon)
            tx = x + 62
            _text(screen, _font(20, True, True), t.name, (tx, y - 2), GOLD, width=w - 62)
            era = "national" if t.national else f"era {ROMAN[t.era]}"
            _text(screen, _font(12), f"{tech.BRANCH_NAMES[t.branch]} · {era}", (tx, y + 26), MUTED, width=w - 62)
            text, colour = self._tech_status(t, state, country)
            _text(screen, _font(12, True), text, (tx, y + 40), colour, width=w - 62)
            y += 66
            for line in _wrap(_font(12), t.flavour, w):
                _text(screen, _font(12), line, (x, y), FAINT)
                y += 16
            y += 8
            y = self._side_sections(rect, x, w, y, legend_y, t, country)
        self._draw_tech_legend(rect, legend_y)

    def _side_sections(self, rect, x, w, y, stop, t, country):
        screen = self.screen

        def heading(title, y):
            _text(screen, _font(11, True), title, (x, y), GOLD)
            pygame.draw.line(screen, LINE, (x, y + 16), (rect.right - 16, y + 16))
            return y + 22

        if y < stop - 40:
            y = heading("UNLOCKS", y)
            for line in _wrap(_font(12), t.text, w):
                _text(screen, _font(12), line, (x, y), TEXT)
                y += 16
            y += 10
        if y < stop - 40:
            y = heading("NEEDS", y)
            rows = [(tech.tech(n).name, n in country.techs, "known" if n in country.techs else "missing")
                    for n in t.needs]
            if t.era > 1:
                reached = country.era >= t.era
                rows.append((f"Era {ROMAN[t.era]}", reached, f"reached {ERAS[t.era][1]}" if reached else "not yet"))
            if not rows:
                _text(screen, _font(12), "Nothing: available from the start.", (x, y), MUTED)
                y += 18
            for name, ok, note in rows:
                pygame.draw.circle(screen, GREEN if ok else RED, (x + 4, y + 8), 4)
                _text(screen, _font(12), name, (x + 16, y), TEXT, width=w - 90)
                _text(screen, _font(11), note, (rect.right - 16, y + 1), MUTED, align="right")
                y += 18
            y += 8
        leads = [u for u in tech.TECHS.values() if t.key in u.needs]
        if y < stop - 40:
            y = heading("LEADS TO", y)
            if not leads:
                _text(screen, _font(12), "Nothing yet.", (x, y), MUTED)
                y += 18
            for u in leads:
                pygame.draw.circle(screen, BRANCH_COLOUR[u.branch], (x + 4, y + 8), 4)
                _text(screen, _font(12), u.name, (x + 16, y), TEXT, width=w - 80)
                _text(screen, _font(11), f"era {ROMAN[u.era]}", (rect.right - 16, y + 1), MUTED, align="right")
                y += 18
            y += 8
        if y < stop - 40:
            y = heading("BATTLE CARDS", y)
            if not t.cards:
                _text(screen, _font(12), "None.", (x, y), MUTED)
                y += 18
            cx, cy = x, y
            for card in t.cards:
                cw = _font(11).size(card)[0] + 14
                if cx + cw > rect.right - 16:
                    cx, cy = x, cy + 24
                pygame.draw.rect(screen, (52, 46, 34), (cx, cy, cw, 19), border_radius=5)
                pygame.draw.rect(screen, (150, 120, 60), (cx, cy, cw, 19), 1, border_radius=5)
                _text(screen, _font(11), card, (cx + 7, cy + 3), (220, 196, 140))
                cx += cw + 6
            y = cy + 30
        if y < stop - 40:
            y = heading("WHO HAS IT", y)
            names = self._who_has(t.key)
            if t.key in country.techs:
                names = ["You"] + names
            body = ", ".join(names) if names else "Nobody you know yet."
            for line in _wrap(_font(12), body, w):
                _text(screen, _font(12), line, (x, y), TEXT if names else MUTED)
                y += 16
        return y

    def _tech_status(self, t, state, country):
        cost = self._tech_cost(t.key) if state != "known" else 0
        if state == "known":
            return ("KNOWN" + (" · NATIONAL" if t.national else ""), GREEN)
        if state == "researching":
            return (f"RESEARCHING  {int(country.research)} / {cost}", GOLD)
        if state == "queued":
            return ("QUEUED", QUEUE_TEXT)
        if state == "available":
            return (f"AVAILABLE · {cost} RP", TEXT)
        if state == "later":
            return (f"LATER AGE · {cost} RP", FAINT)
        missing = next(n for n in t.needs if n not in country.techs)
        return (f"LOCKED: needs {tech.tech(missing).name}", RED)

    def _draw_tech_legend(self, rect, top):
        screen = self.screen
        x = rect.x + 16
        _text(screen, _font(10, True), "LEGEND", (x, top + 2), FAINT)
        items = [("known", "known"), ("researching", "researching"), ("available", "available"),
                 ("blocked", "missing a prerequisite"), ("later", "later age")]
        for i, (state, label) in enumerate(items):
            col, row = i % 2, i // 2
            ix = x + col * 130
            iy = top + 22 + row * 20
            fill, border, _width = STATE_STYLE[state]
            pygame.draw.rect(screen, fill, (ix, iy, 16, 12), border_radius=3)
            pygame.draw.rect(screen, border, (ix, iy, 16, 12), 1, border_radius=3)
            _text(screen, _font(11), label, (ix + 22, iy - 1), MUTED, width=104)
        ly = top + 22 + 3 * 20
        pygame.draw.line(screen, GOLD, (x, ly + 6), (x + 22, ly + 6), 2)
        _text(screen, _font(11), "in a branch", (x + 28, ly), MUTED)
        _dashed(screen, (78, 86, 100), [(x + 150, ly + 6), (x + 172, ly + 6)], 2)
        _text(screen, _font(11), "cross-branch", (x + 178, ly), MUTED)

    def _draw_tech_toast(self, geo):
        ui = self.ui
        if not ui.toast or pygame.time.get_ticks() >= ui.toast_until:
            return
        img = _font(14).render(ui.toast, True, TEXT)
        box = img.get_rect(midbottom=(geo["left"] // 2, geo["H"] - 12)).inflate(26, 12)
        pygame.draw.rect(self.screen, (12, 14, 18), box, border_radius=6)
        pygame.draw.rect(self.screen, LINE, box, 1, border_radius=6)
        self.screen.blit(img, img.get_rect(center=box.center))

    def _draw_idea_modal(self):
        screen = self.screen
        W, H = screen.get_size()
        world = self.world
        country = world.countries[self.player]
        ideas = [i for i in (_idea(k) for k in country.pending_ideas) if i is not None]
        if not ideas:
            return
        shade(screen, (0, 0, W, H), (5, 7, 10, 160))
        bw, bh = min(900, W - 48), min(470, H - 36)
        box = pygame.Rect(0, 0, bw, bh)
        box.center = (W // 2, H // 2)
        pygame.draw.rect(screen, PANEL, box, border_radius=12)
        pygame.draw.rect(screen, GOLD, box, 1, border_radius=12)
        cx = box.centerx
        _text(screen, _font(11, True), f"{world.date()} · A NEW AGE".upper(), (cx, box.y + 14), MUTED, align="center")
        _text(screen, _font(26, True, True), f"The {ERAS[country.era][0]}", (cx, box.y + 30), GOLD, align="center")
        names = _join([troop(b, country.era).name.lower() for b in BRANCHES])
        y = box.y + 72
        for line in _wrap(_font(13), f"{names[0].upper() + names[1:]} can now be raised. "
                                     "Refit old troops in your towns.", bw - 80):
            _text(screen, _font(13), line, (cx, y), TEXT, align="center")
            y += 19
        y += 2
        _text(screen, _font(13), f"Era {ROMAN[country.era]} techs are open. Choose one idea to keep:",
              (cx, y), MUTED, align="center")
        top = y + 26
        footer = 40
        card_h = box.bottom - footer - top
        gap = 18
        card_w = (bw - 48 - gap * (len(ideas) - 1)) // len(ideas)
        for i, idea in enumerate(ideas):
            x = box.x + 24 + i * (card_w + gap)
            r = pygame.Rect(x, top, card_w, card_h)
            national = bool(idea.nation)
            hovered = r.collidepoint(self.ui.mouse)
            pygame.draw.rect(screen, (42, 48, 60) if hovered else (34, 39, 49), r, border_radius=10)
            pygame.draw.rect(screen, GOLD if national else LINE, r, 2 if national else 1, border_radius=10)
            col = BRANCH_COLOUR[idea.branch]
            art = pygame.Rect(r.x + 1, r.y + 1, r.w - 2, 84)
            pygame.draw.rect(screen, col, art, border_radius=10)
            _glyph(screen, "star" if national else BRANCH_ICON[idea.branch], art.centerx, art.centery, 18)
            tag = pygame.Rect(r.x, art.bottom, r.w, 20)
            if national:
                name = world.countries[idea.nation].name.upper() if idea.nation in world.countries else idea.nation
                pygame.draw.rect(screen, (120, 96, 30), tag)
                _text(screen, _font(11, True), f"{name} · NATIONAL", (r.centerx, tag.y + 3), GOLD, align="center")
            else:
                pygame.draw.rect(screen, _mix(col, (0, 0, 0), 0.4), tag)
                _text(screen, _font(11, True), tech.BRANCH_NAMES[idea.branch].upper(), (r.centerx, tag.y + 3),
                      TEXT, align="center")
            _text(screen, _font(18, True, True), idea.name, (r.centerx, tag.bottom + 12),
                  GOLD if national else TEXT, width=r.w - 16, align="center")
            ty = tag.bottom + 44
            for line in _wrap(_font(13), idea.text, r.w - 30):
                _text(screen, _font(13), line, (r.centerx, ty), MUTED, align="center")
                ty += 18
            self.tech_buttons.append((r, ("pick", idea.key)))
            btn = pygame.Rect(r.x + 12, r.bottom - 42, r.w - 24, 30)
            if national:
                btn_colour = (120, 96, 30)
            else:
                btn_colour = BUTTON_HOT if btn.collidepoint(self.ui.mouse) else BUTTON
            pygame.draw.rect(screen, btn_colour, btn, border_radius=6)
            _text(screen, _font(13, True), "Take", (btn.centerx, btn.y + 7), TEXT, align="center")
            self.tech_buttons.append((btn, ("pick", idea.key)))
        _text(screen, _font(11), "One card is always your nation's; the others lean toward the branch you research most.",
              (cx, box.bottom - 26), FAINT, align="center")
