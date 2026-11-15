"""The growing map: what stands on the Genoa close-up at five moments in time (see docs/design/map/06-growing-map.md).

This file is data only. The land (coast, hills, ridges, torrents, town sites, camera, palette) is the same in every
stage and is not listed here. growth.py reads one of these records and draws the scene; positions are in drawing px
(2x of the 1280x720 picture), the same frame as closeup.py.

The numbered sites are fixed for all stages (they stand for the map's sockets):
  HAMLETS 0 Giovi road, 1 west valley, 2 Bisagno, 3 east coast, 4 west coast, 5 Giovi road east, 6 north-east
  FARMS   0..7, BLOCKS 0..19 (field blocks), TOWERS 0..2 (coast watchtowers)
"""

HAMLETS = [(1330, 410, 23, "right"), (566, 640, 24, "left"), (1808, 640, 25, "right"), (2300, 892, 26, "left"), (676, 968, 27, "right"),
           (1420, 420, 28, "left"), (2050, 600, 29, "right")]
FARMS = ((330, 800), (900, 596), (1730, 880), (2440, 962), (500, 930), (1960, 742), (1325, 560), (150, 842))
BLOCKS = [(420, 968, -8, 4, 2, 62, 40), (560, 716, 6, 4, 2, 60, 40), (700, 620, -10, 2, 2, 60, 42), (836, 700, 14, 2, 4, 54, 42),
          (880, 520, 16, 2, 3, 56, 44), (1130, 470, 14, 2, 2, 56, 40), (1380, 490, -6, 2, 2, 60, 42), (1740, 760, 12, 2, 4, 56, 42),
          (1900, 660, -8, 3, 2, 58, 40), (1790, 990, 6, 3, 2, 60, 38), (1960, 1040, 4, 3, 1, 62, 42), (2210, 940, -6, 3, 2, 60, 40),
          (2400, 900, 8, 3, 2, 60, 40), (300, 860, -14, 3, 2, 60, 42), (90, 900, 8, 3, 2, 60, 40), (2060, 690, 8, 3, 2, 56, 40),
          (1420, 500, 6, 3, 2, 56, 38), (760, 880, -4, 3, 1, 60, 38), (640, 1010, -3, 3, 1, 56, 34), (2160, 1060, 3, 2, 1, 60, 36)]
TOWERS = ((1876, 1070), (2470, 1090), (560, 990))

# crop mixes of a field block
STRIPS = ("wheat", "wheat", "green", "fallow", "fallow", "green", "wheat")           # open strips, no vines yet
MIXED = ("wheat", "wheat", "green", "fallow", "vine", "olive", "green")              # today's mix
WINE = ("vine", "vine", "vine", "olive", "olive", "vine", "green", "wheat")
GROVES = ("vine", "olive", "vine", "olive", "green", "wheat", "fallow")              # the first vines and olives by a hamlet
GRAIN = ("wheat", "wheat", "wheat", "wheat", "green", "fallow", "wheat", "green")

# the ships: (kind, x, y, options)
FLEET_1480 = [
    ("carrack", 1168, 1012, dict(sc=1.0, d=1, furled=True)),
    ("boat", 1262, 946, dict(sc=1.0, d=-1, sail=False)),
    ("galley", 760, 1216, dict(sc=1.3, d=1)),
    ("boat", 2010, 1152, dict(sc=1.3, d=1)),
]
FLEET_1520 = FLEET_1480 + [
    ("boat", 1372, 982, dict(sc=1.05, d=-1)),
    ("carrack", 1560, 1262, dict(sc=1.75, d=-1)),
    ("boat", 380, 1136, dict(sc=1.25, d=1)),
]
FLEET_1600 = [
    ("carrack", 1168, 1012, dict(sc=1.0, d=1, furled=True)),
    ("galley", 1322, 1030, dict(sc=0.86, d=-1, sail=False)),
    ("boat", 1126, 966, dict(sc=1.0, d=1, sail=False)),
    ("boat", 1262, 946, dict(sc=1.0, d=-1, sail=False)),
    ("boat", 1372, 982, dict(sc=1.05, d=-1)),
    ("carrack", 1560, 1262, dict(sc=1.75, d=-1)),
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
    ("carrack", 250, 1150, dict(sc=0.9, d=1, furled=True)),
    ("carrack", 2200, 1150, dict(sc=0.85, d=-1, furled=True)),
    ("galley", 880, 1290, dict(sc=1.0, d=-1)),
    ("galley", 2480, 1226, dict(sc=0.95, d=1)),
    ("boat", 900, 1140, dict(sc=1.1, d=-1)),
    ("boat", 1700, 1130, dict(sc=1.1, d=1)),
    ("boat", 1300, 1200, dict(sc=1.0, d=1)),
    ("boat", 560, 1260, dict(sc=1.1, d=1)),
    ("boat", 2390, 1180, dict(sc=1.05, d=-1)),
    ("boat", 1760, 1400, dict(sc=1.2, d=-1)),
]
FLEET_GRAIN = [
    ("carrack", 1168, 1012, dict(sc=1.0, d=1, furled=True)),
    ("boat", 1262, 946, dict(sc=1.0, d=-1, sail=False)),
    ("galley", 1322, 1030, dict(sc=0.86, d=-1, sail=False)),
    ("galley", 760, 1216, dict(sc=1.3, d=1)),
    ("galley", 2040, 1240, dict(sc=1.2, d=-1)),
    ("boat", 2010, 1152, dict(sc=1.3, d=1)),
    ("boat", 380, 1136, dict(sc=1.25, d=1)),
]

