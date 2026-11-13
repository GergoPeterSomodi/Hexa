"""Battle statistics of all-AI campaign games: the numbers the battle system (slice 1) is tuned against.

    python tools/battle_stats.py [--root <checkout>] [--seeds 1,2,3,4] [--seasons 40] [--json <file>]

Plays all-AI games on the Europe map and on random maps, `--seasons` seasons each (the season of
tools/oracle_runner.py: every country's AI, then the round's end), and counts the bus events of each game: wars,
battles (battle_started), units lost, provinces that changed hands, storms and surrenders. From each battle's end
(battle_ended) it takes the length in seasons, who won (draws have no winner), the men killed and wounded, and whether
the battle reached the safety stop (ended at or past BATTLE_MAX_SEASONS seasons). Per war it gives battles, units lost
and provinces. `--root` measures another checkout's hexa package (a base worktree, say); the tool refuses a hexa from
anywhere else. Pygame-free: it uses the public API only (CampaignWorld, ai.run, end_round, and bus.tap to listen).

The numbers of docs/reports/battle-baseline.json keep their names: the old `battles` and `bombardments` were one-shot
fights of the old war.battle(); from slice 1 on a battle is counted when it starts, and nothing bombards. `--json`
writes them all (docs/design/battle-slice1-build-spec.md section 7.3.2: the baseline PR 5 compares with).
"""
import argparse
import json
import math
import os
import statistics
import sys
import time
from collections import Counter

DEFAULT_SEEDS = (1, 2, 3, 4)
DEFAULT_SEASONS = 40
SUITES = ("europe", "random")
COUNTS = ("wars", "battles", "bombardments", "units_lost", "units_lost_battle", "surrenders", "provinces_sieged",
          "storms", "provinces_peace", "battle_lost_units", "battle_strength_hurt")
MEN_COUNTS = ("men_killed", "men_wounded", "battles_ended", "battles_stopped", "battles_draw", "battle_wins_attacker",
              "battle_wins_defender", "battles_destroyed")
ENDS = ("broke", "withdrew", "surrendered", "destroyed", "peace", "gone")     # battle_ended's "how", counted
EVEN = (2 / 3, 3 / 2)            # an even battle: the attackers' men at the start are within these ratios of the defenders'


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
    """Counts the events of one game. A bus tap: it never changes the game. ``world`` gives the battle's men at its start
    (battle_started is sent while the battle stands in world.battles)."""

    def __init__(self, stop_seasons, world=None):
        self.count = Counter()
        self.lengths = []
        self.even_lengths = []
        self.stop_seasons = stop_seasons
        self.world = world
        self.even_at = {}          # pos -> whether the battle starts even (its men at the start)

    def __call__(self, event):
        kind, count = event.kind, self.count
        if kind == "war_declared":
            count["wars"] += 1
        elif kind == "battle_started":
            count["battles"] += 1
            battle = self.world.battle_at(event.pos) if self.world is not None else None
            if battle is not None:
                men = [battle.men0.get(battle.attacker, 0), battle.men0.get(battle.defender, 0)]
                self.even_at[event.pos] = bool(min(men) > 0 and EVEN[0] <= men[0] / men[1] <= EVEN[1])
        elif kind == "battle_ended":
            self.ended(event)
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

    def ended(self, event):
        count = self.count
        seasons = event.get("seasons") or 0
        self.lengths.append(seasons)
        count["battles_ended"] += 1
        how = event.get("how")
        count[f"end_{how}"] += 1
        if how == "destroyed":
            count["battles_destroyed"] += 1
        if self.even_at.pop(event.pos, False):
            self.even_lengths.append(seasons)
        killed = sum((event.get("killed") or {}).values())
        wounded = sum((event.get("wounded") or {}).values())
        count["men_killed"] += round(killed)
        count["men_wounded"] += round(wounded)
        count["battle_strength_hurt"] += round(killed + wounded)
        if seasons >= self.stop_seasons:
            count["battles_stopped"] += 1
        winner = event.get("winner")
        if winner is None:
            count["battles_draw"] += 1
        elif winner == event.get("attacker"):
            count["battle_wins_attacker"] += 1
        else:
            count["battle_wins_defender"] += 1


