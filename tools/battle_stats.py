"""Battle statistics: the numbers the battle system (slice 1) is tuned against.

    python tools/battle_stats.py [--root <checkout>] [--seeds 1,2,3,4] [--seasons 40] [--no-scenarios] [--json <file>]

Two parts. (1) Scenarios: the fixed fights of tests/support/scenarios.py (3 v 3, 4 v 3, 6 v 4, 6 v 6 and the mixed ones)
on plains and on hills, 30 seeds each: the attacker's win rate, the length in seasons (median, p90), the share that
reach the safety stop and the loser's share of its men lost. These are the bands of tests/test_battle.py.
(2) All-AI games (Europe and random maps, `--seasons` seasons each; the season of tools/oracle_runner.py). They count
wars, battles, units lost, provinces that changed hands, storms and surrenders, and per battle its end. Each battle is
also bucketed by its START strength ratio: the attacker's men x army morale over the defender's, when the battle starts
(even 0.8-1.25, about 1.3x 1.25-1.6, about 2x 1.6-2.5, overwhelming above 2.5, under 0.8 for the outnumbered attacker).
Per bucket: battles, attacker win rate (draws are left out), median and p90 length, and the share at the safety stop.
The snowball measure: the biggest country's share of the land, at the start and at the end of each game (the
stop-steamrolling measure, docs/design/stop-steamrolling.md section 6).

Per war it gives battles, units lost and provinces. `--root` measures another checkout's hexa package (a base snapshot,
say); the tool refuses a hexa from anywhere else. Pygame-free: it uses the public API only (CampaignWorld, ai.run,
end_round, bus.tap to listen), and the scenarios of tests/support (no pygame there either).

The numbers of docs/reports/battle-baseline.json keep their names: the old `battles` and `bombardments` were one-shot
fights of the old war.battle(); from slice 1 on a battle is counted when it starts, and nothing bombards. `--json`
writes them all (docs/design/battle-slice1-build-spec.md section 7.3.2).
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
# The start strength ratio (attacker men x morale over the defender's): name, from (inclusive), to (exclusive).
BUCKETS = (("under 0.8", 0.0, 0.8), ("even 0.8-1.25", 0.8, 1.25), ("about 1.3x 1.25-1.6", 1.25, 1.6),
           ("about 2x 1.6-2.5", 1.6, 2.5), ("overwhelming above 2.5", 2.5, math.inf))


def load_hexa(root):
    """Import the hexa package of `root`. Refuses one from anywhere else."""
    root = os.path.abspath(root)
    sys.path.insert(0, root)
    import hexa
    if os.path.normcase(os.path.realpath(os.path.dirname(hexa.__file__))) != \
            os.path.normcase(os.path.realpath(os.path.join(root, "hexa"))):
        raise SystemExit("wrong hexa: " + hexa.__file__)
    return hexa


def bucket_of(ratio):
    """The bucket name of a start strength ratio, or None when it is not a number (no defenders)."""
    if ratio is None or math.isinf(ratio) or math.isnan(ratio):
        return None
    for name, low, high in BUCKETS:
        if low <= ratio < high:
            return name
    return None


def empty_bucket():
    return {"battles": 0, "attacker_wins": 0, "defender_wins": 0, "draws": 0, "stops": 0, "lengths": []}


class Tally:
    """Counts the events of one game. A bus tap: it never changes the game. ``world`` gives the battle's men and morale
    at its start (battle_started is sent while the battle stands in world.battles)."""

    def __init__(self, stop_seasons, world=None):
        self.count = Counter()
        self.lengths = []
        self.stop_seasons = stop_seasons
        self.world = world
        self.bucket_at = {}                              # pos -> bucket name, from the battle's start to its end
        self.buckets = {name: empty_bucket() for name, _, _ in BUCKETS}

    def __call__(self, event):
        kind, count = event.kind, self.count
        if kind == "war_declared":
            count["wars"] += 1
        elif kind == "battle_started":
            count["battles"] += 1
            battle = self.world.battle_at(event.pos) if self.world is not None else None
            if battle is not None:
                self.bucket_at[event.pos] = bucket_of(self.ratio(battle))
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

    def ratio(self, battle):
        """The attacker's men x army morale over the defender's, at the start (None when the defender has none)."""
        from hexa.campaign.systems import combat
        att = combat.battle_strength(self.world, battle, battle.attacker)
        dfn = combat.battle_strength(self.world, battle, battle.defender)
        return att / dfn if dfn > 0 else None

    def ended(self, event):
        count = self.count
        seasons = event.get("seasons") or 0
        self.lengths.append(seasons)
        count["battles_ended"] += 1
        how = event.get("how")
        count[f"end_{how}"] += 1
        if how == "destroyed":
            count["battles_destroyed"] += 1
        killed = sum((event.get("killed") or {}).values())
        wounded = sum((event.get("wounded") or {}).values())
        count["men_killed"] += round(killed)
        count["men_wounded"] += round(wounded)
        count["battle_strength_hurt"] += round(killed + wounded)
        stopped = seasons >= self.stop_seasons
        if stopped:
            count["battles_stopped"] += 1
        winner = event.get("winner")
        if winner is None:
            count["battles_draw"] += 1
        elif winner == event.get("attacker"):
            count["battle_wins_attacker"] += 1
        else:
            count["battle_wins_defender"] += 1
        name = self.bucket_at.pop(event.pos, None)
        if name is not None:
            rec = self.buckets[name]
            rec["battles"] += 1
            rec["lengths"].append(seasons)
            rec["stops"] += stopped
            if winner is None:
                rec["draws"] += 1
            elif winner == event.get("attacker"):
                rec["attacker_wins"] += 1
            else:
                rec["defender_wins"] += 1


def land_top_share(world):
    """The biggest country's share of the land hexes it owns (0 when there is no land)."""
    counts = Counter(p.owner for p in world.provinces.values() if p.owner is not None and world.is_land(p.pos))
    total = sum(counts.values())
    return max(counts.values()) / total if total else 0.0