OLD_MOLE = [(1420, 1058), (1372, 1074), (1310, 1080), (1262, 1076)]
NEW_MOLE = [(1052, 1070), (1090, 1084), (1136, 1086)]
SUBURBS = ((930, 905), (902, 960), (1600, 935), (1596, 880), (940, 968))

GENOA_1480 = dict(
    rows=168, churches=2, quay=(226, 318), piers=((258, 62), (288, 60)),
    moles=((OLD_MOLE, 22),), lights=((1262, 1080, 14, 34, 1082),),
    slips=(), hulls=(), crane=False, goods=(262, 284), lanterna=False, castle=True, suburbs=(),
    gardens=(180, 204, 236, 262, 290, 320), strand_boats=(200, 208, 334), beacon=True, pave_in_wall=True,
)
GENOA_1520 = dict(
    rows=200, churches=3, quay=(208, 338), piers=((226, 52), (258, 62), (288, 60)),
    moles=((OLD_MOLE, 22),), lights=((1262, 1080, 14, 34, 1082),),
    slips=((1052, 968),), hulls=((1052, 962, 975),), crane=False, goods=(236, 262, 284, 300), lanterna=False, castle=True,
    suburbs=SUBURBS[:2], gardens=(212, 236, 262, 290, 320), strand_boats=(198,), beacon=True, pave_in_wall=True,
)
GENOA_1600 = dict(
    rows=232, churches=4, quay=(184, 357), piers=((226, 52), (258, 62), (288, 60), (318, 50)),
    moles=((OLD_MOLE, 22), (NEW_MOLE, 20)), lights=((1262, 1080, 14, 34, 1082), (1136, 1090, 12, 26, 1092)),
    slips=((1052, 968), (1084, 954)), hulls=((1052, 962, 975), (1086, 948, 962)), crane=True,
    goods=(214, 236, 262, 284, 300, 326), lanterna=True, castle=True, suburbs=SUBURBS,
    gardens=(212, 236, 262, 290, 320),
)
GENOA_TRADE = dict(
    GENOA_1600,
    piers=((212, 44), (226, 52), (242, 58), (258, 62), (274, 62), (288, 60), (304, 56), (318, 50)),
    moles=(([(1420, 1058), (1372, 1076), (1310, 1084), (1248, 1082), (1214, 1074)], 30),
           ([(1052, 1070), (1090, 1090), (1140, 1106), (1196, 1114), (1250, 1116)], 22)),
    lights=((1214, 1078, 14, 34, 1080), (1250, 1120, 13, 30, 1122)),
    slips=((1052, 968), (1084, 954), (1030, 990)), hulls=((1052, 962, 975), (1086, 948, 962), (1030, 984, 997)),
    goods=(204, 214, 226, 236, 250, 262, 284, 300, 312, 326, 340),
    suburbs=SUBURBS + ((1650, 900), (1668, 946), (880, 890), (1700, 900)),
    mole_warehouses=((1392, 1066, 40), (1338, 1076, 44), (1282, 1078, 40)),
    east_quay=True, yard_timber=((1004, 962), (1112, 936)), crane2=True,
)
GENOA_GRAIN = dict(GENOA_1520, rows=232, churches=4, castle=False, fort=True, suburbs=SUBURBS, flags=True, pave_in_wall=False,
                   gardens=(212, 236, 262, 290, 320))

ORDER = ("1", "2", "3", "4a", "4b")

