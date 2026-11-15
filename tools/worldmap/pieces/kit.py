"""The shared drawing kit for Hexa's normal-map pieces. Rule book: docs/design/map/pieces/GUIDE.md.

A piece is the picture of one hex's improvement at one level in one season, at hex radius 60.
Every family module imports this kit and exposes
    draw(level, season, variant=0, mirror=False) -> pygame.Surface        (see README.md).

Who draws what (the owner's answers of 2026-11-15, guide sections 1, 6, 10 and 12):
  - The MAP draws the ground, the coast and the wild land (woods, scrub). A piece draws only the work.
  - Level 0 is "no piece" on the map. On the sheets the level 0 column is kit.wild(): the wild land as the map
    draws it for that terrain.
  - The map thins its wild land under the piece's FOOTPRINT (take_apart()["footprint"], Piece.footprint()).
  - A coast piece is told where the sea is (sea=, shore=) and builds at that shore: p.coast() returns a Shore.
  - Every family has a mirrored version and a second layout; pick(col, row) chooses them from the hex.
    Mirroring moves positions only: every standing thing is still drawn lit from the upper left.
  - No name plates on the normal map for now.

Coordinates: everything a family module passes to the kit is in PIECE PIXELS at 100% size, with the origin at
the hex centre, x to the right and y down. The kit draws at 2x and scales down, so never multiply by 2 yourself.
The hex is pointy-top, 104 px wide and 102 px tall (north-south distances are already squashed to 85%).

Colours and shapes of the house, trees, walls, ship and shadows are taken from the style frame
(tools/worldmap/style_frame/frame.py and render.py), so pieces sit in the same world.
"""
import math
import os
import random

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
import pygame

pygame.init()

# ------------------------------------------------------------------ canvas
SS = 2                      # drawn at 2x, smoothscaled to 1x
R = 60                      # hex radius in px at 100%
TILT = 0.85                 # the ground plane: north-south distances at 85%
SIZE = 112                  # the piece canvas, square, at 100%
C = SIZE // 2               # the hex centre on the canvas
HEX_W = R * math.sqrt(3)    # 103.9
HEX_H = 2 * R * TILT        # 102
MARGIN = 3                  # standing things stay this far inside the hex border
FEATHER = 5                 # the ground fades out over this many px at the hex border
SEASONS = ("spring", "summer", "autumn", "winter")

INK = (52, 44, 46)
SHADOW = (30, 50, 30)
SHADOW_ALPHA = 46


NO_BASE = False               # set by take_apart(): pieces are then drawn without their ground base (for the map)
LAST = None                   # the Piece most recently finished (take_apart() reads it)
SITE = {}                     # set by take_apart(): the hex's mirror, sea and shore, for modules that do not pass them on
WILD = None                   # set by with_wild(): a footprint mask; the piece then stands in thinned wild land (sheets)
CHECK = True                  # False while a piece is drawn only to measure it

# The sea side of a hex, as the direction from the hex centre to the sea on screen (x right, y down). A pointy-top
# hex has the six neighbours E, SE, SW, W, NW, NE; S and N stand for "both lower" and "both upper" neighbours.
_D = (HEX_W / 2, 0.75 * HEX_H)
_L = math.hypot(*_D)
SIDES = {"E": (1.0, 0.0), "W": (-1.0, 0.0), "S": (0.0, 1.0), "N": (0.0, -1.0),
         "SE": (_D[0] / _L, _D[1] / _L), "SW": (-_D[0] / _L, _D[1] / _L),
         "NE": (_D[0] / _L, -_D[1] / _L), "NW": (-_D[0] / _L, -_D[1] / _L)}


def sea_vector(sea):
    """The unit vector towards the sea. sea: a side name ("S", "SE", ...), several of them (("E", "SE"): the sea
    lies on both; the middle is taken), or an angle in degrees on screen (0 = east, 90 = south)."""
    if isinstance(sea, (int, float)):
        return (math.cos(math.radians(sea)), math.sin(math.radians(sea)))
    names = [sea] if isinstance(sea, str) else list(sea)
    x, y = sum(SIDES[q][0] for q in names), sum(SIDES[q][1] for q in names)
    d = math.hypot(x, y)
    return (x / d, y / d) if d > 1e-6 else SIDES[names[0]]


def pick(col, row, variants=2):
    """Which picture a hex shows: (variant, mirror), from the hex's coordinates alone (offset coordinates with odd
    rows shoved right, as the map has them). The same hex always gives the same answer. With two layouts no two
    neighbours ever show the same picture: the grid is split in three classes that never touch; one class shows
    layout 0 mirrored, one the last layout, and the third takes plain layout 0 or the last layout mirrored by a
    hash of the hex. With one layout only the mirror differs, so some neighbours repeat.
    With three layouts or more each of the three classes shows its own layout (0, 1, 2; a fourth and further layout
    takes turns with layout 0 by the hash), plain or mirrored by the hash: no two neighbours show the same layout."""
    q = col - ((row - (row & 1)) >> 1)
    cls = (q - row) % 3
    h = ((col * 73856093) ^ (row * 19349663)) & 0xffffffff
    h = ((h ^ (h >> 13)) * 0x5bd1e995) & 0xffffffff
    bit = (h >> 15) & 1
    if variants >= 3:
        v = cls
        if cls == 0 and variants > 3:
            v = (0, *range(3, variants))[(h >> 17) % (variants - 2)]
        return (v, bool(bit))
    last = max(1, variants) - 1
    if cls == 1:
        return (last, False)
    if cls == 2:
        return (0, True)
    return (last, True) if bit else (0, False)


def mirror_gates(gates, mirror=True, variant=0):
    """A module's GATES table as it lies in the mirrored piece: x turned round, east and west swapped.
    GATES is one dict for the module, or a list with one dict per layout (then give variant=)."""
    if isinstance(gates, (list, tuple)):
        gates = gates[min(variant, len(gates) - 1)]
    if not mirror:
        return dict(gates)
    swap = {"east": "west", "west": "east"}
    return {swap.get(k, k): (-p[0], p[1]) for k, p in gates.items()}


def hex_points(shrink=0.0):
    """The six corners in piece px (origin at the centre), pulled in by `shrink` px."""
    r = R - shrink / math.cos(math.radians(30))
    return [(r * math.cos(math.radians(-90 + 60 * k)), r * math.sin(math.radians(-90 + 60 * k)) * TILT) for k in range(6)]


def in_hex(x, y, margin=0.0):
    """True if the piece-px point lies inside the hex, `margin` px clear of the border."""
    ax, ay = abs(x), abs(y) / TILT
    inner = R * math.cos(math.radians(30)) - margin
    return ax <= inner and ax * 0.5 + ay * math.cos(math.radians(30)) <= inner


# ------------------------------------------------------------------ colour helpers
def mix(c1, c2, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))


def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c[:3])


# ------------------------------------------------------------------ the palette (named tokens)
# Fixed tokens: the same in every season.
STONE = (214, 202, 174)         # town walls, quays, moles
STONE_D = (176, 164, 140)
STONE_GREY = (176, 172, 166)    # castles, mines
STONE_GREY_D = (132, 128, 126)
PLASTER = [(240, 228, 196), (232, 200, 140), (234, 192, 166), (246, 240, 228), (226, 210, 170)]   # house walls
CHURCH = (236, 226, 204)
ROOF = (204, 94, 62)            # tile roofs
ROOF_D = (160, 70, 50)
THATCH = (198, 168, 104)        # huts, barns
THATCH_D = (158, 128, 78)
SLATE = (112, 116, 132)         # castle and tower roofs
SLATE_D = (82, 86, 102)
TIMBER = (150, 110, 72)         # palisades, jetties, fences, frames
TIMBER_D = (112, 80, 54)
TRUNK = (92, 70, 50)
DOOR = (70, 56, 50)
DOME = (150, 160, 150)
DOME_L = (178, 188, 176)
HULL = (120, 78, 52)
SAIL = (246, 240, 226)
SAIL_D = (214, 206, 190)
ROAD = (226, 206, 152)
ROAD_EDGE = (128, 100, 66)
SNOW = (242, 245, 250)
SNOW_D = (206, 214, 228)        # the shaded side of snow
SMOKE = (236, 236, 232)
SMOKE_SNOW = (186, 190, 202)     # smoke in winter: grey, so it shows against snow
FLAG = (196, 52, 48)
SALT = (248, 246, 240)
SPOIL = (150, 140, 132)         # mine waste heaps
SPOIL_D = (112, 104, 100)

# Signature tokens of the families brought over from the Python tiles (guide sections 4 and 8). They live here, in
# one place, so no two families can pick the same colour; each has ONE owner (named at the right).
MARBLE = (240, 236, 226)        # quarry: cut blocks and columns. Landmarks: Venice's fronts
MARBLE_D = (200, 196, 188)
PIT = (212, 202, 180)           # quarry: the ledges of the pit, lit top
PIT_D = (164, 152, 132)         # quarry: the cut faces
DYE = {"blue": (58, 98, 172), "red": (192, 54, 60), "yellow": (234, 192, 62), "purple": (128, 72, 152)}   # dye works: vats and cloth
RET = (98, 132, 118)            # hemp: the retting pond (dull green water), with RET_D as its edge
RET_D = (64, 92, 86)
BOLL = (250, 248, 240)          # cotton: the open bolls
DOME_TILE = (64, 150, 168)      # silk: the caravanserai's small turquoise dome
DOME_TILE_D = (44, 112, 132)
PELT = (146, 94, 58)            # furs: pelts on stretching frames
PELT_D = (106, 68, 46)
GLOW = (250, 150, 50)           # mines, iron: the furnace mouth (with harbour's lamp the only light on the map)
VERDIGRIS = (96, 160, 140)      # mines, copper: the stained rock. Landmarks: Venice's campanile cap
VERDIGRIS_D = (66, 122, 110)
# Mines by ore: spoil heaps (lit, shaded) and the ore pile (lit, shaded). mines.draw(..., ore=None) keeps SPOIL and
# the module's own ORE: today's picture.
ORES = {
    "iron": dict(spoil=(150, 134, 126), spoil_d=(112, 98, 94), ore=(164, 86, 54), ore_d=(122, 62, 44)),
    "silver": dict(spoil=(176, 184, 196), spoil_d=(132, 140, 156), ore=(208, 214, 222), ore_d=(160, 168, 182)),
    "copper": dict(spoil=(140, 142, 132), spoil_d=(104, 108, 100), ore=(214, 132, 62), ore_d=(170, 98, 48)),
    "gold": dict(spoil=(214, 194, 140), spoil_d=(172, 150, 104), ore=(222, 184, 84), ore_d=(178, 140, 60)),
}
BRICK = (178, 74, 60)           # landmarks: Moscow's and Granada's red walls
BRICK_D = (136, 56, 48)
LEAD = (118, 140, 168)          # landmarks: the grey-blue domes of Constantinople and Venice
LEAD_D = (88, 108, 136)
GILT = (228, 188, 84)           # landmarks: a gilded dome or finial, 2 px at most
ONION = [(228, 188, 84), (72, 132, 92), (62, 104, 170), (190, 60, 56)]       # landmarks: Moscow's onion domes

# Season tokens. PAL[season][token].
PAL = {
    "spring": dict(
        grass=(152, 196, 92), farm=(176, 202, 104), wood=(120, 172, 82), rock=(170, 156, 130), sand=(234, 216, 162),
        soil=(152, 114, 78), soil_d=(124, 92, 64), tuft=(112, 158, 72), hedge=(84, 140, 66), hedge_d=(56, 100, 52),
        leaf=((44, 76, 40), (86, 150, 66), (118, 180, 80), (156, 208, 104)),            # outline, dark, mid, light
        conifer=((34, 56, 40), (66, 120, 70), (46, 92, 58)),                            # outline, lit, shaded
        sea=(71, 143, 192), shallow=(96, 168, 210), foam=(226, 242, 248), river=(74, 146, 206), river_edge=(44, 92, 140),
        blossom=(250, 232, 236)),
    "summer": dict(
        grass=(146, 186, 86), farm=(178, 198, 98), wood=(112, 164, 78), rock=(170, 156, 130), sand=(234, 216, 162),
        soil=(162, 126, 86), soil_d=(132, 100, 70), tuft=(112, 150, 70), hedge=(70, 128, 60), hedge_d=(46, 92, 50),
        leaf=((38, 60, 38), (70, 128, 60), (96, 158, 72), (130, 186, 92)),
        conifer=((34, 56, 40), (66, 120, 70), (46, 92, 58)),
        sea=(71, 143, 192), shallow=(96, 168, 210), foam=(226, 242, 248), river=(74, 146, 206), river_edge=(44, 92, 140),
        blossom=None),
    "autumn": dict(
        grass=(172, 174, 84), farm=(188, 178, 98), wood=(152, 152, 76), rock=(166, 150, 126), sand=(230, 212, 160),
        soil=(140, 102, 70), soil_d=(112, 80, 56), tuft=(150, 140, 70), hedge=(150, 112, 52), hedge_d=(108, 78, 44),
        leaf=((78, 50, 32), (176, 96, 44), (210, 134, 52), (236, 178, 76)),             # rust; see LEAF_AUTUMN for the mix
        conifer=((34, 56, 40), (66, 116, 68), (46, 90, 56)),
        sea=(66, 134, 182), shallow=(92, 160, 202), foam=(226, 242, 248), river=(70, 138, 196), river_edge=(44, 92, 140),
        blossom=None),
    "winter": dict(
        grass=(228, 233, 238), farm=(232, 236, 240), wood=(216, 224, 230), rock=(208, 208, 208), sand=(234, 230, 214),
        soil=(176, 156, 136), soil_d=(150, 128, 110), tuft=(150, 150, 110), hedge=(108, 96, 76), hedge_d=(78, 68, 56),
        leaf=((70, 54, 44), (104, 82, 62), (104, 82, 62), (104, 82, 62)),               # bare: only twigs are drawn
        conifer=((34, 56, 40), (62, 106, 72), (44, 82, 60)),
        sea=(62, 122, 166), shallow=(104, 158, 194), foam=(232, 242, 248), river=(86, 142, 190), river_edge=(52, 96, 140),
        blossom=None),
}
# Autumn broadleaves are a fixed mix of three colourings, chosen by the tree's index (i % 3): rust, gold, late green.
LEAF_AUTUMN = [
    ((78, 50, 32), (176, 96, 44), (210, 134, 52), (236, 178, 76)),
    ((84, 62, 30), (190, 144, 44), (222, 180, 62), (242, 212, 104)),
    ((48, 62, 36), (110, 132, 58), (140, 160, 68), (176, 190, 90)),
]
ICE = (206, 226, 238)
ICE_D = (172, 200, 220)

