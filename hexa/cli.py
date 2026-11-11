"""The command line of play.py. No pygame here, so tests can import it."""
import argparse


def build_parser():
    parser = argparse.ArgumentParser(description="Play Hexa.")
    parser.add_argument("--mode", choices=("campaign", "conquest", "colony"), help="skip the menu and start this mode")
    parser.add_argument("--nation", help="campaign: play this country straight away, by tag or name in any case "
                        "(e.g. POR, eng, Venice); random worlds have their own countries")
    parser.add_argument("--map", choices=("europe", "random"), default="europe",
                        help="campaign: the real 1480 map or a random world")
    parser.add_argument("--start", choices=("sea", "land"), default="sea", help="colonisation: how to start")
    parser.add_argument("--goal", choices=("survive", "independence", "endless"), default="survive",
                        help="colonisation: how to win")
    parser.add_argument("--seed", type=int, help="map number, to replay the same map")
    return parser


def parse(argv=None):
    """Parse argv (default sys.argv[1:]) into (settings, skip_menu, nation, seed).

    settings is the dict the menu starts from; skip_menu is True when --mode was given; nation is the raw
    --nation text (CampaignApp matches it to a country) and seed the --seed int, each None when absent."""
    args = build_parser().parse_args(argv)
    settings = {"mode": args.mode or "campaign", "start": args.start, "goal": args.goal, "map": args.map}
    return settings, args.mode is not None, args.nation, args.seed
