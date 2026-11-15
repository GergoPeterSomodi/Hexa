"""The growing map: what stands on the Genoa close-up at five moments in time (see docs/design/map/06-growing-map.md).

This file is data only. The land (coast, hills, ridges, the torrent, the road lines, camera, palette) is the same in
every stage and is not listed here. growth.py reads one of these records and draws the scene; positions are in
drawing px (2x of the 1280x720 picture), the same frame as closeup.py.

The rule: one city, one hex, drawn inside it. Every 28 km hex of the normal map is one district with one main use,
one seat (its only settlement) and a stage per panel (DISTRICTS). Everything a district owns - its seat, farms, field
blocks, terraces, watchtower - stands inside its hex, clear of the border; a higher stage fills more of the hex and
never spills over. growth.py checks every site against its hex (growth.check_layout).
"""

PANELS = ("1", "2", "3", "4a", "4b")
# stages: 0 wild, 1 first settlers, 2 early growth, 3 developed, 4 rich, 5 great city


def _st(*v):
    return dict(zip(PANELS, v))


# hex (column, row) of the normal map -> the district. seat: the hex's one settlement.
DISTRICTS = {
    (8, 13): dict(name="Genoa", use="city and port", seat="Genoa (city)", stage=_st(2, 3, 4, 5, 4)),
    (7, 13): dict(name="Savona", use="farmland", seat="Savona (town)", stage=_st(1, 2, 3, 4, 4)),
    (9, 13): dict(name="Chiavari", use="terraced coast", seat="Chiavari (village)", stage=_st(1, 2, 3, 4, 3)),
    (9, 12): dict(name="Giovi", use="pass road", seat="pass post", stage=_st(1, 2, 3, 4, 4)),
    (8, 12): dict(name="Stura", use="woodland", seat="hamlet (from stage 2)", stage=_st(0, 1, 1, 2, 2)),
    (10, 12): dict(name="Antola", use="high woods", seat="none", stage=_st(0, 0, 1, 1, 1)),
    (10, 13): dict(name="Fontanabuona", use="wooded hills", seat="hamlet (from stage 2)", stage=_st(0, 1, 2, 3, 3)),
    (8, 14): dict(name="Savona roads", use="sea", seat="none", stage=None),
    (9, 14): dict(name="Gulf of Genoa", use="sea", seat="none", stage=None),
    (10, 14): dict(name="Riviera", use="sea", seat="none", stage=None),
}


def stage_of(hx, panel):
    d = DISTRICTS.get(hx)
    return d["stage"][panel] if d and d["stage"] else 0


# what a stage looks like on the land of its hex: the woods (bias: more wood when positive), scrub on open ground
# (coast, inland), woodcutters' clearings, and how many terrace lines the low hills carry
LOOK = {
    0: dict(tree_bias=0.42, scrub=(0.36, 0.07), clearings=False, hill_lines=0, ridge_wood=0.76),
    1: dict(tree_bias=0.34, scrub=(0.30, 0.05), clearings=True, hill_lines=0, ridge_wood=0.74),
    2: dict(tree_bias=0.18, scrub=(0.18, 0.03), clearings=True, hill_lines=2, ridge_wood=0.70),
    3: dict(tree_bias=0.0, scrub=(0.0, 0.0), clearings=False, hill_lines=5, ridge_wood=0.62),
    4: dict(tree_bias=-0.08, scrub=(0.0, 0.0), clearings=False, hill_lines=7, ridge_wood=0.60),
    5: dict(tree_bias=-0.14, scrub=(0.0, 0.0), clearings=False, hill_lines=7, ridge_wood=0.60),
}

# ---- the sites. Each belongs to the hex it stands in; the last number is the district stage that builds it.
# seats of the small districts: (x, y, seed, church side); level 1 at stage 2, 2 at stage 3, 3 at stage 4
HAMLETS = [(470, 205, 23, "left"), (2372, 792, 26, "left")]
HAMLET_LEVEL = {0: 0, 1: 0, 2: 1, 3: 2, 4: 3, 5: 3}
SAVONA_AT = (235, 926, 100, 46)          # centre and radii of the town
CHIAVARI_AT = (1715, 990, 106, 42)
PASS_AT = (1152, 100)
FARMS = ((610, 735, 2), (862, 600, 3), (1192, 742, 2), (538, 640, 4), (1096, 588, 4),          # Genoa
         (1592, 792, 2), (1960, 925, 3), (1792, 602, 3), (2040, 762, 2),                       # Chiavari
         (62, 884, 1), (300, 742, 2), (212, 582, 3), (376, 690, 4),                            # Savona
         (2452, 700, 3))                                                                       # Fontanabuona