# Crop colours per season: strip colours cycle through the list. Each family owns its crop (see the guide).
CROPS = {
    "wheat": dict(
        spring=[(150, 192, 88), (168, 202, 98), (136, 178, 84), (160, 122, 84)],          # green shoots, one bare strip
        summer=[(222, 198, 104), (232, 212, 128), (210, 180, 96), (226, 204, 112)],       # ripe gold
        autumn=[(142, 104, 72), (204, 182, 122), (156, 118, 80), (128, 94, 66)],          # ploughed earth and stubble
        winter=[(238, 241, 245), (214, 224, 236), (238, 241, 245), (190, 170, 148)]),     # snow, one strip of bare earth
    "garden": dict(                                                                       # small plots by houses
        spring=[(128, 176, 84), (160, 124, 86), (146, 190, 96)],
        summer=[(110, 164, 80), (150, 186, 92), (170, 134, 90)],
        autumn=[(150, 112, 76), (166, 160, 84), (134, 98, 68)],
        winter=[(230, 234, 240), (222, 228, 236), (204, 190, 172)]),
    "meadow": dict(                                                                       # fenced pasture, hay
        spring=[(166, 206, 104)], summer=[(170, 200, 100)], autumn=[(186, 182, 98)], winter=[(234, 238, 242)]),
    "vine_soil": dict(
        spring=[(176, 140, 104)], summer=[(180, 146, 106)], autumn=[(168, 130, 96)], winter=[(226, 228, 232)]),
    "vine": dict(                                                                         # the row colour
        spring=[(120, 170, 76)], summer=[(72, 128, 62)], autumn=[(170, 70, 60)], winter=[(96, 76, 60)]),
    "olive_soil": dict(
        spring=[(206, 196, 140)], summer=[(212, 198, 142)], autumn=[(204, 188, 136)], winter=[(226, 226, 222)]),
    "hemp": dict(                                                                         # dark blue-green blocks: never gold
        spring=[(150, 116, 82), (140, 108, 76)],                                          # sown late: bare earth (the rows are drawn over it)
        summer=[(52, 112, 76), (62, 124, 84)],                                            # the signature: the darkest crop on the map
        autumn=[(176, 160, 104), (164, 148, 96)],                                         # cut: pale stubble, the stooks stand on it
        winter=[(236, 239, 244), (212, 222, 234)]),
    "hemp_row": dict(                                                                     # the young rows of spring
        spring=[(84, 148, 86)], summer=[(40, 92, 64)], autumn=[(140, 124, 80)], winter=[(190, 170, 148)]),
    "cotton_soil": dict(                                                                  # the red earth, as a patch only
        spring=[(178, 116, 86)], summer=[(184, 112, 82)], autumn=[(168, 106, 80)], winter=[(228, 226, 228)]),
    "cotton": dict(                                                                       # the plant rows; summer and autumn carry BOLL dots
        spring=[(120, 168, 84)], summer=[(96, 140, 76)], autumn=[(132, 112, 72)], winter=[(120, 90, 66)]),
    "mulberry_soil": dict(                                                                # the pale strip under a mulberry row
        spring=[(190, 196, 120)], summer=[(196, 194, 118)], autumn=[(196, 180, 112)], winter=[(230, 233, 236)]),
}
CROP_EDGE = dict(spring=(104, 130, 62), summer=(128, 124, 60), autumn=(100, 78, 54), winter=(140, 152, 176))

# ------------------------------------------------------------------ the three winters (guide section 7)
# Winter is not the same everywhere. The map gives every hex one of three winters, by its climate (winter_of()):
#   "snow"   the hard winter: everything under snow (PAL["winter"], as before; the default)
#   "frost"  the light winter: snow on roofs, trees and worked ground and in patches on the wild ground, which
#            shows through pale and frosted; still water frozen
#   "mild"   the Mediterranean winter: no snow and no ice. Rain-darkened green-grey ground, bare broadleaves and
#            vines, dark wet soil, young winter corn; olives and conifers stay green
# A module still draws draw(level, "winter"): the kit knows the hex's winter (climate(), take_apart(climate=)).
CLIMATES = ("snow", "frost", "mild")
CLIMATE = "snow"              # the winter of the hex being drawn (set by climate(); take_apart and with_wild set it)
WINTER = {
    "snow": PAL["winter"],
    "frost": dict(
        PAL["winter"],
        grass=(190, 200, 172), farm=(198, 204, 176), wood=(176, 190, 164), rock=(196, 194, 186), sand=(230, 222, 196),
        soil=(170, 148, 126), soil_d=(144, 122, 104), tuft=(140, 144, 104)),
    "mild": dict(
        grass=(140, 160, 102), farm=(154, 164, 106), wood=(114, 142, 86), rock=(158, 148, 128), sand=(222, 206, 160),
        soil=(132, 100, 72), soil_d=(106, 78, 56), tuft=(110, 126, 76), hedge=(104, 108, 62), hedge_d=(72, 78, 50),
        leaf=((70, 54, 44), (104, 82, 62), (104, 82, 62), (104, 82, 62)),               # bare: only twigs are drawn
        conifer=((34, 56, 40), (62, 112, 68), (44, 88, 56)),
        sea=(62, 122, 166), shallow=(104, 158, 194), foam=(232, 242, 248), river=(78, 134, 182), river_edge=(48, 92, 136),
        blossom=None),
}
WINTER_CROPS = {
    "frost": dict(                                         # a thin snow: the pattern and more of the ground show
        wheat=[(228, 233, 232), (198, 208, 184), (234, 238, 240), (176, 156, 134)],
        garden=[(222, 228, 226), (200, 208, 188), (190, 174, 154)],
        meadow=[(214, 222, 204)], vine_soil=[(210, 204, 194)], vine=[(96, 76, 60)], olive_soil=[(218, 212, 190)],
        hemp=[(224, 228, 222), (196, 200, 180)], hemp_row=[(176, 156, 134)],
        cotton_soil=[(212, 196, 190)], cotton=[(120, 90, 66)], mulberry_soil=[(212, 216, 196)]),
    "mild": dict(                                          # no snow: young winter corn and dark wet earth
        wheat=[(128, 160, 84), (138, 108, 78), (120, 150, 80), (150, 118, 84)],
        garden=[(136, 106, 76), (122, 150, 82), (146, 114, 80)],
        meadow=[(158, 176, 104)], vine_soil=[(160, 128, 94)], vine=[(96, 76, 60)], olive_soil=[(196, 180, 130)],
        hemp=[(134, 104, 76), (124, 96, 70)], hemp_row=[(112, 88, 64)],
        cotton_soil=[(156, 100, 76)], cotton=[(112, 84, 62)], mulberry_soil=[(168, 168, 108)]),
}
WINTER_EDGE = {"snow": CROP_EDGE["winter"], "frost": (136, 144, 150), "mild": (96, 96, 60)}
# In a mild winter nothing is white. A module asks p.winter before it draws snow (False in a mild winter), but a
# few older lines use the snow and ice tokens whenever the season is winter. While a mild piece is drawn the kit
# therefore reads those four tokens as wet earth and open water: a safety net, not a way to draw (guide section 7).
_MILD_TOKENS = dict(SNOW=(176, 158, 124), SNOW_D=(156, 138, 108), ICE=(104, 150, 186), ICE_D=(48, 92, 136))
_COLD_TOKENS = {}


def cold_index(lat, height_m=0.0, sea_km=None):
    """How hard the winter of a hex is, as one number (see winter_of()). lat: degrees north; height_m: the hex's
    mean height (ETOPO); sea_km: km from the hex centre to the nearest sea (None: far inland). Within 25 km of
    the sea the height counts less (not at all on the shore): a coastal hex is settled at sea level, whatever
    mountains stand behind it."""
    sea = 400.0 if sea_km is None else max(0.0, sea_km)
    warm = max(0.25, min(1.0, (50.0 - lat) / 8.0))          # the sea warms the south; it does little in the north
    height_m = height_m * min(1.0, sea / 25.0)
    return (0.5 * (lat - 36.0) + height_m / 300.0
            - warm * (3.5 * max(0.0, 1 - sea / 40.0) + 2.0 * max(0.0, 1 - sea / 15.0)) + min(2.0, sea / 300.0))


MILD_BELOW, SNOW_FROM = 4.5, 8.0


def winter_of(lat, height_m=0.0, sea_km=None):
    """The winter of a hex: "snow", "frost" or "mild", from its latitude, its height and its distance to the sea
    (guide section 7). The same hex has the same winter in every year."""
    c = cold_index(lat, height_m, sea_km)
    return "mild" if c < MILD_BELOW else "frost" if c < SNOW_FROM else "snow"


class climate:
    """with kit.climate("mild"): ...   Winter pieces drawn inside are drawn for that winter ("snow", "frost" or
    "mild"; None leaves it as it is). Other seasons are not touched. take_apart(), with_wild() and wild() take
    climate= and do this themselves."""

    def __init__(self, name):
        assert name is None or name in CLIMATES, name
        self.name = name

    def __enter__(self):
        global CLIMATE
        self.old = CLIMATE
        if self.name is not None:
            CLIMATE = self.name
            _tokens()
        return self

    def __exit__(self, *a):
        global CLIMATE
        CLIMATE = self.old
        _tokens()


def _tokens():
    g = globals()
    if not _COLD_TOKENS:
        _COLD_TOKENS.update({k: g[k] for k in _MILD_TOKENS})
    g.update(_MILD_TOKENS if CLIMATE == "mild" else _COLD_TOKENS)


def crop(name, season):
    if season == "winter" and CLIMATE != "snow":
        return WINTER_CROPS[CLIMATE][name]
    return CROPS[name][season]


# ------------------------------------------------------------------ the pen (2x drawing with ink)
class Pen:
    """Draws on a 2x surface in piece px. Every family uses this for its own landmarks, so ink and scale agree."""

    def __init__(self, surf, m=1, dx=0.0):
        self.s = surf
        self.m = m              # -1: x is turned round (the kit's ground pen of a mirrored piece)
        self.dx = dx            # a shift in px (a standing thing of a mirrored piece: moved, not turned)

    @staticmethod
    def T(p):
        return ((p[0] + C) * SS, (p[1] + C) * SS)

    def t(self, p):
        return ((p[0] * self.m + self.dx + C) * SS, (p[1] + C) * SS)

    @staticmethod
    def W(w):
        return max(1, int(round(w * SS)))

    def poly(self, pts, fill=None, ink=INK, w=1):
        q = [self.t(p) for p in pts]
        if fill is not None:
            pygame.draw.polygon(self.s, fill, q)
        if ink is not None:
            pygame.draw.polygon(self.s, ink, q, self.W(w))

    def rect(self, x, y, w, h, fill=None, ink=INK, lw=1):
        """x, y is the top left corner."""
        self.poly([(x, y), (x + w, y), (x + w, y + h), (x, y + h)], fill, ink, lw)

    def box(self, x, y, w, h, col, ink=INK, side=0.24):
        """An upright wall face standing on (x, y) = middle of its foot: lit, with a shaded strip on the right."""
        x0 = x - w / 2
        self.rect(x0, y - h, w, h, col, None)
        self.rect(x0 + w * (1 - side), y - h, w * side, h, shade(col, 0.84), None)
        if ink is not None:
            self.rect(x0, y - h, w, h, None, ink)

    def line(self, a, b, col=INK, w=1):
        pygame.draw.line(self.s, col, self.t(a), self.t(b), self.W(w))

    def lines(self, pts, col=INK, w=1, closed=False):
        if len(pts) > 1:
            pygame.draw.lines(self.s, col, closed, [self.t(p) for p in pts], self.W(w))

    def circle(self, x, y, r, fill=None, ink=None, w=1):
        if fill is not None:
            pygame.draw.circle(self.s, fill, self.t((x, y)), r * SS)
        if ink is not None:
            pygame.draw.circle(self.s, ink, self.t((x, y)), r * SS, self.W(w))

    def ellipse(self, x, y, w, h, fill=None, ink=None, lw=1):
        """x, y is the centre."""
        r = pygame.Rect(0, 0, max(1, int(w * SS)), max(1, int(h * SS)))
        r.center = self.t((x, y))
        if fill is not None:
            pygame.draw.ellipse(self.s, fill, r)
        if ink is not None:
            pygame.draw.ellipse(self.s, ink, r, self.W(lw))

    def dot(self, x, y, col, size=1.0):
        self.rect(x - size / 2, y - size / 2, size, size, col, None)


def ring_points(cx, cy, rx, ry, a0, a1, n=40):
    return [(cx + math.cos(a0 + (a1 - a0) * q / n) * rx, cy + math.sin(a0 + (a1 - a0) * q / n) * ry) for q in range(n + 1)]