STAGES = {
    "1": dict(
        file="growth_1480", year="1480", title="1. Start", sub="rough country, old mole only, a mule track over the Giovi",
        farm_gain=0.25, wood_gain=1.3, sun=(158, 186, 96),
        tree_bias=0.42, scrub=(0.36, 0.07), clearings=False,
        ridge=dict(wood=0.76, clear=0.0, terr=0.0), ridge_low=dict(wood=0.76, clear=0.0, terr=0.0),
        dome=dict(wood=0.52, terr=0.0),
        hill_lines=0, hill_lines_inland=0, hill_near_only=False, hill_crop="olive", hill_scrub=True,
        hamlets={0: 1, 4: 1}, farms=(4, 2),
        blocks={13: STRIPS, 14: STRIPS, 0: STRIPS, 17: STRIPS, 9: STRIPS}, hedge=False, auto_blocks=None,
        road_giovi=("track", 6), road_coast=("cart", 8),
        crossings=dict(pol="ford", bis="ford"), pass_="cairn",
        travellers=(("giovi", 0.5, "mule2", 1),),
        towers=(0,), tower_flags=False,
        savona=dict(n=7, big=0, walled=False, church=False, paved=False, jetty=False, port=False),
        chiavari=dict(n=4, big=0, church=True, paved=False, jetty=False, port=False),
        genoa=GENOA_1480, fleet=FLEET_1480, mills=(), press=(), barns=(),
        flocks=((1290, 150), (700, 760), (2150, 800), (240, 720), (1560, 640), (860, 860)),
        strand_boats=5,
    ),
    "2": dict(
        file="growth_1520", year="about 1520", title="2. Early growth", sub="clearings, first vines and olives, a timber bridge, Savona's wall begun",
        farm_gain=0.6, wood_gain=1.15, sun=(168, 192, 98),
        tree_bias=0.2, scrub=(0.2, 0.03), clearings=True,
        ridge=dict(wood=0.7, clear=0.0, terr=0.0), ridge_low=dict(wood=0.7, clear=0.12, terr=0.0),
        dome=dict(wood=0.42, terr=0.3),
        hill_lines=2, hill_lines_inland=0, hill_near_only=True, hill_crop="olive", hill_scrub=True,
        hamlets={0: 2, 4: 1, 2: 1, 3: 1}, farms=(4, 2, 0, 6),
        blocks={13: MIXED, 14: STRIPS, 0: STRIPS, 17: STRIPS, 9: STRIPS, 3: STRIPS, 4: STRIPS, 6: GROVES, 18: GROVES, 7: STRIPS, 8: GROVES,
                11: STRIPS, 12: GROVES, 16: GROVES, 15: GROVES},
        hedge=True, auto_blocks=None,
        road_giovi=("cart", 8), road_coast=("cart", 9),
        crossings=dict(pol="timber", bis="ford"), pass_="hut",
        travellers=(("giovi", 0.33, "mule", -1), ("giovi", 0.62, "cart", 1)),
        towers=(0, 2), tower_flags=False,
        savona=dict(n=11, big=1, walled=True, wall_frac=0.42, scaffold=True, church=True, paved=True, pave_k=0.88, jetty=False, port=False),
        chiavari=dict(n=6, big=0, church=True, paved=True, jetty=True, port=False),
        genoa=GENOA_1520, fleet=FLEET_1520, mills=(), press=(), barns=(),
        flocks=((1290, 150), (700, 760), (2150, 800), (240, 720), (1560, 640)),
        strand_boats=5,
    ),
    "3": dict(
        file="growth_1600", year="about 1600", title="3. Developed", sub="today's picture: terraces, seven hamlets, stone bridges, new mole and Lanterna",
        farm_gain=1.0, wood_gain=1.0, sun=(176, 198, 100),
        tree_bias=0.0, scrub=(0.0, 0.0), clearings=False,
        ridge=dict(wood=0.62, clear=0.0, terr=0.0), ridge_low=dict(wood=0.62, clear=0.14, terr=0.0),
        dome=dict(wood=0.34, terr=0.66),
        hill_lines=5, hill_lines_inland=0, hill_near_only=False, hill_crop="olive", hill_scrub=False,
        hamlets={0: 2, 1: 2, 2: 2, 3: 2, 4: 2, 5: 2, 6: 2}, farms=(0, 1, 2, 3, 4, 5, 6, 7),
        blocks={i: MIXED for i in range(20)}, hedge=True, auto_blocks=None,
        road_giovi=(None, 11), road_coast=(None, 10),
        crossings=dict(pol="stone", bis="stone"), pass_="hospice",
        travellers=(("giovi", 0.33, "mule", -1), ("giovi", 0.62, "mule", 1)),
        towers=(0, 1, 2), tower_flags=False,
        savona=dict(n=15, big=3, walled=True, church=True, paved=True, jetty=True, port=False),
        chiavari=dict(n=8, big=0, church=True, paved=True, jetty=True, port=False),
        genoa=GENOA_1600, fleet=FLEET_1600, mills=(), press=(), barns=(),
        flocks=((1290, 150), (700, 760), (2150, 800), (240, 720)),
        strand_boats=5,
    ),
    "4a": dict(
        file="growth_1650_trade", year="1650", title="4a. Trade and wine", sub="great port, vines and olives to the ridges, press houses, a highway over the Giovi",
        farm_gain=1.15, wood_gain=0.9, sun=(190, 200, 106),
        tree_bias=-0.14, scrub=(0.0, 0.0), clearings=False,
        ridge=dict(wood=0.6, clear=0.0, terr=0.37, crop="mixed"), ridge_low=dict(wood=0.6, clear=0.0, terr=0.64, crop="mixed"),
        dome=dict(wood=0.3, terr=0.82, crop="mixed"),
        hill_lines=7, hill_lines_inland=5, hill_near_only=False, hill_crop="mixed", hill_scrub=False,
        hamlets={0: 3, 1: 2, 2: 2, 3: 3, 4: 3, 5: 2, 6: 2}, farms=(0, 1, 2, 3, 4, 5, 6, 7),
        blocks={i: WINE for i in range(20)}, hedge=True, auto_blocks=dict(n=10, kind="vine", mix=WINE, hedge=True),
        road_giovi=("highway", 15), road_coast=("highway", 13),
        crossings=dict(pol="stone", bis="stone"), pass_="inn",
        travellers=(("giovi", 0.2, "mule", 1), ("giovi", 0.33, "mule", -1), ("giovi", 0.48, "cart", 1), ("giovi", 0.62, "mule", 1),
                    ("giovi", 0.8, "mule", -1), ("west", 0.35, "cart", 1), ("east", 0.55, "cart", -1), ("west", 0.7, "mule", -1)),
        towers=(0, 1, 2), tower_flags=False,
        savona=dict(n=19, big=5, walled=True, church=True, paved=True, jetty=True, port=True),
        chiavari=dict(n=12, big=3, church=True, paved=True, jetty=True, port=True),
        genoa=GENOA_TRADE, fleet=FLEET_TRADE, mills=(("bis", 0.5),), press=(1, 2, 6, 5, 3), barns=(),
        flocks=((1290, 150), (240, 720)),
        strand_boats=5,
    ),
    "4b": dict(
        file="growth_1650_grain", year="1650", title="4b. Grain and castles", sub="hedged grain on the valley floors, mills, a bastion fortress, a castle at the Giovi",
        farm_gain=1.5, wood_gain=1.0, sun=(192, 200, 100),
        tree_bias=-0.04, scrub=(0.0, 0.0), clearings=False,
        ridge=dict(wood=0.64, clear=0.0, terr=0.0), ridge_low=dict(wood=0.64, clear=0.14, terr=0.0),
        dome=dict(wood=0.34, terr=0.46),
        hill_lines=3, hill_lines_inland=0, hill_near_only=False, hill_crop="olive", hill_scrub=False,
        hamlets={0: 3, 1: 3, 2: 3, 3: 2, 4: 2, 5: 2, 6: 2}, farms=(0, 1, 2, 3, 4, 5, 6, 7),
        blocks={i: GRAIN for i in range(20)}, hedge="trees", auto_blocks=dict(n=16, kind="grain", mix=GRAIN, hedge="trees"),
        road_giovi=(None, 11), road_coast=(None, 10),
        crossings=dict(pol="stone", bis="stone"), pass_="castle",
        travellers=(("giovi", 0.33, "cart", -1), ("giovi", 0.62, "mule", 1), ("west", 0.4, "cart", 1)),
        towers=(0, 1, 2), tower_flags=True,
        savona=dict(n=15, big=3, walled=True, church=True, paved=True, jetty=True, port=False, flags=True),
        chiavari=dict(n=9, big=0, church=True, paved=True, jetty=True, port=False, tower=True),
        genoa=GENOA_GRAIN, fleet=FLEET_GRAIN, mills=(("pol", 0.42), ("pol", 0.66), ("bis", 0.36), ("bis", 0.62)), press=(), barns=(1, 2, 5, 6, 0),
        flocks=((1290, 150), (240, 720), (2150, 800)),
        strand_boats=5,
    ),
}
