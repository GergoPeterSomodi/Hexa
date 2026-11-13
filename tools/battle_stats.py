"""Battle statistics of all-AI campaign games: the baseline the battle system (slice 1) is tuned against.

    python tools/battle_stats.py [--root <checkout>] [--seeds 1,2,3,4] [--seasons 40] [--json <file>]

Plays all-AI games on the Europe map and on random maps, `--seasons` seasons each (the season of
tools/oracle_runner.py: every country's AI, then the round's end), and counts the bus events of each game: wars,
battles, bombardments, units lost, provinces that changed hands, storms and surrenders. Per war it gives battles,
units lost and provinces. `--root` measures another checkout's hexa package (a base worktree, say); the tool
refuses a hexa from anywhere else. Pygame-free: it uses the public API only (CampaignWorld, ai.run, end_round, and
bus.tap to listen).

Numbers the battle system adds (battle length in seasons, the attacker's win rate, the killed and wounded shares)
need the battle's own end event, so they read as null on a checkout without it. `--json` writes them all, for
docs/design/battle-slice1-build-spec.md section 7.3.2 (the baseline PR 5 compares with).
"""
import argparse
import json
import os
import sys
import time
from collections import Counter

DEFAULT_SEEDS = (1, 2, 3, 4)
DEFAULT_SEASONS = 40
SUITES = ("europe", "random")
COUNTS = ("wars", "battles", "bombardments", "units_lost", "units_lost_battle", "surrenders", "provinces_sieged",
          "storms", "provinces_peace", "battle_lost_units", "battle_strength_hurt")


def load_hexa(root):
    """Import the hexa package of `root`. Refuses one from anywhere else."""
    root = os.path.abspath(root)
    sys.path.insert(0, root)
    import hexa
    if os.path.normcase(os.path.realpath(os.path.dirname(hexa.__file__))) != \
            os.path.normcase(os.path.realpath(os.path.join(root, "hexa"))):
        raise SystemExit("wrong hexa: " + hexa.__file__)
    return hexa


class Tally:
    """Counts the events of one game. A bus tap: it never changes the game."""

    def __init__(self):
        self.count = Counter()

    def __call__(self, event):
        kind, count = event.kind, self.count
        if kind == "war_declared":
            count["wars"] += 1
        elif kind == "battle":
            if event.get("ranged"):
                count["bombardments"] += 1
            else:
                count["battles"] += 1
                lost, hurt = event.get("lost") or (0, 0), event.get("hurt") or (0, 0)
                count["battle_lost_units"] += sum(lost)
                count["battle_strength_hurt"] += sum(hurt)
        elif kind == "unit_lost":
            count["units_lost"] += 1
            if event.get("why") == "battle":
                count["units_lost_battle"] += 1
            elif event.get("why") == "surrendered":
                count["surrenders"] += 1
        elif kind == "province_captured":
            if event.get("by") == "storm":
                count["storms"] += 1
            else:
                count["provinces_sieged"] += 1
        elif kind == "peace_made":
            count["provinces_peace"] += event.get("moved") or 0


def play(mode, seed, seasons):
    """One all-AI game; returns its counts, the seasons it ran and the turn it ended on."""
    from hexa.campaign import ai
    from hexa.campaign.world import CampaignWorld
    world = CampaignWorld(seed, map="random") if mode == "random" else CampaignWorld(seed)
    world.player = None
    tally = Tally()
    world.bus.tap(tally)
    for _ in range(seasons):
        for tag in list(world.countries):
            ai.run(world, tag)
        world.end_round()
    return dict(tally.count), world.turn


def share(total, wars):
    return round(total / wars, 3) if wars else None


def summary(rows):
    """Totals over games, and per war: battles, units lost and provinces that changed hands."""
    total = Counter()
    for row in rows:
        total.update({k: row["counts"].get(k, 0) for k in COUNTS})
    wars = total["wars"]
    per_war = {
        "battles_per_war": share(total["battles"], wars),
        "units_lost_per_war": share(total["units_lost"], wars),
        "provinces_per_war": share(total["provinces_sieged"] + total["provinces_peace"], wars),
        "battle_length_seasons": None,          # needs battle_ended (slice 1, PR 3)
        "attacker_win_rate": None,              # needs battle_ended (slice 1, PR 3)
        "killed_share": None,                   # needs battle_ended (slice 1, PR 3)
        "wounded_share": None,                  # needs battle_ended (slice 1, PR 3)
    }
    return {"totals": {k: total[k] for k in COUNTS}, "per_war": per_war}


def run(root, seeds, seasons, quiet=False):
    load_hexa(root)
    rows = []
    for suite in SUITES:
        for seed in seeds:
            started = time.time()
            counts, turn = play(suite, seed, seasons)
            rows.append({"suite": suite, "seed": seed, "turn": turn, "counts": counts})
            if not quiet:
                print(f"{suite:6} seed {seed:3}: {counts.get('wars', 0)} wars, {counts.get('battles', 0)} battles, "
                      f"{counts.get('bombardments', 0)} bombardments ({time.time() - started:.1f} s)", flush=True)
    return {"suites": list(SUITES), "seeds": list(seeds), "seasons": seasons, "games": rows, **summary(rows)}


def table(result):
    t, p = result["totals"], result["per_war"]

    def f(value):
        return "n/a" if value is None else (f"{value:.2f}" if isinstance(value, float) else str(value))

    lines = ["| Measure | Value |", "|---|---|"]
    for name in COUNTS:
        lines.append(f"| {name} (total) | {t[name]} |")
    for name, value in p.items():
        lines.append(f"| {name} | {f(value)} |")
    return "\n".join(lines)


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--root", default=os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                        help="the checkout whose hexa package is measured (default: this one)")
    parser.add_argument("--seeds", default=",".join(str(s) for s in DEFAULT_SEEDS))
    parser.add_argument("--seasons", type=int, default=DEFAULT_SEASONS)
    parser.add_argument("--json", metavar="FILE", help="write the numbers here")
    args = parser.parse_args(argv)
    seeds = [int(s) for s in args.seeds.split(",") if s.strip()]
    result = run(args.root, seeds, args.seasons)
    print()
    print(table(result))
    if args.json:
        with open(args.json, "w", encoding="utf-8") as f:
            json.dump(result, f, indent=1, sort_keys=True)
            f.write("\n")
        print(f"wrote {args.json}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
