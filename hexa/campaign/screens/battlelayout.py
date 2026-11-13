"""Where the battle panel's parts go (battle slice 1, PR 7): pure geometry, no drawing, no pygame.

Rectangles are (x, y, w, h) tuples; battle.py turns them into pygame rects. The panel is a window of its own on the
stack: a frame, a header (title, ground, season and day, the close button), a morale bar, then two columns. The field
(left) is the battle: the enemy's back line and reserve at the top, the enemy's three lanes, the dashed front line,
our three lanes, our back line and reserve at the bottom. The side column (right) holds the sides, the orders, the
last day's dice and the log.

``panel(win_w, win_h)`` sizes the panel to the window (at most PANEL_MAX_W x PANEL_MAX_H, centred). ``field_slots``
gives every regiment slot of the field; the card height shrinks when a side has many regiments in reserve, so the
field fits 1280x720 with a full battle.
"""

MARGIN = 12                 # the window's edge to the panel
PANEL_MAX_W, PANEL_MAX_H = 1240, 880
PAD = 14                    # the panel's edge to its contents
HEADER_H = 76
MORALE_H = 46
SIDE_W = 340                # the side column
COL_GAP = 16                # the field to the side column
CARD_W_MAX = 320
CARD_H_MAX = 98
CARD_GAP = 10
LANES = 3
LABEL_H = 18                # a band label (ENGLAND back line, left flank ...)
FRONT_H = 18                # the dashed front line and its crossed swords


def panel(win_w, win_h):
    """The panel's rectangle in a window of win_w x win_h."""
    w = min(win_w - 2 * MARGIN, PANEL_MAX_W)
    h = min(win_h - 2 * MARGIN, PANEL_MAX_H)
    return ((win_w - w) // 2, (win_h - h) // 2, w, h)


def header(panel_rect):
    x, y, w, _ = panel_rect
    return (x, y, w, HEADER_H)


def close_button(panel_rect):
    """The close button, top right of the header."""
    x, y, w, _ = panel_rect
    return (x + w - PAD - 84, y + 14, 84, 30)


def morale(panel_rect):
    x, y, w, _ = panel_rect
    return (x, y + HEADER_H, w, MORALE_H)


def body(panel_rect):
    """The space under the morale bar, in which the field and the side column sit."""
    x, y, w, h = panel_rect
    top = y + HEADER_H + MORALE_H
    return (x, top, w, y + h - top - MARGIN)


def field_rect(panel_rect):
    x, top, w, h = body(panel_rect)
    side_w = SIDE_W
    return (x + PAD, top, w - 2 * PAD - side_w - COL_GAP, h)


def side_rect(panel_rect):
    x, top, w, h = body(panel_rect)
    return (x + w - PAD - SIDE_W, top, SIDE_W, h)


def _grid_rows(count):
    """Rows of the three-column grid that holds ``count`` regiments (0 when there are none)."""
    return -(-count // LANES) if count > 0 else 0


def card_size(field, top_count, bottom_count):
    """(width, height) of one regiment card for a field of that size and that many regiments in the two back grids."""
    fx, fy, fw, fh = field
    width = min(CARD_W_MAX, (fw - (LANES - 1) * CARD_GAP) // LANES)
    rows = _grid_rows(top_count) + _grid_rows(bottom_count) + 2          # + the two lane rows
    fixed = 2 * LABEL_H + 2 * LABEL_H + FRONT_H + rows * CARD_GAP        # labels of the bands and the front
    height = (fh - fixed) // max(1, rows)
    return width, max(40, min(CARD_H_MAX, height))


def field_slots(panel_rect, top_count, bottom_count):
    """Where everything in the field goes: a dict with ``top`` and ``bottom`` (lists of card rects of the two back
    grids, row by row), ``enemy`` and ``ours`` (the three lane rects of each side, left to right), ``labels`` (the
    band labels' y, for the enemy's and our back grid and each lane row), ``front`` (the y of the front line) and the
    card size. The top grid lists the enemy's back line first (the outermost row), the bottom grid lists our reserve
    first, our back line last (the outermost row)."""
    field = field_rect(panel_rect)
    fx, fy, fw, fh = field
    cw, ch = card_size(field, top_count, bottom_count)
    total = LANES * cw + (LANES - 1) * CARD_GAP
    x0 = fx + (fw - total) // 2

    def cell(col, y):
        return (x0 + col * (cw + CARD_GAP), y, cw, ch)

    y = fy
    labels = {"top": y}
    y += LABEL_H
    top = []
    for index in range(top_count):
        top.append(cell(index % LANES, y + (index // LANES) * (ch + CARD_GAP)))
    y += _grid_rows(top_count) * (ch + CARD_GAP)
    labels["enemy_lanes"] = y
    y += LABEL_H
    enemy = [cell(col, y) for col in range(LANES)]
    y += ch + CARD_GAP
    front = y
    y += FRONT_H
    labels["ours_lanes"] = y
    y += LABEL_H
    ours = [cell(col, y) for col in range(LANES)]
    y += ch + CARD_GAP
    labels["bottom"] = y
    y += LABEL_H
    bottom = []
    for index in range(bottom_count):
        bottom.append(cell(index % LANES, y + (index // LANES) * (ch + CARD_GAP)))
    return {"top": top, "enemy": enemy, "ours": ours, "bottom": bottom, "labels": labels, "front": front,
            "card": (cw, ch), "x0": x0, "width": total}


def split(x, y, w, count, h, gap=8):
    """``count`` buttons in a row of width w, starting at (x, y), each h high."""
    if count <= 0:
        return []
    bw = (w - (count - 1) * gap) // count
    return [(x + i * (bw + gap), y, bw, h) for i in range(count)]


def last_lines(blocks, max_lines):
    """The newest entries of a log that fit ``max_lines`` lines. ``blocks`` is a list of entries, each a list of the
    lines it wraps to, oldest first; the result keeps whole entries from the bottom up and returns the lines oldest
    first. An entry that does not fit at all is cut from its top, so the newest line always shows."""
    out = []
    room = max_lines
    for lines in reversed(blocks):
        if room <= 0:
            break
        take = lines[-room:] if len(lines) > room else lines
        out = list(take) + out
        room -= len(take)
    return out