# ------------------------------------------------------------------ the shore
class Shore:
    """Where the sea meets the land in this hex, as p.coast() returns it. A coast family lays out its shore things
    in SHORE COORDINATES: u px along the shore from its middle, v px out to sea (v < 0 is inland).
        shore.pt(u, v)   the piece-px point (give it to any kit call)
        shore.land(x, y) True if the piece-px point lies on land
        shore.out        the unit vector towards the sea;  shore.along  the unit vector along the shore (u grows)
        shore.depth      px of land behind the shore at its middle (down to the hex border)
        shore.at(u, v, du, dv)   the point du along and dv out from pt(u, v), on straight axes
        shore.rect(u, v, w, h)   a true rectangle lying at the shore (a pan, a yard, a slip): four piece-px corners
        shore.fits(u, v, tall, wide)   True if a standing thing that size, its foot at pt(u, v), stays inside the hex
        shore.fit(u, v, tall, wide)    pt(u, v) slid back towards the shore until the thing fits, or None
        shore.first(spots, tall, wide) the first of several (u, v) spots where the thing fits, or None
        shore.front      True if the sea lies in front (the south half): boats and jetties are then in front of the land
    With the sea in front (the sheets' default), pt(u, v) is (u, shore(u) + v): shore(x) still gives the y of the
    water's edge, as the first kit did."""

    def __init__(self, out, h):
        self.out = out
        self.along = (out[1], -out[0])
        self.h = h
        self.bay = None                 # a Bay, in a carved port (see Bay); None on an open shore
        self.front = out[1] > 0.3
        d = 0.0
        while d < 2 * R and in_hex(*self.pt(0, -d - 1)):
            d += 1
        self.depth = d

    def pt(self, u, v=0.0):
        d = self.h(u) + v
        return (self.along[0] * u + self.out[0] * d, self.along[1] * u + self.out[1] * d)

    def land(self, x, y, margin=0.0):
        u = x * self.along[0] + y * self.along[1]
        return x * self.out[0] + y * self.out[1] < self.h(u) - margin

    def at(self, u, v, du=0.0, dv=0.0):
        """The point du px along and dv px out from the shore point (u, v), on straight axes: one shore point per
        shape keeps the shape true where the shore is wavy or slanted."""
        x, y = self.pt(u, v)
        return (x + self.along[0] * du + self.out[0] * dv, y + self.along[1] * du + self.out[1] * dv)

    def rect(self, u, v, w, h):
        """A rectangle lying at the shore: centre (u, v), w px along the shore and h px across it. Returns its four
        corners in piece px (for p.patch, p.pond)."""
        return [self.at(u, v, du, dv) for du, dv in ((-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2))]

    def fits(self, u, v, tall, wide=0.0, margin=MARGIN + 0.5):
        """True if a standing thing `tall` px high and `wide` px wide with the middle of its foot at pt(u, v) stays
        inside the hex. Standing things are upright on every sea side, so with the sea behind the land (north) a
        tall thing far out to sea leaves the hex at the top: ask before you place a lighthouse or a ship."""
        x, y = self.pt(u, v)
        return all(in_hex(x + dx, y + dy, margin) for dx in (-wide / 2, wide / 2) for dy in (-tall, 1.0))

    def fit(self, u, v, tall, wide=0.0, v_min=None):
        """pt(u, v), slid back towards the shore (v growing smaller, down to v_min; default: half way) until the
        thing fits (see fits()). Returns the piece-px point, or None if it fits nowhere: then leave the thing out."""
        v_min = v * 0.5 if v_min is None else v_min
        q = v
        while q >= v_min - 1e-6:
            if self.fits(u, q, tall, wide):
                return self.pt(u, q)
            q -= 1.0
        return None

    def first(self, spots, tall, wide=0.0):
        """The first of the (u, v) spots where a thing that size fits, as (u, v), or None. For a landmark that has
        one place on most coasts and a fall-back where the hex is too short above it."""
        for u, v in spots:
            if self.fits(u, v, tall, wide):
                return (u, v)
        return None

    def __call__(self, x):
        assert abs(self.out[0]) < 1e-6 and self.out[1] > 0, "shore(x) only works with the sea in front: use shore.pt(u, v)"
        return self.h(x)


# ------------------------------------------------------------------ the carved bay (ports, guide section 10)
BAY_REACH = 19.0            # px: a carved bay moves the shore at most this far inland (5 km at this zoom): the owner's
                            # answer of 2026-11-15, for carved ports only
COVE_REACH = 13.3           # px: every other change the map makes to a coast (a cove) stays within 3.5 km
BAY_WIDTH = 72.0            # px: a bay's width, horn to horn: the same for every carved port
BAY_BACK = 13.0             # px: the back of a bay comes no nearer to the hex centre than this


def bay_profile(t):
    """How deep the bay is across its width: t = -1 and 1 are the horns, 0 the middle. A flat back over the middle
    70 per cent and a rounded shoulder up to each horn: a basin, not a notch."""
    t = abs(t)
    if t >= 1.0:
        return 0.0
    if t <= 0.7:
        return 1.0
    return 0.5 + 0.5 * math.cos((t - 0.7) / 0.3 * math.pi)


def _carved(h, u0, width, depth):
    """The shore h with a bay cut into it: the back of the bay is a straight line, depth px inland of the old
    shore at the bay's middle, whatever waves the old shore had."""
    back = h(u0) - depth
    return lambda u: h(u) - max(0.0, h(u) - back) * bay_profile((u - u0) / (width / 2.0))


def carve(sea, shore, bay):
    """FOR THE MAP: the shore of a hex with a bay carved into it, as a Shore. sea, shore: where the map has the
    sea now (as for take_apart); bay: (u0, width, depth) in px: the middle of the bay along the shore, its width
    horn to horn and how far its back lies inland of the old shore. The map turns to sea every point of the hex
    for which carve(...).land(x, y) is False, then hands the piece its new shore line and the same bay=."""
    out = sea_vector(sea)
    return Shore(out, _carved(_shore_h(shore, out), *bay))


class Bay:
    """The bay of a carved port, as shore.bay gives it to a coast piece (None on an open shore).
        bay.u0, bay.width, bay.depth    the middle (u along the shore), the width horn to horn, the depth (px)
        bay.west, bay.east              the u of the two horns (the headlands on the old coast)
        bay.pt(u, v)    the point u along the shore and v px out from the MOUTH LINE (the straight line from horn
                        to horn, where the old coast ran): moles that close the bay are laid along it
        bay.room(u)     px of water from the bay's shore out to the mouth line at u
        bay.uv(u, v)    bay.pt(u, v) as shore coordinates, for shore.fits / fit / first
    shore.pt(u, v) still measures from the water's edge, which is now the bay's own shore: a quay at v = -1 lies
    along the back of the bay by itself."""

    def __init__(self, shore, u0, width, depth):
        self.shore, self.u0, self.width, self.depth = shore, u0, width, depth
        self.west, self.east = u0 - width / 2.0, u0 + width / 2.0
        self._a, self._b = shore.h(self.west), shore.h(self.east)

    def mouth(self, u):
        """The mouth line's distance out from the hex centre at u (between the horns; the shore itself outside)."""
        if not self.west <= u <= self.east:
            return self.shore.h(u)
        return self._a + (self._b - self._a) * (u - self.west) / self.width

    def pt(self, u, v=0.0):
        s, d = self.shore, self.mouth(u) + v
        return (s.along[0] * u + s.out[0] * d, s.along[1] * u + s.out[1] * d)

    def room(self, u):
        return self.mouth(u) - self.shore.h(u)

    def uv(self, u, v=0.0):
        """The same point as bay.pt(u, v), in shore coordinates (u, v from the water's edge): for shore.fits,
        shore.fit and shore.first, which take shore coordinates."""
        return (u, self.room(u) + v)


def _shore_h(line, out):
    """h(u) for a shore line the map gives as piece-px points: the line's distance out from the centre at u."""
    along = (out[1], -out[0])
    q = sorted((x * along[0] + y * along[1], x * out[0] + y * out[1]) for x, y in line)

    def h(u):
        if u <= q[0][0]:
            return q[0][1]
        for a, b in zip(q, q[1:]):
            if u <= b[0]:
                return a[1] + (b[1] - a[1]) * (u - a[0]) / max(1e-6, b[0] - a[0])
        return q[-1][1]
    return h


# ------------------------------------------------------------------ the wild land (what the map draws)
# The generic scatter of each terrain: trees, bushes, tufts, stones, scrub patches, scree. Used on the sheets only.
WILD_MIX = {
    "farm": dict(round=4, conifer=0, bush=4, tufts=14, stones=2, scrub=3, scree=0),
    "grass": dict(round=4, conifer=1, bush=6, tufts=16, stones=3, scrub=3, scree=0),
    "wood": dict(round=8, conifer=16, bush=2, tufts=8, stones=0, scrub=0, scree=0),
    "rock": dict(round=0, conifer=2, bush=1, tufts=0, stones=4, scrub=0, scree=18),
    "sand": dict(round=0, conifer=0, bush=2, tufts=12, stones=3, scrub=0, scree=0),
}


