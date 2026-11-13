"""The technology screen's layout and data: where things go and what state each tech is in. No drawing.

``geometry(size)`` cuts a window of that size into the side card, the three era columns and the scrolling grid body;
``nodes(geo, country)`` gives every tech card its rect in grid-body coordinates; ``tech_state`` says how a tech looks
for a country (known, researching, queued, available, blocked, later); ``research_order`` gives its place on the
research path; ``who_has`` says which explored countries know it. techdraw.py draws from these, techscreen.py takes the input.
"""
import pygame

from ...ui.theme import TECH_GOLD as GOLD
from .. import tech

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

def mix(a, b, f):
    return tuple(int(x + (y - x) * f) for x, y in zip(a, b))


def join_words(words):
    if len(words) <= 1:
        return "".join(words)
    return ", ".join(words[:-1]) + " and " + words[-1]


def idea_of(key):
    if key in tech.IDEAS:
        return tech.IDEAS[key]
    return next((i for lst in tech.NATIONAL_IDEAS.values() for i in lst if i.key == key), None)


def geometry(size):
    """The screen's regions for a window of `size`: the side card, the era columns, the grid body."""
    W, H = size
    side = max(270, min(340, int(W * 0.22)))
    left = W - side
    era_x = LABEL_W + 8
    era_w = (left - era_x - 6) // 3
    body_top = TOP_H + STRIP_H + HEAD_H + 4
    return {"W": W, "H": H, "side": side, "left": left, "era_x": era_x, "era_w": era_w,
            "body_top": body_top, "body_h": H - body_top}


def max_scroll(size):
    return max(0, 4 * BLOCK_H - geometry(size)["body_h"])


def cells(country):
    """Techs per (branch, era) cell, with the national tech in its branch's era I cell."""
    cells = {}
    for key, t in tech.TECHS.items():
        cells.setdefault((t.branch, t.era), []).append(key)
    nat = tech.tech(country.national) if country.national else None
    if nat is not None:
        cells.setdefault((nat.branch, 1), []).append(nat.key)
    return cells


def nodes(geo, country):
    """Node rects in grid-body coordinates (before scrolling)."""
    rects = {}
    node_w = (geo["era_w"] - 14) // 2
    grid = cells(country)
    for bi, branch in enumerate(tech.BRANCHES):
        top = bi * BLOCK_H
        for era in (1, 2, 3):
            for i, key in enumerate(grid.get((branch, era), [])):
                x = geo["era_x"] + (era - 1) * geo["era_w"] + (i % 2) * (node_w + 6)
                y = top + 6 + (i // 2) * (NODE_H + NODE_GAP)
                rects[key] = pygame.Rect(x, y, node_w, NODE_H)
    return rects


def tech_state(key, country):
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


def research_order(country):
    """Position of each tech on the research path: 0 is the tech being researched, 1 and up the queue."""
    order = {}
    if country.researching:
        order[country.researching] = 0
    for i, key in enumerate(country.queue):
        order.setdefault(key, i + 1)
    return order


def who_has(world, tag, key):
    """Names of the other countries that know the tech and that country `tag` has explored."""
    seen = world.countries[tag].explored
    names = []
    for c in world.countries.values():
        if c.tag == tag or not c.alive or key not in c.techs:
            continue
        if c.capital in seen:
            names.append(c.name)
    return names