# field blocks: (x, y, angle, columns, rows, parcel width, parcel depth, stage)
BLOCKS = [(585, 800, -8, 3, 2, 60, 40, 2), (590, 560, 6, 3, 2, 60, 40, 2), (760, 540, -10, 2, 2, 60, 42, 3), (780, 452, 10, 3, 2, 58, 40, 3),
          (940, 470, 14, 2, 3, 56, 44, 3), (1190, 640, -6, 2, 2, 60, 42, 2), (1176, 896, 6, 2, 2, 56, 40, 3), (560, 905, -4, 2, 1, 60, 38, 3),
          (1080, 655, 8, 2, 2, 56, 40, 4),                                                                                          # Genoa
          (1560, 880, 6, 3, 2, 60, 38, 1), (1860, 900, -6, 3, 2, 60, 40, 1), (1500, 760, 12, 2, 3, 56, 42, 2), (1900, 780, -8, 3, 2, 58, 40, 2),
          (1450, 570, 8, 2, 2, 56, 40, 3), (1850, 580, -6, 3, 2, 60, 40, 3), (2010, 830, 8, 2, 2, 56, 40, 3), (1640, 540, 6, 2, 2, 56, 40, 4),  # Chiavari
          (120, 820, -8, 3, 2, 62, 40, 1), (60, 690, 8, 3, 2, 60, 40, 1), (270, 650, -14, 3, 2, 60, 42, 2), (140, 560, 6, 3, 2, 60, 40, 3),
          (340, 560, -4, 2, 2, 60, 40, 3), (60, 560, 4, 2, 2, 60, 40, 4),                                                             # Savona
          (420, 305, -6, 2, 2, 58, 40, 2),                                                                                          # Stura
          (1330, 330, 8, 2, 2, 56, 40, 3), (1010, 300, -8, 2, 2, 56, 40, 4),                                                          # Giovi
          (2330, 880, -6, 3, 2, 60, 40, 2), (2440, 610, 8, 3, 2, 60, 40, 3), (2250, 620, -8, 2, 2, 56, 40, 3)]                        # Fontanabuona
TOWERS = ((1830, 1040, 1), (2340, 992, 2), (98, 1040, 2))       # coast watchtowers: (x, y, stage)
STRAND = ((1672, 1062), (1752, 1070), (190, 1012), (292, 1012), (1150, 985))    # boats pulled up on the sand

# crop mixes of a field block
STRIPS = ("wheat", "wheat", "green", "fallow", "fallow", "green", "wheat")           # open strips, no vines yet
MIXED = ("wheat", "wheat", "green", "fallow", "vine", "olive", "green")              # today's mix
WINE = ("vine", "vine", "vine", "olive", "olive", "vine", "green", "wheat")
GROVES = ("vine", "olive", "vine", "olive", "green", "wheat", "fallow")              # the first vines and olives by a hamlet
GRAIN = ("wheat", "wheat", "wheat", "wheat", "green", "fallow", "wheat", "green")

# the ships: (kind, x, y, options). The first few lie in Genoa's basin, the rest are at sea.
IN_PORT_1480 = [("carrack", 838, 1036, dict(sc=0.8, d=1, furled=True)), ("boat", 905, 998, dict(sc=0.9, d=-1, sail=False))]
IN_PORT_1600 = IN_PORT_1480 + [("galley", 912, 1034, dict(sc=0.72, d=-1, sail=False)), ("boat", 800, 1012, dict(sc=0.9, d=1, sail=False)),
                               ("boat", 972, 1012, dict(sc=0.9, d=-1))]