def play(mode, seed, seasons):
    """One all-AI game; returns its counts, the lengths of its battles, its buckets, the biggest land share at the start
    and at the end, and the turn it ended on."""
    from hexa.campaign import ai
    from hexa.campaign.data import BATTLE_MAX_SEASONS
    from hexa.campaign.world import CampaignWorld
    world = CampaignWorld(seed, map="random") if mode == "random" else CampaignWorld(seed)
    world.player = None
    top_start = land_top_share(world)
    tally = Tally(BATTLE_MAX_SEASONS, world)
    world.bus.tap(tally)
    for _ in range(seasons):
        for tag in list(world.countries):
            ai.run(world, tag)
        world.end_round()
    return {"counts": dict(tally.count), "lengths": tally.lengths, "buckets": tally.buckets, "turn": world.turn,
            "top_start": top_start, "top_end": land_top_share(world)}


def share(total, wars):
    return round(total / wars, 3) if wars else None


def p90(values):
    """The 90th percentile by nearest rank."""
    ordered = sorted(values)
    return ordered[math.ceil(0.9 * len(ordered)) - 1]


def length_stats(values):
    return {"median": statistics.median(values), "p90": p90(values)} if values else None


def summary(rows):
    """Totals over games, per war, the buckets and the snowball measure."""
    total = Counter()
    lengths = []
    for row in rows:
        total.update({k: row["counts"].get(k, 0) for k in COUNTS + MEN_COUNTS + tuple(f"end_{h}" for h in ENDS)})
        lengths += row["lengths"]
    wars, battles = total["wars"], total["battles"]
    decided = total["battle_wins_attacker"] + total["battle_wins_defender"]
    casualties = total["men_killed"] + total["men_wounded"]
    per_war = {
        "battles_per_war": share(battles, wars),
        "units_lost_per_war": share(total["units_lost"], wars),
        "provinces_per_war": share(total["provinces_sieged"] + total["provinces_peace"], wars),
        "battle_length_seasons": length_stats(lengths),
        "destroyed_share": share(total["battles_destroyed"], battles),
        "attacker_win_rate": round(total["battle_wins_attacker"] / decided, 3) if decided else None,
        "draw_rate": share(total["battles_draw"], battles),
        "stop_share": share(total["battles_stopped"], battles),
        "killed_per_battle": share(total["men_killed"], battles),
        "wounded_per_battle": share(total["men_wounded"], battles),
        "wounded_share": round(total["men_wounded"] / casualties, 3) if casualties else None,
    }
    tops = [row["top_start"] for row in rows], [row["top_end"] for row in rows]
    snowball = {"top_share_start_mean": round(statistics.mean(tops[0]), 3) if rows else None,
                "top_share_end_mean": round(statistics.mean(tops[1]), 3) if rows else None,
                "top_share_end_max": round(max(tops[1]), 3) if rows else None}
    return {"totals": {k: total[k] for k in COUNTS + MEN_COUNTS + tuple(f"end_{h}" for h in ENDS)},
            "per_war": per_war, "buckets": bucket_summary(rows), "snowball": snowball}


def bucket_summary(rows):
    """Per start-strength bucket: battles, attacker win rate (draws left out), length and the share at the stop."""
    out = {}
    for name, _, _ in BUCKETS:
        battles = wins = losses = stops = 0
        lengths = []
        for row in rows:
            rec = row["buckets"].get(name, empty_bucket())
            battles += rec["battles"]
            wins += rec["attacker_wins"]
            losses += rec["defender_wins"]
            stops += rec["stops"]
            lengths += rec["lengths"]
        decided = wins + losses
        out[name] = {"battles": battles,
                     "attacker_win_rate": round(wins / decided, 3) if decided else None,
                     "length_seasons": length_stats(lengths),
                     "stop_share": share(stops, battles)}
    return out