def play(mode, seed, seasons):
    """One all-AI game; returns its counts, the lengths of its battles, the lengths of its even battles and the turn it
    ended on."""
    from hexa.campaign import ai
    from hexa.campaign.data import BATTLE_MAX_SEASONS
    from hexa.campaign.world import CampaignWorld
    world = CampaignWorld(seed, map="random") if mode == "random" else CampaignWorld(seed)
    world.player = None
    tally = Tally(BATTLE_MAX_SEASONS, world)
    world.bus.tap(tally)
    for _ in range(seasons):
        for tag in list(world.countries):
            ai.run(world, tag)
        world.end_round()
    return dict(tally.count), tally.lengths, tally.even_lengths, world.turn


def share(total, wars):
    return round(total / wars, 3) if wars else None


def p90(values):
    """The 90th percentile by nearest rank."""
    ordered = sorted(values)
    return ordered[math.ceil(0.9 * len(ordered)) - 1]


def summary(rows):
    """Totals over games, and per war: battles, units lost, provinces, and the battles' own measures."""
    total = Counter()
    lengths, even = [], []
    for row in rows:
        total.update({k: row["counts"].get(k, 0) for k in COUNTS + MEN_COUNTS + tuple(f"end_{h}" for h in ENDS)})
        lengths += row["lengths"]
        even += row.get("even_lengths", [])
    wars, battles = total["wars"], total["battles"]
    decided = total["battle_wins_attacker"] + total["battle_wins_defender"]
    casualties = total["men_killed"] + total["men_wounded"]
    per_war = {
        "battles_per_war": share(battles, wars),
        "units_lost_per_war": share(total["units_lost"], wars),
        "provinces_per_war": share(total["provinces_sieged"] + total["provinces_peace"], wars),
        "battle_length_seasons": {"median": statistics.median(lengths), "p90": p90(lengths)} if lengths else None,
        "even_battle_length_seasons": {"median": statistics.median(even), "p90": p90(even), "battles": len(even)}
        if even else None,
        "destroyed_share": share(total["battles_destroyed"], battles),
        "attacker_win_rate": round(total["battle_wins_attacker"] / decided, 3) if decided else None,
        "draw_rate": share(total["battles_draw"], battles),
        "stop_share": share(total["battles_stopped"], battles),
        "killed_per_battle": share(total["men_killed"], battles),
        "wounded_per_battle": share(total["men_wounded"], battles),
        "wounded_share": round(total["men_wounded"] / casualties, 3) if casualties else None,
    }
    return {"totals": {k: total[k] for k in COUNTS + MEN_COUNTS + tuple(f"end_{h}" for h in ENDS)}, "per_war": per_war}


def run(root, seeds, seasons, quiet=False):
    load_hexa(root)
    rows = []
    for suite in SUITES:
        for seed in seeds:
            started = time.time()
            counts, lengths, even, turn = play(suite, seed, seasons)
            rows.append({"suite": suite, "seed": seed, "turn": turn, "counts": counts, "lengths": lengths,
                         "even_lengths": even})
            if not quiet:
                print(f"{suite:6} seed {seed:3}: {counts.get('wars', 0)} wars, {counts.get('battles', 0)} battles, "
                      f"{counts.get('units_lost', 0)} units lost ({time.time() - started:.1f} s)", flush=True)
    return {"suites": list(SUITES), "seeds": list(seeds), "seasons": seasons, "games": rows, **summary(rows)}


def table(result):
    t, p = result["totals"], result["per_war"]

    def f(value):
        if value is None:
            return "n/a"
        if isinstance(value, dict):
            return ", ".join(f"{k} {v}" for k, v in value.items())
        return f"{value:.3f}" if isinstance(value, float) else str(value)

    lines = ["| Measure | Value |", "|---|---|"]
    for name in COUNTS + MEN_COUNTS + tuple(f"end_{h}" for h in ENDS):
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