FLEET_1480 = IN_PORT_1480 + [
    ("galley", 760, 1216, dict(sc=1.3, d=1)),
    ("boat", 2010, 1152, dict(sc=1.3, d=1)),
]
FLEET_1520 = FLEET_1480 + [
    ("boat", 972, 1012, dict(sc=0.9, d=-1)),
    ("carrack", 1480, 1296, dict(sc=1.75, d=-1)),
    ("boat", 380, 1136, dict(sc=1.25, d=1)),
]
FLEET_1600 = IN_PORT_1600 + [
    ("carrack", 1480, 1296, dict(sc=1.75, d=-1)),
    ("galley", 760, 1216, dict(sc=1.3, d=1)),
    ("carrack", 330, 1352, dict(sc=1.15, d=1, cross=False)),
    ("carrack", 2330, 1336, dict(sc=1.3, d=-1)),
    ("boat", 2010, 1152, dict(sc=1.3, d=1)),
    ("boat", 2140, 1206, dict(sc=1.15, d=-1)),
    ("boat", 1880, 1300, dict(sc=1.2, d=1)),
    ("boat", 380, 1136, dict(sc=1.25, d=1)),
    ("boat", 470, 1190, dict(sc=1.1, d=-1)),
    ("boat", 1030, 1180, dict(sc=1.15, d=1)),
]
FLEET_TRADE = FLEET_1600 + [
    ("carrack", 1130, 1300, dict(sc=1.25, d=1)),
    ("carrack", 1452, 1176, dict(sc=1.0, d=-1, furled=True)),
    ("carrack", 1830, 1196, dict(sc=1.05, d=1, cross=False)),
    ("carrack", 640, 1372, dict(sc=1.0, d=-1)),
    ("carrack", 2060, 1392, dict(sc=1.1, d=1)),
    ("carrack", 250, 1190, dict(sc=0.9, d=1, furled=True)),
    ("carrack", 2200, 1150, dict(sc=0.85, d=-1, furled=True)),
    ("galley", 880, 1290, dict(sc=1.0, d=-1)),
    ("galley", 2480, 1226, dict(sc=0.95, d=1)),
    ("boat", 884, 1150, dict(sc=1.1, d=-1)),
    ("boat", 1700, 1160, dict(sc=1.1, d=1)),
    ("boat", 1300, 1200, dict(sc=1.0, d=1)),
    ("boat", 560, 1260, dict(sc=1.1, d=1)),
    ("boat", 2390, 1180, dict(sc=1.05, d=-1)),
    ("boat", 1760, 1400, dict(sc=1.2, d=-1)),
]
FLEET_GRAIN = IN_PORT_1480 + [
    ("galley", 912, 1034, dict(sc=0.72, d=-1, sail=False)),
    ("galley", 760, 1216, dict(sc=1.3, d=1)),
    ("galley", 2040, 1240, dict(sc=1.2, d=-1)),
    ("boat", 2010, 1152, dict(sc=1.3, d=1)),
    ("boat", 380, 1136, dict(sc=1.25, d=1)),
]

# Genoa's harbour works. The basin is the corner of sea inside Genoa's own hex; the moles close it and stay inside too.
OLD_MOLE = [(1062, 1014), (1030, 1030), (985, 1050), (945, 1066)]
NEW_MOLE = [(706, 1016), (740, 1034), (790, 1052)]
OLD_LIGHT, NEW_LIGHT = (945, 1070, 13, 30, 1072), (790, 1056, 11, 24, 1058)
SUBURBS = ((640, 950), (622, 905), (1162, 948), (1168, 902), (600, 935))