# ------------------------------------------------------------------ the piece
class Piece:
    """One hex picture. Ground-plane calls draw at once, in call order. Standing calls are queued and drawn back to
    front (by the y of their foot) in finish()."""

    def __init__(self, season, ground="grass", seed=0, texture=True, base=None, mirror=None, sea=None, shore=None, bay=None):
        """mirror: draw the layout turned round (x to -x); every standing thing keeps its light from the upper left.
        sea, shore: where the map has the sea in this hex (see coast()). bay: the bay the map has carved for a
        port, (u0, width, depth) in px (see coast() and Bay). All default to what take_apart() was told, so a
        module that does not pass them on still follows the map.

        Winter: p.season is "winter" in every climate; p.climate is the hex's winter ("snow", "frost", "mild";
        None in the other seasons). p.winter is True where SNOW LIES (snow and frost winters): ask it before
        drawing snow. p.frozen is True where still water is frozen (the same two). In a mild winter both are False
        and the palette is the mild one; what belongs to the season and not to the snow (boats laid up, few
        animals out, smoke, bare trees) hangs on season == "winter"."""
        assert season in SEASONS, season
        self.mirror = bool(SITE.get("mirror")) if mirror is None else bool(mirror)
        self.m = -1 if self.mirror else 1
        sea = SITE.get("sea") if sea is None else sea
        line = SITE.get("shore") if shore is None else shore
        # the sea in the module's own (unmirrored) coordinates: the kit turns it round with everything else
        self.sea = None if sea is None else (lambda v: (v[0] * self.m, v[1]))(sea_vector(sea))
        self.shore_line = None if line is None else [(x * self.m, y) for x, y in line]
        bay = SITE.get("bay") if bay is None else bay
        self.bay_spec = None if not bay else (bay[0] * self.m, bay[1], bay[2])
        self.shore = None               # the Shore, once coast() is called
        self.dx = {}                    # mirrored pieces: how far each standing thing was moved
        self.box = {}                   # the bounding box of each standing thing (filled by footprint())
        self.lifted = set()
        self.claims = []                # ground the piece holds without a surface of its own (see claim())
        self.wild_done = False
        self.seed = seed
        self.season = season
        self.cold = season == "winter"                     # the season, in every climate
        self.climate = CLIMATE if self.cold else None
        self.pal = WINTER[CLIMATE] if self.cold else PAL[season]
        self.winter = self.cold and CLIMATE != "mild"      # snow lies (snow and frost winters)
        self.frozen = self.winter                          # still water is frozen
        big = (SIZE * SS, SIZE * SS)
        self.g = pygame.Surface(big, pygame.SRCALPHA)      # the ground plane
        self.sh = pygame.Surface(big)                      # soft shadows
        self.sh.fill((255, 255, 255))
        self.sh.set_colorkey((255, 255, 255))
        self.o = pygame.Surface(big, pygame.SRCALPHA)      # standing things
        self.gp = Pen(self.g, self.m)   # ground detail is flat: a mirrored piece simply draws it turned round
        self.raw = Pen(self.g)          # ... except what has a lit side (stones) and the sheet's base
        self.op = Pen(self.o)
        self.queue = []                 # (order y, n, fn); the true foot y of entry n is self.foot[n]
        self.foot = {}
        self.n = 0
        self.rnd = random.Random(seed * 7919 + 13)          # never seeded by the season: the same ground in all seasons
        self.ground_kind = ground
        self.has_base = (not NO_BASE) if base is None else base     # False: only the ground detail, for the map
        self.base(ground, texture)

    # -------------------------------------------------------------- ground plane
    def base(self, kind, texture=True):
        """The season ground: a flat fill with soft mottling. The same mottling in every season and level."""
        col = self.pal[kind]
        rnd = random.Random(self.rnd.random())          # drawn from in every case, so the scatter never shifts
        if not self.has_base:
            self.g.fill((0, 0, 0, 0))
            return
        self.g.fill(col + (255,))
        if not texture:
            return
        for i in range(26):
            x, y = rnd.uniform(-52, 52), rnd.uniform(-50, 50)
            w, h = rnd.uniform(10, 26), rnd.uniform(5, 11)
            f = 1.035 if i % 2 else 0.965
            if self.climate == "frost":              # patches of thin snow on the frosted ground
                c2 = mix(col, SNOW, 0.8) if i % 2 else shade(col, 0.965)
            elif self.winter:
                f = 1.0 if i % 2 else 0.972          # snow never goes brighter than its base, only bluer
                c2 = mix(shade(col, f), SNOW_D, 0.0 if i % 2 else 0.25)
            else:
                c2 = shade(col, f)
            self.raw.ellipse(x, y, w, h, c2)

    def tufts(self, n=14, area=None, avoid=()):
        """Grass tufts (in winter: dry stalks through the snow). `avoid` is a list of (x, y, r) to keep clear."""
        rnd = random.Random(self.rnd.random())
        col = self.pal["tuft"]
        done = 0
        for _ in range(n * 6):
            if done >= n:
                break
            x, y = rnd.uniform(-46, 46), rnd.uniform(-44, 44)
            if not in_hex(x, y, 6) or any(math.hypot(x - a[0], (y - a[1]) / TILT) < a[2] for a in avoid):
                continue
            if area and not (area[0] <= x <= area[2] and area[1] <= y <= area[3]):
                continue
            for q in (-1, 0, 1):
                self.gp.line((x + q, y), (x + q * 1.6, y - 2.2), col, 0.5)
            done += 1

    def stones(self, spots):
        """Small boulders lying on the ground. spots: [(x, y, r)]."""
        for x, y, r in spots:
            x = x * self.m                          # mirrored: the stone moves, its shaded side stays on the right
            pts = [(x + math.cos(a) * r, y + math.sin(a) * r * 0.7) for a in [q * math.pi / 3 for q in range(6)]]
            self.raw.poly(pts, (196, 186, 166) if not self.winter else SNOW, (84, 74, 68), 0.5)
            self.raw.poly([pts[0], pts[1], pts[2], (x, y)], (140, 130, 118), None)

    def patch(self, pts, col, ink=None, w=0.5):
        """A flat shape on the ground (a yard, a pan, a clearing)."""
        self.gp.poly(pts, col, ink, w)

    def over(self, fn, alpha=0.5):
        """Draw fn(pen) on the ground half-transparent (alpha 0..1), so it tints whatever ground lies under it.
        Use it for everything that is a change of the ground itself: trodden earth, scrub, tracks, yards."""
        if alpha >= 0.999:
            fn(self.gp)
            return
        lay = pygame.Surface(self.g.get_size(), pygame.SRCALPHA)
        fn(Pen(lay, self.gp.m))
        a = pygame.Surface(self.g.get_size(), pygame.SRCALPHA)
        a.fill((255, 255, 255, int(round(255 * alpha))))
        lay.blit(a, (0, 0), special_flags=pygame.BLEND_RGBA_MULT)
        self.g.blit(lay, (0, 0))

    def blob(self, x, y, w, h, col, alpha=1.0, edge=None, lw=0.5):
        """A soft ellipse on the ground, centre (x, y). alpha < 1 lays it half-transparent over the ground (use this
        for trodden or cleared ground). edge: a darker rim colour (a mound, a millstone, a clearing)."""
        self.over(lambda pen: pen.ellipse(x, y, w, h, col, edge, lw), alpha)

    def scrub(self, x, y, w, h, dark=0.07):
        """A darker patch of the ground itself (scrub, rough grass, the place where work will come): a
        half-transparent shade, so it works on any ground colour. dark 0.07 = the ground colour x 0.93."""
        self.over(lambda pen: pen.ellipse(x, y, w, h, (0, 0, 0)), dark)

    def field(self, cx, cy, w, h, angle=0.0, cols=None, strips=5, along=True, edge=None, furrows=False):
        """A block of field strips on the ground. cx, cy: centre; w, h: size before the tilt; angle in degrees.
        cols: strip colours, cycled (use kit.crop(name, season)). along=True: strips run along w.
        furrows: thin darker lines inside each strip (ploughed earth, winter furrows). Returns the corner points."""
        cols = cols or crop("wheat", self.season)
        edge = edge or (WINTER_EDGE[self.climate] if self.cold else CROP_EDGE[self.season])
        ca, sa = math.cos(math.radians(angle)), math.sin(math.radians(angle))

        def P(u, v):
            return (cx + ca * u - sa * v, cy + (sa * u + ca * v) * TILT)
        for i in range(strips):
            if along:
                v0, v1 = -h / 2 + h * i / strips, -h / 2 + h * (i + 1) / strips
                pts = [P(-w / 2, v0), P(w / 2, v0), P(w / 2, v1), P(-w / 2, v1)]
            else:
                u0, u1 = -w / 2 + w * i / strips, -w / 2 + w * (i + 1) / strips
                pts = [P(u0, -h / 2), P(u1, -h / 2), P(u1, h / 2), P(u0, h / 2)]
            c = cols[i % len(cols)]
            self.gp.poly(pts, c, None)
            if furrows:
                a = ((pts[0][0] + pts[3][0]) / 2, (pts[0][1] + pts[3][1]) / 2)
                b = ((pts[1][0] + pts[2][0]) / 2, (pts[1][1] + pts[2][1]) / 2)
                if not along:
                    a = ((pts[0][0] + pts[1][0]) / 2, (pts[0][1] + pts[1][1]) / 2)
                    b = ((pts[3][0] + pts[2][0]) / 2, (pts[3][1] + pts[2][1]) / 2)
                self.gp.line(a, b, shade(c, 0.86), 0.5)
            self.gp.poly(pts, None, mix(edge, c, 0.45), 0.5)
        corners = [P(-w / 2, -h / 2), P(w / 2, -h / 2), P(w / 2, h / 2), P(-w / 2, h / 2)]
        self.gp.poly(corners, None, edge, 0.5)
        return corners

    def rows(self, cx, cy, w, h, angle=0.0, n=6, col=None, lw=1.2, soil=None, dashed=False):
        """Plant rows (vines, vegetables) over a soil block: n lines across the block's short side, on a soil patch.
        col: the row colour (default the season's vine colour); soil: the patch colour, or False for no patch.
        dashed=True breaks each row into plants 3 px apart (young vines, level 1)."""
        col = col or crop("vine", self.season)[0]
        if soil is not False:
            self.field(cx, cy, w, h, angle, [soil or crop("vine_soil", self.season)[0]], 1)
        ca, sa = math.cos(math.radians(angle)), math.sin(math.radians(angle))

        def P(u, v):
            return (cx + ca * u - sa * v, cy + (sa * u + ca * v) * TILT)
        for i in range(n):
            u = -w / 2 + w * (i + 0.5) / n
            a, b = P(u, -h / 2 + 1), P(u, h / 2 - 1)
            if not dashed:
                self.gp.line(a, b, col, lw)
            else:
                m = max(2, int(h // 3))
                for q in range(m):
                    t = (q + 0.5) / m
                    self.gp.dot(a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, col, lw)

    def terrace(self, pts, face=0.0):
        """A dry-stone terrace wall along a line on the ground: a pale stone line with a dark foot below it.
        face > 0: the wall shows a front face that many px tall under the top line (a retaining wall seen from the
        front: olives, vineyards, any walled shelf)."""
        if face > 0:
            low = [(p[0], p[1] + face) for p in pts]
            self.gp.poly(list(pts) + low[::-1], STONE_D, None)
            self.gp.lines(low, shade(STONE_D, 0.72), 0.5)
            self.gp.lines(pts, (222, 212, 190) if not self.winter else SNOW, 1.0)
            return
        self.gp.lines([(p[0], p[1] + 0.8) for p in pts], shade(self.pal[self.ground_kind], 0.72), 1.0)
        self.gp.lines(pts, (222, 212, 190) if not self.winter else SNOW, 1.0)

    def drystone(self, pts, closed=False):
        """A dry-stone field wall along a line on the ground (upland pastures): a grey line 1 px wide with a dark
        foot and a light top, greyer and darker than a terrace wall; snow on its top where snow lies. A thin line:
        it does not count for the footprint (put a meadow patch inside it, or claim() the pasture)."""
        pts = list(pts) + ([pts[0]] if closed else [])
        self.gp.lines([(p[0], p[1] + 0.9) for p in pts], shade(STONE_GREY_D, 0.78), 1.0)
        self.gp.lines(pts, STONE_GREY, 1.2)
        self.gp.lines([(p[0], p[1] - 0.5) for p in pts], SNOW if self.winter else shade(STONE_GREY, 1.12), 0.5)

    def ring(self, cx, cy, rx, ry=None, kind="fence", gate=None, claim=True, col=None):
        """A round pen lying on the ground: a paddock ring (kind="fence": post and rail, as fence()) or a round
        sheepfold (kind="stone": a dry-stone ring, as drystone()). ry defaults to rx x TILT (a true circle on the
        ground). gate: the middle of a 4 px opening as an angle in degrees (90 = the front, 0 = the east side),
        or None. claim=True: the inside counts for the footprint (no wild tree in the pen). Returns the ring's
        points. For a meadow inside, draw it BEFORE the ring:
        p.patch(kit.ring_points(cx, cy, rx, rx * kit.TILT, 0, 2 * math.pi), colour)."""
        ry = rx * TILT if ry is None else ry
        n = max(16, int(rx * 2.2))
        if gate is None:
            a0, a1 = 0.0, 2 * math.pi
        else:
            half = 2.0 / max(1.0, rx)
            a0, a1 = math.radians(gate) + half, math.radians(gate) + 2 * math.pi - half
        pts = ring_points(cx, cy, rx, ry, a0, a1, n)
        if claim:
            self.claim(ring_points(cx, cy, rx + 1, ry + 1, 0, 2 * math.pi, n))
        if kind == "stone":
            self.drystone(pts)
        else:
            self.fence(pts, col or TIMBER_D)
        return pts

    def arc(self, cx, cy, rx, ry, a0, a1, col=None, lw=1.2, dashed=False):
        """A curved plant row on the ground (contour rows round a house): the part of the ellipse round (cx, cy)
        from angle a0 to a1 in degrees (0 = east, 90 = the front). col defaults to the season's vine colour;
        dashed=True breaks it into plants 3 px apart (young vines), as rows() does. For the soil under a band of
        arcs draw a patch between two kit.ring_points() lines first."""
        col = col or crop("vine", self.season)[0]
        ln = abs(math.radians(a1 - a0)) * (rx + ry) / 2.0
        if not dashed:
            self.gp.lines(ring_points(cx, cy, rx, ry, math.radians(a0), math.radians(a1), max(4, int(ln / 2))), col, lw)
            return
        m = max(2, int(ln // 3))
        for q in range(m):
            a = math.radians(a0 + (a1 - a0) * (q + 0.5) / m)
            self.gp.dot(cx + math.cos(a) * rx, cy + math.sin(a) * ry, col, lw)

    def scree(self, n=18, avoid=()):
        """Scree streaks and small stones for rock ground, which must never be flat grey."""
        rnd = random.Random(self.rnd.random())
        done = 0
        for _ in range(n * 6):
            if done >= n:
                break
            x, y = rnd.uniform(-46, 46), rnd.uniform(-44, 44)
            if not in_hex(x, y, 6) or any(math.hypot(x - a[0], (y - a[1]) / TILT) < a[2] for a in avoid):
                continue
            col = (198, 188, 168) if done % 2 else (128, 118, 104)
            if self.winter:
                col = SNOW if done % 2 else (150, 144, 138)
            ln = rnd.uniform(2.5, 4.5)
            self.gp.line((x, y), (x + ln * 0.35, y + ln * 0.8), col, 0.5)
            self.gp.line((x + 2, y), (x + 2 + ln * 0.3, y + ln * 0.65), col, 0.5)
            done += 1

    def jetty(self, a, b=None, w=2.2, stone=False, snow=False):
        """A timber jetty (or a stone quay or mole with stone=True) lying on the ground or water. Either from a to b,
        or along a list of points given as a (a bent mole). snow=True: a snow line on its top in winter."""
        if b is not None and not snow:
            self.gp.line(a, b, INK, w + 1.6)
            self.gp.line(a, b, STONE if stone else TIMBER, w)
            return
        pts = [a, b] if b is not None else list(a)
        col = STONE if stone else TIMBER
        for c, ww in ((INK, w + 1.6), (col, w)):
            self.gp.lines(pts, c, ww)
            for q in pts[1:-1]:                     # round the bends
                self.gp.ellipse(q[0], q[1], ww, ww, c)
        if snow and self.winter:
            self.gp.lines([(q[0], q[1] - w * 0.2) for q in pts], SNOW, max(0.5, w * 0.55))

    def hedge(self, pts, w=1.6):
        """A hedge along a line on the ground: a dark base line with a lighter top line."""
        self.gp.lines(pts, self.pal["hedge_d"], w)
        self.gp.lines([(p[0] - 0.3 * self.m, p[1] - 0.6) for p in pts], self.pal["hedge"], w * 0.55)
        if self.winter:
            self.gp.lines([(p[0] - 0.3 * self.m, p[1] - 0.9) for p in pts], SNOW, 0.5)

    def fence(self, pts, col=TIMBER_D):
        """A post-and-rail fence along a line: a thin rail with a post every 4 px."""
        self.gp.lines(pts, col, 0.5)
        for a, b in zip(pts, pts[1:]):
            d = math.dist(a, b)
            for i in range(int(d // 4) + 1):
                t = min(1.0, i * 4 / d) if d else 0
                x, y = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
                self.gp.line((x, y), (x, y - 1.6), col, 0.5)

    def road(self, pts, w=2.0, track=False):
        """A road on the ground. track=True: a thin farm track without an edge line. Snow-covered tracks stay visible."""
        col = ROAD if not self.winter else (214, 206, 190)
        if not track:
            self.gp.lines(pts, ROAD_EDGE, w + 1)
            self.gp.lines(pts, col, w)
        else:                                       # a track is worn ground: laid 75% over whatever is there
            self.over(lambda pen: pen.lines(pts, col, max(1.0, w * 0.6)), 0.75)

    def water(self, pts, w=3.0, frozen=None):
        """A stream or canal along a line. Freezes in winter unless frozen=False."""
        frozen = self.winter if frozen is None else frozen
        self.gp.lines(pts, self.pal["river_edge"] if not frozen else ICE_D, w + 1)
        self.gp.lines(pts, self.pal["river"] if not frozen else ICE, w)

    def pond(self, pts, frozen=None, ink=True, col=None, edge=None):
        """Still water as a shape (a pond, a salt pan uses patch() instead). Freezes in winter.
        col, edge: the open-water colours (default the river's); the frozen colours are always ICE."""
        frozen = self.winter if frozen is None else frozen
        col, edge = col or self.pal["river"], edge or self.pal["river_edge"]
        self.gp.poly(pts, col if not frozen else ICE, (edge if not frozen else ICE_D) if ink else None, 0.5)
        if frozen:
            a, b = pts[0], pts[len(pts) // 2]
            self.gp.line(((a[0] * 2 + b[0]) / 3, (a[1] * 2 + b[1]) / 3), ((a[0] + b[0] * 2) / 3, (a[1] + b[1] * 2) / 3), SNOW, 0.5)

    def coast(self, y0=10.0, amp=3.0, sand=4.0, seed=3):
        """The shore of this hex. Returns a Shore (see the class): lay out everything that belongs to the water's
        edge with shore.pt(u, v).

        A CARVED PORT: Piece(bay=(u0, width, depth)) or take_apart(..., bay=). The map has cut a bay into the hex;
        shore.bay then tells the piece where it lies (see Bay), and shore.pt() measures from the bay's own shore.

        THE MAP OWNS THE COAST. Where the sea lies comes from the map: Piece(sea=..., shore=...) or take_apart(...,
        sea=, shore=). sea is the side (or sides, or an angle) the sea is on; shore is the map's shore line through
        the hex as piece-px points. On the map nothing is drawn here: the map has its own sea, sand and foam.

        On the sheets (no map) the kit draws a sea so the piece can be judged: a sand strip, the shallows, the sea,
        a foam line. Without sea= it lies in front (south), below a wavy line at about y0, as before; with a side
        and no shore line it lies y0 px out from the centre on that side. The sea never freezes."""
        rnd = random.Random(seed)
        ph = [rnd.uniform(0, 6.28) for _ in range(3)]
        out = self.sea or SIDES["S"]
        if self.shore_line:
            h = _shore_h(self.shore_line, out)          # the map's line: a carved bay is already in it
        else:
            def h(u):
                return y0 + amp * (math.sin(u * 0.07 + ph[0]) * 0.6 + math.sin(u * 0.17 + ph[1]) * 0.3 + math.sin(u * 0.4 + ph[2]) * 0.1)
            if self.bay_spec:                           # the sheets: the kit carves the stand-in shore itself,
                u0, bw, bd = self.bay_spec              # the back of the bay lying where the open shore lay
                h = _carved(lambda u, h=h: h(u) + bd, u0, bw, bd)
        shore = self.shore = Shore(out, h)
        if self.bay_spec:
            shore.bay = Bay(shore, *self.bay_spec)
        if not self.has_base:
            return shore
        line = [shore.pt(u) for u in range(-90, 92, 2)]
        far = (out[0] * 170, out[1] * 170)

        def body(v):
            pts = [(x + out[0] * v, y + out[1] * v) for x, y in line]
            return pts + [(pts[-1][0] + far[0], pts[-1][1] + far[1]), (pts[0][0] + far[0], pts[0][1] + far[1])]
        if sand:
            self.gp.poly(body(-sand), self.pal["sand"], None)
        self.gp.poly(body(0), self.pal["shallow"], None)
        self.gp.poly(body(5), self.pal["sea"], None)
        self.gp.lines(line, self.pal["foam"], 1)
        for wx, wy in ((-30, 12), (8, 20), (30, 9), (-8, 30)):       # little wave marks, as in the style frame
            x, y = shore.pt(wx, 8 + wy)
            if in_hex(x, y, 8):
                self.gp.lines([(x - 3, y), (x - 1.5, y - 0.8), (x, y), (x + 1.5, y - 0.8), (x + 3, y)], mix(self.pal["sea"], self.pal["foam"], 0.45), 0.5)
        return shore

    def snow_patch(self, x, y, w, h):
        """A drift of snow on the ground (winter only; does nothing in other seasons)."""
        if self.winter:
            self.gp.ellipse(x, y, w, h, SNOW)

    def claim(self, pts):
        """Ground this piece holds although nothing is drawn on it: the polygon counts for the footprint, so the
        map keeps its wild trees out. The kit claims the inside of every ring wall; use it for a court, a square
        or a gap between two works that must stay open. Draws nothing."""
        self.claims.append([(x * self.m, y) for x, y in pts])

    # -------------------------------------------------------------- shadows
    def shadow(self, x, y, w, h):
        """A soft ground shadow: an ellipse centred on (x, y). Standing primitives add their own."""
        r = pygame.Rect(0, 0, max(1, int(w * SS)), max(1, int(h * SS)))
        r.center = Pen.T((x * self.m, y))
        pygame.draw.ellipse(self.sh, SHADOW, r)

    def cast(self, x, y, w, h=None):
        """The usual shadow of a standing thing whose foot is w wide: lower right of the foot (also when the piece
        is mirrored: the foot moves, the shadow still falls to the lower right)."""
        self.shadow(x + self.m * w * 0.35, y + 0.6, w * 1.5, h or max(2.0, w * 0.5))

    # -------------------------------------------------------------- standing things
    def stand(self, y, fn, lift=0.0, x=None, on=None):
        """Queue fn(pen) to be drawn at depth y (the y of the thing's foot). Use for a family's own landmarks.
        lift: draw it that many px later in the order than its foot says (smoke: it must lie over its chimney).
        Returns a handle for on=.

        In a mirrored piece the thing is MOVED to its mirrored place and drawn as it is, so it stays lit from the
        upper left. The kit finds the place itself (the middle of the thing's picture goes from x to -x). Give x=
        if the thing should turn round another axis (the x of its foot), or on=<handle of another thing> if it
        belongs to that thing and must move with it (smoke on an off-centre chimney, a wheel on a mill)."""
        n = self.n
        if self.mirror:
            if on is not None:
                dx = self.dx.get(on, 0.0)
            else:
                dx = -2.0 * (x if x is not None else self._middle(fn))
            dx = round(dx * SS) / SS                    # whole 2x pixels: the thing is drawn exactly as unmirrored
            self.dx[n] = dx
            if dx:
                fn = (lambda f, d: lambda pen: f(Pen(pen.s, 1, d + pen.dx)))(fn, dx)
        self.queue.append((y + lift, n, fn))
        self.foot[n] = y
        if lift:
            self.lifted.add(n)
        self.n += 1
        return n

    _scratch = None

    def _bounds(self, fn):
        """The bounding box of what fn draws, in piece px: (left, top, right, bottom), or None."""
        if Piece._scratch is None:
            Piece._scratch = pygame.Surface((SIZE * SS, SIZE * SS), pygame.SRCALPHA)
        sc = Piece._scratch
        sc.fill((0, 0, 0, 0))
        fn(Pen(sc))
        r = sc.get_bounding_rect()
        if not r.width:
            return None
        return (r.left / SS - C, r.top / SS - C, r.right / SS - C, r.bottom / SS - C)

    def _middle(self, fn):
        b = self._bounds(fn)
        return 0.0 if b is None else (b[0] + b[2]) / 2.0

    def footprint(self, grow=3, front=10):
        """The area this piece works, as a pygame.mask.Mask of the piece canvas at 100% (SIZE x SIZE; the piece-px
        point (x, y) is mask pixel (x + C, y + C); test it with kit.in_footprint). The map draws no wild tree,
        bush or scrub whose foot lies in it.

        It is: the ground detail that is a real surface (fields, plots, pans, yards, trodden ground; thin lines such
        as tracks, fences and tufts and faint scrub overlays do not count), grown by `grow` px; and the foot of
        every standing thing, 2 px to each side and up to `front` px in front of it (so nothing wild stands in
        front of a building); and what the piece claims (claim(): the inside of a ring wall). Smoke does not count. Only for a piece drawn without its base (take_apart())."""
        assert not self.has_base, "footprint() needs the piece without its ground base: use kit.take_apart()"
        small = pygame.transform.smoothscale(self.g, (SIZE, SIZE))
        work = pygame.mask.from_surface(small, 60)
        work = _grow(_shrink(work, 1), 1 + grow)
        if self.claims:
            lay = pygame.Surface((SIZE, SIZE), pygame.SRCALPHA)
            for pts in self.claims:
                pygame.draw.polygon(lay, (255, 255, 255, 255), [(x + C, y + C) for x, y in pts])
            work.draw(pygame.mask.from_surface(lay, 127), (0, 0))
        for y, n, fn in self.queue:
            if n in self.lifted:
                continue
            if n not in self.box:
                self.box[n] = self._bounds(fn)
            b = self.box[n]
            if b is None:
                continue
            fy = min(self.foot[n], b[3])
            ahead = min(front, 2 + 0.8 * (b[3] - b[1]))
            r = pygame.Rect(0, 0, int(round(b[2] - b[0] + 4)), int(round(3 + ahead)))
            r.midtop = (int(round((b[0] + b[2]) / 2 + C)), int(round(fy - 3 + C)))
            r = r.clip(pygame.Rect(0, 0, SIZE, SIZE))
            if r.width and r.height:
                work.draw(pygame.mask.Mask(r.size, fill=True), r.topleft)
        return work

    def layers(self):
        """The piece taken apart for the map (see take_apart()):
        'ground'    the ground-plane layer at 2x (with base=False: only the detail, transparent elsewhere), not yet
                    feathered at the hex border;
        'shadow'    the 2x shadow layer (white = none; blend it with SHADOW_ALPHA);
        'standing'  the standing things, back to front: (foot_y, order_y, fn), fn(pen) draws one of them;
        'footprint' the area the piece works (see footprint()): the map thins its wild land there;
        'shore'     the Shore the piece built at, or None;
        'mirror'    True if the piece is drawn mirrored (mirror the module's GATES with kit.mirror_gates)."""
        st = [(self.foot[q[1]], q[0], q[2]) for q in sorted(self.queue, key=lambda q: (q[0], q[1]))]
        return {"ground": self.g, "shadow": self.sh, "standing": st, "footprint": None if self.has_base else self.footprint(),
                "shore": self.shore, "mirror": self.mirror}

    def wild(self, thin=None, mix=None):
        """The wild land of this piece's terrain, as the map draws it: a generic scatter of trees, bushes, tufts,
        stones and scrub (WILD_MIX). FOR THE SHEETS ONLY: on the map the map draws it. thin: a footprint mask;
        nothing wild is drawn where it is set. The scatter depends on the terrain and the seed only, so the same
        wild things stand at every level and the work thins them. It is never mirrored: it belongs to the map."""
        self.wild_done = True
        k = dict(WILD_MIX[self.ground_kind])
        k.update(mix or {})
        rnd = random.Random("wild %s %d" % (self.ground_kind, self.seed))
        m = self.m

        def free(x, y):
            if thin is not None and 0 <= int(x + C) < SIZE and 0 <= int(y + C) < SIZE and thin.get_at((int(x + C), int(y + C))):
                return False
            return self.shore is None or self.shore.land(x * m, y, 3)

        def spots(n, room_x, room_y, half, tall, taken, margin=MARGIN + 1.5):
            got = []
            for _ in range(n * 40):
                if len(got) >= n:
                    break
                x, y = rnd.uniform(-48, 48), rnd.uniform(-44, 46)
                if not (in_hex(x - half, y + 1, margin) and in_hex(x + half, y + 1, margin) and in_hex(x - half * 0.7, y - tall, margin)
                        and in_hex(x + half * 0.7, y - tall, margin)):
                    continue
                if any(abs(x - q[0]) < room_x and abs(y - q[1]) < room_y for q in taken + got):
                    continue
                got.append((x, y))
            return got
        for x, y in spots(k["scrub"], 26, 12, 13, 5, []):            # rough ground, as an overlay
            w, h = rnd.uniform(22, 30), rnd.uniform(9, 13)
            if free(x, y):
                keep, self.gp = self.gp, self.raw
                try:
                    self.scrub(x, y, w, h, 0.07)
                finally:
                    self.gp = keep
        col = self.pal["tuft"]
        for x, y in spots(k["tufts"], 5, 3, 2, 3, [], 6):
            if free(x, y):
                for q in (-1, 0, 1):
                    self.raw.line((x + q, y), (x + q * 1.6, y - 2.2), col, 0.5)
        for i, (x, y) in enumerate(spots(k["scree"], 5, 3, 2, 1, [], 6)):
            if free(x, y):
                c = (198, 188, 168) if i % 2 else (128, 118, 104)
                if self.winter:
                    c = SNOW if i % 2 else (150, 144, 138)
                ln = rnd.uniform(2.5, 4.5)
                self.raw.line((x, y), (x + ln * 0.35, y + ln * 0.8), c, 0.5)
                self.raw.line((x + 2, y), (x + 2 + ln * 0.3, y + ln * 0.65), c, 0.5)
        stones = [(x, y, rnd.uniform(1.5, 2.2)) for x, y in spots(k["stones"], 10, 6, 3, 2, [])]
        self.stones([(x * m, y, r) for x, y, r in stones if free(x, y)])
        n_all = k["round"] + k["conifer"]
        dense = n_all > 12
        trees = spots(n_all, 9 if dense else 13, 6 if dense else 9, 4.5, 12.5, [])
        for i, (x, y) in enumerate(trees):
            kind = "conifer" if (i * 7 + 3) % max(1, n_all) < k["conifer"] else "round"
            sc = 0.85 + 0.15 * ((i * 5) % 4) / 3.0
            if free(x, y):
                self.tree(x * m, y, sc, kind, i)
        for i, (x, y) in enumerate(spots(k["bush"], 9, 6, 3, 4, trees)):
            if free(x, y):
                self.tree(x * m, y, 1.0, "bush", i)

    def tree(self, x, y, sc=1.0, kind="round", i=0):
        """A tree with its foot at (x, y). kind: 'round' (broadleaf), 'conifer', 'poplar' (tall, thin), 'bush',
        'olive' (silver green, evergreen), 'fruit' (small, blossom in spring), 'mulberry' (a low pollarded crown on
        a pale stem, no blossom: silk's planted rows). i: the tree's index (autumn colour mix)."""
        season, pal, winter, bare = self.season, self.pal, self.winter, self.cold
        self.cast(x, y, {"conifer": 4.5, "poplar": 3.5, "bush": 4.0}.get(kind, 5.5) * sc)

        def fn(p):
            if kind == "conifer":
                oc, lit, dk = pal["conifer"]
                h, w = 12.5 * sc, 7.2 * sc
                p.line((x, y), (x, y - 2.5 * sc), TRUNK, 1.3 * sc)
                pts = [(x, y - h), (x + w / 2, y - 2 * sc), (x - w / 2, y - 2 * sc)]
                p.poly(pts, lit, None)
                p.poly([(x, y - h), (x + w / 2, y - 2 * sc), (x + w * 0.06, y - 2 * sc)], dk, None)
                if winter:      # snow lies on the lit (left) side
                    p.poly([(x, y - h), (x - w * 0.5, y - 2 * sc), (x - w * 0.16, y - 2 * sc), (x - w * 0.02, y - h * 0.5)], SNOW, None)
                p.poly(pts, None, oc, 0.5)
                return
            if kind == "poplar":
                oc, dk, mid, lt = pal["leaf"] if season != "autumn" else LEAF_AUTUMN[1]
                h, w = 15 * sc, 4.2 * sc
                p.line((x, y), (x, y - 3 * sc), TRUNK, 1.0 * sc)
                if bare:
                    for q in (-1, 0, 1):
                        p.line((x, y - 3 * sc), (x + q * 1.4 * sc, y - h), TRUNK, 0.5)
                    return
                p.ellipse(x, y - 2 * sc - h * 0.45, w + 1, h * 0.9 + 1, oc)
                p.ellipse(x, y - 2 * sc - h * 0.45, w, h * 0.9, dk)
                p.ellipse(x - w * 0.16, y - 2 * sc - h * 0.5, w * 0.56, h * 0.7, mid)
                return
            if kind == "olive":
                r = 3.4 * sc
                cy = y - 2.2 * sc - r * 0.6
                p.line((x, y), (x + 0.5, y - 2.4 * sc), (104, 88, 70), 1.2 * sc)
                p.ellipse(x, cy, r * 2 + 1, r * 1.5 + 1, (62, 78, 62))
                p.ellipse(x, cy, r * 2, r * 1.5, (122, 142, 104))
                p.ellipse(x - r * 0.3, cy - r * 0.22, r * 1.2, r * 0.8, (168, 182, 142) if not winter else SNOW)
                return
            r = {"round": 4.4, "bush": 2.6, "fruit": 3.2, "mulberry": 2.8}[kind] * sc
            th = {"round": 3.0, "bush": 0.6, "fruit": 2.4, "mulberry": 2.8}[kind] * sc
            if kind == "mulberry":              # pollarded: a pale stem and a flat low crown; autumn gold and late green by turns
                p.line((x, y), (x, y - th), (176, 160, 132), 1.2 * sc)
                if bare:
                    for dx in (-0.8, -0.3, 0.3, 0.8):
                        p.line((x, y - th), (x + dx * r, y - th - r * 0.9), pal["leaf"][0], 0.6)
                    if winter:
                        p.line((x - r * 0.6, y - th - 0.4), (x + r * 0.3, y - th - 0.4), SNOW, 0.5)
                    return
                oc, dk, mid, lt = pal["leaf"] if season != "autumn" else LEAF_AUTUMN[1 + i % 2]
                p.ellipse(x, y - th - r * 0.45, r * 2 + 1, r * 1.3 + 1, oc)
                p.ellipse(x, y - th - r * 0.45, r * 2, r * 1.3, mid)
                p.ellipse(x - r * 0.25, y - th - r * 0.6, r * 1.2, r * 0.7, lt)
                return
            cy = y - th - r * 0.75
            if kind != "bush":
                p.line((x, y), (x, y - th - (r * 0.4 if not bare else 0)), TRUNK, 1.4 * sc)
            if bare:            # bare twigs with a dab of snow; a bush is a snow mound with twigs
                if kind == "bush":
                    if not winter:                  # a mild winter: a bare brown thicket, no snow
                        p.ellipse(x, y - r * 0.6, r * 2, r * 1.3, pal["hedge_d"])
                        p.ellipse(x - r * 0.2, y - r * 0.75, r * 1.5, r * 0.9, pal["hedge"])
                        return
                    p.ellipse(x, y - r * 0.6, r * 2, r * 1.3, SNOW_D)
                    p.ellipse(x - r * 0.2, y - r * 0.75, r * 1.5, r * 0.9, SNOW)
                    return
                for dx, dy in ((-0.9, -0.5), (-0.45, -1.0), (0.1, -1.15), (0.6, -0.95), (0.95, -0.45)):
                    p.line((x, y - th), (x + dx * r, y - th + dy * r * 1.25), pal["leaf"][0], 0.8)
                if winter:
                    p.line((x - r * 0.7, y - th - r * 0.75), (x - r * 0.1, y - th - r * 1.3), SNOW, 0.5)
                return
            oc, dk, mid, lt = pal["leaf"] if season != "autumn" else LEAF_AUTUMN[i % 3]
            p.circle(x, cy, r + 0.5, oc)
            p.circle(x, cy, r, dk)
            p.circle(x - r * 0.28, cy - r * 0.28, r * 0.66, mid)
            p.circle(x - r * 0.45, cy - r * 0.45, r * 0.26, lt)
            if kind == "fruit" and pal["blossom"]:
                for dx, dy in ((-0.5, -0.3), (0.3, -0.5), (0.1, 0.3), (-0.2, 0.5), (0.55, 0.15)):
                    p.dot(x + dx * r, cy + dy * r, pal["blossom"], 1.0)
        return self.stand(y, fn, x=x)

    def house(self, x, y, w=7.0, h=4.6, roof_h=3.6, wall=0, kind="ridge", roof="tile", door=True, smoke=False):
        """A house with the middle of its foot at (x, y). kind: 'ridge' (roof slope faces the viewer) or 'gable'
        (gable to the front). roof: 'tile', 'thatch' or 'slate'. wall: an index into PLASTER, or a colour.
        Winter puts snow on the roof. smoke=True adds chimney smoke in autumn and winter only."""
        wallc = PLASTER[wall % len(PLASTER)] if isinstance(wall, int) else wall
        r1, r2 = {"tile": (ROOF, ROOF_D), "thatch": (THATCH, THATCH_D), "slate": (SLATE, SLATE_D)}[roof]
        eave_l = r1
        if self.winter:
            r1, r2 = SNOW, SNOW_D
        self.cast(x, y, w)
        smoky = smoke and self.season in ("autumn", "winter")

        def fn(p):
            x0, top = x - w / 2, y - h
            if kind == "ridge":
                p.rect(x0, top, w, h, wallc, None)
                p.rect(x0 + w * 0.78, top, w * 0.22, h, shade(wallc, 0.84), None)
                rf = [(x0 - 1, top + 0.3), (x0 + w + 1, top + 0.3), (x0 + w - 0.6, top - roof_h), (x0 + 0.6, top - roof_h)]
                p.poly(rf, r1, None)
                p.poly([rf[1], rf[2], (x0 + w * 0.72, top - roof_h), (x0 + w * 0.78, top + 0.3)], r2, None)
                if self.winter:                 # the eave keeps the roof colour: a 1 px band, so roofs stay roofs
                    p.poly([rf[0], rf[1], (rf[1][0] - 0.3, rf[1][1] - 1.1), (rf[0][0] + 0.3, rf[0][1] - 1.1)], eave_l, None)
                p.poly(rf, None, INK, 0.5)
            else:
                p.rect(x0, top, w, h, wallc, None)
                p.poly([(x0, top), (x0 + w / 2, top - roof_h), (x0 + w, top)], wallc, None)
                slope = [(x0 + w / 2, top - roof_h), (x0 + w / 2 + 2.6, top - roof_h - 2.2), (x0 + w + 2.8, top - 2.2), (x0 + w + 0.6, top + 0.4)]
                p.poly(slope, r2, INK, 0.5)
                if self.winter:
                    p.line((slope[3][0] + 0.2, slope[3][1] - 0.5), (slope[2][0] - 0.2, slope[2][1] - 0.5), eave_l, 1.0)
                p.line((x0 - 0.6, top + 0.4), (x0 + w / 2, top - roof_h), r1, 1.4)
                p.line((x0, top), (x0 + w / 2, top - roof_h), INK, 0.5)
            if door:
                p.rect(x0 + w * 0.4, y - 2.2, 1.4, 2.2, DOOR, None)
            p.rect(x0, top, w, h, None, INK, 0.5)
            if smoky:
                _smoke(p, x + w * 0.2, top - roof_h - 0.5, self.winter)
        return self.stand(y, fn, x=x)

    def smoke(self, x, y, always=False, foot=None, on=None):
        """Chimney smoke rising from (x, y). Autumn and winter only, unless always=True (the listed chimneys: the
        smelter, the charcoal mound). Grey in winter so it shows on snow. foot: the foot y of the thing that smokes.
        on: the handle of the thing that smokes (what p.stand or a kit call returned); give it when the chimney is
        not in the middle of that thing, so the smoke stays on the chimney in the mirrored piece."""
        if always or self.season in ("autumn", "winter"):
            fy = y if foot is None else foot
            return self.stand(fy, lambda p: _smoke(p, x, y, self.winter), lift=y + 30 - fy, x=x, on=on)

    def church(self, x, y, size="church", sc=1.0):
        """size: 'chapel' (village), 'church' (town), 'cathedral' (city: a dome and a tall bell tower).
        (x, y) is the middle of the nave's foot; the tower stands to the right. sc scales the whole building."""
        big = size != "chapel"
        w, hw = ((9, 6) if big else (6, 4.5))
        w, hw = w * sc, hw * sc
        th = {"chapel": 8, "church": 13, "cathedral": 17}[size] * sc
        r1, r2 = (ROOF, ROOF_D) if not self.winter else (SNOW, SNOW_D)
        self.cast(x + 2 if not self.mirror else x + 3.5 * sc - 2, y, w + 5 * sc)     # the tower stays on the right

        def fn(p):
            rh = 3.5 * sc
            p.rect(x - w / 2, y - hw, w, hw, CHURCH, None)
            p.rect(x + w * 0.28, y - hw, w * 0.22, hw, shade(CHURCH, 0.86), None)
            rf = [(x - w / 2 - 0.5, y - hw), (x + w / 2 + 0.5, y - hw), (x + w / 2 - 0.5, y - hw - rh), (x - w / 2 + 0.5, y - hw - rh)]
            p.poly(rf, r1, INK, 0.5)
            if self.winter:
                p.poly([rf[0], rf[1], (rf[1][0] - 0.3, rf[1][1] - 1.1), (rf[0][0] + 0.3, rf[0][1] - 1.1)], ROOF, None)
                p.poly(rf, None, INK, 0.5)
            p.rect(x - w / 2, y - hw, w, hw, None, INK, 0.5)
            p.rect(x - 0.8 * sc, y - 2.6 * sc, 1.6 * sc, 2.6 * sc, DOOR, None)
            if size == "cathedral":
                cx, cy = x, y - hw - rh
                dr = 4.2 * sc                                   # the dome on its drum
                p.ellipse(cx, cy - 3 * sc, dr * 2 + 1, dr * 2 + 1, INK)
                p.ellipse(cx, cy - 3 * sc, dr * 2, dr * 2, DOME if not self.winter else SNOW_D)
                p.ellipse(cx - dr * 0.25, cy - 3 * sc - dr * 0.25, dr * 1.2, dr * 1.2, DOME_L if not self.winter else SNOW)
                p.rect(cx - 3.6 * sc, cy - 3 * sc, 7.2 * sc, 3 * sc, CHURCH, INK, 0.5)
                p.line((cx, cy - 3 * sc - dr), (cx, cy - 3 * sc - dr - 2.2 * sc), INK, 0.5)
            tx = x + w / 2 + 1.5 * sc
            tw = 4 * sc
            p.rect(tx - tw / 2, y - th, tw, th, CHURCH, None)
            p.rect(tx + tw * 0.15, y - th, tw * 0.35, th, shade(CHURCH, 0.85), None)
            cap = [(tx - tw / 2 - 0.6, y - th), (tx + tw / 2 + 0.6, y - th), (tx, y - th - 4 * sc)]
            p.poly(cap, ROOF_D if not self.winter else SNOW_D, INK, 0.5)
            p.rect(tx - tw / 2, y - th, tw, th, None, INK, 0.5)
            p.rect(tx - 0.5 * sc, y - th + 1.5 * sc, 1 * sc, 1.8 * sc, DOOR, None)
        return self.stand(y, fn, x=x + 1.75 * sc)

    def tower(self, x, y, w=4.2, h=9.0, col=STONE, top="battlement", flag=None, roof=SLATE):
        """A tower with the middle of its foot at (x, y). top: 'battlement', 'cone' (a pointed roof) or 'flat'.
        flag: a colour for a small banner, or None."""
        self.cast(x, y, w + 1)

        def fn(p):
            p.box(x, y, w, h, col, None)
            if top == "battlement":
                p.rect(x - w / 2 - 0.5, y - h - 1.4, w + 1, 1.6, col, INK, 0.5)
                for q in (-1, 0, 1):
                    p.rect(x + q * (w / 2) - 0.5, y - h - 2.4, 1.0, 1.0, col if not self.winter else SNOW, None)
            elif top == "cone":
                rc = roof if not self.winter else SNOW_D
                p.poly([(x - w / 2 - 0.6, y - h), (x + w / 2 + 0.6, y - h), (x, y - h - w * 0.95)], rc, INK, 0.5)
                if self.winter:
                    p.poly([(x - w / 2 - 0.6, y - h), (x, y - h), (x, y - h - w * 0.95)], SNOW, None)
            p.rect(x - w / 2, y - h, w, h, None, INK, 0.5)
            if h >= 8:
                p.rect(x - 0.4, y - h * 0.62, 0.8, 1.6, DOOR, None)
            if flag:
                ty = y - h - (2.4 if top == "battlement" else w * 0.95 if top == "cone" else 0)
                p.line((x, ty), (x, ty - 4.5), INK, 0.5)
                p.poly([(x, ty - 4.5), (x + 3.2, ty - 3.6), (x, ty - 2.6)], flag, None)
        return self.stand(y, fn, x=x)

    def wall(self, cx, cy, rx, ry, kind="stone", towers=(0.25, 0.5, 0.75), gate=0.5, back_towers=(), height=4.0, col=None):
        """A ring wall round (cx, cy). kind: 'palisade' (timber stakes, no towers unless asked) or 'stone'
        (battlements). towers and gate are positions along the front half, 0 = right end, 1 = left end
        (0.5 = the middle of the front). The back half is queued behind everything inside, the front half before it."""
        col = col or (STONE if kind == "stone" else TIMBER)       # col=STONE_GREY for castles
        if self.mirror:                                           # the ring is moved; its towers and gate change ends
            towers, back_towers = [1 - a for a in towers], [1 - a for a in back_towers]
            gate = None if gate is None else 1 - gate
        back = ring_points(cx, cy, rx, ry, math.pi, 2 * math.pi)
        front = ring_points(cx, cy, rx, ry, 0, math.pi)
        hw = height
        self.shadow(cx + self.m * rx * 0.2, cy + ry * 0.35, rx * 2.3, ry * 2.0)
        self.claim(ring_points(cx, cy, rx + 2, ry + 2, 0, 2 * math.pi))       # no wild tree inside or on the wall

        def stakes(p, pts, c):
            for q in range(0, len(pts), 1):
                a = pts[q]
                p.line((a[0], a[1] - hw + 0.4), (a[0], a[1] - hw - 0.9), c, 0.5)

        def fb(p):
            top = [(a[0], a[1] - hw) for a in back]
            p.poly(back + top[::-1], shade(col, 0.82), None)
            if kind == "palisade":
                stakes(p, back, shade(col, 0.7))
            p.lines(top, INK if kind == "stone" else TIMBER_D, 0.5)
            for a in back_towers:
                q = back[int(len(back) * a)]
                p.box(q[0], q[1], 3.6, hw + 3, shade(col, 0.9), INK)

        def ff(p):
            top = [(a[0], a[1] - hw) for a in front]
            p.poly(front + top[::-1], col, None)
            if kind == "stone":
                for q in range(0, len(front), 3):
                    a = top[q]
                    p.rect(a[0] - 0.8, a[1] - 1.4, 1.6, 1.5, col if not self.winter else SNOW, None)
            else:
                stakes(p, front, TIMBER_D)
                for q in range(2, len(front), 4):
                    a = front[q]
                    p.line((a[0], a[1] - hw + 0.8), (a[0], a[1] - 0.4), TIMBER_D, 0.5)
            p.lines(top, INK, 0.5)
            p.lines(front, INK, 0.5)
            for a in towers:
                q = front[int((len(front) - 1) * a)]
                tw, th = 4.2, hw + 3.5
                p.box(q[0], q[1], tw, th, col, INK)
                if self.winter:
                    p.rect(q[0] - tw / 2, q[1] - th - 0.6, tw, 1.0, SNOW, None)
            if gate is not None:
                q = front[int((len(front) - 1) * gate)]
                p.rect(q[0] - 1.6, q[1] - 3.0, 3.2, 3.0, DOOR, None)
                if kind == "palisade":
                    p.rect(q[0] - 2.4, q[1] - hw - 1.6, 4.8, 1.2, TIMBER_D, None)
        self.stand(cy - ry - 0.5, fb, x=cx)
        return self.stand(cy + ry + 0.5, ff, x=cx)

    def boat(self, x, y, sc=1.0, sail=True):
        """A ship or boat with its keel at (x, y). sc 1.0 = a trading ship (12 px long, 13 tall); 0.7 = a fishing
        boat; 0.55 = a small boat drawn up on the beach. sail=False: a bare mast (boats laid up in winter)."""
        def fn(p):
            k = sc
            hull = [(x - 6 * k, y - 3 * k), (x + 6 * k, y - 3 * k), (x + 4 * k, y), (x - 4 * k, y)]
            p.poly(hull, HULL, INK, 0.5)
            p.line((x, y - 3 * k), (x, y - 13 * k), INK, 0.5)
            if sail:
                sl = [(x - 4.2 * k, y - 11.5 * k), (x + 4.2 * k, y - 11.5 * k), (x + 3.6 * k, y - 5 * k), (x - 3.6 * k, y - 5 * k)]
                p.poly(sl, SAIL, None)
                p.poly([(x + 0.5 * k, y - 11.5 * k), sl[1], sl[2], (x + 0.5 * k, y - 5 * k)], SAIL_D, None)
                p.poly(sl, None, INK, 0.5)
            p.line((x - 7 * k, y + 0.5), (x - 3 * k, y + 0.5), (240, 244, 248), 0.5)
        return self.stand(y, fn, x=x)

    def person(self, x, y, col=(196, 72, 60)):
        """A person as a dot: 1 px wide, 3 px tall (a dark head on a coloured body)."""
        def fn(p):
            p.rect(x - 0.6, y - 2.4, 1.2, 2.4, col, None)
            p.rect(x - 0.6, y - 3.4, 1.2, 1.1, INK, None)
        return self.stand(y, fn, x=x)

    def animal(self, x, y, kind="sheep", flip=False, sc=1.0, col=None):
        """An animal as a blob: 'sheep' (white, 3x2), 'cow' (brown and white, 4x2.5), 'horse' (dark, 4x3 on legs).
        sc: 0.7 for a young one. col: another coat colour."""
        if self.mirror:                 # the animal moves and looks the other way (that is not lighting)
            flip = not flip
        d = -1 if flip else 1
        if sc != 1.0 or col is not None:
            def fy(p):
                body = col or {"sheep": (250, 248, 240), "cow": (150, 92, 60), "horse": (96, 66, 50)}[kind]
                if kind == "horse":
                    p.line((x - 1.2 * sc, y), (x - 1.2 * sc, y - 1.6 * sc), INK, 0.5)
                    p.line((x + 1.2 * sc, y), (x + 1.2 * sc, y - 1.6 * sc), INK, 0.5)
                    p.ellipse(x, y - 2.4 * sc, 4.4 * sc, 2.2 * sc, body, INK, 0.5)
                    p.line((x + 1.8 * d * sc, y - 2.8 * sc), (x + 2.6 * d * sc, y - 4.4 * sc), body, 1.0)
                else:
                    if kind == "sheep":
                        _sheep(p, x, y, d, sc, body)
                        return
                    w, h = 4.4, 2.6
                    p.ellipse(x, y - h * sc * 0.58, w * sc, h * sc, body, INK, 0.5)
                    p.dot(x + w * 0.48 * d * sc, y - h * sc * 0.75, shade(body, 0.72), 1.0)
            return self.stand(y, fy, x=x)

        def fn(p):
            if kind == "sheep":
                _sheep(p, x, y, d, 1.0, (250, 248, 240) if not self.winter else (226, 218, 200))
            elif kind == "cow":
                p.ellipse(x, y - 1.6, 4.4, 2.6, (150, 92, 60), INK, 0.5)
                p.dot(x - 0.6 * d, y - 1.8, (240, 232, 220), 1.2)
                p.dot(x + 2.2 * d, y - 2.2, (110, 66, 44), 1.4)
            else:
                p.line((x - 1.2, y), (x - 1.2, y - 1.6), INK, 0.5)
                p.line((x + 1.2, y), (x + 1.2, y - 1.6), INK, 0.5)
                p.ellipse(x, y - 2.4, 4.4, 2.2, (96, 66, 50), INK, 0.5)
                p.line((x + 1.8 * d, y - 2.8), (x + 2.6 * d, y - 4.4), (96, 66, 50), 1.0)
        return self.stand(y, fn, x=x)

    def haystack(self, x, y, sc=1.0):
        """A round haystack (a snow-capped mound in winter)."""
        self.cast(x, y, 4 * sc)

        def fn(p):
            w, h = 4.6 * sc, 4.6 * sc
            pts = [(x - w / 2, y), (x - w / 2, y - h * 0.45), (x, y - h), (x + w / 2, y - h * 0.45), (x + w / 2, y)]
            p.poly(pts, (226, 196, 110), None)
            p.poly([(x + w * 0.12, y), (x + w * 0.08, y - h * 0.9), (x + w / 2, y - h * 0.45), (x + w / 2, y)], (190, 158, 86), None)
            if self.winter:
                p.poly([(x - w / 2, y - h * 0.45), (x, y - h), (x + w / 2, y - h * 0.45), (x, y - h * 0.62)], SNOW, None)
            p.poly(pts, None, (110, 84, 50), 0.5)
        return self.stand(y, fn, x=x)

    def heap(self, x, y, w, h, col, col_d=None, ink=INK):
        """A cone-shaped heap (salt, spoil, grain, charcoal): two-tone, lit from the left. Snow-capped in winter."""
        col_d = col_d or shade(col, 0.8)
        self.cast(x, y, w * 0.8)

        def fn(p):
            pts = [(x - w / 2, y), (x - w * 0.12, y - h), (x + w * 0.12, y - h), (x + w / 2, y)]
            p.poly(pts, col, None)
            p.poly([(x + w * 0.02, y - h), (x + w * 0.12, y - h), (x + w / 2, y), (x + w * 0.1, y)], col_d, None)
            if self.winter:
                p.poly([(x - w * 0.3, y - h * 0.55), (x - w * 0.12, y - h), (x + w * 0.12, y - h), (x + w * 0.28, y - h * 0.6), (x, y - h * 0.72)], SNOW, None)
            p.poly(pts, None, ink, 0.5)
        return self.stand(y, fn, x=x)

    def logs(self, x, y, n=3, w=7.0):
        """A pile of n logs lying across, seen from the side with their cut ends to the right."""
        self.cast(x, y, w)

        def fn(p):
            for i in range(n):
                yy = y - i * 1.5
                ww = w - i * 1.2
                p.rect(x - ww / 2, yy - 1.6, ww, 1.6, TIMBER if not (self.winter and i == n - 1) else SNOW, INK, 0.5)
                p.dot(x + ww / 2 - 0.6, yy - 0.8, (226, 196, 140), 1.0)
        return self.stand(y, fn, x=x)

    # -------------------------------------------------------------- output
    def finish(self, check=True, label=""):
        """Compose the piece: ground (faded at the hex border), shadows, then standing things back to front.
        Returns a SIZE x SIZE surface with alpha. With check=True, prints a line if a standing thing leaves the hex."""
        global LAST
        LAST = self
        if WILD is not None and self.has_base and not self.wild_done:
            self.wild(thin=WILD)                    # sheets: the piece stands in the map's wild land, thinned
        for q in sorted(self.queue, key=lambda q: (q[0], q[1])):
            q[2](self.op)
        mask = _hex_mask()
        ground = self.g.copy()
        sh = pygame.Surface(self.g.get_size(), pygame.SRCALPHA)
        self.sh.set_alpha(SHADOW_ALPHA)
        sh.blit(self.sh, (0, 0))
        ground.blit(sh, (0, 0))
        ground.blit(mask, (0, 0), special_flags=pygame.BLEND_RGBA_MULT)
        ground.blit(self.o, (0, 0))
        out = pygame.transform.smoothscale(ground, (SIZE, SIZE))
        if check and CHECK:
            bad = overhang(self.o)
            if bad:
                print("PIECE PROBLEM %s %s: %d px of standing art outside the hex margin" % (label, self.season, bad))
        return out


def _sheep(p, x, y, d, sc, body):
    """A sheep: a clean pale body with no outline (an outline greys so small a shape), a dark line under the belly
    so it stands off a pale meadow or snow, and a dark head."""
    w, h = 3.4 * sc, 2.4 * sc
    p.ellipse(x, y - h * 0.42, w, h, (104, 92, 80))              # the belly line and legs, showing 0.5 px below
    p.ellipse(x, y - h * 0.62, w, h, body)
    p.dot(x + w * 0.5 * d, y - h * 0.72, INK, 1.0 * max(0.8, sc))


def _smoke(p, x, y, winter=False):
    for i, (dx, dy, r) in enumerate(((0.0, -1.5, 1.0), (0.8, -3.6, 1.3), (2.0, -5.8, 1.6))):
        p.circle(x + dx, y + dy, r, SMOKE_SNOW if winter else SMOKE)


def _grow(mask, r):
    out = pygame.mask.Mask(mask.get_size())
    for dx in range(-r, r + 1):
        for dy in range(-r, r + 1):
            if dx * dx + dy * dy <= r * r + 1:
                out.draw(mask, (dx, dy))
    return out


def _shrink(mask, r):
    inv = mask.copy()
    inv.invert()
    inv = _grow(inv, r)
    inv.invert()
    return inv


def in_footprint(mask, x, y):
    """True if the piece-px point (origin at the hex centre) lies in the footprint mask."""
    i, j = int(math.floor(x + C)), int(math.floor(y + C))
    return 0 <= i < SIZE and 0 <= j < SIZE and bool(mask.get_at((i, j)))


def _accepts(draw):
    import inspect
    try:
        return set(inspect.signature(draw).parameters)
    except (TypeError, ValueError):
        return set()


def variants_of(draw):
    """How many layouts the module of this draw function has (its VARIANTS; 1 if it has none yet)."""
    import sys as _sys
    return int(getattr(_sys.modules.get(getattr(draw, "__module__", "")), "VARIANTS", 1))


def take_apart(draw, level, season, hex=None, variant=None, mirror=None, sea=None, shore=None, bay=None, climate=None, **kw):
    """Draw one piece for the map: without its ground base, and returned as layers (see Piece.layers()), so the map
    can lay the ground detail on its own ground, sort every standing thing into its own back-to-front list and thin
    its wild land under the piece's footprint.

    Level 0 is no piece: returns None (the map draws the wild land itself).
    hex=(col, row): the layout and the mirror are chosen from the hex by pick(); or give variant= and mirror=.
    sea=, shore=: where the map has the sea in this hex (see Piece.coast()); None for an inland hex.
    bay=(u0, width, depth): the bay the map carved for a port in this hex (see carve() and Bay).
    climate=: the hex's winter, "snow", "frost" or "mild" (see winter_of()); it only matters when season is
    "winter". None: the kit's current one (snow unless set).
    Works with every family module as it is: what a module's draw() does not take yet (variant, mirror, sea) is
    handed to the kit instead, so the mirror and the sea side still apply."""
    global NO_BASE, SITE
    if level == 0:
        return None
    if hex is not None:
        v, m = pick(hex[0], hex[1], variants_of(draw))
        variant = v if variant is None else variant
        mirror = m if mirror is None else mirror
    variant, mirror = variant or 0, bool(mirror)
    names = _accepts(draw)
    for k, v in (("variant", variant), ("mirror", mirror), ("sea", sea), ("shore", shore), ("bay", bay)):
        if k in names:
            kw[k] = v
    NO_BASE, old = True, SITE
    SITE = {"mirror": mirror, "sea": sea, "shore": shore, "bay": bay}
    try:
        with globals()["climate"](climate):
            draw(level, season, **kw)
    finally:
        NO_BASE, SITE = False, old
    lay = LAST.layers()
    lay["variant"] = variant if "variant" in names else 0
    return lay


def with_wild(draw, level, season, variant=0, mirror=False, sea=None, shore=None, bay=None, climate=None, **kw):
    """A piece as the sheets show it once the map draws the wild land: the flat picture standing in the terrain's
    wild scatter (Piece.wild()), thinned by the piece's own footprint. Level 0: draw() itself (kit.wild).
    climate=: the winter to show ("snow", "frost", "mild"); bay=: a carved port's bay (see take_apart())."""
    global WILD, CHECK, SITE
    names = _accepts(draw)
    site = {"variant": variant, "mirror": mirror, "sea": sea, "shore": shore, "bay": bay}
    with globals()["climate"](climate):
        if level == 0:
            old, SITE = SITE, (dict(SITE, bay=bay) if bay is not None else SITE)
            try:
                return draw(level, season, **dict(kw, **{k: v for k, v in site.items() if k in names and k != "variant"}))
            finally:
                SITE = old
        CHECK = False
        try:
            lay = take_apart(draw, level, season, **dict(kw, **site))
        finally:
            CHECK = True
        kw = dict(kw, **{k: v for k, v in site.items() if k in names})
        WILD, old = lay["footprint"], SITE
        SITE = {"mirror": mirror, "sea": sea, "shore": shore, "bay": bay}
        try:
            return draw(level, season, **kw)
        finally:
            WILD, SITE = None, old


def wild(season, ground="grass", seed=0, coast=None, thin=None, mix=None, label="wild", climate=None, **site):
    """The level 0 picture of a family: the wild land of its terrain, as the map draws it. FOR THE SHEETS ONLY.
    Use the family's own ground and seed. coast: the keywords of the family's p.coast() call, for a coast family
    (coast={} for the defaults). A module's draw() returns this for level 0:
        if level == 0:
            return kit.wild(season, "farm", seed=1)"""
    with globals()["climate"](climate):
        p = Piece(season, ground, seed, **site)
        if coast is not None:
            p.coast(**coast)
        p.wild(thin, mix)
        return p.finish(label=label)


_MASK = None


def _hex_mask():
    """White inside the hex, alpha fading to 0 over FEATHER px at the border (2x surface)."""
    global _MASK
    if _MASK is None:
        m = pygame.Surface((SIZE * SS, SIZE * SS), pygame.SRCALPHA)
        m.fill((255, 255, 255, 0))
        n = FEATHER * SS
        for i in range(n + 1):
            pts = [Pen.T(p) for p in hex_points(i / SS)]
            pygame.draw.polygon(m, (255, 255, 255, int(255 * i / n)), pts)
        _MASK = m
    return _MASK


def overhang(obj_layer):
    """The number of 1x pixels of standing art that lie outside the hex pulled in by MARGIN. 0 = the piece fits."""
    small = pygame.transform.scale(obj_layer, (SIZE, SIZE))
    allowed = pygame.Surface((SIZE, SIZE), pygame.SRCALPHA)
    pygame.draw.polygon(allowed, (255, 255, 255, 255), [(p[0] + C, p[1] + C) for p in hex_points(MARGIN)])
    am = pygame.mask.from_surface(allowed, 127)
    om = pygame.mask.from_surface(small, 60)
    am.invert()
    return om.overlap_area(am, (0, 0))


# ------------------------------------------------------------------ sheets
SHEET_BG = (26, 30, 44)
SHEET_TEXT = (226, 226, 220)
SHEET_DIM = (150, 156, 170)


def _font(size, bold=False):
    f = pygame.font.Font(None, size)
    f.set_bold(bold)
    return f


def backdrop(season, w, h, ground="grass", climate=None):
    """A patch of plain season ground to show pieces on, so the blend at the hex border can be judged.
    climate: the winter to show (default: the kit's current one)."""
    s = pygame.Surface((w, h))
    s.fill(WINTER[climate or CLIMATE][ground] if season == "winter" else PAL[season][ground])
    return s


def _cell(piece, season, scale=1.0, pad=6, ground="grass", climate=None):
    w = int((SIZE + pad * 2) * scale)
    s = backdrop(season, w, w, ground, climate)
    img = piece if scale == 1.0 else pygame.transform.smoothscale(piece, (int(SIZE * scale), int(SIZE * scale)))
    s.blit(img, (int(pad * scale), int(pad * scale)))
    lay = pygame.Surface((w, w), pygame.SRCALPHA)
    pts = [((p[0] + C + pad) * scale, (p[1] + C + pad) * scale) for p in hex_points()]
    pygame.draw.lines(lay, (30, 40, 30, 40), True, pts, 1)
    s.blit(lay, (0, 0))
    return s


def sheet(draw, levels, title, path, level_names=None, ground="grass", row_season="summer", wild=False):
    """Lay a family out as a labelled grid and save it as a PNG.

    wild=True (for a module that no longer draws its own wild scatter): every piece is shown standing in the
    terrain's wild land, thinned by its footprint, as on the map (with_wild()); level 0 is draw(0, season), which
    returns kit.wild(...).

    draw(level, season) -> Surface (SIZE x SIZE);  levels: e.g. range(0, 4);  level_names: {level: "name"}.
    Left: rows = levels, columns = seasons, at 100%. Right: the same grid at 50% (the small-size test).
    Bottom: every level of `row_season` side by side as touching hexes (the seam and progression test).
    Returns the dict {(level, season): Surface}."""
    levels = list(levels)
    level_names = level_names or {}
    if wild:
        pieces = {(lv, se): with_wild(draw, lv, se) for lv in levels for se in SEASONS}
    else:
        pieces = {(lv, se): draw(lv, se) for lv in levels for se in SEASONS}
    for k, s in pieces.items():
        assert s.get_size() == (SIZE, SIZE), "draw%r must return a %dx%d surface" % (k, SIZE, SIZE)
    pad, gap, left, top = 6, 6, 118, 64
    cw = SIZE + pad * 2
    hw = cw // 2
    gw = len(SEASONS) * (cw + gap)
    gh = len(levels) * (cw + gap)
    x50 = left + gw + 30
    row_w = int(len(levels) * HEX_W + 40)
    W = max(x50 + len(SEASONS) * (hw + 4) + 20, left + row_w + 20)
    H = top + gh + 40 + 150
    out = pygame.Surface((W, H))
    out.fill(SHEET_BG)
    f_t, f_h, f_s = _font(30, True), _font(22), _font(18)
    out.blit(f_t.render(title, True, SHEET_TEXT), (16, 12))
    out.blit(f_s.render("100%  (hex radius 60)", True, SHEET_DIM), (left, 44))
    out.blit(f_s.render("50% test", True, SHEET_DIM), (x50, 44))
    for j, se in enumerate(SEASONS):
        out.blit(f_h.render(se, True, SHEET_TEXT), (left + j * (cw + gap) + 4, top - 2 + gh))
        out.blit(f_s.render(se, True, SHEET_DIM), (x50 + j * (hw + 4), top - 2 + len(levels) * (hw + 4)))
    for i, lv in enumerate(levels):
        y = top + i * (cw + gap)
        out.blit(f_h.render("Level %d" % lv, True, SHEET_TEXT), (14, y + 40))
        if lv in level_names:
            out.blit(f_s.render(level_names[lv], True, SHEET_DIM), (14, y + 62))
        for j, se in enumerate(SEASONS):
            out.blit(_cell(pieces[(lv, se)], se, 1.0, pad, ground), (left + j * (cw + gap), y))
            out.blit(_cell(pieces[(lv, se)], se, 0.5, pad, ground), (x50 + j * (hw + 4), top + i * (hw + 4)))
    # the row of touching hexes
    ry = top + gh + 34
    out.blit(f_s.render("Side by side, %s (touching hexes: seams and progression)" % row_season, True, SHEET_DIM), (left, ry - 6))
    strip = backdrop(row_season, row_w, 124, ground)
    for i, lv in enumerate(levels):
        strip.blit(pieces[(lv, row_season)], (int(20 + i * HEX_W - (SIZE - HEX_W) / 2), 6))
    out.blit(strip, (left, ry + 14))
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    pygame.image.save(out, path)
    return pieces


def hex_field(get, cols, rows, season="summer", ground="grass", pad=8):
    """A block of touching hexes, as on the map (odd rows shoved right). get(col, row) -> a piece Surface or None.
    Returns the picture: the repetition test."""
    w = int(cols * HEX_W + HEX_W / 2 + pad * 2)
    h = int((rows - 1) * 0.75 * HEX_H + HEX_H + pad * 2)
    out = backdrop(season, w, h, ground)
    for r in range(rows):
        for c in range(cols):
            img = get(c, r)
            if img is not None:
                cx = pad + HEX_W / 2 + c * HEX_W + (r & 1) * HEX_W / 2
                cy = pad + HEX_H / 2 + r * 0.75 * HEX_H
                out.blit(img, (int(round(cx - C)), int(round(cy - C))))
    return out


def variant_sheet(draw, levels, title, path, level_names=None, ground="grass", variants=None, season="summer", wild=True, **kw):
    """The second sheet of a family: its layouts and their mirrors, and how they repeat. Saves a PNG.

    Left: rows = levels (level 0 is left out: it is no piece), columns = layout 0, layout 0 mirrored, layout 1,
    layout 1 mirrored, at 100% in `season`; a small 50% copy beside it. Check: the light still comes from the upper
    left in the mirrored columns, nothing collides, layout 1 is not taken for a mirror of layout 0.
    Right: a block of 5 x 4 touching hexes of the top level, each hex's picture chosen by pick(col, row): no two
    neighbours may be the same picture. wild=True shows the pieces in the thinned wild land, as on the map."""
    levels = [lv for lv in levels if lv != 0]
    level_names = level_names or {}
    n = variants or variants_of(draw)
    combos = [(v, m) for v in range(n) for m in (False, True)]

    def one(lv, v, m):
        if wild:
            return with_wild(draw, lv, season, variant=v, mirror=m, **kw)
        names = _accepts(draw)
        k2 = dict(kw, **{k: val for k, val in (("variant", v), ("mirror", m)) if k in names})
        global SITE
        old, SITE = SITE, {"mirror": m}
        try:
            return draw(lv, season, **k2)
        finally:
            SITE = old
    pieces = {(lv, c): one(lv, *c) for lv in levels for c in combos}
    pad, gap, left, top = 6, 6, 118, 64
    cw = SIZE + pad * 2
    hw = cw // 2
    gw = len(combos) * (cw + gap)
    gh = len(levels) * (cw + gap)
    x50 = left + gw + 24
    fx = x50 + len(combos) * (hw + 4) + 24
    field = hex_field(lambda c, r: pieces[(levels[-1], pick(c, r, n))], 5, 4, season, ground)
    W = fx + field.get_width() + 20
    H = max(top + gh + 40, top + field.get_height() + 60)
    out = pygame.Surface((W, H))
    out.fill(SHEET_BG)
    f_t, f_h, f_s = _font(30, True), _font(22), _font(18)
    out.blit(f_t.render(title, True, SHEET_TEXT), (16, 12))
    out.blit(f_s.render("100%%, %s (light: upper left in every column)" % season, True, SHEET_DIM), (left, 44))
    out.blit(f_s.render("50% test", True, SHEET_DIM), (x50, 44))
    out.blit(f_s.render("Level %d on 5 x 4 hexes, chosen by kit.pick(col, row)" % levels[-1], True, SHEET_DIM), (fx, 44))
    for j, (v, m) in enumerate(combos):
        out.blit(f_h.render("layout %d%s" % (v, ", mirrored" if m else ""), True, SHEET_TEXT), (left + j * (cw + gap) + 4, top - 2 + gh))
    for i, lv in enumerate(levels):
        y = top + i * (cw + gap)
        out.blit(f_h.render("Level %d" % lv, True, SHEET_TEXT), (14, y + 40))
        if lv in level_names:
            out.blit(f_s.render(level_names[lv], True, SHEET_DIM), (14, y + 62))
        for j, c in enumerate(combos):
            out.blit(_cell(pieces[(lv, c)], season, 1.0, pad, ground), (left + j * (cw + gap), y))
            out.blit(_cell(pieces[(lv, c)], season, 0.5, pad, ground), (x50 + j * (hw + 4), top + i * (hw + 4)))
    out.blit(field, (fx, top))
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    pygame.image.save(out, path)
    return pieces
