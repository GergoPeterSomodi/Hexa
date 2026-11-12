"""Play fixed-seed all-AI games and print a digest of how each one ended (one line per seed).

    python3 -m tests.support.digest_run conquest 0 1 2            Conquest, AI against AI to the end
    python3 -m tests.support.digest_run colony 5 --turns 30       Colonisation, every side by the AI, 30 rounds
    python3 -m tests.support.digest_run campaign 1480 --turns 4   Age of Discovery (Europe), 4 all-AI seasons

The determinism test runs this twice with different PYTHONHASHSEED values and compares the output: the same
seed must give the same game whatever order string hashing puts sets in. Run it by hand the same way:

    PYTHONHASHSEED=0 python3 -m tests.support.digest_run colony 5 --turns 30
    PYTHONHASHSEED=1 python3 -m tests.support.digest_run colony 5 --turns 30

No pygame needed.
"""
import argparse

from tests.support.digests import world_digest
from tests.support.games import play_colony, play_conquest

DEFAULT_TURNS = {"conquest": None, "colony": 30, "campaign": 4}


def play(mode, seed, turns=None):
    """The world after a fixed-seed all-AI game (Conquest always plays to the end)."""
    turns = DEFAULT_TURNS[mode] if turns is None else turns
    if mode == "conquest":
        from hexa.world import World
        return play_conquest(World(seed))
    if mode == "colony":
        from hexa.colony.world import ColonyWorld
        return play_colony(ColonyWorld(seed), turns)
    from hexa.campaign.world import CampaignWorld
    from tests.support.worlds import play_seasons
    return play_seasons(CampaignWorld(seed), turns)


def main(argv=None):
    parser = argparse.ArgumentParser(prog="python3 -m tests.support.digest_run", description=__doc__.split("\n")[0])
    parser.add_argument("mode", choices=sorted(DEFAULT_TURNS))
    parser.add_argument("seeds", nargs="+", type=int)
    parser.add_argument("--turns", type=int, help="Colonisation rounds or campaign seasons (default 30 / 4)")
    args = parser.parse_args(argv)
    for seed in args.seeds:
        world = play(args.mode, seed, args.turns)
        print(args.mode, seed, world.turn, world_digest(world), flush=True)


if __name__ == "__main__":
    main()