GENOA_1480 = dict(
    rows=168, churches=2, quay=(226, 318), piers=((258, 40), (288, 39)),
    moles=((OLD_MOLE, 20),), lights=(OLD_LIGHT,),
    slips=(), hulls=(), crane=False, goods=(262, 284), lanterna=False, castle=True, suburbs=(),
    gardens=(180, 204, 236, 262, 290, 320), strand_boats=(200, 208, 334), beacon=True, pave_in_wall=True,
)
GENOA_1520 = dict(
    rows=200, churches=3, quay=(208, 338), piers=((226, 34), (258, 40), (288, 39)),
    moles=((OLD_MOLE, 20),), lights=(OLD_LIGHT,),
    slips=((748, 1004),), hulls=((748, 998, 1011),), crane=False, goods=(236, 262, 284, 300), lanterna=False, castle=True,
    suburbs=SUBURBS[:2], gardens=(212, 236, 262, 290, 320), strand_boats=(198,), beacon=True, pave_in_wall=True,
)
GENOA_1600 = dict(
    rows=232, churches=4, quay=(184, 357), piers=((226, 34), (258, 40), (288, 39), (318, 32)),
    moles=((OLD_MOLE, 20), (NEW_MOLE, 18)), lights=(OLD_LIGHT, NEW_LIGHT),
    slips=((748, 1004), (772, 994)), hulls=((748, 998, 1011), (772, 988, 1001)), crane=True,
    goods=(214, 236, 262, 284, 300, 326), lanterna=True, castle=True, suburbs=SUBURBS,
    gardens=(212, 236, 262, 290, 320),
)
GENOA_TRADE = dict(
    GENOA_1600,
    piers=((212, 28), (226, 34), (242, 38), (258, 40), (274, 40), (288, 39), (304, 36), (318, 32)),
    moles=(([(1062, 1014), (1030, 1030), (985, 1052), (940, 1072), (910, 1084)], 26),
           ([(706, 1016), (740, 1034), (790, 1056), (824, 1072), (846, 1082)], 20)),
    lights=((910, 1088, 13, 30, 1090), (846, 1086, 12, 26, 1088)),
    slips=((748, 1004), (772, 994), (798, 986)), hulls=((748, 998, 1011), (772, 988, 1001), (798, 980, 993)),
    goods=(204, 214, 226, 236, 250, 262, 284, 300, 312, 326, 340),
    suburbs=SUBURBS + ((1210, 885), (585, 890), (1226, 928), (575, 945)),
    mole_warehouses=((1046, 1018, 34), (1008, 1036, 36), (966, 1054, 34)),
    yard_timber=((728, 984), (756, 972)), crane2=True,
)
GENOA_GRAIN = dict(GENOA_1520, rows=232, churches=4, castle=False, fort=True, suburbs=SUBURBS, flags=True, pave_in_wall=False,
                   gardens=(212, 236, 262, 290, 320))

# Savona and Chiavari by the stage of their hex
SAVONA = {
    1: dict(n=5, big=0, walled=False, church=False, paved=False, jetty=False, port=False),
    2: dict(n=8, big=1, walled=True, wall_frac=0.42, scaffold=True, church=True, paved=True, pave_k=0.88, jetty=False, port=False),
    3: dict(n=11, big=2, walled=True, church=True, paved=True, jetty=True, port=False),
    4: dict(n=14, big=4, walled=True, church=True, paved=True, jetty=True, port=True),
}
CHIAVARI = {
    1: dict(n=4, big=0, church=True, paved=False, jetty=False, port=False),
    2: dict(n=6, big=0, church=True, paved=True, jetty=True, port=False),
    3: dict(n=8, big=0, church=True, paved=True, jetty=True, port=False),
    4: dict(n=11, big=2, church=True, paved=True, jetty=True, port=True),
}
PASS = {0: "cairn", 1: "cairn", 2: "hut", 3: "hospice", 4: "inn"}

FLOCKS = ((1380, 180), (300, 380), (2200, 420), (2300, 620), (1900, 480), (240, 720))

ORDER = ("1", "2", "3", "4a", "4b")