def scenario_rows(root, seeds=None):
    """The scenario fights of tests/support/scenarios.py on each terrain: attacker win rate, seasons, the stop, and the
    loser's share of its men lost (median)."""
    load_hexa(root)
    from tests.support.scenarios import SCENARIOS, SEEDS, TERRAINS, play
    from tests.support.worlds import fresh
    world = fresh("POR")
    out = {}
    for name, (spec_a, spec_d) in SCENARIOS.items():
        out[name] = {}
        for terrain in TERRAINS:
            rows = [play(world, seed, spec_a, spec_d, terrain) for seed in (seeds or SEEDS)]
            att = sum(1 for r in rows if r["winner"] == r["battle"].attacker)
            seasons = [r["seasons"] for r in rows]
            losses = [r["loss"][r["battle"].attacker if r["winner"] != r["battle"].attacker else r["battle"].defender]
                      for r in rows]
            out[name][terrain] = {"attacker_win_rate": round(att / len(rows), 3),
                                  "length_seasons": length_stats(seasons),
                                  "in_1_to_3_seasons": round(sum(1 for s in seasons if 1 <= s <= 3) / len(rows), 3),
                                  "stop_share": round(sum(1 for r in rows if r["stopped"]) / len(rows), 3),
                                  "loser_loss_median": round(statistics.median(losses), 3)}
    return out


def run(root, seeds, seasons, quiet=False):
    load_hexa(root)
    rows = []
    for suite in SUITES:
        for seed in seeds:
            started = time.time()
            game = play(suite, seed, seasons)
            rows.append({"suite": suite, "seed": seed, **game})
            if not quiet:
                counts = game["counts"]
                print(f"{suite:6} seed {seed:3}: {counts.get('wars', 0)} wars, {counts.get('battles', 0)} battles, "
                      f"{counts.get('units_lost', 0)} units lost ({time.time() - started:.1f} s)", flush=True)
    return {"suites": list(SUITES), "seeds": list(seeds), "seasons": seasons,
            "games": [{k: r[k] for k in ("suite", "seed", "counts", "turn")} for r in rows],
            "rows": rows, **summary(rows)}


def fmt(value):
    if value is None:
        return "n/a"
    if isinstance(value, dict):
        return ", ".join(f"{k} {v}" for k, v in value.items())
    return f"{value:.3f}" if isinstance(value, float) else str(value)


def table(result):
    t, p = result["totals"], result["per_war"]
    lines = ["| Measure | Value |", "|---|---|"]
    for name in COUNTS + MEN_COUNTS + tuple(f"end_{h}" for h in ENDS):
        lines.append(f"| {name} (total) | {t[name]} |")
    for name, value in p.items():
        lines.append(f"| {name} | {fmt(value)} |")
    for name, value in result["snowball"].items():
        lines.append(f"| {name} | {fmt(value)} |")
    return "\n".join(lines)


def bucket_table(result):
    lines = ["| Start strength (attacker men x morale / defender's) | Battles | Attacker win % | Length median (p90) | At the stop |",
             "|---|---|---|---|---|"]
    for name, rec in result["buckets"].items():
        win = "n/a" if rec["attacker_win_rate"] is None else f"{100 * rec['attacker_win_rate']:.0f}%"
        length = rec["length_seasons"]
        size = "n/a" if length is None else f"{length['median']} ({length['p90']})"
        stop = "n/a" if rec["stop_share"] is None else f"{100 * rec['stop_share']:.0f}%"
        lines.append(f"| {name} | {rec['battles']} | {win} | {size} | {stop} |")
    return "\n".join(lines)


def scenario_table(scenarios):
    lines = ["| Scenario | Ground | Attacker win % | Length median (p90) | In 1-3 seasons | At the stop | Loser loses (median) |",
             "|---|---|---|---|---|---|---|"]
    for name, by_terrain in scenarios.items():
        for terrain, rec in by_terrain.items():
            size = rec["length_seasons"]
            lines.append(f"| {name} | {terrain} | {100 * rec['attacker_win_rate']:.0f}% | "
                         f"{size['median']} ({size['p90']}) | {100 * rec['in_1_to_3_seasons']:.0f}% | "
                         f"{100 * rec['stop_share']:.0f}% | {100 * rec['loser_loss_median']:.0f}% |")
    return "\n".join(lines)


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--root", default=os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                        help="the checkout whose hexa package is measured (default: this one)")
    parser.add_argument("--seeds", default=",".join(str(s) for s in DEFAULT_SEEDS))
    parser.add_argument("--seasons", type=int, default=DEFAULT_SEASONS)
    parser.add_argument("--no-scenarios", action="store_true", help="skip the scenario table")
    parser.add_argument("--json", metavar="FILE", help="write the numbers here")
    args = parser.parse_args(argv)
    seeds = [int(s) for s in args.seeds.split(",") if s.strip()]
    result = {}
    if not args.no_scenarios:
        result["scenarios"] = scenario_rows(args.root)
        print(scenario_table(result["scenarios"]))
        print()
    game = run(args.root, seeds, args.seasons)
    result.update(game)
    print()
    print(table(result))
    print()
    print(bucket_table(result))
    if args.json:
        result.pop("rows", None)
        with open(args.json, "w", encoding="utf-8") as f:
            json.dump(result, f, indent=1, sort_keys=True)
            f.write("\n")
        print(f"wrote {args.json}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
