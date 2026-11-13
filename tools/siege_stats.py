"""The siege pace table (0.2.2, design sieges-and-retreats.md section 4.3): the seasons it takes each besieger to take a place
with no castle and castles 1 to 3, played in the engine (war.sieges, season by season), next to the design's numbers.

    python -m tools.siege_stats            # the table, and whether every cell is within one season of the design
    python -m tools.siege_stats --forecast # also the card's forecast (war.siege_forecast) for each cell

Plains, full garrisons, no general, no hunger before the stores run out (the table's conditions). A place with no castle
falls to a militia of 500 men. Pygame-free; it changes a fresh world only. tests/test_sieges.py asserts the same table.
"""
import sys

from hexa.campaign.data import GARRISON_HP
from hexa.campaign.state import War
from hexa.campaign.world import CampaignWorld
from tests.support.battles import place

# (besieger, regiments and guns as (branch, era, count), the design's seasons: no castle, castle 1, 2, 3; None = cannot)
DESIGN = (
    ("1 regiment, no guns", [("infantry", 1, 1)], (2, 4, None, None)),
    ("3 regiments, no guns", [("infantry", 1, 3)], (2, 3, 4, 7)),
    ("6 regiments, no guns", [("infantry", 1, 6)], (2, 3, 4, 6)),
    ("3 regiments + 1 bombard", [("infantry", 1, 3), ("artillery", 1, 1)], (2, 2, 4, 6)),
    ("6 regiments + 1 bombard", [("infantry", 1, 6), ("artillery", 1, 1)], (2, 2, 3, 5)),
    ("3 regiments + 2 culverins", [("infantry", 1, 3), ("artillery", 2, 2)], (2, 2, 2, 3)),
)
LIMIT = 40


def _world():
    return CampaignWorld(player="POR")


def _castle_target(world, castle):
    """An empty Castilian province, not its capital, set to ``castle`` levels with a full garrison (none for level 0)."""
    world.wars.append(War("POR", "CAS", world.turn))
    prov = next(p for p in sorted(world.provinces_of("CAS"), key=lambda p: p.pos)
                if p.pos != world.countries["CAS"].capital and not world.units_at(p.pos))
    prov.terrain, prov.castle = "plains", castle
    prov.garrison = castle * GARRISON_HP
    prov.controller, prov.siege, prov.besieger, prov.siege_turns, prov.siege_name = "CAS", 0, "", 0, ""
    world.changed(ownership=True)
    return prov


def seasons_in_engine(castle, spec):
    """The seasons the engine takes to give the place to the besieger (None: it never falls within LIMIT)."""
    world = _world()
    world.units, world.battles = [], []
    prov = _castle_target(world, castle)
    for branch, era, count in spec:
        place(world, branch, era, "POR", prov.pos, count)
    for season in range(1, LIMIT + 1):
        world.sieges()
        if prov.controller == "POR":
            return season
    return None


def forecast(castle, spec):
    """The card's forecast for the same stack, before it arrives (war.siege_forecast)."""
    from hexa.campaign.systems import war
    world = _world()
    world.units, world.battles = [], []
    prov = _castle_target(world, castle)
    units = [u for branch, era, count in spec for u in place(world, branch, era, "POR", prov.pos, count)]
    return war.siege_forecast(world, prov, "POR", units)


def main(argv):
    show_forecast = "--forecast" in argv
    bad = 0
    print(f"{'besieger':28}" + "".join(f"{label:>14}" for label in ("no castle", "castle 1", "castle 2", "castle 3")))
    for label, spec, design in DESIGN:
        row = []
        for castle, want in zip((0, 1, 2, 3), design):
            got = seasons_in_engine(castle, spec)
            cell = "cannot" if got is None else str(got)
            if want is None:
                ok = got is None
            else:
                ok = got is not None and abs(got - want) <= 1
            bad += not ok
            if want is not None and got != want:
                cell += f" ({want})"                  # the design's number, where the engine differs
            row.append(f"{cell:>14}")
        print(f"{label:28}" + "".join(row))
        if show_forecast:
            fc = [forecast(castle, spec) for castle in (0, 1, 2, 3)]
            print(f"{'  card forecast':28}" + "".join(f"{('cannot' if v is None else str(v)):>14}" for v in fc))
    print("cells off the design by more than one season (or wrongly possible or impossible):", bad)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