# What is the same for the whole panel: the year's light, the class of the roads, the ships, Genoa's works, and which
# way the rich districts went (outcome: "wine" or "grain"). Everything else comes from the district stages above.
STAGES = {
    "1": dict(
        file="growth_1480", year="1480", title="1. Start", sub="rough country, old mole only, a mule track over the Giovi",
        farm_gain=0.25, wood_gain=1.3, sun=(158, 186, 96), outcome=None,
        ridge=dict(wood=0.76, clear=0.0, terr=0.0), ridge_low=dict(wood=0.76, clear=0.0, terr=0.0),
        dome=dict(wood=0.52, terr=0.0), hill_crop="olive", auto_blocks=None,
        road_giovi=("track", 6), road_coast=("cart", 8), road_spur=("track", 5),
        crossing="ford",
        travellers=(("giovi", 0.5, "mule2", 1),), tower_flags=False,
        genoa=GENOA_1480, fleet=FLEET_1480, mills=(), press=(), barns=(),
        flocks=(0, 1, 2, 3, 4, 5), strand_boats=4,
    ),
    "2": dict(
        file="growth_1520", year="about 1520", title="2. Early growth", sub="clearings, first vines and olives, a timber bridge, Savona's wall begun",
        farm_gain=0.6, wood_gain=1.15, sun=(168, 192, 98), outcome=None,
        ridge=dict(wood=0.7, clear=0.0, terr=0.0), ridge_low=dict(wood=0.7, clear=0.12, terr=0.0),
        dome=dict(wood=0.42, terr=0.3), hill_crop="olive", auto_blocks=None,
        road_giovi=("cart", 8), road_coast=("cart", 9), road_spur=("cart", 7),
        crossing="timber",
        travellers=(("giovi", 0.33, "mule", -1), ("giovi", 0.62, "cart", 1)), tower_flags=False,
        genoa=GENOA_1520, fleet=FLEET_1520, mills=(), press=(), barns=(),
        flocks=(0, 1, 2, 3, 4), strand_boats=5,
    ),
    "3": dict(
        file="growth_1600", year="about 1600", title="3. Developed", sub="today's picture: terraces, hedged fields, a stone bridge, new mole and Lanterna",
        farm_gain=1.0, wood_gain=1.0, sun=(176, 198, 100), outcome=None,
        ridge=dict(wood=0.62, clear=0.0, terr=0.0), ridge_low=dict(wood=0.62, clear=0.14, terr=0.0),
        dome=dict(wood=0.34, terr=0.66), hill_crop="olive", auto_blocks=None,
        road_giovi=(None, 11), road_coast=(None, 10), road_spur=("cart", 8),
        crossing="stone",
        travellers=(("giovi", 0.33, "mule", -1), ("giovi", 0.62, "mule", 1)), tower_flags=False,
        genoa=GENOA_1600, fleet=FLEET_1600, mills=(), press=(), barns=(),
        flocks=(0, 1, 2, 3), strand_boats=5,
    ),
    "4a": dict(
        file="growth_1650_trade", year="1650", title="4a. Trade and wine", sub="great port, vines and olives to the ridges, press houses, a highway over the Giovi",
        farm_gain=1.15, wood_gain=0.9, sun=(190, 200, 106), outcome="wine",
        ridge=dict(wood=0.6, clear=0.0, terr=0.37, crop="mixed"), ridge_low=dict(wood=0.6, clear=0.0, terr=0.64, crop="mixed"),
        dome=dict(wood=0.3, terr=0.82, crop="mixed"), hill_crop="mixed",
        auto_blocks=dict(n=9, kind="vine", mix="WINE", hedge=True),
        road_giovi=("highway", 15), road_coast=("highway", 13), road_spur=(None, 9),
        crossing="stone",
        travellers=(("giovi", 0.2, "mule", 1), ("giovi", 0.33, "mule", -1), ("giovi", 0.48, "cart", 1), ("giovi", 0.62, "mule", 1),
                    ("giovi", 0.8, "mule", -1), ("west", 0.35, "cart", 1), ("east", 0.55, "cart", -1), ("west", 0.7, "mule", -1)),
        tower_flags=False,
        genoa=GENOA_TRADE, fleet=FLEET_TRADE, mills=(0.5,), press=(0, 2, 5, 8, 10, 6), barns=(),
        flocks=(0, 2), strand_boats=5,
    ),
    "4b": dict(
        file="growth_1650_grain", year="1650", title="4b. Grain and castles", sub="hedged grain on the valley floors, mills, a bastion fortress, a castle at the Giovi",
        farm_gain=1.5, wood_gain=1.0, sun=(192, 200, 100), outcome="grain",
        ridge=dict(wood=0.64, clear=0.0, terr=0.0), ridge_low=dict(wood=0.64, clear=0.14, terr=0.0),
        dome=dict(wood=0.34, terr=0.46), hill_crop="olive",
        auto_blocks=dict(n=14, kind="grain", mix="GRAIN", hedge="trees"),
        road_giovi=(None, 11), road_coast=(None, 10), road_spur=("cart", 8),
        crossing="stone",
        travellers=(("giovi", 0.33, "cart", -1), ("giovi", 0.62, "mule", 1), ("west", 0.4, "cart", 1)), tower_flags=True,
        genoa=GENOA_GRAIN, fleet=FLEET_GRAIN, mills=(0.22, 0.5), press=(), barns=(0, 2, 5, 8, 10, 11),
        flocks=(0, 2, 3), strand_boats=5,
        savona_extra=dict(flags=True, port=False, n=11, big=2), chiavari_extra=dict(tower=True), pass_="castle",
    ),
}


def block_mix(use, stage, outcome, index):
    """The crops of a field block: by the stage of its hex, the hex's use and the way the rich districts went.
    Returns (mix, hedge)."""
    coast = use == "terraced coast"
    if stage <= 1:
        return STRIPS, False
    if stage == 2:
        return (GROVES if coast or index % 2 else STRIPS), True
    if stage == 3 or outcome is None:
        return MIXED, True
    if outcome == "grain":
        return GRAIN, "trees"
    return WINE, True
